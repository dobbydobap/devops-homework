# Python Hello World

Flask app on port 5000. Flask has to bind to `0.0.0.0` and not `127.0.0.1`, otherwise it only
listens inside the container and the published port gives back nothing.

```bash
docker build -t python-app .
docker run -d --name hw-python -p 5000:5000 python-app
```

```
$ curl http://localhost:5000
<h1>Hello World from Python</h1>
```
