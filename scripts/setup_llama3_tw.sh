#!/usr/bin/env bash
set -euo pipefail

MODEL_URL="https://huggingface.co/QuantFactory/Llama-3-Taiwan-8B-Instruct-GGUF/resolve/main/Llama-3-Taiwan-8B-Instruct.Q5_K_M.gguf"
MODEL_FILE="Llama-3-Taiwan-8B-Instruct.Q5_K_M.gguf"
CUSTOM_MODEL_NAME="llama-3-tw:8b"

echo "🇹🇼 開始建置 Llama-3-Taiwan-8B-Instruct Q5_K_M 開源繁中模型..."

# 如果檔案不存在才下載
if [[ ! -f "$MODEL_FILE" ]]; then
  echo "📥 正在從 HuggingFace 載入模型權重 (約 5.7 GB，根據網路環境可能需要十分鐘)..."
  curl -L -C - "$MODEL_URL" -o "$MODEL_FILE"
else
  echo "✅ 模型權重檔案已存在，跳過下載。"
fi

echo "⚙️ 正在產生 Ollama Modelfile..."
cat <<EOF > Modelfile.tw
FROM ./${MODEL_FILE}

# 設定模型參數
PARAMETER temperature 0.6
PARAMETER num_ctx 8192

# 預設繁中 System Prompt
SYSTEM """
你是一個由台灣開發者訓練的人工智慧助理，你的名字是 Llama 3 Taiwan。
請一律使用繁體中文（zh-TW）以及台灣在地的用語來回答使用者的問題。
"""
EOF

echo "🚀 正在將模型匯入 Ollama (命名為 $CUSTOM_MODEL_NAME)..."
ollama create "$CUSTOM_MODEL_NAME" -f Modelfile.tw

echo "🎉 完成！現在您可以透過指令： ollama run $CUSTOM_MODEL_NAME 呼叫它了！"
