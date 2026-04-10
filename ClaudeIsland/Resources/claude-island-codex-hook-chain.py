#!/usr/bin/python3
import json
import os
import re
import subprocess
import sys
from pathlib import Path


HOME = Path.home()
CHAIN_PATH = Path(
    os.environ.get(
        "CLAUDE_ISLAND_CODEX_HOOK_CHAIN",
        HOME / ".codex/claude-island/hook-chain.json",
    )
)
BRIDGE_PATH = os.environ.get(
    "CLAUDE_ISLAND_CODEX_BRIDGE",
    str(HOME / ".claude-island/bin/claude-island-bridge-launcher.sh"),
)


def load_payload(raw):
    try:
        return json.loads(raw)
    except Exception:
        return None


def event_name(payload):
    if not isinstance(payload, dict):
        return None
    for key in ("hook_event_name", "hookEventName", "event", "type"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    return None


def command_items(entry):
    hooks = entry.get("hooks")
    if isinstance(hooks, list):
        return [item for item in hooks if isinstance(item, dict)]
    if isinstance(entry, dict):
        return [entry]
    return []


def extract_match_target(payload, hook_event):
    if not isinstance(payload, dict):
        return None

    if hook_event in ("PreToolUse", "PostToolUse"):
        for key in ("tool_name", "toolName"):
            value = payload.get(key)
            if isinstance(value, str) and value:
                return value
        tool = payload.get("tool")
        if isinstance(tool, dict):
            for key in ("name", "tool_name", "toolName"):
                value = tool.get(key)
                if isinstance(value, str) and value:
                    return value

    if hook_event == "SessionStart":
        for key in (
            "start_source",
            "startSource",
            "session_start_source",
            "sessionStartSource",
            "trigger",
            "reason",
            "source",
        ):
            value = payload.get(key)
            if isinstance(value, str) and value:
                return value

    return None


def entry_matches(entry, payload, hook_event):
    matcher = entry.get("matcher")
    if matcher in (None, "", "*"):
        return True
    if not isinstance(matcher, str):
        return False

    target = extract_match_target(payload, hook_event)
    if not target:
        return False

    try:
        return re.search(matcher, target) is not None
    except re.error:
        return False


def run_hook_command(raw, payload, item):
    command = item.get("command") or item.get("bash")
    if not isinstance(command, str) or not command:
        return {
            "stdout": "",
            "stderr": "",
            "returncode": 0,
        }

    env = os.environ.copy()
    extra_env = item.get("env")
    if isinstance(extra_env, dict):
        for key, value in extra_env.items():
            if isinstance(key, str) and isinstance(value, str):
                env[key] = value

    cwd = payload.get("cwd") if isinstance(payload, dict) else None
    if not isinstance(cwd, str) or not cwd:
        cwd = None

    timeout = item.get("timeout")
    if timeout is None:
        timeout = item.get("timeoutSec")
    if not isinstance(timeout, (int, float)) or timeout <= 0:
        timeout = None

    try:
        completed = subprocess.run(
            command,
            input=raw,
            text=True,
            capture_output=True,
            shell=True,
            cwd=cwd,
            env=env,
            timeout=timeout,
            check=False,
        )
        return {
            "stdout": completed.stdout or "",
            "stderr": completed.stderr or "",
            "returncode": int(completed.returncode),
        }
    except subprocess.TimeoutExpired:
        return {
            "stdout": "",
            "stderr": "",
            "returncode": 0,
        }
    except Exception:
        return {
            "stdout": "",
            "stderr": "",
            "returncode": 0,
        }


def parse_json_output(text):
    if not text:
        return None
    try:
        value = json.loads(text)
        return value if isinstance(value, dict) else None
    except Exception:
        return None


def is_blocking_response(text, returncode):
    if returncode == 2:
        return True

    payload = parse_json_output(text)
    if not payload:
        return False

    if payload.get("continue") is False:
        return True

    if payload.get("decision") == "block":
        return True

    hook_specific = payload.get("hookSpecificOutput")
    if isinstance(hook_specific, dict):
        if hook_specific.get("permissionDecision") == "deny":
            return True
        if hook_specific.get("decision") == "block":
            return True
        decision = hook_specific.get("decision")
        if isinstance(decision, dict) and decision.get("behavior") == "deny":
            return True

    if payload.get("permissionDecision") == "deny":
        return True

    return False


def choose_response(results):
    chosen = {
        "stdout": "",
        "stderr": "",
        "returncode": 0,
    }

    for result in results:
        if is_blocking_response(result["stdout"], result["returncode"]):
            return result

        if chosen["returncode"] == 0 and result["returncode"] == 2:
            chosen = result
            continue

        if not chosen["stdout"] and result["stdout"]:
            chosen = result

    return chosen


def load_chain_entries(hook_event):
    if not CHAIN_PATH.exists():
        return []

    try:
        data = json.loads(CHAIN_PATH.read_text(encoding="utf-8"))
    except Exception:
        return []

    entries = data.get(hook_event)
    if isinstance(entries, list):
        return [entry for entry in entries if isinstance(entry, dict)]
    return []


def main():
    raw = sys.stdin.read()
    if not raw:
        return 0

    payload = load_payload(raw)
    hook_event = event_name(payload)

    results = []
    bridge_result = run_hook_command(
        raw,
        payload or {},
        {"command": f'"{BRIDGE_PATH}" --source codex'},
    )
    results.append(bridge_result)

    if hook_event:
        for entry in load_chain_entries(hook_event):
            if not entry_matches(entry, payload, hook_event):
                continue
            for item in command_items(entry):
                results.append(run_hook_command(raw, payload or {}, item))

    chosen = choose_response(results)

    if chosen["stdout"]:
        sys.stdout.write(chosen["stdout"])
    if chosen["stderr"]:
        sys.stderr.write(chosen["stderr"])

    return chosen["returncode"]


if __name__ == "__main__":
    sys.exit(main())
