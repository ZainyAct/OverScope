package com.taskforge

import akka.actor.typed.ActorSystem
import akka.actor.typed.scaladsl.Behaviors
import akka.http.scaladsl.Http
import akka.http.scaladsl.server.Directives._
import akka.http.scaladsl.marshallers.sprayjson.SprayJsonSupport._
import akka.stream.Materializer
import spray.json.DefaultJsonProtocol._
import spray.json._

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import scala.concurrent.ExecutionContextExecutor
import scala.concurrent.duration._
import scala.concurrent.Await

import com.taskforge.models._
import com.taskforge.models.DomainModelsJsonProtocol._
import com.taskforge.services._
import com.taskforge.db.Database

object TaskEngine extends App {
  implicit val system: ActorSystem[Nothing] = ActorSystem(Behaviors.empty, "TaskEngine")
  implicit val executionContext: ExecutionContextExecutor = system.executionContext
  implicit val materializer: Materializer = Materializer(system)

  // Initialize database connection (from environment variables or config)
  val dbUrl = sys.env.getOrElse("DATABASE_URL", "jdbc:postgresql://localhost:5432/taskforge_development")
  val dbUser = sys.env.getOrElse("DB_USER", "postgres")
  val dbPassword = sys.env.getOrElse("DB_PASSWORD", "postgres")
  
  try {
    Database.initialize(dbUrl, dbUser, dbPassword)
    println("Database connection initialized")
  } catch {
    case e: Exception =>
      println(s"Warning: Could not initialize database: ${e.getMessage}")
      println("Some features may not work without database connection")
  }

  // Start streaming analytics
  try {
    StreamingAnalytics.startStream(system, materializer)
  } catch {
    case e: Exception =>
      println(s"Warning: Could not start streaming analytics: ${e.getMessage}")
  }

  // Legacy JSON protocols for backward compatibility
  case class TaskInput(id: String, complexity: Int, due_date: Option[String], priority: Int, status: String)
  case class TaskScore(id: String, score: Double, reason: String)
  case class HealthResponse(status: String)
  
  case class OptimizeScheduleRequest(users: List[User], tasks: List[Task])
  case class ForecastRequest(users: List[User], tasks: List[Task], organizationId: Option[String])
  case class SimulateRequest(users: List[User], tasks: List[Task], config: SimConfig)
  case class PriorityRequest(task: Task)
  case class PriorityResponse(score: Double, explanations: List[String])
  case class FireAlarmResponse(alert: Boolean, message: String)
  case class EstimateRequest(task: Task, userId: Option[String] = None)
  case class EstimateResponse(estimateHours: Int, method: String, breakdown: Map[String, Double])
  case class TrackAccuracyRequest(taskId: String, estimatedHours: Int, actualHours: Double, userId: Option[String] = None)
  case class EstimationStatsResponse(
    totalTasks: Int,
    avgAccuracy: Double,
    avgOverestimate: Double,
    avgUnderestimate: Double
  )

  implicit val taskInputFormat: RootJsonFormat[TaskInput] = jsonFormat5(TaskInput)
  implicit val taskScoreFormat: RootJsonFormat[TaskScore] = jsonFormat3(TaskScore)
  implicit val healthResponseFormat: RootJsonFormat[HealthResponse] = jsonFormat1(HealthResponse)
  implicit val optimizeScheduleRequestFormat: RootJsonFormat[OptimizeScheduleRequest] = jsonFormat2(OptimizeScheduleRequest)
  implicit val forecastRequestFormat: RootJsonFormat[ForecastRequest] = jsonFormat3(ForecastRequest)
  implicit val simulateRequestFormat: RootJsonFormat[SimulateRequest] = jsonFormat3(SimulateRequest)
  implicit val priorityRequestFormat: RootJsonFormat[PriorityRequest] = jsonFormat1(PriorityRequest)
  implicit val priorityResponseFormat: RootJsonFormat[PriorityResponse] = jsonFormat2(PriorityResponse)
  implicit val fireAlarmResponseFormat: RootJsonFormat[FireAlarmResponse] = jsonFormat2(FireAlarmResponse)
  implicit val estimateRequestFormat: RootJsonFormat[EstimateRequest] = jsonFormat2(EstimateRequest)
  implicit val estimateResponseFormat: RootJsonFormat[EstimateResponse] = jsonFormat3(EstimateResponse)
  implicit val trackAccuracyRequestFormat: RootJsonFormat[TrackAccuracyRequest] = jsonFormat4(TrackAccuracyRequest)
  implicit val estimationStatsResponseFormat: RootJsonFormat[EstimationStatsResponse] = jsonFormat4(EstimationStatsResponse)

