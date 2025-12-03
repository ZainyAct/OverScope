package com.taskforge.services

import java.time.{LocalDate, LocalDateTime}
import scala.util.Random
import com.taskforge.models.{User, Task, Assignment, Plan}

object ScheduleOptimizer {
  
  def bestPlan(users: List[User], tasks: List[Task]): Plan = {
    val candidates = generatePlans(users, tasks, maxCandidates = 100)
    // Score all plans with task information
    val scoredCandidates = candidates.map(plan => scorePlanWithTasks(plan, tasks, users))
    scoredCandidates.maxBy(_.score)
  }
  
  def generatePlans(users: List[User], tasks: List[Task], maxCandidates: Int = 50): List[Plan] = {
    if (users.isEmpty || tasks.isEmpty) {
      return List(Plan(Nil, 0.0, 0.0, 0.0, List("No users or tasks provided")))
    }
    
    // Strategy 1: Greedy by priority
    val greedyPlan = greedyAssignment(users, tasks)
    
    // Strategy 2: Round-robin
    val roundRobinPlan = roundRobinAssignment(users, tasks)
    
    // Strategy 3: Random variations (simulated annealing approach)
    val randomPlans = (1 to (maxCandidates - 2)).map { _ =>
      randomVariation(users, tasks)
    }.toList
    
    (greedyPlan :: roundRobinPlan :: randomPlans).map(scorePlan)
  }
  
  private def greedyAssignment(users: List[User], tasks: List[Task]): Plan = {
    val sortedTasks = tasks.sortBy(t => (-t.priority, t.dueDate.map(_.toEpochDay).getOrElse(Long.MaxValue)))
    val assignments = scala.collection.mutable.ListBuffer[Assignment]()
    val userLoads = scala.collection.mutable.Map[String, Int]()
    users.foreach(u => userLoads(u.id) = 0)
    
    val today = LocalDate.now()
    
    for (task <- sortedTasks) {
      // Find user with least load who has capacity
      val availableUsers = users.filter { u =>
        userLoads(u.id) + task.estimateHours <= u.capacityHours
      }
      
      if (availableUsers.nonEmpty) {
        val user = availableUsers.minBy(u => userLoads(u.id))
        val startDate = today.plusDays(userLoads(user.id) / 8) // Assuming 8 hours/day
        val completionDate = startDate.plusDays((task.estimateHours / 8.0).ceil.toInt)
        
        assignments += Assignment(user.id, task.id, startDate, completionDate)
        userLoads(user.id) += task.estimateHours
      }
    }
    
    Plan(assignments.toList, 0.0) // Score will be computed later
  }
  
  private def roundRobinAssignment(users: List[User], tasks: List[Task]): Plan = {
    val sortedTasks = tasks.sortBy(t => (-t.priority, t.dueDate.map(_.toEpochDay).getOrElse(Long.MaxValue)))
    val assignments = scala.collection.mutable.ListBuffer[Assignment]()
    val userLoads = scala.collection.mutable.Map[String, Int]()
    users.foreach(u => userLoads(u.id) = 0)
    
    val today = LocalDate.now()
    var userIndex = 0
    
    for (task <- sortedTasks) {
      var assigned = false
      var attempts = 0
      
      while (!assigned && attempts < users.length) {
        val user = users(userIndex % users.length)
        
        if (userLoads(user.id) + task.estimateHours <= user.capacityHours) {
          val startDate = today.plusDays(userLoads(user.id) / 8)
          val completionDate = startDate.plusDays((task.estimateHours / 8.0).ceil.toInt)
          
          assignments += Assignment(user.id, task.id, startDate, completionDate)
          userLoads(user.id) += task.estimateHours
          assigned = true
        }
        
        userIndex += 1
        attempts += 1
      }
    }
    
    Plan(assignments.toList, 0.0)
  }
  
  private def randomVariation(users: List[User], tasks: List[Task]): Plan = {
    val sortedTasks = Random.shuffle(tasks)
    val assignments = scala.collection.mutable.ListBuffer[Assignment]()
    val userLoads = scala.collection.mutable.Map[String, Int]()
    users.foreach(u => userLoads(u.id) = 0)
    
    val today = LocalDate.now()
    
    for (task <- sortedTasks) {
      val availableUsers = users.filter { u =>
        userLoads(u.id) + task.estimateHours <= u.capacityHours
      }
      
      if (availableUsers.nonEmpty) {
        val user = Random.shuffle(availableUsers).head
        val startDate = today.plusDays(userLoads(user.id) / 8)
        val completionDate = startDate.plusDays((task.estimateHours / 8.0).ceil.toInt)
        
        assignments += Assignment(user.id, task.id, startDate, completionDate)
        userLoads(user.id) += task.estimateHours
      }
    }
    
    Plan(assignments.toList, 0.0)
  }
  
