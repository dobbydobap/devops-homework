# LoadBalancer Service (03-loadbalancer)

My run of the `03-loadbalancer` lab. Manifests in
[manifests/03-loadbalancer/](manifests/03-loadbalancer/).

A LoadBalancer Service asks the **cloud provider** to provision a real external load balancer and
hand back a public IP. On EKS you get an ELB, on GKE a Google load balancer, on AKS an Azure one.

```
$ kubectl apply -f 03-loadbalancer/
deployment.apps/web-app-loadbalancer created
service/web-service-loadbalancer created

$ kubectl get svc web-service-loadbalancer
NAME                       TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
web-service-loadbalancer   LoadBalancer   10.96.22.9   <pending>     80:31332/TCP   56s
```

## EXTERNAL-IP stays `<pending>` — and that is the correct result

The lab notes expect an external IP to appear. On my cluster it never will, and it is worth being
straight about why rather than pretending otherwise.

`kind` is a local cluster with no cloud provider behind it. When a LoadBalancer Service is
created, the cloud-controller-manager is supposed to notice it and go provision something. There
is no cloud-controller-manager here, so nothing ever claims the Service and `EXTERNAL-IP` sits at
`<pending>` forever. There is not even an event about it:

```
$ kubectl get events --field-selector involvedObject.name=web-service-loadbalancer
No resources found in default namespace.
```

Silence, because no controller is watching. That is the signature of this situation — as opposed
to a real cloud failure, which would log an error event about quota or permissions.

## It is still a working Service

The `<pending>` only affects the external IP. Everything underneath was still set up:

```
$ kubectl describe svc web-service-loadbalancer
Type:                     LoadBalancer
NodePort:                 http  31332/TCP
Endpoints:                10.244.0.79:80,10.244.0.80:80,10.244.0.81:80
```

It has a ClusterIP (`10.96.22.9`), three healthy endpoints, **and an automatically assigned
NodePort (31332)** that nobody asked for. Hitting that port works:

```
$ docker exec devops-heros-control-plane curl -s localhost:31332
<h1>Welcome to nginx!</h1>
```

That is the real lesson from this lab. The three types stack:

```
LoadBalancer  =  NodePort  +  cloud load balancer in front
NodePort      =  ClusterIP +  a port opened on every node
ClusterIP     =  the base, internal only
```

So a LoadBalancer Service is a NodePort Service that additionally asks a cloud for a front door.
Take the cloud away and you are left with a working NodePort — which is exactly what I have.

## Getting a real external IP locally

Two options if I needed one:

- **MetalLB** — a bare-metal load balancer implementation. You give it a pool of IPs from your
  network and it hands them out to LoadBalancer Services and answers ARP for them.
- **cloud-provider-kind** — a small controller made for exactly this, which watches for
  LoadBalancer Services on kind clusters and puts a container-based proxy in front of them.

I did not install either. The cluster was already memory-constrained during these labs, and the
`<pending>` result demonstrates the concept accurately — the Service is correct, the environment
simply has nothing to fulfil it.
