{
  "name": "Trigger",
  "slug": "trigger",
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
      "required": ["starting_position"],
      "properties": {
        "starting_position": {
          "type": "string",
          "title": "Start Reading From",
          "default": "TRIM_HORIZON",
          "enum": ["TRIM_HORIZON", "LATEST"],
          "description": "TRIM_HORIZON reads every record still in the stream, LATEST only the ones written from now on. Setting up a trigger takes a few minutes to start polling, so LATEST can miss events created in that window.",
          "editableOn": ["create", "update"],
          "order": 1
        },
        "batch_size": {
          "type": "integer",
          "title": "Batch Size",
          "default": 100,
          "minimum": 1,
          "maximum": 10000,
          "description": "How many records the function receives per invocation, at most. A batch is also capped at 6 MB.",
          "editableOn": ["create", "update"],
          "order": 2
        },
        "batching_window_seconds": {
          "type": "integer",
          "title": "Batching Window (seconds)",
          "default": 0,
          "minimum": 0,
          "maximum": 300,
          "description": "How long to wait accumulating records before invoking the function. Zero invokes as soon as records are available.",
          "editableOn": ["create", "update"],
          "order": 3
        },
        "enabled": {
          "type": "boolean",
          "title": "Enabled",
          "default": true,
          "description": "Turn the trigger off without deleting it. While off, records accumulate in the stream and expire after 24 hours.",
          "editableOn": ["create", "update"],
          "order": 4
        },
        "function_name": {
          "type": "string",
          "title": "Lambda Function",
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Function this trigger invokes (resolved from the linked application)",
          "order": 5
        },
        "trigger_id": {
          "type": "string",
          "title": "Trigger ID",
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "AWS identifier of the event source mapping",
          "order": 6
        }
      }
    },
    "values": {}
  }
}
