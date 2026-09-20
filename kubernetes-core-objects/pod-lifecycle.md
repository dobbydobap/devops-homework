# Pod Lifecycle

The twelve manifests from `session10-k8s-core-objects/pod-lifecycle/`, applied to my kind cluster.
Files are in [pod-lifecycle/](pod-lifecycle/).

I applied all twelve at once so the different states would be visible side by side:

```
$ kubectl apply -f 01-running.yaml
pod/lifecycle-running created
$ kubectl apply -f 02-pending.yaml
pod/lifecycle-pending created
$ kubectl apply -f 03-succeeded.yaml
pod/lifecycle-succeeded created
$ kubectl apply -f 04-failed.yaml
pod/lifecycle-failed created
$ kubectl apply -f 05-crashloopbackoff.yaml
pod/lifecycle-crashloop created
$ kubectl apply -f 06-imagepullbackoff.yaml
pod/lifecycle-image-error created
$ kubectl apply -f 07-readiness.yaml
pod/lifecycle-readiness created
$ kubectl apply -f 08-liveness.yaml
pod/lifecycle-liveness created
$ kubectl apply -f 09-startup.yaml
pod/lifecycle-startup created
$ kubectl apply -f 10-init-container.yaml
pod/lifecycle-init created
$ kubectl apply -f 11-multi-container.yaml
pod/lifecycle-multi-container created
$ kubectl apply -f 12-termination.yaml
pod/lifecycle-termination created
```

Once they had all settled, every state is on screen at the same time:

```
$ kubectl get pods
NAME                               READY   STATUS             RESTARTS      AGE
lifecycle-crashloop                0/1     CrashLoopBackOff   2 (42s ago)   3m57s
lifecycle-failed                   0/1     Error              0             3m59s
lifecycle-image-error              0/1     ErrImagePull       0             3m56s
lifecycle-init                     1/1     Running            0             3m38s
lifecycle-liveness                 1/1     Running            0             3m39s
lifecycle-multi-container          2/2     Running            0             3m37s
lifecycle-pending                  0/1     Pending            0             4m2s
lifecycle-readiness                1/1     Running            0             3m40s
lifecycle-running                  1/1     Running            0             4m3s
lifecycle-startup                  1/1     Running            0             3m38s
lifecycle-succeeded                0/1     Completed          0             4m1s
lifecycle-termination              1/1     Running            0             3m35s
```

Worth being clear on something the `STATUS` column hides: Kubernetes only has **five** real pod
phases — `Pending`, `Running`, `Succeeded`, `Failed`, `Unknown`. Everything else above
(`CrashLoopBackOff`, `ErrImagePull`, `Completed`, `Init:0/1`) is `kubectl` showing you the
*container's* state or the waiting reason, because that is far more useful when debugging. A pod
stuck in `CrashLoopBackOff` is still in phase `Running`.

---

## Pending — scheduled nowhere

`02-pending.yaml` asks for 9Gi of memory, which no node here can satisfy:

```yaml
resources:
  requests:
    cpu: "1"
    memory: "9Gi"
```

```
$ kubectl get pod lifecycle-pending -o wide
NAME                READY   STATUS    RESTARTS   AGE    IP       NODE     NOMINATED NODE
lifecycle-pending   0/1     Pending   0          3m44s  <none>   <none>   <none>
```

`NODE` is `<none>` — that is what Pending means. The pod object exists in etcd, but the scheduler
cannot place it, so no kubelet has ever seen it. The reason is in the events:

```
$ kubectl get events | grep lifecycle-pending
Warning   FailedScheduling   pod/lifecycle-pending   0/1 nodes are available: 1 Insufficient memory. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```

`Insufficient memory`, and preemption would not help because there is nothing lower-priority worth
evicting. This is the single most common "why is my pod not starting" cause in real clusters, and
`kubectl describe pod` tells you in one line.

Note this is about the **request**, not actual usage. The node had free memory; it had already
promised enough of it to other pods that it could not promise another 9Gi.

---

## Succeeded and Failed — pods that are meant to end

Both of these have `restartPolicy: Never` and run a short command.

`03-succeeded.yaml` exits 0:

