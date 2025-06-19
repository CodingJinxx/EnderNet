#!/bin/bash
# backup.sh for the backup container using RCON and timestamp-based change detection

set -euo pipefail

[ -f /env.sh ] && source /env.sh

SKIP_RCON=${SKIP_RCON:-false}
WORLD_ID=${WORLD_ID:-defaultworld}
TIMESTAMP=$(date +%s)
BACKUP_NAME="${WORLD_ID}-${TIMESTAMP}.zip"
REPO_DIR="/gitrepo"
DATA_DIR="/data"
BACKUP_DIR="/backups"
REPLACED_DIR="/replaced_worlds"
RCON_HOST="${RCON_HOST:-modpack-runner}"
RCON_PORT="${RCON_PORT:-25575}"
RCON_PASSWORD="${RCON_PASSWORD:-password}"

export GIT_SSH_COMMAND="ssh -i /ssh/id_rsa -o StrictHostKeyChecking=no"

# Clone or update the Git repo
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$GIT_REPO" "$REPO_DIR"
else
  cd "$REPO_DIR"
  git pull
fi

# Check if world has changed based on timestamp.txt
cd $REPO_DIR
LATEST_FILE=$(ls -1 ${WORLD_ID}-*.zip 2>/dev/null | sort -t'-' -k2 -n | tail -n 1 || true)
cd $DATA_DIR

if [ -n "$LATEST_FILE" ]; then
  echo "Found latest backup: $LATEST_FILE"

  LATEST_TIMESTAMP=$(unzip -p "$REPO_DIR/$LATEST_FILE" world/timestamp.txt 2>/dev/null || echo "0")
  CURRENT_TIMESTAMP=$(cat "$DATA_DIR/world/timestamp.txt" 2>/dev/null || echo "0")

  echo "Latest backup timestamp: $LATEST_TIMESTAMP"
  echo "Current world timestamp: $CURRENT_TIMESTAMP"

  if [ "$LATEST_TIMESTAMP" -ge "$CURRENT_TIMESTAMP" ]; then
    echo "No newer world state detected. Skipping backup."
    exit 0
  else
    echo "World has changed since last backup. Proceeding."
  fi
fi

echo Connecting to $RCON_HOST:$RCON_PORT with Password: $RCON_PASSWORD

# Disable autosave and flush to disk

if [ "$SKIP_RCON" != "true" ]; then
/usr/local/bin/mcrcon -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "/say Beginning Backup"
/usr/local/bin/mcrcon -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "/say BTW Connor stop sucking so much cock, your breath stinks"
/usr/local/bin/mcrcon -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "/save-off"
/usr/local/bin/mcrcon -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "/save-all"
  sleep 5
fi


sleep 5

# Archive world safely
cd "$DATA_DIR"
zip -r "$BACKUP_DIR/$BACKUP_NAME" world/

# Re-enable saving
if [ "$SKIP_RCON" != "true" ]; then
  /usr/local/bin/mcrcon -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "/save-on"
  /usr/local/bin/mcrcon -H "$RCON_HOST" -P "$RCON_PORT" -p "$RCON_PASSWORD" "/say Backup Complete"
fi
# Copy and push to Git
cp "$BACKUP_DIR/$BACKUP_NAME" "$REPO_DIR"
cd "$REPO_DIR"
git add "$BACKUP_NAME"
git commit -m "Backup $BACKUP_NAME"
git push
