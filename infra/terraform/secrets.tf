# ═══════════════════════════════════════════════════════════════════
#  AWS Secrets Manager
#  Stores sensitive credentials accessed at Lambda runtime
# ═══════════════════════════════════════════════════════════════════

# ── OpenAI API Key ────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "${local.name_prefix}/openai-api-key"
  description             = "OpenAI API key for GPT-4o-mini (Agentic AI)"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-openai-api-key"
  }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id = aws_secretsmanager_secret.openai_api_key.id
  secret_string = jsonencode({
    api_key = var.openai_api_key
  })
}

# ── Google Calendar Service Account ──────────────────────────────
resource "aws_secretsmanager_secret" "google_cal_sa" {
  name                    = "${local.name_prefix}/google-cal-service-account"
  description             = "Google Calendar service account JSON for calendar sync Lambda"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-google-cal-sa"
  }
}

resource "aws_secretsmanager_secret_version" "google_cal_sa" {
  secret_id     = aws_secretsmanager_secret.google_cal_sa.id
  secret_string = var.google_cal_service_account_json
}

# ── Google OAuth Credentials (for reference by Cognito IdP) ─────
resource "aws_secretsmanager_secret" "google_oauth" {
  name                    = "${local.name_prefix}/google-oauth"
  description             = "Google OAuth client_id and client_secret for Cognito"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-google-oauth"
  }
}

resource "aws_secretsmanager_secret_version" "google_oauth" {
  secret_id = aws_secretsmanager_secret.google_oauth.id
  secret_string = jsonencode({
    client_id     = var.google_client_id
    client_secret = var.google_client_secret
  })
}
