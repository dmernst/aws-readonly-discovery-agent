variable "region" {
  description = "Region for the provider. IAM is global; us-east-1 is also where Cost Explorer lives."
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "Name of the read-only role the agent assumes."
  type        = string
  default     = "mcp-discovery-readonly"
}

variable "trusted_principal_arns" {
  description = "IAM role or user ARNs allowed to assume the discovery role (for example, your IAM Identity Center permission set role)."
  type        = list(string)
}

variable "external_id" {
  description = "Optional external ID. Use it when a partner or another account assumes this role into a customer account."
  type        = string
  default     = ""
}

variable "max_session_hours" {
  description = "Maximum session length. Keep it short: a discovery run is an afternoon, not a week."
  type        = number
  default     = 1
}
