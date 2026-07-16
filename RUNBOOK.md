# RUNBOOK — nginx-kind

Step-by-step guide to build the lab and test **every** ingress scenario locally.
Every command is copy-paste-able. Run from the repo root.

> Convention: the demo hosts (`app.example.com`, `shop.example.com`, …) are not
> real DNS. We reach them with `curl --resolve <host>:<port>:127.0.0.1`, which
> tells curl "pretend this host resolves to localhost" — no `/etc/hosts` edits.

---

## 0. Prerequisites check

```bash
docker version --format '{{.Server.Version}}'   # 24+
kind version
kubectl version --client -o yaml | grep gitVersion
helm version --short
terraform version | head -1
```

Install Ansible into a local virtualenv (no sudo needed):

```bash
make install-ansible
```

---

## 1. Create the cluster

```bash
make cluster
```

This creates a 2-node kind cluster named `nginx-kind` with host ports **80** and
**443** mapped into the control-plane node (labeled `ingress-ready=true`).

Verify:

```bash
kubectl get nodes
# NAME                        STATUS   ROLES           AGE   VERSION
# nginx-kind-control-plane    Ready    control-plane   1m    v1.3x
# nginx-kind-worker           Ready    <none>          1m    v1.3x
# nginx-kind-worker2          Ready    <none>          1m    v1.3x
```

---

## 2. Provision infrastructure (Terraform)

```bash
make infra
```

Installs:
- **ingress-nginx** (namespace `ingress-nginx`, hostPort 80/443, single replica)
- **PostgreSQL** StatefulSet + headless Service (namespace `data`)
- **demo apps** app1, app2, shop, api, blog, canary-stable, canary-canary + **Adminer** (namespace `apps`)

Verify:

```bash
kubectl -n ingress-nginx get pods
kubectl -n apps get pods,svc
kubectl -n data get pods,svc,pvc
```

Wait until the ingress controller pod is `Running`/`Ready` before continuing:

```bash
kubectl -n ingress-nginx wait --for=condition=ready pod \
  -l app.kubernetes.io/component=controller --timeout=180s
```

---

## 3. Post-config (Ansible)

```bash
make config
```

This:
1. generates a self-signed cert (SAN = all demo hosts) → `demo-tls` Secret
2. generates an htpasswd (`admin` / `secret123`) → `basic-auth` Secret
3. applies all 8 ingress manifests
4. seeds a `visitors` table in PostgreSQL
5. runs a quick smoke test

Verify the ingresses landed:

```bash
kubectl -n apps get ingress
```

---

## 4. Test every scenario (automated)

```bash
make test
```

Expected tail:

```
  Results: 12 passed, 0 failed
```

The sections below reproduce each check **manually** so you can see the raw
behaviour.

---

## 5. Manual scenario walkthrough

### 5.1 Path-based routing
```bash
curl -s --resolve app.example.com:80:127.0.0.1 http://app.example.com/app1 | grep Name
curl -s --resolve app.example.com:80:127.0.0.1 http://app.example.com/app2 | grep Name
```
Expect `Name: app1` then `Name: app2` — same host, different path → different Service.

### 5.2 Host-based routing
```bash
for h in shop api blog; do
  echo "== $h =="
  curl -s --resolve $h.example.com:80:127.0.0.1 http://$h.example.com/ | grep Name
done
```
Each host is served by its own backend (`Name: shop|api|blog`).

### 5.3 TLS termination
```bash
# HTTPS works (self-signed, so -k):
curl -sk --resolve secure.example.com:443:127.0.0.1 https://secure.example.com/ | grep Name
# Plain HTTP is redirected to HTTPS:
curl -s -o /dev/null -w "%{http_code}\n" --resolve secure.example.com:80:127.0.0.1 http://secure.example.com/
```
Expect the HTTPS call to return the whoami body and the HTTP call to return `308`.

### 5.4 URL rewrite
```bash
curl -s --resolve rewrite.example.com:80:127.0.0.1 http://rewrite.example.com/svc/hello | grep '^GET'
```
Expect `GET /hello HTTP/1.1` — the `/svc` prefix was stripped before the backend.

### 5.5 Rate limiting
```bash
seq 1 40 | xargs -P10 -I{} curl -s -o /dev/null -w "%{http_code}\n" \
  --resolve ratelimit.example.com:80:127.0.0.1 http://ratelimit.example.com/ | sort | uniq -c
```
Expect a mix of `200` and `503` — excess requests are throttled.

