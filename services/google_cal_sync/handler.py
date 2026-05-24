"""
Google Calendar Sync Service — Integrates with Google Calendar API
Routes:
  POST /calendar/sync   → Push user tasks to Google Calendar
  GET /calendar/events  → Fetch upcoming events from Google Calendar
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

GOOGLE_CAL_SECRET_ARN = os.environ["GOOGLE_CAL_SECRET_ARN"]
TASKS_TABLE           = os.environ["TASKS_TABLE"]

tasks_table = dynamodb.Table(TASKS_TABLE)

_google_client = None


def get_google_credentials():
    """Fetch Service Account JSON from Secrets Manager."""
    try:
        secret = secrets_client.get_secret_value(SecretId=GOOGLE_CAL_SECRET_ARN)
        return json.loads(secret["SecretString"])
    except Exception as e:
        logger.error(f"Failed to fetch Google credentials: {e}")
        return None


def get_calendar_service():
    """Initialize Google Calendar API client."""
    global _google_client
    if _google_client is None:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build

        creds_json = get_google_credentials()
        if not creds_json:
            return None

        scopes = ["https://www.googleapis.com/auth/calendar"]
        creds = service_account.Credentials.from_service_account_info(creds_json, scopes=scopes)
        _google_client = build("calendar", "v3", credentials=creds)
    return _google_client


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


def fetch_pending_tasks(user_id: str) -> list:
    from boto3.dynamodb.conditions import Key
    result = tasks_table.query(
        IndexName="UserStatusIndex",
        KeyConditionExpression=Key("userId").eq(user_id) & Key("status").eq("pending"),
    )
    return result.get("Items", [])


# ── Handlers ──────────────────────────────────────────────────────
def sync_to_calendar(user_id: str, body: dict) -> dict:
    """
    POST /calendar/sync
    Syncs all pending tasks to a Google Calendar.
    """
    service = get_calendar_service()
    if not service:
        return resp(500, {"error": "Google Calendar service not configured"})

    tasks = fetch_pending_tasks(user_id)
    if not tasks:
        return resp(200, {"message": "No tasks to sync"})

    synced_count = 0
    # In a real app, you'd store the Google Calendar ID in user preferences.
    # Defaulting to 'primary' for the service account (or a specified one).
    calendar_id = body.get("calendarId", "primary")

    for task in tasks:
        # Avoid double-syncing if we had a gcalEventId field
        if task.get("gcalEventId"):
            continue

        start_time = task.get("dueDate", datetime.now(timezone.utc).isoformat())
        # End time = start time + 30 mins default
        from datetime import datetime, timedelta
        end_time = (datetime.fromisoformat(start_time.replace("Z", "+00:00")) + timedelta(minutes=30)).isoformat()

        event_body = {
            "summary":     task.get("title"),
            "description": task.get("notes", ""),
            "start":       {"dateTime": start_time, "timeZone": "UTC"},
            "end":         {"dateTime": end_time, "timeZone": "UTC"},
        }

        try:
            event = service.events().insert(calendarId=calendar_id, body=event_body).execute()
            # Update task with GCAL ID
            tasks_table.update_item(
                Key={"userId": user_id, "taskId": task["taskId"]},
                UpdateExpression="SET gcalEventId = :eid",
                ExpressionAttributeValues={":eid": event["id"]}
            )
            synced_count += 1
        except Exception as e:
            logger.error(f"Failed to sync task {task['taskId']}: {e}")

    return resp(200, {"message": f"Synced {synced_count} tasks to Google Calendar"})


def get_calendar_events(user_id: str, params: dict) -> dict:
    """
    GET /calendar/events
    Fetch upcoming events from Google Calendar.
    """
    service = get_calendar_service()
    if not service:
        return resp(500, {"error": "Google Calendar service not configured"})

    calendar_id = params.get("calendarId", "primary")
    now         = datetime.now(timezone.utc).isoformat()

    try:
        events_result = service.events().list(
            calendarId=calendar_id,
            timeMin=now,
            maxResults=10,
            singleEvents=True,
            orderBy="startTime"
        ).execute()
        events = events_result.get("items", [])
        return resp(200, {"events": events})
    except Exception as e:
        logger.error(f"Failed to list events: {e}")
        return resp(500, {"error": str(e)})


# ── Main Handler ──────────────────────────────────────────────────
def lambda_handler(event: dict, context) -> dict:
    logger.info(f"Event: {json.dumps(event)}")

    try:
        user_id = get_user_id(event)
    except ValueError as e:
        return resp(401, {"error": str(e)})

    path   = event.get("rawPath", "")
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    params = event.get("queryStringParameters") or {}
    body   = json.loads(event.get("body") or "{}") if event.get("body") else {}

    try:
        if "/calendar/sync" in path:
            return sync_to_calendar(user_id, body)
        elif "/calendar/events" in path:
            return get_calendar_events(user_id, params)
        else:
            return resp(404, {"error": f"Unknown route: {path}"})
    except Exception as e:
        logger.exception("Unhandled error in calendar sync service")
        return resp(500, {"error": "Internal server error", "detail": str(e)})
