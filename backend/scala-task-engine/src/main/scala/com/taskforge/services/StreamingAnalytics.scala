package com.taskforge.services

import akka.actor.typed.ActorSystem
import akka.stream.scaladsl.{Sink, Source}
import akka.stream.{Materializer, OverflowStrategy, ThrottleMode}
import scala.concurrent.duration._
import scala.concurrent.{ExecutionContext, Future}
import com.taskforge.db.Database
import com.taskforge.models.{TaskEvent, UserMetrics, OrganizationMetrics}
import com.taskforge.services.EstimationService
import java.time.{LocalDate, LocalDateTime}
import java.util.UUID
import scala.collection.mutable

object StreamingAnalytics {
  
  case class AnalyticsState(
    lastProcessedId: Long,
    userMetrics: mutable.Map[String, UserMetrics],
    orgMetrics: mutable.Map[String, OrganizationMetrics],
    taskCompletionTimes: mutable.Map[String, List[Double]] // taskId -> list of completion times
  )
  
  private var state = AnalyticsState(
    lastProcessedId = 0L,
    userMetrics = mutable.Map.empty,
    orgMetrics = mutable.Map.empty,
    taskCompletionTimes = mutable.Map.empty
  )
  
  def startStream(system: ActorSystem[_], materializer: Materializer): Unit = {
    implicit val ec: ExecutionContext = system.executionContext
    implicit val mat: Materializer = materializer
    
    // Initialize last processed ID (use timestamp)
    try {
      state = state.copy(lastProcessedId = Database.getMaxTaskEventId)
    } catch {
      case e: Exception =>
        println(s"Warning: Could not get max task event ID: ${e.getMessage}")
        state = state.copy(lastProcessedId = 0L)
    }
    
    // Create a stream that polls for new events
    val eventStream = Source.unfoldAsync(state.lastProcessedId) { lastId =>
      Future {
        try {
          val events = Database.fetchNewTaskEvents(lastId, limit = 1000)
          if (events.nonEmpty) {
            // Use timestamp-based ID for tracking
            val newLastId = events.map(e => e.createdAt.toEpochSecond(java.time.ZoneOffset.UTC)).max
            Some((newLastId, events))
          } else {
            Some((lastId, Nil))
          }
        } catch {
          case e: Exception =>
            println(s"Error fetching events: ${e.getMessage}")
            Some((lastId, Nil))
        }
      }
    }
    .throttle(1, 5.seconds, 1, ThrottleMode.Shaping) // Poll every 5 seconds
    .mapConcat(identity) // Flatten list of events
    .async
    .runWith(Sink.foreach(processEvent)) // Process each event
    
    println("Streaming analytics started")
  }
  
  private def processEvent(event: TaskEvent): Unit = {
    event.eventType match {
      case "created" => handleCreated(event)
      case "started" => handleStarted(event)
      case "completed" => handleCompleted(event)
      case "reassigned" => handleReassigned(event)
      case _ => // Unknown event type
    }
    
    // Update metrics periodically
    updateMetrics()
  }
  
  private def handleCreated(event: TaskEvent): Unit = {
    // Track task creation
    // Could update org metrics for tasks created
  }
  
  private def handleStarted(event: TaskEvent): Unit = {
    // Track when task was started
    // Could calculate time to start
  }
  
  private def handleCompleted(event: TaskEvent): Unit = {
    // Calculate completion time from actual task events
    Database.fetchTaskCreationAndCompletionTimes(event.taskId).foreach { case (createdAt, completedAt) =>
      val completionTimeHours = java.time.Duration.between(createdAt, completedAt).toHours.toDouble
      event.actorUserId.foreach { userId =>
        updateUserMetrics(userId, completionTimeHours)
      }
      
      // Update organization metrics
      updateOrganizationMetricsForTask(event.taskId, completionTimeHours)
      
      // Track estimation accuracy
      try {
        val conn = com.taskforge.db.Database.getConnection
        try {
          val stmt = conn.prepareStatement(
            "SELECT estimate_hours FROM tasks WHERE id = ?"
          )
          stmt.setObject(1, java.util.UUID.fromString(event.taskId))
          val rs = stmt.executeQuery()
          if (rs.next()) {
            val estimatedHours = rs.getInt("estimate_hours")
            if (estimatedHours > 0) {
              EstimationService.trackAccuracy(
                event.taskId,
                estimatedHours,
                completionTimeHours,
                event.actorUserId
              )
            }
          }
          rs.close()
          stmt.close()
        } finally {
          conn.close()
        }
      } catch {
        case e: Exception => // Ignore errors
      }
    }
  }
  
