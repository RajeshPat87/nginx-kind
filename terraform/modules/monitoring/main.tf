# (1) TERRAFORM BLOCK — provider requirements for this module.
terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# (3) RESOURCE BLOCK — kube-prometheus-stack, trimmed for a low-RAM laptop.
# Gated behind var.enabled (count) so the core lab always fits in RAM.
resource "helm_release" "monitoring" {
  count = var.enabled ? 1 : 0

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 900
  wait             = false

  values = [yamlencode({
    alertmanager = { enabled = false }
    defaultRules = { create = false }

    grafana = {
      adminPassword = "admin"
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { memory = "256Mi" }
      }
      defaultDashboardsTimezone = "browser"
    }

    prometheus = {
      prometheusSpec = {
        retention                               = "6h"
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        resources = {
          requests = { cpu = "100m", memory = "512Mi" }
          limits   = { memory = "768Mi" }
        }
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources   = { requests = { storage = "2Gi" } }
            }
          }
        }
      }
    }

    "prometheus-node-exporter" = {
      resources = { requests = { cpu = "10m", memory = "24Mi" } }
    }
    "kube-state-metrics" = {
      resources = { requests = { cpu = "10m", memory = "48Mi" } }
    }
  })]
}
