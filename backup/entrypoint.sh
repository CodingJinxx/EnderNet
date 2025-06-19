#!/bin/bash

set -euo pipefail

CRON_FILE="/etc/cron.d/mc-backup"
BACKUP_INTERVAL_H=${BACKUP_INTERVAL_H:-6}
REPO_DIR="/gitrepo"
DATA_DIR="/data"
WORLD_ID=${WORLD_ID:-defaultworld}
REPLACED_DIR="/replaced_worlds"
CRON_FILE="/etc/cron.d/mc-backup"
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

# Generate SSH key if not present
if [ ! -f /ssh/id_rsa ]; then
  echo "🔐 Generating new SSH key..."
  mkdir -p /ssh
  ssh-keygen -t rsa -f /ssh/id_rsa -N ""
  echo "⚠️  Add the following public key to your Git repo's deploy keys:"
  cat /ssh/id_rsa.pub
fi


export GIT_SSH_COMMAND="ssh -i /ssh/id_rsa -o StrictHostKeyChecking=no"

echo "🔍 Testing SSH connection to GitHub..."
SSH_OUTPUT=$(ssh -i /ssh/id_rsa -o StrictHostKeyChecking=no -T git@github.com 2>&1 || true)
echo "$SSH_OUTPUT"

if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
  echo "✅ Git SSH access looks good."
else
  echo "⚠️ Git SSH output did not match expected pattern."
  echo "⚠️ Output was:"
  echo "$SSH_OUTPUT"
  echo "⚠️ Proceeding anyway assuming key was accepted."
fi

# Clone or update the Git repo
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$GIT_REPO" "$REPO_DIR"
else
  cd "$REPO_DIR"
  git pull
fi

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