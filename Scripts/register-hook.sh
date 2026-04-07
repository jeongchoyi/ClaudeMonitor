#!/bin/bash
CWD="$(pwd)"
NAME="$(basename "$CWD")"
curl -s -X POST http://localhost:9877/register \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NAME\",\"cwd\":\"$CWD\",\"isAuto\":true}" \
  > /dev/null 2>&1
