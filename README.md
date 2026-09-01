# DevOps Homework

My submissions for the DevOps sessions (Linux, shell scripting, networking, Git, Docker).
Every command output in these files was copied from an actual run on my machine.

## Setup I used

Windows 11 with Docker Desktop (WSL2 backend). Since the Linux tasks need a real Linux
system, I ran them inside containers rather than faking anything:

- `ubuntu:24.04` for the file/user/networking commands
- `jrei/systemd-ubuntu:24.04` (privileged, with cgroups mounted) for the `journalctl` task,
  because plain containers have no systemd and journalctl would have nothing to read

## What is in here

| Folder | Session |
|---|---|
| [linux/](linux/) | Linux fundamentals - soft/hard links, adduser vs useradd, journalctl, cheat sheet |
| [shell-scripting/](shell-scripting/) | System information script |
| [networking/](networking/) | Networking commands with output and notes |
| [git-github/](git-github/) | `git commit -a -m` and cherry-pick |
| [multi-stage-build/](multi-stage-build/) | Multi-stage Dockerfile running on port 8080 |
| [docker-networking/](docker-networking/) | Networks, host network, bind mount, overlay notes |

Docker "Hello World" apps, one folder each:

| Folder | Base image | Port |
|---|---|---|
| [nodejs-app/](nodejs-app/) | node:22-alpine | 3000 |
| [python-app/](python-app/) | python:3.12-alpine | 5000 |
| [java-app/](java-app/) | eclipse-temurin 21 (jdk -> jre) | 8081 |
| [Apache-app/](Apache-app/) | httpd:2.4 | 8082 |
| [React-app/](React-app/) | node:22-alpine -> nginx:alpine | 8083 |
| [nginx-app/](nginx-app/) | nginx:alpine | 8084 |

## Running all six apps

```bash
docker build -t nodejs-app ./nodejs-app
docker build -t python-app ./python-app
docker build -t java-app   ./java-app
docker build -t apache-app ./Apache-app
docker build -t react-app  ./React-app
docker build -t nginx-app  ./nginx-app

docker run -d --name hw-node   -p 3000:3000 nodejs-app
docker run -d --name hw-python -p 5000:5000 python-app
docker run -d --name hw-java   -p 8081:8080 java-app
docker run -d --name hw-apache -p 8082:80   apache-app
docker run -d --name hw-react  -p 8083:80   react-app
docker run -d --name hw-nginx  -p 8084:80   nginx-app
```

All six running at the same time:

```
NAMES       IMAGE        STATUS          PORTS
hw-nginx    nginx-app    Up 14 seconds   0.0.0.0:8084->80/tcp, [::]:8084->80/tcp
hw-react    react-app    Up 15 seconds   0.0.0.0:8083->80/tcp, [::]:8083->80/tcp
hw-apache   apache-app   Up 16 seconds   0.0.0.0:8082->80/tcp, [::]:8082->80/tcp
hw-java     java-app     Up 17 seconds   0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
hw-python   python-app   Up 18 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
hw-node     nodejs-app   Up 18 seconds   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp
```

Each response (the Apache and Nginx ones serve a full HTML page, so I filtered to the heading):

```
$ curl -s http://localhost:3000 | grep h1
<h1>Hello World from Node.js</h1>

$ curl -s http://localhost:5000 | grep h1
<h1>Hello World from Python</h1>

$ curl -s http://localhost:8081 | grep h1
<h1>Hello World from Java</h1>

$ curl -s http://localhost:8082 | grep h1
    <h1>Hello World from Apache</h1>

$ curl -s http://localhost:8084 | grep h1
    <h1>Hello World from Nginx</h1>
```

React serves a built bundle, so `curl` on the page returns the HTML shell and the heading is
rendered by JavaScript. Checking the bundle itself shows the text is there:

```
$ curl -s http://localhost:8083/assets/index-DnZR9tUp.js | grep -o "Hello World from React"
Hello World from React
```

Cleanup:

```bash
docker rm -f hw-node hw-python hw-java hw-apache hw-react hw-nginx
```
