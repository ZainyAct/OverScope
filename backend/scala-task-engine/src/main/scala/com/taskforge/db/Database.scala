package com.taskforge.db

import java.sql.{Connection, DriverManager, ResultSet, Timestamp}
import java.time.{LocalDate, LocalDateTime}
import java.util.UUID
import scala.util.{Try, Success, Failure}
import com.taskforge.models.{TaskEvent, UserMetrics, OrganizationMetrics, Task, User}
import com.taskforge.services.{CapacityForecaster, EstimationService}
import com.zaxxer.hikari.{HikariConfig, HikariDataSource}

object Database {
  private var dataSource: Option[HikariDataSource] = None
  
  def initialize(dbUrl: String, dbUser: String, dbPassword: String): Unit = {
    val config = new HikariConfig()
    config.setJdbcUrl(dbUrl)
    config.setUsername(dbUser)
    config.setPassword(dbPassword)
    config.setMaximumPoolSize(10)
    config.setMinimumIdle(2)
    config.setConnectionTimeout(30000)
    dataSource = Some(new HikariDataSource(config))
  }
  
  def getConnection: Connection = {
    dataSource match {
      case Some(ds) => ds.getConnection
      case None => throw new IllegalStateException("Database not initialized")
    }
  }
  
  def fetchNewTaskEvents(lastId: Long, limit: Int = 1000): List[TaskEvent] = {
    val conn = getConnection
    try {
      // Use timestamp-based tracking (lastId is epoch seconds)
      val lastTimestamp = new java.sql.Timestamp(lastId * 1000)
      val stmt = conn.prepareStatement(
        "SELECT id, task_id, event_type, actor_user_id, created_at, metadata " +
        "FROM task_events " +
        "WHERE created_at > ? " +
        "ORDER BY created_at " +
        "LIMIT ?"
      )
      stmt.setTimestamp(1, lastTimestamp)
      stmt.setInt(2, limit)
      
      val rs = stmt.executeQuery()
      val events = scala.collection.mutable.ListBuffer[TaskEvent]()
      
      while (rs.next()) {
        val id = rs.getObject("id").toString
        val taskId = rs.getObject("task_id").toString
        val eventType = rs.getString("event_type")
        val actorUserIdObj = rs.getObject("actor_user_id")
        val actorUserId = if (actorUserIdObj != null) Some(actorUserIdObj.toString) else None
        val createdAt = rs.getTimestamp("created_at").toLocalDateTime
        val metadataJson = rs.getString("metadata")
        val metadata = if (metadataJson != null && metadataJson.nonEmpty) {
          // Simple JSON parsing - in production use proper JSON library
          Map.empty[String, String] // Simplified for now
        } else {
          Map.empty[String, String]
        }
        
        events += TaskEvent(id, taskId, eventType, actorUserId, createdAt, metadata)
      }
      
      rs.close()
      stmt.close()
      events.toList
    } finally {
      conn.close()
    }
  }
  
  def getMaxTaskEventId: Long = {
    val conn = getConnection
    try {
      // Use the most recent created_at timestamp as a proxy for "last seen"
      val stmt = conn.prepareStatement(
        "SELECT COALESCE(EXTRACT(EPOCH FROM MAX(created_at))::bigint, 0) as max_timestamp FROM task_events"
      )
      val rs = stmt.executeQuery()
      if (rs.next()) {
        rs.getLong("max_timestamp")
      } else {
        0L
      }
    } finally {
      conn.close()
    }
  }
  