### 5.6 Basic auth
```bash
# no creds -> 401
curl -s -o /dev/null -w "%{http_code}\n" --resolve auth.example.com:80:127.0.0.1 http://auth.example.com/
# with creds -> 200
curl -s -o /dev/null -w "%{http_code}\n" -u admin:secret123 --resolve auth.example.com:80:127.0.0.1 http://auth.example.com/
```

### 5.7 Canary / weighted split
```bash
for i in $(seq 1 40); do
  curl -s --resolve canary.example.com:80:127.0.0.1 http://canary.example.com/ | grep '^Name'
done | sort | uniq -c
```
Expect ~70% `canary-stable` and ~30% `canary-canary` (the `canary-weight: 30`).
`canary-stable` runs 2 replicas — the varying `Hostname:` lines show HA/load-balancing.

### 5.8 DB-backed app through ingress
```bash
# Adminer is reachable through the ingress:
curl -s -o /dev/null -w "%{http_code}\n" --resolve db.example.com:80:127.0.0.1 http://db.example.com/
# Postgres has the seeded data:
kubectl -n data exec statefulset/postgres -- \
  env PGPASSWORD=apppass123 psql -U appuser -d appdb -c "SELECT * FROM visitors;"
```
In a browser (see below) open `http://db.example.com`, log in with
System=PostgreSQL, Server=`postgres.data.svc.cluster.local`, User=`appuser`,
Password=`apppass123`, DB=`appdb`.

### 5.9 Default backend
```bash
curl -s -o /dev/null -w "%{http_code}\n" --resolve nope.example.com:80:127.0.0.1 http://nope.example.com/
```
Expect `404` from the default backend (no rule matched).

---

## 5.10 Ingress controller High Availability (MetalLB LoadBalancer)

The 9 scenarios above run a **single** controller replica on the control-plane
node, bound to `localhost:80/443` via hostPort. That is deliberate for simple
local access — but it is *not* the HA topology from the usecase diagram
(*External LoadBalancer → Replica 1 / 2 / N → Services → Pods*).

HA is available as a **toggle** that switches the controller to multiple
replicas behind a real LoadBalancer, without disturbing the default path.

**What flips when `ingress_ha_enabled=true`:**

| | Default | HA mode |
|---|---|---|
| Replicas | 1 | `ingress_replica_count` (3 = one per node) |
| Scheduling | pinned to control-plane | one per node (required pod anti-affinity) |
| Service type | NodePort + hostPort | `LoadBalancer` (MetalLB) + hostPort |
| Reached via | `localhost:80` | `localhost:80` *and* the MetalLB IP |

Both modes stay reachable on `localhost:80`, because HA mode keeps `hostPort`
and tolerates the control-plane taint so one replica still lands there. kind
maps host 80/443 into the control-plane node only, so a replica has to be
running there or nothing answers on localhost — the LoadBalancer IP alone is
not enough, since it is unreachable from Windows.

`ingress_replica_count` should equal the node count. The anti-affinity is
required-during-scheduling, so extra replicas beyond one-per-node sit `Pending`
forever.

```bash
# The cluster must already have 2 workers (kind/cluster.yaml). If you built it
# before this change, recreate it:  make down && make cluster

# Enable HA and apply. MetalLB is installed automatically when this is set.
terraform -chdir=terraform apply -auto-approve \
  -var ingress_ha_enabled=true -var ingress_replica_count=3

# Three controller replicas, one per node:
kubectl -n ingress-nginx get pods -o wide -l app.kubernetes.io/component=controller

# The Service is now type LoadBalancer with an EXTERNAL-IP from the pool:
kubectl -n ingress-nginx get svc ingress-nginx-controller

# Grab the assigned IP and exercise the same scenarios against it:
LB_IP="$(terraform -chdir=terraform output -raw ingress_external_ip)"
echo "ingress LoadBalancer IP: $LB_IP"
INGRESS_IP="$LB_IP" ./scripts/test-scenarios.sh

# Prove HA: delete one replica and watch traffic keep flowing while it reschedules.
kubectl -n ingress-nginx delete pod -l app.kubernetes.io/component=controller --field-selector=status.phase=Running --wait=false | head -1
curl -s --resolve app.example.com:80:$LB_IP http://app.example.com/app1 | grep Hostname
```

> **Address pool:** `metallb_address_pool` must sit inside the kind Docker
> network subnet. Verify with
> `docker network inspect kind -f '{{ (index .IPAM.Config 0).Subnet }}'`
> (kind defaults to `172.18.0.0/16`) and override the var if yours differs.
>
> **WSL2 note:** the LoadBalancer IP lives on the kind Docker bridge. It is
> reachable from inside the WSL2 VM (where you run these commands). To reach it
> from a Windows browser you would route to the WSL2/Docker network — the
> default `localhost` path (HA disabled) is simpler for browser testing.

