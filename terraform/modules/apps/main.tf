# (1) TERRAFORM BLOCK — provider requirements for this module.
terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# (3) RESOURCE BLOCK — namespace owned by this module.
resource "kubernetes_namespace" "apps" {
  metadata {
    name   = var.namespace
    labels = var.labels
  }
}

# (3) RESOURCE BLOCK — one release of the local demo-app chart per backend.
# for_each keeps this DRY: add a key to the demo_apps map and you get another
# whoami Service, no copy-paste.
resource "helm_release" "demo_app" {
  for_each = var.demo_apps

  name      = each.key
  namespace = kubernetes_namespace.apps.metadata[0].name
  chart     = var.chart_path
  wait      = true
  timeout   = 300

  values = [yamlencode({
    fullnameOverride = each.key
    replicaCount     = each.value.replicas
    image            = var.demo_image
    appName          = each.key
  })]
}

# (3) RESOURCE BLOCKS — Adminer: a real DB client exposed through ingress,
# demonstrating Ingress -> Service (ClusterIP) -> Pod -> PostgreSQL Service.
resource "kubernetes_deployment" "adminer" {
  metadata {
    name      = "adminer"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels    = merge(var.labels, { app = "adminer" })
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "adminer" }
    }
    template {
      metadata {
        labels = { app = "adminer" }
      }
      spec {
        container {
          name  = "adminer"
          image = "adminer:4.8.1"
          port {
            container_port = 8080
          }
          env {
            name  = "ADMINER_DEFAULT_SERVER"
            value = "postgres.${var.data_namespace}.svc.cluster.local"
          }
          resources {
            requests = { cpu = "10m", memory = "32Mi" }
            limits   = { memory = "128Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "adminer" {
  metadata {
    name      = "adminer"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels    = merge(var.labels, { app = "adminer" })
  }
  spec {
    selector = { app = "adminer" }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}
