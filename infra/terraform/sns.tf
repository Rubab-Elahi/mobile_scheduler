# ═══════════════════════════════════════════════════════════════════
#  Amazon SNS — Push Notifications
# ═══════════════════════════════════════════════════════════════════

resource "aws_sns_topic" "notifications" {
  name         = "${local.name_prefix}-notifications"
  display_name = "Mobile Scheduler Notifications"

  tags = {
    Name = "${local.name_prefix}-notifications"
  }
}

# ── SNS Topic Policy — allow EventBridge to publish ───────────────
resource "aws_sns_topic_policy" "notifications" {
  arn = aws_sns_topic.notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.notifications.arn
      },
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.notification_service.arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}

# ── Mobile Push Platform Applications ────────────────────────────
# NOTE: Uncomment and fill in platform credentials once you have
# APNs (iOS) and/or FCM (Android) certificates.
#
# resource "aws_sns_platform_application" "fcm" {
#   name                      = "${local.name_prefix}-fcm"
#   platform                  = "GCM"
#   platform_credential       = var.fcm_server_key
# }
#
# resource "aws_sns_platform_application" "apns" {
#   name                      = "${local.name_prefix}-apns"
#   platform                  = "APNS"
#   platform_credential       = var.apns_private_key
#   platform_principal        = var.apns_certificate
# }