  // Legacy task scoring service (now uses PriorityEngine)
  object TaskScoringService {
    def scoreTask(task: TaskInput): TaskScore = {
      val taskModel = Task(
        id = task.id,
        estimateHours = 5, // Default
        priority = task.priority,
        dueDate = task.due_date.map(LocalDate.parse(_, DateTimeFormatter.ISO_DATE)),
        status = task.status,
        complexity = task.complexity,
        tags = Nil
      )
      
      val result = PriorityEngine.calculatePriority(taskModel)
      TaskScore(task.id, result.score, result.explanations.mkString(", "))
    }
  }

  // Routes
  val route =
    path("health") {
      get {
        complete(HealthResponse("ok"))
      }
    } ~
    // Legacy endpoint
    path("score-tasks") {
      post {
        entity(as[List[TaskInput]]) { tasks =>
          val scoredTasks = tasks.map(TaskScoringService.scoreTask)
          complete(scoredTasks)
        }
      }
    } ~
    // New endpoints
    path("optimize-schedule") {
      post {
        entity(as[OptimizeScheduleRequest]) { request =>
          val plan = ScheduleOptimizer.bestPlan(request.users, request.tasks)
          // Score the plan with task information
          val scoredPlan = ScheduleOptimizer.scorePlanWithTasks(plan, request.tasks, request.users)
          complete(scoredPlan)
        }
      }
    } ~
    path("forecast") {
      post {
        entity(as[ForecastRequest]) { request =>
          // Fetch tasks from database if organizationId is provided
          val tasks = request.organizationId match {
            case Some(orgId) =>
              try {
                Database.fetchTasksForOrganization(orgId)
              } catch {
                case _: Exception => request.tasks
              }
            case None => request.tasks
          }
          
          // Historical data will be fetched automatically from DB if not provided
          val historicalData = Map.empty[String, CapacityForecaster.HistoricalData]
          val forecasts = CapacityForecaster.forecast(request.users, tasks, historicalData)
          complete(forecasts)
        }
      }
    } ~
    path("forecast" / "burnout") {
      get {
        parameter("threshold".as[Double].?(0.8), "organizationId".as[String].?) { (threshold, orgId) =>
          val users = orgId match {
            case Some(id) => Database.fetchAllUsers(Some(id))
            case None => Database.fetchAllUsers()
          }
          val risks = CapacityForecaster.detectBurnoutRisk(users, threshold)
          complete(risks)
        }
      }
    } ~
    path("simulate") {
      post {
        entity(as[SimulateRequest]) { request =>
          val outcome = SimulationEngine.runSimulation(
            request.users,
            request.tasks,
            request.config
          )
          complete(outcome)
        }
      }
    } ~
    path("priority" / "calculate") {
      post {
        entity(as[PriorityRequest]) { request =>
          val result = PriorityEngine.calculatePriority(request.task)
          complete(PriorityResponse(result.score, result.explanations))
        }
      }
    } ~
    path("priority" / "explain") {
      post {
        entity(as[PriorityRequest]) { request =>
          val explanation = PriorityEngine.explainPriority(request.task)
          complete(Map("explanation" -> explanation))
        }
      }
    } ~
    path("analytics" / "user" / Segment) { userId =>
      get {
        // Try DB first, then in-memory cache
        val metrics = StreamingAnalytics.getUserMetricsFromDB(userId)
        metrics match {
          case Some(m) => complete(m)
          case None => complete(Map("error" -> "User metrics not found"))
        }
      }
    } ~
    path("analytics" / "alerts") {
      get {
        parameter("threshold".as[Double].?(0.7)) { threshold =>
          val alerts = StreamingAnalytics.getPressureAlerts(threshold)
          complete(alerts)
        }
      }
    } ~
    path("analytics" / "fire-alarm") {
      get {
        parameter("organizationId".as[String], "threshold".as[Int].?(5), "hoursWindow".as[Int].?(24)) { (orgId, threshold, hoursWindow) =>
          val alert = StreamingAnalytics.checkOverdueTaskSpike(orgId, threshold, hoursWindow)
          alert match {
            case Some(message) => complete(FireAlarmResponse(true, message))
            case None => complete(FireAlarmResponse(false, "No spike detected"))
          }
        }
      }
    } ~
    path("estimate") {
      post {
        entity(as[EstimateRequest]) { request =>
          val estimate = EstimationService.estimateTask(request.task, request.userId)
          // Get breakdown of estimation strategies
          val complexityEst = EstimationService.complexityBasedEstimate(request.task).getOrElse(0).toDouble
          val historicalEst = EstimationService.historicalEstimate(request.task, request.userId).getOrElse(0).toDouble
          val breakdown = Map[String, Double](
            "complexity_based" -> complexityEst,
            "historical" -> historicalEst,
            "final_estimate" -> estimate.toDouble
          )
          complete(EstimateResponse(estimate, "weighted_average", breakdown))
        }
      }
    } ~
    path("estimate" / "track-accuracy") {
      post {
        entity(as[TrackAccuracyRequest]) { request =>
          EstimationService.trackAccuracy(
            request.taskId,
            request.estimatedHours,
            request.actualHours,
            request.userId
          )
          complete(Map("status" -> "success", "message" -> "Accuracy tracked"))
        }
      }
    } ~
    path("estimate" / "stats") {
      get {
        parameter("userId".as[String].?, "organizationId".as[String].?) { (userId, orgId) =>
          val stats = EstimationService.getEstimationStats(userId, orgId)
          complete(EstimationStatsResponse(
            stats.totalTasks,
            stats.avgAccuracy,
            stats.avgOverestimate,
            stats.avgUnderestimate
          ))
        }
      }
    }

