# 在 Omarchy（Hyprland / Arch）安裝倉頡輸入法

適用環境：Omarchy（基於 Arch Linux 的 Hyprland 桌面）。使用 **Fcitx5** 作為輸入法框架（比 ibus 更適合 Hyprland / wlroots 的 Wayland 環境）。

## 1. 安裝套件

```bash
sudo pacman -S --needed fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-table-extra
```

**注意事項：**

- `fcitx5-table-extra` 才是真正提供倉頡碼表的套件（`cangjie.conf`、`cangjie3.conf`、`cangjie5.conf`、`cangjie-large.conf`）。只裝 `fcitx5` 本體是不夠的，會導致清單裡完全找不到倉頡。
- `fcitx5-configtool` 這個套件裝好後，真正的 GUI 執行檔叫 `fcitx5-config-qt`，不是 `fcitx5-configtool`（那只是套件名稱，直接執行會找不到指令，改成打開設定資料夾）。

驗證碼表檔案確實存在：

```bash
find /usr/share/fcitx5/inputmethod -iname '*cangjie*'
```

## 2. 設定 Wayland/Hyprland 環境變數

在 `~/.config/hypr/` 下建立（或加入既有的）環境變數檔，例如 `hypr-env.conf`：

```ini
env = GTK_IM_MODULE,fcitx
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = SDL_IM_MODULE,fcitx
```

並在 `hyprland.conf` 裡用 `source = ~/.config/hypr/hypr-env.conf` 引入。

**重要：** 環境變數只在登入時套用一次，`hyprctl reload` 不會重新讀取。改完要**登出再登入**（或重開機）才會生效。

Omarchy 預設本身可能已經透過 D-Bus service activation（`/usr/share/dbus-1/services/org.fcitx.Fcitx5.service`）或 `~/.config/autostart/org.fcitx.Fcitx5.desktop` 自動啟動 fcitx5，不一定需要自己加 `exec-once`。可以先確認：

```bash
pgrep -a fcitx5
```

## 3. 加入倉頡輸入法（務必用 GUI，不要手動改 profile）

```bash
fcitx5-config-qt
```

步驟：

1. 點選左下角「Current Input Methods」旁的 **+**
2. 取消勾選 **「Only Show Current Language」**
3. 搜尋 `cangjie`，選擇 **Cangjie5**（或想要的版本），按 **Add**
4. 按 **OK / Apply**

### 為什麼不要手動編輯 `~/.config/fcitx5/profile`？

`table` addon 是 `OnDemand=True`（隨需載入），只有在真正被觸發列舉時才會掃描碼表檔案。實測發現：手動把 `cangjie5` 寫進 profile 後，fcitx5 重啟時會直接把這筆設定**靜默移除**並覆寫回乾淨版本，因為當下 table addon 還沒枚舉出這個輸入法。用 GUI 加入才會正確觸發 addon 枚舉、寫入正確設定。

## 4. 驗證

```bash
fcitx5-remote -t   # 切換輸入法
fcitx5-remote -n   # 印出目前使用中的輸入法，應該會顯示 Cangjie5 相關名稱
```

或直接在任何文字欄位測試：

- **Ctrl+Space**：切換 英文 ↔ 倉頡
- 輸入字根代碼（最多 5 碼），按 **空白鍵** 選字，或用數字鍵選候選字

## 疑難排解重點整理

| 症狀 | 原因 | 解法 |
|---|---|---|
| `fcitx5-configtool` 打開變成開 Nautilus 資料夾 | `fcitx5-config-qt` 執行檔沒裝 | `sudo pacman -S fcitx5-configtool` |
| GUI 裡搜尋不到 Cangjie | 沒裝 `fcitx5-table-extra` | 安裝後再開一次 GUI |
| `fcitx5 -r -v` 顯示 `Failed to create addon: dbus ...Is there another fcitx already running?` | 有另一個行程透過 D-Bus service activation 自動搶先啟動，前景指令搶不到 D-Bus name | 不影響最終結果，改用背景執行的那個既有行程即可，不需自己再開一個 |
| 手動寫 profile 加 `cangjie5`，重啟後被清掉 | `table` addon 是 OnDemand，尚未枚舉到這個 IM 就被判定無效而移除 | 改用 `fcitx5-config-qt` GUI 新增 |
| `GTK_IM_MODULE` 是空的 | 環境變數檔沒被登入時期讀到 | 確認 `hyprland.conf` 有 `source =` 該檔案，並整個登出/登入一次 |
