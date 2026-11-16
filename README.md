# services-dynamo-db

Nullplatform service that provisions **AWS DynamoDB** tables and connects them to applications.

## What it does

Creates a DynamoDB table per service instance and hands applications scoped credentials to use it. Streams are always on, so a table can feed a Lambda trigger without extra configuration.

| Capability | Notes |
| :---- | :---- |
| Partition and sort key | Set at creation; both are immutable afterwards |
| Billing mode | On-demand or provisioned, switchable |
| Global secondary indexes | Added and removed after creation |
| TTL | Automatic item expiry on a timestamp attribute |
| Deletion protection | Must be turned off before deleting the service |
| Streams | Always enabled, `NEW_AND_OLD_IMAGES` |
| Metrics | Four CloudWatch metrics of the table, queried for the time range picked in the UI |

## Links

| Link | What it does |
| :---- | :---- |
| `connect` | Gives the application a dedicated IAM user with an access key, scoped to the table and its indexes. Access levels: `read`, `read-write`, `full` (adds PartiQL). |
| `trigger` | Makes every change to the table invoke the application's Lambda function. The application receives nothing — the wiring happens on the AWS side. |

## Layout

```
dynamodb/
├── specs/
│   ├── service-spec.json.tpl      # capabilities shown to the developer
│   ├── links/connect.json.tpl
│   ├── links/trigger.json.tpl
│   └── requirements/aws/          # IAM role the agent assumes
├── publish/                       # publishes the service as a package (release workflow only)
├── deployment/                    # the table
├── permissions/                   # connect link: per-link IAM user
├── trigger/                       # trigger link: stream to Lambda
├── scripts/aws/                   # context building and tofu execution
├── utils/                         # assume role helpers
├── entrypoint/                    # action routing
├── workflows/aws/                 # per action, and per link type where they differ
└── values.yaml                    # static config, not exposed in the UI
```

## Install in your organization

The service is published once as the package `np-aws-dynamodb` (specification "AWS DynamoDB"), visible to every organization. You do not copy its specs: you install the package and use it read-only.

