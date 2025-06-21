#!/bin/bash

set -euo pipefail

[ -f /env.sh ] && source /env.sh

SFTP_PORT=${SFTP_PORT:-22}
SFTP_HOST=${SFTP_HOST:-}
SFTP_USER=${SFTP_USER:-}
SECRET_PATH=${SECRET_PATH:-"/sftp/SFTP_PASSWORD"}
REPO_DIR=${REPO_DIR:-"/repo"}

if [[ -z "${SFTP_USER:-}" || -z "${SFTP_HOST:-}" || -z "${SFTP_PORT:-}" || -z "${REPO_DIR:-}" ]]; then
  echo "❌ Required environment variables: SFTP_USER, SFTP_HOST, SFTP_PORT, REPO_DIR"
  exit 1
fi

if [ -f "$SECRET_PATH" ]; then
  export SFTP_PASSWORD=$(cat "$SECRET_PATH")
  if [ -z "$SFTP_PASSWORD" ] || [ ${#SFTP_PASSWORD} -lt 8 ]; then
    echo "❌ SFTP password is too short or empty. Must be at least 8 characters."
    exit 1
  else
    echo "🔐 SFTP password loaded successfully — length: ${#SFTP_PASSWORD} characters"
  fi
else 
  echo "🚫 Missing secret: '$SECRET_PATH'. Please mount the SFTP password file."
  exit 1
fi

# Test SFTP connection
echo "🔍 Testing SFTP connection to $SFTP_HOST:$SFTP_PORT..."

# Use sshpass if available, or fallback to expect
if command -v sshpass >/dev/null 2>&1; then
  sshpass -p "$SFTP_PASSWORD" sftp -o StrictHostKeyChecking=no -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" <<< $'bye'
else
  echo "⚠️ sshpass not available. Skipping automated SFTP login test."
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "❌ sshpass not found. Please install it."
  exit 1
fi

echo "🚀 Starting selective download to $REPO_DIR..."
mkdir -p "$REPO_DIR"

echo "📡 Getting list of remote files..."

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
REMOTE_FILES=$(echo "$filenames" | grep -E '\.zip$' || true)


# Check for obvious errors or missing output
if [[ -z "$REMOTE_FILES" ]] || echo "$REMOTE_FILES" | grep -qE "Failure|Permission denied|Connection closed|ls"; then
  echo "📭 No remote files found or failed to list remote directory."
else
  echo "🗂️ Remote files detected:"
  echo "$REMOTE_FILES"
fi

FILES_TO_DOWNLOAD=()

# Parse file names safely
while read -r line; do
  filename=$(echo "$line" | awk '{print $NF}')
  [[ -z "$filename" ]] && continue
  local_path="$REPO_DIR/$filename"
  if [ ! -f "$local_path" ]; then
    FILES_TO_DOWNLOAD+=("$filename")
  else
    echo "✅ Skipping existing file: $filename"
  fi
done <<< "$REMOTE_FILES"

if [ ${#FILES_TO_DOWNLOAD[@]} -eq 0 ]; then
  echo "📭 No new files to download."
else
  echo "⬇️ Downloading ${#FILES_TO_DOWNLOAD[@]} new file(s)..."

  sshpass -p "$SFTP_PASSWORD" sftp -o StrictHostKeyChecking=no -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" <<EOF
lcd $REPO_DIR
$(for file in "${FILES_TO_DOWNLOAD[@]}"; do echo "get $file"; done)
bye
EOF

  echo "✅ Download complete."
fi

echo "🎉 All done!"

/seed.sh

echo "🔍 Checking for missing backups on remote..."

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


if [[ -z "$REMOTE_LIST" ]]; then
  echo "📭 Remote backup folder is empty. Uploading all local backups..."
else
  echo "🗃️ Remote backups found:"
  echo "$REMOTE_LIST"
fi

# Check if any .zip files exist
if ! ls "$REPO_DIR"/*.zip >/dev/null 2>&1; then
  echo "📭 No local ZIP backups to upload."
else
  shopt -s nullglob
  for f in "$REPO_DIR"/*.zip; do
    filename=$(basename "$f")
    if ! echo "$REMOTE_LIST" | grep -q "$filename"; then
      echo "⬆️ Uploading missing file: $filename"
      sshpass -p "$SFTP_PASSWORD" sftp -o StrictHostKeyChecking=no -P "$SFTP_PORT" "$SFTP_USER@$SFTP_HOST" <<EOF
put "$f"
bye
EOF
    else
      echo "✅ $filename already exists remotely. Skipping."
    fi
  done
  shopt -u nullglob
fi
echo "🚀 Remote sync complete."
