FROM postgres:18-alpine

RUN apk add --no-cache tzdata

COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

CMD sh -c "while true; do /backup.sh; sleep 3600; done"
