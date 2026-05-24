"""
Agentic AI Service — OpenAI GPT-4o-mini orchestration
Routes:
  POST /ai/chat             → conversational AI with task + habit context
  POST /ai/generate-schedule → generate optimized daily schedule from tasks
"""
import json
import os
import logging
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secrets_client = boto3.client("secretsmanager")
dynamodb       = boto3.resource("dynamodb")

OPENAI_SECRET_ARN = os.environ["OPENAI_SECRET_ARN"]
HABITS_TABLE      = os.environ["HABITS_TABLE"]
TASKS_TABLE       = os.environ["TASKS_TABLE"]
OPENAI_MODEL      = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

habits_table = dynamodb.Table(HABITS_TABLE)
tasks_table  = dynamodb.Table(TASKS_TABLE)

_openai_client = None  # Lazy init


def get_openai_client():
    """Lazy-initialize OpenAI client using key from Secrets Manager."""
    global _openai_client
    if _openai_client is None:
        import openai
        secret = secrets_client.get_secret_value(SecretId=OPENAI_SECRET_ARN)
        api_key = json.loads(secret["SecretString"])["api_key"]
        _openai_client = openai.OpenAI(api_key=api_key)
    return _openai_client


# ── Helpers ───────────────────────────────────────────────────────
def resp(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(body, default=str),
    }


def get_user_id(event: dict) -> str:
    try:
        return event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except (KeyError, TypeError):
        raise ValueError("Unable to extract userId from token")


def fetch_habits(user_id: str, limit: int = 20) -> list:
    """Fetch recent habit/interaction logs for the user (Agent Memory)."""
    try:
        from boto3.dynamodb.conditions import Key
        result = habits_table.query(
            KeyConditionExpression=Key("userId").eq(user_id),
            ScanIndexForward=False,
            Limit=limit,
        )
        return result.get("Items", [])
    except Exception:
        logger.warning("Could not fetch habits", exc_info=True)
        return []


def fetch_tasks(user_id: str) -> list:
    """Fetch pending tasks for the user."""
    try:
        from boto3.dynamodb.conditions import Key
        result = tasks_table.query(
            IndexName="UserStatusIndex",
            KeyConditionExpression=Key("userId").eq(user_id) & Key("status").eq("pending"),
        )
        return result.get("Items", [])
    except Exception:
        logger.warning("Could not fetch tasks", exc_info=True)
        return []


def save_interaction(user_id: str, role: str, content: str) -> None:
    """Save an interaction to the habits/logs memory table."""
    try:
        from datetime import timezone
        habits_table.put_item(Item={
            "userId":    user_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "entryType": "interaction",
            "role":      role,
            "content":   content[:2000],  # Trim to avoid huge items
        })
    except Exception:
        logger.warning("Could not save interaction", exc_info=True)


# ── Route Handlers ────────────────────────────────────────────────
def ai_chat(user_id: str, body: dict) -> dict:
    """
    POST /ai/chat
    Body: { "message": "Add gym tomorrow at 3pm", "conversationHistory": [...] }
    Returns: { "reply": "...", "intent": "add_task|query|schedule|chat" }
    """
    message = body.get("message", "").strip()
    if not message:
        return resp(400, {"error": "message is required"})

    history = body.get("conversationHistory", [])

    # Build context from habits and tasks
    habits = fetch_habits(user_id, limit=10)
    tasks  = fetch_tasks(user_id)

    habits_summary = "\n".join(
        f"- [{h.get('entryType', 'log')}] {h.get('content', '')[:200]}"
        for h in habits[:5]
    ) or "No recent habits logged."

    tasks_summary = "\n".join(
        f"- [{t.get('priority','?')}] {t.get('title','')} (due: {t.get('dueDate','N/A')})"
        for t in tasks[:10]
    ) or "No pending tasks."

    system_prompt = f"""You are an intelligent AI scheduling assistant for a mobile productivity app.
You help users manage tasks, create smart schedules, and stay productive.

Current date/time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}

User's pending tasks:
{tasks_summary}

User's recent habits and interactions:
{habits_summary}

When responding:
1. Be concise and action-oriented
2. If the user wants to add/update/delete a task, reply with intent="add_task|update_task|delete_task" and include a "taskData" object
3. If the user wants their schedule, reply with intent="schedule"
4. For general chat, reply with intent="chat"
5. Always include an "intent" field in your JSON response

Respond ONLY with valid JSON:
{{
  "reply": "Your natural language reply",
  "intent": "chat|add_task|update_task|delete_task|schedule|query",
  "taskData": {{...}} // optional, only for task intents
}}"""

    messages = [{"role": "system", "content": system_prompt}]
    # Add conversation history (last 6 exchanges)
    for h in history[-12:]:
        if h.get("role") in ("user", "assistant"):
            messages.append({"role": h["role"], "content": h["content"]})
    messages.append({"role": "user", "content": message})

    client = get_openai_client()
    completion = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=messages,
        temperature=0.7,
        max_tokens=512,
        response_format={"type": "json_object"},
    )

    ai_reply_raw = completion.choices[0].message.content
    try:
        ai_reply = json.loads(ai_reply_raw)
    except json.JSONDecodeError:
        ai_reply = {"reply": ai_reply_raw, "intent": "chat"}

    # Save interaction to memory
    save_interaction(user_id, "user", message)
    save_interaction(user_id, "assistant", ai_reply.get("reply", ""))

    return resp(200, {
        "reply":    ai_reply.get("reply", ""),
        "intent":   ai_reply.get("intent", "chat"),
        "taskData": ai_reply.get("taskData"),
        "usage":    {
            "promptTokens":     completion.usage.prompt_tokens,
            "completionTokens": completion.usage.completion_tokens,
        },
    })


