---
name: github-push
description: Agent 直接透過 curl 呼叫 GitHub REST API 完成打包上傳，不需依賴 git 指令，可在所有沙盒環境使用
platforms: [macos, linux, windows]
---


# GitHub 自動上傳技能 (github-push)

## 前置條件與觸發規則
當 PM 說出「打包上傳」、「推到 GitHub」、「整合上傳」等相關指示時，Agent 應立即觸發此技能。
此技能使用純 `curl` 呼叫 GitHub REST API，完全不依賴 `git` 指令，可在所有沙盒環境中正常運作。

## 前置環境確認

在執行上傳前，Agent 必須確認：

1. **Token 檔案存在**：
   ```bash
   cat ~/ai-brain/.github_agent.env
   ```
   若不存在，請 PM 執行（只需一次）：
   ```bash
   echo "GITHUB_TOKEN=ghp_您的Token" > ~/ai-brain/.github_agent.env
   ```

2. **確認目標 Repo**：詢問 PM 目標是哪個 GitHub Repo（格式：`使用者名稱/repo名稱`）。PM 的 GitHub 帳號為：`bluemaple18-home`。

3. **確認版本號**：詢問 PM 本次的版本號，格式為 `v1.0.0`，若未指定則預設使用 `v1.0.0`。

## 核心上傳步驟

### Step 1：定義上傳清單與目標 Repo
Agent 需要明確知道：
- 哪些本機路徑的檔案要上傳？
- 對應的 GitHub 遠端路徑為何？
- 目標 Repo 名稱為何？

### Step 2：執行 curl 上傳（每個檔案一次 API 請求）

```bash
source ~/ai-brain/.github_agent.env

REPO="bluemaple18-home/目標repo名稱"  # 由 PM 指定
VERSION="v1.0.0"                        # 由 PM 指定

upload_file() {
    local LOCAL_PATH="$1"
    local REMOTE_PATH="$2"
    local CONTENT
    CONTENT=$(base64 -i "$LOCAL_PATH" | tr -d '\r\n')
    local SHA
    SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO/contents/$REMOTE_PATH" 2>/dev/null \
        | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')
    if [ -n "$SHA" ]; then
        curl -s -o /dev/null -w "HTTP %{http_code} -> $REMOTE_PATH\n" \
            -X PUT "https://api.github.com/repos/$REPO/contents/$REMOTE_PATH" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"sync: $VERSION - 更新 $REMOTE_PATH\",\"content\":\"$CONTENT\",\"sha\":\"$SHA\"}"
    else
        curl -s -o /dev/null -w "HTTP %{http_code} -> $REMOTE_PATH\n" \
            -X PUT "https://api.github.com/repos/$REPO/contents/$REMOTE_PATH" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"sync: $VERSION - 新增 $REMOTE_PATH\",\"content\":\"$CONTENT\"}"
    fi
}

# 依專案逐一呼叫，例如：
upload_file "/Users/matt/專案路徑/某檔案.sh" "對應的遠端路徑/某檔案.sh"
```

### Step 3：打上版本 Tag

```bash
LATEST_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/commits/HEAD" \
    | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')

# 若舊 Tag 存在先刪除(可選)
curl -s -X DELETE "https://api.github.com/repos/$REPO/git/refs/tags/$VERSION" \
    -H "Authorization: token $GITHUB_TOKEN" > /dev/null 2>&1 || true

# 建立新 Tag
curl -s -o /dev/null -w "Tag %{http_code}\n" \
    -X POST "https://api.github.com/repos/$REPO/git/refs" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"ref\":\"refs/tags/$VERSION\",\"sha\":\"$LATEST_SHA\"}"
```

## 防呆與地雷區

> [!WARNING]
> macOS 的 `base64` 指令格式為 `base64 -i 檔案路徑`，而不是 `base64 檔案路徑`（後者會報錯）。
> 在轉換後需加上 `| tr -d '\r\n'` 去除換行符號，否則 JSON 會格式錯誤導致上傳失敗。

> [!WARNING]
> `ai-core/` 目錄因沙盒限制，Agent 不能直接用 `tar` 打包讀取，必須以逐檔 `curl` 方式處理。
> 如需上傳 ai-core 規則，須先以 `cp` 複製到 `ai-brain/` 沙盒內再上傳。

> [!CAUTION]
> **絕對不要呼叫 `git` 指令**。在 macOS 沙盒下，Xcode Tools 的安全限制會封鎖 Agent 使用 `git`。
> 本技能改以 `curl` + GitHub REST API 作為唯一授權路徑。

> [!IMPORTANT]
> Token 存放於 `~/ai-brain/.github_agent.env`，內容格式為：
> `GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxx`
> 此檔案屬於機密，不可上傳至任何 GitHub 倉庫。

## 常見專案對照表（PM 慣用 Repo）

| 用途 | GitHub Repo | 本機路徑 |
|------|-------------|----------|
| GBrain 系統架構備份 | `bluemaple18-home/autoupdate` | `~/ai-brain/` |
| （其他 Repo 由 PM 告知後補充）| | |
