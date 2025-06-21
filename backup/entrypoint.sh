#!/bin/bash

set -euo pipefail

CRON_FILE="/etc/cron.d/mc-backup"
BACKUP_INTERVAL_H=${BACKUP_INTERVAL_H:-6}
REPO_DIR="/repo"
DATA_DIR="/data"
WORLD_ID=${WORLD_ID:-defaultworld}
REPLACED_DIR="/replaced_worlds"
MAX_ATTEMPTS=50
SLEEP_SECONDS=5

# Export all current env variables to a file (excluding a few)
printenv | grep -v "^PWD=" | grep -v "^SHLVL=" | grep -v "^_=" > /env.sh

# Prefix all with 'export '
sed -i 's/^/export /' /env.sh

# Define cleanup function
on_shutdown() {
  echo "🛑 Caught shutdown signal. Running final backup..."
  /backup.sh || echo "⚠️ Final backup failed."
  echo "✅ Final backup complete. Exiting."
  exit 0
}

# Trap SIGTERM and SIGINT
trap on_shutdown SIGTERM SIGINT

# Validate interval
if ! [[ "$BACKUP_INTERVAL_H" =~ ^[0-9]+$ ]] || [ "$BACKUP_INTERVAL_H" -lt 1 ] || [ "$BACKUP_INTERVAL_H" -gt 24 ]; then
  echo "Invalid BACKUP_INTERVAL_H: $BACKUP_INTERVAL_H. Must be between 1 and 24."
  exit 1
fi

# Create cron schedule
if [ -n "${DEBUG_CRON:-}" ]; then
  echo "⚠️ Debug mode: forcing backup every 2 minutes"
  SCHEDULE="*/2 * * * *"
elif [ "$BACKUP_INTERVAL_H" -eq 1 ]; then
  SCHEDULE="0 * * * *"
else
  SCHEDULE="0 */$BACKUP_INTERVAL_H * * *"
fi


# Write crontab
cat <<EOF > "$CRON_FILE"
$SCHEDULE root /backup.sh >> /var/log/mc-backup.log 2>&1
EOF

chmod 0644 "$CRON_FILE"
crontab "$CRON_FILE"

if [[ "${BACKUP_TARGET,,}" == "git" ]]; then
  echo "🔍 Initializing Git-based backup..."
  /git_entrypoint.sh
elif [[ "${BACKUP_TARGET,,}" == "sftp" ]]; then
  echo "☁️ Initializing SFTP based backup..."
  /sftp_entrypoint.sh
else
  echo "📁 BACKUP_TARGET set to '$BACKUP_TARGET'. Skipping known backup entrypoint handlers."
fi

if [[ "${NO_RESTORE,,}" != "true" ]]; then
  # Restore the latest world if necessary
  LATEST_FILE=$(ls -1 "$REPO_DIR/${WORLD_ID}"-*.zip 2>/dev/null | sort -r | head -n 1 || true)

  if [ -n "$LATEST_FILE" ]; then
    if [ ! -d "$DATA_DIR/world" ]; then
      echo "[INIT] No world folder found. Restoring from latest backup: $LATEST_FILE"
      unzip -o "$LATEST_FILE" -d "$DATA_DIR"
    else
      LATEST_TIMESTAMP=$(unzip -p "$LATEST_FILE" world/timestamp.txt 2>/dev/null || echo "0")
      CURRENT_TIMESTAMP=$(cat "$DATA_DIR/world/timestamp.txt" 2>/dev/null || echo "0")

      if [ "$LATEST_TIMESTAMP" -gt "$CURRENT_TIMESTAMP" ]; then
        echo "[INIT] Backup is newer. Replacing local world."
        mkdir -p "$REPLACED_DIR"
        cp -r "$DATA_DIR/world" "$REPLACED_DIR/world-$CURRENT_TIMESTAMP"
        rm -rf "$DATA_DIR/world"
        unzip "$LATEST_FILE" -d "$DATA_DIR"
      else
        echo "[INIT] Local world is up to date. No restore needed."
      fi
    fi
  else
    echo "[INIT] No backups found to restore."
  fi
else
   echo "[INIT] NO_RESTORE=true — skipping any world restoration."
fi

for i in $(seq 1 $MAX_ATTEMPTS); do
  echo "🔁 Attempt $i: Starting Minecraft server..."
  RESPONSE=$(curl -s -X GET "$CONTROL_HOST:$CONTROL_PORT/start" || true)
  echo "➡️  Response: $RESPONSE"
  if echo "$RESPONSE" | grep -qi "Server started"; then
    echo "✅ Server successfully started."
    break
  fi
  echo "⏳ Waiting $SLEEP_SECONDS seconds before retry..."
  sleep $SLEEP_SECONDS

done

if [ $i -eq $MAX_ATTEMPTS ]; then
  echo "❌ Failed to start server after $MAX_ATTEMPTS attempts."
  exit 1
fi


# Launch cron in foreground
exec cron -f