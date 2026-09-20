# Deployment Rollout Strategies

The four strategies from `session10-k8s-core-objects/`, each run end to end on my kind cluster.
Manifests are in [rollout-strategies/](rollout-strategies/).

All four move an app from `nginx:1.24-alpine` (v1) to `nginx:1.25-alpine` (v2). What differs is
*how* the old pods are replaced.

---

## 1. Rolling update

`maxSurge: 1, maxUnavailable: 0` — one extra pod allowed above the desired count, and never fewer
than the full count available. That combination is what makes it zero downtime.

```
$ kubectl apply -f 01-rolling-update/deployment-v1.yaml -f 01-rolling-update/service.yaml
deployment.apps/app-rolling created
service/app-rolling-service created

$ kubectl get deploy app-rolling -o wide
NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES              SELECTOR
app-rolling   4/4     4            4           73s   web          nginx:1.24-alpine   app=app-rolling
```

Four v1 pods:

```
$ kubectl get pods -l app=app-rolling -L version
app-rolling-7cdb64ff89-9pl8m   Running   v1
app-rolling-7cdb64ff89-dxkxq   Running   v1
app-rolling-7cdb64ff89-nk56w   Running   v1
app-rolling-7cdb64ff89-qbdvs   Running   v1
```

Rolling to v2:

```
$ kubectl apply -f 01-rolling-update/deployment-v2.yaml
deployment.apps/app-rolling configured

$ kubectl rollout status deployment/app-rolling
Waiting for deployment "app-rolling" rollout to finish: 1 out of 4 new replicas have been updated...
Waiting for deployment "app-rolling" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "app-rolling" rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for deployment "app-rolling" rollout to finish: 1 old replicas are pending termination...
deployment "app-rolling" successfully rolled out
```

You can watch it step 1 → 2 → 3 → 4, one pod at a time. It only terminates an old pod once a new
one is Ready, which is what the readiness probe in the manifest is there for. Without a readiness
probe, Kubernetes would consider a pod "ready" the moment the container started, and the rollout
would happily replace all four before any of them could actually serve traffic.

### Two ReplicaSets, not one

This is the bit that explains everything:

```
$ kubectl get rs -l app=app-rolling
NAME                     DESIRED   CURRENT   READY   AGE
app-rolling-7cdb64ff89   0         0         0       2m8s
app-rolling-7fd6bc8cfd   4         4         4       54s
```

The Deployment did not modify the old ReplicaSet — it created a **new** one and scaled the old one
down to 0. The old one is kept at zero replicas on purpose, because that is the rollback.

```
$ kubectl rollout history deployment/app-rolling
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

`CHANGE-CAUSE` is `<none>` for both because I did not annotate the rollout. In real use you would
set `kubernetes.io/change-cause` so this table tells you what each revision was.

### Rollback

```
$ kubectl rollout undo deployment/app-rolling
deployment.apps/app-rolling rolled back
deployment "app-rolling" successfully rolled out

$ kubectl get deploy app-rolling -o wide
NAME          READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES              SELECTOR
app-rolling   4/4     4            4           2m44s   web          nginx:1.24-alpine   app=app-rolling
```

Back on `nginx:1.24-alpine`. The rollback was instant because the old ReplicaSet still existed — it
just scaled it back up. Nothing was rebuilt or re-pulled.

---

## 2. Blue-green

Two full environments side by side, and a Service selector that decides which one is live.

```
$ kubectl apply -f 02-blue-green/deployment-blue.yaml -f 02-blue-green/deployment-green.yaml -f 02-blue-green/service-blue.yaml
deployment.apps/app-blue created
deployment.apps/app-green created
service/myapp-service created

$ kubectl get pods -l app=myapp -L slot,version
NAME                         READY   STATUS    RESTARTS   AGE   SLOT    VERSION
app-blue-695bd9d968-crkw9    1/1     Running   0          29s   blue    v1
app-blue-695bd9d968-g26sn    1/1     Running   0          29s   blue    v1
app-blue-695bd9d968-zftl7    1/1     Running   0          30s   blue    v1
app-green-76699bb5cc-2mvpg   1/1     Running   0          29s   green   v2
app-green-76699bb5cc-dr4cd   1/1     Running   0          29s   green   v2
app-green-76699bb5cc-g9zfd   1/1     Running   0          29s   green   v2
```

Six pods running, both versions, at the same time. Note that costs double the resources — that is
the trade-off for this strategy.

The Service selects `slot: blue`, so only the three blue pods are endpoints:

```
$ kubectl get endpoints myapp-service
NAME            ENDPOINTS                                      AGE
myapp-service   10.244.0.44:80,10.244.0.45:80,10.244.0.46:80   30s
```

Three IPs, not six. Confirming what traffic actually gets:

```
$ kubectl run bg-probe --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- myapp-service
<p style="font-size:0.5em">Version: v1 | Slot: BLUE (LIVE)</p>
```

### The switch

The only thing that changes is the Service's selector, `slot: blue` → `slot: green`:

```
$ kubectl apply -f 02-blue-green/service-green.yaml
service/myapp-service configured

