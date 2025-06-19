#!/bin/bash

set -e

ZIP_PATH="/downloads/$MODPACK_ZIP"

echo "⚙️  Using zip file: $MODPACK_ZIP"

if [ -z "$ZIP_PATH" ]; then
  echo "❌ ERROR: MODPACK_ZIP environment variable not set."
  exit 1
fi


while [ ! -f $ZIP_PATH ]; do
    echo 'Waiting for modpack.zip...';
    sleep 2;
done;

if [ ! -f "$ZIP_PATH" ]; then
  echo "❌ ERROR: File not found: $ZIP_PATH"
  exit 2
fi

unzip -o $ZIP_PATH -d /opt/app;

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

# Run the modpack's start.sh with automatic answers
if [ -f /opt/app/start.sh ]; then
  echo "🚀 Running start.sh with auto inputs..."

  bash /opt/app/start.sh
else
  echo "⚠️  No start.sh found in /opt/app"
fi

# Optionally start your Java app after unzipping
# java -jar /opt/app/yourapp.jar

exec "$@"
