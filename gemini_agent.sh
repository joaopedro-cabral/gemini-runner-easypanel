#!/usr/bin/env bash
set -euo pipefail

TASK="${1:-generic}"
PAYLOAD="$(cat)"

PROMPT="$(printf '%s' "$PAYLOAD" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    prompt = data.get("ai_prompt") or data.get("prompt") or ""
    print(prompt)
except Exception:
    print("")
')"

if [ -z "$PROMPT" ]; then
  printf '{"fallback_required":true,"error":"missing_ai_prompt","task":"%s"}\n' "$TASK"
  exit 0
fi

MODEL_ARGS=()
if [ -n "${GEMINI_MODEL:-}" ]; then
  MODEL_ARGS=(--model "$GEMINI_MODEL")
fi

RAW_OUTPUT="$(gemini -p "$PROMPT" --output-format json "${MODEL_ARGS[@]}" 2>&1)" || {
  printf '%s' "$RAW_OUTPUT" | python3 -c '
import sys, json
err = sys.stdin.read()
print(json.dumps({
  "fallback_required": True,
  "error": "gemini_cli_failed",
  "stderr": err[-2000:]
}, ensure_ascii=False))
'
  exit 0
}

printf '%s' "$RAW_OUTPUT" | python3 -c '
import sys, json, re

raw = sys.stdin.read()

try:
    wrapper = json.loads(raw)
    response = wrapper.get("response", "")
except Exception:
    print(json.dumps({
        "fallback_required": True,
        "error": "invalid_gemini_wrapper",
        "raw": raw[-2000:]
    }, ensure_ascii=False))
    sys.exit(0)

response = response.strip()
response = re.sub(r"^```(?:json)?", "", response).strip()
response = re.sub(r"```$", "", response).strip()

try:
    parsed = json.loads(response)
    print(json.dumps(parsed, ensure_ascii=False))
except Exception:
    print(json.dumps({
        "fallback_required": True,
        "error": "invalid_json_response",
        "raw_response": response[-2000:]
    }, ensure_ascii=False))
'
