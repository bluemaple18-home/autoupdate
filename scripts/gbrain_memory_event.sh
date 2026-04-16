#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:-}"
SUMMARY="${2:-}"
DRY_RUN="${DRY_RUN:-0}"
# 棄用即時存檔，改寫入佇列
QUEUE_DIR="${HOME}/ai-brain/.state"
QUEUE_FILE="${QUEUE_DIR}/gbrain_memory_queue.txt"

function usage() {
  cat <<'EOF'
用法：
  gbrain_memory_event.sh <event> "<summary>"

說明：
  紀錄 Agent 或系統的成功與失敗事件。
  為了保護 Context Caching 並消除卡頓，此腳本不會即時觸發 ollama 模型，
  而是將事件推入佇列 (Queue)，留待晚上 DreamCycle 批次消化，或觸發
  Context Compressor 壓縮交接時一併總結。

支援事件：
  task_done        task.md 階段完成
  module_done      模組或功能完成
  bug_fixed        Bug 已定位並修復
  bug_blocked      同一問題連續嘗試未解，先存除錯摘要
  handoff          對話收尾或交接
  reusable_fact    跨專案可重用事實
EOF
}

if [[ -z "$EVENT" || -z "$SUMMARY" ]]; then
  usage
  exit 1
fi

case "$EVENT" in
  task_done|module_done|bug_fixed|bug_blocked|handoff|reusable_fact) ;;
  *)
    echo "[FAIL] 不支援的事件：$EVENT" >&2
    usage
    exit 1
    ;;
esac

timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
cwd="$(pwd)"
payload="[GBrain非同步存檔][$EVENT][$timestamp] $SUMMARY | cwd=$cwd"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY-RUN] $payload"
  exit 0
fi

mkdir -p "$QUEUE_DIR"
echo "$payload" >> "$QUEUE_FILE"

echo "[OK] 事件已進入背景記憶佇列：$EVENT。這不會造成操作延遲！"
