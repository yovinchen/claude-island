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
ERROR_FILE="$(mktemp -t claude-island-pi-json.error.XXXXXX)"
STDERR_FILE="$(mktemp -t claude-island-pi-json.stderr.XXXXXX)"
STREAM_FILE="$(mktemp -t claude-island-pi-json.stream.XXXXXX)"

cleanup() {
  rm -f "$LAST_FILE" "$ERROR_FILE" "$STDERR_FILE" "$STREAM_FILE"
}

trap cleanup EXIT

send_event "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON}"
send_event "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"prompt\":$PROMPT_JSON}"

PARSER='import json, pathlib, re, subprocess, sys
last_path = pathlib.Path(sys.argv[1])
error_path = pathlib.Path(sys.argv[2])
stream_path = pathlib.Path(sys.argv[3])
stderr_path = pathlib.Path(sys.argv[4])
bridge = sys.argv[5]
session_id = sys.argv[6]
cwd = sys.argv[7]
last_text = ""
result_error = ""
tool_calls = {}
seen_pre = set()
seen_post = set()
ansi_re = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")

def send(payload):
    if not bridge:
        return
    try:
        subprocess.run([bridge, "--source", "pi"], input=json.dumps(payload).encode(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    except Exception:
        pass

def stringify(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, dict):
                if item.get("type") == "text" and item.get("text"):
                    parts.append(item["text"])
                elif item.get("text"):
                    parts.append(item["text"])
                else:
                    parts.append(json.dumps(item, ensure_ascii=False))
            elif item is not None:
                parts.append(str(item))
        return "\\n".join(part for part in parts if part)
    if value is None:
        return ""
    return json.dumps(value, ensure_ascii=False)

def emit_tool_start(tool_id, name, tool_input):
    if not tool_id or tool_id in seen_pre:
        return
    seen_pre.add(tool_id)
    tool_calls[tool_id] = {"name": name, "input": tool_input}
    send({
        "hook_event_name": "PreToolUse",
        "session_id": session_id,
        "cwd": cwd,
        "tool_name": name,
        "tool_input": tool_input,
        "tool_use_id": tool_id,
    })

def emit_tool_end(tool_id, content, is_error=False):
    if not tool_id or tool_id in seen_post:
        return
    seen_post.add(tool_id)
    metadata = tool_calls.get(tool_id, {})
    text = stringify(content)
    send({
        "hook_event_name": "PostToolUseFailure" if is_error else "PostToolUse",
        "session_id": session_id,
        "cwd": cwd,
        "tool_name": metadata.get("name"),
        "tool_input": metadata.get("input"),
        "tool_use_id": tool_id,
        "tool_response": text,
        "error": text if is_error else None,
    })

def emit_tool_execution_event(obj):
    event_type = str(obj.get("type") or "")
    tool_id = obj.get("toolCallId") or obj.get("tool_use_id") or obj.get("toolUseId") or obj.get("id")
    tool_name = obj.get("toolName") or obj.get("tool_name") or obj.get("tool")
    tool_input = obj.get("args") or obj.get("input") or obj.get("arguments")
    if event_type == "tool_execution_start":
        emit_tool_start(tool_id, tool_name, tool_input)
        return
    if event_type in ("tool_execution_end", "tool_execution_update"):
        partial = obj.get("partialResult") if event_type == "tool_execution_update" else obj.get("result")
        emit_tool_end(tool_id, partial or obj.get("content") or obj.get("output"), bool(obj.get("isError") or obj.get("is_error")))

def record_error(value):
    global result_error
    if isinstance(value, str) and value.strip():
        result_error = value.strip()

def remember_text(value):
    global last_text
    if isinstance(value, str) and value.strip():
        last_text = value.strip()

def process_content_items(content):
    texts = []
    if not isinstance(content, list):
        return texts
    for item in content:
        if not isinstance(item, dict):
            if item is not None:
                texts.append(str(item))
            continue
        item_type = item.get("type")
        if item_type in ("tool_use", "tool-call", "tool_call", "toolCall"):
            emit_tool_start(
                item.get("id") or item.get("tool_use_id") or item.get("toolUseId"),
                item.get("name") or item.get("tool"),
                item.get("input") or item.get("arguments"),
            )
            continue
        if item_type in ("tool_result", "tool-response", "tool_response", "toolResult"):
            emit_tool_end(
                item.get("tool_use_id") or item.get("toolUseId") or item.get("id"),
                item.get("content") or item.get("output"),
                bool(item.get("is_error") or item.get("isError")),
            )
            continue
        if item.get("text"):
            texts.append(item["text"])
        elif item.get("content") is not None:
            text = stringify(item.get("content"))
            if text:
                texts.append(text)
    return texts

def process_message(message):
    if not isinstance(message, dict):
        return
    role = str(message.get("role") or "").lower()
    if str(message.get("stopReason") or "").lower() == "error":
        record_error(message.get("errorMessage"))
    if role in ("toolresult", "tool_result", "tool-result"):
        emit_tool_end(
            message.get("toolCallId") or message.get("tool_use_id") or message.get("toolUseId") or message.get("id"),
            message.get("content") or message.get("output"),
            bool(message.get("isError") or message.get("is_error")),
        )
        return

    if role == "assistant":
        remember_text(message.get("text"))
    texts = process_content_items(message.get("content"))
    if role == "assistant" and texts:
        remember_text("\\n".join(texts))

def process_line(raw):
    raw = ansi_re.sub("", raw).strip()
    if not raw:
        return
    try:
        obj = json.loads(raw)
    except Exception:
        return

    if not isinstance(obj, dict):
        return

    remember_text(obj.get("text"))
    remember_text(obj.get("content") if isinstance(obj.get("content"), str) else None)

    top_type = obj.get("type")
    if top_type == "auto_retry_start":
        result_error = ""
    elif top_type == "auto_retry_end":
        if obj.get("success") is False:
            record_error(obj.get("finalError") or obj.get("errorMessage"))
        elif obj.get("success") is True:
            result_error = ""
    if top_type in ("tool_use", "tool-call", "tool_call", "toolCall"):
        emit_tool_start(obj.get("id") or obj.get("tool_use_id") or obj.get("toolUseId"), obj.get("name") or obj.get("tool"), obj.get("input") or obj.get("arguments"))
    elif top_type in ("tool_result", "tool-response", "tool_response", "toolResult"):
        emit_tool_end(obj.get("tool_use_id") or obj.get("toolUseId") or obj.get("id"), obj.get("content") or obj.get("output"), bool(obj.get("is_error") or obj.get("isError")))
    elif top_type.startswith("tool_execution_"):
        emit_tool_execution_event(obj)
    if str(obj.get("stopReason") or "").lower() == "error":
        record_error(obj.get("errorMessage"))
    record_error(obj.get("errorMessage"))

    process_message(obj.get("message"))

    assistant_event = obj.get("assistantMessageEvent")
    if isinstance(assistant_event, dict):
        remember_text(assistant_event.get("delta"))
        process_message(assistant_event.get("partial"))
        process_message(assistant_event.get("message"))

    messages = obj.get("messages")
    if isinstance(messages, list):
        for message in messages:
            process_message(message)

    tool_results = obj.get("toolResults")
    if isinstance(tool_results, list):
        for tool_result in tool_results:
            if not isinstance(tool_result, dict):
                continue
            emit_tool_end(
                tool_result.get("toolCallId") or tool_result.get("tool_use_id") or tool_result.get("toolUseId") or tool_result.get("id"),
                tool_result.get("content") or tool_result.get("output"),
                bool(tool_result.get("isError") or tool_result.get("is_error")),
            )

for raw in stream_path.read_text().splitlines():
    process_line(raw)

for raw in stderr_path.read_text().splitlines():
    process_line(raw)

last_path.write_text(last_text)
error_path.write_text(result_error)'

"$PI_BIN" --mode json -p "$PROMPT" 2>"$STDERR_FILE" | tee "$STREAM_FILE"
STATUS=$?

BRIDGE_PATH=""
if [ -x "$BRIDGE" ]; then
  BRIDGE_PATH="$BRIDGE"
fi
python3 -c "$PARSER" "$LAST_FILE" "$ERROR_FILE" "$STREAM_FILE" "$STDERR_FILE" "$BRIDGE_PATH" "$SESSION_ID" "$PWD"

LAST_ASSISTANT_MESSAGE=""
if [ -f "$LAST_FILE" ]; then
  LAST_ASSISTANT_MESSAGE="$(cat "$LAST_FILE")"
fi

RESULT_ERROR=""
if [ -f "$ERROR_FILE" ]; then
  RESULT_ERROR="$(cat "$ERROR_FILE")"
fi

if [ $STATUS -eq 0 ] && [ -z "$RESULT_ERROR" ]; then
  if [ -n "$LAST_ASSISTANT_MESSAGE" ]; then
    LAST_JSON="$(escape_json "$LAST_ASSISTANT_MESSAGE")"
    send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"last_assistant_message\":$LAST_JSON}"
  else
    send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"message\":\"Pi json mode finished\"}"
  fi
elif [ -n "$RESULT_ERROR" ]; then
  notify_error "$RESULT_ERROR"
  send_event "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\",\"cwd\":$CWD_JSON,\"message\":\"Pi json mode reported an execution error\"}"
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
