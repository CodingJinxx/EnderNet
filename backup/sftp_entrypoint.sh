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

# Add code here to find the latest filename in REMOTE_LIST, dont do anything if the REMOTE_LIST string
# once you have the latest_file check if it exists in /repo, if it doesnt download it

# --- pick the one ZIP with the biggest Unix-timestamp suffix ---
if [[ -z "$REMOTE_LIST" ]]; then
  echo "📭 No remote .zip files found; nothing to do."
else
  latest_file=$(printf "%s\n" $REMOTE_LIST \
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
get "$latest_file"
bye
EOF
  fi
fi

/seed.sh

echo "🔍 Checking for missing backups on remote..."

# (1) Grab only the .zip filenames, one per line, with absolutely no prompt noise.
raw_listing=$(sshpass -p "$SFTP_PASSWORD" \
    sftp -q -o StrictHostKeyChecking=no \
         -P "$SFTP_PORT" \
         "$SFTP_USER@$SFTP_HOST" <<-'EOF'
    ls -1 *.zip
    bye
EOF
)

# (2) Normalize CRs, drop blank lines, drop any 'sftp>' or echoed commands.
mapfile -t remote_files < <(printf '%s\n' "$raw_listing" \
    | tr -d '\r' \
    | sed '/^[[:space:]]*$/d' \
    | sed '/^sftp>/d' \
    | sed '/^\(ls -1 \|bye\)$/d'
)

if [[ ${#remote_files[@]} -eq 0 ]]; then
  echo "📭 Remote backup folder is empty. Uploading all local backups…"
else
  echo "🗃️ Remote backups found:"
  printf '  %s\n' "${remote_files[@]}"
fi

# (3) Walk local .zips and only upload the truly missing ones
shopt -s nullglob
for f in "$REPO_DIR"/*.zip; do
  filename=${f##*/}
  if printf '%s\n' "${remote_files[@]}" | grep -Fqx -- "$filename"; then
    echo "✅ $filename already exists remotely. Skipping."
  else
    echo "⬆️ Uploading missing file: $filename"
    sshpass -p "$SFTP_PASSWORD" sftp -q -o StrictHostKeyChecking=no -P "$SFTP_PORT" \
      "$SFTP_USER@$SFTP_HOST" <<EOF
put "$f"
bye
EOF
  fi
done
shopt -u nullglob

echo "🚀 Remote sync complete."