How installing a package works, how it coexists with a copy you registered, how to upgrade, and when to fork instead are in the [package installation guide](https://docs.nullplatform.com/docs/packages/install); this section has what is specific to this service.

Installing it touches the same three layers as registering a service yourself, and only the nullplatform layer changes:

| Layer | What | Module |
|---|---|---|
| infrastructure (AWS credentials) | The IAM role the service assumes, and the metrics policy of the agent role | [`dynamodb/specs/requirements/aws`](./dynamodb/specs/requirements/aws) |
| nullplatform (nullplatform API key) | The installation of the package and the agent channel | tofu-modules' `service_package_installation` |
| bindings | The role under selector `dynamodb` in your IAM provider | your `aws-iam-configuration` provider |

Pick ONE release of this repository (the latest is on its [releases page](https://github.com/nullplatform/services-dynamo-db/releases)) and use its version in both places below: the IAM role is the one the worker of that same release expects.

```hcl
# ── infrastructure layer ─────────────────────────────────────────────
module "dynamodb_requirements" {
  source            = "git::https://github.com/nullplatform/services-dynamo-db.git//dynamodb/specs/requirements/aws?ref=vX.Y.Z"
  cluster_name      = "<your-cluster>"
  state_bucket_name = "<your-existing-state-bucket>"
}

# The agent role must be allowed to assume it: add it to the assume_role_arns
# of tofu-modules' infrastructure/aws/iam/agent.
#   assume_role_arns = [..., module.dynamodb_requirements.permissions_role_arn]

# ── nullplatform layer ───────────────────────────────────────────────
# The same module a catalog entry with `install_package` becomes. For a
# service the installation is the whole nullplatform side, channel included.
module "dynamodb" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_package_installation?ref=v9.16.0"

  nrn                  = var.nrn
  package_slug         = "np-aws-dynamodb"
  package_version      = "X.Y.Z" # the same release, without the v
  agent_tags_selectors = { cluster = "runtime" } # must match the agent's TAGS
  # channel_sources defaults to ["service", "telemetry"]: without telemetry the
  # service shows no metrics.
}
# Keeping channels in a separate bindings layer instead? Use
# nullplatform/package_installation here and service_definition_agent_association
# there, with package_slug = "np-aws-dynamodb" and channel_sources = ["service", "telemetry"].

# ── bindings layer ───────────────────────────────────────────────────
# One aws-iam-configuration per NRN and dimensions: add the entry to the list
# your IAM provider already has.
#   { selector = "dynamodb", arn = module.dynamodb_requirements.permissions_role_arn }
```

The agent role itself needs `cloudwatch:GetMetricStatistics` on `*`: metrics run on the agent's credentials, never on the permissions role, so they cost a single AWS call. The requirements module attaches that policy to `agent_role_arn` and `additional_agent_role_arns`; set `attach_metrics_policy_to_agent_roles = false` if the agent role is managed elsewhere.

The service assumes the role it finds under selector `dynamodb` in the IAM provider closest to its NRN. To upgrade, move the release in both layers: `ref` of the requirements module and `package_version` of the installation. See tofu-modules' [`service_package_installation`](https://github.com/nullplatform/tofu-modules/tree/main/nullplatform/service_package_installation) for its inputs and outputs.

Prerequisites: an agent whose `TAGS` match the channel's `tags_selectors`, with `public.ecr.aws/nullplatform/*` in `worker.allowedRegistries` and `np-aws-dynamodb` in its `worker_orchestrated_packages` (the worker then runs with the agent's identity, the one the role trusts), and an AWS cloud provider exposing `account.region` at the NRN or above it.

## How the package is published

Every release publishes a new revision of the package from this repository, in the same run that pushes the worker image ([`.github/workflows/release.yml`](./.github/workflows/release.yml)): the `publish-package` job applies [`dynamodb/publish`](./dynamodb/publish), a stack on tofu-modules' `service_package_publish`, which pins this tag's specs and the image by digest. The package version is the release tag, as for the image.

## How it works

Set `DYNAMO_S3_STATE_BUCKET` on the agent to the name of an existing S3 bucket, and every service instance keeps its Terraform state there under `services/dynamodb/<service-id>/`. Links use the same prefix under a separate key, so creating or removing a link never touches the table state. Deleting a service removes only its own prefix; the bucket is never touched.

The bucket must already exist — the service does not create it, and any name works. Pass it as `state_bucket_name` to the `specs/requirements/aws` module, which grants the role access to that bucket and nothing else.

`DYNAMO_S3_STATE_BUCKET` is required. Without it every action fails before touching AWS.

Earlier versions created one bucket per instance (`np-service-<service-id>`) and deleted it with the service. That is gone. **Instances provisioned by those versions must have their state moved before the next action runs**, or tofu will start from an empty state and try to create a table that already exists:

```bash
aws s3 cp "s3://np-service-<service-id>/terraform.tfstate" \
          "s3://<shared-bucket>/services/dynamodb/<service-id>/terraform.tfstate"

# links, if the instance has any
aws s3 cp --recursive "s3://np-service-<service-id>/links/" \
                      "s3://<shared-bucket>/services/dynamodb/<service-id>/links/"

aws s3 rb "s3://np-service-<service-id>" --force
```

The old bucket can go once the copy is verified.

Before any AWS call, each workflow assumes the permissions role resolved from the IAM provider. When no role is configured the agent's own credentials are used, which is what makes local testing work.

The table name is computed once from the service name and then frozen in the service attributes. Renaming the service does not rename the table — the name is a ForceNew attribute in AWS and changing it would destroy the table along with its data.

## Metrics

`metric:list` and `metric:data` notifications run `scripts/aws/list_metrics` and `scripts/aws/fetch_metric` directly from `entrypoint/metric`, without `np service workflow exec` and without assuming the permissions role. `metric:data` makes one AWS call, to CloudWatch: `AWS/DynamoDB` with the dimension `TableName = table_name`, in the `table_region` of the service, for the requested `start_time`, `end_time` and `period` (rounded up to a multiple of 60 seconds).

| Metric | Statistic | Unit |
| :---- | :---- | :---- |
| `ConsumedReadCapacityUnits` | Sum | count |
| `ConsumedWriteCapacityUnits` | Sum | count |
| `ReadThrottleEvents` | Sum | count |
| `WriteThrottleEvents` | Sum | count |

Only metrics CloudWatch publishes with `TableName` alone are offered. Latency, system errors and returned items need the `Operation` dimension, and the provisioned capacity metrics exist only for provisioned tables, so none of them are listed. CloudWatch publishes no datapoint while a table is idle, so these graphs are empty until the table has traffic.

A service whose table does not exist yet returns an empty series. A CloudWatch error fails the request instead of showing an empty graph.

The service has no logs: `log:*` notifications run `scripts/aws/read_logs`, which answers with no entries. Telemetry scripts print nothing but their result, since stdout is the response. Workflow overrides do not apply to telemetry.

## Triggers

A `trigger` link points the event source mapping at the function's **alias**, not at the function itself, so a blue/green deployment does not leave the trigger consuming a version that no longer serves traffic.

Two defaults worth knowing. Reading starts at the beginning of the stream rather than at the newest record: setting up a mapping takes a few minutes to start polling, and starting at the newest record would silently skip everything written in that window. And batches are bisected on error, so a single failing record is isolated instead of blocking its shard until the record expires.

Delivery is at-least-once, so handlers must be idempotent. Functions that report partial batch failures get them honoured; functions that do not are unaffected.

The target function is resolved from the linked scope using the Lambda scope's naming convention. If that convention ever changes, the trigger fails with "function not found" rather than wiring something wrong.

Because the function name is derived from the scope, the link is only meaningful when bound to one: attached to the application, the context arrives without `tags.scope_id` and there is nothing to wire. The spec declares `assignable_to: scope` so the platform does not offer it at application level. Note that this only takes effect once the registering module forwards the field — `service_definition` currently does not.

## Local testing

Set `aws_profile` in `values.yaml`, run `aws sso login --profile <name>`, and start the agent locally. The service falls back to those credentials when no IAM provider is configured.
