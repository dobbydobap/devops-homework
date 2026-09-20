# Session 10 — Kubernetes Pods, ReplicaSets and Deployments

My run of the session 10 material, split into three parts so each stays readable. Every command
output was copied from an actual run on my kind cluster (`kind-devops-heros`).

| Write-up | Covers |
|---|---|
| [core-objects.md](core-objects.md) | Pod, ReplicaSet, Deployment, DaemonSet, StatefulSet |
| [pod-lifecycle.md](pod-lifecycle.md) | all 12 lifecycle states, probes, init and multi-container pods |
| [rollout-strategies.md](rollout-strategies.md) | rolling update, blue-green, canary, recreate |

Manifests, copied unmodified from the course repo:

- [manifests/](manifests/) — the five core objects
- [pod-lifecycle/](pod-lifecycle/) — the twelve lifecycle pods
- [rollout-strategies/](rollout-strategies/) — the four deployment strategies

## The through-line

The single idea that connects all three parts is that Kubernetes is a set of **control loops**,
not a command runner. You record the state you want, and a controller works continuously to close
the gap between that and reality.

Everything below is the same loop wearing different clothes:

- delete a pod from a ReplicaSet and a **new** one appears with a different name, because the
  controller saw 2 where it wanted 3
- change a Deployment's image and it creates a second ReplicaSet, scaling one up while scaling the
  other down — that is all a rolling update is
- `kubectl rollout undo` is instant because the old ReplicaSet was never deleted, only scaled to 0
- a blue-green switch moves no pods at all; editing the Service selector makes the endpoints
  controller recalculate which pods match

It also explains the failure states. A pod stuck `Pending` is a loop that cannot proceed because
the scheduler has nowhere to put it, and `CrashLoopBackOff` is a loop deliberately slowing itself
down so a broken container cannot spin the node.

## Environment note

Everything ran on a single-node kind cluster on Docker Desktop (WSL2). Two things worth recording:

- The StatefulSet lab runs 3 replicas of `mysql:5.7` with 5Gi volumes each. On this machine
  (15.6GB RAM, WSL capped at 8GB) that was enough to push the VM into memory pressure and take the
  API server offline for a while. I captured the StatefulSet output first, then deleted it before
  running the rollout strategy labs.
- The PVCs bound because kind ships a default StorageClass (`standard`, local-path). On a cluster
  without one they would have stayed `Pending` and the StatefulSet would never have started.
