FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn -q -B -ntp dependency:go-offline
COPY src ./src
RUN mvn -q -B -ntp package -DskipTests

FROM eclipse-temurin:21-jre
RUN groupadd --system --gid 10001 cipher \
 && useradd --system --uid 10001 --gid cipher --no-create-home --home-dir /app --shell /usr/sbin/nologin cipher \
 && mkdir -p /app/data \
 && chown -R cipher:cipher /app
WORKDIR /app
COPY --from=build --chown=cipher:cipher /workspace/target/cipher-relay-*.jar /app/cipher-relay.jar
USER cipher
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/cipher-relay.jar"]