  def upsertUserMetrics(metrics: UserMetrics): Unit = {
    val conn = getConnection
    try {
      // Note: user_metrics table should be created via Rails migration
      // This will fail gracefully if table doesn't exist yet
      
      // Upsert user metrics
      val stmt = conn.prepareStatement(
        """INSERT INTO user_metrics 
           (user_id, avg_completion_hours, tasks_completed_last_30_days, current_load_hours, capacity_hours, pressure_score, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, NOW())
           ON CONFLICT (user_id) 
           DO UPDATE SET 
             avg_completion_hours = EXCLUDED.avg_completion_hours,
             tasks_completed_last_30_days = EXCLUDED.tasks_completed_last_30_days,
             current_load_hours = EXCLUDED.current_load_hours,
             capacity_hours = EXCLUDED.capacity_hours,
             pressure_score = EXCLUDED.pressure_score,
             updated_at = NOW()"""
      )
      stmt.setObject(1, UUID.fromString(metrics.userId))
      stmt.setDouble(2, metrics.avgCompletionHours)
      stmt.setInt(3, metrics.tasksCompletedLast30Days)
      stmt.setDouble(4, metrics.currentLoadHours)
      stmt.setInt(5, metrics.capacityHours.toInt)
      stmt.setDouble(6, metrics.pressureScore)
      stmt.executeUpdate()
      stmt.close()
    } catch {
      case e: Exception =>
        println(s"Warning: Could not upsert user metrics: ${e.getMessage}")
    } finally {
      conn.close()
    }
  }
  
  def fetchUserMetrics(userId: String): Option[UserMetrics] = {
    val conn = getConnection
    try {
      val stmt = conn.prepareStatement(
        "SELECT user_id, avg_completion_hours, tasks_completed_last_30_days, current_load_hours, capacity_hours, pressure_score FROM user_metrics WHERE user_id = ?"
      )
      stmt.setObject(1, UUID.fromString(userId))
      val rs = stmt.executeQuery()
      if (rs.next()) {
        Some(UserMetrics(
          rs.getObject("user_id").toString,
          rs.getDouble("avg_completion_hours"),
          rs.getInt("tasks_completed_last_30_days"),
          rs.getDouble("current_load_hours"),
          rs.getInt("capacity_hours"),
          rs.getDouble("pressure_score")
        ))
      } else {
        None
      }
    } catch {
      case e: Exception =>
        println(s"Warning: Could not fetch user metrics: ${e.getMessage}")
        None
    } finally {
      conn.close()
    }
  }
  
  def fetchAllUsers(organizationId: Option[String] = None): List[User] = {
    val conn = getConnection
    try {
      val query = organizationId match {
        case Some(orgId) =>
          """SELECT DISTINCT u.id, u.email, u.full_name
             FROM users u
             JOIN memberships m ON u.id = m.user_id
             WHERE m.organization_id = ?"""
        case None =>
          "SELECT id, email, full_name FROM users"
      }
      
      val stmt = conn.prepareStatement(query)
      organizationId.foreach(orgId => stmt.setObject(1, UUID.fromString(orgId)))
      val rs = stmt.executeQuery()
      val users = scala.collection.mutable.ListBuffer[User]()
      
      while (rs.next()) {
        val userId = rs.getObject("id").toString
        // Default capacity - in production, this would come from a user settings table
        val capacity = 40
        users += User(userId, capacity, Nil)
      }
      
      rs.close()
      stmt.close()
      users.toList
    } catch {
      case e: Exception =>
        println(s"Warning: Could not fetch users: ${e.getMessage}")
        Nil
    } finally {
      conn.close()
    }
  }
  