```
$ kubectl logs lifecycle-succeeded
Task started
Task completed successfully

$ kubectl get pod lifecycle-succeeded -o jsonpath="{.status.phase}"
Succeeded
```

`04-failed.yaml` is identical except it exits 1:

```
$ kubectl logs lifecycle-failed
Task started
Task failed

$ kubectl get pod lifecycle-failed -o jsonpath="{.status.phase}"
Failed
```

The only difference between the two is the exit code. `Completed` in the STATUS column corresponds
to phase `Succeeded`; `Error` corresponds to phase `Failed`.

Neither is restarted, because `restartPolicy: Never`. This is how Jobs behave, and it is why a
finished pod still shows up in `kubectl get pods` — a terminal pod is a record of what happened,
not a leak.

---

## CrashLoopBackOff — the restart penalty

`05-crashloopbackoff.yaml` starts, waits 3 seconds, then exits 1. Its restart policy defaults to
`Always`, so Kubernetes keeps restarting it:

```
$ kubectl logs lifecycle-crashloop
Application started
Application crashed

$ kubectl get pod lifecycle-crashloop
NAME                  READY   STATUS             RESTARTS      AGE
lifecycle-crashloop   0/1     CrashLoopBackOff   2 (42s ago)   3m57s
```

The important word is **BackOff**. Kubernetes is not restarting it as fast as it can — it doubles
the delay each time (10s, 20s, 40s, up to 5 minutes) so a broken app cannot spin the node. That is
why after nearly 4 minutes the restart count is only 2. The pod flips between `Running` briefly,
`Error`, then `CrashLoopBackOff` while it waits out the penalty.

`kubectl logs` shows the last run. When the current attempt has already died, `kubectl logs
--previous` is the one that actually holds the useful error.

---

## ErrImagePull / ImagePullBackOff — the image does not exist

`06-imagepullbackoff.yaml` points at a deliberately nonsense image, `jakwehrgkaejw:kahsdfgkhj`:

```
$ kubectl get pod lifecycle-image-error
NAME                    READY   STATUS         RESTARTS   AGE
lifecycle-image-error   0/1     ErrImagePull   0          3m56s
```

`ErrImagePull` is the first failure; after a few retries it settles into `ImagePullBackOff`, the
same exponential back-off idea as above. I caught both states during the run — it was showing
`ImagePullBackOff` earlier and `ErrImagePull` when I took the table above, because it cycles
between them as it retries.

The distinction that matters in practice: this pod was scheduled fine (it has a node), so it is
not a capacity problem. The kubelet simply cannot fetch the image. Real causes are a typo in the
tag, a private registry with no `imagePullSecret`, or a deleted image.

---

## Probes — readiness, liveness, startup

Three different probes that people mix up constantly.

**Readiness** (`07-readiness.yaml`) decides whether a pod receives traffic:

```
$ kubectl get pod lifecycle-readiness
NAME                  READY   STATUS    RESTARTS   AGE
lifecycle-readiness   1/1     Running   0          3m40s
```

`READY 1/1` is the readiness probe passing. If it failed, the pod would stay `Running` but show
`0/1`, and every Service would pull it out of its endpoints. Failing readiness never restarts
anything — it just stops traffic.

**Liveness** (`08-liveness.yaml`) decides whether the container gets killed. This one creates
`/tmp/healthy`, sleeps 20 seconds, then deletes it — so the probe passes and then starts failing:

```yaml
livenessProbe:
  exec:
    command: ["sh", "-c", "test -f /tmp/healthy"]
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
```

With `periodSeconds: 5` and `failureThreshold: 2`, it takes about 10 seconds of failure after the
file disappears before the kubelet restarts the container. It was still at 0 restarts in the table
above because that first cycle had not elapsed yet. Checking back later, it had:

