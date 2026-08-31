# React Hello World

React + Vite. The Dockerfile is multi-stage: stage one installs the dependencies and runs
`npm run build`, stage two copies only the `dist/` output into Nginx. Node and `node_modules`
are not in the final image, which is why it comes out at about 93MB instead of ~250MB.

```bash
docker build -t react-app .
docker run -d --name hw-react -p 8083:80 react-app
```

The build output during `docker build`:

```
dist/index.html                  0.32 kB | gzip:  0.24 kB
dist/assets/index-DnZR9tUp.js  142.52 kB | gzip: 45.74 kB
built in 1.25s
```

Because React renders into `<div id="root">` at runtime, `curl` on the page returns the shell:

```
$ curl http://localhost:8083
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>React App</title>
    <script type="module" crossorigin src="/assets/index-DnZR9tUp.js"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
```

The heading is inside the JS bundle, and shows up in the browser:

```
$ curl -s http://localhost:8083/assets/index-DnZR9tUp.js | grep -o "Hello World from React"
Hello World from React
```

![react app](../screenshots/react-app.png)