  def fetchHistoricalDataForUser(userId: String, weeks: Int = 8): CapacityForecaster.HistoricalData = {
    val conn = getConnection
    try {
      // Fetch completed tasks for the user in the last N weeks
      val stmt = conn.prepareStatement(
        s"""SELECT 
             EXTRACT(EPOCH FROM (te_completed.created_at - te_created.created_at)) / 3600.0 as lead_time_hours,
             DATE_TRUNC('week', te_completed.created_at) as week
           FROM task_events te_completed
           JOIN task_events te_created ON te_completed.task_id = te_created.task_id
           WHERE te_completed.event_type = 'completed'
             AND te_created.event_type = 'created'
             AND te_completed.actor_user_id = ?
             AND te_completed.created_at >= NOW() - INTERVAL '$weeks weeks'
           ORDER BY te_completed.created_at"""
      )
      stmt.setObject(1, UUID.fromString(userId))
      val rs = stmt.executeQuery()
      
      val weeklyThroughput = scala.collection.mutable.Map[String, Double]()
      val completionTimes = scala.collection.mutable.ListBuffer[Double]()
      
      while (rs.next()) {
        val leadTime = rs.getDouble("lead_time_hours")
        if (!rs.wasNull() && leadTime > 0) {
          completionTimes += leadTime
          val week = rs.getString("week")
          weeklyThroughput(week) = weeklyThroughput.getOrElse(week, 0.0) + leadTime
        }
      }
      
      rs.close()
      stmt.close()
      
      val avgCompletionTime = if (completionTimes.nonEmpty) {
        completionTimes.sum / completionTimes.length
      } else {
        0.0
      }
      
      CapacityForecaster.HistoricalData(
        userId,
        weeklyThroughput.values.toList,
        avgCompletionTime,
        completionTimes.length
      )
    } catch {
      case e: Exception =>
        println(s"Warning: Could not fetch historical data: ${e.getMessage}")
        CapacityForecaster.HistoricalData(userId, Nil, 0.0, 0)
    } finally {
      conn.close()
    }
  }
  
  def fetchOverdueTasksCount(organizationId: String, hoursWindow: Int = 24): Int = {
    val conn = getConnection
    try {
      val stmt = conn.prepareStatement(
        s"""SELECT COUNT(*) as overdue_count
           FROM tasks t
           JOIN projects p ON t.project_id = p.id
           WHERE p.organization_id = ?
             AND t.status IN ('open', 'in_progress')
             AND t.due_date < CURRENT_DATE
             AND t.updated_at >= NOW() - INTERVAL '$hoursWindow hours'"""
      )
      stmt.setObject(1, UUID.fromString(organizationId))
      val rs = stmt.executeQuery()
      if (rs.next()) {
        rs.getInt("overdue_count")
      } else {
        0
      }
    } catch {
      case e: Exception =>
        println(s"Warning: Could not fetch overdue tasks: ${e.getMessage}")
        0
    } finally {
      conn.close()
    }
  }
  
  def fetchTaskCreationAndCompletionTimes(taskId: String): Option[(LocalDateTime, LocalDateTime)] = {
    val conn = getConnection
    try {
      val stmt = conn.prepareStatement(
        """SELECT 
             MAX(CASE WHEN event_type = 'created' THEN created_at END) as created_at,
             MAX(CASE WHEN event_type = 'completed' THEN created_at END) as completed_at
           FROM task_events
           WHERE task_id = ?
             AND event_type IN ('created', 'completed')"""
      )
      stmt.setObject(1, UUID.fromString(taskId))
      val rs = stmt.executeQuery()
      if (rs.next()) {
        val createdObj = rs.getTimestamp("created_at")
        val completedObj = rs.getTimestamp("completed_at")
        if (createdObj != null && completedObj != null) {
          Some((createdObj.toLocalDateTime, completedObj.toLocalDateTime))
        } else {
          None
        }
      } else {
        None
      }
    } catch {
      case e: Exception =>
        None
    } finally {
      conn.close()
    }
  }
  
  def upsertOrganizationMetrics(metrics: OrganizationMetrics): Unit = {
    val conn = getConnection
    try {
      val stmt = conn.prepareStatement(
        """INSERT INTO task_metrics_daily 
           (organization_id, date, tasks_created, tasks_completed, avg_lead_time_hours)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT (organization_id, date) 
           DO UPDATE SET 
             tasks_created = EXCLUDED.tasks_created,
             tasks_completed = EXCLUDED.tasks_completed,
             avg_lead_time_hours = EXCLUDED.avg_lead_time_hours"""
      )
      stmt.setObject(1, UUID.fromString(metrics.organizationId))
      stmt.setDate(2, java.sql.Date.valueOf(metrics.date))
      stmt.setInt(3, metrics.tasksCreated)
      stmt.setInt(4, metrics.tasksCompleted)
      stmt.setDouble(5, metrics.avgLeadTimeHours)
      stmt.executeUpdate()
      stmt.close()
    } finally {
      conn.close()
    }
  }
  
