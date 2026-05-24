# ═══════════════════════════════════════════════════════════════════
#  AWS Amplify — Flutter App Hosting / Config Stub
#  The outputs here are used to generate amplifyconfiguration.dart
# ═══════════════════════════════════════════════════════════════════

resource "aws_amplify_app" "main" {
  name        = "${local.name_prefix}-flutter"
  description = "Mobile Scheduler Flutter application"

  # Build settings (for web/CI; Flutter mobile build is local)
  build_spec = <<-YAML
    version: 1
    frontend:
      phases:
        build:
          commands:
            - echo "Flutter mobile build is done locally"
      artifacts:
        baseDirectory: /
        files:
          - '**/*'
  YAML

  # Environment variables available to the Amplify build
  environment_variables = {
    COGNITO_USER_POOL_ID      = aws_cognito_user_pool.main.id
    COGNITO_APP_CLIENT_ID     = aws_cognito_user_pool_client.mobile.id
    API_GATEWAY_URL           = "${aws_apigatewayv2_api.main.api_endpoint}/${var.environment}"
    APPSYNC_GRAPHQL_URL       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
    S3_VOICE_BUCKET           = aws_s3_bucket.voice_files.bucket
    AWS_REGION                = var.aws_region
    ENVIRONMENT               = var.environment
  }

  tags = {
    Name = "${local.name_prefix}-amplify"
  }
}

# ── Amplify Branch (main) ─────────────────────────────────────────
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.main.id
  branch_name = "main"
  stage       = var.environment == "prod" ? "PRODUCTION" : "DEVELOPMENT"

  environment_variables = {
    ENVIRONMENT = var.environment
  }
}
