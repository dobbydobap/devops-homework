# Docker Multi-Stage Build

**Name:** Varshitha Kolupuri
**Enrollment number:** 10271

Source files taken from the course repository:
`devops-heros/session6-7-docker/multi-stage-dockerfile`

---

## Task 1: Build and run the multi-stage Dockerfile

```bash
git clone https://github.com/Nency-Ravaliya/devops-heros.git
cd devops-heros/session6-7-docker/multi-stage-dockerfile
docker build -t multistage-app .
docker run -d --name hw-multistage -p 8080:3000 multistage-app
```

The Dockerfile:

```dockerfile
# Stage 1: Build
FROM node:24-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Stage 2: Production
FROM node:24-alpine AS production
WORKDIR /app
COPY --from=builder /app/package*.json ./
RUN npm install --omit=dev
COPY --from=builder /app/server.js ./
EXPOSE 3000
CMD ["npm", "start"]
```

The app listens on 3000 inside the container. `-p 8080:3000` publishes it on **port 8080** on my
machine, which is what the task asks for.

### The application running

```
$ curl http://localhost:8080
<h1>Hello World from Docker Multi-Stage Build!</h1>
```

```
$ docker logs hw-multistage
> docker-hello-world@1.0.0 start
> node server.js

Server running on port 3000
```

![application running on port 8080](screenshots/app-8080.png)

### docker ps showing the container on port 8080

```
$ docker ps
NAMES           IMAGE            STATUS         PORTS
hw-multistage   multistage-app   Up 5 seconds   0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
```

![docker ps on port 8080](screenshots/docker-ps.png)

---

## Task 2: What the two stages actually do

Stage one (`builder`) installs **all** dependencies including dev ones and holds the full source
tree. Stage two starts from a fresh `node:24-alpine`, copies across only `package*.json` and
`server.js` from the builder, and installs production dependencies with `--omit=dev`. Anything
that only mattered during the build never reaches the final image.

I also built the same app as a single stage image to compare:

```
$ docker images
REPOSITORY             SIZE
multistage-app         247MB
singlestage-app        253MB
```

Only about 6MB apart, and I think it is worth being honest about why: this app's whole build is
`npm install express`, so there is very little build-time baggage to leave behind. The saving is
the dev dependencies and the source tree, nothing more.

Where it genuinely pays off is a build that produces an artifact. The [React app](../React-app/)
in this repo builds with Node and then copies only the compiled `dist/` folder into
`nginx:alpine` - final image about **93MB** instead of the ~250MB a Node image would cost, since
Node and `node_modules` are dropped entirely. The [java-app](../java-app/) does the same thing,
compiling with a JDK and shipping only the `.class` files on a JRE.

So the rule I took from this: multi-stage helps most when the build tools are heavy and the thing
you actually run is small.

---

## Task 3: Three application types deployed with Docker

All three are in this repository, each with its own folder and Dockerfile:

| Application | Folder | Image | Port | Verified output |
|---|---|---|---|---|
| Node.js | [nodejs-app/](../nodejs-app/) | node:22-alpine | 3000 | `<h1>Hello World from Node.js</h1>` |
| Python | [python-app/](../python-app/) | python:3.12-alpine | 5000 | `<h1>Hello World from Python</h1>` |
| Java | [java-app/](../java-app/) | temurin 21 jdk -> jre | 8081 | `<h1>Hello World from Java</h1>` |

Running together:

```
$ docker ps
NAMES       IMAGE        STATUS          PORTS
hw-java     java-app     Up 17 seconds   0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
hw-python   python-app   Up 18 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
hw-node     nodejs-app   Up 18 seconds   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp
```

```
$ curl http://localhost:3000
<h1>Hello World from Node.js</h1>

$ curl http://localhost:5000
<h1>Hello World from Python</h1>

$ curl http://localhost:8081
<h1>Hello World from Java</h1>
```

![three applications](screenshots/three-apps.png)

Three more (Apache, React, Nginx) are in the repository as well - see the
[root README](../README.md).

---

## Cleanup

```bash
docker rm -f hw-multistage
```
