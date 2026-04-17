#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.request


def read_input():
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def extract_last_assistant_text(transcript_path: str) -> str:
    if not transcript_path or not os.path.isfile(transcript_path):
        return ""
    last = ""
    try:
        with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                if entry.get("type") != "assistant":
                    continue
                msg = entry.get("message") or {}
                content = msg.get("content")
                if not isinstance(content, list):
                    continue
                texts = [
                    c.get("text", "")
                    for c in content
                    if isinstance(c, dict) and c.get("type") == "text"
                ]
                text = " ".join(t.strip() for t in texts if t and t.strip())
                if text:
                    last = text
    except Exception:
        return ""
    return last


def truncate(text: str, limit: int = 60) -> str:
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def cache_path_for(session_id: str) -> str:
    cache_dir = os.path.expanduser("~/.claude-monitor/last-messages")
    try:
        os.makedirs(cache_dir, exist_ok=True)
    except Exception:
        pass
    safe = "".join(c for c in session_id if c.isalnum() or c in "-_")
    return os.path.join(cache_dir, safe + ".txt") if safe else ""


def read_previous(cache_file: str) -> str:
    if not cache_file or not os.path.isfile(cache_file):
        return ""
    try:
        with open(cache_file, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except Exception:
        return ""


def write_previous(cache_file: str, text: str) -> None:
    if not cache_file or not text:
        return
    try:
        with open(cache_file, "w", encoding="utf-8") as f:
            f.write(text)
    except Exception:
        pass


def wait_for_new_message(transcript_path: str, previous: str) -> str:
    # Stop hook fires before the current assistant message is flushed to the
    # transcript (the flush happens after the hook returns). Snapshot what
    # the transcript currently ends with, then wait until the tail moves past
    # both that snapshot and whatever we stored from the previous turn.
    baseline = extract_last_assistant_text(transcript_path)
    for _ in range(150):  # ~30s total
        latest = extract_last_assistant_text(transcript_path)
        if latest and latest != baseline and latest != previous:
            return latest
        time.sleep(0.2)
    return baseline


def send_notification(cwd: str, message: str) -> None:
    payload = json.dumps({"cwd": cwd, "message": message}).encode("utf-8")
    req = urllib.request.Request(
        "http://localhost:9877/notify",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        urllib.request.urlopen(req, timeout=1).read()
    except Exception:
        pass


def do_work(data: dict) -> None:
    event = data.get("hook_event_name", "")
    cwd = data.get("cwd") or os.getcwd()
    session_id = data.get("session_id", "") or ""

    if event == "Notification":
        message = (data.get("message") or "").strip() or "done"
        send_notification(cwd, message)
        return

    cache_file = cache_path_for(session_id)
    previous = read_previous(cache_file)
    latest = wait_for_new_message(data.get("transcript_path", ""), previous)
    if latest:
        write_previous(cache_file, latest)
    message = truncate(latest) or "done"
    send_notification(cwd, message)


def main():
    data = read_input()

    # Return immediately so the hook doesn't block Claude. The transcript is
    # flushed after Stop hooks return, so polling has to happen in a detached
    # child process.
    try:
        pid = os.fork()
    except OSError:
        do_work(data)
        return

    if pid != 0:
        # Parent: reap the intermediate child right away so it doesn't zombie.
        try:
            os.waitpid(pid, 0)
        except OSError:
            pass
        return

    # First child: detach and fork again so the grandchild is reparented to
    # init and won't be reaped by Claude Code.
    try:
        os.setsid()
    except OSError:
        pass
    try:
        pid2 = os.fork()
    except OSError:
        pid2 = 0
    if pid2 != 0:
        os._exit(0)

    # Grandchild: close std fds so we don't keep the hook's pipes open.
    for fd in (0, 1, 2):
        try:
            os.close(fd)
        except OSError:
            pass
    try:
        devnull = os.open(os.devnull, os.O_RDWR)
        for fd in (0, 1, 2):
            try:
                os.dup2(devnull, fd)
            except OSError:
                pass
    except OSError:
        pass

    try:
        do_work(data)
    except Exception:
        pass
    os._exit(0)


if __name__ == "__main__":
    main()
