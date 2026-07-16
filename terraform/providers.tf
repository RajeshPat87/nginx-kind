# Providers read the kubeconfig produced by `kind create cluster`.
# The cluster is created out-of-band (make cluster) BEFORE terraform runs, so
# the context already exists at plan/apply time (no chicken-and-egg).
provider "kubernetes" {
  config_path    = var.kubeconfig
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig
    config_context = var.kube_context
  }
}
