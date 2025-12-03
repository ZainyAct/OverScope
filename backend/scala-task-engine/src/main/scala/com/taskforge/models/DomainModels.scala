package com.taskforge.models

import java.time.{LocalDate, LocalDateTime}
import spray.json.{DefaultJsonProtocol, JsonFormat, RootJsonFormat}
import DefaultJsonProtocol._

// Domain models for the task engine

case class User(
  id: String,
  capacityHours: Int,
  skills: List[String] = Nil
)

case class Task(
  id: String,
  estimateHours: Int,
  priority: Int,
  dueDate: Option[LocalDate],
  status: String = "open",
  complexity: Int = 3,
  tags: List[String] = Nil,
  organizationId: Option[String] = None
)

case class Assignment(
  userId: String,
  taskId: String,
  startDate: LocalDate,
  estimatedCompletionDate: LocalDate
)

case class Plan(
  assignments: List[Assignment],
  score: Double,
  totalLateness: Double = 0.0,
  totalOverload: Double = 0.0,
  explanations: List[String] = Nil
)

case class TaskEvent(
  id: String,
  taskId: String,
  eventType: String, // "created", "started", "completed", "reassigned"
  actorUserId: Option[String],
  createdAt: LocalDateTime,
  metadata: Map[String, String] = Map.empty
)

case class UserMetrics(
  userId: String,
  avgCompletionHours: Double,
  tasksCompletedLast30Days: Int,
  currentLoadHours: Double,
  capacityHours: Double,
  pressureScore: Double // 0-1, higher = more pressure
)

case class OrganizationMetrics(
  organizationId: String,
  avgLeadTimeHours: Double,
  tasksCompleted: Int,
  tasksCreated: Int,
  overdueTasksCount: Int,
  date: LocalDate
)

case class ForecastResult(
  userId: String,
  risk: String, // "low", "medium", "high"
  reason: String,
  predictedLoadPercent: Double,
  predictedMissedDeadlines: Int
)

case class SimConfig(
  weeks: Int,
  newUserCapacity: Option[Int],
  delayProjectWeeks: Option[Int],
  dropLowPriority: Boolean = false
)

case class SimOutcome(
  completed: Int,
  missedDeadlines: Int,
  userLoad: Map[String, Double],
  totalHoursWorked: Double
)

// JSON protocols
object DomainModelsJsonProtocol {
  // LocalDate and LocalDateTime formatters must be defined first
  implicit val localDateFormat: JsonFormat[LocalDate] = new spray.json.JsonFormat[LocalDate] {
    def write(date: LocalDate) = spray.json.JsString(date.toString)
    def read(value: spray.json.JsValue) = value match {
      case spray.json.JsString(s) => LocalDate.parse(s)
      case _ => throw new spray.json.DeserializationException("Expected LocalDate as string")
    }
  }
  
  implicit val localDateTimeFormat: JsonFormat[LocalDateTime] = new spray.json.JsonFormat[LocalDateTime] {
    def write(dateTime: LocalDateTime) = spray.json.JsString(dateTime.toString)
    def read(value: spray.json.JsValue) = value match {
      case spray.json.JsString(s) => LocalDateTime.parse(s)
      case _ => throw new spray.json.DeserializationException("Expected LocalDateTime as string")
    }
  }
  
  // Case class formats (these depend on the date formatters above)
  implicit val userFormat: RootJsonFormat[User] = jsonFormat3(User)
  implicit val taskFormat: RootJsonFormat[Task] = jsonFormat8(Task)
  implicit val assignmentFormat: RootJsonFormat[Assignment] = jsonFormat4(Assignment)
  implicit val planFormat: RootJsonFormat[Plan] = jsonFormat5(Plan)
  implicit val taskEventFormat: RootJsonFormat[TaskEvent] = jsonFormat6(TaskEvent)
  implicit val userMetricsFormat: RootJsonFormat[UserMetrics] = jsonFormat6(UserMetrics)
  implicit val organizationMetricsFormat: RootJsonFormat[OrganizationMetrics] = jsonFormat6(OrganizationMetrics)
  implicit val forecastResultFormat: RootJsonFormat[ForecastResult] = jsonFormat5(ForecastResult)
  implicit val simConfigFormat: RootJsonFormat[SimConfig] = jsonFormat4(SimConfig)
  implicit val simOutcomeFormat: RootJsonFormat[SimOutcome] = jsonFormat4(SimOutcome)
}

