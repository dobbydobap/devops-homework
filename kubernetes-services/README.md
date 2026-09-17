# Session 11 — ClusterIP Service (01-clusterip)

My run of the `01-clusterip` lab from the session 11 Kubernetes Services material.
Every output below was copied from an actual run on my machine, not from the lab notes.

## Setup: kind instead of minikube

The lab says `minikube start`. minikube is not installed on my machine, and I already had
`kind` and Docker Desktop (WSL2 backend), so I ran the whole lab on a kind cluster I created
just for this session:

```bash
kind create cluster --name devops-heros
```

```
$ kubectl config current-context
kind-devops-heros

$ kubectl get nodes -o wide
NAME                         STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                              CONTAINER-RUNTIME
devops-heros-control-plane   Ready    control-plane   42h   v1.36.1   172.24.0.2    <none>        Debian GNU/Linux 13 (trixie)   6.18.33.1-microsoft-standard-WSL2 (amd64)   containerd://2.3.1
```

Nothing else in the lab changed — every `kubectl` command is exactly the one in the lab README.
The manifests in this folder are copies of the lab's three files, unmodified.

Two differences from the expected output in the lab notes, both harmless:

- **My IPs are different.** Pod and service IPs are allocated per cluster, so my ClusterIP is
  `10.96.225.143` and not the `10.96.150.45` in the notes.
- **`kubectl get endpoints` now prints a deprecation warning.** This cluster is v1.36, and the
  `v1 Endpoints` object was deprecated in v1.33 in favour of `discovery.k8s.io/v1 EndpointSlice`.
  The command still works and shows the same data.

---

## Step 1 — Deploy the backend web application

```
$ kubectl apply -f app-deployment.yaml
deployment.apps/web-app-clusterip created

$ kubectl get pods -l app=web-clusterip -o wide
NAME                                 READY   STATUS    RESTARTS   AGE   IP            NODE                         NOMINATED NODE   READINESS GATES
web-app-clusterip-86f7fc5489-d6xtc   1/1     Running   0          3s    10.244.0.11   devops-heros-control-plane   <none>           <none>
web-app-clusterip-86f7fc5489-h9rfg   1/1     Running   0          3s    10.244.0.13   devops-heros-control-plane   <none>           <none>
web-app-clusterip-86f7fc5489-pp6z8   1/1     Running   0          3s    10.244.0.12   devops-heros-control-plane   <none>           <none>
```

Three pods, three different IPs (`10.244.0.11`, `.12`, `.13`). These are the ephemeral pod IPs
the lab describes — the ones you must not hardcode in a frontend, because they change whenever
a pod is rescheduled.

## Step 2 — Deploy the ClusterIP Service

```
$ kubectl apply -f service.yaml
service/web-service-clusterip created

$ kubectl get svc web-service-clusterip
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
web-service-clusterip   ClusterIP   10.96.225.143   <none>        8080/TCP   0s
```

`EXTERNAL-IP` is `<none>` — this is the part that shows a ClusterIP has no way in from outside
the cluster.

## Step 3 — Inspect the endpoints

```
$ kubectl get endpoints web-service-clusterip
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                    ENDPOINTS                                      AGE
web-service-clusterip   10.244.0.11:80,10.244.0.12:80,10.244.0.13:80   1s
```

All three pod IPs are bound, on port 80 (`targetPort`), even though the service itself is
published on 8080 (`port`). That is the `port` → `targetPort` mapping from the lab.

---

## Testing the service (Method 1 — internal test pod)

```
$ kubectl apply -f client-pod.yaml
pod/curl-client created

$ kubectl get pod curl-client
NAME          READY   STATUS    RESTARTS   AGE
curl-client   1/1     Running   0          1s
```

### Test 1 — by service name (CoreDNS resolution)

