# Omarchy 倉頡輸入法 一鍵安裝

複製整段貼到終端機執行即可（會需要 sudo 密碼）。

```bash
# 1. 安裝 fcitx5 + 倉頡碼表
sudo pacman -S --needed --noconfirm \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-table-extra

# 2. 設定 Wayland/Hyprland 環境變數
mkdir -p ~/.config/hypr
ENV_FILE="$HOME/.config/hypr/hypr-env.conf"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

if ! grep -q "GTK_IM_MODULE" "$ENV_FILE" 2>/dev/null; then
cat >> "$ENV_FILE" <<'EOF'
env = GTK_IM_MODULE,fcitx
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = SDL_IM_MODULE,fcitx
EOF
fi

if [ -f "$HYPR_CONF" ] && ! grep -q "hypr-env.conf" "$HYPR_CONF"; then
    echo "source = $ENV_FILE" >> "$HYPR_CONF"
fi

# 3. 停掉所有現有 fcitx5 行程，避免設定寫入時發生競爭
pkill -x fcitx5 2>/dev/null
sleep 2

# 4. 直接寫入設定檔，把倉頡5加進輸入法清單
mkdir -p ~/.config/fcitx5
cat > ~/.config/fcitx5/profile <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=cangjie5
Layout=

[GroupOrder]
0=Default
EOF

# 5. 重新啟動 fcitx5（會透過 D-Bus 自動拉起單一乾淨的行程）
fcitx5-remote -r
sleep 2

# 6. 驗證
echo "目前輸入法："
fcitx5-remote -n
```

## 驗證與切換

執行完上面整段後，`fcitx5-remote -n` 應該顯示 `keyboard-us`（預設狀態）。按 **Ctrl+Space** 切換到倉頡，再跑一次確認：

```bash
fcitx5-remote -t
fcitx5-remote -n
```

應該會變成 `cangjie5` 或類似名稱，代表切換成功。

打字方式：輸入字根代碼（最多 5 碼字母），按 **空白鍵** 選字，或用數字鍵選候選字。

## 若自動寫入沒生效（GUI 備援）

`table` 這個 addon 是隨需載入（OnDemand），極少數情況下直接寫設定檔會在下次啟動時被清掉。如果第 6 步驗證後切換不出倉頡，改用 GUI 手動加入一次即可：

```bash
fcitx5-configtool
```

1. 點 **+**
2. 取消勾選 **Only Show Current Language**
3. 搜尋 `cangjie`，選 **Cangjie5**，按 **Add** → **Apply**

之後不用再重複，設定會持久保存。

## 重要：環境變數需要重新登入才生效

`hyprctl reload` 不會套用新的環境變數。改完後請**登出再登入**（或重開機），GTK/Qt 應用程式才能正確吃到 `GTK_IM_MODULE` / `QT_IM_MODULE`，否則就算輸入法切換成功，某些程式裡也打不出候選字。
