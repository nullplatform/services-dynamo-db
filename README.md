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

| Link | What the application gets |
| :---- | :---- |
| `connect` | A dedicated IAM user with an access key, scoped to the table and its indexes. Access levels: `read`, `read-write`, `full` (adds PartiQL). |

## Layout

```
dynamodb/
├── specs/
│   ├── service-spec.json.tpl      # capabilities shown to the developer
│   ├── links/connect.json.tpl
│   └── requirements/aws/          # IAM role the agent assumes
├── deployment/                    # the table
├── permissions/                   # per-link IAM user
├── scripts/aws/                   # context building and tofu execution
├── utils/                         # assume role helpers
├── entrypoint/                    # action routing
├── workflows/aws/                 # create, update, delete, read, link, link-update, unlink
└── values.yaml                    # static config, not exposed in the UI
```

## Installation

**1. Create the permissions role.** Apply `dynamodb/specs/requirements/aws` in the target AWS account:

```hcl
module "dynamodb_requirements" {
  source       = "git::https://github.com/nullplatform/services-dynamo-db.git//dynamodb/specs/requirements/aws?ref=main"
  cluster_name = "<your-cluster>"
}
```

**2. Publish the role.** Register `permissions_role_arn` in the nullplatform AWS IAM provider under the selector **`dynamodb`**, and allow the agent role to assume it.

**3. Register the service.** Point a `service_definition` at this repository with `service_path = "dynamodb"`, and add it to the agent's repository list.

## How it works

Every service instance keeps its Terraform state in its own S3 bucket (`np-service-<service-id>`), created on demand and removed when the service is deleted. Links use the same bucket under a separate key, so creating or removing a link never touches the table state.

Before any AWS call, each workflow assumes the permissions role resolved from the IAM provider. When no role is configured the agent's own credentials are used, which is what makes local testing work.

The table name is computed once from the service name and then frozen in the service attributes. Renaming the service does not rename the table — the name is a ForceNew attribute in AWS and changing it would destroy the table along with its data.

## Local testing

Set `aws_profile` in `values.yaml`, run `aws sso login --profile <name>`, and start the agent locally. The service falls back to those credentials when no IAM provider is configured.
