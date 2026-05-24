# ═══════════════════════════════════════════════════════════════════
#  Amazon EventBridge
#  Custom event bus used by scheduler_agent to fire schedule triggers
#  Rules forward events to notification_service Lambda
# ═══════════════════════════════════════════════════════════════════

# ── Custom Event Bus ──────────────────────────────────────────────
resource "aws_cloudwatch_event_bus" "scheduler" {
  name = "${local.name_prefix}-scheduler-bus"

  tags = {
    Name = "${local.name_prefix}-scheduler-bus"
  }
}

# ── Rule 1: Schedule Trigger (task reminder) ──────────────────────
resource "aws_cloudwatch_event_rule" "schedule_trigger" {
  name           = "${local.name_prefix}-schedule-trigger"
  description    = "Fires when scheduler_agent emits a schedule trigger event"
  event_bus_name = aws_cloudwatch_event_bus.scheduler.name

  event_pattern = jsonencode({
    source      = ["mobile-scheduler.agent"]
    detail-type = ["ScheduleTrigger"]
  })

  tags = {
    Name = "${local.name_prefix}-schedule-trigger"
  }
}

# ── Rule 2: Missed Task Alert ─────────────────────────────────────
resource "aws_cloudwatch_event_rule" "missed_task" {
  name           = "${local.name_prefix}-missed-task-alert"
  description    = "Fires when a task is overdue"
  event_bus_name = aws_cloudwatch_event_bus.scheduler.name

  event_pattern = jsonencode({
    source      = ["mobile-scheduler.agent"]
    detail-type = ["MissedTask"]
  })

  tags = {
    Name = "${local.name_prefix}-missed-task-alert"
  }
}

# ── Rule 3: Daily Schedule Generation (cron) ──────────────────────
resource "aws_cloudwatch_event_rule" "daily_schedule_gen" {
  name                = "${local.name_prefix}-daily-schedule-gen"
  description         = "Triggers daily schedule generation at 7 AM UTC"
  schedule_expression = "cron(0 7 * * ? *)"

  tags = {
    Name = "${local.name_prefix}-daily-schedule-gen"
  }
}

# ── Targets — route events to notification_service Lambda ─────────
resource "aws_cloudwatch_event_target" "schedule_trigger_to_lambda" {
  rule           = aws_cloudwatch_event_rule.schedule_trigger.name
  event_bus_name = aws_cloudwatch_event_bus.scheduler.name
  target_id      = "NotificationServiceScheduleTrigger"
  arn            = aws_lambda_function.notification_service.arn
}

resource "aws_cloudwatch_event_target" "missed_task_to_lambda" {
  rule           = aws_cloudwatch_event_rule.missed_task.name
  event_bus_name = aws_cloudwatch_event_bus.scheduler.name
  target_id      = "NotificationServiceMissedTask"
  arn            = aws_lambda_function.notification_service.arn
}

resource "aws_cloudwatch_event_target" "daily_schedule_gen_to_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_schedule_gen.name
  target_id = "SchedulerAgentDailyRun"
  arn       = aws_lambda_function.scheduler_agent.arn
}

# ── Lambda Permissions — allow EventBridge to invoke Lambdas ─────
resource "aws_lambda_permission" "eventbridge_notification_schedule" {
  statement_id  = "AllowEventBridgeScheduleTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_service.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_trigger.arn
}

resource "aws_lambda_permission" "eventbridge_notification_missed" {
  statement_id  = "AllowEventBridgeMissedTask"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_service.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.missed_task.arn
}

resource "aws_lambda_permission" "eventbridge_scheduler_daily" {
  statement_id  = "AllowEventBridgeDailySchedulerRun"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler_agent.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule_gen.arn
}
