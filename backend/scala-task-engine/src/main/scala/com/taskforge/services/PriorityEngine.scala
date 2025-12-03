package com.taskforge.services

import java.time.{LocalDate, LocalDateTime}
import com.taskforge.models.Task

// DSL for priority rules

sealed trait Condition {
  def matches(task: Task): Boolean
}

case class DueWithin(days: Int) extends Condition {
  def matches(task: Task): Boolean = {
    task.dueDate.exists { dueDate =>
      val daysUntil = java.time.temporal.ChronoUnit.DAYS.between(LocalDate.now(), dueDate)
      daysUntil >= 0 && daysUntil <= days
    }
  }
}

case class Overdue() extends Condition {
  def matches(task: Task): Boolean = {
    task.dueDate.exists(_.isBefore(LocalDate.now()))
  }
}

case class MaxComplexity(n: Int) extends Condition {
  def matches(task: Task): Boolean = task.complexity <= n
}

case class MinComplexity(n: Int) extends Condition {
  def matches(task: Task): Boolean = task.complexity >= n
}

case class HasTag(tag: String) extends Condition {
  def matches(task: Task): Boolean = task.tags.contains(tag)
}

case class HasStatus(status: String) extends Condition {
  def matches(task: Task): Boolean = task.status == status
}

case class MinPriority(n: Int) extends Condition {
  def matches(task: Task): Boolean = task.priority >= n
}

case class MaxPriority(n: Int) extends Condition {
  def matches(task: Task): Boolean = task.priority <= n
}

case class And(conditions: Condition*) extends Condition {
  def matches(task: Task): Boolean = conditions.forall(_.matches(task))
}

case class Or(conditions: Condition*) extends Condition {
  def matches(task: Task): Boolean = conditions.exists(_.matches(task))
}

case class Not(condition: Condition) extends Condition {
  def matches(task: Task): Boolean = !condition.matches(task)
}

// Effects

sealed trait Effect {
  def apply(task: Task, currentScore: Double): (Double, String)
}

case class Boost(factor: Double) extends Effect {
  def apply(task: Task, currentScore: Double): (Double, String) = {
    val newScore = math.min(1.0, currentScore * (1.0 + factor))
    (newScore, s"Boosted by ${(factor * 100).toInt}%")
  }
}

case class Penalty(factor: Double) extends Effect {
  def apply(task: Task, currentScore: Double): (Double, String) = {
    val newScore = math.max(0.0, currentScore * (1.0 - factor))
    (newScore, s"Penalized by ${(factor * 100).toInt}%")
  }
}

case class SetScore(score: Double) extends Effect {
  def apply(task: Task, currentScore: Double): (Double, String) = {
    (math.max(0.0, math.min(1.0, score)), s"Score set to ${score}")
  }
}

case class AddScore(amount: Double) extends Effect {
  def apply(task: Task, currentScore: Double): (Double, String) = {
    val newScore = math.min(1.0, currentScore + amount)
    (newScore, s"Added ${amount} to score")
  }
}

case class SubtractScore(amount: Double) extends Effect {
  def apply(task: Task, currentScore: Double): (Double, String) = {
    val newScore = math.max(0.0, currentScore - amount)
    (newScore, s"Subtracted ${amount} from score")
  }
}

// Rule definition

case class Rule(
  name: String,
  condition: Condition,
  effect: Effect,
  priority: Int = 0 // Higher priority rules apply first
)

case class PriorityResult(
  score: Double,
  explanations: List[String]
)

object PriorityEngine {
  
  // Default rules
  val defaultRules: List[Rule] = List(
    Rule(
      "Overdue boost",
      Overdue(),
      Boost(0.3),
      priority = 10
    ),
    Rule(
      "Due soon boost",
      DueWithin(3),
      Boost(0.2),
      priority = 9
    ),
    Rule(
      "High priority boost",
      MinPriority(4),
      Boost(0.15),
      priority = 8
    ),
    Rule(
      "Blocked penalty",
      HasStatus("blocked"),
      Penalty(0.5),
      priority = 7
    ),
    Rule(
      "Low complexity bonus",
      And(MaxComplexity(2), MinPriority(3)),
      Boost(0.1),
      priority = 6
    ),
    Rule(
      "VIP client boost",
      HasTag("vip"),
      Boost(0.25),
      priority = 5
    )
  )
  
  private var rules: List[Rule] = defaultRules
  
  def setRules(newRules: List[Rule]): Unit = {
    rules = newRules.sortBy(-_.priority) // Sort by priority descending
  }
  
  def addRule(rule: Rule): Unit = {
    rules = (rule :: rules).sortBy(-_.priority)
  }
  
  def calculatePriority(task: Task): PriorityResult = {
    // Start with base score from priority (1-5 normalized to 0-1)
    var score = task.priority / 5.0
    
    // Adjust for status
    task.status match {
      case "completed" => return PriorityResult(0.0, List("Task is completed"))
      case "in_progress" => score = score * 0.7
      case _ => // open - no adjustment
    }
    
    val explanations = scala.collection.mutable.ListBuffer[String]()
    explanations += s"Base score: ${(score * 100).toInt}% (priority ${task.priority})"
    
    // Apply rules in priority order
    for (rule <- rules) {
      if (rule.condition.matches(task)) {
        val (newScore, explanation) = rule.effect.apply(task, score)
        if (newScore != score) {
          explanations += s"${rule.name}: $explanation"
          score = newScore
        }
      }
    }
    
    // Ensure score is in valid range
    score = math.max(0.0, math.min(1.0, score))
    
    PriorityResult(score, explanations.toList)
  }
  
  def explainPriority(task: Task): String = {
    val result = calculatePriority(task)
    s"Priority Score: ${(result.score * 100).toInt}%\n" +
    result.explanations.mkString("\n")
  }
  
  // Helper methods for building rules from JSON/YAML
  def parseCondition(json: Map[String, Any]): Condition = {
    json.get("type").map(_.toString) match {
      case Some("due_within") => DueWithin(json("days").toString.toInt)
      case Some("overdue") => Overdue()
      case Some("max_complexity") => MaxComplexity(json("value").toString.toInt)
      case Some("min_complexity") => MinComplexity(json("value").toString.toInt)
      case Some("has_tag") => HasTag(json("value").toString)
      case Some("has_status") => HasStatus(json("value").toString)
      case Some("min_priority") => MinPriority(json("value").toString.toInt)
      case Some("max_priority") => MaxPriority(json("value").toString.toInt)
      case Some("and") => And(json("conditions").asInstanceOf[List[Map[String, Any]]].map(parseCondition): _*)
      case Some("or") => Or(json("conditions").asInstanceOf[List[Map[String, Any]]].map(parseCondition): _*)
      case Some("not") => Not(parseCondition(json("condition").asInstanceOf[Map[String, Any]]))
      case _ => throw new IllegalArgumentException(s"Unknown condition type: ${json.get("type")}")
    }
  }
  
  def parseEffect(json: Map[String, Any]): Effect = {
    json.get("type").map(_.toString) match {
      case Some("boost") => Boost(json("factor").toString.toDouble)
      case Some("penalty") => Penalty(json("factor").toString.toDouble)
      case Some("set_score") => SetScore(json("value").toString.toDouble)
      case Some("add_score") => AddScore(json("value").toString.toDouble)
      case Some("subtract_score") => SubtractScore(json("value").toString.toDouble)
      case _ => throw new IllegalArgumentException(s"Unknown effect type: ${json.get("type")}")
    }
  }
}