  val bindingFuture = Http().newServerAt("0.0.0.0", 8080).bind(route)
  
  bindingFuture.onComplete {
    case scala.util.Success(binding) =>
      println(s"Server online at http://${binding.localAddress.getHostString}:${binding.localAddress.getPort}/")
      println("Available endpoints:")
      println("  GET  /health")
      println("  POST /score-tasks (legacy)")
      println("  POST /optimize-schedule")
      println("  POST /forecast")
      println("  GET  /forecast/burnout?threshold=0.8&organizationId=<org-id>")
      println("  POST /simulate")
      println("  POST /priority/calculate")
      println("  POST /priority/explain")
      println("  GET  /analytics/user/:userId")
      println("  GET  /analytics/alerts?threshold=0.7")
      println("  GET  /analytics/fire-alarm?organizationId=<org-id>&threshold=5&hoursWindow=24")
      println("  POST /estimate")
      println("  POST /estimate/track-accuracy")
      println("  GET  /estimate/stats?userId=<id>&organizationId=<id>")
    case scala.util.Failure(e) =>
      println(s"Server failed to start: ${e.getMessage}")
      e.printStackTrace()
      system.terminate()
  }
  
  // Register shutdown hook for graceful shutdown
  sys.addShutdownHook {
    println("Shutting down server...")
    Database.close()
    bindingFuture
      .flatMap(_.unbind())
      .onComplete(_ => system.terminate())
  }
  
  // Keep the actor system running
  Await.result(system.whenTerminated, Duration.Inf)
}
