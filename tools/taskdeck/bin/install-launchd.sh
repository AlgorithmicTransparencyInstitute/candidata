#!/bin/bash
# Run the Taskdeck hub at login on macOS (and restart it if it crashes).
#
#   bin/install-launchd.sh                         # localhost only
#   HOST=0.0.0.0 TASKDECK_TOKEN=secret bin/install-launchd.sh   # serve your other Macs
#   bin/install-launchd.sh --uninstall
set -euo pipefail

LABEL="com.taskdeck.hub"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node)"
LOGDIR="$HOME/.taskdeck"

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed $LABEL"
  exit 0
fi

mkdir -p "$LOGDIR" "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$NODE</string><string>$ROOT/server.js</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOST</key><string>${HOST:-127.0.0.1}</string>
    <key>PORT</key><string>${PORT:-4777}</string>
    <key>TASKDECK_TOKEN</key><string>${TASKDECK_TOKEN:-}</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOGDIR/hub.log</string>
  <key>StandardErrorPath</key><string>$LOGDIR/hub.log</string>
</dict>
</plist>
EOF
chmod 600 "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Taskdeck hub running at http://${HOST:-127.0.0.1}:${PORT:-4777} (logs: $LOGDIR/hub.log)"
