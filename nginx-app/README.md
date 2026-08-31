# Nginx Hello World

Static page copied into the Nginx document root (`/usr/share/nginx/html`).

```bash
docker build -t nginx-app .
docker run -d --name hw-nginx -p 8084:80 nginx-app
```

```
$ curl http://localhost:8084
<!DOCTYPE html>
<html>
  <head>
    <title>Nginx App</title>
  </head>
  <body>
    <h1>Hello World from Nginx</h1>
  </body>
</html>
```

![nginx app](../screenshots/nginx-app.png)
