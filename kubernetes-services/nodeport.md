# NodePort Service (02-nodeport)

My run of the `02-nodeport` lab. Manifests in [manifests/02-nodeport/](manifests/02-nodeport/).

NodePort opens the same port on **every node** in the cluster and forwards it to the Service. It
builds on ClusterIP rather than replacing it — the ClusterIP is still there and still works.

```
$ kubectl apply -f 02-nodeport/
deployment.apps/web-app-nodeport created
service/web-service-nodeport created

$ kubectl get svc web-service-nodeport
NAME                   TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
web-service-nodeport   NodePort   10.96.149.44   <none>        80:30080/TCP   24s
```

`80:30080/TCP` is the thing to read carefully — port `80` is the Service port inside the cluster,
`30080` is the port opened on the node. The manifest pins `nodePort: 30080`; leave it out and
Kubernetes picks one from 30000–32767.

```
$ kubectl get endpoints web-service-nodeport
NAME                   ENDPOINTS                       AGE
web-service-nodeport   10.244.0.77:80,10.244.0.78:80   24s
```

Two pod IPs behind it, same as a ClusterIP would have.

## Reaching it

The node's internal IP:

```
$ kubectl get nodes -o wide
devops-heros-control-plane 172.24.0.2
```

From a pod inside the cluster, hitting the node IP on the nodePort:

```
$ kubectl run np-probe --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- 172.24.0.2:30080
<h1>Welcome to nginx!</h1>
```

And from inside the kind node container itself, which is the closest thing I have to "the node":

```
$ docker exec devops-heros-control-plane curl -s localhost:30080
<h1>Welcome to nginx!</h1>
```

## What does not work here, and why

On a real cluster you would now browse to `http://<any-node-public-ip>:30080`. On my setup that
fails:

```
$ curl -s --max-time 5 http://localhost:30080
(curl exit: 7 — connection refused)
```

This is not the Service being broken. kind runs the whole "node" as a Docker container inside the
WSL2 VM, so port 30080 is open on **that container's** network namespace (172.24.0.2), not on
Windows. Windows never had anything listening on 30080.

To reach it from Windows you would have to create the kind cluster with an `extraPortMappings`
entry publishing 30080, like this:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
```

I could not redo that here — the `kind` binary is blocked by an Application Control policy on this
machine, so I cannot delete and recreate the cluster. The two checks above prove the Service works;
only the last hop to Windows is missing. `kubectl port-forward svc/web-service-nodeport 8080:80`
is the other way round it.

## When you would actually use it

Rarely on its own. NodePort is mostly a building block — it is what a LoadBalancer Service and
most Ingress controllers sit on top of. Using it directly means hard-coding node IPs and living
with the 30000–32767 range, which is why production traffic normally comes in through a
LoadBalancer or an Ingress instead.

| | ClusterIP | NodePort |
|---|---|---|
| Reachable from inside cluster | yes | yes |
| Reachable from outside | no | yes, on every node IP |
| Port range | any | 30000–32767 |
| Gets a ClusterIP too | — | yes, NodePort is a superset |
