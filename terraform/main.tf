# (8) MODULE BLOCKS — compose the platform from small, reusable modules.
# The root module stays thin: wiring, not resources.

module "monitoring" {
  source        = "./modules/monitoring"
  enabled       = var.enable_monitoring
  chart_version = var.monitoring_chart_version
  grafana_host  = "grafana.${var.domain}"
}

# MetalLB provides a real LoadBalancer implementation for the HA ingress
# use-case. Skipped entirely (count = 0) when ingress_ha_enabled is false.
module "loadbalancer" {
  source        = "./modules/loadbalancer"
  enabled       = var.ingress_ha_enabled
  chart_version = var.metallb_chart_version
  address_pool  = var.metallb_address_pool
}

module "ingress" {
  source                 = "./modules/ingress"
  chart_version          = var.ingress_chart_version
  enable_service_monitor = var.enable_monitoring
  ha_enabled             = var.ingress_ha_enabled
  replica_count          = var.ingress_replica_count

  # The ingress chart renders a ServiceMonitor whose CRD is provided by the
  # monitoring stack, so that must be installed first. In HA mode the
  # controller's LoadBalancer Service needs MetalLB ready to assign an IP.
  depends_on = [module.monitoring, module.loadbalancer]
}

module "database" {
  source      = "./modules/database"
  namespace   = var.data_namespace
  labels      = local.common_labels
  pg_user     = var.pg_user
  pg_password = var.pg_password
  pg_database = var.pg_database
}

module "apps" {
  source         = "./modules/apps"
  namespace      = var.apps_namespace
  labels         = local.common_labels
  demo_apps      = local.demo_apps
  demo_image     = var.demo_image
  chart_path     = local.demo_chart_path
  data_namespace = var.data_namespace

  # Apps reference the nginx IngressClass, so bring the controller up first.
  depends_on = [module.ingress]
}

# ---------------------------------------------------------------------------
# moved blocks: migrate state from the earlier flat layout into the modules
# in place (no destroy/recreate). Safe to keep; they are no-ops once migrated.
# ---------------------------------------------------------------------------
moved {
  from = helm_release.ingress_nginx
  to   = module.ingress.helm_release.ingress_nginx
}
moved {
  from = kubernetes_namespace.data
  to   = module.database.kubernetes_namespace.data
}
moved {
  from = kubernetes_secret.postgres
  to   = module.database.kubernetes_secret.postgres
}
moved {
  from = kubernetes_stateful_set.postgres
  to   = module.database.kubernetes_stateful_set.postgres
}
moved {
  from = kubernetes_service.postgres
  to   = module.database.kubernetes_service.postgres
}
moved {
  from = kubernetes_namespace.apps
  to   = module.apps.kubernetes_namespace.apps
}
moved {
  from = helm_release.demo_app
  to   = module.apps.helm_release.demo_app
}
moved {
  from = kubernetes_deployment.adminer
  to   = module.apps.kubernetes_deployment.adminer
}
moved {
  from = kubernetes_service.adminer
  to   = module.apps.kubernetes_service.adminer
}
