# Session 12 — Kubernetes Ingress, ConfigMaps and Secrets

My run of the session 12 lab (`04-full-demo`), on my kind cluster. Manifests in
[manifests/](manifests/), copied unmodified from the course repo.

The demo is a two-tier app: an nginx frontend and a Python backend, with configuration in a
ConfigMap, credentials in a Secret, and an Ingress routing `/` and `/api` to the two services.

---

## Part 1: ConfigMap

A ConfigMap holds non-sensitive configuration as key-value pairs, so the same image can run in dev
and production with different settings.

```
$ kubectl apply -f configmap.yaml
configmap/yatri-app-config created

$ kubectl get configmap yatri-app-config
NAME               DATA   AGE
yatri-app-config   5      0s
```

`DATA 5` — five keys. The values are stored in plain text and `describe` shows them:

```
$ kubectl describe configmap yatri-app-config
ENVIRONMENT:
----
production

LOG_LEVEL:
----
INFO

MAX_BOOKING_DAYS:
----
30
```

---

## Part 2: Secret

A Secret is the same idea for sensitive values, with one important difference in how it is
displayed.

```
$ kubectl apply -f secret.yaml
secret/yatri-db-secret created

$ kubectl get secret yatri-db-secret
NAME              TYPE     DATA   AGE
yatri-db-secret   Opaque   3      0s
```

`describe` deliberately does **not** print the values:

```
$ kubectl describe secret yatri-db-secret
Type:  Opaque

Data
====
POSTGRES_DB:        19 bytes
POSTGRES_PASSWORD:  14 bytes
POSTGRES_USER:      11 bytes
```

Just byte counts. That is the only protection you get from the CLI.

### The base64 gotcha

The lab has a `troubleshooting/secret-base64-gotcha.md` note and it is worth proving rather than
reading:

```
$ kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}'
c2VjcmV0cGFzc3dvcmQ=

$ kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
secretpassword
```

**Base64 is encoding, not encryption.** Anyone who can `get secrets` in the namespace can read
every password in one command, and by default they are stored unencrypted in etcd too. A Secret is
better than a ConfigMap because it is not printed by accident, is not in your git repo, and can be
RBAC-restricted separately — but it is not, on its own, secure storage.

For real protection you need encryption at rest on etcd, tight RBAC on the `secrets` resource, and
ideally an external store (Vault, AWS Secrets Manager, Sealed Secrets) so the plaintext never
enters a manifest at all.

---

## Part 3: The app consuming both

```
$ kubectl apply -f backend.yaml -f frontend.yaml
deployment.apps/yatri-backend created
service/yatri-backend-service created
deployment.apps/yatri-frontend created
service/yatri-frontend-service created

$ kubectl get pods
yatri-backend-8776f7d7-tq8rp      1/1   Running   0   47s
yatri-backend-8776f7d7-z68j9      1/1   Running   0   47s
yatri-frontend-67f945bd49-9qwm5   1/1   Running   0   47s
yatri-frontend-67f945bd49-vmvmq   1/1   Running   0   47s
```

The proof that it actually wired up — the environment inside a running backend container:

```
$ kubectl exec yatri-backend-8776f7d7-tq8rp -- env | grep -E 'ENVIRONMENT|LOG_LEVEL|APP_PORT|CURRENCY|BOOKING|POSTGRES'
APP_PORT=5000
DEFAULT_CURRENCY=INR
ENVIRONMENT=production
LOG_LEVEL=INFO
MAX_BOOKING_DAYS=30
POSTGRES_DB=yatri_production_db
POSTGRES_PASSWORD=secretpassword
POSTGRES_USER=yatri_admin
```

Five from the ConfigMap, three from the Secret. Note the Secret values arrive **already decoded** —
the container sees `secretpassword`, not the base64. Kubernetes decodes on injection, so the app
needs no special handling.

It also shows the other half of the gotcha: once a Secret is exposed as an env var, anyone who can
`kubectl exec` into the pod can read it.

---

## Part 4: Ingress

