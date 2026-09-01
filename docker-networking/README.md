# Docker Networking and Volumes

---

## Task 1: Container networking with three tiers

Three containers (frontend, backend, database) across three networks, with the backend attached
to two of them.

### Create the networks

```
$ docker network create frontend-net
59cc6a778d77cffb12d76c05cfb8829e481e3322f5137b5cd2964ff5c68e67a5
$ docker network create backend-net
7bb95973d3d1a2c7972fd34a26082c742bdf0d4cffb6ecdbb4640fe0a3163441
$ docker network create db-net
473a541aef4ac34dc4708cf33d6d55d51fa78c58f75ec989c550990e93405e54

$ docker network ls
NETWORK ID     NAME           DRIVER    SCOPE
7bb95973d3d1   backend-net    bridge    local
473a541aef4a   db-net         bridge    local
59cc6a778d77   frontend-net   bridge    local
```

### Create the containers

```bash
docker run -d --name frontend --network frontend-net nginx:alpine
docker run -d --name backend  --network frontend-net alpine sleep infinity

# the backend also has to reach the database, so give it a second network
docker network connect backend-net backend

docker run -d --name database --network backend-net -e MYSQL_ROOT_PASSWORD=root123 mysql:8.2
docker network connect db-net database
```

Nginx for the frontend, Alpine for the backend, MySQL for the database, as the task asked.

### The layout that gives

```
$ docker network inspect <net> --format "{{range .Containers}}{{.Name}} {{end}}"
frontend-net   members: frontend backend
backend-net    members: backend database
db-net         members: database
```

The backend is on two networks and has an address on each:

```
$ docker inspect backend --format "{{range $k,$v := .NetworkSettings.Networks}}{{$k}} => {{$v.IPAddress}}{{println}}{{end}}"
backend-net => 172.26.0.2
frontend-net => 172.25.0.3

--- frontend ---
frontend-net => 172.25.0.2

--- database ---
backend-net => 172.26.0.3
db-net => 172.27.0.2
```

So the backend sits in the middle: it can talk to the frontend on 172.25.x and to the database on
172.26.x. The frontend and the database share no network at all.

### Connectivity checks

Backend to frontend, both on `frontend-net`:

```
$ docker exec backend ping -c 3 frontend
PING frontend (172.25.0.2): 56 data bytes
64 bytes from 172.25.0.2: seq=0 ttl=64 time=2.711 ms
64 bytes from 172.25.0.2: seq=1 ttl=64 time=0.139 ms
64 bytes from 172.25.0.2: seq=2 ttl=64 time=0.278 ms

--- frontend ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss

$ docker exec backend curl -s http://frontend | head -4
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

Backend to database, both on `backend-net`:

```
$ docker exec backend ping -c 3 database
PING database (172.26.0.3): 56 data bytes
64 bytes from 172.26.0.3: seq=0 ttl=64 time=1.739 ms
64 bytes from 172.26.0.3: seq=1 ttl=64 time=0.148 ms
64 bytes from 172.26.0.3: seq=2 ttl=64 time=0.127 ms

--- database ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss

$ docker exec backend nc -zv database 3306
Connection to database (172.26.0.3) 3306 port [tcp/mysql] succeeded!
```

And a real query against it over the network:

```
$ docker run --rm --network backend-net mysql:8.2 mysql -h database -u root -proot123 -e "SELECT VERSION();"
VERSION()
8.2.0
```

Frontend to database, which share no network:

```
$ docker exec frontend ping -c 2 database
ping: bad address 'database'

$ docker exec frontend nc -zv database 3306
nc: bad address 'database'
```

That failure is the interesting result. It does not even get as far as a connection attempt - the
name `database` will not resolve. Docker's built in DNS only resolves container names **within a
shared network**, so from the frontend the database simply does not exist. This is how you keep a
database off the public facing tier: don't put them on the same network.

### Cleanup

```bash
docker rm -f frontend backend database
docker network rm frontend-net backend-net db-net
```

---

## Task 2: Host network

```
$ docker pull httpd:2.4
$ docker run -d --name apache-host --network host httpd:2.4
fb7f2142f15f9c498270c6db95d9ca743ba71cdf837c238015ed548e172adce4

$ docker ps
NAMES         IMAGE       STATUS         PORTS
apache-host   httpd:2.4   Up 5 seconds

$ docker inspect apache-host --format "{{.HostConfig.NetworkMode}}"
host
```

The `PORTS` column is empty, which is the giveaway. With `--network host` there is no port
mapping and no separate network namespace - the container uses the host's network directly, so
Apache binds port 80 on the host itself.

Apache serving on port 80:

```
$ wget -qO- http://localhost:80
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
<body>
<p>It works!</p>
</body>
</html>

$ netstat -tuln | grep ":80 "
tcp        0      0 :::80                   :::*                    LISTEN
```

And the request shows up in Apache's own log, confirming it served it:

```
$ docker logs apache-host
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 192.168.65.3
[Mon Aug 31 16:08:15 2026] [mpm_event:notice] AH00489: Apache/2.4.68 (Unix) configured -- resuming normal operations
[Mon Aug 31 16:08:15 2026] [core:notice] AH00094: Command line: 'httpd -D FOREGROUND'
::1 - - [31/Aug/2026:16:08:44 +0000] "GET / HTTP/1.1" 200 191
```

### One thing I hit on Windows

I run Docker Desktop, which keeps containers inside a WSL2 Linux virtual machine. With host
networking the "host" is that VM, not Windows, so `curl http://localhost:80` from a Windows
terminal gets connection refused even though Apache is running perfectly:

```
$ curl -s http://localhost:80
(curl exit code 7 - connection refused)
```

The two commands above were therefore run from inside that same host namespace:

