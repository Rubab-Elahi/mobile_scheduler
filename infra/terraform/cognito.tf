# ═══════════════════════════════════════════════════════════════════
#  Amazon Cognito — Authentication
#  • Google OAuth federated sign-in
#  • JWT-based authorisation for API Gateway
# ═══════════════════════════════════════════════════════════════════

# ── User Pool ─────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-user-pool"

  # Allow email and username login
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  schema {
    name                = "family_name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  # MFA — optional (users can enable TOTP)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  tags = {
    Name = "${local.name_prefix}-user-pool"
  }
}

# ── Google Identity Provider ──────────────────────────────────────
resource "aws_cognito_user_pool_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email       = "email"
    given_name  = "given_name"
    family_name = "family_name"
    username    = "sub"
  }
}

# ── User Pool Domain (Hosted UI) ──────────────────────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ── App Client (Flutter / Mobile) ────────────────────────────────
resource "aws_cognito_user_pool_client" "mobile" {
  name         = "${local.name_prefix}-mobile-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false # Flutter apps cannot keep secrets securely

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1   # hours
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Auth flows — allow SRP and refresh
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]

  # OAuth 2.0 settings
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = [
    "COGNITO",
    aws_cognito_user_pool_identity_provider.google.provider_name,
  ]

  # Callback / logout URLs — update once you have your Flutter deep-link scheme
  callback_urls = [
    "myapp://callback",
    "https://localhost:3000/callback",
  ]

  logout_urls = [
    "myapp://signout",
    "https://localhost:3000/signout",
  ]

  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_user_pool_identity_provider.google]
}

# ── Resource Server (optional — for machine-to-machine) ───────────
resource "aws_cognito_resource_server" "api" {
  identifier   = "https://api.${local.name_prefix}"
  name         = "${local.name_prefix}-api"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "read"
    scope_description = "Read access to API"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write access to API"
  }
}
