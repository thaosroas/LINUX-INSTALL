#!/usr/bin/env bash
# Set up a WireGuard (Surfshark) config to connect automatically at boot on Arch.
#
# Copies the .conf into /etc/wireguard/ and enables wg-quick@<name>.service,
# so systemd brings the tunnel up on every boot without any manual command.
#
# NOTE: if this box uses NetworkManager (most desktops, including Omarchy),
# consider importing the config into NetworkManager instead - see
# WIREGUARD-AUTOSTART.md "Method 1" for why, and how to add
# PersistentKeepalive there. Do NOT run both on the same interface name:
# NetworkManager and wg-quick will fight over creating/deleting the
# interface and you'll see "wg-quick: '<name>' already exists" forever.
#
# Usage: ./wireguard-autostart.sh [path/to/config.conf]
#        (defaults to ~/Downloads/tw-tai.conf)

set -euo pipefail

CONF_SRC="${1:-$HOME/Downloads/tw-tai.conf}"

if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this as your normal user, not root (sudo is used internally)." >&2
    exit 1
fi

if [ ! -f "$CONF_SRC" ]; then
    echo "Config not found: $CONF_SRC" >&2
    echo "Pass the path explicitly, e.g. ./wireguard-autostart.sh ~/Downloads/tw-tai.conf" >&2
    exit 1
fi

IFACE="$(basename "$CONF_SRC" .conf)"
if [ "${#IFACE}" -gt 15 ]; then
    echo "Interface name '$IFACE' is longer than 15 characters; rename the .conf file first." >&2
    exit 1
fi

echo "Installing wireguard-tools..."
sudo pacman -S --needed --noconfirm wireguard-tools

# wg-quick needs a `resolvconf` command to apply the DNS = line in the config.
# Arch ships two providers: systemd-resolvconf (for systemd-resolved) and
# openresolv (standalone). They conflict, so pick the one that matches the box.
if grep -qi '^[[:space:]]*DNS[[:space:]]*=' "$CONF_SRC" && ! command -v resolvconf >/dev/null; then
    if systemctl is-active --quiet systemd-resolved; then
        echo "Config sets DNS and systemd-resolved is active; installing systemd-resolvconf..."
        sudo pacman -S --needed --noconfirm systemd-resolvconf
    else
        echo "Config sets DNS; installing openresolv to provide resolvconf..."
        sudo pacman -S --needed --noconfirm openresolv
    fi
fi

echo "Installing config as /etc/wireguard/$IFACE.conf (root-only, mode 600)..."
sudo install -d -m 700 /etc/wireguard
sudo install -m 600 -o root -g root "$CONF_SRC" "/etc/wireguard/$IFACE.conf"

echo "Enabling and starting wg-quick@$IFACE..."
sudo systemctl enable --now "wg-quick@$IFACE.service"

echo
echo "Current tunnel status:"
sudo wg show || true

cat <<EOF

WireGuard '$IFACE' is now enabled at boot.

Useful commands:
  sudo systemctl status wg-quick@$IFACE     # is it up?
  sudo wg show                              # handshake / transfer counters
  sudo systemctl stop wg-quick@$IFACE       # disconnect for now
  sudo systemctl start wg-quick@$IFACE      # reconnect
  sudo systemctl disable wg-quick@$IFACE    # stop connecting at boot

Verify you are going through the VPN:
  curl https://ifconfig.me

The private key now lives in /etc/wireguard/$IFACE.conf; you can delete the
copy in $CONF_SRC if you do not want a world-readable one lying around.
EOF
