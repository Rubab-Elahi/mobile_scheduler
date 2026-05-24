"""
Task Service — CRUD handler for tasks stored in DynamoDB
Routes: GET /tasks, GET /tasks/{taskId}, POST /tasks, PUT /tasks/{taskId}, DELETE /tasks/{taskId}
"""
import json
import os
import uuid
import time
import logging
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TASKS_TABLE"]
table = dynamodb.Table(TABLE_NAME)


# ── Helpers ───────────────────────────────────────────────────────
def response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }


def get_user_id(event: dict) -> str:
    """Extract Cognito userId (sub) from JWT claims injected by API Gateway."""
    try:
        return event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except (KeyError, TypeError):
        raise ValueError("Unable to extract userId from token claims")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def ttl_90_days() -> int:
    return int(time.time()) + (90 * 24 * 60 * 60)


# ── Route Handlers ────────────────────────────────────────────────
def list_tasks(user_id: str, query_params: dict) -> dict:
    """GET /tasks — list all tasks for a user, optionally filtered by status."""
    status_filter = query_params.get("status") if query_params else None

    if status_filter:
        result = table.query(
            IndexName="UserStatusIndex",
            KeyConditionExpression=Key("userId").eq(user_id) & Key("status").eq(status_filter),
        )
    else:
        result = table.query(
            KeyConditionExpression=Key("userId").eq(user_id),
        )

    return response(200, {"tasks": result["Items"], "count": result["Count"]})


def get_task(user_id: str, task_id: str) -> dict:
    """GET /tasks/{taskId}"""
    result = table.get_item(Key={"userId": user_id, "taskId": task_id})
    item = result.get("Item")
    if not item:
        return response(404, {"error": "Task not found"})
    return response(200, {"task": item})


def create_task(user_id: str, body: dict) -> dict:
    """POST /tasks"""
    if not body.get("title"):
        return response(400, {"error": "title is required"})

    task_id = str(uuid.uuid4())
    now = now_iso()

    item = {
        "userId":    user_id,
        "taskId":    task_id,
        "title":     body["title"],
        "priority":  body.get("priority", "medium"),
        "status":    "pending",
        "dueDate":   body.get("dueDate", ""),
        "notes":     body.get("notes", ""),
        "tags":      body.get("tags", []),
        "createdAt": now,
        "updatedAt": now,
        "expiresAt": ttl_90_days(),
    }

    table.put_item(Item=item)
    logger.info(f"Created task {task_id} for user {user_id}")
    return response(201, {"task": item})


def update_task(user_id: str, task_id: str, body: dict) -> dict:
    """PUT /tasks/{taskId}"""
    allowed = ["title", "priority", "status", "dueDate", "notes", "tags"]
    update_expr_parts = ["updatedAt = :updatedAt"]
    expr_values = {":updatedAt": now_iso()}

    for field in allowed:
        if field in body:
            update_expr_parts.append(f"{field} = :{field}")
            expr_values[f":{field}"] = body[field]

    if len(update_expr_parts) == 1:
        return response(400, {"error": "No valid fields to update"})

    try:
        result = table.update_item(
            Key={"userId": user_id, "taskId": task_id},
            UpdateExpression="SET " + ", ".join(update_expr_parts),
            ExpressionAttributeValues=expr_values,
            ConditionExpression="attribute_exists(taskId)",
            ReturnValues="ALL_NEW",
        )
        return response(200, {"task": result["Attributes"]})
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Task not found"})
        raise


def delete_task(user_id: str, task_id: str) -> dict:
    """DELETE /tasks/{taskId}"""
    try:
        table.delete_item(
            Key={"userId": user_id, "taskId": task_id},
            ConditionExpression="attribute_exists(taskId)",
        )
        return response(200, {"message": "Task deleted", "taskId": task_id})
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "Task not found"})
        raise


# ── Main Handler ──────────────────────────────────────────────────
def lambda_handler(event: dict, context) -> dict:
    logger.info(f"Event: {json.dumps(event)}")

    try:
        user_id = get_user_id(event)
    except ValueError as e:
        return response(401, {"error": str(e)})

    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path   = event.get("rawPath", "/tasks")
    params = event.get("queryStringParameters") or {}
    body   = json.loads(event.get("body") or "{}") if event.get("body") else {}

    # Extract taskId from path e.g. /tasks/{taskId}
    path_params = event.get("pathParameters") or {}
    task_id = path_params.get("taskId")

    try:
        if method == "GET" and not task_id:
            return list_tasks(user_id, params)
        elif method == "GET" and task_id:
            return get_task(user_id, task_id)
        elif method == "POST":
            return create_task(user_id, body)
        elif method == "PUT" and task_id:
            return update_task(user_id, task_id, body)
        elif method == "DELETE" and task_id:
            return delete_task(user_id, task_id)
        else:
            return response(405, {"error": f"Method {method} not allowed on {path}"})
    except Exception as e:
        logger.exception("Unhandled error")
        return response(500, {"error": "Internal server error", "detail": str(e)})
