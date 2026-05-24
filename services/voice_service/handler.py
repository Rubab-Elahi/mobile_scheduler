"""
Voice Service — Amazon Transcribe + Amazon Polly
Routes:
  POST /voice/upload-url    → presigned S3 PUT URL for Flutter
  POST /voice/transcribe    → start transcription job, return transcript
  POST /voice/synthesize    → Polly TTS, return audio URL
"""
import json
import os
import uuid
import time
import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client         = boto3.client("s3")
transcribe_client = boto3.client("transcribe")
polly_client      = boto3.client("polly")

VOICE_BUCKET = os.environ["VOICE_BUCKET"]


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


# ── Handlers ──────────────────────────────────────────────────────
def get_upload_url(user_id: str, body: dict) -> dict:
    """
    POST /voice/upload-url
    Body: { "filename": "recording.m4a", "contentType": "audio/m4a" }
    Returns a presigned S3 PUT URL valid for 5 minutes.
    """
    filename     = body.get("filename", f"{uuid.uuid4()}.m4a")
    content_type = body.get("contentType", "audio/m4a")
    s3_key       = f"uploads/{user_id}/{uuid.uuid4()}_{filename}"

    url = s3_client.generate_presigned_url(
        "put_object",
        Params={
            "Bucket":      VOICE_BUCKET,
            "Key":         s3_key,
            "ContentType": content_type,
        },
        ExpiresIn=300,
    )

    return resp(200, {
        "uploadUrl": url,
        "s3Key":     s3_key,
        "bucket":    VOICE_BUCKET,
        "expiresIn": 300,
    })


def transcribe_audio(user_id: str, body: dict) -> dict:
    """
    POST /voice/transcribe
    Body: { "s3Key": "uploads/uid/file.m4a" }
    Starts a Transcribe job and polls for completion (up to 55 s).
    Returns the transcript text.
    """
    s3_key = body.get("s3Key")
    if not s3_key:
        return resp(400, {"error": "s3Key is required"})

    job_name  = f"sched-{uuid.uuid4().hex[:16]}"
    media_uri = f"s3://{VOICE_BUCKET}/{s3_key}"

    transcribe_client.start_transcription_job(
        TranscriptionJobName=job_name,
        Media={"MediaFileUri": media_uri},
        MediaFormat=s3_key.rsplit(".", 1)[-1] if "." in s3_key else "m4a",
        LanguageCode="en-US",
        OutputBucketName=VOICE_BUCKET,
        OutputKey=f"transcriptions/{user_id}/{job_name}.json",
        Settings={
            "ShowSpeakerLabels": False,
            "ChannelIdentification": False,
        },
    )

    # Poll for up to 55 seconds (Lambda max is 60s for this function)
    for _ in range(11):
        time.sleep(5)
        job = transcribe_client.get_transcription_job(
            TranscriptionJobName=job_name
        )["TranscriptionJob"]
        status = job["TranscriptionJobStatus"]

        if status == "COMPLETED":
            # Fetch transcript JSON from S3
            output_key = f"transcriptions/{user_id}/{job_name}.json"
            obj = s3_client.get_object(Bucket=VOICE_BUCKET, Key=output_key)
            transcript_data = json.loads(obj["Body"].read())
            transcript_text = transcript_data["results"]["transcripts"][0]["transcript"]

            return resp(200, {
                "transcript": transcript_text,
                "jobName":    job_name,
                "status":     "COMPLETED",
            })

        elif status == "FAILED":
            return resp(500, {
                "error":   "Transcription job failed",
                "jobName": job_name,
                "reason":  job.get("FailureReason", "Unknown"),
            })

    # Job still running — return job name for async polling
    return resp(202, {
        "message": "Transcription in progress",
        "jobName": job_name,
        "status":  "IN_PROGRESS",
    })


def synthesize_speech(user_id: str, body: dict) -> dict:
    """
    POST /voice/synthesize
    Body: { "text": "Your next task is ...", "voiceId": "Joanna" }
    Synthesizes speech and saves to S3, returns a presigned GET URL.
    """
    text     = body.get("text", "")
    voice_id = body.get("voiceId", "Joanna")

    if not text:
        return resp(400, {"error": "text is required"})
    if len(text) > 3000:
        return resp(400, {"error": "text exceeds 3000 character limit"})

    polly_response = polly_client.synthesize_speech(
        Text=text,
        OutputFormat="mp3",
        VoiceId=voice_id,
        Engine="neural",
    )

    audio_key = f"tts/{user_id}/{uuid.uuid4()}.mp3"
    s3_client.put_object(
        Bucket=VOICE_BUCKET,
        Key=audio_key,
        Body=polly_response["AudioStream"].read(),
        ContentType="audio/mpeg",
    )

    audio_url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": VOICE_BUCKET, "Key": audio_key},
        ExpiresIn=3600,
    )

    return resp(200, {"audioUrl": audio_url, "s3Key": audio_key})


# ── Main Handler ──────────────────────────────────────────────────
def lambda_handler(event: dict, context) -> dict:
    logger.info(f"Event: {json.dumps(event)}")

    try:
        user_id = get_user_id(event)
    except ValueError as e:
        return resp(401, {"error": str(e)})

    path   = event.get("rawPath", "")
    body   = json.loads(event.get("body") or "{}") if event.get("body") else {}

    try:
        if "/voice/upload-url" in path:
            return get_upload_url(user_id, body)
        elif "/voice/transcribe" in path:
            return transcribe_audio(user_id, body)
        elif "/voice/synthesize" in path:
            return synthesize_speech(user_id, body)
        else:
            return resp(404, {"error": f"Unknown route: {path}"})
    except Exception as e:
        logger.exception("Unhandled error in voice service")
        return resp(500, {"error": "Internal server error", "detail": str(e)})
