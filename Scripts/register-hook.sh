#!/bin/bash
CWD="$(pwd)"
NAME="$(basename "$CWD")"
TTY="$("$(dirname "$0")/claude-tty.sh")"
curl -s -X POST http://localhost:9877/register \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NAME\",\"cwd\":\"$CWD\",\"tty\":\"$TTY\",\"isAuto\":true}" \
  > /dev/null 2>&1
