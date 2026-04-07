#!/bin/bash
CWD="$(pwd)"
PROJECT="$(basename "$CWD")"
curl -s -X POST http://localhost:9877/notify \
  -H "Content-Type: application/json" \
  -d "{\"cwd\":\"$CWD\",\"message\":\"$PROJECT: done\"}" \
  > /dev/null 2>&1
