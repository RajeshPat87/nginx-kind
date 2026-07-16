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
