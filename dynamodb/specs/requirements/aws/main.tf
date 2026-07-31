################################################################################
# aws-dynamodb service — assume-role IAM
#
# The service operates AWS (DynamoDB tables + per-link IAM users + tfstate) via
# the ASSUME-ROLE pattern: this dedicated role holds the permissions and the
# nullplatform agent assumes it (sts:AssumeRole). The consuming stack passes
# this role's ARN to the agent (assume_role_arns) and publishes it to the
# nullplatform AWS IAM provider (selector "dynamodb").
#
# The role trusts the agent role BY NAME (derived default) rather than by a
# module output, so the consuming stack can wire the ARN back into the agent
# without creating a dependency cycle. The agent role name is the conventional
# "nullplatform-{cluster_name}-agent-role".
################################################################################

resource "aws_iam_role" "nullplatform_dynamodb" {
  count = local.iam_create ? 1 : 0

  name        = local.role_name
  description = "Permissions role assumed by the nullplatform agent role for the aws-dynamodb service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = concat([local.agent_role_arn], var.additional_agent_role_arns) }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.iam_default_tags
}

# --- DynamoDB table management ------------------------------------------------
# dynamodb:* is scoped to tables carrying the managed prefix. Enumerating the
# individual actions is brittle — the provider reads a wide surface on refresh
# (tags, TTL, continuous backups, indexes) and each provider upgrade tends to
# add one more. If a tighter scope is ever needed, narrow the Resource rather
# than the Action list.
#
# ListTables and DescribeLimits are account-level calls that take no resource,
# so they sit in their own statement.
resource "aws_iam_policy" "nullplatform_dynamodb" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_dynamodb_policy"
  description = "DynamoDB table management for the nullplatform aws-dynamodb service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ManageTables"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = local.managed_table_arns
      },
      {
        Sid    = "AccountLevelReads"
        Effect = "Allow"
        Action = [
          "dynamodb:ListTables",
          "dynamodb:DescribeLimits",
        ]
        Resource = "*"
      },
    ]
  })

  tags = local.iam_default_tags
}

# --- Per-link IAM users -------------------------------------------------------
# Every link gets its own IAM user with an access key. Scoped to the
# /nullplatform/dynamodb/ path so the role cannot reach any other identity.
resource "aws_iam_policy" "nullplatform_dynamodb_iam" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_dynamodb_iam_policy"
  description = "Per-link IAM user management for the nullplatform aws-dynamodb service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageLinkUsers"
      Effect = "Allow"
      Action = [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:GetUser",
        "iam:TagUser",
        "iam:UntagUser",
        "iam:ListUserTags",
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:ListAccessKeys",
        "iam:PutUserPolicy",
        "iam:DeleteUserPolicy",
        "iam:GetUserPolicy",
        "iam:ListUserPolicies",
        "iam:ListAttachedUserPolicies",
      ]
      Resource = local.link_user_path_arn
    }]
  })

  tags = local.iam_default_tags
}

# --- Terraform state ----------------------------------------------------------
# One bucket per service instance, created on the fly by build_context and
# removed by delete_tfstate_bucket. use_lockfile=true keeps the lock as an
# object inside the same bucket, so no DynamoDB lock table is involved.
resource "aws_iam_policy" "nullplatform_dynamodb_state" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_dynamodb_state_policy"
  description = "Terraform state bucket management for the nullplatform aws-dynamodb service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageStateBuckets"
      Effect = "Allow"
      Action = ["s3:*"]
      Resource = [
        "arn:aws:s3:::np-service-*",
        "arn:aws:s3:::np-service-*/*",
      ]
    }]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_dynamodb[0].name
  policy_arn = aws_iam_policy.nullplatform_dynamodb[0].arn
}

resource "aws_iam_role_policy_attachment" "dynamodb_iam" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_dynamodb[0].name
  policy_arn = aws_iam_policy.nullplatform_dynamodb_iam[0].arn
}

resource "aws_iam_role_policy_attachment" "dynamodb_state" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_dynamodb[0].name
  policy_arn = aws_iam_policy.nullplatform_dynamodb_state[0].arn
}
