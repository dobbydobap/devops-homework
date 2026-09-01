# Java Hello World

Uses the HTTP server that ships with the JDK, so there is no Maven or Gradle build to set up.

The Dockerfile is multi-stage: the first stage has the full JDK and compiles `App.java`,
the second stage only carries a JRE and the compiled `.class` file. The compiler never ends
up in the final image.

```bash
docker build -t java-app .
docker run -d --name hw-java -p 8081:8080 java-app
```

The app listens on 8080 inside the container, published on 8081 here so it does not clash with
the multi-stage build task.

```
$ curl http://localhost:8081
<h1>Hello World from Java</h1>
```
