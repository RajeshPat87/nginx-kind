# (5) VARIABLE BLOCKS — module inputs
variable "enabled" {
  description = "Whether to install the monitoring stack."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Namespace for the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
}
