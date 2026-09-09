# 讓 WireGuard（Surfshark）開機自動連線

適用環境：Arch Linux / Omarchy，使用 `wireguard-tools`（`wg-quick`）連 Surfshark。

原理：`wireguard-tools` 本身就附帶一個 systemd 樣板服務 `wg-quick@.service`。
只要把設定檔放到 `/etc/wireguard/<名稱>.conf`，再 `systemctl enable` 對應的
`wg-quick@<名稱>`，systemd 就會在每次開機時自動把隧道拉起來，不用再手動下指令。

## 懶人版

```bash
./wireguard-autostart.sh ~/Downloads/tw-tai.conf
```

不帶參數時預設就是 `~/Downloads/tw-tai.conf`。

## 手動步驟

### 1. 安裝套件

```bash
sudo pacman -S --needed wireguard-tools
```

### 2. 把設定檔放進 /etc/wireguard/

**介面名稱就是檔名**，所以 `tw-tai.conf` 對應的服務叫 `wg-quick@tw-tai`。
（檔名去掉 `.conf` 後不能超過 15 個字元，這是 Linux 網路介面名稱的上限。）

```bash
sudo install -d -m 700 /etc/wireguard
sudo install -m 600 -o root -g root ~/Downloads/tw-tai.conf /etc/wireguard/tw-tai.conf
```

**重要：** 設定檔裡有 `PrivateKey`，一定要是 `600` 且屬於 root。
`~/Downloads` 下那份預設是 `644`（誰都讀得到），確認搬好之後建議刪掉：

```bash
rm ~/Downloads/tw-tai.conf
```

### 3. 啟用開機自動連線

```bash
sudo systemctl enable --now wg-quick@tw-tai
```

- `enable` = 以後每次開機自動連
- `--now` = 順便現在就連上

### 4. 確認

```bash
sudo systemctl status wg-quick@tw-tai   # 服務狀態
sudo wg show                            # 看 handshake 有沒有成功
curl https://ifconfig.me                # 對外 IP 應該變成 Surfshark 的
```

`wg show` 裡的 `latest handshake` 有時間、`transfer` 有數字，就代表真的通了。

## 常用指令

| 動作 | 指令 |
| --- | --- |
| 暫時斷線 | `sudo systemctl stop wg-quick@tw-tai` |
| 重新連線 | `sudo systemctl start wg-quick@tw-tai` |
| 取消開機自動連 | `sudo systemctl disable wg-quick@tw-tai` |
| 看失敗原因 | `sudo journalctl -u wg-quick@tw-tai -b` |

## 常見問題

### `resolvconf: command not found`

Surfshark 的設定檔通常有 `DNS = ...` 這一行，`wg-quick` 會呼叫 `resolvconf`
去套用它，沒裝就會啟動失敗。Arch 上有兩個提供者，**兩者互相衝突，只能裝一個**：

- 有在用 `systemd-resolved`（`systemctl is-active systemd-resolved`）→ 裝 `systemd-resolvconf`
- 沒有的話 → 裝 `openresolv`

```bash
sudo pacman -S openresolv          # 或 systemd-resolvconf
```

腳本會自動判斷並裝正確的那一個。

### 連上 VPN 之後上不了網 / DNS 壞掉

多半是上面那個 resolvconf 沒裝好，導致 DNS 沒切過去。先看
`resolvectl status`（或 `cat /etc/resolv.conf`）確認 DNS 是不是 Surfshark 給的那組。

### 開機時連不上，但手動 start 就可以

`wg-quick@.service` 已經 `After=network-online.target`，但如果網路是 NetworkManager
管的，要確認 wait-online 有啟用：

```bash
sudo systemctl enable NetworkManager-wait-online.service
```

### 想換其他國家的節點

Surfshark 每個節點一個 `.conf`。同樣丟進 `/etc/wireguard/`，
然後 enable 對應的 `wg-quick@<檔名>` 即可。**同一時間只 enable 一個**，
不然多條隧道會互搶預設路由：

```bash
sudo systemctl disable --now wg-quick@tw-tai
sudo systemctl enable --now wg-quick@jp-tok
```
