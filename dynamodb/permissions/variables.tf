variable "link_id" {
  type        = string
  description = "Nullplatform link ID (used as a keeper to stabilize resources across re-applies)"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "table_name" {
  type        = string
  description = "Target DynamoDB table name"
}

variable "table_arn" {
  type        = string
  description = "Target DynamoDB table ARN"
}

variable "iam_user_name" {
  type        = string
  description = "IAM user name for this link (derived from link ID)"
}

variable "access_level" {
  type        = string
  default     = "read-write"
  description = "Permission level: read, read-write or full"

  validation {
    condition     = contains(["read", "read-write", "full"], var.access_level)
    error_message = "access_level must be one of: read, read-write, full"
  }
}
