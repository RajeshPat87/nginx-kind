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

## 6. Browser access

`curl --resolve` doesn't help a browser. Add the hosts to `/etc/hosts`
(pointing at localhost) once:

```bash
sudo tee -a /etc/hosts >/dev/null <<'EOF'
127.0.0.1 app.example.com shop.example.com api.example.com blog.example.com
127.0.0.1 secure.example.com rewrite.example.com ratelimit.example.com
127.0.0.1 auth.example.com canary.example.com db.example.com
EOF
```

Then browse `http://app.example.com/app1`, `https://secure.example.com`
(accept the self-signed cert), `http://db.example.com`, etc.

> **WSL2 note:** these run inside the WSL2 VM. From a Windows browser use the
> WSL2 IP (`ip addr show eth0`) instead of `127.0.0.1`, or run the browser
> inside WSL. From a WSL2 terminal, `127.0.0.1` works as shown.

---

## 7. Observability (optional, needs RAM)

```bash
make monitoring        # installs trimmed kube-prometheus-stack
make grafana           # port-forward -> http://localhost:3000  (admin/admin)
```

In Grafana, the NGINX ingress metrics are scraped automatically (the controller
exposes a ServiceMonitor once monitoring is enabled). Try the
**"NGINX Ingress controller"** dashboard or query `nginx_ingress_controller_requests`.

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
