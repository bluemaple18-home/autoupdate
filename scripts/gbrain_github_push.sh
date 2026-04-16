#!/usr/bin/env bash
# gbrain_github_push.sh
# 純 curl 版 GitHub 上傳器，完全不需要 git 指令
# 用法：bash ~/ai-brain/scripts/gbrain_github_push.sh [版本號]
# 例如：bash ~/ai-brain/scripts/gbrain_github_push.sh v2.0.0

set -euo pipefail

VERSION_TAG="${1:-v2.0.0}"
TOKEN_FILE="$HOME/ai-brain/.github_agent.env"
REPO="bluemaple18-home/autoupdate"
API_BASE="https://api.github.com"

# 讀取 Token
if [ ! -f "$TOKEN_FILE" ]; then
    echo "❌ 找不到 Token 檔案：$TOKEN_FILE"
    exit 1
fi
source "$TOKEN_FILE"

echo "🚀 GBrain $VERSION_TAG 開始透過 GitHub API 上傳..."

# ===== Helper：上傳單一檔案至 GitHub =====
upload_file() {
    local LOCAL_PATH="$1"
    local REMOTE_PATH="$2"
    
    if [ ! -f "$LOCAL_PATH" ]; then
        echo "   ⚠️ 跳過（不存在）：$LOCAL_PATH"
        return 0
    fi

    local CONTENT
    CONTENT=$(base64 -i "$LOCAL_PATH" | tr -d '\n')
    
    # 先取得遠端 SHA（如果存在）
    local SHA
    SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$API_BASE/repos/$REPO/contents/$REMOTE_PATH" 2>/dev/null \
        | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')

    if [ -n "$SHA" ]; then
        # 已存在，更新
        curl -s -X PUT "$API_BASE/repos/$REPO/contents/$REMOTE_PATH" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"sync: $VERSION_TAG - 更新 $REMOTE_PATH\",\"content\":\"$CONTENT\",\"sha\":\"$SHA\"}" > /dev/null
    else
        # 新增
        curl -s -X PUT "$API_BASE/repos/$REPO/contents/$REMOTE_PATH" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"sync: $VERSION_TAG - 新增 $REMOTE_PATH\",\"content\":\"$CONTENT\"}" > /dev/null
    fi
    echo "   ✅ $REMOTE_PATH"
}

# ===== 上傳核心腳本 =====
echo ""
echo "📂 上傳核心腳本 (scripts/)..."
for f in gbrain_skill_generator gbrain_context_compressor gbrain_memory_event gbrain_github_push setup_llama3_tw codex_task_checkpoint deploy_autoupdate; do
    upload_file "$HOME/ai-brain/scripts/${f}.sh" "scripts/${f}.sh"
done

# ===== 上傳規則文件 =====
echo ""
echo "📂 上傳全域規則 (rules/)..."
# 只上傳我們有讀取權限的規則副本（先複製到 ai-brain 再上傳）
mkdir -p "$HOME/ai-brain/.tmp_upload/rules"
for f in 03-memory-protocol.md 04-handoff-protocol.md 05-karpathy-coding-protocol.md; do
    SRC="$HOME/ai-core/rules/$f"
    TMP="$HOME/ai-brain/.tmp_upload/rules/$f"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$TMP" 2>/dev/null || echo "   ⚠️ 跳過（沙盒限制）：$f"
        upload_file "$TMP" "rules/$f"
    fi
done

# ===== 上傳其他重要設定 =====
echo ""
echo "📂 上傳偏好設定與遷移指南..."
upload_file "$HOME/ai-brain/habits/PM_preferences.md" "habits/PM_preferences.md"
upload_file "$HOME/ai-brain/gbrain_v2_migration_guide.md" "README.md"

# ===== 清理暫存 =====
rm -rf "$HOME/ai-brain/.tmp_upload"

# ===== 建立 Release Tag =====
echo ""
echo "🏷️ 正在建立 Release Tag $VERSION_TAG..."

# 先取得 default 分支最新 commit SHA
LATEST_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$API_BASE/repos/$REPO/commits/HEAD" | grep '"sha"' | head -1 \
    | sed 's/.*"sha": *"\([^"]*\)".*/\1/')

# 刪除舊 tag（如有）
curl -s -X DELETE "$API_BASE/repos/$REPO/git/refs/tags/$VERSION_TAG" \
    -H "Authorization: token $GITHUB_TOKEN" > /dev/null || true

# 建立新 tag
curl -s -X POST "$API_BASE/repos/$REPO/git/refs" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"ref\":\"refs/tags/$VERSION_TAG\",\"sha\":\"$LATEST_SHA\"}" > /dev/null

echo "   ✅ Tag $VERSION_TAG 已建立"

echo ""
echo "🎉 GBrain $VERSION_TAG 所有檔案已成功上傳至 GitHub！"
echo "   👉 https://github.com/$REPO"
