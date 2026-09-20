# Headless Service (05-headless)

My run of the `05-headless` lab. Manifests in [manifests/05-headless/](manifests/05-headless/).

A headless Service is any Service with `clusterIP: None`. Instead of giving you one virtual IP
that load balances, DNS returns **the pod IPs directly** — and each pod gets its own DNS name.

```yaml
spec:
  clusterIP: None
  selector:
    app: web-headless
```

```
$ kubectl apply -f 05-headless/
statefulset.apps/web-stateful created
pod/headless-dns-client created
service/web-service-headless created

$ kubectl get svc web-service-headless
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
web-service-headless   ClusterIP   None         <none>        80/TCP    30s
```

`CLUSTER-IP` is literally `None`. There is no virtual IP, so `kube-proxy` has no iptables rules to
write for it and nothing is being proxied.

Three pods from the StatefulSet:

```
$ kubectl get pods -l app=web-headless -o wide
web-stateful-0 Running 10.244.0.84
web-stateful-1 Running 10.244.0.85
web-stateful-2 Running 10.244.0.86
```

## DNS returns every pod, not one IP

```
$ kubectl exec headless-dns-client -- nslookup web-service-headless
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.0.86
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.0.84
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.0.85
```

Three A records for one name — the actual pod IPs `10.244.0.84`, `.85` and `.86`, matching the
`kubectl get pods` output exactly. A normal ClusterIP Service would have returned a single virtual
IP like `10.96.x.x` and hidden the pods entirely.

The client now picks a pod itself. Load balancing became the caller's problem, which is the whole
point: the caller is trusted to care *which* backend it talks to.

## Per-pod DNS names

This is the part that makes StatefulSets work:

```
$ kubectl exec headless-dns-client -- nslookup web-stateful-0.web-service-headless.default.svc.cluster.local
Name:	web-stateful-0.web-service-headless.default.svc.cluster.local
Address: 10.244.0.84
```

`10.244.0.84` is exactly `web-stateful-0`'s IP. The pattern is:

```
<pod-name>.<headless-service>.<namespace>.svc.cluster.local
```

So every pod has a stable, individually addressable name. Combine that with the StatefulSet's
stable pod names from [../kubernetes-core-objects/core-objects.md](../kubernetes-core-objects/core-objects.md)
and `web-stateful-0` is always reachable at the same DNS name with the same data attached — even
after it is rescheduled onto a different node with a different IP.

This is the gap I flagged in the session 10 StatefulSet write-up: that manifest set
`serviceName: "mysql"` but never included the headless Service, so its `mysql-0.mysql` names could
not resolve. This lab is the missing half.

## Where it is used for real

- **Databases with replication** — a replica needs to talk to *the primary*, not "any database
  pod". Round-robin across a ClusterIP would be actively wrong.
- **Clustered systems** — Kafka, Cassandra, Elasticsearch, etcd. Members discover each other by
  stable name and form a quorum.
- **gRPC clients** — gRPC holds long-lived HTTP/2 connections, so a ClusterIP pins each client to
  one pod for the connection's lifetime. Clients that resolve all pod IPs can balance per-request
  themselves.

| | ClusterIP | Headless (`clusterIP: None`) |
|---|---|---|
| Virtual IP | yes | none |
| DNS returns | one service IP | every pod IP |
| Load balancing | kube-proxy does it | the client does it |
| Per-pod DNS names | no | yes |
| Use for | stateless apps | StatefulSets, clustered databases |
