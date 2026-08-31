# Node.js Hello World

Express app served on port 3000.

```bash
docker build -t nodejs-app .
docker run -d --name hw-node -p 3000:3000 nodejs-app
```

```
$ curl http://localhost:3000
<h1>Hello World from Node.js</h1>
```

![nodejs app](../screenshots/nodejs-app.png)
