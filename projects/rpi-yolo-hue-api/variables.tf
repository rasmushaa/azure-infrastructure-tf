variable "subscription_id" {
  description = "Azure subscription GUID in which to create the project resources."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be an Azure subscription GUID, without the /subscriptions/ prefix."
  }
}

variable "owner_principal_id" {
  description = "Private Microsoft Entra object ID of the user who owns and administers the project resource group."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.owner_principal_id))
    error_message = "owner_principal_id must be a Microsoft Entra object ID in GUID format."
  }
}

variable "location" {
  description = "Azure region for the project's resources."
  type        = string
  default     = "northeurope"
  nullable    = false

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "soft_delete_retention_days" {
  description = "Days that deleted blobs and containers remain recoverable."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition = (
      var.soft_delete_retention_days >= 1 &&
      var.soft_delete_retention_days <= 365 &&
      floor(var.soft_delete_retention_days) == var.soft_delete_retention_days
    )
    error_message = "soft_delete_retention_days must be a whole number between 1 and 365."
  }
}

variable "old_version_retention_days" {
  description = "Days to retain previous blob versions before lifecycle deletion."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition = (
      var.old_version_retention_days >= 1 &&
      floor(var.old_version_retention_days) == var.old_version_retention_days
    )
    error_message = "old_version_retention_days must be a whole number of at least 1."
  }
}

