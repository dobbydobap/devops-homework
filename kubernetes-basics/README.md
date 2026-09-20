# Session 9 — Kubernetes Basics and Cluster Architecture

The session 9 folder in the course repo is a set of resource links rather than a lab, so I worked
through the Kubernetes Basics tutorial and the architecture docs it points at, and captured what
the cluster actually looks like from the inside.

Every output below came from a real run against my cluster.

## Setup: kind instead of minikube

The resources suggest minikube. minikube is not installed on my machine and the `kind` binary is
blocked by an Application Control policy here, so I used the kind cluster I already created for
session 11:

```
$ kubectl config current-context
kind-devops-heros

$ kubectl get nodes -o wide
NAME                         STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                              CONTAINER-RUNTIME
devops-heros-control-plane   Ready    control-plane   5d    v1.36.1   172.24.0.2    <none>        Debian GNU/Linux 13 (trixie)   6.18.33.1-microsoft-standard-WSL2 (amd64)   containerd://2.3.1
```

This is a single node cluster, so the one node is both the control plane and the worker. On a real
cluster those are separate machines. Note `kind` has removed the usual control-plane taint, which
is why ordinary pods are allowed to schedule here at all:

```
Taints:             <none>
```

One thing to flag about my setup:

```
$ kubectl version
Client Version: v1.34.1
Kustomize Version: v5.7.1
Server Version: v1.36.1
Warning: version difference between client (1.34) and server (1.36) exceeds the supported minor version skew of +/-1
```

My `kubectl` is two minor versions behind the cluster. Kubernetes only supports a skew of one, so
this warning is legitimate. Everything in these labs worked, but it is the kind of thing that
causes odd failures on newer API fields, and on a real cluster I would upgrade the client.

---

## The control plane

`cluster-info` shows where the API server lives:

```
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:64162
CoreDNS is running at https://127.0.0.1:64162/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

The port is a random localhost port because kind publishes the API server out of its node
container onto my machine.

Every control plane component runs as a pod in `kube-system`:

```
$ kubectl get pods -n kube-system
NAME                                                 READY   STATUS    RESTARTS        AGE
coredns-589f44dc88-r845z                             1/1     Running   6 (3m46s ago)   5d
coredns-589f44dc88-z4zrl                             1/1     Running   6 (3m45s ago)   5d
etcd-devops-heros-control-plane                      1/1     Running   0               2m22s
kindnet-m864c                                        1/1     Running   4 (3m46s ago)   3d6h
kube-apiserver-devops-heros-control-plane            1/1     Running   0               2m21s
kube-controller-manager-devops-heros-control-plane   1/1     Running   6 (3m46s ago)   5d
kube-proxy-pqhmv                                     1/1     Running   5 (3m46s ago)   5d
kube-scheduler-devops-heros-control-plane            1/1     Running   6 (3m45s ago)   5d
```

What each one is doing:

| Component | Job |
|---|---|
| `kube-apiserver` | the front door. Every `kubectl` command, every controller, every kubelet talks to this and nothing talks to etcd directly |
| `etcd` | the key-value store holding all cluster state. If you lose etcd you lose the cluster |
| `kube-scheduler` | watches for pods with no node assigned and picks a node based on resources, affinity and taints |
| `kube-controller-manager` | runs the control loops — it is what notices a ReplicaSet has 2 of 3 pods and creates the third |
| `kube-proxy` | programs iptables/IPVS on each node so Service IPs route to the right pod |
| `coredns` | cluster DNS. This is what lets a pod reach `backend` by name instead of by IP |
| `kindnet` | kind's CNI plugin, handling the pod network. On a real cluster this slot would be Calico, Flannel or similar |

The restart counts are from my machine sleeping and Docker Desktop being restarted, not from
anything being broken.

The default namespaces:

```
$ kubectl get namespaces
NAME                 STATUS   AGE
default              Active   5d
kube-node-lease      Active   5d
kube-public          Active   5d
kube-system          Active   5d
local-path-storage   Active   5d
```

`local-path-storage` is kind's built-in storage provisioner. It matters later — it is what lets the
StatefulSet in session 10 actually bind a volume instead of hanging on a Pending PVC.

---

## The basic kubectl workflow

Creating a pod imperatively:

```
$ kubectl run hello-k8s --image=nginx:alpine --restart=Never
pod/hello-k8s created

$ kubectl get pod hello-k8s -o wide
NAME        READY   STATUS    RESTARTS   AGE   IP           NODE                         NOMINATED NODE   READINESS GATES
hello-k8s   1/1     Running   0          21s   10.244.0.7   devops-heros-control-plane   <none>           <none>
```

The pod got IP `10.244.0.7` from the cluster pod CIDR, and the scheduler placed it on the only
node available.

`describe` is the command I would reach for first when something is wrong, because the Events at
the bottom are a narrative of what happened:

```
$ kubectl describe pod hello-k8s | tail -12
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  20s   default-scheduler  Successfully assigned default/hello-k8s to devops-heros-control-plane
  Normal  Pulling    20s   kubelet            Pulling image "nginx:alpine"
  Normal  Pulled     1s    kubelet            Successfully pulled image "nginx:alpine" in 19.204s (19.204s including waiting). Image size: 26335703 bytes.
  Normal  Created    1s    kubelet            Container created
  Normal  Started    1s    kubelet            Container started
```

You can read the whole lifecycle there: the scheduler assigned it, then the kubelet pulled the
image (19 seconds), created the container and started it. `QoS Class: BestEffort` is because I set
no resource requests or limits.

Logs and exec:

```
$ kubectl logs hello-k8s | tail -5
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf

$ kubectl exec hello-k8s -- nginx -v
nginx version: nginx/1.31.6

$ kubectl exec hello-k8s -- hostname
hello-k8s
```

The pod's hostname is the pod name, which is worth remembering — it is how you tell replicas apart
when you are load balancing across them.

```
$ kubectl delete pod hello-k8s
pod "hello-k8s" deleted from default namespace
```

---

## What I took away

The part that made the architecture click was that the control plane is just pods. `etcd`,
the scheduler and the controller manager are containers on the node like anything else, and the
API server is the only thing any of them speak to. Nothing reaches into etcd on its own.

The other thing is how much of Kubernetes is a control loop rather than a command. `kubectl run`
does not create a container — it records the desired state in etcd through the API server, and
then the scheduler and kubelet independently notice and act on it. That is why a deleted pod under
a Deployment comes straight back: nothing "restarted" it, the controller simply saw that observed
state no longer matched desired state.

## Commands used

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl version
kubectl get pods -n kube-system
kubectl get namespaces
kubectl describe node <node>
kubectl run <name> --image=<image> --restart=Never
kubectl get pod <name> -o wide
kubectl describe pod <name>
kubectl logs <name>
kubectl exec <name> -- <command>
kubectl delete pod <name>
```
