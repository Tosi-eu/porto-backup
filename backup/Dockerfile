FROM postgres:18-alpine

RUN apk add --no-cache tzdata python3 py3-pip \
  && pip install --break-system-packages --no-cache-dir awscli

COPY backup.sh /backup.sh
COPY backup-entrypoint.sh /backup-entrypoint.sh
RUN chmod +x /backup.sh /backup-entrypoint.sh

# Interval between runs (seconds). Override in compose: BACKUP_INTERVAL_SECONDS
ENV BACKUP_INTERVAL_SECONDS=86400

CMD ["/backup-entrypoint.sh"]