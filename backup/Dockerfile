FROM debian:bookworm-slim

ENV BACKUP_INTERVAL_H=6
ENV NO_RESTORE=false
ENV BACKUP_TARGET=git

RUN apt-get update && \
    apt-get install -y git zip curl cron openssh-client build-essential dos2unix sshpass && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/Tiiffi/mcrcon.git /tmp/mcrcon && \
    cd /tmp/mcrcon && \
    make && \
    cp mcrcon /usr/local/bin/mcrcon && \
    chmod +x /usr/local/bin/mcrcon && \
    rm -rf /tmp/mcrcon


COPY backup.sh /backup.sh
COPY git_backup.sh /git_backup.sh
COPY sftp_backup.sh /sftp_backup.sh
COPY entrypoint.sh /entrypoint.sh
COPY git_entrypoint.sh /git_entrypoint.sh
COPY sftp_entrypoint.sh /sftp_entrypoint.sh
COPY seed.sh /seed.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh
RUN dos2unix /git_entrypoint.sh && chmod +x /git_entrypoint.sh
RUN dos2unix /sftp_entrypoint.sh && chmod +x /sftp_entrypoint.sh
RUN dos2unix /backup.sh && chmod +x /backup.sh
RUN dos2unix /git_backup.sh && chmod +x /git_backup.sh
RUN dos2unix /sftp_backup.sh && chmod +x /sftp_backup.sh
RUN dos2unix /seed.sh && chmod +x /seed.sh

ENTRYPOINT ["/entrypoint.sh"]