$ kubectl get endpoints myapp-service
NAME            ENDPOINTS                                      AGE
myapp-service   10.244.0.47:80,10.244.0.48:80,10.244.0.49:80   34s
```

Different three IPs — `.47/.48/.49` instead of `.44/.45/.46`. No pod was created, deleted or
restarted; the endpoints controller just recalculated which pods match the selector.

```
$ kubectl run bg-probe2 --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- myapp-service
<p style="font-size:0.5em">Version: v2 | Slot: GREEN (STANDBY -> PROMOTED)</p>
```

All traffic moved to v2 in one atomic step. Rollback is the same edit in reverse and is just as
instant, which is the real appeal — no waiting for pods to come back up.

---

## 3. Canary

One Service in front of two Deployments that share a label. The traffic split comes from the
**ratio of pod counts**, not from any routing rule.

`app-stable` has 9 replicas at v1, `app-canary` has 1 at v2, and both carry `app: myapp-canary`
which is what the Service selects:

```
$ kubectl get deploy -l app=myapp-canary
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
app-canary   1/1     1            1           45s
app-stable   9/9     9            9           45s

$ kubectl get pods -l app=myapp-canary -L track,version
app-canary-596b65bf66-74sk6  Running  track=canary  version=v2
app-stable-b74f6f677-428w2   Running  track=stable  version=v1
app-stable-b74f6f677-7djz2   Running  track=stable  version=v1
app-stable-b74f6f677-fvng5   Running  track=stable  version=v1
app-stable-b74f6f677-gqb89   Running  track=stable  version=v1
app-stable-b74f6f677-h4hph   Running  track=stable  version=v1
app-stable-b74f6f677-m4cp6   Running  track=stable  version=v1
app-stable-b74f6f677-pfr8n   Running  track=stable  version=v1
app-stable-b74f6f677-vd6kz   Running  track=stable  version=v1
app-stable-b74f6f677-vlzrk   Running  track=stable  version=v1
```

All ten are endpoints of the one Service:

```
$ kubectl get endpoints myapp-canary-service
NAME                   ENDPOINTS                                      AGE
myapp-canary-service   10.244.0.64:80,10.244.0.65:80,10.244.0.66:80 + 7 more...   47s
   (endpoint count: 10)
```

### Does the 10% actually hold?

Rather than assume it, I sent 50 requests through the Service and counted the answers:

```
$ kubectl run canary-probe --rm -i --restart=Never --image=busybox:1.36 -- \
    sh -c 'for i in $(seq 1 50); do wget -qO- myapp-canary-service | grep -oE "(CANARY|STABLE) v[0-9]"; done'
      6 CANARY v2
     34 STABLE v1
```

6 canary out of 40 responses that came back, so about 15% rather than a clean 10%. That gap is the
honest result and it is worth understanding: `kube-proxy` balances by picking a backend at
**random** per connection, not round-robin, so over only 40 samples you get ordinary statistical
scatter. Ten of the 50 requests returned nothing at all, which I would put down to the busybox
loop reusing connections against a cluster that was already memory-constrained.

The takeaway is that pod-ratio canary gives you *approximate* traffic weighting. If you need real
percentages — 1%, or splitting by header or user — you need an ingress controller or a service
mesh that can weight routes properly.

---

## 4. Recreate

`strategy: type: Recreate`. Every old pod is terminated before any new pod is created, so the two
versions never run at the same time — at the cost of real downtime.

```
$ kubectl get pods -l app=app-recreate -L version   # v1 steady state
NAME                           READY   STATUS    RESTARTS   AGE   VERSION
app-recreate-547b84f78-jf5bx   1/1     Running   0          5s    v1
app-recreate-547b84f78-prxnj   1/1     Running   0          5s    v1
app-recreate-547b84f78-vqc74   1/1     Running   0          5s    v1

$ kubectl apply -f 04-recreate/deployment-v2.yaml
deployment.apps/app-recreate configured
```

Sampling once per second immediately after:

```
  t+1s  total=3  ContainerCreating=3
  t+2s  total=3  Running=3
  t+3s  total=3  Running=3
  t+4s  total=3  Running=3
```

Two things in that trace:

- **`total` never goes above 3.** A rolling update with `maxSurge: 1` would have shown 5 pods at
  some point. Here the count never exceeds the replica count, because nothing is ever added before
  something is removed.
- **At t+1s all three pods are new and none is Ready.** The three v1 pods were already gone by the
  first sample. That moment with zero Ready pods is the downtime — brief here because nginx starts
  in about a second, but on an app with a 30-second boot it would be 30 seconds of hard outage.

I sampled at one-second granularity, so the all-terminated instant fell between samples. The
evidence that it happened is that the new pods were still `ContainerCreating` while no old pod
remained.

---

## Comparison

| | Pods during rollout | Downtime | Both versions live at once | Rollback speed | Extra cost |
|---|---|---|---|---|---|
| Rolling update | N to N+maxSurge | none | yes, briefly | fast (old RS kept) | small |
| Blue-green | 2N | none | yes, but only one gets traffic | instant (flip selector) | double |
| Canary | N + canary | none | yes, deliberately | fast (delete canary) | small |
| Recreate | N, never more | yes | no, never | slow (full recreate) | none |

Which one I would pick:

- **Rolling update** for almost everything. It is the default for a reason.
- **Blue-green** when you need an instant, total rollback — a payments service, or a release you
  want to smoke-test fully before any user sees it.
- **Canary** when you want real production traffic to find the bug for you, on 10% of users
  instead of 100%.
- **Recreate** when two versions genuinely must not coexist — a database schema migration, or an
  app that takes an exclusive lock on a shared volume. The downtime is the point, not a flaw.
