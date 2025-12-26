# Build stage
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app

# If the shared 'common' module is present in the repo root, copy and install it
# into the local Maven repository so the device-registry build can resolve it.
COPY services/common /tmp/common
RUN if [ -f /tmp/common/pom.xml ]; then mvn -f /tmp/common/pom.xml install -DskipTests -B; fi

# Copy device-registry pom for dependency caching
COPY services/device-registry/pom.xml ./pom.xml

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy device-registry source code
COPY services/device-registry/src ./src

# Build the application
RUN mvn package -DskipTests -B

# Runtime stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Add non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy the built jar
COPY --from=build /app/target/*.jar app.jar

# Change ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
