#!/bin/bash
#
# Claude Code hook script - sends notification to ClaudeMonitor
# Usage: Add to ~/.claude/settings.json hooks
#

CWD="$(pwd)"
PROJECT="$(basename "$CWD")"

curl -s -X POST http://localhost:9877/notify \
  -H "Content-Type: application/json" \
  -d "{\"cwd\":\"$CWD\",\"message\":\"$PROJECT: done\"}" \
  > /dev/null 2>&1 &