  private def updateOrganizationMetricsForTask(taskId: String, completionTimeHours: Double): Unit = {
    // Fetch organization ID from task
    try {
      val conn = com.taskforge.db.Database.getConnection
      try {
        val stmt = conn.prepareStatement(
          """SELECT p.organization_id 
             FROM tasks t
             JOIN projects p ON t.project_id = p.id
             WHERE t.id = ?"""
        )
        stmt.setObject(1, java.util.UUID.fromString(taskId))
        val rs = stmt.executeQuery()
        if (rs.next()) {
          val orgId = rs.getObject("organization_id").toString
          val today = LocalDate.now()
          
          // Get or create org metrics
          val metrics = state.orgMetrics.getOrElse(
            orgId,
            OrganizationMetrics(orgId, 0.0, 0, 0, 0, today)
          )
          
          // Update metrics (simplified - in production, aggregate properly)
          state.orgMetrics(orgId) = metrics.copy(
            avgLeadTimeHours = (metrics.avgLeadTimeHours + completionTimeHours) / 2.0,
            tasksCompleted = metrics.tasksCompleted + 1
          )
        }
        rs.close()
        stmt.close()
      } finally {
        conn.close()
      }
    } catch {
      case e: Exception => // Ignore errors
    }
  }
  
  private def handleReassigned(event: TaskEvent): Unit = {
    // Track reassignments
    // Could indicate workload issues
  }
  
  private def updateUserMetrics(userId: String, completionTime: Double): Unit = {
    val current = state.userMetrics.getOrElse(
      userId,
      UserMetrics(userId, 0.0, 0, 0.0, 40, 0.0)
    )
    
    // Update average completion time (simple moving average)
    val newAvg = if (current.tasksCompletedLast30Days > 0) {
      (current.avgCompletionHours * current.tasksCompletedLast30Days + completionTime) / 
      (current.tasksCompletedLast30Days + 1)
    } else {
      completionTime
    }
    
    val updated = current.copy(
      avgCompletionHours = newAvg,
      tasksCompletedLast30Days = current.tasksCompletedLast30Days + 1
    )
    
    state.userMetrics(userId) = updated
    
    // Calculate pressure score
    val pressureScore = calculatePressureScore(updated)
    state.userMetrics(userId) = updated.copy(pressureScore = pressureScore)
    
    // Persist to database
    Database.upsertUserMetrics(state.userMetrics(userId))
  }
  
  private def calculatePressureScore(metrics: UserMetrics): Double = {
    // Pressure score based on:
    // 1. Current load vs capacity
    // 2. Recent completion rate
    // 3. Average completion time trends
    
    val loadRatio = if (metrics.capacityHours > 0) {
      metrics.currentLoadHours / metrics.capacityHours
    } else {
      0.0
    }
    
    // Normalize to 0-1 scale
    math.min(1.0, math.max(0.0, loadRatio * 0.7 + (if (metrics.tasksCompletedLast30Days > 20) 0.3 else 0.0)))
  }
  
  private def updateMetrics(): Unit = {
    // Periodically update organization metrics
    // In production, this would be more sophisticated
    state.orgMetrics.foreach { case (orgId, metrics) =>
      Database.upsertOrganizationMetrics(metrics)
    }
  }
  
  def getUserMetrics(userId: String): Option[UserMetrics] = {
    state.userMetrics.get(userId)
  }
  
  def getOrganizationMetrics(organizationId: String): Option[OrganizationMetrics] = {
    state.orgMetrics.get(organizationId)
  }
  
  def getPressureAlerts(threshold: Double = 0.7): List[UserMetrics] = {
    state.userMetrics.values.filter(_.pressureScore >= threshold).toList
  }
  
  // Fire alarm: detect spike in overdue tasks
  def checkOverdueTaskSpike(organizationId: String, threshold: Int = 5, hoursWindow: Int = 24): Option[String] = {
    val overdueCount = Database.fetchOverdueTasksCount(organizationId, hoursWindow)
    if (overdueCount >= threshold) {
      Some(s"ALERT: $overdueCount overdue tasks detected in the last $hoursWindow hours (threshold: $threshold)")
    } else {
      None
    }
  }
  
  def getUserMetricsFromDB(userId: String): Option[UserMetrics] = {
    Database.fetchUserMetrics(userId).orElse(state.userMetrics.get(userId))
  }
}

