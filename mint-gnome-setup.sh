#!/usr/bin/env bash

set -e

########################################
# VARIABLES
########################################

USER_HOME="$HOME"
BIN_DIR="$USER_HOME/bin"
WRAPPER="$BIN_DIR/terminator-max"
SYSTEM_WRAPPER="/usr/local/bin/terminator-max"

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
  wmctrl
  google-chrome-stable
  code
  trash-cli
  flameshot
  neovim
)

########################################
# FUNCTIONS
########################################

install_nala() {
  echo "==> Installing nala..."
  sudo apt update -y
  sudo apt install -y nala
}

install_basic_tools() {
  echo "==> Installing basic tools..."
  sudo nala update
  sudo nala install -y "${BASIC_TOOLS[@]}"
}

setup_vscode_repo() {
  if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
    echo "==> Setting up VS Code repo..."

    sudo mkdir -p /etc/apt/keyrings

    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  fi
}

setup_chrome_repo() {
  if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
    echo "==> Setting up Google Chrome repo..."

    sudo mkdir -p /etc/apt/keyrings

    wget -qO- https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor | sudo tee /etc/apt/keyrings/google.gpg > /dev/null

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
      | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
  fi
}

install_packages() {
  echo "==> Installing packages..."
  sudo nala update
  sudo nala install -y "${PACKAGES[@]}"
}

remove_libreoffice() {
  echo "==> Removing LibreOffice..."
  sudo apt purge -y 'libreoffice*' || true
  sudo apt autoremove -y
}

setup_terminator() {
  echo "==> Configuring Terminator..."

  mkdir -p "$BIN_DIR"

  cat << 'EOF' > "$WRAPPER"
#!/usr/bin/env bash
terminator -e "bash -c 'wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz; exec bash'"
EOF

  chmod +x "$WRAPPER"

  # Make wrapper global
  sudo ln -sf "$WRAPPER" "$SYSTEM_WRAPPER"

  # Register + force as default terminal
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$SYSTEM_WRAPPER" 100
  sudo update-alternatives --set x-terminal-emulator "$SYSTEM_WRAPPER"

  # Optional (won’t hurt, sometimes helps)
  gsettings set org.gnome.desktop.default-applications.terminal exec "$SYSTEM_WRAPPER" || true
  gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-x' || true

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

[[PaulMillr]]
background_darkness = 0.9
background_type = transparent
cursor_bg_color = "#4d4d4d"
font = MesloLGS Nerd Font Mono Italic 10
foreground_color = "#f2f2f2"
scrollback_infinite = True
palette = "#2a2a2a:#ff0000:#79ff0f:#e7bf00:#396bd7:#b449be:#66ccff:#bbbbbb:#666666:#ff0080:#66ff66:#f3d64e:#709aed:#db67e6:#7adff2:#ffffff"
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

setup_linutil() {
  echo "==> Configuring Linutil..."

  cat << 'EOF' > "$LINUTIL_CONFIG"
auto_execute = [
"Bash Prompt",
"FastFetch"
]

skip_confirmation = true
size_bypass = true
EOF

  curl -fsSL https://christitus.com/linux | sh -s -- -c "$LINUTIL_CONFIG" -y
}

upgrade_pkgs() {
  echo "==> Upgrading packages..."
  sudo nala upgrade -y
}

setup_terminal_shortcut() {
  echo "==> Fixing terminal shortcut (Super+T)..."

  local BASE_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  local KEY_PATH="$t/custom0/"

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
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH command 'x-terminal-emulator'
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEY_PATH binding '<Super>t'
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

  # Keep last (interactive)
  setup_linutil

  echo
  echo "==> Setup complete!"
  echo "👉 Re-login recommended."
}

main