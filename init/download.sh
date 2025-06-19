#!/bin/sh
set -e

if [ -f "$MODPACK_PATH" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
  echo "modpack.zip already exists at $MODPACK_PATH, skipping download."
  exit 0
fi

if [ -z "$MODPACK_URL" ]; then
  echo "ERROR: MODPACK_URL is not set."
  exit 1
fi

echo "Downloading modpack zip from $MODPACK_URL..."

TMP=/tmp/tmp.zip
wget --user-agent="Mozilla/5.0" -O $TMP "$MODPACK_URL"
mv $TMP $MODPACK_PATH
touch /modpacks/done.marker

echo "Download complete."
