# ═══════════════════════════════════════════════════════════════════
#  OUTPUTS — use these to configure your Flutter amplifyconfiguration
# ═══════════════════════════════════════════════════════════════════

# ── Cognito ───────────────────────────────────────────────────────
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.mobile.id
}

output "cognito_user_pool_domain" {
  description = "Cognito Hosted UI domain"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

# ── API Gateway ───────────────────────────────────────────────────
output "api_gateway_url" {
  description = "Base URL for all REST API calls"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/${var.environment}"
}

# ── AppSync ───────────────────────────────────────────────────────
output "appsync_graphql_url" {
  description = "AppSync GraphQL endpoint"
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
}

output "appsync_realtime_url" {
  description = "AppSync real-time (WebSocket) endpoint"
  value       = aws_appsync_graphql_api.main.uris["REALTIME"]
}

# ── S3 ────────────────────────────────────────────────────────────
output "voice_bucket_name" {
  description = "S3 bucket name for voice audio uploads"
  value       = aws_s3_bucket.voice_files.bucket
}

# ── DynamoDB ──────────────────────────────────────────────────────
output "tasks_table_name" {
  description = "DynamoDB Tasks table name"
  value       = aws_dynamodb_table.tasks.name
}

output "habits_logs_table_name" {
  description = "DynamoDB HabitsLogs table name (Agent Memory Layer)"
  value       = aws_dynamodb_table.habits_logs.name
}

# ── SNS ───────────────────────────────────────────────────────────
output "sns_topic_arn" {
  description = "SNS topic ARN for push notifications"
  value       = aws_sns_topic.notifications.arn
}

# ── Helper config block for Flutter ──────────────────────────────
output "flutter_amplify_config_hint" {
  description = "Values to paste into Flutter amplifyconfiguration.dart"
  value = {
    auth = {
      userPoolId        = aws_cognito_user_pool.main.id
      userPoolClientId  = aws_cognito_user_pool_client.mobile.id
      region            = var.aws_region
    }
    api = {
      restApiUrl    = "${aws_apigatewayv2_api.main.api_endpoint}/${var.environment}"
      graphqlApiUrl = aws_appsync_graphql_api.main.uris["GRAPHQL"]
    }
    storage = {
      bucketName = aws_s3_bucket.voice_files.bucket
      region     = var.aws_region
    }
  }
  sensitive = false
}
