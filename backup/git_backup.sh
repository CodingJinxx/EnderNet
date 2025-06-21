#!/bin/bash

set -euo pipefail

[ -f /env.sh ] && source /env.sh

ACTION=${1:-push} 
BACKUP_NAME="${WORLD_ID}-${TIMESTAMP}.zip"

export GIT_SSH_COMMAND="ssh -i /ssh/id_rsa -o StrictHostKeyChecking=no"

if [[ "$ACTION" == "pull" ]]; then
  # Clone or update the Git repo
  cd $REPO_DIR
  if [ ! -d "$REPO_DIR/.git" ]; then
    git clone "$GIT_REPO" "$REPO_DIR"
  else
    cd "$REPO_DIR"
    git pull
  fi
  exit 0
fi

if [[ "$ACTION" == "push" ]]; then
  cd $REPO_DIR
  git add "$BACKUP_NAME"
  git commit -m "Backup $BACKUP_NAME"
  git push
  exit 0
fi

echo "❌ Invalid action: $ACTION. Use 'push' or 'pull'."
exit 1