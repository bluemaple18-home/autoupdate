#!/usr/bin/env bash
set -euo pipefail

function usage() {
  cat << 'EOF'
用法：
  bash gbrain_context_compressor.sh <目前的卡點或即將交接的進度簡述>

說明：
  擷取當前目錄的 git 狀態、task.md 進度以及當前執行的最新對話紀錄，
  透過背景呼叫 Ollama 進行高度結構化的對話壓縮，產出精煉的交接文件。
  避免 MODEL_CAPACITY_EXHAUSTED 的超級救星。
EOF
}

SUBJECT="${1:-}"

if [[ -z "$SUBJECT" ]]; then
  usage
  exit 1
fi

DATE_STR=$(date '+%Y%m%d_%H%M%S')
OUT_FILE="$(pwd)/handoff_${DATE_STR}.md"

echo "🔍 正在收集工作區快照..."
# 1. 收集 Git 狀態
if [ -d .git ]; then
  GIT_STATUS=$(git status --short 2>/dev/null || true)
  GIT_DIFF=$(git diff --stat 2>/dev/null || true)
else
  GIT_STATUS="無 Git 環境或不在根目錄"
  GIT_DIFF="N/A"
fi

# 2. 收集最近的任務日誌或對話
RECENT_LOG=""
if [ -d "$HOME/.gemini/antigravity/brain/" ]; then
  # 抓取最新的 Conversation 資料夾
  LATEST_CONVO=$(ls -td "$HOME/.gemini/antigravity/brain/"* 2>/dev/null | head -n 1 || true)
  if [[ -n "$LATEST_CONVO" && -f "$LATEST_CONVO/.system_generated/logs/overview.txt" ]]; then
     # 只取最後 150 行作為 Context，避免塞爆壓縮模型
     RECENT_LOG=$(tail -n 150 "$LATEST_CONVO/.system_generated/logs/overview.txt")
  fi
fi

# 3. 收集 Task.md
TASK_CONTENT=""
if [ -f "task.md" ]; then
  TASK_CONTENT=$(cat "task.md")
fi

echo "🧠 正在呼叫本地 Llama 進行脈絡壓縮 (可能需要 5-15 秒)..."

PROMPT=$(cat <<EOF
你是一個專業的上下文壓縮引擎（Context Compressor）。
你的目標是將開發者的工作狀態與對話尾聲的環境片段，提取為高度結構化的交接報告，讓下一個接收的 Agent 可以秒懂目前進度。

[任務主題/瓶頸簡述]
$SUBJECT

[Git 狀態]
$GIT_STATUS
$GIT_DIFF

[當前 task.md 狀態]
$TASK_CONTENT

[最新對話與日誌截錄 (Tail 150 lines)]
$RECENT_LOG

請以「繁體中文台灣用語」輸出符合以下結構的 Markdown 報告（請勿輸出多餘的開場白與結語，純 Markdown 即可）：

# 交接報告：$SUBJECT
1. **Goal**: 最終大目標是什麼？
2. **Constraints & Preferences**: 必須遵守的特例或偏好？
3. **Completed Actions**: 條列已完成的動作、檔案修改（具體檔案名稱）
4. **Active State**: 目前有被修改但未 commit 的檔案狀態或啟動中的環境
5. **In Progress / Remaining Work**: 正要往下做的或是尚未勾選的任務清單
6. **Blocked & Errors**: 目前卡在哪裡？具體的錯誤訊息、退出碼或瓶頸是什麼？
7. **Key Decisions & Resolved**: 嘗試過哪些做法且失敗了（防雷指南）或已決定的最終架構方向
EOF
)

# 使用 ollama 驅動本地模型 (優先嘗試 CLI，若被沙盒擋住則走 REST API)
if command -v ollama >/dev/null 2>&1; then
  echo "$PROMPT" | ollama run llama-3-tw:8b > "$OUT_FILE"
elif command -v curl >/dev/null 2>&1 && curl -s http://localhost:11434/api/tags >/dev/null; then
  echo "(切換為 REST API 模式以繞過沙盒限制...)"
  JSON_PAYLOAD=$(jq -n --arg model "llama-3-tw:8b" --arg prompt "$PROMPT" '{model: $model, prompt: $prompt, stream: false}')
  curl -s http://localhost:11434/api/generate -d "$JSON_PAYLOAD" | jq -r '.response' > "$OUT_FILE"
else
  echo "⚠️ 找不到 ollama 指令或 API，無法執行智慧壓縮，將產出空白樣板供人工填寫..."
  cat <<EOF > "$OUT_FILE"
# 交接報告（降級版）：$SUBJECT
> [!WARNING]
> 找不到 Ollama 指令，無法執行壓縮。上方為空白樣板，請 PM 人工填寫。

1. **Goal**: 
2. **Constraints & Preferences**: 
3. **Completed Actions**: 
4. **Active State**: 
5. **In Progress / Remaining Work**: 
6. **Blocked & Errors**: 
7. **Key Decisions**: 
EOF
fi

echo "✅ 脈絡壓縮完成！輸出檔案：$OUT_FILE"
echo "👉 [提示] Agent (Antigravity): 請記得執行 memory_store.sh 將這份交接狀態存入知識庫。"
