variable "kubeconfig" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context for the kind cluster."
  type        = string
  default     = "kind-nginx-kind"
}

variable "apps_namespace" {
  description = "Namespace for demo apps, ingresses, TLS and auth secrets."
  type        = string
  default     = "apps"
}

variable "data_namespace" {
  description = "Namespace for PostgreSQL."
  type        = string
  default     = "data"
}

variable "domain" {
  description = "Base domain used by the demo ingress hosts."
  type        = string
  default     = "example.com"
}

# ---- ingress-nginx ----
variable "ingress_chart_version" {
  description = "ingress-nginx Helm chart version."
  type        = string
  default     = "4.11.3"
}

# ---- PostgreSQL ----
variable "pg_user" {
  description = "PostgreSQL application username."
  type        = string
  default     = "appuser"
}

variable "pg_password" {
  description = "PostgreSQL application password."
  type        = string
  default     = "apppass123"
  sensitive   = true
}

variable "pg_database" {
  description = "PostgreSQL application database."
  type        = string
  default     = "appdb"
}

# ---- monitoring (optional / RAM heavy) ----
variable "enable_monitoring" {
  description = "Install kube-prometheus-stack (needs extra RAM)."
  type        = bool
  default     = false
}

variable "monitoring_chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
  default     = "65.5.1"
}

# ---- demo apps ----
variable "demo_image" {
  description = "Image used by the demo backend apps (echoes host/headers)."
  type        = string
  default     = "traefik/whoami:v1.10.4"
}
