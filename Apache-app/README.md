# Apache Hello World

Static page copied into the Apache document root (`/usr/local/apache2/htdocs`).

```bash
docker build -t apache-app .
docker run -d --name hw-apache -p 8082:80 apache-app
```

```
$ curl http://localhost:8082
<!DOCTYPE html>
<html>
  <head>
    <title>Apache App</title>
  </head>
  <body>
    <h1>Hello World from Apache</h1>
  </body>
</html>
```
