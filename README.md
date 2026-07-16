# nginx-kind — NGINX Ingress Controller lab on kind

A fully local, reproducible lab that stands up the **NGINX Ingress Controller**
on a [kind](https://kind.sigs.k8s.io/) cluster and demonstrates **every common
ingress use case** end to end — path & host routing, TLS termination, URL
rewrite, rate limiting, basic auth, canary traffic splitting, and an ingress in
front of a **PostgreSQL**-backed app.

Provisioned with the tools you'd use in production:

| Tool | Role in this lab |
|------|------------------|
| **Docker** | runs the kind nodes as containers |
| **kind** | creates the local Kubernetes cluster (host ports 80/443 mapped) |
| **Terraform** | installs ingress-nginx, PostgreSQL, demo apps, and (optional) Prometheus as Helm releases / k8s objects |
| **Helm** | packages the demo backend app (`helm/demo-app`) and the upstream charts |
| **Ansible** | day-2 post-config: TLS certs, htpasswd, applies ingress rules, seeds the DB, smoke test |
| **kubectl** | inspection & verification |
| **kube-prometheus-stack** | optional observability (Grafana + Prometheus) |

---

## Architecture

```
                 host: localhost:80 / :443
                            │
                 ┌──────────▼───────────┐   kind node (control-plane, ingress-ready=true)
                 │   ingress-nginx      │   hostPort 80/443
                 │  (controller pod)    │
                 └──────────┬───────────┘
        ┌──────────┬────────┼─────────┬──────────┬─────────────┐
        ▼          ▼        ▼         ▼          ▼             ▼
   app1/app2    shop/api  secure    rewrite   auth/canary   adminer
   (whoami)      /blog    (TLS)    (rewrite)   (auth)          │
   path route  host route                                      ▼
                                                       postgres.data (StatefulSet + Service)
```

The ingress controller is the only component in the data path; each Ingress
object is just a rule set the controller compiles into NGINX config.

---

## Prerequisites

| Tool | Tested version |
|------|----------------|
| Docker | 24+ |
| kind | 0.22+ |
| kubectl | 1.29+ |
| Helm | 3.13+ |
| Terraform | 1.5+ (OpenTofu 1.6+ works too) |
| Ansible | installed into a local venv by `make install-ansible` |
| Python 3 | for the Ansible venv |

~8 GB free RAM is recommended **only if** you enable the Prometheus stack. The
core lab (ingress + Postgres + demo apps) runs comfortably in ~2 GB, so
monitoring is a separate opt-in step (`make monitoring`).

---

## Quickstart

```bash
# 0. one-time: install ansible into ./.venv (no sudo)
make install-ansible

# 1. bring everything up: kind cluster -> terraform -> ansible
make up

# 2. exercise every ingress scenario
make test

# 3. (optional) observability — needs extra RAM
make monitoring
make grafana          # http://localhost:3000  (admin/admin)

# teardown
make down
```

`make test` uses `curl --resolve`, so you don't need to touch `/etc/hosts`.
For browser testing, see [RUNBOOK.md](./RUNBOOK.md#browser-access).

---

## Ingress use cases covered

| # | Scenario | Host | What it shows |
|---|----------|------|---------------|
| 1 | Path routing | `app.example.com/app1`,`/app2` | fan-out by path |
| 2 | Host routing | `shop`/`api`/`blog.example.com` | name-based virtual hosts |
| 3 | TLS termination | `https://secure.example.com` | HTTPS + http→https redirect |
| 4 | URL rewrite | `rewrite.example.com/svc/...` | strip path prefix |
| 5 | Rate limiting | `ratelimit.example.com` | throttle → 503 |
| 6 | Basic auth | `auth.example.com` | 401 → 200 with creds |
| 7 | Canary split | `canary.example.com` | weighted traffic (30%) + HA replicas |
| 8 | DB-backed app | `db.example.com` | Ingress → Adminer → PostgreSQL |
| 9 | Default backend | any unknown host | 404 fallback |

---

## Repository layout

```
nginx-kind/
├── kind/cluster.yaml         # kind cluster (port mappings, ingress-ready label)
├── terraform/                # modular IaC (see below)
│   ├── versions.tf           # (1) terraform block
│   ├── providers.tf          # (2) provider blocks
│   ├── variables.tf          # (5) variable blocks
│   ├── locals.tf             # (7) locals block
│   ├── main.tf               # (8) module blocks + moved blocks
│   ├── outputs.tf            # (6) output blocks
│   └── modules/              # reusable modules (resource (3) + data (4) blocks)
│       ├── ingress/          #   ingress-nginx controller
│       ├── database/         #   postgres StatefulSet + Service
│       ├── apps/             #   whoami backends (for_each) + adminer
│       └── monitoring/       #   kube-prometheus-stack (optional)
├── helm/demo-app/            # chart for the whoami backends
├── manifests/                # the ingress use-case manifests
├── ansible/                  # post-config roles (tls, basic_auth, rules, seed, smoke)
├── scripts/                  # up/down/install/test helpers
├── practices/                # reference images (Terraform standards)
├── Makefile                  # entrypoint (make help)
├── README.md
└── RUNBOOK.md                # step-by-step manual test guide
```

### Terraform structure

The Terraform follows standard IaC practice — a thin root that only *wires*
modules together, with each concern (ingress, database, apps, monitoring) in its
own reusable, DRY module. It intentionally exercises all **8 standard Terraform
block types**: `terraform` (1), `provider` (2), `resource` (3), `data` (4),
`variable` (5), `output` (6), `locals` (7) and `module` (8). Adding another demo
backend is a one-line edit to the `demo_apps` map in `locals.tf` (driven by
`for_each`), not a copy-paste.

See **[RUNBOOK.md](./RUNBOOK.md)** for the full step-by-step walkthrough,
expected output for every scenario, and troubleshooting.
