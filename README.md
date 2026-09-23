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
│   └── requirements/aws/          # IAM role the agent assumes
├── deployment/                    # the table
├── permissions/                   # connect link: per-link IAM user
├── trigger/                       # trigger link: stream to Lambda
├── scripts/aws/                   # context building and tofu execution
├── utils/                         # assume role helpers
├── entrypoint/                    # action routing
├── workflows/aws/                 # per action, and per link type where they differ
└── values.yaml                    # static config, not exposed in the UI
```

## Installation

**1. Create the permissions role.** Apply `dynamodb/specs/requirements/aws` in the target AWS account:

```hcl
module "dynamodb_requirements" {
  source            = "git::https://github.com/nullplatform/services-dynamo-db.git//dynamodb/specs/requirements/aws?ref=main"
  cluster_name      = "<your-cluster>"
  state_bucket_name = "<your-existing-state-bucket>"
}
```

**2. Publish the role.** Register `permissions_role_arn` in the nullplatform AWS IAM provider under the selector **`dynamodb`**, and allow the agent role to assume it.

**3. Register the service.** Point a `service_definition` at this repository with `service_path = "dynamodb"`, and add it to the agent's repository list.

## How it works

Set `DYNAMO_S3_STATE_BUCKET` on the agent to the name of an existing S3 bucket, and every service instance keeps its Terraform state there under `services/<service-id>/`. Links use the same prefix under a separate key, so creating or removing a link never touches the table state. Deleting a service removes only its own prefix; the bucket is never touched.

The bucket must already exist — the service does not create it, and any name works. Pass it as `state_bucket_name` to the `specs/requirements/aws` module, which grants the role access to that bucket and nothing else.

`DYNAMO_S3_STATE_BUCKET` is required. Without it every action fails before touching AWS.

Earlier versions created one bucket per instance (`np-service-<service-id>`) and deleted it with the service. That is gone. **Instances provisioned by those versions must have their state moved before the next action runs**, or tofu will start from an empty state and try to create a table that already exists:

```bash
aws s3 cp "s3://np-service-<service-id>/terraform.tfstate" \
          "s3://<shared-bucket>/services/<service-id>/terraform.tfstate"

# links, if the instance has any
aws s3 cp --recursive "s3://np-service-<service-id>/links/" \
                      "s3://<shared-bucket>/services/<service-id>/links/"

aws s3 rb "s3://np-service-<service-id>" --force
```

The old bucket can go once the copy is verified.

Before any AWS call, each workflow assumes the permissions role resolved from the IAM provider. When no role is configured the agent's own credentials are used, which is what makes local testing work.

The table name is computed once from the service name and then frozen in the service attributes. Renaming the service does not rename the table — the name is a ForceNew attribute in AWS and changing it would destroy the table along with its data.

## Triggers

A `trigger` link points the event source mapping at the function's **alias**, not at the function itself, so a blue/green deployment does not leave the trigger consuming a version that no longer serves traffic.

Two defaults worth knowing. Reading starts at the beginning of the stream rather than at the newest record: setting up a mapping takes a few minutes to start polling, and starting at the newest record would silently skip everything written in that window. And batches are bisected on error, so a single failing record is isolated instead of blocking its shard until the record expires.

Delivery is at-least-once, so handlers must be idempotent. Functions that report partial batch failures get them honoured; functions that do not are unaffected.

The target function is resolved from the linked scope using the Lambda scope's naming convention. If that convention ever changes, the trigger fails with "function not found" rather than wiring something wrong.

Because the function name is derived from the scope, the link is only meaningful when bound to one: attached to the application, the context arrives without `tags.scope_id` and there is nothing to wire. The spec declares `assignable_to: scope` so the platform does not offer it at application level. Note that this only takes effect once the registering module forwards the field — `service_definition` currently does not.

## Local testing

Set `aws_profile` in `values.yaml`, run `aws sso login --profile <name>`, and start the agent locally. The service falls back to those credentials when no IAM provider is configured.
