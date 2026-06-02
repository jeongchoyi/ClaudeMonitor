#!/bin/bash
#
#  claude-tty.sh
#  ClaudeMonitor
#
#  Created by Choyi on 2026/06/02.
#
# Prints the controlling tty (e.g. "ttys036") of the nearest `claude` ancestor
# process. Hook/tool subprocesses don't have a controlling tty of their own
# (stdin is a pipe), but the claude process that spawned them does — and that
# tty matches iTerm2's `tty of session`, giving a unique key per terminal pane.
# Prints an empty string if no claude ancestor is found.

pid=$$
for _ in $(seq 1 12); do
  comm=$(ps -o comm= -p "$pid" 2>/dev/null)
  case "$comm" in
    *claude*)
      t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
      [ "$t" = "??" ] && t=""
      printf '%s' "${t#/dev/}"
      exit 0
      ;;
  esac
  ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -z "$ppid" ] || [ "$ppid" = "0" ] || [ "$ppid" = "1" ]; then
    break
  fi
  pid=$ppid
done
printf ''
