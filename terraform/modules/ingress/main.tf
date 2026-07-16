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

# (7) LOCALS BLOCK — the controller config differs by access mode. Everything
# common lives in controller_base; the two modes contribute the rest, then the
# maps are merged so only one path is ever rendered.
locals {
  # Shared across both modes.
  controller_base = {
    watchIngressWithoutClass = true
    allowSnippetAnnotations  = true
    config = {
      "use-forwarded-headers" = "true"
      "enable-real-ip"        = "true"
    }
    metrics = {
      enabled        = true
      serviceMonitor = { enabled = var.enable_service_monitor }
    }
    resources = {
      requests = { cpu = "100m", memory = "128Mi" }
    }
    admissionWebhooks = { enabled = true }
  }

  # Default: one replica pinned to the control-plane node, binding hostPort
  # 80/443 so the host reaches it on localhost (backs the 9 baseline usecases).
  controller_single = {
    replicaCount = 1
    nodeSelector = {
      "ingress-ready" = "true"
    }
    tolerations = [
      {
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Equal"
        effect   = "NoSchedule"
      }
    ]
    hostPort = {
      enabled = true
      ports   = { http = 80, https = 443 }
    }
    service        = { type = "NodePort" }
    publishService = { enabled = false }
  }

  # HA: N replicas spread one-per-node via required pod anti-affinity, behind a
  # MetalLB LoadBalancer Service (no hostPort, no control-plane pinning). This
  # is the "Ingress Controller High Availability" usecase from the diagram.
  controller_ha = {
    replicaCount   = var.replica_count
    service        = { type = "LoadBalancer" }
    publishService = { enabled = true }
    affinity = {
      podAntiAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = [
          {
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name"      = "ingress-nginx"
                "app.kubernetes.io/component" = "controller"
              }
            }
            topologyKey = "kubernetes.io/hostname"
          }
        ]
      }
    }
  }

  default_backend = {
    enabled   = true
    resources = { requests = { cpu = "10m", memory = "20Mi" } }
  }

  # Render each mode to a full values string. The two modes are differently
  # shaped objects, so we compare rendered strings (a consistent type) rather
  # than the objects themselves in the conditional below.
  values_single = yamlencode({
    controller     = merge(local.controller_base, local.controller_single)
    defaultBackend = local.default_backend
  })
  values_ha = yamlencode({
    controller     = merge(local.controller_base, local.controller_ha)
    defaultBackend = local.default_backend
  })
}

# (3) RESOURCE BLOCK — ingress-nginx controller. Access mode is chosen by
# var.ha_enabled; see the locals above for what each mode renders.
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600
  wait             = true

  values = [var.ha_enabled ? local.values_ha : local.values_single]
}

# (4) DATA BLOCK — read the controller Service that Helm just created so we can
# surface its details as an output (demonstrates reading existing resources).
data "kubernetes_service" "controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}