```bash
docker run --rm --network host alpine wget -qO- http://localhost:80
docker run --rm --network host alpine netstat -tuln | grep ":80 "
```

On a native Linux host, `curl http://localhost:80` would work straight away. On Docker Desktop
you need to turn on "Enable host networking" under Settings > Resources > Network to reach it
from Windows. I left that setting alone because it needs a Docker restart and I had other
containers running.

### Cleanup

```bash
docker rm -f apache-host
```

---

## Task 3: Bind mount

A folder on my machine mounted straight into an Nginx container.

The folder is [site/](site/) and contains `index.html`:

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Bind Mount Demo</title>
  </head>
  <body>
    <h1>Hello students</h1>
  </body>
</html>
```

```
$ docker run -d --name bind-nginx -p 8085:80 \
    -v C:\Users\varsh\devops-homework\docker-networking\site:/usr/share/nginx/html nginx:alpine
d2092e861980d0f34de9e473e1153585361670fb0b911491cc67dd28d3f2a383

$ docker ps
NAMES        IMAGE          STATUS        PORTS
bind-nginx   nginx:alpine   Up 4 seconds  0.0.0.0:8085->80/tcp, [::]:8085->80/tcp

$ docker inspect bind-nginx --format "{{range .Mounts}}{{.Type}}  {{.Source}} -> {{.Destination}}{{end}}"
bind  C:\Users\varsh\devops-homework\docker-networking\site -> /usr/share/nginx/html
```

Mount type is `bind`, pointing at my real folder. Serving it:

```
$ curl http://localhost:8085
<!DOCTYPE html>
<html>
  <head>
    <title>Bind Mount Demo</title>
  </head>
  <body>
    <h1>Hello students</h1>
  </body>
</html>
```

### Editing the file without restarting

The container started at a fixed time, and I did not touch it after that:

```
$ docker inspect bind-nginx --format "{{.State.StartedAt}}"
2026-08-31T16:09:16.945225115Z
```

Now edit the file on the host:

```
$ sed -i "s|Hello students|Hello students - file updated from the host|" site/index.html

$ curl http://localhost:8085
<!DOCTYPE html>
<html>
  <head>
    <title>Bind Mount Demo</title>
  </head>
  <body>
    <h1>Hello students - file updated from the host</h1>
  </body>
</html>
```

The new content is served immediately, and the container was never restarted:

```
$ docker inspect bind-nginx --format "{{.State.StartedAt}}  restarts={{.RestartCount}}"
2026-08-31T16:09:16.945225115Z  restarts=0

$ docker ps
NAMES        STATUS
bind-nginx   Up 18 seconds
```

Same `StartedAt` as before the edit and `restarts=0`. Nothing was copied into the image at build
time - the container is reading my actual directory, so whatever the file says right now is what
Nginx serves. That is exactly why bind mounts are handy in development.

(The file in this repo is back to plain "Hello students" so the demo starts from the beginning.)

### Bind mount vs volume

| | Bind mount | Named volume |
|---|---|---|
| Where the data lives | a path you choose on the host | Docker managed area |
| Created with | `-v /host/path:/container/path` | `-v myvolume:/container/path` |
| Good for | source code in development, config files | databases, production data |
| Host path must exist | yes | no, Docker creates it |
| Portable across machines | no, the path is machine specific | yes |

### Cleanup

```bash
docker rm -f bind-nginx
```

---

## Task 4: Overlay networks

I did not have a swarm to run this on, so this task is written up rather than demonstrated.

A bridge network only reaches containers on **one** Docker host. An overlay network spans
**several** hosts, so containers on different physical machines can talk to each other by
container name as if they were on the same LAN.

How it works: Docker builds a VXLAN tunnel between the hosts. A packet leaving a container gets
wrapped inside a UDP packet (VXLAN uses port 4789), sent across the real network to the other
host, unwrapped there and handed to the destination container. Neither container knows any of
this happened - they see one flat virtual layer 2 network. A key-value store keeps the hosts
agreeing on which container has which address; in Swarm mode the manager nodes do this job.

Ports the hosts need open between them:

| Port | Purpose |
|---|---|
| 2377/tcp | swarm cluster management |
| 7946/tcp+udp | node discovery between hosts |
| 4789/udp | VXLAN, the actual container traffic |

Creating one, on a swarm manager:

```bash
docker swarm init
docker network create -d overlay my-overlay
docker service create --name web --network my-overlay --replicas 3 nginx:alpine
```

`--attachable` lets standalone containers join it too, not just swarm services.

When it is used:

- containers spread over multiple hosts that need to reach each other
- Docker Swarm services, where replicas land on whichever node has room
- scaling past what a single machine can hold, while keeping service names working

Encryption is off by default because it costs performance; `--opt encrypted` turns on IPsec for
the tunnel traffic.

Where I have actually seen this idea: Kubernetes solves the same problem with its own CNI plugins
(Flannel, Calico), and Flannel also uses VXLAN underneath. Overlay networking is the general
answer to "containers on different machines need one flat network".

| | Bridge | Overlay |
|---|---|---|
| Scope | one host | many hosts |
| Driver | `bridge` | `overlay` |
| Needs a swarm | no | yes (or an external key-value store) |
| Typical use | single machine, compose | swarm services, multi host clusters |
| Transport | Linux bridge | VXLAN tunnel over UDP 4789 |

---

## Everything used here

```bash
docker network create <name>
docker network ls
docker network inspect <name>
docker network connect <network> <container>
docker network disconnect <network> <container>
docker network rm <name>

docker run --network <name> ...
docker run --network host ...
docker run -v /host/path:/container/path ...

docker inspect <container> --format "{{.State.StartedAt}}"
docker exec <container> ping -c 3 <other>
docker exec <container> nc -zv <other> <port>
```
