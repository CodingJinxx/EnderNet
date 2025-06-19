FROM debian:bookworm-slim

ENV BACKUP_INTERVAL_H=6

RUN apt-get update && \
    apt-get install -y git zip curl cron openssh-client build-essential dos2unix && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/Tiiffi/mcrcon.git /tmp/mcrcon && \
    cd /tmp/mcrcon && \
    make && \
    cp mcrcon /usr/local/bin/mcrcon && \
    chmod +x /usr/local/bin/mcrcon && \
    rm -rf /tmp/mcrcon

COPY backup.sh /backup.sh
COPY entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh
RUN dos2unix /backup.sh && chmod +x /backup.sh

ENTRYPOINT ["/entrypoint.sh"]