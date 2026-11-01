variable "subscription_id" {
  description = "Azure subscription GUID in which to create the budget."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be an Azure subscription GUID, without the /subscriptions/ prefix."
  }
}

variable "notification_emails" {
  description = "Email addresses that receive budget notifications."
  type        = list(string)
  sensitive   = true
  nullable    = false

  validation {
    condition = (
      length(var.notification_emails) > 0 &&
      alltrue([
        for email in var.notification_emails :
        can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))
      ])
    )
    error_message = "notification_emails must contain at least one valid email address."
  }
}

variable "budget_amount" {
  description = "Monthly budget amount in the subscription's billing currency."
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be greater than zero."
  }
}

variable "budget_start_date" {
  description = "Budget start in UTC, using the first day of a month (YYYY-MM-01T00:00:00Z)."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(formatdate("YYYY-MM-DD", var.budget_start_date)) &&
      can(regex("^[0-9]{4}-(0[1-9]|1[0-2])-01T00:00:00Z$", var.budget_start_date))
    )
    error_message = "budget_start_date must be the first day of a valid month in UTC, formatted as YYYY-MM-01T00:00:00Z."
  }
}

