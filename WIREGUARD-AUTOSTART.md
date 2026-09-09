# 讓 WireGuard（Surfshark）開機自動連線

適用環境：Arch Linux / Omarchy。

這份文件記錄兩種做法：**推薦用 NetworkManager**（已在 Omarchy 上實測跑通），
以及 **`wg-quick` + systemd**（另一種常見做法，但**不能跟 NetworkManager 那套同時用同一個介面名稱**，
兩邊會搶著建立/刪除介面，導致 `wg-quick: 'xxx' already exists` 這種錯誤，永遠連不上）。

如果你不確定要選哪個：**選 NetworkManager**。理由：

- Omarchy/大部分桌面環境本來就是 NetworkManager 在管網路，沒有額外套件要裝
- `endpoint` 若是主機名稱（Surfshark 的 conf 常見寫法，例如
  `tw-tai.prod.surfshark.com:51820`，背後對應多台伺服器做負載平衡），
  NetworkManager 支援每次連線時自動重新解析 DNS，換伺服器 IP 也不會斷
- 可以在桌面右上角網路選單直接開關，不用打指令
- `autoconnect=yes` 讓它開機/登入後自動連，不用手動介入

---

## 方法一：NetworkManager（推薦）

### 1. 把 Surfshark 的設定檔匯入成 NetworkManager 連線

```bash
sudo nmcli connection import type wireguard file ~/Downloads/tw-tai.conf
```

連線名稱預設會跟檔名一樣（`tw-tai`）。也可以用 `nm-connection-editor`
的 GUI 匯入，效果一樣。

### 2. 確認 autoconnect 有開（預設就是開的，保險起見查一下）

```bash
nmcli -f NAME,TYPE,AUTOCONNECT connection show
```

如果 `tw-tai` 那行 `AUTOCONNECT` 不是 `yes`：

```bash
nmcli connection modify tw-tai connection.autoconnect yes
```

### 3. 加上 `persistent-keepalive`（重要，見下方「為什麼要加 keepalive」）

Surfshark 官方匯出的 conf 通常**沒有**這個設定。WireGuard 本身不會主動維持連線，
如果你的電腦在 NAT 後面（幾乎都是），過一段時間沒有封包來回，NAT 對應表會過期，
介面看起來還是 up，但實際上已經斷了，要手動重連才會恢復 —— 這就是「過幾天 VPN
突然連不上」的常見原因。

NetworkManager 的 WireGuard peer 是複合屬性，`nmcli connection modify` 的 CSV
語法在實測中很容易出錯（key 不能加 `public-key=` 標籤、逗號分隔規則也不直覺），
**最可靠的方式是直接編輯設定檔**：

```bash
sudo sed -i '/^\[wireguard-peer\./a persistent-keepalive=25' \
  /etc/NetworkManager/system-connections/tw-tai.nmconnection

sudo nmcli connection reload
nmcli connection down tw-tai
nmcli connection up tw-tai
```

確認設定檔內容應該長這樣（`endpoint` 保留原本的主機名稱，不要改成寫死的 IP）：

```ini
[wireguard-peer.<對方公鑰>]
persistent-keepalive=25
endpoint=tw-tai.prod.surfshark.com:51820
allowed-ips=0.0.0.0/0;
```

### 4. 確認連線成功

```bash
sudo wg show
curl https://ifconfig.me
```

`wg show` 要看到：

- `latest handshake: ... ago`（有數字才算真的連上，不是只是介面 up）
- `transfer: ... received, ... sent`（有流量）
- `persistent keepalive: every 25 seconds`

`curl ifconfig.me` 應該回傳 VPN 伺服器那邊的 IP，而不是你家裡/公司的 IP。

### 常用指令

| 動作 | 指令 |
| --- | --- |
| 手動斷線 | `nmcli connection down tw-tai` |
| 手動重連 | `nmcli connection up tw-tai` |
| 取消開機自動連 | `nmcli connection modify tw-tai connection.autoconnect no` |
| 看目前狀態 | `sudo wg show` |
| 看有沒有跟其他連線衝突 | `nmcli connection show` |

### 換節點

