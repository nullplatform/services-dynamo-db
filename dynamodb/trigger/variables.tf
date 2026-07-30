variable "link_id" {
  type        = string
  description = "Nullplatform link ID"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "stream_arn" {
  type        = string
  description = "ARN of the table's DynamoDB stream, read from the service attributes"
}

variable "table_name" {
  type        = string
  description = "Table the stream belongs to. Used for naming and tagging only"
}

variable "function_name" {
  type        = string
  description = "Lambda function the trigger invokes, derived from the linked scope"
}

variable "alias_name" {
  type        = string
  default     = "main"
  description = "Alias the trigger points at. Pointing at the alias rather than the function keeps the trigger on whichever version serves traffic after a blue/green deployment"
}

variable "starting_position" {
  type        = string
  default     = "TRIM_HORIZON"
  description = "Where in the stream to start reading"

  validation {
    condition     = contains(["TRIM_HORIZON", "LATEST"], var.starting_position)
    error_message = "starting_position must be one of: TRIM_HORIZON, LATEST"
  }
}

variable "batch_size" {
  type        = number
  default     = 100
  description = "Maximum records per invocation"
}

variable "batching_window_seconds" {
  type        = number
  default     = 0
  description = "Seconds to accumulate records before invoking"
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Whether the trigger is active"
}
