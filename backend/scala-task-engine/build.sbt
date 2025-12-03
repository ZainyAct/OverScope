ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / scalaVersion := "2.13.12"

lazy val root = (project in file("."))
  .enablePlugins(JavaAppPackaging)
  .settings(
    name := "scala-task-engine",
    Compile / mainClass := Some("com.taskforge.TaskEngine"),
    libraryDependencies ++= Seq(
      "com.typesafe.akka" %% "akka-http" % "10.5.3",
      "com.typesafe.akka" %% "akka-http-spray-json" % "10.5.3",
      "com.typesafe.akka" %% "akka-stream" % "2.8.5",
      "com.typesafe.akka" %% "akka-actor-typed" % "2.8.5",
      "org.postgresql" % "postgresql" % "42.6.0",
      "ch.qos.logback" % "logback-classic" % "1.4.11",
      "com.typesafe" % "config" % "1.4.3",
      "com.zaxxer" % "HikariCP" % "5.1.0",
      "org.scala-lang.modules" %% "scala-collection-contrib" % "0.3.0"
    )
  )

