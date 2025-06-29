#!/bin/bash

set -euo pipefail

REPO_DIR="/repo"

[ -f /env.sh ] && source /env.sh

# Check if any .zip files were pulled into REPO_DIR
if ! ls "$REPO_DIR"/*.zip >/dev/null 2>&1; then
  echo "📭 No backups found in remote. Seeding REPO_DIR with local /backups contents..."
  if ls /repo/*.zip >/dev/null 2>&1; then
    cp /repo/*.zip "$REPO_DIR/"
    echo "📦 Copied backups from /backups to $REPO_DIR."
  else
    echo "⚠️ No local backups found in /backups either. REPO_DIR remains empty."
  fi
else
  echo "📁 REPO_DIR already populated — no seeding needed."
fi