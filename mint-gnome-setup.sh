#!/usr/bin/env bash

set -e

########################################
# VARIABLES
########################################

USER_HOME="$HOME"
BIN_DIR="$USER_HOME/bin"

TERMINATOR_CONFIG_DIR="$USER_HOME/.config/terminator"
TERMINATOR_CONFIG_FILE="$TERMINATOR_CONFIG_DIR/config"

LINUTIL_CONFIG="$USER_HOME/linutil-config.toml"

BASIC_TOOLS=(gpg wget)

PACKAGES=(
  gnome-session
  gnome-control-center
  gnome-tweaks
  gnome-startup-applications
  gnome-shell-extensions
  nautilus
  terminator
  git
  zoxide
  fzf
  google-chrome-stable
  code
  trash-cli
  flameshot
  neovim
  devilspie2
  jq
)

########################################
# FUNCTIONS
########################################

install_nala() {
  echo
  echo
  echo "==> Installing nala..."
  sudo apt update -y
  sudo apt install -y nala
}

install_basic_tools() {
  echo
  echo
  echo "==> Installing basic tools..."
  sudo nala update
  sudo nala install -y "${BASIC_TOOLS[@]}"
}

setup_vscode_repo() {
  echo "==> Setting up VS Code repo (idempotent safe mode)..."

  # Remove all possible conflicting definitions
  sudo rm -f /etc/apt/sources.list.d/vscode.list
  sudo rm -f /etc/apt/sources.list.d/vscode.sources

  # Remove old keys (avoid mismatch conflicts)
  sudo rm -f /usr/share/keyrings/microsoft.gpg
  sudo rm -f /etc/apt/keyrings/microsoft.gpg

  # Recreate clean key
  sudo mkdir -p /etc/apt/keyrings

  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null

  # Recreate repo (single format only)
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
}

setup_chrome_repo() {
  if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
    echo
    echo
    echo "==> Setting up Google Chrome repo..."

    sudo mkdir -p /etc/apt/keyrings

    wget -qO- https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor | sudo tee /etc/apt/keyrings/google.gpg > /dev/null

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
      | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
  fi
}

install_packages() {
  echo
  echo
  echo "==> Installing packages..."
  sudo nala update
  sudo nala install -y "${PACKAGES[@]}"
}

remove_libreoffice() {
  echo
  echo
  echo "==> Removing LibreOffice..."
  sudo apt purge -y 'libreoffice*' || true
  sudo apt autoremove -y
}

########################################
# TERMINATOR (clean, no wrapper, no wmctrl)
########################################

setup_terminator() {
  echo
  echo
  echo "==> Configuring Terminator..."

  mkdir -p "$TERMINATOR_CONFIG_DIR"

  cat << 'EOF' > "$TERMINATOR_CONFIG_FILE"
[global_config]
window_state = maximise
enabled_plugins = LaunchpadBugURLHandler, LaunchpadCodeURLHandler, APTURLHandler, TerminatorThemes

[keybindings]

[profiles]
[[default]]
background_darkness = 0.9
background_type = transparent
font = MesloLGS Nerd Font Mono Italic 10
foreground_color = "#ffffff"
scrollback_infinite = True
use_system_font = False
title_transmit_bg_color = "#044a72"

[[VibrantInk]]
background_darkness = 0.9
background_type = transparent
cursor_bg_color = "#ffffff"
font = MesloLGS Nerd Font Mono Italic 10
foreground_color = "#ffffff"
scrollback_infinite = True
palette = "#878787:#ff6600:#ccff04:#ffcc00:#44b4cc:#9933cc:#44b4cc:#f5f5f5:#555555:#ff0000:#00ff00:#ffff00:#0000ff:#ff00ff:#00ffff:#e5e5e5"
use_system_font = False
title_transmit_bg_color = "#044a72"

[layouts]
[[default]]
[[[window0]]]
type = Window
parent = ""
[[[child1]]]
type = Terminal
parent = window0
profile = VibrantInk

[plugins]
EOF
}


