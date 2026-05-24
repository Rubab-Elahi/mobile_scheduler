"""
Scheduler Agent — triggered by DynamoDB Streams on the Tasks table.
Re-evaluates the user's schedule using GPT-4o-mini whenever tasks change,
then emits EventBridge events for notifications.
"""
import json
import os
import logging
from datetime import datetime, timezone, timedelta

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secrets_client   = boto3.client("secretsmanager")
events_client    = boto3.client("events")
dynamodb         = boto3.resource("dynamodb")

TASKS_TABLE       = os.environ["TASKS_TABLE"]
HABITS_TABLE      = os.environ["HABITS_TABLE"]
OPENAI_SECRET_ARN = os.environ["OPENAI_SECRET_ARN"]
EVENT_BUS_NAME    = os.environ["EVENT_BUS_NAME"]
OPENAI_MODEL      = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

tasks_table  = dynamodb.Table(TASKS_TABLE)
habits_table = dynamodb.Table(HABITS_TABLE)

_openai_client = None


def get_openai_client():
    global _openai_client
    if _openai_client is None:
        import openai
        secret = secrets_client.get_secret_value(SecretId=OPENAI_SECRET_ARN)
        api_key = json.loads(secret["SecretString"])["api_key"]
        _openai_client = openai.OpenAI(api_key=api_key)
    return _openai_client


def parse_stream_records(records: list) -> list[dict]:
    """Extract (userId, event_type, task) tuples from DynamoDB stream records."""
    changes = []
    for record in records:
        event_name = record.get("eventName")  # INSERT | MODIFY | REMOVE
        image = record.get("dynamodb", {}).get("NewImage") or record.get("dynamodb", {}).get("OldImage", {})

        # Deserialize DynamoDB typed attributes
        from boto3.dynamodb.types import TypeDeserializer
        deserializer = TypeDeserializer()
        task = {k: deserializer.deserialize(v) for k, v in image.items()}

        changes.append({
            "eventName": event_name,
            "userId":    task.get("userId"),
            "task":      task,
        })
    return changes


def get_user_tasks(user_id: str) -> list:
    from boto3.dynamodb.conditions import Key
    result = tasks_table.query(
        IndexName="UserStatusIndex",
        KeyConditionExpression=Key("userId").eq(user_id) & Key("status").eq("pending"),
    )
    return result.get("Items", [])


def put_event(detail_type: str, detail: dict) -> None:
    """Emit an event to the custom EventBridge bus."""
    events_client.put_events(Entries=[{
        "Source":       "mobile-scheduler.agent",
        "DetailType":   detail_type,
        "Detail":       json.dumps(detail, default=str),
        "EventBusName": EVENT_BUS_NAME,
    }])


def check_missed_tasks(user_id: str, tasks: list) -> None:
    """Emit MissedTask events for overdue tasks."""
    now = datetime.now(timezone.utc).date()
    for task in tasks:
        due_date_str = task.get("dueDate", "")
        if not due_date_str:
            continue
        try:
            due_date = datetime.fromisoformat(due_date_str).date()
            if due_date < now:
                put_event("MissedTask", {
                    "userId":    user_id,
                    "taskId":    task.get("taskId"),
                    "taskTitle": task.get("title"),
                    "dueDate":   due_date_str,
                    "message":   f"Task '{task.get('title')}' was due on {due_date_str}",
                })
                logger.info(f"Emitted MissedTask event for task {task.get('taskId')}")
        except (ValueError, TypeError):
            continue


def generate_schedule_notification(user_id: str, tasks: list) -> None:
    """
    Use GPT-4o-mini to decide if a schedule-change notification should fire.
    """
    if not tasks:
        return

    tasks_summary = "\n".join(
        f"- [{t.get('priority','medium')}] {t.get('title','')} (due: {t.get('dueDate','N/A')})"
        for t in tasks[:10]
    )

    tomorrow = (datetime.now(timezone.utc) + timedelta(days=1)).strftime("%Y-%m-%d")

    prompt = f"""A user's task list was just updated.
Current pending tasks:
{tasks_summary}

Should a schedule update notification be sent? If yes, provide a brief notification message.
Respond with JSON:
{{
  "sendNotification": true/false,
  "message": "...",
  "urgency": "low|medium|high"
}}"""

    client = get_openai_client()
    completion = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=[
            {"role": "system", "content": "You are a smart scheduling assistant."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.3,
        max_tokens=200,
        response_format={"type": "json_object"},
    )

    result = json.loads(completion.choices[0].message.content)
    if result.get("sendNotification"):
        put_event("ScheduleTrigger", {
            "userId":  user_id,
            "message": result.get("message", f"Your schedule for {tomorrow} has been updated"),
            "urgency": result.get("urgency", "medium"),
        })
        logger.info(f"Emitted ScheduleTrigger for user {user_id}")


def lambda_handler(event: dict, context) -> dict:
    logger.info(f"DynamoDB Stream event with {len(event.get('Records', []))} records")

    records = event.get("Records", [])
    if not records:
        return {"statusCode": 200, "body": "No records"}

    changes = parse_stream_records(records)

    # Group by userId — process each user once
    user_ids = list({c["userId"] for c in changes if c.get("userId")})
    logger.info(f"Processing schedule updates for users: {user_ids}")

    for user_id in user_ids:
        try:
            tasks = get_user_tasks(user_id)
            check_missed_tasks(user_id, tasks)
            generate_schedule_notification(user_id, tasks)
        except Exception as e:
            logger.exception(f"Error processing user {user_id}: {e}")
            # Continue processing other users even if one fails

    return {"statusCode": 200, "body": f"Processed {len(records)} stream records"}
