# (1) TERRAFORM BLOCK — provider requirements for this module.
terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# (3) RESOURCE BLOCK — MetalLB gives kind a real LoadBalancer implementation.
# kind has no cloud LB, so a `type: LoadBalancer` Service would sit <pending>
# forever. MetalLB assigns it an IP from a pool on the kind Docker network and
# announces it over L2 (ARP). Only installed when HA is enabled.
resource "helm_release" "metallb" {
  count            = var.enabled ? 1 : 0
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 600
  wait             = true
}

# (3) RESOURCE BLOCK — the address pool + L2 advertisement, shipped as a tiny
# local chart. Depends on the MetalLB release so its CRDs and validating
# webhook exist before these custom resources are applied.
resource "helm_release" "metallb_config" {
  count     = var.enabled ? 1 : 0
  name      = "metallb-config"
  chart     = abspath("${path.module}/../../../helm/metallb-config")
  namespace = var.namespace
  timeout   = 300
  wait      = true

  values = [yamlencode({
    addressPool = var.address_pool
  })]

  depends_on = [helm_release.metallb]
}