setup_terminal_shortcut() {
  echo
  echo
  echo "==> Fixing terminal shortcut (Super+T)..."

  local BASE_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  local KEY_PATH="$BASE_PATH/custom0/"

  current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

  if [[ "$current" == "@as []" ]]; then
    new_list="['$KEY_PATH']"
  elif [[ "$current" != *"$KEY_PATH"* ]]; then
    new_list=$(echo "$current" | sed "s/]$/, '$KEY_PATH']/")
  else
    new_list="$current"
  fi

  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_list"

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH name 'Terminal'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command 'terminator'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding '<Super>t'
}

setup_devilspie2() {
  echo
  echo
  echo "==> Configuring devilspie2..."

  local CONF_DIR="$USER_HOME/.config/devilspie2"

  mkdir -p "$CONF_DIR"

  cat << 'EOF' > "$CONF_DIR/terminator.lua"
if string.find(get_application_name():lower(), "terminator") then
  maximize()
end
EOF

  mkdir -p "$USER_HOME/.config/autostart"

  cat << 'EOF' > "$USER_HOME/.config/autostart/devilspie2.desktop"
[Desktop Entry]
Type=Application
Exec=devilspie2
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Devilspie2
EOF
}

setup_linutil() {
  echo
  echo
  echo "==> Configuring Linutil..."

  cat << 'EOF' > "$LINUTIL_CONFIG"
auto_execute = [
"Bash Prompt",
"FastFetch"
]

skip_confirmation = true
size_bypass = true
EOF

  curl -fsSL https://christitus.com/linux | sudo sh -s -- -c "$LINUTIL_CONFIG" -y -s
}

upgrade_pkgs() {
  echo
  echo
  echo "==> Upgrading packages..."
  sudo nala full-upgrade -y
}

setup_browser_shortcut() {
  echo
  echo
  echo "==> Setting browser shortcut (Super+B)..."

  local BASE_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  local KEY_PATH="$BASE_PATH/custom1/"

  current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

  # remove @as [] formatting safely
  if [[ "$current" == "@as []" ]]; then
    new_list="['$KEY_PATH']"
  else
    # safer append using Python (avoids sed issues completely)
    new_list=$(python3 - <<EOF
import ast
current = ast.literal_eval("""$current""")
key = "$KEY_PATH"
if key not in current:
    current.append(key)
print(current)
EOF
)
  fi

  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_list"

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH name 'Browser'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command 'google-chrome'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding '<Super>b'
}

setup_gnome() {
  echo
  echo
  echo "==> Configuring GNOME (theme + UI behavior)..."

  # Dark mode
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

  # GTK theme
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

  # Icon theme (correct choice)
  gsettings set org.gnome.desktop.interface icon-theme 'Yaru-blue-dark'

  # Window buttons (only close)
  gsettings set org.gnome.desktop.wm.preferences button-layout ':close'

  # Enable antialiasing
  gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'

  # Hinting (improves sharpness on low-DPI displays)
  gsettings set org.gnome.desktop.interface font-hinting 'slight'

  # Subpixel order (most common: RGB)
  gsettings set org.gnome.desktop.interface font-rgba-order 'rgb'
}

setup_startup_apps() {
  echo
  echo
  echo "==> Setting up GNOME startup applications..."

  local AUTOSTART_DIR="$USER_HOME/.config/autostart"
  mkdir -p "$AUTOSTART_DIR"

  # Flameshot (if you want it at login)
  cat << 'EOF' > "$AUTOSTART_DIR/flameshot.desktop"
[Desktop Entry]
Type=Application
Exec=flameshot
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Flameshot
Comment=Screenshot tool
EOF
}


########################################
# MAIN
########################################

main() {
  install_nala
  install_basic_tools
  setup_vscode_repo
  setup_chrome_repo
  install_packages
  remove_libreoffice

  setup_terminator
  setup_terminal_shortcut
  setup_devilspie2
  
  setup_browser_shortcut
  setup_gnome
  upgrade_pkgs

  setup_linutil

  echo
  echo "==> Setup complete!"
}

main