variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name used as a prefix for all resources"
  type        = string
  default     = "mobile-scheduler"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

# ── Google OAuth (Cognito federated sign-in) ──────────────────────────────────
variable "google_client_id" {
  description = "Google OAuth 2.0 Client ID (from Google Cloud Console)"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth 2.0 Client Secret"
  type        = string
  sensitive   = true
}

# ── OpenAI ────────────────────────────────────────────────────────────────────
variable "openai_api_key" {
  description = "OpenAI API key for GPT-4o-mini"
  type        = string
  sensitive   = true
  default     = "REPLACE_AFTER_DEPLOY"
}

# ── Google Calendar Service Account ──────────────────────────────────────────
variable "google_cal_service_account_json" {
  description = "Google Calendar service account JSON key (as string)"
  type        = string
  sensitive   = true
  default     = "{}"
}

# ── Lambda Runtime ────────────────────────────────────────────────────────────
variable "lambda_runtime" {
  description = "Python runtime for Lambda functions"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Default Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Default Lambda memory in MB"
  type        = number
  default     = 256
}

# ── DynamoDB ──────────────────────────────────────────────────────────────────
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST | PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}
