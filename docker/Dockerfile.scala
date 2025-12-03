FROM eclipse-temurin:17-jdk AS build

WORKDIR /app

# Install sbt and curl
RUN apt-get update && \
    apt-get install -y curl && \
    curl -L https://github.com/sbt/sbt/releases/download/v1.9.7/sbt-1.9.7.tgz | tar xz -C /opt && \
    ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt && \
    rm -rf /var/lib/apt/lists/*

# Copy build files
COPY backend/scala-task-engine/build.sbt ./
COPY backend/scala-task-engine/project/ ./project/

# Download dependencies (this will create target directory)
RUN sbt update || true

# Copy source code
COPY backend/scala-task-engine/src/ ./src/

# Build the application
RUN sbt stage

# Runtime stage
FROM eclipse-temurin:17-jre

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# Copy the built application
COPY --from=build /app/target/universal/stage/ ./

EXPOSE 8080

CMD ["./bin/scala-task-engine"]

