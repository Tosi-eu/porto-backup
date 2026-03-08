#!/bin/bash
set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

echo "[Backup] Starting backup at $TIMESTAMP"

mkdir -p "$BACKUP_DIR"

export PGPASSWORD="${POSTGRES_PASSWORD:-$DB_PASSWORD}"

pg_dump \
  -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER" \
  "$POSTGRES_DB" \
  | gzip > "$BACKUP_FILE"

unset PGPASSWORD

echo "[Backup] Backup created: $BACKUP_FILE"

FILE_TO_UPLOAD="$BACKUP_FILE"
ENCRYPTED_FILE=""
if [ -n "${BACKUP_ENCRYPTION_PASSWORD}" ]; then
  ENCRYPTED_FILE="${BACKUP_FILE}.enc"
  if openssl enc -aes-256-cbc -salt -pbkdf2 -in "$BACKUP_FILE" -out "$ENCRYPTED_FILE" -k "$BACKUP_ENCRYPTION_PASSWORD" 2>/dev/null; then
    FILE_TO_UPLOAD="$ENCRYPTED_FILE"
    echo "[Backup] Encrypted backup: $ENCRYPTED_FILE"
  else
    ENCRYPTED_FILE=""
    echo "[Backup] Encryption failed (non-fatal), uploading plain backup"
  fi
fi

if [ "${NODE_ENV:-}" = "production" ] && [ -n "${R2_ACCOUNT_ID}" ] && [ -n "${R2_ACCESS_KEY_ID}" ] && [ -n "${R2_SECRET_ACCESS_KEY}" ] && [ -n "${R2_BUCKET_NAME}" ]; then
  if echo "$R2_BUCKET_NAME" | grep -q '://'; then
    echo "[Backup] R2 skipped: R2_BUCKET_NAME must be the bucket name only (e.g. abrigo-backup), not the S3 API URL. Use R2_ACCOUNT_ID for the endpoint."
  else
  echo "[Backup] Uploading to R2 bucket: $R2_BUCKET_NAME"
  R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  export AWS_DEFAULT_REGION="${R2_REGION:-auto}"

  if aws s3 cp "$FILE_TO_UPLOAD" "s3://${R2_BUCKET_NAME}/backups/$(basename "$FILE_TO_UPLOAD")" --endpoint-url "$R2_ENDPOINT"; then
    echo "[Backup] R2 upload OK"
    R2_RETENTION_COUNT="${R2_RETENTION_COUNT:-168}"
    aws s3 ls "s3://${R2_BUCKET_NAME}/backups/" --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
      | sort -k1,2 -r \
      | tail -n +$((R2_RETENTION_COUNT + 1)) \
      | awk '{print $4}' \
      | while read -r fname; do
          [ -z "$fname" ] && continue
          echo "[Backup] Deleting old R2 object: $fname"
          aws s3 rm "s3://${R2_BUCKET_NAME}/backups/${fname}" --endpoint-url "$R2_ENDPOINT" 2>/dev/null || true
        done
  else
    echo "[Backup] R2 upload failed (non-fatal)"
  fi
  [ -n "${ENCRYPTED_FILE}" ] && [ -f "${ENCRYPTED_FILE}" ] && rm -f "${ENCRYPTED_FILE}"
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
  fi
else
  if [ "${NODE_ENV:-}" != "production" ]; then
    echo "[Backup] R2 skipped (NODE_ENV is not production; backup is local only)"
  else
    echo "[Backup] R2 skipped (missing R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY or R2_BUCKET_NAME)"
  fi
fi

echo "[Backup] Cleaning old local backups (keeping latest only)"

ls -1t "$BACKUP_DIR"/backup_*.sql.gz 2>/dev/null \
  | tail -n +2 \
  | xargs -r rm -- 2>/dev/null || true
find "$BACKUP_DIR" -type f -name "backup_*.sql.gz" -mmin +2880 -delete 2>/dev/null || true

echo "[Backup] Cleanup done"
echo "[Backup] Old backups cleaned"

if [ -n "${POSTGRES_HOST}" ] && [ -n "${POSTGRES_DB}" ] && [ -n "${POSTGRES_USER}" ]; then
  LAST_BACKUP_AT=$(date -Iseconds)
  export PGPASSWORD="${POSTGRES_PASSWORD:-$DB_PASSWORD}"
  if psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -t -c \
    "INSERT INTO system_config (key, value, created_at, updated_at) VALUES ('last_backup_at', '$LAST_BACKUP_AT', NOW(), NOW()) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();" 2>/dev/null; then
    echo "[Backup] system_config last_backup_at updated: $LAST_BACKUP_AT"
  else
    echo "[Backup] Could not update system_config (table may not exist yet): non-fatal"
  fi
  unset PGPASSWORD
fi
