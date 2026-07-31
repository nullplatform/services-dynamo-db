################################################################################
# Permissions for the trigger link
#
# A trigger wires a table stream to a Lambda function. That needs two things
# the rest of the service does not: managing event source mappings, and adding
# an inline policy to the function's execution role — a role this service does
# not own, since the Lambda scope created it.
################################################################################

variable "lambda_execution_role_arns" {
  description = "Role ARNs whose inline policies the service may manage, so a trigger can grant the target function permission to read the stream. Defaults to every role in the account: narrow it to the roles the Lambda scope creates when their naming is known, since the scope makes the name configurable and it cannot be derived here."
  type        = list(string)
  default     = null
}

variable "enable_trigger_permissions" {
  description = "Whether to grant the permissions the trigger link needs. Set to false to install the service with only the connect link."
  type        = bool
  default     = true
}

locals {
  trigger_enabled = local.iam_create && var.enable_trigger_permissions

  lambda_execution_role_arns = coalesce(
    var.lambda_execution_role_arns,
    ["arn:aws:iam::${local.account_id}:role/*"]
  )
}

resource "aws_iam_policy" "nullplatform_dynamodb_trigger" {
  count = local.trigger_enabled ? 1 : 0

  name        = "${local.policies_name_prefix}_dynamodb_trigger_policy"
  description = "Event source mapping management for the nullplatform aws-dynamodb service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Event source mappings are not addressable by ARN: AWS authorizes
        # these calls against "*". The blast radius is bounded by the trust
        # policy on the role, not by the resource here.
        Sid    = "ManageEventSourceMappings"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:GetEventSourceMapping",
          "lambda:ListEventSourceMappings",
          "lambda:ListTags",
          "lambda:TagResource",
          "lambda:UntagResource",
        ]
        Resource = "*"
      },
      {
        # Reading the target function to resolve its alias ARN and execution
        # role before creating the mapping.
        Sid    = "ReadTargetFunctions"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionConcurrency",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetPolicy",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:ListVersionsByFunction",
        ]
        Resource = "*"
      },
      {
        # Granting the function's execution role permission to read the
        # stream. Scoped to inline policies on the roles listed above; the
        # service never attaches managed policies nor touches trust policies.
        Sid    = "GrantStreamAccessToTargetRole"
        Effect = "Allow"
        Action = [
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
        ]
        Resource = local.lambda_execution_role_arns
      },
    ]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_role_policy_attachment" "dynamodb_trigger" {
  count = local.trigger_enabled ? 1 : 0

  role       = aws_iam_role.nullplatform_dynamodb[0].name
  policy_arn = aws_iam_policy.nullplatform_dynamodb_trigger[0].arn
}
