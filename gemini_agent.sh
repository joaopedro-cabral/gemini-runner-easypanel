cat > /opt/n8n-ai/gemini_agent.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export GEMINI_CLI_TRUST_WORKSPACE=true
export HOME=/home/gemini
cd /home/gemin

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

ERR_FILE="$(mktemp)"

if ! RAW_OUTPUT="$(gemini -p "$PROMPT" --output-format json "${MODEL_ARGS[@]}" 2>"$ERR_FILE")"; then
  ERR_CONTENT="$(cat "$ERR_FILE" || true)"
  rm -f "$ERR_FILE"

  printf '%s' "$ERR_CONTENT" | python3 -c '
import sys, json
err = sys.stdin.read()
print(json.dumps({
  "fallback_required": True,
  "error": "gemini_cli_failed",
  "stderr": err[-3000:]
}, ensure_ascii=False))
'
  exit 0
fi

rm -f "$ERR_FILE"

printf '%s' "$RAW_OUTPUT" | python3 -c '
import sys, json, re

raw = sys.stdin.read().strip()

def extract_json_object(text):
    text = text.strip()

    # Caso venha algum aviso antes/depois do JSON externo
    start = text.find("{")
    end = text.rfind("}")

    if start == -1 or end == -1 or end <= start:
        raise ValueError("no_json_object_found")

    return text[start:end+1]

try:
    clean_raw = extract_json_object(raw)
    wrapper = json.loads(clean_raw)
except Exception:
    print(json.dumps({
        "fallback_required": True,
        "error": "invalid_gemini_wrapper",
        "raw": raw[-3000:]
    }, ensure_ascii=False))
    sys.exit(0)

response = wrapper.get("response", "")

# Algumas versões podem devolver response como objeto, não string
if isinstance(response, dict):
    print(json.dumps(response, ensure_ascii=False))
    sys.exit(0)

if not isinstance(response, str):
    print(json.dumps({
        "fallback_required": True,
        "error": "empty_or_invalid_response",
        "wrapper": wrapper
    }, ensure_ascii=False))
    sys.exit(0)

response = response.strip()

# Remove markdown fences, caso o modelo responda com ```json
response = re.sub(r"^```(?:json)?", "", response).strip()
response = re.sub(r"```$", "", response).strip()

# Caso venha texto antes/depois do JSON de resposta
try:
    inner = extract_json_object(response)
    parsed = json.loads(inner)
    print(json.dumps(parsed, ensure_ascii=False))
except Exception:
    print(json.dumps({
        "fallback_required": True,
        "error": "invalid_json_response",
        "raw_response": response[-3000:]
    }, ensure_ascii=False))
'
EOF

chmod +x /opt/n8n-ai/gemini_agent.sh
