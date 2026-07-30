locals {
  # Module identifier
  iam_module_name = "requirements-dynamodb"

  # Whether resources are created
  iam_create = var.iam_create_role

  # Derived names (overridable via variables).
  role_name            = var.role_name != "" ? var.role_name : "nullplatform_${var.cluster_name}_dynamodb_role"
  policies_name_prefix = var.policies_name_prefix != "" ? var.policies_name_prefix : "nullplatform_${var.cluster_name}"

  # Primary agent role trusted by the permissions role. Defaults to the
  # conventional agent role name for the cluster when not provided explicitly.
  agent_role_arn = var.agent_role_arn != "" ? var.agent_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/nullplatform-${var.cluster_name}-agent-role"

  account_id = data.aws_caller_identity.current.account_id

  # Tables the service manages, plus their indexes and streams. Scoped by the
  # name prefix so the role cannot touch tables created outside nullplatform.
  managed_table_arns = [
    "arn:aws:dynamodb:*:${local.account_id}:table/${var.table_name_prefix}*",
    "arn:aws:dynamodb:*:${local.account_id}:table/${var.table_name_prefix}*/index/*",
    "arn:aws:dynamodb:*:${local.account_id}:table/${var.table_name_prefix}*/stream/*",
  ]

  # Per-link IAM users live under this path. Scoping the IAM statements to it
  # keeps the role from being able to touch any other user in the account.
  link_user_path_arn = "arn:aws:iam::${local.account_id}:user/nullplatform/dynamodb/*"

  # Default tags applied to every IAM resource
  iam_default_tags = merge(var.iam_resource_tags_json, {
    ManagedBy = "nullplatform-custom-scope-role"
    Module    = local.iam_module_name
  })
}
