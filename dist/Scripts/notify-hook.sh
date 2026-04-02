#!/bin/bash
#
# Claude Code hook script - sends notification to ClaudeMonitor
# Skips notification if terminal app is currently focused
#

FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
if [ "$FRONT_APP" = "iTerm2" ] || [ "$FRONT_APP" = "Terminal" ]; then
    exit 0
fi

CWD="$(pwd)"
PROJECT="$(basename "$CWD")"

curl -s -X POST http://localhost:9877/notify \
  -H "Content-Type: application/json" \
  -d "{\"cwd\":\"$CWD\",\"message\":\"$PROJECT: done\"}" \
  > /dev/null 2>&1 &