Surfshark 每個節點一個 `.conf`，重複上面「匯入」步驟即可，每個節點會是獨立的
NetworkManager 連線。**同一時間只 `up` 一個**，不然會互搶預設路由。

---

## 方法二：`wg-quick` + systemd（跟方法一二選一，不要同時用）

如果你的環境沒有 NetworkManager，或基於某些理由想用 wg-quick，可以用這個腳本：

```bash
./wireguard-autostart.sh ~/Downloads/tw-tai.conf
```

原理：`wireguard-tools` 附帶 systemd 樣板服務 `wg-quick@.service`，介面名稱取自
檔名（`tw-tai.conf` → `wg-quick@tw-tai`），`systemctl enable --now` 之後開機自動連。

**在採用這個方法之前，務必先確認沒有同名的 NetworkManager 連線**：

```bash
nmcli connection show | grep tw-tai
```

如果有，兩邊都想建立/管理同一個介面（`tw-tai`）會互搶，典型症狀是：

```
wg-quick: `tw-tai' already exists
```

明明手動 `wg-quick down tw-tai` 顯示清除成功，下一秒 `systemctl restart` 又報同樣的
錯誤 —— 因為 NetworkManager 那邊 `autoconnect=yes` 又把介面建回來了。解法是兩者
只留一個：

```bash
# 停用 NetworkManager 那邊，改用 wg-quick
nmcli connection down tw-tai
nmcli connection modify tw-tai connection.autoconnect no
# 或乾脆刪除：nmcli connection delete tw-tai

# 或者反過來，停用 wg-quick，改用 NetworkManager（本文件推薦的方法一）
sudo systemctl disable --now wg-quick@tw-tai
```

### 常見問題（`wg-quick` 方式專屬）

**`resolvconf: command not found`**：conf 檔有 `DNS = ...` 這行時，`wg-quick`
需要 `resolvconf` 指令套用它。裝其中一個（兩者互相衝突，只能擇一）：

```bash
systemctl is-active systemd-resolved && sudo pacman -S systemd-resolvconf || sudo pacman -S openresolv
```

腳本 `wireguard-autostart.sh` 會自動判斷並安裝正確的一個。

**手動加 `persistent-keepalive`**：直接編輯 `/etc/wireguard/tw-tai.conf`，
在 `[Peer]` 段落加一行：

```ini
[Peer]
PublicKey = ...
Endpoint = tw-tai.prod.surfshark.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

改完 `sudo systemctl restart wg-quick@tw-tai`。

**其他指令**：

| 動作 | 指令 |
| --- | --- |
| 暫時斷線 | `sudo systemctl stop wg-quick@tw-tai` |
| 重新連線 | `sudo systemctl start wg-quick@tw-tai` |
| 取消開機自動連 | `sudo systemctl disable wg-quick@tw-tai` |
| 看失敗原因 | `sudo journalctl -xeu wg-quick@tw-tai -b` |

---

## 附錄：這份設定是不是「浮動 IP」？

分兩件事看：

1. **`Address`（你的隧道內部 IP，如 `10.14.0.2/16`）**：不是浮動的，是 Surfshark
   依你的公鑰固定分配的，不會自己變。
2. **`Endpoint`（VPN 伺服器那端）**：如果寫的是主機名稱（例如
   `tw-tai.prod.surfshark.com:51820`）而不是純 IP，**背後對應的伺服器 IP 是會變的**
   —— 每次連線 DNS 解析可能拿到不同台伺服器（負載平衡），實測同一個節點在幾次
   重連間就出現過 `89.117.42.131`、`45.144.227.35`、`82.140.187.42` 等不同 IP。
   這是正常現象，**不要把 endpoint 寫死成某個 IP**，保留主機名稱讓它每次自動重新
   解析，否則哪天那台伺服器維護或下線，你的設定就連不上了。

真正會讓連線「過三四天失效」的原因通常不是 IP 浮動，而是**沒設定
`PersistentKeepalive`**，導致 NAT 對應逾時、介面顯示 up 但實際不通。本文件的兩種
方法都已包含加上 `persistent-keepalive = 25`（Surfshark 官方建議值）的步驟。
