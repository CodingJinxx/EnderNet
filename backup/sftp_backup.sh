#!/bin/bash

set -euo pipefail

[ -f /env.sh ] && source /env.sh

ACTION=${1:-push} 
LATEST_FILE=${2:-} # latest file name

SFTP_PORT=${SFTP_PORT:-22}
SFTP_HOST=${SFTP_HOST:-}
SFTP_USER=${SFTP_USER:-}
SECRET_PATH=${SECRET_PATH:-"/sftp/SFTP_PASSWORD"}
REPO_DIR=${REPO_DIR:-"/repo"}

if [[ -z "$SFTP_USER" || -z "$SFTP_HOST" ]]; then
  echo "❌ SFTP_USER and SFTP_HOST must be set."
  exit 1
fi

if [ ! -f "$SECRET_PATH" ]; then
  echo "🚫 Missing secret: '$SECRET_PATH'. Please mount the SFTP password file."
  exit 1
fi

SFTP_PASSWORD=$(cat "$SECRET_PATH")

if [[ -z "$SFTP_PASSWORD" || ${#SFTP_PASSWORD} -lt 6 ]]; then
  echo "❌ SFTP password is too short or empty. Must be at least 6 characters."
  exit 1
fi

if [[ "$ACTION" == "pull" ]]; then
  echo "📡 Connecting to SFTP server to list remote files..."

# (1) Grab the raw directory listing
raw_listing=$(sshpass -p "$SFTP_PASSWORD" \
  sftp -o StrictHostKeyChecking=no \
       -P "$SFTP_PORT" \
       "$SFTP_USER@$SFTP_HOST" <<-'EOF'
    ls
    bye
EOF
)

# (2) Extract only the filename column (last field)
#     e.g. "-rw-r--r--    1 user group   12345 Jun 21 12:34 file.zip"
#           becomes "file.zip"
filenames=$(echo "$raw_listing" | awk '{print $NF}')

# (3) Filter to .zip files; if grep finds nothing, it returns exit code 1,
#     so we OR it with true so our script doesn’t die, and yield an empty string.
REMOTE_FILENAMES=$(echo "$filenames" | grep -E '\.zip$' || true)

# --- pick the one ZIP with the biggest Unix-timestamp suffix ---
if [[ -z "$REMOTE_FILENAMES" ]]; then
  echo "📭 No remote .zip files found; nothing to do."
else
  latest_file=$(printf "%s\n" $REMOTE_FILENAMES \
    | sort -t- -k2,2n \
    | tail -n1)

  echo "🔍 Latest remote file is: $latest_file"

    # (3) check if it’s in /repo already; if not, download it
  if [[ -f "/repo/$latest_file" ]]; then
    echo "✔ Already have $latest_file in /repo"
  else
    echo "⬇ Downloading $latest_file to /repo…"

     sshpass -p "$SFTP_PASSWORD" sftp -q -o StrictHostKeyChecking=no -P "$SFTP_PORT" \
      "$SFTP_USER@$SFTP_HOST" <<EOF
lcd /repo
get "$latest_file"
bye
EOF
  fi
fi
fi

if [[ "$ACTION" == "push" ]]; then
  echo "⬆️ Pushing new backups from $REPO_DIR to SFTP..."

  if [[ -z "$LATEST_FILE" ]]; then
    echo "⚠️ No backup ZIP files found to push."
    exit 0
  fi

  FILE_NAME=$(basename "$LATEST_FILE")

  echo "📡 Checking if $FILE_NAME already exists on remote..."

# (1) Grab the raw directory listing
raw_listing=$(sshpass -p "$SFTP_PASSWORD" \
  sftp -o StrictHostKeyChecking=no \
       -P "$SFTP_PORT" \
       "$SFTP_USER@$SFTP_HOST" <<-'EOF'
    ls
    bye
EOF
)

# (2) Extract only the filename column (last field)
#     e.g. "-rw-r--r--    1 user group   12345 Jun 21 12:34 file.zip"
#           becomes "file.zip"
filenames=$(echo "$raw_listing" | awk '{print $NF}')

# (3) Filter to .zip files; if grep finds nothing, it returns exit code 1,
#     so we OR it with true so our script doesn’t die, and yield an empty string.
REMOTE_LIST=$(echo "$filenames" | grep -E '\.zip$' || true)

  if echo "$REMOTE_LIST" | awk '{print $NF}' | grep -qx "$FILE_NAME"; then
    echo "🚫 Remote already contains $FILE_NAME. Skipping upload."
  else
    echo "⬆️ Uploading missing file: $FILE_NAME"
    sshpass -p "$SFTP_PASSWORD" sftp -o StrictHostKeyChecking=no -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" <<EOF
put "$LATEST_FILE"
bye
EOF
    echo "✅ Push complete."
  fi

  exit 0
fi

echo "❌ Invalid ACTION: $ACTION. Use 'pull' or 'push'."
exit 1
