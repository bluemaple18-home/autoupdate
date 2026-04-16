# GBrain & AI-Core V2 架構遷移指南

這份文件記錄了我們近期從 Hermes 系統移植的「記憶與交接升級」全貌。當您要將系統部署到另一台新電腦時，請嚴格參照此指引進行檔案覆蓋與舊制棄用。

## 🚀 1. 新增與升級的核心檔案清單 (需打包至新機)

### A. 全域大腦腳本 (`~/ai-brain/scripts/`)
1. **`gbrain_skill_generator.sh`** (NEW)
   - 取代模型自寫 YAML。提供標準、防呆、具備自動同步功能的跨工具技能產生器。
2. **`gbrain_context_compressor.sh`** (NEW)
   - 對話脈絡壓縮器（秘書層）。攔截即將爆掉的對話紀錄，由本地模型榨汁濃縮出 500 字交接包。
3. **`gbrain_memory_event.sh`** (NEW)
   - 零延遲記憶事件紀錄器。取代舊的即時向量化機制。
4. **`setup_llama3_tw.sh`** (NEW)
   - 本地台灣 8B 模型自動安裝腳本。
5. **`codex_task_checkpoint.sh`** (MODIFIED)
   - 已改查線至 `gbrain_memory_event.sh`。

### B. 全域規則主庫 (`~/ai-core/rules/`)
1. **`03-memory-protocol.md`** (MODIFIED)
   - 導入 Frozen Snapshot 機制，將記憶更新改為佇列制，以保護 LLM 的前綴快取 (Prefix Caching)。
2. **`04-handoff-protocol.md`** (MODIFIED)
   - 制定了 Agent 在面臨 Token 爆量前的「4大自主觸發閥值（鬼打牆、安全線等）」。
   - 強制套用了高度結構化的 Handoff 框架 (Goal, Constraints, Active State...)。
3. **`05-karpathy-coding-protocol.md`** (NEW)
   - 納入 Andrej Karpathy 的 4 項神級鐵律 (Think Before Coding, Surgical Changes 等)，強制 Agent 不可自作聰明瞎猜。

## 🤖 2. 必須安裝的地端模型清單 (Local Model Dependencies)
為了確保這套 GBrain 系統與本地環境順利脫離雲端依賴，新主機的 `Ollama` 必須備齊以下這三包核心模型：
1. **`nomic-embed-text:latest`** (大腦記憶庫專用)
   - 負責將日常記憶轉化為向量存入 PGLite (`memory_store` 與 `dream_cycle` 的底層引擎)。
   - 👉 安裝指令：`ollama pull nomic-embed-text`
2. **`llama-3-tw:8b`** (對話壓縮秘書專用)
   - 負責在 Token 快爆掉時做上下文壓縮與交接摘要 (`Context Compressor` 的核心引擎)。
   - 👉 安裝指令：無需手動 pull，請執行我們寫好的 `bash ~/ai-brain/scripts/setup_llama3_tw.sh`
3. **`qwen2.5-coder`** (選配：寫 Code 專用)
   - 目前表現最佳的本地端輕量級寫碼模型。
   - 👉 安裝指令：`ollama pull qwen2.5-coder`

### C. 設置與技能 (`~/ai-brain/habits/` & `~/ai-core/skills/`)
1. **`PM_preferences.md`** (MODIFIED)
   - 封裝系統安全閥（禁止並行搜尋、禁用 `IsArtifact`）。
   - 嚴格指定套件管理必須優先使用 `pnpm` 取代 npm。
   - 綁定新主機必須使用 `llama-3-tw:8b`。
2. **`auto-skill/SKILL.md`** (MODIFIED)
   - 更新執行流程，強制呼叫 `gbrain_skill_generator.sh`。

---

## 🗑 3. 必須棄用與刪除的機關 (Deprecations)

當您搬移到新電腦時，以下做法與檔案**千萬不要**帶過去，否則會發生衝突或卡頓：

1. **棄用腳本：`codex_memory_event.sh`**
   - ❌ 過去做法：每次打勾 Task 就瘋狂啟動模型查向量，造成系統卡住數十秒。
   - 💡 新機作法：已被 `gbrain_memory_event.sh` 徹底取代，請將舊檔刪除。
2. **棄用檔案格式：`walkthrough.md`**
   - ❌ 過去做法：容易觸發平台渲染器的無盡轉圈 Bug。
   - 💡 新機作法：全面改用腳本自動生成的 `handoff_*.md` 作為實體交接斷點。
3. **棄用指令：手動呼叫 `memory_store.sh` 進行瑣碎存檔**
   - ❌ 過去做法：Agent 自作主張去底層跑 `~/.antigravity/bin/memory_store.sh` 導致沙盒權限報錯。
   - 💡 新機作法：日常瑣事只寫入佇列，交給夜間 `dream_cycle.sh` 一次結算。

---

## 📦 4. 新機一鍵對齊步驟 (Migration Steps)

到達新電腦後，請依照順序執行：

1. 將打包好的 `gbrain_v2_migration.tar.gz` 解壓縮至使用者的根目錄 (`~`)。
2. 匯入全域規則：
   ```bash
   cd ~/ai-core
   bash sync.sh
   ```
3. 安裝地端模型與繁中壓縮精靈：
   ```bash
   ollama pull nomic-embed-text
   ollama pull qwen2.5-coder
   cd ~/ai-brain
   bash scripts/setup_llama3_tw.sh
   ```
4. 刪除新機上的系統殘存垃圾（如果有裝錯的）：
   ```bash
   ollama rm llama3.2 text-embedding-3-large
   rm ~/ai-brain/scripts/codex_memory_event.sh
   ```
