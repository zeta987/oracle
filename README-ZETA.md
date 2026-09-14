# Zeta Oracle：npm 安裝、更新與發佈

這是 [zeta987/oracle](https://github.com/zeta987/oracle) 的操作說明。一般使用者安裝 **`@zeta987/oracle`**；`oracle` 與 `oracle-mcp` 指令名稱保持不變。

## 1. 一般使用者安裝

先準備 Node.js 24 或更新的相容版本；本專案開發驗證使用 Node 24／26。安裝包已包含編譯後的 JavaScript，一般使用者不用 clone、安裝 pnpm 或手動 build。

```powershell
npm install -g @zeta987/oracle
oracle --version
```

第一版為 `0.20.3-zeta.1`。npm 帳號與 GitHub 帳號的 scope 是不同的權限；本套件由 npm 帳號 `zeta987` 發佈。

## 2. 從官方版或 clone + link 遷移

舊套件與新套件都提供 `oracle`／`oracle-mcp`，第一次遷移先移除舊套件或其連結，再安裝新套件：

```powershell
npm uninstall -g @steipete/oracle
npm install -g @zeta987/oracle
oracle --version
npm ls -g @zeta987/oracle --depth=0
```

解除 npm link 不會刪除原本 clone 的 repo。個人的 `~/.oracle/config.json`、瀏覽器 profile 與 session 也不會因這個套件遷移而改寫。

不要使用 `--force` 解決不明的同名指令衝突；先用 `Get-Command oracle -All` 找出實際指令來源。

## 3. 平常更新

```powershell
npm update -g @zeta987/oracle
# 或連同其他全域套件一起更新
npm update -g
oracle --version
```

更新來自 npm registry 的 `latest` 標籤。開發者只有 push GitHub commit、尚未發佈新版本時，npm 不會有新版本可下載。

如果想明確安裝目前的最新發佈版：

```powershell
npm install -g @zeta987/oracle@latest
```

## 4. 確認版本與指令來源

```powershell
Get-Command oracle -All
oracle --version
npm ls -g @zeta987/oracle --depth=0
npm view @zeta987/oracle version
```

`oracle --version` 是目前執行的版本；`npm view` 是 registry 的 latest。兩者相同表示版本號一致，還要確認命令沒有被 alias、function 或其他 npm prefix 的舊程式遮蔽。

`npm install -g @steipete/oracle` 仍代表原作者的套件，不是這份 fork。請分享帶有 `@zeta987` 的安裝指令。

## 5. 網頁模型與設定

每台電腦使用自己的瀏覽器登入。可先預覽 CLI 解析結果，不會送出模型請求：

```powershell
oracle --engine browser --model gpt-5.6-sol --browser-thinking-time xhigh --browser-model-strategy select --dry-run summary -p 'Reply only ORACLE_OK'
oracle --engine browser --model gpt-6-pro --browser-thinking-time pro --browser-model-strategy select --dry-run summary -p 'Reply only ORACLE_OK'
```

Sol 的 `xhigh` 會解析為 Extra High／「極高」；GPT-6 Pro 對應目前的 `Latest`／「最新的」與 Pro 強度。移除 dry-run 後才是實際請求，應檢查模型與思考強度的選取證據。

設定檔為 `~/.oracle/config.json`（JSON5），設定 `ORACLE_HOME_DIR` 時以該位置為準。例如：

```json
{
  "engine": "browser",
  "model": "gpt-6-pro",
  "browser": {
    "modelStrategy": "select",
    "thinkingTime": "pro",
    "manualLogin": true
  }
}
```

已有可附掛的 Chrome 相容瀏覽器時，才依自己的環境使用 `browser.attachRunning`。保留及備份原本的個人設定，不要把另一台的憑證或 browser profile 當成安裝包的一部分。詳見 [Browser mode](docs/browser-mode.md)。

## 6. Skill 與上傳備援

npm 套件包含 `skills/oracle/SKILL.md`。它不會自動改寫 Codex、Claude Code 或 agy 的個人 skill 目錄；將該檔案安裝到宿主實際載入的位置。全域套件目錄可用 `npm root -g` 查詢，下面接 `@zeta987/oracle/skills/oracle/SKILL.md`。

真正測試上傳使用 `--browser-attachments always`。`auto` 可能直接貼入小型文字檔。

上傳失敗時先確認是否已送出；確認未送出後，文字／程式碼檔可改用 `--browser-attachments never`。已送出或狀態不明時先續接既有 session，避免重複請求。原始 PDF、圖片等二進位檔不能直接使用文字貼入備援。完整條件見 [Oracle skill](skills/oracle/SKILL.md)。

## 7. 維護者的版本規則

版本格式為 **`上游版本-zeta.修訂號`**：

- 基於上游 0.20.3 的第一版：`0.20.3-zeta.1`
- 下一次發佈修訂：`0.20.3-zeta.2`，再來是 `.3`
- 改以新上游 0.20.4 為基底時：`0.20.4-zeta.1`

每次準備發佈自己的新修訂時，在乾淨的 repo 執行：

```powershell
npm run version:zeta
```

這會修改版本號，不會自動 commit、tag 或 publish。不要在第一次 `0.20.3-zeta.1` 發佈前再執行一次，否則會進到 `.2`。

升級上游基底時，明確設定：

```powershell
npm version 0.20.4-zeta.1 --no-git-tag-version
```

`-zeta.N` 在 SemVer 中屬於 prerelease；發佈時刻意使用 `--tag latest` 作為本 fork 的一般更新頻道。npm 12.0.2 隔離實測已確認 latest 從 `.1` 指向 `.2` 後，一般 `npm update -g` 可更新。不要改成 `+zeta.N`，build metadata 不提供相同的版本排序效果。

每個已發佈的名稱與版本組合只能使用一次。發佈內容與檢查步驟見 [Zeta 發佈程序](docs/RELEASING.md)，修訂紀錄見 [CHANGELOG-ZETA.md](CHANGELOG-ZETA.md)。

## 8. 開發者仍可使用 clone + link

```powershell
git clone --branch main --single-branch https://github.com/zeta987/oracle.git
Set-Location oracle
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build
npm link --ignore-scripts
```

這會把 `@zeta987/oracle` 連到本機 repo。保留 repo、`node_modules` 與 `dist`。之後更新原始碼：

```powershell
git status --short
git pull --ff-only
pnpm install --frozen-lockfile --ignore-scripts
pnpm run build
```

逐步執行，任一步驟失敗先停止。link 模式下，`npm update -g` 不會代替 `git pull` 或 build；要回到 registry 版，執行 `npm install -g @zeta987/oracle@latest`。