  def fetchTasksForOrganization(organizationId: String): List[Task] = {
    val conn = getConnection
    try {
      val stmt = conn.prepareStatement(
        """SELECT t.id, t.priority, t.due_date, t.status, t.created_at, 
                  COALESCE(t.estimate_hours, 5) as estimate_hours,
                  COALESCE(t.complexity, 3) as complexity
           FROM tasks t
           JOIN projects p ON t.project_id = p.id
           WHERE p.organization_id = ? AND t.status != 'completed'"""
      )
      stmt.setObject(1, UUID.fromString(organizationId))
      val rs = stmt.executeQuery()
      val tasks = scala.collection.mutable.ListBuffer[Task]()
      
      while (rs.next()) {
        val id = rs.getObject("id").toString
        val priority = rs.getInt("priority")
        val dueDateObj = rs.getDate("due_date")
        val dueDate = if (dueDateObj != null) Some(dueDateObj.toLocalDate) else None
        val status = rs.getString("status")
        val estimateHours = rs.getInt("estimate_hours")
        val complexity = rs.getInt("complexity")
        
        tasks += Task(id, estimateHours, priority, dueDate, status, complexity, Nil, Some(organizationId))
      }
      
      rs.close()
      stmt.close()
      tasks.toList
    } finally {
      conn.close()
    }
  }
  
  def getAverageCompletionTime(complexity: Int, priority: Int, userId: Option[String]): Option[Double] = {
    val conn = getConnection
    try {
      val query = userId match {
        case Some(uid) =>
          """SELECT AVG(EXTRACT(EPOCH FROM (te_completed.created_at - te_created.created_at)) / 3600.0) as avg_hours
             FROM tasks t
             JOIN task_events te_created ON t.id = te_created.task_id AND te_created.event_type = 'created'
             JOIN task_events te_completed ON t.id = te_completed.task_id AND te_completed.event_type = 'completed'
             WHERE COALESCE(t.complexity, 3) = ? AND t.priority = ? AND te_completed.actor_user_id = ?
             AND te_completed.created_at >= NOW() - INTERVAL '90 days'"""
        case None =>
          """SELECT AVG(EXTRACT(EPOCH FROM (te_completed.created_at - te_created.created_at)) / 3600.0) as avg_hours
             FROM tasks t
             JOIN task_events te_created ON t.id = te_created.task_id AND te_created.event_type = 'created'
             JOIN task_events te_completed ON t.id = te_completed.task_id AND te_completed.event_type = 'completed'
             WHERE COALESCE(t.complexity, 3) = ? AND t.priority = ?
             AND te_completed.created_at >= NOW() - INTERVAL '90 days'"""
      }
      
      val stmt = conn.prepareStatement(query)
      stmt.setInt(1, complexity)
      stmt.setInt(2, priority)
      userId.foreach(uid => stmt.setObject(3, UUID.fromString(uid)))
      
      val rs = stmt.executeQuery()
      if (rs.next() && !rs.wasNull()) {
        val avg = rs.getDouble("avg_hours")
        if (avg > 0) Some(avg) else None
      } else {
        None
      }
    } catch {
      case e: Exception =>
        println(s"Warning: Could not get average completion time: ${e.getMessage}")
        None
    } finally {
      conn.close()
    }
  }
  