```
$ kubectl exec curl-client -- curl -s http://web-service-clusterip:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### Test 2 — by ClusterIP

```
$ kubectl exec curl-client -- curl -s http://10.96.225.143:8080
```

Same nginx page (trimmed here to the two lines that matter):

```
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```

### Test 3 — by FQDN

```
$ kubectl exec curl-client -- curl -s http://web-service-clusterip.default.svc.cluster.local:8080
```

Same nginx page again. The FQDN breaks down as
`<service>.<namespace>.svc.cluster.local`.

I also checked what the name actually resolves to, which confirms the DNS name maps to the
ClusterIP from step 2:

```
$ kubectl exec curl-client -- nslookup web-service-clusterip.default.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-service-clusterip.default.svc.cluster.local
Address: 10.96.225.143
```

`10.96.0.10` is the CoreDNS service, which the lab's troubleshooting section says to check:

```
$ kubectl get pods -n kube-system -l k8s-app=kube-dns
NAME                       READY   STATUS    RESTARTS        AGE
coredns-589f44dc88-r845z   1/1     Running   2 (3m39s ago)   42h
coredns-589f44dc88-z4zrl   1/1     Running   2 (3m39s ago)   42h
```

## Testing the service (Method 2 — port-forward)

```
$ kubectl port-forward svc/web-service-clusterip 8080:8080
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080

$ curl http://localhost:8080
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
```

The page here is my custom one rather than the nginx default, because by this point I had
already run the load-balancing check below. The `Handling connection for 8080` line is printed
by `port-forward` each time a request comes through it.

Worth noting that `port-forward` is a debugging tunnel through the API server, not a real
network route — it only exists while the command is running, and only my machine can use it.
That is the difference between it and a NodePort.

---

## Extra check — proving the load balancing is real

The lab says kube-proxy load balances across the endpoints. The default nginx page looks
identical from every pod, so it cannot show this. I gave each pod its own page first:

```bash
for p in $(kubectl get pods -l app=web-clusterip -o jsonpath='{.items[*].metadata.name}'); do
  kubectl exec $p -- sh -c "echo 'Served by POD: $p' > /usr/share/nginx/html/index.html"
done
```

Then sent 12 requests to the one service name:

```
$ kubectl exec curl-client -- sh -c 'for i in $(seq 1 12); do curl -s http://web-service-clusterip:8080; done'
Served by POD: web-app-clusterip-86f7fc5489-pp6z8
Served by POD: web-app-clusterip-86f7fc5489-pp6z8
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-h9rfg
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
Served by POD: web-app-clusterip-86f7fc5489-pp6z8
Served by POD: web-app-clusterip-86f7fc5489-d6xtc
```

Over 30 requests, all three pods are used:

```
$ kubectl exec curl-client -- sh -c 'for i in $(seq 1 30); do curl -s http://web-service-clusterip:8080; done' | sort | uniq -c
     13 Served by POD: web-app-clusterip-86f7fc5489-d6xtc
     11 Served by POD: web-app-clusterip-86f7fc5489-h9rfg
      6 Served by POD: web-app-clusterip-86f7fc5489-pp6z8
```

The split is uneven because kube-proxy in iptables mode picks a backend at random per new
connection — it is not round-robin, so it only evens out over many requests.

---

## Cleanup

```
$ kubectl delete -f client-pod.yaml
pod "curl-client" deleted from default namespace

$ kubectl delete -f service.yaml
service "web-service-clusterip" deleted from default namespace

$ kubectl delete -f app-deployment.yaml
deployment.apps "web-app-clusterip" deleted from default namespace

$ kubectl get all -l app=web-clusterip
NAME                                     READY   STATUS        RESTARTS   AGE
pod/web-app-clusterip-86f7fc5489-d6xtc   1/1     Terminating   0          2m11s
pod/web-app-clusterip-86f7fc5489-h9rfg   1/1     Terminating   0          2m11s
pod/web-app-clusterip-86f7fc5489-pp6z8   1/1     Terminating   0          2m11s
```

---

## What I took away from this lab

- A ClusterIP is a stable name and virtual IP in front of a set of pods whose own IPs keep
  changing. The client only ever needs `web-service-clusterip:8080`.
- The service finds its pods by **label selector**, not by name. `spec.selector.app: web-clusterip`
  matching the pods' `app: web-clusterip` label is what populates the endpoints list — if those
  two do not match, the endpoints list comes back empty and every request fails, which is the
  first thing to check when a service does not work.
- `port` is the service's port, `targetPort` is the container's. They do not have to be the same,
  and here they are not (8080 → 80).
- A ClusterIP genuinely has no route in from outside. Reaching it from my laptop needed
  `port-forward`, which is a debug tunnel, not a way to expose anything for real.

## Reproducing this

```bash
kind create cluster --name devops-heros      # or: minikube start
kubectl apply -f app-deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f client-pod.yaml
kubectl exec curl-client -- curl -s http://web-service-clusterip:8080
```
