#!/bin/bash

set -e

ZIP_PATH="/downloads/$MODPACK_ZIP"

echo "⚙️  Using zip file: $MODPACK_ZIP"

if [ -z "$ZIP_PATH" ]; then
  echo "❌ ERROR: MODPACK_ZIP environment variable not set."
  exit 1
fi


while [ ! -f /downloads/done.marker ]; do
    echo 'Waiting for modpack.zip...';
    sleep 10;
done;

if [ ! -f "$ZIP_PATH" ]; then
  echo "❌ ERROR: File not found: $ZIP_PATH"
  exit 2
fi

MANIFEST_TMP="/tmp/manifest.json"
EXISTING_MANIFEST="/opt/app/manifest.json"
if unzip -p "$ZIP_PATH" manifest.json > "$MANIFEST_TMP"; then
  incoming_version=$(jq -r '.serverPackCreatorVersion' "$MANIFEST_TMP")
else
  echo "❌ Could not read manifest.json from ZIP — forcing unzip."
  unzip -o "$ZIP_PATH" -d /opt/app
  exit 0
fi

# Try to read existing installed version
if [ -f "$EXISTING_MANIFEST" ]; then
  existing_version=$(jq -r '.serverPackCreatorVersion' "$EXISTING_MANIFEST")
else
  echo "🆕 No existing manifest found — assuming first install"
  existing_version=""
fi

# Compare versions
if [ "$incoming_version" != "$existing_version" ]; then
  echo "📦 Modpack version changed: '$existing_version' → '$incoming_version'"
  unzip -o "$ZIP_PATH" -d /opt/app
else
  echo "✅ Modpack version unchanged ($incoming_version), skipping unzip."
fi

if [ -d "/overrides" ]; then
  echo "🧩 Copying overrides into /opt/app..."
  cp -r /overrides/* /opt/app/
else
  echo "⚠️  No overrides directory found"
fi

sed -i 's/\r$//' /opt/app/variables.txt
sed -i 's/read -r WHY/WHY="Yes"/' /opt/app/start.sh
sed -i 's/read -r ANSWER/ANSWER="I agree"/' /opt/app/start.sh
sed -i 's/^SKIP_JAVA_CHECK=.*/SKIP_JAVA_CHECK=true/' /opt/app/variables.txt || echo "SKIP_JAVA_CHECK=true" >> /opt/app/variables.txt

PROPERTIES_FILE="/opt/app/server.properties"
if [ -f "$PROPERTIES_FILE" ]; then
  echo "🔧 Configuring RCON in server.properties..."
  sed -i 's/^enable-rcon=.*/enable-rcon=true/' "$PROPERTIES_FILE"
  sed -i "s/^rcon.password=.*/rcon.password=${RCON_PASSWORD:-changeme}/" "$PROPERTIES_FILE"
  sed -i 's/^rcon.port=.*/rcon.port=25575/' "$PROPERTIES_FILE"
else
  echo "⚠️  server.properties not found at $PROPERTIES_FILE"
fi

socat TCP4-LISTEN:$CONTROL_PORT,reuseaddr,fork SYSTEM:"bash /control.sh" &

# Wait for server.properties to appear and configure it only once
PROPERTIES_FILE="/opt/app/server.properties"
CONFIG_FLAG="/opt/app/.rcon_config_done"

# Wait for the file to exist
while [ ! -f "$PROPERTIES_FILE" ]; do
  echo "⏳ Waiting for server.properties to be generated..."
  sleep 2
done

if [ ! -f "$CONFIG_FLAG" ]; then
  echo "🔧 Configuring server.properties and start scripts..."

  sed -i 's/\r$//' /opt/app/variables.txt
  sed -i 's/read -r WHY/WHY="Yes"/' /opt/app/start.sh
  sed -i 's/read -r ANSWER/ANSWER="I agree"/' /opt/app/start.sh
  sed -i 's/^SKIP_JAVA_CHECK=.*/SKIP_JAVA_CHECK=true/' /opt/app/variables.txt || echo "SKIP_JAVA_CHECK=true" >> /opt/app/variables.txt

  sed -i 's/^enable-rcon=.*/enable-rcon=true/' "$PROPERTIES_FILE"
  sed -i "s/^rcon.password=.*/rcon.password=${RCON_PASSWORD:-changeme}/" "$PROPERTIES_FILE"
  sed -i 's/^rcon.port=.*/rcon.port=25575/' "$PROPERTIES_FILE"

  touch "$CONFIG_FLAG"
  echo "✅ Configuration complete."
else
  echo "✅ Configuration already applied. Skipping."
fi

# Wait for world directory to exist before writing timestamp
WORLD_PATH="/opt/app/world"
echo "⏳ Waiting for world directory to exist..."
while [ ! -d "$WORLD_PATH" ]; do
  sleep 2
done

echo "📌 World directory found. Starting timestamp loop."
while true; do
  date +%s > "$WORLD_PATH/timestamp.txt"
  sleep 60
done