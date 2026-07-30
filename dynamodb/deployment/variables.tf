variable "service_id" {
  type        = string
  description = "Nullplatform service ID"
}

variable "table_name" {
  type        = string
  description = "DynamoDB table name. Computed once on create and frozen afterwards (see build_context)"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "billing_mode" {
  type        = string
  default     = "PAY_PER_REQUEST"
  description = "Billing mode: PAY_PER_REQUEST or PROVISIONED"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be one of: PAY_PER_REQUEST, PROVISIONED"
  }
}

variable "hash_key" {
  type        = string
  description = "Partition key attribute name"
}

variable "hash_key_type" {
  type        = string
  default     = "S"
  description = "Partition key type: S, N or B"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type must be one of: S, N, B"
  }
}

variable "range_key" {
  type        = string
  default     = ""
  description = "Optional sort key attribute name. Empty means a partition-key-only table"
}

variable "range_key_type" {
  type        = string
  default     = "S"
  description = "Sort key type: S, N or B"

  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "range_key_type must be one of: S, N, B"
  }
}

variable "read_capacity" {
  type        = number
  default     = 5
  description = "Provisioned read capacity units. Ignored when billing_mode is PAY_PER_REQUEST"
}

variable "write_capacity" {
  type        = number
  default     = 5
  description = "Provisioned write capacity units. Ignored when billing_mode is PAY_PER_REQUEST"
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Prevents the table from being deleted by AWS until explicitly turned off"
}

variable "ttl_enabled" {
  type        = bool
  default     = false
  description = "Automatically delete items once the TTL attribute timestamp has passed"
}

variable "ttl_attribute_name" {
  type        = string
  default     = "expires_at"
  description = "Item attribute holding the expiration time as a Unix epoch in seconds"
}

# ---------------------------------------------------------------------------
# Global secondary indexes.
#
# This variable arrives through a tfvars.json file, not through a -var flag:
# do_tofu word-splits $TOFU_VARIABLES, so a JSON list on the command line
# breaks at the first space. build_context writes the file and passes
# -var-file=..., which survives word-splitting as a single token.
# ---------------------------------------------------------------------------
variable "global_secondary_indexes" {
  type = list(object({
    name               = string
    hash_key           = string
    hash_key_type      = optional(string, "S")
    range_key          = optional(string, "")
    range_key_type     = optional(string, "S")
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
    read_capacity      = optional(number, 5)
    write_capacity     = optional(number, 5)
  }))
  default     = []
  description = "Additional query patterns on attributes other than the table keys"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags applied to the table"
}
