# ---------------------------------------------------------------------------
# IAM user per link
#
# The user lives under a dedicated path so the agent's own permissions can be
# scoped to /nullplatform/dynamodb/ instead of granting IAM-wide access.
# ---------------------------------------------------------------------------

resource "aws_iam_user" "link" {
  name = var.iam_user_name
  path = "/nullplatform/dynamodb/"

  tags = {
    "managed-by" = "nullplatform"
    "link-id"    = var.link_id
    "table"      = var.table_name
  }
}

# ---------------------------------------------------------------------------
# Access key delivered to the application as environment variables.
# ---------------------------------------------------------------------------

resource "aws_iam_access_key" "link" {
  user = aws_iam_user.link.name
}

# ---------------------------------------------------------------------------
# Inline policy scoped to the table and its indexes.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "link" {
  statement {
    sid       = "TableAccess"
    effect    = "Allow"
    actions   = local.iam_actions[var.access_level]
    resources = local.table_resources
  }
}

resource "aws_iam_user_policy" "link" {
  name   = "dynamodb-access-${var.link_id}"
  user   = aws_iam_user.link.name
  policy = data.aws_iam_policy_document.link.json
}
