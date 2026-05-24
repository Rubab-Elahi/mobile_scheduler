"""
Notification Service — Triggers push notifications via Amazon SNS
Triggered by: EventBridge (ScheduleTrigger or MissedTask events)
"""
import json
import os
import logging

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    """
    Event detail example (from EventBridge):
    {
        "userId": "...",
        "message": "Task 'Gym' starts in 10 mins",
        "urgency": "high"
    }
    """
    logger.info(f"Notification event received: {json.dumps(event)}")

    # EventBridge detail is usually in event['detail']
    detail = event.get("detail", {})
    user_id = detail.get("userId")
    message = detail.get("message", "You have a new productivity alert!")
    urgency = detail.get("urgency", "medium")

    if not user_id:
        logger.warning("No userId in notification event, skipping")
        return {"status": "skipped", "reason": "no_userId"}

    # In a full SNS setup with FCM/APNs, you'd target a specific EndpointArn
    # mapped to the userId. For now, we publish to a topic that the app can subscribe to.
    
    payload = {
        "default": message,
        "GCM": json.dumps({
            "notification": {
                "title": f"Scheduler Alert ({urgency})",
                "body": message,
                "sound": "default"
            },
            "data": {
                "userId": user_id,
                "urgency": urgency
            }
        }),
        "APNS": json.dumps({
            "aps": {
                "alert": {
                    "title": f"Scheduler Alert ({urgency})",
                    "body": message
                },
                "sound": "default"
            },
            "userId": user_id
        })
    }

    try:
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(payload),
            MessageStructure="json",
            MessageAttributes={
                "userId": {
                    "DataType": "String",
                    "StringValue": user_id
                }
            }
        )
        logger.info(f"Published notification to SNS: {response.get('MessageId')}")
        return {"status": "success", "messageId": response.get("MessageId")}
        
    except Exception as e:
        logger.error(f"Failed to publish notification: {e}")
        return {"status": "error", "detail": str(e)}
