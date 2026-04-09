#!/bin/zsh

set -o pipefail

QODERCLI_BIN=""
BRIDGE="$HOME/.claude-island/bin/claude-island-bridge-launcher.sh"

if command -v uuidgen >/dev/null 2>&1; then
  SESSION_ID="qodercli-json-$(uuidgen)"
else
  SESSION_ID="qodercli-json-$(date +%s)-$$"
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
    print -rn -- "$payload" | "$BRIDGE" --source qoder_cli >/dev/null 2>&1 || true
  fi
}

notify_error() {
  local message="$1"
  local cwd_json msg_json
  cwd_json="$(escape_json "$PWD")"
  msg_json="$(escape_json "$message")"
  send_event "{\"hook_event_name\":\"Notification\",\"session_id\":\"$SESSION_ID\",\"cwd\":$cwd_json,\"message\":$msg_json,\"notification_type\":\"error\"}"
}

for CANDIDATE in "$HOME/.local/bin/qodercli" "/opt/homebrew/bin/qodercli" "/usr/local/bin/qodercli" "qodercli"; do
  if [ "$CANDIDATE" = "qodercli" ]; then
    if command -v qodercli >/dev/null 2>&1; then
      QODERCLI_BIN="$(command -v qodercli)"
      break
    fi
  elif [ -x "$CANDIDATE" ]; then
    QODERCLI_BIN="$CANDIDATE"
    break
  fi
done

if [ -z "$QODERCLI_BIN" ]; then
  notify_error "Qoder CLI not found for claude-island-qodercli-json"
  echo "claude-island-qodercli-json: qodercli not found" >&2
  exit 127
fi

if [ "$#" -gt 0 ]; then
  PROMPT="$*"
else
  PROMPT="$(cat)"
fi

if [ -z "$PROMPT" ]; then
  notify_error "Prompt required for claude-island-qodercli-json"
  echo "claude-island-qodercli-json: prompt required" >&2
  exit 1
fi

PROMPT_JSON="$(escape_json "$PROMPT")"
CWD_JSON="$(escape_json "$PWD")"
LAST_FILE="$(mktemp -t claude-island-qodercli.last.XXXXXX)"
ERROR_FILE="$(mktemp -t claude-island-qodercli.error.XXXXXX)"
COUNT_FILE="$(mktemp -t claude-island-qodercli.count.XXXXXX)"
CLEAN_STREAM_FILE="$(mktemp -t claude-island-qodercli.clean.XXXXXX)"
STDERR_FILE="$(mktemp -t claude-island-qodercli.stderr.XXXXXX)"
STREAM_FILE="$(mktemp -t claude-island-qodercli.stream.XXXXXX)"

cleanup() {
  rm -f "$LAST_FILE" "$ERROR_FILE" "$COUNT_FILE" "$CLEAN_STREAM_FILE" "$STDERR_FILE" "$STREAM_FILE"
}
trap cleanup EXIT

send_event "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON}"
send_event "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"prompt\":$PROMPT_JSON}"

PARSER='import json, pathlib, sys
last_path = pathlib.Path(sys.argv[1])
error_path = pathlib.Path(sys.argv[2])
count_path = pathlib.Path(sys.argv[3])
clean_path = pathlib.Path(sys.argv[4])
stream_path = pathlib.Path(sys.argv[5])
last_text = ""
result_error = ""
json_line_count = 0
clean_lines = []

def remember_text(value):
    global last_text
    if isinstance(value, str) and value.strip():
        last_text = value.strip()

def remember_error(value):
    global result_error
    if isinstance(value, str) and value.strip():
        result_error = value.strip()

for raw in stream_path.read_text(errors="ignore").splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except Exception:
        continue

    if not isinstance(obj, dict):
        continue

    json_line_count += 1
    clean_lines.append(raw)
    kind = obj.get("type")
    subtype = obj.get("subtype")

    if kind == "error":
        code = obj.get("error_code")
        error_obj = obj.get("error")
        if isinstance(error_obj, dict):
            remember_error(error_obj.get("message"))
        remember_error(obj.get("message"))
        remember_error(obj.get("result"))
        if not result_error:
            remember_error(f"Qoder CLI {subtype or 'error'} ({code})" if code is not None else f"Qoder CLI {subtype or 'error'}")
        continue

    remember_text(obj.get("message"))
    remember_text(obj.get("text"))
    remember_text(obj.get("result"))
    data = obj.get("data")
    if isinstance(data, dict):
        remember_text(data.get("message"))
        remember_text(data.get("text"))
        remember_text(data.get("content"))

count_path.write_text(str(json_line_count))
clean_path.write_text("\\n".join(clean_lines))
last_path.write_text(last_text)
error_path.write_text(result_error)'

"$QODERCLI_BIN" -p "$PROMPT" -f stream-json -q >"$STREAM_FILE" 2>"$STDERR_FILE"
STATUS=$?

python3 -c "$PARSER" "$LAST_FILE" "$ERROR_FILE" "$COUNT_FILE" "$CLEAN_STREAM_FILE" "$STREAM_FILE"

LAST_ASSISTANT_MESSAGE=""
if [ -f "$LAST_FILE" ]; then
  LAST_ASSISTANT_MESSAGE="$(cat "$LAST_FILE")"
fi

RESULT_ERROR=""
if [ -f "$ERROR_FILE" ]; then
  RESULT_ERROR="$(cat "$ERROR_FILE")"
fi

JSON_LINE_COUNT=0
if [ -f "$COUNT_FILE" ]; then
  JSON_LINE_COUNT="$(cat "$COUNT_FILE")"
fi

SANITIZED_STDERR="$(python3 - <<'PY' "$STDERR_FILE"
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text(errors="ignore") if path.exists() else ""
lines = []
for line in text.splitlines():
    stripped = line.strip()
    if not stripped:
        continue
    if "write error: can't rename log file:" in stripped:
        continue
    lines.append(stripped)
print("\n".join(lines), end="")
PY
)"

if [ $STATUS -eq 0 ] && [ -z "$RESULT_ERROR" ]; then
  if [ -n "$LAST_ASSISTANT_MESSAGE" ]; then
    LAST_JSON="$(escape_json "$LAST_ASSISTANT_MESSAGE")"
    send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"last_assistant_message\":$LAST_JSON}"
  else
    send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"message\":\"Qoder CLI json mode finished\"}"
  fi
else
  if [ -n "$RESULT_ERROR" ]; then
    notify_error "$RESULT_ERROR"
    print -r -- "$RESULT_ERROR" >&2
  else
    notify_error "Qoder CLI json mode failed with exit code $STATUS"
    print -r -- "Qoder CLI json mode failed with exit code $STATUS" >&2
  fi
  send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"message\":\"Qoder CLI json mode failed\"}"
fi

if [ "${JSON_LINE_COUNT:-0}" -gt 0 ] && [ -s "$CLEAN_STREAM_FILE" ]; then
  cat "$CLEAN_STREAM_FILE"
fi

if [ -n "$SANITIZED_STDERR" ]; then
  print -r -- "$SANITIZED_STDERR" >&2
fi

exit $STATUS
