variable "subscription_id" {
  description = "Azure subscription where everything is created."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "name_prefix" {
  description = "Prefix used in resource names."
  type        = string
  default     = "forgetask"
}

variable "node_count" {
  description = "Number of AKS worker nodes."
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "VM size of the worker nodes. Check availability and quota in your region first."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "zones" {
  description = "Availability zones for the node pool, e.g. [\"1\",\"2\",\"3\"]. Empty = no zone pinning."
  type        = list(string)
  default     = []
}

variable "db_admin_login" {
  description = "Administrator login of the PostgreSQL server (baseline: the app uses it directly)."
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "Administrator password of the PostgreSQL server."
  type        = string
  sensitive   = true
}
