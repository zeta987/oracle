# zeta987 Oracle：安裝、更新與確認版本

這份說明適用於 [zeta987/oracle](https://github.com/zeta987/oracle) 的本機原始碼安裝，指令以 **Windows PowerShell 7** 為例。

使用方式是 **clone → 安裝相依套件 → build → npm link**。`oracle` 指令會透過 npm 的全域連結執行這個 repo 的 `dist` 建置成品。

## 1. 第一次安裝

先安裝 Git、Node.js 24 或 26。pnpm 版本以 `package.json` 的 `packageManager` 為準；以下版本是本次驗證使用的 `11.26.0`。

在準備放置 repo 的目錄逐行執行；任一步驟失敗時先停止，不要繼續 link 不完整的建置：

```powershell
npm install -g pnpm@11.26.0
git clone --branch main --single-branch https://github.com/zeta987/oracle.git
Set-Location oracle
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build
npm link --ignore-scripts
oracle --version
```

`--ignore-scripts` 讓安裝相依套件與建置分開；上一個步驟已明確執行 `pnpm run build`，所以 link 時不必再跑一次 `prepare`。

不用先解除安裝同名的官方版本，也不需要 `--force`。在 npm 12.0.2 的 Windows 隔離實測中，`npm link` 可將同名的一般安裝替換成指向 repo 的 Junction。

**保留 repo 的位置、`node_modules` 與 `dist`。** 移動 repo 後需要從新位置重新執行 `npm link --ignore-scripts`。

## 2. 平常更新 CLI

在這份 repo 的 `main` 分支執行：

```powershell
git status --short
git switch main
git pull --ff-only
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build
```

先確認沒有需要保留的未提交修改。若切換分支、拉取或建置失敗，先處理該錯誤；不要用 `reset --hard` 或強制拉取來略過。

既有 npm 連結仍指向這個目錄，所以更新後通常**不用重新 link**。只有連結被其他安裝取代、npm prefix 改變，或 repo 移動時，才重新執行：

```powershell
npm link --ignore-scripts
```

`git pull` 只更新原始碼；**沒有重新 build，CLI 就仍可能執行舊的 `dist`**。

## 3. 從舊修補分支改用 main

如果之前使用 `--branch fix/astra-zh-tw-picker --single-branch` clone，單純 `git fetch` 可能只更新該修補分支。合併後改成追蹤 fork 的 `main`：

```powershell
git status --short
git remote set-branches --add origin main
git fetch origin
git switch main
git branch --set-upstream-to=origin/main main
git pull --ff-only
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build
```

一般 Git 設定會在 `git switch main` 時從唯一的 `origin/main` 建立本機分支。若沒有本機 `main`，且自動建立被停用，改用 `git switch -c main --track origin/main`；已有本機 `main` 時不要加 `-c`。

## 4. 確認執行的真的是這份修正版

不能只看 `oracle --version`。2026-09-14 的修補 commit 是 `7ea9505df340b4782d06520250a90792731f4c3d`，套件版本仍是 **0.20.3**，因此官方版與這份修正版可能印出相同版號。

### A. 檢查命令與 npm 連結

```powershell
Get-Command oracle -All
Get-Command oracle.cmd -All
Get-Content -LiteralPath (Get-Command oracle.cmd -ErrorAction Stop).Source
$oracleNpmPrefix = (npm prefix -g).Trim()
Get-Item -LiteralPath (Join-Path $oracleNpmPrefix 'node_modules/@steipete/oracle') -Force |
  Format-List FullName, LinkType, Target
npm ls -g @steipete/oracle --depth=0
```

預期結果：

- `oracle` 的 npm shim 位於目前 `npm prefix -g` 顯示的目錄，內容指向該 prefix 下的 `node_modules/@steipete/oracle/dist/bin/oracle-cli.js`。
- 套件的 `LinkType` 是 `Junction` 或 `SymbolicLink`，`Target` 指向你剛更新及 build 的 repo。
- 如果 `Get-Command oracle -All` 的第一筆是同名 alias、function，或另一套 Node/npm 的舊路徑，先處理命令遮蔽；後面的正確連結不代表它會被執行。

也可以明確呼叫這個 npm prefix 裡的 Windows shim：

```powershell
& (Join-Path $oracleNpmPrefix 'oracle.cmd') --version
```

### B. 檢查 Git commit 與 fork 的 main

在連結所指向的 repo 裡執行：

```powershell
git remote -v
git fetch origin
git branch --show-current
git log -1 --format='%h %s'
git rev-list --left-right --count HEAD...origin/main
```

`origin` 應是 `https://github.com/zeta987/oracle.git`，目前分支應是 `main`。最後一行 **`0 0`** 表示本機 HEAD 與剛取得的 fork `main` 相同；其他數字代表仍有落後或額外 commit。

若只想確認 2026-09-14 的修補已在歷史中：

```powershell
git merge-base --is-ancestor 7ea9505df340b4782d06520250a90792731f4c3d HEAD
$oraclePatchExitCode = $LASTEXITCODE
$oraclePatchExitCode
```

輸出 `0` 表示包含該修補。這是歷史檢查，不能取代最新 `origin/main` 與建置檢查。

### C. 重新建置，排除舊 dist

```powershell
pnpm run build
Select-String -LiteralPath './dist/src/browser/actions/modelSelection.js' -SimpleMatch '最新的'
oracle --version
```

建置必須成功；本次修補的編譯成品應包含 `最新的` 精確比對。**正確的命令路徑＋正確的連結目標＋最新 commit＋成功 build**，才確認 CLI 使用了這份原始碼的成品。

## 5. 確認兩個網頁模型的指令

以下只預覽，不送出模型請求：

```powershell
oracle --engine browser --model gpt-5.6-sol --browser-thinking-time xhigh --browser-model-strategy select --dry-run summary -p 'Reply only ORACLE_OK'
oracle --engine browser --model gpt-6-pro --browser-thinking-time pro --browser-model-strategy select --dry-run summary -p 'Reply only ORACLE_OK'
```

Sol 預覽目標應為 `GPT-5.6 Sol`；GPT-6 Pro 的選單目標是 `Latest`，繁中網頁可能顯示「最新的」。`xhigh` 是網頁 `extra-high`／「極高」的別名，不能拼成 `xihgh`。

預覽只證明 CLI 解析與路由，不能證明帳戶可用性。實際測試時移除 `--dry-run summary`，使用已登入的瀏覽器，並核對回報的模型與思考強度證據都有 `verified=yes`。GPT-6 Pro 必須確認 Pro 強度；不要使用 `current` 或 `ignore` 來代替指定模型的驗證。

## 6. npm update 與 npm install 的差別

| 操作                                          | 對這份 fork 的影響                                                                                         |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `npm update -g`                               | npm 12.0.2 實測保留本機連結；不執行 `git pull`，也不重新 build                                             |
| `npm install -g @steipete/oracle`             | 安裝官方 registry 套件，會取代目前連結                                                                     |
| `npm install -g 'github:zeta987/oracle#main'` | Git 來源安裝方式；仍需符合該 npm 版本的 Git 安裝政策及建置條件，後續一般 `npm update -g` 不會追蹤 Git 分支 |
| 在 fork repo 執行 `npm link --ignore-scripts` | 把全域指令連回這份本機建置                                                                                 |

若希望一般 `npm update -g` 自動取得自己的新版，必須另行發布自己的 npm 套件到 registry；GitHub push 本身不會發布 npm 版本。這份 fork 目前採用原始碼＋本機連結方式。

## 7. Skill、設定與上傳備援

- repo 內的 skill 是 [`skills/oracle/SKILL.md`](skills/oracle/SKILL.md)，每台電腦需要另外安裝到宿主實際載入的目錄。`npm link` 不會自動安裝或更新 skill。
- 個人設定通常位於 `~/.oracle/config.json`，有設定 `ORACLE_HOME_DIR` 時則以它為準。不要直接覆寫另一台已有的設定；先核對及備份。
- 本次使用的預設為 `engine: "browser"`、`model: "gpt-6-pro"`、`browser.modelStrategy: "select"`、`browser.thinkingTime: "pro"`。要使用 Sol，明確傳入 `--browser-thinking-time xhigh` 覆寫 Pro 強度。
- `browser.attachRunning: true` 需要該台電腦已有可附掛且已登入的 Chrome 相容瀏覽器。瀏覽器登入及遠端除錯允許狀態需在每台電腦各自處理，詳見 [Browser mode](docs/browser-mode.md)。
- 真正測試文件上傳使用 `--browser-attachments always`；`auto` 可能直接把小型文字檔貼入提示。
- 上傳失敗先檢查是否已送出。確認未送出後，文字／程式碼檔可改用 `--browser-attachments never` 貼入內容；已送出或狀態不明時先續接既有 session，避免重複請求。原始 PDF、圖片等二進位檔不能直接用這種文字備援。

上傳與貼入的完整操作條件請看 [Oracle skill](skills/oracle/SKILL.md)。
