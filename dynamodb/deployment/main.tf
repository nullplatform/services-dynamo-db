locals {
  common_tags = merge(var.tags, {
    "managed-by" = "nullplatform"
    "service-id" = var.service_id
  })

  has_range_key  = trimspace(var.range_key) != ""
  is_provisioned = var.billing_mode == "PROVISIONED"

  # -------------------------------------------------------------------------
  # Attribute definitions.
  #
  # DynamoDB only accepts attributes that participate in a key schema — the
  # table keys plus every index key — and rejects the table outright if the
  # same attribute is declared twice. We collect all of them and dedupe by
  # name, keeping insertion order (table keys first).
  # -------------------------------------------------------------------------
  declared_attributes = concat(
    [{ name = var.hash_key, type = var.hash_key_type }],
    local.has_range_key ? [{ name = var.range_key, type = var.range_key_type }] : [],
    flatten([
      for gsi in var.global_secondary_indexes : concat(
        [{ name = gsi.hash_key, type = gsi.hash_key_type }],
        trimspace(gsi.range_key) != "" ? [{ name = gsi.range_key, type = gsi.range_key_type }] : []
      )
    ])
  )

  # The ellipsis is required: a plain object comprehension errors out on
  # duplicate keys instead of collapsing them, and reusing an attribute across
  # indexes is the normal case. Grouping and taking the first keeps one entry
  # per name.
  attributes = [
    for name, group in { for a in local.declared_attributes : a.name => a... } : group[0]
  ]

  # Same attribute name declared with two different types: the map above would
  # silently keep the last one and DynamoDB would build an index over the wrong
  # type. Compared as name:type pairs, a conflict shows up as a count mismatch.
  attribute_conflict = length(local.attributes) != length(distinct([
    for a in local.declared_attributes : "${a.name}:${a.type}"
  ]))

  range_key_equals_hash_key = local.has_range_key && trimspace(var.range_key) == trimspace(var.hash_key)
}

resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = local.has_range_key ? var.range_key : null

  read_capacity  = local.is_provisioned ? var.read_capacity : null
  write_capacity = local.is_provisioned ? var.write_capacity : null

  deletion_protection_enabled = var.deletion_protection

  # -------------------------------------------------------------------------
  # Streams are always on, and the event always carries both images.
  #
  # These are deliberately not variables. Enabling a stream costs nothing —
  # there is no charge for the stream itself nor for its 24h retention, and
  # reads performed by a Lambda trigger are not billed — so leaving it off
  # would only add a configuration step before every trigger.
  #
  # Keeping the view type fixed also keeps the stream ARN stable: changing it
  # recreates the stream under a new ARN and every event source mapping
  # pointing at the old one silently stops receiving records.
  # -------------------------------------------------------------------------
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  dynamic "attribute" {
    for_each = local.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_enabled ? [1] : []
    content {
      attribute_name = var.ttl_attribute_name
      enabled        = true
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = trimspace(global_secondary_index.value.range_key) != "" ? global_secondary_index.value.range_key : null
      projection_type = global_secondary_index.value.projection_type

      non_key_attributes = (
        global_secondary_index.value.projection_type == "INCLUDE"
        ? global_secondary_index.value.non_key_attributes
        : null
      )

      read_capacity  = local.is_provisioned ? global_secondary_index.value.read_capacity : null
      write_capacity = local.is_provisioned ? global_secondary_index.value.write_capacity : null
    }
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = !local.range_key_equals_hash_key
      error_message = "The sort key and the partition key are both set to '${var.hash_key}'. A table cannot use the same attribute for both: pick a different attribute for the sort key, or leave it empty for a partition-key-only table."
    }

    precondition {
      condition     = !local.attribute_conflict
      error_message = "The same attribute is declared with two different types across the table keys and the global secondary indexes. Every index that reuses an attribute must declare the same type for it."
    }
  }
}
