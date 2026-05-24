# ═══════════════════════════════════════════════════════════════════
#  DynamoDB Tables
#  • tasks          — primary data store + DynamoDB Streams
#  • habits_logs    — Agent Memory Layer (habits & interaction logs)
# ═══════════════════════════════════════════════════════════════════

# ── Tasks Table ───────────────────────────────────────────────────
resource "aws_dynamodb_table" "tasks" {
  name         = "${local.name_prefix}-tasks"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "userId"
  range_key    = "taskId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "taskId"
    type = "S"
  }

  attribute {
    name = "dueDate"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI — query tasks by dueDate for a user
  global_secondary_index {
    name            = "UserDueDateIndex"
    hash_key        = "userId"
    range_key       = "dueDate"
    projection_type = "ALL"
  }

  # GSI — query tasks by status for a user (active, completed, missed)
  global_secondary_index {
    name            = "UserStatusIndex"
    hash_key        = "userId"
    range_key       = "status"
    projection_type = "ALL"
  }

  # DynamoDB Streams — triggers scheduler_agent Lambda
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Encryption at rest
  server_side_encryption {
    enabled = true
  }

  # TTL — optional: auto-expire old tasks after 90 days (Unix timestamp)
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = {
    Name = "${local.name_prefix}-tasks"
  }
}

# ── HabitsLogs Table (Agent Memory Layer) ────────────────────────
resource "aws_dynamodb_table" "habits_logs" {
  name         = "${local.name_prefix}-habits-logs"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "userId"
  range_key    = "timestamp"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "entryType"
    type = "S"
  }

  # GSI — query memory entries by type (habit | interaction | feedback)
  global_secondary_index {
    name            = "UserEntryTypeIndex"
    hash_key        = "userId"
    range_key       = "entryType"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  # Auto-expire old habit logs after 1 year
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = {
    Name = "${local.name_prefix}-habits-logs"
  }
}
