FROM eclipse-temurin:17-jdk AS build

WORKDIR /app

# Install sbt
RUN apt-get update && \
    apt-get install -y curl && \
    curl -L https://github.com/sbt/sbt/releases/download/v1.9.7/sbt-1.9.7.tgz | tar xz -C /opt && \
    ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

# Copy build files
COPY build.sbt project/ ./
COPY project/ ./project/

# Download dependencies
RUN sbt update

# Copy source code
COPY src/ ./src/

# Build the application
RUN sbt stage

# Runtime stage
FROM eclipse-temurin:17-jre

WORKDIR /app

# Copy the built application
COPY --from=build /app/target/universal/stage/ ./

EXPOSE 8080

CMD ["./bin/scala-task-engine"]

