#!/usr/bin/env bash
# Installs pi-orchestrate agents globally and prints the thinking-level block.
set -euo pipefail
DEST="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/agents"
mkdir -p "$DEST"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
for f in scout.md smart-worker.md; do
  if [ -f "$DEST/$f" ]; then cp "$DEST/$f" "$DEST/$f.bak"; echo "backed up $DEST/$f -> $f.bak"; fi
  cp "$SRC/agents/$f" "$DEST/$f"; echo "installed $DEST/$f"
done
echo
echo "Add to settings.json modelThinkingLevels (or keep yours):"
python3 -c "import json; print(json.dumps({
  'opencode-go/glm-5.3-flash': 'low',
  'opencode-go/deepseek-v4-flash': 'low',
  'openai-codex/gpt-5.6-luna': 'high',
  'openai-codex/gpt-6-astra': 'low',
  'opencode-go/kimi-k3': 'medium'
}, indent=2))"
echo
echo "Copy orchestrate.json to your project's .harness/ for ranked retry policy."
