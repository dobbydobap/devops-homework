# Session 11 — Kubernetes Networking and Services

My runs of the session 11 service labs, one file per service type. Every output was copied from an
actual run on my kind cluster (`kind-devops-heros`), not from the lab notes.

| Service type | Write-up | What it gives you |
|---|---|---|
| ClusterIP | [clusterip.md](clusterip.md) | one internal virtual IP, load balanced across pods |
| NodePort | [nodeport.md](nodeport.md) | a port on every node, reachable from outside the cluster |
| LoadBalancer | [loadbalancer.md](loadbalancer.md) | a cloud-provisioned external IP in front of a NodePort |
| ExternalName | [externalname.md](externalname.md) | a CNAME alias to a hostname outside the cluster |
| Headless | [headless.md](headless.md) | no virtual IP — DNS returns the pod IPs directly |

Manifests are in [manifests/](manifests/), copied unmodified from the course repo, except the
ClusterIP lab's three files which sit at the top level of this folder from when I did that one.

## The core idea

Pods are disposable and their IPs change every time one is replaced. A Service is a stable name
and address in front of a set of pods, chosen by label selector, so callers never have to know or
care which pods currently exist.

The four IP-based types build on each other rather than being alternatives:

```
ExternalName   - a DNS CNAME, no IP, no proxying at all (the odd one out)

LoadBalancer   = NodePort  + a cloud load balancer in front
NodePort       = ClusterIP + a port opened on every node
ClusterIP      = the base: one virtual IP, internal only

Headless       = ClusterIP with clusterIP: None - no virtual IP, DNS returns every pod
```

I confirmed that stacking directly in the LoadBalancer lab: the LoadBalancer Service had a
ClusterIP *and* an automatically assigned NodePort it was never asked for.

## Ports, which is the part that trips people up

```
nodePort    30080   the port opened on each node        (30000-32767)
port        80      the Service's own port, cluster-internal
targetPort  80      the port the container listens on
```

## Environment notes

Two results in these labs differ from the lab notes, and both are the environment rather than a
mistake:

- **LoadBalancer stays `<pending>`.** kind has no cloud provider to fulfil the request, so nothing
  ever assigns an external IP. Documented properly in [loadbalancer.md](loadbalancer.md).
- **NodePort is not reachable from Windows.** The kind "node" is a container inside the WSL2 VM,
  so port 30080 is open there and not on Windows. I verified it from inside the cluster and from
  the node container instead. Details in [nodeport.md](nodeport.md).

I could not work around either by rebuilding the cluster, because the `kind` binary is blocked by
an Application Control policy on this machine.
