#!/usr/bin/env bash
# Install and enable the Cangjie Chinese input method on Omarchy (Arch + Hyprland).
#
# Uses Fcitx5, the input method framework that plays well with Hyprland's
# Wayland text-input protocol (ibus is flaky under wlroots compositors).
#
# Usage: ./cangjie-input-setup.sh
#
# After running, log out of the Hyprland session and back in so the
# environment variables and fcitx5 autostart take effect.

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this as your normal user, not root (sudo is used internally)." >&2
    exit 1
fi

echo "Installing Fcitx5 and the Cangjie table (fcitx5-table-extra provides Cangjie 3/5)..."
sudo pacman -S --needed --noconfirm \
    fcitx5 \
    fcitx5-configtool \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-table-extra

ENV_FILE="$HOME/.config/hypr/hypr-env.conf"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

echo "Setting fcitx5 environment variables for Wayland/Hyprland..."
mkdir -p "$HOME/.config/hypr"
if [ ! -f "$ENV_FILE" ] || ! grep -q "GTK_IM_MODULE" "$ENV_FILE" 2>/dev/null; then
    cat >> "$ENV_FILE" <<'EOF'
env = GTK_IM_MODULE,fcitx
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = SDL_IM_MODULE,fcitx
env = GLFW_IM_MODULE,ibus
EOF
    echo "Wrote fcitx5 env vars to $ENV_FILE"
fi

if [ -f "$HYPR_CONF" ] && ! grep -q "hypr-env.conf" "$HYPR_CONF"; then
    echo "source = $ENV_FILE" >> "$HYPR_CONF"
    echo "Sourced $ENV_FILE from $HYPR_CONF"
fi

if [ -f "$HYPR_CONF" ] && ! grep -q "fcitx5" "$HYPR_CONF"; then
    echo "exec-once = fcitx5 -d" >> "$HYPR_CONF"
    echo "Added fcitx5 autostart to $HYPR_CONF"
fi

cat <<'EOF'

Fcitx5 with Cangjie installed.

Next steps:
  1. Log out of Hyprland and back in (so env vars + autostart apply),
     or run `fcitx5 -d -r` now to start it in this session.
  2. Run `fcitx5-configtool`, click "+", uncheck "Only Show Current
     Language", search "Cangjie", and add "Cangjie 5" (or "Cangjie 3" if
     you prefer the older table).
  3. Toggle input methods with the fcitx5 default shortcut (Ctrl+Space),
     or set your own in fcitx5-configtool > Global Options.
EOF
