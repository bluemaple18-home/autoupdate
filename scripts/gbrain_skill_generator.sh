#!/usr/bin/env bash
set -euo pipefail

function usage() {
  cat << 'EOF'
用法：
  bash gbrain_skill_generator.sh <skill-name> "<description>" <body_file_path> [--force]

說明：
  提供給 AI 代理人使用的自動化技能產生器，確保技能檔 (SKILL.md) 寫入正確的
  全域目錄 (~/ai-core/skills) 並加上標準的 YAML Frontmatter，最後觸發全域同步。

參數：
  <skill-name>       短破折號命名的目錄名稱 (例如: react-linter)
  <description>      技能的簡短描述 (YAML 內使用)
  <body_file_path>   存放技能主體 (Markdown) 的暫存檔案絕對路徑
  --force            (可選) 若技能已存在則強制覆寫
EOF
}

SKILL_NAME="${1:-}"
DESCRIPTION="${2:-}"
BODY_FILE="${3:-}"
FORCE="${4:-}"

if [[ -z "$SKILL_NAME" || -z "$DESCRIPTION" || -z "$BODY_FILE" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$BODY_FILE" ]]; then
  echo "[FATAL] 找不到技能主體檔案 $BODY_FILE" >&2
  exit 1
fi

# 在跨工具共用資料夾建立技能
DEST_DIR="$HOME/ai-core/skills/$SKILL_NAME"
DEST_FILE="$DEST_DIR/SKILL.md"

if [[ -d "$DEST_DIR" && "$FORCE" != "--force" ]]; then
  echo "[FATAL] 技能目錄 $DEST_DIR 已存在。若要覆寫請加上 --force 參數。" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

# 第一步：寫入 YAML Frontmatter
cat <<EOF > "$DEST_FILE"
---
name: $SKILL_NAME
description: $DESCRIPTION
platforms: [macos, linux, windows]
---

EOF

# 第二步：疊加真正的 Markdown 主體
cat "$BODY_FILE" >> "$DEST_FILE"

echo "[OK] 成功產生標準技能檔: $DEST_FILE"

# 第三步：觸發 ai-core 的全域同步
SYNC_SCRIPT="$HOME/ai-core/sync.sh"
if [[ -f "$SYNC_SCRIPT" ]]; then
  echo "[OK] 偵測到 ai-sync 機制，正在向所有 Agent 推署..."
  bash "$SYNC_SCRIPT" >/dev/null 2>&1 || true
  echo "[OK] 所有代理人已完成技能同步！"
else
  echo "[WARN] 找不到同步腳本 $SYNC_SCRIPT，請人工確認。"
fi
