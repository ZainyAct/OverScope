package com.taskforge.services

import java.time.LocalDate
import com.taskforge.models.Task
import com.taskforge.db.Database
import com.taskforge.db.Database.EstimationStats

object EstimationService {
  
  // Complexity-based base estimates (hours)
  private val complexityBaseHours = Map(
    1 -> 2,   // Very Simple
    2 -> 4,   // Simple
    3 -> 8,   // Medium
    4 -> 16,  // Complex
    5 -> 32   // Very Complex
  )
  
  /**
   * Estimate task hours using multiple strategies and return the best estimate
   */
  def estimateTask(task: Task, userId: Option[String] = None): Int = {
    val strategies = List(
      historicalEstimate(task, userId),
      complexityBasedEstimate(task),
      priorityBasedEstimate(task),
      userSpecificEstimate(task, userId)
    ).flatten
    
    if (strategies.nonEmpty) {
      // Use weighted average, giving more weight to historical data
      val weights = List(0.4, 0.3, 0.2, 0.1)
      val weightedSum = strategies.zip(weights).map { case (est, weight) => est * weight }.sum
      val totalWeight = weights.take(strategies.length).sum
      (weightedSum / totalWeight).toInt.max(1)
    } else {
      // Fallback to complexity-based
      complexityBasedEstimate(task).getOrElse(8)
    }
  }
  
  /**
   * Strategy 1: Historical average for similar tasks
   */
  def historicalEstimate(task: Task, userId: Option[String]): Option[Int] = {
    try {
      val avgHours = Database.getAverageCompletionTime(
        complexity = task.complexity,
        priority = task.priority,
        userId = userId
      )
      avgHours.map(_.toInt)
    } catch {
      case _: Exception => None
    }
  }
  
  /**
   * Strategy 2: Complexity-based estimation
   */
  def complexityBasedEstimate(task: Task): Option[Int] = {
    complexityBaseHours.get(task.complexity)
  }
  
  /**
   * Strategy 3: Priority-adjusted estimation
   * Higher priority tasks might take longer due to complexity
   */
  private def priorityBasedEstimate(task: Task): Option[Int] = {
    val base = complexityBasedEstimate(task).getOrElse(8)
    // Adjust based on priority (higher priority = potentially more complex)
    val multiplier = task.priority match {
      case 5 => 1.2  // High priority might be more complex
      case 4 => 1.1
      case 3 => 1.0
      case 2 => 0.9
      case 1 => 0.8
      case _ => 1.0
    }
    Some((base * multiplier).toInt)
  }
  
  /**
   * Strategy 4: User-specific adjustment
   * Adjust based on user's historical performance
   */
  private def userSpecificEstimate(task: Task, userId: Option[String]): Option[Int] = {
    userId.flatMap { uid =>
      try {
        val userMetrics = Database.fetchUserMetrics(uid)
        userMetrics.map { metrics =>
          val base = complexityBasedEstimate(task).getOrElse(8)
          // If user's avg completion is different from baseline (8h), adjust
          val userMultiplier = if (metrics.avgCompletionHours > 0) {
            metrics.avgCompletionHours / 8.0
          } else {
            1.0
          }
          (base * userMultiplier).toInt.max(1)
        }
      } catch {
        case _: Exception => None
      }
    }
  }
  
  /**
   * Track estimation accuracy when a task is completed
   */
  def trackAccuracy(taskId: String, estimatedHours: Int, actualHours: Double, userId: Option[String]): Unit = {
    try {
      val accuracyRatio = if (estimatedHours > 0) {
        actualHours / estimatedHours
      } else {
        1.0
      }
      
      Database.saveEstimationAccuracy(
        taskId = taskId,
        estimatedHours = estimatedHours,
        actualHours = actualHours,
        accuracyRatio = accuracyRatio,
        userId = userId
      )
    } catch {
      case e: Exception =>
        println(s"Warning: Could not track estimation accuracy: ${e.getMessage}")
    }
  }
  
  /**
   * Get estimation statistics for a user or organization
   */
  def getEstimationStats(userId: Option[String], organizationId: Option[String]): EstimationStats = {
    try {
      Database.getEstimationStats(userId, organizationId)
    } catch {
      case e: Exception =>
        println(s"Warning: Could not get estimation stats: ${e.getMessage}")
        EstimationStats(0, 0.0, 0.0, 0.0)
    }
  }
}

