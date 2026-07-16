# (5) VARIABLE BLOCKS — module inputs
variable "namespace" {
  description = "Namespace for PostgreSQL."
  type        = string
}

variable "labels" {
  description = "Common labels applied to module resources."
  type        = map(string)
  default     = {}
}

variable "pg_user" {
  description = "PostgreSQL application username."
  type        = string
}

variable "pg_password" {
  description = "PostgreSQL application password."
  type        = string
  sensitive   = true
}

variable "pg_database" {
  description = "PostgreSQL application database."
  type        = string
}

variable "image" {
  description = "PostgreSQL container image."
  type        = string
  default     = "postgres:16-alpine"
}

variable "storage_size" {
  description = "PVC size for the database."
  type        = string
  default     = "1Gi"
}
