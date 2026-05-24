# ═══════════════════════════════════════════════════════════════════
#  S3 Bucket — Voice Audio Files
#  Stores raw audio uploaded from Flutter for Amazon Transcribe
# ═══════════════════════════════════════════════════════════════════

resource "aws_s3_bucket" "voice_files" {
  bucket = "${local.name_prefix}-voice-files-${local.account_id}"

  tags = {
    Name    = "${local.name_prefix}-voice-files"
    Purpose = "VoiceAudioStorage"
  }
}

# ── Versioning ────────────────────────────────────────────────────
resource "aws_s3_bucket_versioning" "voice_files" {
  bucket = aws_s3_bucket.voice_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ── Server-side encryption ────────────────────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "voice_files" {
  bucket = aws_s3_bucket.voice_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# ── Block all public access ───────────────────────────────────────
resource "aws_s3_bucket_public_access_block" "voice_files" {
  bucket = aws_s3_bucket.voice_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Lifecycle — auto-delete raw audio after 7 days ────────────────
resource "aws_s3_bucket_lifecycle_configuration" "voice_files" {
  bucket = aws_s3_bucket.voice_files.id

  rule {
    id     = "expire-raw-audio"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 7
    }
  }

  rule {
    id     = "expire-transcription-output"
    status = "Enabled"

    filter {
      prefix = "transcriptions/"
    }

    expiration {
      days = 30
    }
  }
}

# ── CORS — allow Flutter to PUT via presigned URLs ────────────────
resource "aws_s3_bucket_cors_configuration" "voice_files" {
  bucket = aws_s3_bucket.voice_files.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"] # Tighten to your Flutter app domain in prod
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
