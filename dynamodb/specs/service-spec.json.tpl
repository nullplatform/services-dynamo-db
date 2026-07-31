{
  "name": "AWS DynamoDB",
  "slug": "aws-dynamodb",
  "type": "dependency",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "available_links": ["connect", "trigger"],
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
      "required": ["billing_mode", "hash_key", "hash_key_type"],
      "properties": {
        "billing_mode": {
          "type": "string",
          "title": "Billing Mode",
          "default": "PAY_PER_REQUEST",
          "enum": ["PAY_PER_REQUEST", "PROVISIONED"],
          "description": "PAY_PER_REQUEST (on-demand) scales automatically and you pay per request. PROVISIONED requires you to set read/write capacity units.",
          "editableOn": ["create", "update"],
          "order": 1
        },
        "hash_key": {
          "type": "string",
          "title": "Partition Key",
          "description": "Name of the attribute used as partition key. Cannot be changed after creation.",
          "pattern": "^[a-zA-Z0-9_.-]{1,255}$",
          "editableOn": ["create"],
          "order": 2
        },
        "hash_key_type": {
          "type": "string",
          "title": "Partition Key Type",
          "default": "S",
          "enum": ["S", "N", "B"],
          "description": "S = String, N = Number, B = Binary. Cannot be changed after creation.",
          "editableOn": ["create"],
          "order": 3
        },
        "range_key": {
          "type": "string",
          "title": "Sort Key",
          "default": "",
          "description": "Optional attribute used as sort key. Leave empty for a partition-key-only table. Cannot be changed after creation.",
          "editableOn": ["create"],
          "order": 4
        },
        "range_key_type": {
          "type": "string",
          "title": "Sort Key Type",
          "default": "S",
          "enum": ["S", "N", "B"],
          "description": "Attribute type for the sort key. Only used when a sort key is set.",
          "editableOn": ["create"],
          "order": 5
        },
        "read_capacity": {
          "type": "integer",
          "title": "Read Capacity Units",
          "default": 5,
          "minimum": 1,
          "description": "Provisioned read capacity. Only used when Billing Mode is PROVISIONED.",
          "editableOn": ["create", "update"],
          "order": 6
        },
        "write_capacity": {
          "type": "integer",
          "title": "Write Capacity Units",
          "default": 5,
          "minimum": 1,
          "description": "Provisioned write capacity. Only used when Billing Mode is PROVISIONED.",
          "editableOn": ["create", "update"],
          "order": 7
        },
        "deletion_protection": {
          "type": "boolean",
          "title": "Deletion Protection",
          "default": false,
          "description": "Prevents the table from being deleted by AWS. Must be turned off before deleting this service.",
          "editableOn": ["create", "update"],
          "order": 8
        },
        "ttl_enabled": {
          "type": "boolean",
          "title": "Enable TTL",
          "default": false,
          "description": "Automatically delete items once the timestamp in the TTL attribute has passed.",
          "editableOn": ["create", "update"],
          "order": 9
        },
        "ttl_attribute_name": {
          "type": "string",
          "title": "TTL Attribute",
          "default": "expires_at",
          "description": "Item attribute holding the expiration time as a Unix epoch timestamp in seconds. Only used when TTL is enabled.",
          "editableOn": ["create", "update"],
          "order": 10
        },
        "global_secondary_indexes": {
          "type": "array",
          "title": "Global Secondary Indexes",
          "default": [],
          "description": "Additional query patterns on attributes other than the table keys.",
          "editableOn": ["create", "update"],
          "order": 11,
          "items": {
            "type": "object",
            "required": ["name", "hash_key", "hash_key_type"],
            "properties": {
              "name": {
                "type": "string",
                "title": "Index Name",
                "pattern": "^[a-zA-Z0-9_.-]{3,255}$",
                "description": "Unique name for this index"
              },
              "hash_key": {
                "type": "string",
                "title": "Index Partition Key",
                "description": "Attribute used as partition key for this index"
              },
              "hash_key_type": {
                "type": "string",
                "title": "Index Partition Key Type",
                "default": "S",
                "enum": ["S", "N", "B"]
              },
              "range_key": {
                "type": "string",
                "title": "Index Sort Key",
                "default": "",
                "description": "Optional attribute used as sort key for this index"
              },
              "range_key_type": {
                "type": "string",
                "title": "Index Sort Key Type",
                "default": "S",
                "enum": ["S", "N", "B"]
              },
              "projection_type": {
                "type": "string",
                "title": "Projected Attributes",
                "default": "ALL",
                "enum": ["ALL", "KEYS_ONLY", "INCLUDE"],
                "description": "ALL copies every attribute into the index. KEYS_ONLY copies only the keys. INCLUDE copies the keys plus the attributes you list."
              },
              "non_key_attributes": {
                "type": "array",
                "title": "Included Attributes",
                "default": [],
                "items": {"type": "string"},
                "description": "Extra attributes to project. Only used when Projected Attributes is INCLUDE."
              },
              "read_capacity": {
                "type": "integer",
                "title": "Index Read Capacity Units",
                "default": 5,
                "minimum": 1,
                "description": "Only used when Billing Mode is PROVISIONED"
              },
              "write_capacity": {
                "type": "integer",
                "title": "Index Write Capacity Units",
                "default": 5,
                "minimum": 1,
                "description": "Only used when Billing Mode is PROVISIONED"
              }
            }
          }
        },
        "table_name": {
          "type": "string",
          "title": "Table Name",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Actual DynamoDB table name (auto-populated after creation)",
          "order": 12
        },
        "table_arn": {
          "type": "string",
          "title": "Table ARN",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "DynamoDB table ARN (auto-populated after creation)",
          "order": 13
        },
        "stream_arn": {
          "type": "string",
          "title": "Stream ARN",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "ARN of the table's DynamoDB stream, used to wire triggers (auto-populated after creation)",
          "order": 14
        },
        "table_region": {
          "type": "string",
          "title": "Table Region",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "AWS region where the table lives (auto-populated after creation)",
          "order": 15
        },
        "table_id": {
          "type": "string",
          "title": "Table ID",
          "export": false,
          "visibleOn": [],
          "editableOn": [],
          "description": "Internal DynamoDB table identifier"
        }
      }
    },
    "values": {}
  }
}
