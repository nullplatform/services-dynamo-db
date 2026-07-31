################################################################################
# Stream -> Lambda trigger
#
# DynamoDB does not push to Lambda: Lambda polls the stream. That shapes this
# module in two ways.
#
# First, there is no resource-based policy on the function — nothing invokes it
# from outside. What is needed is for the function's own execution role to be
# able to read the stream, so we attach an inline policy to it.
#
# Second, the execution role belongs to the Lambda scope, not to this service.
# We add a policy under our own name so the scope can keep managing the role
# without the two fighting over it.
################################################################################

# The function must already exist: the trigger is created when an application
# is linked, and the application is deployed by the Lambda scope beforehand.
# Reading it here also gives us the execution role and fails with a clear
# message if the link was created against an application that is not a Lambda.
data "aws_lambda_function" "target" {
  function_name = var.function_name
  qualifier     = var.alias_name
}

locals {
  # data.aws_lambda_function.role is the role ARN; the policy resource wants
  # the name.
  execution_role_name = element(split("/", data.aws_lambda_function.target.role), length(split("/", data.aws_lambda_function.target.role)) - 1)

  policy_name = "np-ddb-stream-${substr(replace(var.link_id, "-", ""), 0, 16)}"
}

resource "aws_iam_role_policy" "stream_read" {
  name = local.policy_name
  role = local.execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadTableStream"
      Effect = "Allow"
      Action = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams",
      ]
      Resource = var.stream_arn
    }]
  })
}

resource "aws_lambda_event_source_mapping" "trigger" {
  event_source_arn = var.stream_arn

  # The alias ARN, not the function ARN. With the bare function the mapping
  # consumes $LATEST, which after a blue/green deployment is not necessarily
  # the version serving traffic. The data source exposes both: .arn drops the
  # qualifier, .qualified_arn keeps it.
  function_name = data.aws_lambda_function.target.qualified_arn

  starting_position = var.starting_position
  enabled           = var.enabled

  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.batching_window_seconds

  # Lets the function checkpoint past the records it did process instead of the
  # whole batch being retried because one record failed. Harmless for functions
  # that do not implement it: returning nothing still counts as a full success.
  function_response_types = ["ReportBatchItemFailures"]

  # Without this a single poison record blocks its shard until it expires,
  # taking everything queued behind it. Bisecting isolates the bad record
  # instead of dragging the healthy ones down with it.
  bisect_batch_on_function_error = true

  # The mapping is rejected if the role cannot read the stream yet, and IAM is
  # eventually consistent, so the policy has to land first.
  depends_on = [aws_iam_role_policy.stream_read]
}