def generate_schedule(user_id: str, body: dict) -> dict:
    """
    POST /ai/generate-schedule
    Body: { "date": "2026-05-25", "preferences": { "workStart": "09:00", "workEnd": "18:00" } }
    Returns: { "schedule": [ { startTime, endTime, taskId, taskTitle, notes } ] }
    """
    date_str    = body.get("date", datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    preferences = body.get("preferences", {})
    work_start  = preferences.get("workStart", "09:00")
    work_end    = preferences.get("workEnd", "18:00")

    tasks  = fetch_tasks(user_id)
    habits = fetch_habits(user_id, limit=15)

    if not tasks:
        return resp(200, {"schedule": [], "message": "No pending tasks to schedule"})

    tasks_json  = json.dumps(tasks, default=str)
    habits_json = json.dumps([
        {"entryType": h.get("entryType"), "content": h.get("content", "")[:300]}
        for h in habits
    ], default=str)

    system_prompt = f"""You are an expert productivity scheduler.
Create an optimized daily schedule for {date_str}.
Working hours: {work_start} – {work_end}.

Rules:
- Schedule high-priority tasks during peak focus hours (9-11 AM, 2-4 PM)
- Include 10-minute breaks every 90 minutes
- Don't schedule more than 8 hours of tasks
- Respect due dates and priorities
- Learn from user habits

Output ONLY valid JSON with this structure:
{{
  "schedule": [
    {{
      "startTime": "HH:MM",
      "endTime":   "HH:MM",
      "taskId":    "uuid or 'break'",
      "taskTitle": "Task name or 'Break'",
      "taskType":  "task|break|buffer",
      "priority":  "high|medium|low|none",
      "notes":     "Optional scheduling note"
    }}
  ],
  "summary": "One-line summary of the schedule",
  "focusScore": 85
}}"""

    user_message = f"""Tasks to schedule:
{tasks_json}

User habits/patterns:
{habits_json}

Generate the schedule for {date_str}."""

    client = get_openai_client()
    completion = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        temperature=0.3,
        max_tokens=1500,
        response_format={"type": "json_object"},
    )

    schedule_raw = completion.choices[0].message.content
    try:
        schedule_data = json.loads(schedule_raw)
    except json.JSONDecodeError:
        return resp(500, {"error": "Failed to parse AI schedule response"})

    # Log the schedule generation event
    save_interaction(user_id, "system", f"Generated schedule for {date_str}: {schedule_data.get('summary', '')}")

    return resp(200, {
        "date":       date_str,
        "schedule":   schedule_data.get("schedule", []),
        "summary":    schedule_data.get("summary", ""),
        "focusScore": schedule_data.get("focusScore", 0),
    })


# ── Main Handler ──────────────────────────────────────────────────
def lambda_handler(event: dict, context) -> dict:
    logger.info(f"Event: {json.dumps(event)}")

    try:
        user_id = get_user_id(event)
    except ValueError as e:
        return resp(401, {"error": str(e)})

    path = event.get("rawPath", "")
    body = json.loads(event.get("body") or "{}") if event.get("body") else {}

    try:
        if "/ai/chat" in path:
            return ai_chat(user_id, body)
        elif "/ai/generate-schedule" in path:
            return generate_schedule(user_id, body)
        else:
            return resp(404, {"error": f"Unknown route: {path}"})
    except Exception as e:
        logger.exception("Unhandled error in agentic AI service")
        return resp(500, {"error": "Internal server error", "detail": str(e)})
