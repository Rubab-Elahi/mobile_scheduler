# ═══════════════════════════════════════════════════════════════════
#  Lambda Functions — IAM Roles, Packages, and Resources
#
#  Functions:
#    1. task_service
#    2. voice_service
#    3. agentic_ai_service
#    4. scheduler_agent       (DynamoDB Stream trigger)
#    5. google_cal_sync
#    6. notification_service  (EventBridge trigger)
# ═══════════════════════════════════════════════════════════════════

# ── Common assume-role policy ────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ── 1. TASK SERVICE ───────────────────────────────────────────────
resource "aws_iam_role" "task_service" {
  name               = "${local.name_prefix}-task-service-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "task_service" {
  name = "${local.name_prefix}-task-service-policy"
  role = aws_iam_role.task_service.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.tasks.arn,
          "${aws_dynamodb_table.tasks.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "task_service" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/task_service"
  output_path = "${path.module}/../../.build/task_service.zip"
}

resource "aws_lambda_function" "task_service" {
  function_name    = "${local.name_prefix}-task-service"
  role             = aws_iam_role.task_service.arn
  runtime          = var.lambda_runtime
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.task_service.output_path
  source_code_hash = data.archive_file.task_service.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  environment {
    variables = {
      TASKS_TABLE      = aws_dynamodb_table.tasks.name
      ENVIRONMENT      = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.task_service]
}

resource "aws_cloudwatch_log_group" "task_service" {
  name              = "/aws/lambda/${aws_lambda_function.task_service.function_name}"
  retention_in_days = 14
}

# ── 2. VOICE SERVICE ──────────────────────────────────────────────
resource "aws_iam_role" "voice_service" {
  name               = "${local.name_prefix}-voice-service-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "voice_service" {
  name = "${local.name_prefix}-voice-service-policy"
  role = aws_iam_role.voice_service.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GeneratePresignedUrl"]
        Resource = ["${aws_s3_bucket.voice_files.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "transcribe:StartTranscriptionJob", "transcribe:GetTranscriptionJob",
          "transcribe:ListTranscriptionJobs"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["polly:SynthesizeSpeech"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "voice_service" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/voice_service"
  output_path = "${path.module}/../../.build/voice_service.zip"
}

resource "aws_lambda_function" "voice_service" {
  function_name    = "${local.name_prefix}-voice-service"
  role             = aws_iam_role.voice_service.arn
  runtime          = var.lambda_runtime
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.voice_service.output_path
  source_code_hash = data.archive_file.voice_service.output_base64sha256
  timeout          = 60  # Transcription jobs can take time
  memory_size      = 512

  environment {
    variables = {
      VOICE_BUCKET = aws_s3_bucket.voice_files.bucket
      ENVIRONMENT  = var.environment
      AWS_ACCOUNT  = local.account_id
    }
  }

  depends_on = [aws_iam_role_policy.voice_service]
}

resource "aws_cloudwatch_log_group" "voice_service" {
  name              = "/aws/lambda/${aws_lambda_function.voice_service.function_name}"
  retention_in_days = 14
}

# ── 3. AGENTIC AI SERVICE ─────────────────────────────────────────
resource "aws_iam_role" "agentic_ai_service" {
  name               = "${local.name_prefix}-agentic-ai-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "agentic_ai_service" {
  name = "${local.name_prefix}-agentic-ai-policy"
  role = aws_iam_role.agentic_ai_service.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.openai_api_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query", "dynamodb:GetItem", "dynamodb:PutItem"
        ]
        Resource = [
          aws_dynamodb_table.habits_logs.arn,
          "${aws_dynamodb_table.habits_logs.arn}/index/*",
          aws_dynamodb_table.tasks.arn,
          "${aws_dynamodb_table.tasks.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "agentic_ai_service" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/agentic_ai_service"
  output_path = "${path.module}/../../.build/agentic_ai_service.zip"
}

resource "aws_lambda_function" "agentic_ai_service" {
  function_name    = "${local.name_prefix}-agentic-ai"
  role             = aws_iam_role.agentic_ai_service.arn
  runtime          = var.lambda_runtime
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.agentic_ai_service.output_path
  source_code_hash = data.archive_file.agentic_ai_service.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      OPENAI_SECRET_ARN  = aws_secretsmanager_secret.openai_api_key.arn
      HABITS_TABLE       = aws_dynamodb_table.habits_logs.name
      TASKS_TABLE        = aws_dynamodb_table.tasks.name
      OPENAI_MODEL       = "gpt-4o-mini"
      ENVIRONMENT        = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.agentic_ai_service]
}

resource "aws_cloudwatch_log_group" "agentic_ai_service" {
  name              = "/aws/lambda/${aws_lambda_function.agentic_ai_service.function_name}"
  retention_in_days = 14
}

# ── 4. SCHEDULER AGENT (DynamoDB Stream trigger) ──────────────────
resource "aws_iam_role" "scheduler_agent" {
  name               = "${local.name_prefix}-scheduler-agent-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "scheduler_agent" {
  name = "${local.name_prefix}-scheduler-agent-policy"
  role = aws_iam_role.scheduler_agent.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords", "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream", "dynamodb:ListStreams"
        ]
        Resource = [aws_dynamodb_table.tasks.stream_arn]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:Query", "dynamodb:GetItem"]
        Resource = [
          aws_dynamodb_table.tasks.arn,
          "${aws_dynamodb_table.tasks.arn}/index/*",
          aws_dynamodb_table.habits_logs.arn,
          "${aws_dynamodb_table.habits_logs.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.openai_api_key.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = [aws_cloudwatch_event_bus.scheduler.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "scheduler_agent" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/scheduler_agent"
  output_path = "${path.module}/../../.build/scheduler_agent.zip"
}

resource "aws_lambda_function" "scheduler_agent" {
  function_name    = "${local.name_prefix}-scheduler-agent"
  role             = aws_iam_role.scheduler_agent.arn
  runtime          = var.lambda_runtime
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.scheduler_agent.output_path
  source_code_hash = data.archive_file.scheduler_agent.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      TASKS_TABLE       = aws_dynamodb_table.tasks.name
      HABITS_TABLE      = aws_dynamodb_table.habits_logs.name
      OPENAI_SECRET_ARN = aws_secretsmanager_secret.openai_api_key.arn
      EVENT_BUS_NAME    = aws_cloudwatch_event_bus.scheduler.name
      ENVIRONMENT       = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.scheduler_agent]
}

# DynamoDB Stream → scheduler_agent trigger
resource "aws_lambda_event_source_mapping" "tasks_stream" {
  event_source_arn              = aws_dynamodb_table.tasks.stream_arn
  function_name                 = aws_lambda_function.scheduler_agent.arn
  starting_position             = "LATEST"
  batch_size                    = 10
  bisect_batch_on_function_error = true

  filter_criteria {
    filter {
      # Only trigger on INSERT or MODIFY, skip REMOVE
      pattern = jsonencode({
        eventName = [{ prefix = "INSER" }, { prefix = "MODIF" }]
      })
    }
  }
}

resource "aws_cloudwatch_log_group" "scheduler_agent" {
  name              = "/aws/lambda/${aws_lambda_function.scheduler_agent.function_name}"
  retention_in_days = 14
}

# ── 5. GOOGLE CALENDAR SYNC ───────────────────────────────────────
resource "aws_iam_role" "google_cal_sync" {
  name               = "${local.name_prefix}-google-cal-sync-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "google_cal_sync" {
  name = "${local.name_prefix}-google-cal-sync-policy"
  role = aws_iam_role.google_cal_sync.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.google_cal_sa.arn]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:Query", "dynamodb:GetItem"]
        Resource = [
          aws_dynamodb_table.tasks.arn,
          "${aws_dynamodb_table.tasks.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "google_cal_sync" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/google_cal_sync"
  output_path = "${path.module}/../../.build/google_cal_sync.zip"
}

resource "aws_lambda_function" "google_cal_sync" {
  function_name    = "${local.name_prefix}-google-cal-sync"
  role             = aws_iam_role.google_cal_sync.arn
  runtime          = var.lambda_runtime
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.google_cal_sync.output_path
  source_code_hash = data.archive_file.google_cal_sync.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      GOOGLE_CAL_SECRET_ARN = aws_secretsmanager_secret.google_cal_sa.arn
      TASKS_TABLE           = aws_dynamodb_table.tasks.name
      ENVIRONMENT           = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.google_cal_sync]
}

resource "aws_cloudwatch_log_group" "google_cal_sync" {
  name              = "/aws/lambda/${aws_lambda_function.google_cal_sync.function_name}"
  retention_in_days = 14
}

# ── 6. NOTIFICATION SERVICE (EventBridge trigger) ─────────────────
resource "aws_iam_role" "notification_service" {
  name               = "${local.name_prefix}-notification-service-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "notification_service" {
  name = "${local.name_prefix}-notification-service-policy"
  role = aws_iam_role.notification_service.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.notifications.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "notification_service" {
  type        = "zip"
  source_dir  = "${path.module}/../../services/notification_service"
  output_path = "${path.module}/../../.build/notification_service.zip"
}

resource "aws_lambda_function" "notification_service" {
  function_name    = "${local.name_prefix}-notification-service"
  role             = aws_iam_role.notification_service.arn
  runtime          = var.lambda_runtime
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.notification_service.output_path
  source_code_hash = data.archive_file.notification_service.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.notifications.arn
      ENVIRONMENT   = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.notification_service]
}

resource "aws_cloudwatch_log_group" "notification_service" {
  name              = "/aws/lambda/${aws_lambda_function.notification_service.function_name}"
  retention_in_days = 14
}
