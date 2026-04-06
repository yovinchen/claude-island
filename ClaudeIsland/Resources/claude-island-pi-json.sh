#!/bin/zsh

set -o pipefail

PI_BIN=""
BRIDGE="$HOME/.claude-island/bin/claude-island-bridge-launcher.sh"

if command -v uuidgen >/dev/null 2>&1; then
  SESSION_ID="pi-json-$(uuidgen)"
else
  SESSION_ID="pi-json-$(date +%s)-$$"
fi

escape_json() {
  python3 - <<'PY' "$1"
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

send_event() {
  local payload="$1"
  if [ -x "$BRIDGE" ]; then
    print -rn -- "$payload" | "$BRIDGE" --source pi >/dev/null 2>&1 || true
  fi
}

notify_error() {
  local message="$1"
  local cwd_json
  local msg_json
  cwd_json="$(escape_json "$PWD")"
  msg_json="$(escape_json "$message")"
  send_event "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":$cwd_json,\"message\":$msg_json,\"notification_type\":\"error\"}"
}

for CANDIDATE in "$HOME/.local/bin/pi" "/opt/homebrew/bin/pi" "/usr/local/bin/pi" "pi"; do
  if [ "$CANDIDATE" = "pi" ]; then
    if command -v pi >/dev/null 2>&1; then
      PI_BIN="$(command -v pi)"
      break
    fi
  elif [ -x "$CANDIDATE" ]; then
    PI_BIN="$CANDIDATE"
    break
  fi
done

if [ -z "$PI_BIN" ]; then
  notify_error "Pi Coding Agent not found for claude-island-pi-json"
  echo "claude-island-pi-json: Pi Coding Agent not found" >&2
  exit 127
fi

if [ "$#" -gt 0 ]; then
  PROMPT="$*"
else
  PROMPT="$(cat)"
fi

if [ -z "$PROMPT" ]; then
  notify_error "Prompt required for claude-island-pi-json"
  echo "claude-island-pi-json: prompt required" >&2
  exit 1
fi

PROMPT_JSON="$(escape_json "$PROMPT")"
CWD_JSON="$(escape_json "$PWD")"
LAST_FILE="$(mktemp -t claude-island-pi-json.last.XXXXXX)"
STDERR_FILE="$(mktemp -t claude-island-pi-json.stderr.XXXXXX)"

cleanup() {
  rm -f "$LAST_FILE" "$STDERR_FILE"
}

trap cleanup EXIT

send_event "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON}"
send_event "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"prompt\":$PROMPT_JSON}"

PARSER='import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
last_text = ""
for raw in sys.stdin:
    sys.stdout.write(raw)
    sys.stdout.flush()
    raw = raw.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except Exception:
        continue
    candidates = []
    if isinstance(obj, dict):
        candidates.extend([
            obj.get("text"),
            obj.get("message"),
            obj.get("content"),
        ])
        message = obj.get("message")
        if isinstance(message, dict):
            candidates.extend([message.get("text"), message.get("content")])
        content = obj.get("content")
        if isinstance(content, list):
            texts = []
            for item in content:
                if isinstance(item, dict):
                    if item.get("type") == "text" and item.get("text"):
                        texts.append(item["text"])
                    elif item.get("text"):
                        texts.append(item["text"])
            if texts:
                candidates.append("\\n".join(texts))
    for value in candidates:
        if isinstance(value, str) and value.strip():
            last_text = value.strip()
path.write_text(last_text)'

"$PI_BIN" --mode json -p "$PROMPT" 2>"$STDERR_FILE" | python3 -c "$PARSER" "$LAST_FILE"
STATUS=$?

LAST_ASSISTANT_MESSAGE=""
if [ -f "$LAST_FILE" ]; then
  LAST_ASSISTANT_MESSAGE="$(cat "$LAST_FILE")"
fi

if [ $STATUS -eq 0 ]; then
  if [ -n "$LAST_ASSISTANT_MESSAGE" ]; then
    LAST_JSON="$(escape_json "$LAST_ASSISTANT_MESSAGE")"
    send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"last_assistant_message\":$LAST_JSON}"
  else
    send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"message\":\"Pi json mode finished\"}"
  fi
else
  ERROR_OUTPUT="$(cat "$STDERR_FILE")"
  if [ -n "$ERROR_OUTPUT" ]; then
    notify_error "$ERROR_OUTPUT"
  else
    notify_error "Pi json mode failed with exit code $STATUS"
  fi
  send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"message\":\"Pi json mode failed\"}"
fi

if [ -s "$STDERR_FILE" ]; then
  cat "$STDERR_FILE" >&2
fi

exit $STATUS
