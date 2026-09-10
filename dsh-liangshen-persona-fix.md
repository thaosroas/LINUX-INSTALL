# dsh-liangshen: "梁神模式" 無法啟動的修復

## https://github.com/zhu1090093659/dsh-web/tree/main

## 症狀

在 DSH Web GUI 新建對話時選擇「梁神模式」預設，跳出錯誤：

```
无法切换到「梁神模式」：failed to apply loader entry persona (@deepseek-ai/dsh-persona):
invalid config: - $.prefix missing required value (at prefix)
(<DSH_HOME>/.agent-presets/liangshen/agent.cordis.yml)
```

## 根本原因

`@linxin666/dsh-liangshen`（目前驗證於 v0.3.18）內建的 preset 檔案裡，
`@deepseek-ai/dsh-persona` 這個 loader entry 用的是**舊欄位名** `text:`：

```yaml
- id: persona
  name: '@deepseek-ai/dsh-persona'
  config:
    text: You are a helpful software engineer assistant.
```

但目前的 `@deepseek-ai/dsh-persona`（DSH host >= 0.1.5-rc.1 一類版本）schema 已經把這個欄位
改名為**必填**的 `prefix:`（見該套件 `lib/index.js` / `lib/types/index.d.ts`：
`prefix: z.string().required()`）。欄位名對不上，preset 組裝時驗證失敗。

這是 `dsh-liangshen` 套件本身沒跟上 `dsh-persona` schema 改名的 bug，跟你自己的設定無關。

## 修復方式

把 `text:` 改成 `prefix:`（值不變）。**需要改兩個地方**（Linux/Ubuntu 路徑，把
`<DSH_PROFILE>` 換成你實際跑 `dsh web` 的 profile 目錄，通常是 `~/.dsh/profiles/web`）：

1. **套件原始檔**（liangshen 每次啟動 sync 時的來源，來源不改，改了也會被蓋掉）：
   
   ```
   <DSH_PROFILE>/node_modules/@linxin666/dsh-liangshen/presets/liangshen/agent.cordis.yml
   ```

2. **已同步到 harness-home 的即時檔**（讓不重啟就能立刻生效；不改這個的話，
   要等下次 `dsh web` 重啟時插件重新 sync 才會覆蓋成修好的版本）：
   
   ```
   ~/.dsh/.agent-presets/liangshen/agent.cordis.yml
   ```
   
   注意目錄名是 **`.agent-presets`**（有底線點開頭的隱藏目錄），不是 `agent-presets`。
   `~/.dsh` 也可能被 `DSH_HOME` 環境變數覆蓋，若你有設這個變數以它為準。

兩個檔案裡都只有一處要改：

```diff
   - id: persona
     name: '@deepseek-ai/dsh-persona'
     config:
-      text: You are a helpful software engineer assistant.
+      prefix: You are a helpful software engineer assistant.
```

可以用 sed 一次改好兩個檔案（先確認上面兩個路徑在你機器上正確）：

```bash
DSH_PROFILE="$HOME/.dsh/profiles/web"   # 依實際情況調整
sed -i 's/^\( *\)text: You are a helpful software engineer assistant\.$/\1prefix: You are a helpful software engineer assistant./' \
  "$DSH_PROFILE/node_modules/@linxin666/dsh-liangshen/presets/liangshen/agent.cordis.yml" \
  "$HOME/.dsh/.agent-presets/liangshen/agent.cordis.yml"
```

改完後回到 GUI 直接重新選一次「梁神模式」；DSH 有熱重載（cordis-plugin-hmr），通常不用重啟
`dsh web` 就會生效。如果還是報同一個錯，重啟一次 `dsh web` 讓 sync 重新跑過即可。

## 重要提醒（會被蓋掉的情況）

這個修正是手動改 `node_modules` 裡的檔案，**不是官方修復**。以下情況會讓 bug 重新出現，
屆時要重複上面步驟：

- 之後執行 `dsh plugin --profile web add @linxin666/dsh-liangshen@latest`（重裝/升級）
- 整個 profile 被重建（例如 `rm -rf ~/.dsh/profiles/web` 後重裝插件）

長期解法是等 `dsh-liangshen` 上游把 preset 裡的 `text:` 改成 `prefix:` 並發新版。
