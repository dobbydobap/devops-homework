# Kubernetes Core Objects

The five objects from `session10-k8s-core-objects/k8s-core-objects/`, applied unmodified to my kind
cluster. Manifests are in [manifests/](manifests/).

---

## Pod

A pod is the smallest thing Kubernetes schedules. It is not "a container" — it is one or more
containers that share a network namespace and storage, and always land on the same node together.

The lab's `pod.yml` has two containers, nginx and a busybox logger:

```
$ kubectl apply -f pod.yml
pod/mypod created

$ kubectl get pod mypod -o wide
NAME    READY   STATUS    RESTARTS   AGE   IP           NODE                         NOMINATED NODE   READINESS GATES
mypod   2/2     Running   0          27s   10.244.0.8   devops-heros-control-plane   <none>           <none>
```

`READY 2/2` is the thing to notice — two containers, both up, but one pod and **one** IP address
(`10.244.0.8`). The two containers share that IP, so they can reach each other on `localhost`.

```
$ kubectl get pod mypod -o jsonpath="{.spec.containers[*].name}"
app logger
```

With more than one container you have to say which one you want logs from:

```
$ kubectl logs mypod -c logger | head -3
log
```

That is the busybox loop printing `log` every five seconds.

A bare pod like this has nobody watching it. Delete it and it stays deleted — there is no
controller to bring it back. That is what the next two objects are for.

---

## ReplicaSet

A ReplicaSet's entire job is to keep N copies of a pod running.

```
$ kubectl apply -f replicaset.yml
replicaset.apps/myapp-rs created

$ kubectl get rs myapp-rs
NAME       DESIRED   CURRENT   READY   AGE
myapp-rs   3         3         3       12s

$ kubectl get pods -l app=web
NAME             READY   STATUS    RESTARTS   AGE
myapp-rs-l7m6b   1/1     Running   0          12s
myapp-rs-trxnm   1/1     Running   0          12s
myapp-rs-zkbt6   1/1     Running   0          12s
```

The self-healing is the part worth proving rather than taking on trust. Delete one pod:

```
$ kubectl delete pod myapp-rs-l7m6b
pod "myapp-rs-l7m6b" deleted from default namespace

$ kubectl get pods -l app=web
NAME             READY   STATUS    RESTARTS   AGE
myapp-rs-trxnm   1/1     Running   0          20s
myapp-rs-vlh4z   1/1     Running   0          7s
myapp-rs-zkbt6   1/1     Running   0          20s
```

`myapp-rs-l7m6b` is gone and `myapp-rs-vlh4z` has appeared, 7 seconds old against the other two at
20 seconds. Nothing restarted the old pod — the controller noticed observed state (2) no longer
matched desired state (3) and created a **new** pod to close the gap. The name is different
because it genuinely is a different pod.

The ReplicaSet finds its pods by label, via `selector.matchLabels: app: web`. That coupling is
worth remembering: if the selector and the pod template labels disagree, the ReplicaSet creates
pods forever because it can never find the ones it just made.

---

## Deployment

You almost never write a ReplicaSet yourself. You write a Deployment, and it manages ReplicaSets
for you — which is what makes rollouts and rollbacks possible.

```
$ kubectl apply -f deployment.yml
deployment.apps/myapp created

$ kubectl get deployment myapp
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
myapp   3/3     3            3           13s
```

The Deployment created a ReplicaSet without being asked:

```
$ kubectl get rs -l app=myapp
NAME               DESIRED   CURRENT   READY   AGE
myapp-7bf644ff86   3         3         3       13s

$ kubectl get pods -l app=myapp
NAME                     READY   STATUS    RESTARTS   AGE
myapp-7bf644ff86-bzkk4   1/1     Running   0          14s
myapp-7bf644ff86-ntdnd   1/1     Running   0          14s
myapp-7bf644ff86-zhwbj   1/1     Running   0          14s
```

