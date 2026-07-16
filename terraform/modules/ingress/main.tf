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
  # MetalLB LoadBalancer Service. This is the "Ingress Controller High
  # Availability" usecase from the diagram.
  #
  # The control-plane toleration + hostPort are what keep the lab reachable on
  # localhost in this mode. kind maps host 80/443 into the control-plane node
  # only, so with replicas confined to the workers nothing answers on
  # localhost:80 and every demo host breaks for a browser on the host. Allowing
  # one replica onto the control-plane (replica_count = node count) restores
  # that path. The MetalLB LoadBalancer IP keeps working either way — hostPort
  # is a container-level setting and is independent of the Service type.
  controller_ha = {
    replicaCount   = var.replica_count
    service        = { type = "LoadBalancer" }
    publishService = { enabled = true }
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
    # One pod per node + required anti-affinity means a rollout cannot surge:
    # there is no spare node for an extra replica, and the hostPort is already
    # held by the outgoing pod on that node. The chart default (maxSurge 25%,
    # maxUnavailable 25%) rounds maxUnavailable down to 0 at 3 replicas, so the
    # rollout deadlocks — it may not remove an old pod, and the new one it adds
    # can never be scheduled. Replace-in-place instead: 2 of 3 replicas stay
    # serving through the roll.
    updateStrategy = {
      type = "RollingUpdate"
      rollingUpdate = {
        maxSurge       = 0
        maxUnavailable = 1
      }
    }
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
