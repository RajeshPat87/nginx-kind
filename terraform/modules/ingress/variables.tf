# (5) VARIABLE BLOCKS — module inputs
variable "namespace" {
  description = "Namespace for the ingress controller."
  type        = string
  default     = "ingress-nginx"
}

variable "chart_version" {
  description = "ingress-nginx Helm chart version."
  type        = string
}

variable "enable_service_monitor" {
  description = "Render a ServiceMonitor (requires Prometheus CRDs)."
  type        = bool
  default     = false
}

variable "ha_enabled" {
  description = "Run the controller in HA mode (multiple replicas behind a MetalLB LoadBalancer) instead of the default single hostPort replica."
  type        = bool
  default     = false
}

variable "replica_count" {
  description = "Controller replicas in HA mode. Should be <= the number of schedulable workers (anti-affinity is required, one replica per node)."
  type        = number
  default     = 2
}
