#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/bluemaple18-home/autoupdate.git"
REPO_DIR="$HOME/ai-brain/autoupdate"
VERSION_TAG="${1:-v2.0.0}"

echo "🚀 開始部署 GBrain $VERSION_TAG 到遠端更新庫..."

# 1. 處理 Git 基礎庫
if [ ! -d "$REPO_DIR" ]; then
    echo "📦 正在 Clone 遠端倉庫..."
    git clone "$REPO_URL" "$REPO_DIR"
else
    echo "🔄 倉庫已存在，正在拉取最新設定..."
    cd "$REPO_DIR"
    git checkout main || git checkout master
    git pull
    cd - >/dev/null
fi

# 2. 打包核心檔案到版控庫
DEST_FILE="$REPO_DIR/gbrain_v2_migration.tar.gz"

echo "🗜️ 正在將最新的核心架構打包至 autoupdate 目錄中..."

# 清除殘留的不良腳本
rm -f "$HOME/ai-brain/scripts/codex_memory_event.sh"

FILES_TO_PACK=(
  "$HOME/ai-brain/scripts/gbrain_skill_generator.sh"
  "$HOME/ai-brain/scripts/gbrain_context_compressor.sh"
  "$HOME/ai-brain/scripts/gbrain_memory_event.sh"
  "$HOME/ai-brain/scripts/setup_llama3_tw.sh"
  "$HOME/ai-brain/scripts/codex_task_checkpoint.sh"
  "$HOME/ai-brain/scripts/dream_cycle.sh"
  "$HOME/ai-brain/gbrain_v2_migration_guide.md"
  "$HOME/ai-brain/habits/"
  "$HOME/ai-core/rules/"
  "$HOME/ai-core/skills/"
  "$HOME/ai-core/sync.sh"
)

# 安靜執行打包以避免洗版
tar -czvf "$DEST_FILE" "${FILES_TO_PACK[@]}" >/dev/null

# 3. 把對齊指南做為對外的 README 門面
cp "$HOME/ai-brain/gbrain_v2_migration_guide.md" "$REPO_DIR/README.md"

# 4. 版控提交與 Tag 推送
cd "$REPO_DIR"
echo "✅ 檔案準備就緒，正在進行 Git 上傳與打標籤..."

git add .
git diff --cached --quiet || git commit -m "feat: 發布 GBrain V2 終極版架構升級 ($VERSION_TAG)

- 加入 Handoff 壓縮器與 Agent 自主防呆機制
- 導入 Andrej Karpathy LLM 鐵律 (05-karpathy)
- 非同步化記憶佇列機制 (零延遲寫入)
- 強制 pnpm 預設套件管理
- 新增全自動技能建立腳本"

# 防呆：如果 Tag 已經存在就先覆蓋
if git rev-parse "$VERSION_TAG" >/dev/null 2>&1; then
    echo "⚠️ 偵測到標籤 $VERSION_TAG 已存在，正在進行強勢覆蓋..."
    git tag -d "$VERSION_TAG"
    git push --delete origin "$VERSION_TAG" || true
fi

echo "🏷️ 打上版本號：$VERSION_TAG"
git tag "$VERSION_TAG"

echo "⬆️ 執行推送 (Push)..."
git push origin HEAD
git push origin "$VERSION_TAG"

echo "🎉 部署大功告成！GBrain $VERSION_TAG 已成功部署於 $REPO_URL"
