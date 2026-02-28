#!/bin/bash
set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

echo "[Backup] Starting backup at $TIMESTAMP"

pg_dump \
  -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER" \
  "$POSTGRES_DB" \
  | gzip > "$BACKUP_FILE"

echo "[Backup] Backup created: $BACKUP_FILE"

# Remove backups older than 48 hours (2880 minutes)
find "$BACKUP_DIR" -type f -name "backup_*.sql.gz" -mmin +2880 -delete

echo "[Backup] Old backups cleaned"