So the ownership chain is **Deployment → ReplicaSet → Pods**, and the pod names show it:
`myapp` + `7bf644ff86` (the ReplicaSet's pod-template hash) + a per-pod suffix. That hash is
derived from the pod template, so changing the image produces a *new* ReplicaSet — which is
exactly how a rolling update works, covered in [rollout-strategies.md](rollout-strategies.md).

Scaling:

```
$ kubectl scale deployment myapp --replicas=5
deployment.apps/myapp scaled

$ kubectl get deployment myapp
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
myapp   5/5     5            5           23s
```

---

## DaemonSet

A DaemonSet runs exactly one copy of a pod on every node — no replica count, because the count
*is* the number of nodes. It is what monitoring agents, log shippers and CNI plugins use.

```
$ kubectl apply -f deamonset.yml
daemonset.apps/node-exporter created

$ kubectl get daemonset node-exporter
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
node-exporter   1         1         1       1            1           <none>          16s

$ kubectl get pods -l app=node-exporter -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP            NODE                         NOMINATED NODE   READINESS GATES
node-exporter-2fcvh   1/1     Running   0          17s   10.244.0.18   devops-heros-control-plane   <none>           <none>
```

`DESIRED 1` because my cluster has exactly one node. Nobody typed a 1 anywhere — the DaemonSet
controller counted the nodes. Add a second node and a second pod appears on it automatically.
`kindnet` and `kube-proxy` from session 9 are DaemonSets for the same reason.

---

## StatefulSet

A Deployment treats its pods as interchangeable. A StatefulSet does the opposite: stable names,
stable storage, and ordered startup. That is what databases need.

The lab's `statefulset.yml` runs 3 MySQL replicas, each with its own 5Gi volume:

```
$ kubectl apply -f statefulset.yml
statefulset.apps/mysql created
```

Catching it partway through shows the ordering:

```
$ kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   0/1     Pending   0          9s
```

Only `mysql-0` exists. A Deployment would have fired all three off at once; a StatefulSet waits
for each pod to be Ready before starting the next. Once finished:

```
$ kubectl get statefulset mysql
NAME    READY   AGE
mysql   3/3     3m14s

$ kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   1/1     Running   0          3m14s
mysql-1   1/1     Running   0          106s
mysql-2   1/1     Running   0          77s
```

The ages confirm the sequence — `mysql-0` is 3m14s, `mysql-1` 106s, `mysql-2` 77s. They started in
order, not together.

The names are `mysql-0/1/2`, not random hashes. Each got its own PersistentVolumeClaim from the
`volumeClaimTemplates`:

```
$ kubectl get pvc
NAME                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
mysql-persistent-storage-mysql-0   Bound    pvc-2f6eced3-d3a7-4de7-b2c1-b51044f680c6   5Gi        RWO            standard       <unset>                 3m15s
mysql-persistent-storage-mysql-1   Bound    pvc-30eab256-f807-4e8e-89dc-84309ba488aa   5Gi        RWO            standard       <unset>                 106s
mysql-persistent-storage-mysql-2   Bound    pvc-aa7ff3b6-cfb2-4800-ba6b-a501bd107fa9   5Gi        RWO            standard       <unset>                 77s
```

Three separate `Bound` volumes, one per pod, named after the pod they belong to. They bound
because kind ships a default StorageClass:

```
$ kubectl get sc
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  5d
```

On a cluster with no default StorageClass these PVCs would sit at `Pending` forever and the
StatefulSet would never start.

### Stable identity

Deleting a StatefulSet pod shows the difference from a ReplicaSet:

```
$ kubectl delete pod mysql-1
pod "mysql-1" deleted from default namespace

$ kubectl get pods -l app=mysql
NAME      READY   STATUS              RESTARTS   AGE
mysql-0   1/1     Running             0          4m7s
mysql-1   0/1     ContainerCreating   0          9s
mysql-2   1/1     Running             0          2m10s
```

It came back as **`mysql-1`** — the same name, and it reattaches to the same PVC. Compare that to
the ReplicaSet earlier, where the replacement got a brand new random name. That stable identity is
the whole point: `mysql-0` is always the same member of the cluster with the same data.

One gap in the lab manifest worth noting: it declares `serviceName: "mysql"` but no headless
Service is included, so the per-pod DNS names like `mysql-0.mysql` do not resolve as written. The
headless Service that makes that work is covered in
[../kubernetes-services/headless.md](../kubernetes-services/headless.md).

---

## Summary

| Object | Keeps | Pod names | Use for |
|---|---|---|---|
| Pod | nothing, no controller | fixed, as written | one-off debugging |
| ReplicaSet | N identical pods | random suffix | almost never directly |
| Deployment | N pods + rollout history | RS hash + suffix | stateless apps |
| DaemonSet | one pod per node | node-based | agents, log shippers, CNI |
| StatefulSet | N pods, ordered, with storage | ordinal (`-0`, `-1`) | databases, quorum systems |
