locals {
  # Read actions every level needs. DescribeTable is required by most SDKs to
  # discover the key schema before issuing queries.
  read_actions = [
    "dynamodb:GetItem",
    "dynamodb:BatchGetItem",
    "dynamodb:Query",
    "dynamodb:Scan",
    "dynamodb:ConditionCheckItem",
    "dynamodb:DescribeTable",
    "dynamodb:DescribeTimeToLive",
    "dynamodb:ListTagsOfResource",
  ]

  write_actions = [
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem",
    "dynamodb:BatchWriteItem",
  ]

  # PartiQL is a separate surface: it can read and write through statements
  # that the item-level actions above do not cover, so it is opt-in.
  partiql_actions = [
    "dynamodb:PartiQLSelect",
    "dynamodb:PartiQLInsert",
    "dynamodb:PartiQLUpdate",
    "dynamodb:PartiQLDelete",
  ]

  iam_actions = {
    read         = local.read_actions
    "read-write" = concat(local.read_actions, local.write_actions)
    full         = concat(local.read_actions, local.write_actions, local.partiql_actions)
  }

  # The table plus every index under it. Queries against a global secondary
  # index are authorized on the index ARN, not the table ARN, so both are
  # needed for a link to be able to use the indexes the service created.
  table_resources = [
    var.table_arn,
    "${var.table_arn}/index/*",
  ]
}
