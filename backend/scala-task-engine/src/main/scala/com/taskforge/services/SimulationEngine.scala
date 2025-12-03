package com.taskforge.services

import java.time.{LocalDate, LocalDateTime}
import scala.util.Random
import com.taskforge.models.{User, Task, Assignment, SimConfig, SimOutcome, Plan}

object SimulationEngine {
  
  case class SimulationState(
    users: List[User],
    tasks: List[Task],
    assignments: List[Assignment],
    currentWeek: Int,
    completedTasks: Set[String],
    userLoads: Map[String, Double] // userId -> hours worked
  )
  
  def runSimulation(
    initialUsers: List[User],
    initialTasks: List[Task],
    config: SimConfig
  ): SimOutcome = {
    // Apply configuration changes
    val users = if (config.newUserCapacity.isDefined) {
      val newUser = User(s"new_user_${System.currentTimeMillis()}", config.newUserCapacity.get)
      initialUsers :+ newUser
    } else {
      initialUsers
    }
    
    val tasks = if (config.delayProjectWeeks.isDefined) {
      initialTasks.map { task =>
        task.copy(
          dueDate = task.dueDate.map(_.plusWeeks(config.delayProjectWeeks.get))
        )
      }
    } else {
      initialTasks
    }
    
    val filteredTasks = if (config.dropLowPriority) {
      tasks.filter(_.priority >= 3)
    } else {
      tasks
    }
    
    // Initialize state
    var state = SimulationState(
      users = users,
      tasks = filteredTasks,
      assignments = Nil,
      currentWeek = 0,
      completedTasks = Set.empty,
      userLoads = users.map(u => u.id -> 0.0).toMap
    )
    
    // Simulate week by week
    for (week <- 1 to config.weeks) {
      state = simulateWeek(state, week)
    }
    
    // Calculate outcomes
    val missedDeadlines = calculateMissedDeadlines(state)
    val totalHoursWorked = state.userLoads.values.sum
    
    SimOutcome(
      completed = state.completedTasks.size,
      missedDeadlines = missedDeadlines,
      userLoad = state.userLoads,
      totalHoursWorked = totalHoursWorked
    )
  }
  
  private def simulateWeek(state: SimulationState, week: Int): SimulationState = {
    val remainingTasks = state.tasks.filterNot(task => state.completedTasks.contains(task.id))
    
    // Generate assignments for this week using optimizer
    val plan = ScheduleOptimizer.bestPlan(state.users, remainingTasks)
    
    // Process assignments for this week
    val weekStart = LocalDate.now().plusWeeks(week - 1)
    val weekEnd = weekStart.plusDays(7)
    
    var newCompleted = state.completedTasks
    var newUserLoads = state.userLoads
    var newAssignments = state.assignments
    
    // Process each assignment
    for (assignment <- plan.assignments) {
      val user = state.users.find(_.id == assignment.userId).get
      val task = remainingTasks.find(_.id == assignment.taskId).get
      
      // Check if task can be completed this week
      val hoursAvailable = user.capacityHours - newUserLoads.getOrElse(user.id, 0.0)
      val hoursNeeded = task.estimateHours
      
      if (hoursNeeded <= hoursAvailable && assignment.startDate.isBefore(weekEnd)) {
        // Task can be completed
        newCompleted = newCompleted + task.id
        newUserLoads = newUserLoads.updated(user.id, newUserLoads.getOrElse(user.id, 0.0) + hoursNeeded)
        newAssignments = assignment :: newAssignments
      } else if (hoursNeeded > 0 && hoursAvailable > 0) {
        // Partial progress
        val hoursWorked = math.min(hoursNeeded, hoursAvailable)
        newUserLoads = newUserLoads.updated(user.id, newUserLoads.getOrElse(user.id, 0.0) + hoursWorked)
        // Task not completed, will continue next week
      }
    }
    
    state.copy(
      assignments = newAssignments,
      currentWeek = week,
      completedTasks = newCompleted,
      userLoads = newUserLoads
    )
  }
  
  private def calculateMissedDeadlines(state: SimulationState): Int = {
    val today = LocalDate.now()
    val simulationEnd = today.plusWeeks(state.currentWeek)
    
    state.tasks.count { task =>
      task.dueDate.exists { dueDate =>
        !state.completedTasks.contains(task.id) && dueDate.isBefore(simulationEnd)
      }
    }
  }
  
  def compareScenarios(
    baseUsers: List[User],
    baseTasks: List[Task],
    scenarios: List[(String, SimConfig)]
  ): Map[String, SimOutcome] = {
    scenarios.map { case (name, config) =>
      name -> runSimulation(baseUsers, baseTasks, config)
    }.toMap
  }
  
  // Monte Carlo simulation for uncertainty
  def monteCarloSimulation(
    users: List[User],
    tasks: List[Task],
    config: SimConfig,
    iterations: Int = 100
  ): SimOutcome = {
    // Add randomness to estimates
    val outcomes = (1 to iterations).map { _ =>
      val randomizedTasks = tasks.map { task =>
        // Add ±20% variance to estimates
        val variance = Random.nextDouble() * 0.4 - 0.2 // -0.2 to +0.2
        val newEstimate = (task.estimateHours * (1.0 + variance)).toInt.max(1)
        task.copy(estimateHours = newEstimate)
      }
      runSimulation(users, randomizedTasks, config)
    }
    
    // Average the outcomes
    val avgCompleted = (outcomes.map(_.completed).sum.toDouble / iterations).toInt
    val avgMissed = (outcomes.map(_.missedDeadlines).sum.toDouble / iterations).toInt
    val avgHours = outcomes.map(_.totalHoursWorked).sum / iterations
    
    // Average user loads
    val allUserLoads = outcomes.flatMap(_.userLoad.toList)
    val avgUserLoads = allUserLoads
      .groupBy(_._1)
      .map { case (userId, loads) =>
        userId -> loads.map(_._2).sum / loads.length
      }
    
    SimOutcome(avgCompleted, avgMissed, avgUserLoads, avgHours)
  }
}