Return to the default single-replica setup any time:

```bash
terraform -chdir=terraform apply -auto-approve -var ingress_ha_enabled=false
```

---

## 6. Browser access

`curl --resolve` doesn't help a browser. Add the hosts to `/etc/hosts`
(pointing at localhost) once:

```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
127.0.0.1 app.example.com shop.example.com api.example.com blog.example.com
127.0.0.1 secure.example.com rewrite.example.com ratelimit.example.com
127.0.0.1 auth.example.com canary.example.com db.example.com
127.0.0.1 grafana.example.com
EOF
```

Then browse `http://app.example.com/app1`, `https://secure.example.com`
(accept the self-signed cert), `http://db.example.com`, etc.

> **WSL2 note:** `127.0.0.1` works from a Windows browser too — WSL forwards
> Windows' localhost into the VM, where kind publishes ports 80/443. Add the
> same entries to the Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`,
> needs an elevated editor), still pointing at `127.0.0.1`. Do not use the WSL2
> `eth0` IP or the ingress LoadBalancer IP there: the first changes on restart,
> and the second is a Docker bridge address Windows cannot route to.

---

## 7. Observability (optional, needs RAM)

```bash
make monitoring        # installs trimmed kube-prometheus-stack
make grafana           # port-forward -> http://localhost:3000  (admin/admin)
```

### Grafana via ingress (no port-forward)

Grafana is also exposed through the nginx ingress at **`grafana.example.com`**
(controlled by the `grafana_host` variable), so it stays reachable without a
port-forward and survives Grafana pod restarts. `terraform output grafana_url`
prints the URL.

`127.0.0.1` is the answer in **both** modes — point `grafana.example.com` at it
in your hosts file, exactly like the app hosts above, and browse
`http://grafana.example.com`. No port-forward, no per-mode difference.

In HA mode the ingress LoadBalancer IP works as well, but only from *inside*
WSL2 — it is a Docker bridge address and is not routable from Windows:

```bash
LB_IP="$(terraform -chdir=terraform output -raw ingress_external_ip)"
curl -s -o /dev/null -w "%{http_code}\n" --resolve grafana.example.com:80:$LB_IP http://grafana.example.com/api/health   # 200 from WSL, times out from Windows
```

> Don't put the LoadBalancer IP in the Windows hosts file — mirrored networking
> does not make it routable. Use `127.0.0.1`.

Prometheus (raw queries / targets) is reachable the same way via port-forward:
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090   # http://localhost:9090
```

In Grafana, the NGINX ingress metrics are scraped automatically (the controller
exposes a ServiceMonitor once monitoring is enabled). Import dashboard **14314**
(or **9614**) and query `nginx_ingress_controller_requests`.

Check Prometheus targets:
```bash
kubectl -n monitoring get servicemonitor
kubectl -n monitoring get pods
```

If pods get OOM-killed on a small machine, disable it again:
```bash
terraform -chdir=terraform apply -var enable_monitoring=false -auto-approve
```

---

## 8. Troubleshooting

| Symptom | Fix |
|--------|-----|
| `make cluster` fails on port 80/443 | Another process owns the port. `sudo lsof -i :80`. Stop it, or edit `kind/cluster.yaml` to map 8080/8443 and adjust `--resolve` ports. |
| Ingress pod `Pending` | Node not labeled. `kubectl get nodes -L ingress-ready`; recreate cluster. |
| `curl` hangs / connection refused | Controller not ready yet: `kubectl -n ingress-nginx get pods`. Wait for `Running`. |
| 404 for a known host | Manifest not applied or wrong `ingressClassName`. `kubectl -n apps get ingress` and `describe`. |
| 503 everywhere | Backend not ready: `kubectl -n apps get pods`. |
| Rate-limit test shows no 503 | Send the burst faster / increase count; nginx counts per-IP per-second. |
| Ansible: `ansible-playbook not found` | `make install-ansible`. |
| Terraform `context ... not found` | Cluster missing: `make cluster` first, or check `kubectl config get-contexts`. |

Useful inspection:
```bash
make status
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | tail -50
kubectl -n apps describe ingress <name>
# Dump the generated nginx.conf the controller compiled from your Ingress rules:
kubectl -n ingress-nginx exec deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | less
```

---

## 9. Teardown

```bash
make down                       # delete the kind cluster
rm -f terraform/terraform.tfstate*   # (optional) reset terraform state
```
