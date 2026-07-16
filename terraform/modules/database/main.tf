# (1) TERRAFORM BLOCK — provider requirements for this module (no config here;
# the configured provider is inherited from the root module).
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# (3) RESOURCE BLOCKS — PostgreSQL as a Kubernetes "db service":
# a StatefulSet backed by a PVC, fronted by a stable (headless) Service at
# postgres.<namespace>.svc.cluster.local:5432.
resource "kubernetes_namespace" "data" {
  metadata {
    name   = var.namespace
    labels = var.labels
  }
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.data.metadata[0].name
  }
  data = {
    POSTGRES_USER     = var.pg_user
    POSTGRES_PASSWORD = var.pg_password
    POSTGRES_DB       = var.pg_database
  }
  type = "Opaque"
}

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.data.metadata[0].name
    labels    = merge(var.labels, { app = "postgres" })
  }

  spec {
    service_name = "postgres"
    replicas     = 1
    selector {
      match_labels = { app = "postgres" }
    }
    template {
      metadata {
        labels = { app = "postgres" }
      }
      spec {
        container {
          name  = "postgres"
          image = var.image

          port {
            container_port = 5432
            name           = "postgres"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.postgres.metadata[0].name
            }
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.pg_user, "-d", var.pg_database]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.pg_user, "-d", var.pg_database]
            }
            initial_delay_seconds = 30
            period_seconds        = 15
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.storage_size
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.data.metadata[0].name
    labels    = merge(var.labels, { app = "postgres" })
  }
  spec {
    selector = { app = "postgres" }
    port {
      port        = 5432
      target_port = 5432
      name        = "postgres"
    }
    cluster_ip = "None" # headless, standard for a StatefulSet DB
  }
}
