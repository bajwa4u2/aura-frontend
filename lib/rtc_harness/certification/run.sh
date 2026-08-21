#!/usr/bin/env bash
# run.sh <build-dir> <report-name>
set -u
SP="/c/Users/muham/AppData/Local/Temp/claude/C--Users-muham-flutter-projects/8acb898a-c911-45dd-b6e8-59e6c40e2623/scratchpad"
BUILD="$1"; NAME="$2"
for pid in $(wmic process where "name='chrome.exe'" get ProcessId,CommandLine /format:csv 2>/dev/null | grep -i "harness-profile" | awk -F, '{print $NF}' | tr -d '\r'); do taskkill //F //PID $pid > /dev/null 2>&1; done
for pid in $(netstat -ano | grep ":8899 " | awk '{print $5}' | sort -u); do taskkill //F //PID $pid > /dev/null 2>&1; done
sleep 2
PROF="$SP/harness-profile-$(date +%s)"
nohup python "$SP/serve.py" "$BUILD" 8899 "$SP/$NAME.json" > "$SP/serve_$NAME.log" 2>&1 &
sleep 2
nohup "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --user-data-dir="$(cygpath -w "$PROF")" --no-first-run --no-default-browser-check \
  --disable-extensions --disable-background-networking --disable-sync \
  --use-fake-ui-for-media-stream --use-fake-device-for-media-stream \
  --autoplay-policy=no-user-gesture-required \
  "http://127.0.0.1:8899/index.html" > "$SP/chrome_$NAME.log" 2>&1 &
echo "started $NAME on $BUILD (profile $PROF)"
