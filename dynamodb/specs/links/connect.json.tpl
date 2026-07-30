{
  "name": "Connect",
  "slug": "connect",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "selectors": {
    "category": "Database",
    "imported": false,
    "provider": "AWS",
    "sub_category": "NoSQL Database"
  },
  "attributes": {
    "schema": {
      "type": "object",
      "$schema": "http://json-schema.org/draft-07/schema#",
      "required": ["access_level"],
      "properties": {
        "access_level": {
          "enum": ["read", "read-write", "full"],
          "type": "string",
          "title": "Access Level",
          "default": "read-write",
          "editableOn": ["create", "update"],
          "description": "Permission level: read (GetItem/Query/Scan), read-write (adds PutItem/UpdateItem/DeleteItem and batch writes), full (adds PartiQL statements)",
          "order": 1
        },
        "aws_access_key_id": {
          "type": "string",
          "title": "AWS Access Key ID",
          "export": {"type": "environment_variable"},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "IAM user access key ID (auto-populated after link creation)",
          "order": 2
        },
        "aws_secret_access_key": {
          "type": "string",
          "title": "AWS Secret Access Key",
          "export": {"type": "environment_variable", "secret": true},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "IAM user secret access key (auto-populated, delivered as secret env var)",
          "order": 3
        },
        "table_name": {
          "type": "string",
          "title": "Table Name",
          "export": {"type": "environment_variable"},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "DynamoDB table name this link grants access to (propagated from the service)",
          "order": 4
        },
        "table_region": {
          "type": "string",
          "title": "Table Region",
          "export": {"type": "environment_variable"},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "AWS region of the table (propagated from the service)",
          "order": 5
        },
        "iam_user_name": {
          "type": "string",
          "export": false,
          "visibleOn": [],
          "editableOn": [],
          "description": "Internal IAM user name created for this link"
        }
      }
    },
    "values": {}
  }
}
