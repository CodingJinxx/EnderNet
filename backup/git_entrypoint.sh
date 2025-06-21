#!/bin/bash

set -euo pipefail

[ -f /env.sh ] && source /env.sh

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


/seed.sh