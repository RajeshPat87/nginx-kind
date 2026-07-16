# (7) LOCALS BLOCK — values reused across modules (DRY).
locals {
  # Labels stamped on every resource we create.
  common_labels = {
    "app.kubernetes.io/part-of"    = "nginx-kind"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  # Demo backends. Add a key here and for_each provisions another whoami
  # Service — no copy-paste. canary-stable runs 2 replicas for the HA demo.
  demo_apps = {
    app1          = { replicas = 1 }
    app2          = { replicas = 1 }
    shop          = { replicas = 1 }
    api           = { replicas = 1 }
    blog          = { replicas = 1 }
    canary-stable = { replicas = 2 }
    canary-canary = { replicas = 1 }
  }

  # Absolute path to the local demo-app chart (stable regardless of CWD).
  demo_chart_path = abspath("${path.module}/../helm/demo-app")
}