```
$ kubectl get pod lifecycle-liveness
NAME                 READY   STATUS    RESTARTS       AGE
lifecycle-liveness   1/1     Running   1 (159m ago)   163m

$ kubectl describe pod lifecycle-liveness | grep -iE "Unhealthy|Killing|Liveness"
  Warning  Unhealthy  160m               kubelet  Liveness probe failed: command timed out: "sh -c test -f /tmp/healthy" timed out after 1s
  Warning  Unhealthy  160m               kubelet  Liveness probe failed:
  Normal   Killing    160m               kubelet  Container app failed liveness probe, will be restarted
  Warning  Unhealthy  10s (x2 over 23s)  kubelet  Liveness probe failed:
```

`Container app failed liveness probe, will be restarted` is the kubelet saying it out loud. Note
the restart does **not** reset the container's filesystem to a fresh state in the way you might
expect from the script — it reruns the command, so it recreates `/tmp/healthy`, passes for another
20 seconds, and the cycle repeats. That is why it is still failing probes 160 minutes later.

**Startup** (`09-startup.yaml`) is the one people forget. It exists for slow-booting apps:
`failureThreshold: 10` with `periodSeconds: 5` gives the app 50 seconds to create `/tmp/started`,
and liveness/readiness are held off entirely until the startup probe passes once. Without it, a
liveness probe would kill a slow app before it ever finished booting.

| Probe | Fails → | Purpose |
|---|---|---|
| readiness | removed from Service endpoints | "can it take traffic right now" |
| liveness | container restarted | "is it wedged and needs a kick" |
| startup | container restarted, but only after the grace budget | "is it still booting" |

---

## Init containers

`10-init-container.yaml` has an init container that sleeps 10 seconds before the real container
starts. Caught mid-startup it shows its own status:

```
$ kubectl get pod lifecycle-init
NAME             READY   STATUS     RESTARTS   AGE
lifecycle-init   0/1     Init:0/1   0          26s
```

`Init:0/1` — zero of one init containers finished. Once done:

```
$ kubectl get pod lifecycle-init
NAME             READY   STATUS    RESTARTS   AGE
lifecycle-init   1/1     Running   0          3m38s
```

Init containers run **to completion, in order, before** any app container starts. If one fails the
pod never proceeds. They are how you wait for a database to be reachable or pull config down
before the app boots.

---

## Multi-container pods

`11-multi-container.yaml` is nginx plus a busybox sidecar:

```
$ kubectl get pod lifecycle-multi-container
NAME                        READY   STATUS    RESTARTS   AGE
lifecycle-multi-container   2/2     Running   0          3m37s
```

`2/2` — both containers ready. Unlike init containers these run **at the same time** for the whole
life of the pod, sharing the network namespace. The sidecar pattern (log shipper, proxy, metrics
exporter) is exactly this.

---

## Graceful termination

`12-termination.yaml` sets `terminationGracePeriodSeconds: 20` and traps `SIGTERM`:

```yaml
trap 'echo "SIGTERM received; cleaning up..."; sleep 10; echo "Cleanup complete"; exit 0' TERM
```

The shutdown sequence Kubernetes runs is worth knowing in order:

1. the pod is marked Terminating and **removed from Service endpoints straight away**, so it stops
   receiving new traffic
2. `SIGTERM` goes to PID 1 in the container
3. Kubernetes waits up to the grace period (20s here) for the process to exit on its own
4. if it is still alive at the deadline, `SIGKILL`

This container cleans up in 10 seconds, comfortably inside its 20-second budget, so it exits
cleanly and never gets killed. An app that ignores SIGTERM gets `SIGKILL`ed at 20 seconds and
drops whatever it was doing — which is how you end up with half-finished requests during a deploy.

---

## What I took away

The genuinely useful idea is that `STATUS` in `kubectl get pods` is a *diagnosis*, not a phase, and
it tells you where to look:

- `Pending` → the scheduler could not place it. Look at node capacity and requests.
- `ImagePullBackOff` → it was placed fine. Look at the image name and registry credentials.
- `CrashLoopBackOff` → it starts and dies. Look at `kubectl logs --previous`.
- `Running` but `0/1` → readiness is failing. It is alive but taking no traffic.

The back-off in both `CrashLoopBackOff` and `ImagePullBackOff` also explains something that used to
confuse me — a broken pod's restart count climbs far more slowly than you would expect, because
Kubernetes is deliberately waiting longer between each attempt.
