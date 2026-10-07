# Kubernetes Volumes

A container's filesystem is thrown away every time the container restarts. Volumes are how a pod
keeps data across restarts, shares files between containers, or reaches storage outside the node.
The example manifests from the course are in [manifests/](manifests/).

---

## emptyDir

An empty directory created when the pod is scheduled onto a node, and **deleted when the pod is
deleted**. It survives container restarts inside the pod, but not the pod itself.

```yaml
volumes:
  - name: cache
    emptyDir: {}          # or emptyDir: {medium: Memory} for a RAM-backed tmpfs
```

Used for: scratch space, caches, and sharing files between containers in the same pod — e.g. a
sidecar writing logs that the main container reads. See
[manifests/emptydir-pod.yaml](manifests/emptydir-pod.yaml).

## hostPath

Mounts a directory from the **node's own filesystem** into the pod.

```yaml
volumes:
  - name: host-logs
    hostPath:
      path: /var/log
      type: Directory
```

The data is tied to that one node: if the pod is rescheduled onto another node, it sees that
node's directory instead. It also gives the pod access to the host, which is a security risk.
In practice it's for node-level agents (log collectors, monitoring DaemonSets), not application
data. See [manifests/hostpath-pod.yaml](manifests/hostpath-pod.yaml).

## PersistentVolume (PV)

A piece of storage in the cluster that exists **independently of any pod** — a cloud disk, an NFS
share, a local disk. It's a cluster-level resource, usually created by an admin or by a provisioner.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata: {name: pv-demo}
spec:
  capacity: {storage: 1Gi}
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  hostPath: {path: /mnt/data}
```

The reclaim policy decides what happens when the claim is released: `Retain` keeps the data for
manual cleanup, `Delete` removes the underlying storage. See [manifests/pv.yaml](manifests/pv.yaml).

## PersistentVolumeClaim (PVC)

A **request** for storage made by a user or app: "I need 1Gi, ReadWriteOnce". Kubernetes binds the
claim to a PV that satisfies it. Pods reference the claim, never the PV directly, so the app doesn't
need to know what the storage actually is.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pvc-demo}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 1Gi}}
```

```yaml
# in the pod
volumes:
  - name: data
    persistentVolumeClaim: {claimName: pvc-demo}
```

See [manifests/pvc.yaml](manifests/pvc.yaml) and [manifests/pod.yaml](manifests/pod.yaml).

Access modes:

| Mode | Meaning |
|---|---|
| ReadWriteOnce (RWO) | read-write by a single node |
| ReadOnlyMany (ROX) | read-only by many nodes |
| ReadWriteMany (RWX) | read-write by many nodes (needs NFS, EFS or similar) |
| ReadWriteOncePod | read-write by a single pod |

## StorageClass

Describes a **type** of storage and which provisioner creates it — e.g. `gp3` SSD on AWS, or
`standard` on Minikube. A PVC names a StorageClass (or uses the default one).

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: fast}
provisioner: ebs.csi.aws.com
parameters: {type: gp3}
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

`WaitForFirstConsumer` delays creating the volume until a pod using it is scheduled, so the disk
is created in the same availability zone as the node that needs it.

## Dynamic provisioning

Without a StorageClass, an admin has to create PVs by hand before anyone can claim them (static
provisioning). With one, **creating the PVC is enough**: the provisioner sees the claim, creates
the PV automatically, and binds them.

This is what actually happened in my session 13 mini project. Its [pvc.yaml](../mini-project/pvc.yaml)
asks for 500Mi and names no PV and no StorageClass. Minikube's default `standard` StorageClass
(provisioner `k8s.io/minikube-hostpath`) created a PV for it and the claim went to `Bound` — see
`persistentvolumeclaim/web-data` in [the mini project screenshot](../screenshots/03-mini-project.png).
In session 10 the MySQL StatefulSet got three PVCs the same way, one per replica, from its
`volumeClaimTemplates`.

## Summary

| | Lifetime | Where the data lives | Typical use |
|---|---|---|---|
| emptyDir | the pod | node, temporarily | scratch space, sharing between containers |
| hostPath | the node | node's filesystem | node agents, DaemonSets |
| PV | independent of pods | external/cluster storage | app data that must survive |
| PVC | until deleted | a bound PV | how pods ask for a PV |
| StorageClass | — | — | describes a storage type and its provisioner |
| Dynamic provisioning | — | — | PVs created automatically from PVCs |