A Service gets you one entry point per app. An Ingress is a single HTTP entry point that routes by
**host and path** to many services, so you do not burn a LoadBalancer per service.

### Installing a controller

An Ingress object on its own does nothing — it is just a rule that some controller has to
implement. kind ships none, so I installed ingress-nginx:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/kind/deploy.yaml
```

It sat `Pending` at first:

```
$ kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller
Warning  FailedScheduling  118s  default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector.
```

The kind-flavoured manifest pins the controller to a node labelled `ingress-ready=true`, which is
normally applied when you create the cluster from a kind config file. My cluster was created with
a plain `kind create cluster`, so no node had it. Labelling the node by hand fixed it:

```
$ kubectl label node devops-heros-control-plane ingress-ready=true --overwrite
node/devops-heros-control-plane labeled

$ kubectl get pods -n ingress-nginx
ingress-nginx-admission-create-6n2m5        0/1   Completed   0   3m2s
ingress-nginx-admission-patch-tsdfb         0/1   Completed   0   3m2s
ingress-nginx-controller-78657859f8-b6wb2   1/1   Running     0   3m3s
```

### The Ingress rules

```
$ kubectl apply -f ingress.yaml
ingress.networking.k8s.io/yatri-ingress created

$ kubectl get ingress yatri-ingress
NAME            CLASS   HOSTS         ADDRESS   PORTS   AGE
yatri-ingress   nginx   yatri.local             80      9s

$ kubectl describe ingress yatri-ingress
Rules:
  Host         Path  Backends
  ----         ----  --------
  yatri.local
               /api(/|$)(.*)   yatri-backend-service:80 (10.244.0.90:5000,10.244.0.91:5000)
               /               yatri-frontend-service:80 (10.244.0.92:80,10.244.0.93:80)
Annotations:   nginx.ingress.kubernetes.io/rewrite-target: /$2
               nginx.ingress.kubernetes.io/ssl-redirect: false
               nginx.ingress.kubernetes.io/use-regex: true
```

Both rules resolved to real pod IPs, which means the selectors matched. `ADDRESS` is blank because
nothing assigned an external address — same root cause as the LoadBalancer in session 11.

The `rewrite-target: /$2` with the `/api(/|$)(.*)` capture group means `/api/health` reaches the
backend as `/health`. Without it the backend would receive `/api/health` and 404.

### Testing the routing

The kind ingress-nginx manifest binds hostPort 80 on the node, so I tested from inside the node
container, sending the `Host` header the rules match on:

```
$ docker exec devops-heros-control-plane curl -s -H "Host: yatri.local" http://localhost/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
<h1>Welcome to nginx!</h1>
```

`/` reached the **frontend**. And the API path:

```
$ docker exec devops-heros-control-plane curl -s -H "Host: yatri.local" http://localhost/api/
Yatri Backend API
=================
ENVIRONMENT     : production
LOG_LEVEL       : INFO
DEFAULT_CURRENCY: INR
POSTGRES_USER   : yatri_admin
POSTGRES_DB     : yatri_production_db
```

`/api/` reached the **backend** — and the backend is printing the ConfigMap and Secret values it
was given. That single response ties all four parts of this session together: the Ingress routed
by path, and the app is running on configuration injected from a ConfigMap and a Secret.

The `Host:` header matters. The Ingress rule is scoped to `yatri.local`, so a request without that
header does not match and gets the controller's default 404. On a real setup you would point DNS
at the load balancer instead; locally you would add `yatri.local` to your hosts file.

---

## Summary

| | ConfigMap | Secret |
|---|---|---|
| For | plain configuration | passwords, tokens, keys |
| Stored as | plain text | base64 (**not** encrypted) |
| Shown by `describe` | full values | byte counts only |
| Injected as | env vars or files | env vars or files, decoded |

| | Service | Ingress |
|---|---|---|
| Layer | 4 (TCP) | 7 (HTTP) |
| Routes by | label selector | host and URL path |
| External entry points | one per Service | one for many services |
| Needs a controller | no | yes, or it does nothing |
