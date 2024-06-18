FROM openjdk:11
EXPOSE 8090
ADD target/javulna-1.0-SNAPSHOT.jar javulna-1.0-SNAPSHOT.jar
ENTRYPOINT ["java","-jar","javulna-1.0-SNAPSHOT.jar","--server.port=8090"]