  private def scorePlan(plan: Plan): Plan = {
    // Score based on:
    // 1. Minimize lateness (tasks completed after due date)
    // 2. Minimize overload (users exceeding capacity)
    // 3. Maximize priority tasks assigned first
    
    var latenessPenalty = 0.0
    var overloadPenalty = 0.0
    var priorityBonus = 0.0
    
    val userLoads = scala.collection.mutable.Map[String, Int]()
    val taskMap = scala.collection.mutable.Map[String, Task]()
    
    // This is simplified - in production, we'd pass tasks to this function
    // For now, we'll compute based on assignments only
    
    plan.assignments.foreach { assignment =>
      userLoads(assignment.userId) = userLoads.getOrElse(assignment.userId, 0) + 1
      
      // Check if completion date is after due date (if we had task info)
      // For now, we'll use a simplified scoring
    }
    
    // Base score starts at 1.0
    var score = 1.0
    
    // Penalize lateness (simplified - would need task due dates)
    score -= latenessPenalty * 0.5
    
    // Penalize overload
    score -= overloadPenalty * 0.3
    
    // Bonus for assigning high priority tasks
    score += priorityBonus * 0.2
    
    // Ensure score is between 0 and 1
    score = math.max(0.0, math.min(1.0, score))
    
    val explanations = scala.collection.mutable.ListBuffer[String]()
    if (latenessPenalty > 0) {
      explanations += s"${latenessPenalty.toInt} tasks may be late"
    }
    if (overloadPenalty > 0) {
      explanations += s"Some users may be overloaded"
    }
    if (plan.assignments.length == 0) {
      explanations += "No assignments could be made"
    } else {
      explanations += s"Assigned ${plan.assignments.length} tasks"
    }
    
    plan.copy(score = score, explanations = explanations.toList)
  }
  
  // Enhanced scoring with task information
  def scorePlanWithTasks(plan: Plan, tasks: List[Task], users: List[User]): Plan = {
    val taskMap = tasks.map(t => t.id -> t).toMap
    val userMap = users.map(u => u.id -> u).toMap
    
    var latenessPenalty = 0.0
    var overloadPenalty = 0.0
    var priorityScore = 0.0
    var totalPriority = 0
    
    val userLoads = scala.collection.mutable.Map[String, Int]()
    
    plan.assignments.foreach { assignment =>
      taskMap.get(assignment.taskId).foreach { task =>
        userLoads(assignment.userId) = userLoads.getOrElse(assignment.userId, 0) + task.estimateHours
        
        // Check lateness
        task.dueDate.foreach { dueDate =>
          if (assignment.estimatedCompletionDate.isAfter(dueDate)) {
            val daysLate = java.time.temporal.ChronoUnit.DAYS.between(dueDate, assignment.estimatedCompletionDate)
            latenessPenalty += daysLate * task.priority
          }
        }
        
        // Priority bonus (higher priority tasks assigned = better)
        priorityScore += task.priority
        totalPriority += task.priority
      }
    }
    
    // Check overload
    userMap.foreach { case (userId, user) =>
      val load = userLoads.getOrElse(userId, 0)
      if (load > user.capacityHours) {
        val overload = load - user.capacityHours
        overloadPenalty += overload.toDouble / user.capacityHours
      }
    }
    
    // Normalize scores
    val normalizedLateness = if (latenessPenalty > 0) math.min(1.0, latenessPenalty / 100.0) else 0.0
    val normalizedPriority = if (totalPriority > 0) priorityScore / totalPriority else 0.0
    
    // Final score: higher is better
    val score = normalizedPriority * 0.5 - normalizedLateness * 0.3 - overloadPenalty * 0.2
    val finalScore = math.max(0.0, math.min(1.0, score))
    
    val explanations = scala.collection.mutable.ListBuffer[String]()
    if (normalizedLateness > 0) {
      explanations += s"${(normalizedLateness * 100).toInt}% lateness risk"
    }
    if (overloadPenalty > 0) {
      explanations += s"${(overloadPenalty * 100).toInt}% overload risk"
    }
    explanations += s"Priority coverage: ${(normalizedPriority * 100).toInt}%"
    
    plan.copy(
      score = finalScore,
      totalLateness = normalizedLateness,
      totalOverload = overloadPenalty,
      explanations = explanations.toList
    )
  }
}

