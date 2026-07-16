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

# (3) RESOURCE BLOCK — ingress-nginx controller, tuned for kind:
#  - schedules on the control-plane node (ingress-ready=true) with a toleration
#  - binds hostPort 80/443 so host traffic on localhost reaches it
#  - single replica (hostPort binds once per node on kind)
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600
  wait             = true

  values = [yamlencode({
    controller = {
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
      service                  = { type = "NodePort" }
      publishService           = { enabled = false }
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
    defaultBackend = {
      enabled   = true
      resources = { requests = { cpu = "10m", memory = "20Mi" } }
    }
  })]
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
