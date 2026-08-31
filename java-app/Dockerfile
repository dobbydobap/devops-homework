FROM eclipse-temurin:21-jdk-alpine AS build

WORKDIR /build
COPY src/App.java .
RUN javac App.java

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
COPY --from=build /build/*.class ./

EXPOSE 8080
CMD ["java", "App"]