  def saveEstimationAccuracy(
    taskId: String,
    estimatedHours: Int,
    actualHours: Double,
    accuracyRatio: Double,
    userId: Option[String]
  ): Unit = {
    val conn = getConnection
    try {
      // Note: estimation_accuracy table should be created via Rails migration
      // This will fail gracefully if table doesn't exist yet
      val stmt = conn.prepareStatement(
        """INSERT INTO estimation_accuracy 
           (task_id, estimated_hours, actual_hours, accuracy_ratio, user_id)
           VALUES (?, ?, ?, ?, ?)"""
      )
      stmt.setObject(1, UUID.fromString(taskId))
      stmt.setInt(2, estimatedHours)
      stmt.setDouble(3, actualHours)
      stmt.setDouble(4, accuracyRatio)
      userId match {
        case Some(uid) => stmt.setObject(5, UUID.fromString(uid))
        case None => stmt.setObject(5, null)
      }
      stmt.executeUpdate()
      stmt.close()
    } catch {
      case e: Exception =>
        println(s"Warning: Could not save estimation accuracy: ${e.getMessage}")
    } finally {
      conn.close()
    }
  }
  
  def getEstimationStats(userId: Option[String], organizationId: Option[String]): EstimationStats = {
    val conn = getConnection
    try {
      val query = (userId, organizationId) match {
        case (Some(uid), _) =>
          """SELECT 
               COUNT(*) as total_tasks,
               AVG(accuracy_ratio) as avg_accuracy,
               AVG(CASE WHEN accuracy_ratio < 1.0 THEN (1.0 - accuracy_ratio) * 100 ELSE 0 END) as avg_overestimate,
               AVG(CASE WHEN accuracy_ratio > 1.0 THEN (accuracy_ratio - 1.0) * 100 ELSE 0 END) as avg_underestimate
             FROM estimation_accuracy
             WHERE user_id = ?"""
        case (_, Some(orgId)) =>
          """SELECT 
               COUNT(*) as total_tasks,
               AVG(ea.accuracy_ratio) as avg_accuracy,
               AVG(CASE WHEN ea.accuracy_ratio < 1.0 THEN (1.0 - ea.accuracy_ratio) * 100 ELSE 0 END) as avg_overestimate,
               AVG(CASE WHEN ea.accuracy_ratio > 1.0 THEN (ea.accuracy_ratio - 1.0) * 100 ELSE 0 END) as avg_underestimate
             FROM estimation_accuracy ea
             JOIN tasks t ON ea.task_id = t.id
             JOIN projects p ON t.project_id = p.id
             WHERE p.organization_id = ?"""
        case _ =>
          """SELECT 
               COUNT(*) as total_tasks,
               AVG(accuracy_ratio) as avg_accuracy,
               AVG(CASE WHEN accuracy_ratio < 1.0 THEN (1.0 - accuracy_ratio) * 100 ELSE 0 END) as avg_overestimate,
               AVG(CASE WHEN accuracy_ratio > 1.0 THEN (accuracy_ratio - 1.0) * 100 ELSE 0 END) as avg_underestimate
             FROM estimation_accuracy"""
      }
      
      val stmt = conn.prepareStatement(query)
      userId.foreach(uid => stmt.setObject(1, UUID.fromString(uid)))
      organizationId.foreach(oid => stmt.setObject(1, UUID.fromString(oid)))
      
      val rs = stmt.executeQuery()
      if (rs.next()) {
        EstimationStats(
          rs.getInt("total_tasks"),
          Option(rs.getDouble("avg_accuracy")).getOrElse(0.0),
          Option(rs.getDouble("avg_overestimate")).getOrElse(0.0),
          Option(rs.getDouble("avg_underestimate")).getOrElse(0.0)
        )
      } else {
        EstimationStats(0, 0.0, 0.0, 0.0)
      }
    } catch {
      case e: Exception =>
        println(s"Warning: Could not get estimation stats: ${e.getMessage}")
        EstimationStats(0, 0.0, 0.0, 0.0)
    } finally {
      conn.close()
    }
  }
  
  case class EstimationStats(
    totalTasks: Int,
    avgAccuracy: Double,
    avgOverestimate: Double,
    avgUnderestimate: Double
  )
  
  def close(): Unit = {
    dataSource.foreach(_.close())
  }
}

