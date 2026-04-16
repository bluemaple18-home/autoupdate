#!/usr/bin/env bash
set -euo pipefail

TASK_FILE="${1:-task.md}"
STATE_ROOT="${STATE_ROOT:-/Users/matt/ai-brain/.state}"
MEM_EVENT_BIN="${MEM_EVENT_BIN:-/Users/matt/ai-brain/scripts/gbrain_memory_event.sh}"
DRY_RUN="${DRY_RUN:-0}"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[SKIP] 找不到 $TASK_FILE"
  exit 0
fi

mkdir -p "$STATE_ROOT"
project_key="$(pwd | shasum | awk '{print $1}')"
state_file="$STATE_ROOT/task_done_${project_key}.txt"
touch "$state_file"

new_count=0

while IFS= read -r line; do
  case "$line" in
    *"[x]"*|*"[X]"*)
      line_key="$(printf '%s' "$line" | shasum | awk '{print $1}')"
      if ! grep -q "^$line_key$" "$state_file"; then
        if [[ "$DRY_RUN" == "1" ]]; then
          echo "[DRY-RUN] 新里程碑：$line"
        else
          "$MEM_EVENT_BIN" "task_done" "task.md 完成：$line"
        fi
        echo "$line_key" >> "$state_file"
        new_count=$((new_count + 1))
      fi
      ;;
  esac
done < "$TASK_FILE"

if [[ "$new_count" -eq 0 ]]; then
  echo "[SKIP] 沒有新的 [x] 里程碑"
else
  echo "[OK] 已處理 $new_count 筆新的 [x] 里程碑"
fi
