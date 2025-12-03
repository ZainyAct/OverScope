package com.taskforge.services

import java.time.{LocalDate, LocalDateTime}
import com.taskforge.models.{User, Task, ForecastResult, UserMetrics}
import com.taskforge.services.StreamingAnalytics
import com.taskforge.db.Database
import scala.collection.mutable

object CapacityForecaster {
  
  case class HistoricalData(
    userId: String,
    weeklyThroughput: List[Double], // Hours completed per week
    avgCompletionTime: Double,
    tasksCompleted: Int
  )
  
  def forecast(
    users: List[User],
    upcomingTasks: List[Task],
    historicalData: Map[String, HistoricalData]
  ): List[ForecastResult] = {
    // If historical data is empty, fetch from database
    val enrichedHistoricalData = if (historicalData.isEmpty) {
      users.map { user =>
        user.id -> Database.fetchHistoricalDataForUser(user.id)
      }.toMap
    } else {
      historicalData
    }
    
    users.map { user =>
      forecastUser(user, upcomingTasks, enrichedHistoricalData.get(user.id))
    }
  }
  
  private def forecastUser(
    user: User,
    upcomingTasks: List[Task],
    historical: Option[HistoricalData]
  ): ForecastResult = {
    // Get user's current metrics if available
    val metrics = StreamingAnalytics.getUserMetrics(user.id)
    
    // Calculate predicted load
    val userTasks = upcomingTasks.filter(_.id.startsWith(user.id)) // Simplified - in production, use assignments
    val predictedHours = userTasks.map(_.estimateHours).sum
    
    // Get historical throughput
    val avgWeeklyThroughput = historical match {
      case Some(data) if data.weeklyThroughput.nonEmpty =>
        data.weeklyThroughput.sum / data.weeklyThroughput.length
      case _ =>
        // Default: assume user completes 80% of capacity
        user.capacityHours * 0.8
    }
    
    // Predict weeks needed
    val weeksNeeded = if (avgWeeklyThroughput > 0) {
      predictedHours / avgWeeklyThroughput
    } else {
      predictedHours / user.capacityHours
    }
    
    // Calculate load percentage
    val loadPercent = (predictedHours / user.capacityHours) * 100.0
    
    // Determine risk level
    val (risk, reason) = if (loadPercent > 120) {
      ("high", s"${loadPercent.toInt}% of typical capacity - severe overload risk")
    } else if (loadPercent > 100) {
      ("high", s"${loadPercent.toInt}% of typical capacity - overload likely")
    } else if (loadPercent > 80) {
      ("medium", s"${loadPercent.toInt}% of typical capacity - approaching limit")
    } else {
      ("low", s"${loadPercent.toInt}% of typical capacity - manageable")
    }
    
    // Predict missed deadlines
    val missedDeadlines = predictMissedDeadlines(user, userTasks, avgWeeklyThroughput)
    
    ForecastResult(user.id, risk, reason, loadPercent, missedDeadlines)
  }
  
  private def predictMissedDeadlines(
    user: User,
    tasks: List[Task],
    weeklyThroughput: Double
  ): Int = {
    val today = LocalDate.now()
    var currentWeek = 0
    var hoursRemaining = tasks.map(_.estimateHours).sum
    var missedCount = 0
    
    val sortedTasks = tasks.sortBy(_.dueDate.map(_.toEpochDay).getOrElse(Long.MaxValue))
    
    for (task <- sortedTasks) {
      // Calculate when this task would be completed
      val weeksToComplete = if (weeklyThroughput > 0) {
        hoursRemaining / weeklyThroughput
      } else {
        hoursRemaining / user.capacityHours
      }
      
      val completionDate = today.plusWeeks(weeksToComplete.toInt)
      
      // Check if deadline would be missed
      task.dueDate.foreach { dueDate =>
        if (completionDate.isAfter(dueDate)) {
          missedCount += 1
        }
      }
      
      hoursRemaining -= task.estimateHours
    }
    
    missedCount
  }
  
  def detectBurnoutRisk(users: List[User], threshold: Double = 0.8): List[ForecastResult] = {
    users.flatMap { user =>
      StreamingAnalytics.getUserMetrics(user.id).map { metrics =>
        val pressureScore = metrics.pressureScore
        val loadRatio = metrics.currentLoadHours / metrics.capacityHours
        
        val (risk, reason) = if (pressureScore >= threshold || loadRatio >= 1.2) {
          ("high", s"Pressure score: ${(pressureScore * 100).toInt}%, Load: ${(loadRatio * 100).toInt}%")
        } else if (pressureScore >= 0.6 || loadRatio >= 1.0) {
          ("medium", s"Pressure score: ${(pressureScore * 100).toInt}%, Load: ${(loadRatio * 100).toInt}%")
        } else {
          ("low", s"Pressure score: ${(pressureScore * 100).toInt}%, Load: ${(loadRatio * 100).toInt}%")
        }
        
        ForecastResult(user.id, risk, reason, loadRatio * 100, 0)
      }
    }
  }
  
  // Simple linear regression for trend analysis
  def calculateTrend(weeklyData: List[Double]): Double = {
    if (weeklyData.length < 2) return 0.0
    
    val n = weeklyData.length
    val x = (0 until n).map(_.toDouble).toList
    val y = weeklyData
    
    val xMean = x.sum / n
    val yMean = y.sum / n
    
    val numerator = x.zip(y).map { case (xi, yi) => (xi - xMean) * (yi - yMean) }.sum
    val denominator = x.map(xi => math.pow(xi - xMean, 2)).sum
    
    if (denominator == 0) 0.0 else numerator / denominator
  }
  
  def predictFutureCapacity(
    user: User,
    historical: HistoricalData,
    weeksAhead: Int = 4
  ): Double = {
    val trend = calculateTrend(historical.weeklyThroughput)
    val currentThroughput = historical.weeklyThroughput.lastOption.getOrElse(user.capacityHours * 0.8)
    
    // Predict future throughput based on trend
    val predictedThroughput = currentThroughput + (trend * weeksAhead)
    
    // Cap at user's capacity
    math.min(predictedThroughput, user.capacityHours)
  }
}

