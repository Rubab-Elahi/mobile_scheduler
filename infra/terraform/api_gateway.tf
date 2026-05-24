# ═══════════════════════════════════════════════════════════════════
#  API Gateway v2 (HTTP API)
#  JWT Authorizer → Cognito User Pool
#  Routes map to Lambda integration targets
# ═══════════════════════════════════════════════════════════════════

# ── HTTP API ──────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "Mobile Scheduler REST API"

  cors_configuration {
    allow_headers = ["Authorization", "Content-Type", "X-Amz-Date", "X-Api-Key"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["*"] # Tighten to Flutter app origin in prod
    max_age       = 300
  }
}

# ── JWT Authorizer (Cognito) ──────────────────────────────────────
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.name_prefix}-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.mobile.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

# ── Stage ─────────────────────────────────────────────────────────
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format          = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = 14
}

# ═══════════════════════════════════════════════════════════════════
#  Lambda Integrations
# ═══════════════════════════════════════════════════════════════════

resource "aws_apigatewayv2_integration" "task_service" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.task_service.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "voice_service" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.voice_service.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "agentic_ai_service" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.agentic_ai_service.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "google_cal_sync" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.google_cal_sync.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# ═══════════════════════════════════════════════════════════════════
#  Routes — /tasks, /voice, /ai, /calendar
# ═══════════════════════════════════════════════════════════════════

locals {
  task_routes = [
    "GET /tasks",
    "POST /tasks",
    "PUT /tasks/{taskId}",
    "DELETE /tasks/{taskId}",
    "GET /tasks/{taskId}",
  ]

  voice_routes = [
    "POST /voice/upload-url",
    "POST /voice/transcribe",
    "POST /voice/synthesize",
  ]

  ai_routes = [
    "POST /ai/chat",
    "POST /ai/generate-schedule",
  ]

  calendar_routes = [
    "POST /calendar/sync",
    "GET /calendar/events",
  ]
}

# Tasks routes
resource "aws_apigatewayv2_route" "tasks" {
  for_each = toset(local.task_routes)

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.task_service.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

# Voice routes
resource "aws_apigatewayv2_route" "voice" {
  for_each = toset(local.voice_routes)

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.voice_service.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

# AI routes
resource "aws_apigatewayv2_route" "ai" {
  for_each = toset(local.ai_routes)

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.agentic_ai_service.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

# Calendar routes
resource "aws_apigatewayv2_route" "calendar" {
  for_each = toset(local.calendar_routes)

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.google_cal_sync.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

# ═══════════════════════════════════════════════════════════════════
#  Lambda Permissions — allow API Gateway to invoke each function
# ═══════════════════════════════════════════════════════════════════

resource "aws_lambda_permission" "task_service_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "voice_service_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.voice_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "agentic_ai_service_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agentic_ai_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "google_cal_sync_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.google_cal_sync.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
