# ExternalName Service (04-externalname)

My run of the `04-externalname` lab. Manifests in
[manifests/04-externalname/](manifests/04-externalname/).

ExternalName is the odd one out. It creates no ClusterIP, selects no pods and load balances
nothing — it is purely a **DNS alias** inside the cluster pointing at a name outside it.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database-service
spec:
  type: ExternalName
  externalName: nencyravaliya.me
```

```
$ kubectl apply -f 04-externalname/service.yaml
service/external-database-service created

$ kubectl get svc external-database-service
NAME                        TYPE           CLUSTER-IP   EXTERNAL-IP        PORT(S)   AGE
external-database-service   ExternalName   <none>       nencyravaliya.me   <none>    16s
```

`CLUSTER-IP` is `<none>` and `PORT(S)` is `<none>`. There is nothing to connect to — there is only
a DNS record.

## What CoreDNS actually returns

```
$ kubectl exec headless-dns-client -- nslookup external-database-service
Server:		10.96.0.10
Address:	10.96.0.10:53

** server can't find external-database-service.cluster.local: NXDOMAIN
** server can't find external-database-service.svc.cluster.local: NXDOMAIN

external-database-service.default.svc.cluster.local	canonical name = nencyravaliya.me
```

The answer is `canonical name = nencyravaliya.me` — a **CNAME record**, not an A record. CoreDNS
does not resolve it to an IP for you; it hands back "go look up this other name instead" and the
client does a second lookup.

The `NXDOMAIN` lines above it are not errors. They are the pod's DNS search path being tried in
order (`.cluster.local`, `.svc.cluster.local`, then `.default.svc.cluster.local`) until one hits.
That is normal resolver behaviour and you see it on every in-cluster lookup.

## Why this is useful

The point is indirection. Suppose your app connects to `external-database-service` and that
currently maps to a managed database at some vendor hostname. When you migrate that database, you
change **one Service manifest** and every pod follows — no config change, no redeploy, no restart.

It also lets you write the same code across environments: in production `external-database-service`
is an ExternalName pointing at RDS, and in dev it is an ordinary ClusterIP pointing at a MySQL pod
in the cluster. The application just connects to `external-database-service` either way.

## Things that catch people out

- **No port mapping.** ExternalName ignores `ports:` entirely. Your client must use whatever port
  the external service actually listens on — the Service cannot remap it.
- **DNS only.** It does not proxy traffic, so there is no load balancing, no health checking and
  no network policy enforcement on it.
- **It must be a hostname, not an IP.** A CNAME has to point at a name. To alias a bare IP you
  need a Service without selectors plus a manual Endpoints object instead.
- **TLS and Host headers.** The client still sends the *external* name in SNI and the `Host`
  header, so certificates have to match `nencyravaliya.me`, not the in-cluster service name.

| | ClusterIP | ExternalName |
|---|---|---|
| Gets an IP | yes | no |
| Selects pods | yes | no |
| Proxies traffic | yes | no, DNS only |
| DNS record type | A | CNAME |
| Points at | pods in the cluster | a hostname outside it |
