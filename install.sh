#!/usr/bin/env bash
# Fresh Arch -> working Hyprland desktop (one-script installer).
#
# Installs ONLY the Hyprland + Hyprlock + Quickshell environment:
#   Hyprland, Hyprlock (+config), Quickshell (+config), the Hyprland
#   configuration, supporting system packages/services, desktop scripts,
#   wallpaper/theme pipeline, and Wayland portal integration.
#
# Waybar is explicitly OUT OF SCOPE (not installed, not configured).
#
# Usage:
#   git clone https://github.com/xubmxd/dotfiles.git ~/dotfiles
#   cd ~/dotfiles
#   ./install.sh [options]
#
#   USERNAME=myuser ./install.sh     # explicit target user (default: auto)
#
# Options:
#   --yes                    non-interactive (assume yes)
#   --no-aur                 skip AUR helper bootstrap + AUR packages
#                            (pywal, lyricsmpris source, emoji modi)
#   --deploy-only            skip package/service steps; only deploy configs +
#                            theming bootstrap + verification (fast re-apply)
#   --display-manager=DM     login manager: ly | none (default: none — TTY
#                            login, then `uwsm start hyprland-uwsm.desktop`)
#   -h, --help               show this help
#
# Idempotent: safe to re-run. Existing configs are backed up (timestamped)
# under ~/.local/share/dotfiles-backups/ before being touched.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/dotfiles-install.log}"
: > "$LOG_FILE"

# ------------------------------------------------------------------ flags
ASSUME_YES=0
WITH_AUR=1
DEPLOY_ONLY=0
DISPLAY_MANAGER="none"

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=1 ;;
    --no-aur) WITH_AUR=0 ;;
    --deploy-only) DEPLOY_ONLY=1 ;;
    --display-manager=*) DISPLAY_MANAGER="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[-] unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
  shift
done

case "$DISPLAY_MANAGER" in
  none|ly) ;;
  *) echo "[-] --display-manager must be ly or none" >&2; exit 1 ;;
esac

# ------------------------------------------------------------------ logging
msg()  { printf '\033[1;32m[+] %s\033[0m\n' "$*" | tee -a "$LOG_FILE"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" | tee -a "$LOG_FILE" >&2; }
err()  { printf '\033[1;31m[-] %s\033[0m\n' "$*" | tee -a "$LOG_FILE" >&2; exit 1; }
log()  { printf '%s\n' "$*" >> "$LOG_FILE"; }

# ------------------------------------------------------------------ user
# Explicit USERNAME= wins, then the sudo-invoking user, then the first human
# account (UID 1000..59999). Never silently configure root.
USERNAME="${USERNAME:-${SUDO_USER:-${USER:-}}}"
if [[ -z "${USERNAME:-}" || "$USERNAME" == "root" ]]; then
  USERNAME="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd 2>/dev/null || true)"
fi
[[ -n "${USERNAME:-}" && "$USERNAME" != "root" ]] \
  || err "cannot detect non-root user; re-run as USERNAME=youruser ./install.sh"
id "$USERNAME" >/dev/null 2>&1 || err "user '$USERNAME' does not exist"
# Resolve HOME from the account database — never assume /home/<name>.
HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6)"
[[ -n "$HOME_DIR" && -d "$HOME_DIR" ]] || err "home directory for '$USERNAME' not found"
USER_ID="$(id -u "$USERNAME")"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME_DIR/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME_DIR/.cache}"
CONFIG_DIR="$HOME_DIR/.config"

msg "Target user : $USERNAME"
msg "Home        : $HOME_DIR"
msg "Repo        : $REPO_DIR"
log "date: $(date -u +%FT%TZ) user=$USERNAME home=$HOME_DIR repo=$REPO_DIR"

run_as_user() {
  # Run a command as the target user (never as root): needed for makepkg/yay
  # and user-scoped setup. Preserves the user's HOME.
  if [[ $EUID -eq 0 ]]; then
    su -s /bin/bash "$USERNAME" -c "export HOME='$HOME_DIR'; $*"
  elif [[ "$(id -un)" == "$USERNAME" ]]; then
    bash -c "export HOME='$HOME_DIR'; $*"
  elif command -v sudo >/dev/null; then
    sudo -u "$USERNAME" env HOME="$HOME_DIR" bash -c "$*"
  else
    err "cannot run user-level commands for $USERNAME (no sudo)"
  fi
}

srun() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# ------------------------------------------------------------------ helpers
BACKUP_ROOT="$HOME_DIR/.local/share/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
AUR_FAILED=()

# trees_match <repo-dir> <target-dir>: true when every repo file exists in the
# target with identical content (extra target files are tolerated).
trees_match() {
  local src="$1" dst="$2" rel
  [[ -d "$dst" ]] || return 1
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    [[ -f "$dst/$rel" ]] || return 1
    cmp -s "$src/$rel" "$dst/$rel" || return 1
  done < <(cd "$src" && find . -type f | sort)
  return 0
}

backup_path() {
  # backup_path <absolute-path>: move existing file/dir to the backup root.
  local target="$1"
  [[ -e "$target" || -L "$target" ]] || return 0
  local rel="${target#$HOME_DIR/}"
  local dest="$BACKUP_ROOT/$rel"
  msg "Backing up $target -> $dest"
  run_as_user "mkdir -p '$(dirname "$dest")' && mv '$target' '$dest'" >>"$LOG_FILE" 2>&1
}

# pkg_names <list-file>: package names only (strips trailing comments/blank lines).
pkg_names() { sed 's/#.*//' "$1" | grep -v '^\s*$' | tr '\n' ' '; }

CORE_LIST="$REPO_DIR/installer/packages-hyprland.txt"
AUR_LIST="$REPO_DIR/installer/packages-hyprland-aur.txt"

# Config trees managed by this installer (Waybar deliberately excluded).
MANAGED_DIRS="hypr quickshell wal rofi foot xdg-desktop-portal uwsm matugen"

IN_PLACE=0
[[ "$REPO_DIR" == "$CONFIG_DIR" ]] && IN_PLACE=1

# ================================================================ [1/8] system
msg "[1/8] Checking system…"
command -v pacman >/dev/null || err "pacman not found — this installer supports Arch Linux only"
if [[ ! -f /etc/arch-release && ! -f /etc/artix-release ]]; then
  warn "not visibly an Arch system; continuing anyway (pacman present)"
fi
if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null; then
  err "run as root or install sudo first"
fi
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || warn "no network? continuing anyway (log: $LOG_FILE)"
[[ -f "$CORE_LIST" ]] || err "missing $CORE_LIST"
[[ -f "$AUR_LIST" ]] || warn "missing $AUR_LIST — AUR step will be skipped"
if [[ $IN_PLACE -eq 1 ]]; then
  msg "Repo IS ~/.config — in-place mode (no copy, machine files untouched)"
else
  msg "Repo will be deployed into $CONFIG_DIR"
fi

if [[ $DEPLOY_ONLY -eq 0 ]]; then

# ================================================================ [2/8] packages
msg "[2/8] Installing official packages (Hyprland environment only)…"
# shellcheck disable=SC2046
srun pacman -S --needed --noconfirm $(pkg_names "$CORE_LIST") >>"$LOG_FILE" 2>&1 \
  || err "official package installation failed (see $LOG_FILE)"

# ================================================================ [3/8] AUR
if [[ $WITH_AUR -eq 1 && -f "$AUR_LIST" ]]; then
  if ! command -v yay >/dev/null && ! run_as_user "command -v yay" >/dev/null; then
    msg "[3/8] Bootstrapping yay-bin (built as $USERNAME, never as root)…"
    srun pacman -S --needed --noconfirm base-devel git curl >>"$LOG_FILE" 2>&1 \
      || err "could not install base-devel/git/curl"
    run_as_user 'tmp="$(mktemp -d)" && git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" >>"'"$LOG_FILE"'" 2>&1 && (cd "$tmp/yay-bin" && makepkg -si --noconfirm >>"'"$LOG_FILE"'" 2>&1) && rm -rf "$tmp"' \
      || err "yay bootstrap failed (see $LOG_FILE)"
  else
    msg "[3/8] yay already available"
  fi
  msg "Installing AUR packages (each failure is logged, install continues)…"
  AUR_FAILED=()
  while read -r pkg _; do
    pkg="${pkg%%#*}"; pkg="$(echo "$pkg" | xargs)"
    [[ -z "$pkg" ]] && continue
    run_as_user "yay -S --needed --noconfirm '$pkg'" >>"$LOG_FILE" 2>&1 \
      || { warn "AUR package failed: $pkg"; AUR_FAILED+=("$pkg"); }
  done < <(grep -v '^\s*#' "$AUR_LIST" | grep -v '^\s*$')
  [[ ${#AUR_FAILED[@]} -eq 0 ]] || warn "failed AUR packages: ${AUR_FAILED[*]}"
else
  msg "[3/8] Skipping AUR packages"
fi

# ------------------------------------------------- display manager (opt-in only)
case "$DISPLAY_MANAGER" in
  ly)
    msg "Installing/enabling ly…"
    srun pacman -S --needed --noconfirm ly >>"$LOG_FILE" 2>&1 || true
    srun systemctl enable ly@tty2.service >>"$LOG_FILE" 2>&1 \
      || warn "ly enable failed — enable a login manager manually"
    ;;
  none) msg "No display manager (log in on TTY, then start Hyprland via uwsm)" ;;
esac

# ------------------------------------------------- system + user services
msg "Enabling required services…"
for svc in NetworkManager.service bluetooth.service; do
  if systemctl list-unit-files --no-legend 2>/dev/null | grep -q "^${svc%%.*}"; then
    srun systemctl enable "$svc" >>"$LOG_FILE" 2>&1 || warn "could not enable $svc"
  else
    log "service unit not installed, skipping: $svc"
  fi
done
# User services: best-effort outside a login session, with a follow-up command.
USER_SERVICES="pipewire.service pipewire-pulse.service wireplumber.service xdg-user-dirs.service pipewire.socket pipewire-pulse.socket"
if ! run_as_user "XDG_RUNTIME_DIR='/run/user/$USER_ID' systemctl --user enable $USER_SERVICES" >>"$LOG_FILE" 2>&1; then
  warn "user services could not be enabled non-interactively; after first login run:"
  warn "  systemctl --user enable $USER_SERVICES"
fi

fi # end DEPLOY_ONLY package/service skip

# ================================================================ [4/8] configs
msg "[4/8] Deploying Hyprland environment configuration…"
run_as_user "mkdir -p '$CONFIG_DIR' '$HOME_DIR/Pictures/wallpapers' '$HOME_DIR/Pictures/gifs' '$HOME_DIR/.local/bin'" >>"$LOG_FILE" 2>&1

if [[ $IN_PLACE -eq 1 ]]; then
  msg "Repo IS ~/.config — configs already in place, skipping copy"
else
  for d in $MANAGED_DIRS; do
    [[ -d "$REPO_DIR/$d" ]] || { log "not in repo, skipping: $d"; continue; }
    if [[ -e "$CONFIG_DIR/$d" || -L "$CONFIG_DIR/$d" ]]; then
      if trees_match "$REPO_DIR/$d" "$CONFIG_DIR/$d"; then
        log "identical, skipping: $d"
        continue
      fi
      backup_path "$CONFIG_DIR/$d"
    fi
    run_as_user "mkdir -p '$CONFIG_DIR/$d' && cp -a '$REPO_DIR/$d/.' '$CONFIG_DIR/$d/'" >>"$LOG_FILE" 2>&1 \
      || warn "deploy failed for $d"
  done
fi

# Portable monitor defaults: the repo's monitors.lua targets one specific
# panel (eDP-1 1080p@1.25). On a fresh machine that would misconfigure (or
# blank) other displays, so a copied install gets "no forced modes" while an
# in-place run keeps the owner's file untouched.
if [[ $IN_PLACE -eq 0 ]]; then
  MON_LUA="$CONFIG_DIR/hypr/source-configs/monitors.lua"
  PORTABLE='-- Generated by install.sh: portable default — no forced modes.
-- Hyprland auto-configures every connected output (preferred mode).
-- Run `hyprctl monitors`, then pin a specific output here if desired.

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
    cursor = {
        no_hardware_cursors = false,
        no_warps = false,
    },
})
'
  if [[ -f "$MON_LUA" ]] && ! grep -q 'Generated by install.sh' "$MON_LUA" 2>/dev/null; then
    backup_path "$MON_LUA"
  fi
  run_as_user "mkdir -p '$CONFIG_DIR/hypr/source-configs' && cat > '$MON_LUA' <<'EOF'
$PORTABLE
EOF" >>"$LOG_FILE" 2>&1
  log "wrote portable monitors.lua"
else
  log "in-place mode: monitors.lua left untouched"
fi

# lyricsmpris backend for quickshell/services/LyricsService.qml, which execs
# it via the absolute path ~/.local/bin/lyricsmpris. The binary ships with
# the AUR `tide-island` package — link it when available.
if [[ -x /usr/share/tide-island/bin/lyricsmpris ]]; then
  if [[ -x "$HOME_DIR/.local/bin/lyricsmpris" && ! -L "$HOME_DIR/.local/bin/lyricsmpris" ]]; then
    log "lyricsmpris already present (real file), leaving it"
  else
    run_as_user "ln -sfn '/usr/share/tide-island/bin/lyricsmpris' '$HOME_DIR/.local/bin/lyricsmpris'" >>"$LOG_FILE" 2>&1
    msg "Linked ~/.local/bin/lyricsmpris (lyrics backend)"
  fi
else
  warn "lyricsmpris source missing (AUR tide-island not installed?) — lyrics pill will stay idle"
fi

# Executable bits on helper scripts (idempotent; never rely on git file modes).
run_as_user "chmod +x '$CONFIG_DIR/hypr/scripts/'*.sh '$CONFIG_DIR/hypr/scripts/emoji-picker' '$CONFIG_DIR/hypr/scripts/pywal-startup-script' 2>/dev/null" >>"$LOG_FILE" 2>&1 || true
if [[ $IN_PLACE -eq 0 ]]; then
  chmod +x "$REPO_DIR/install.sh" 2>/dev/null || true
fi

# ================================================================ [5/8] theming
msg "[5/8] Bootstrapping wallpaper + pywal/matugen colors…"
# hyprland.conf sources ~/.cache/wal/colors-hyprland.conf and quickshell reads
# ~/.cache/wal/colors.json — both only exist after `wal` runs once. Guarantee
# that here so a fresh install never boots unthemed.
run_as_user "XDG_RUNTIME_DIR='/run/user/$USER_ID' xdg-user-dirs-update 2>/dev/null || true" >>"$LOG_FILE" 2>&1 || true
SEED=""
for cand in "$HOME_DIR/Pictures/wallpapers"/*/*.png "$HOME_DIR/Pictures/wallpapers"/*.png; do
  [[ -f "$cand" ]] && { SEED="$cand"; break; }
done
if [[ -z "$SEED" ]]; then
  SEED="$XDG_CACHE_HOME/hypr-default-wallpaper.png"
  if [[ ! -f "$SEED" ]]; then
    msg "No wallpapers found — generating a neutral fallback"
    run_as_user "ffmpeg -y -loglevel error -f lavfi -i 'color=c=0x1a1b26:s=1920x1080' -frames:v 1 '$SEED'" >>"$LOG_FILE" 2>&1 \
      || warn "fallback wallpaper generation failed"
  fi
fi
if [[ -f "$SEED" ]]; then
  if [[ ! -f "$XDG_CACHE_HOME/wal/colors-hyprland.conf" || ! -f "$XDG_CACHE_HOME/wal/colors.json" ]]; then
    run_as_user "'$CONFIG_DIR/hypr/scripts/apply-theme.sh' '$SEED'" >>"$LOG_FILE" 2>&1 \
      || warn "initial theming run failed — colors generate on first wallpaper change"
    run_as_user "cp '$SEED' '$XDG_CACHE_HOME/current_wallpaper' 2>/dev/null; cp '$SEED' '$XDG_CACHE_HOME/current_wallpaper.png' 2>/dev/null" >>"$LOG_FILE" 2>&1 || true
  else
    log "pywal colors already present, skipping initial theming"
  fi
else
  warn "no seed wallpaper available — add images to ~/Pictures/wallpapers/"
fi

# ================================================================ [6/8] login
msg "[6/8] Login/session…"
if [[ "$DISPLAY_MANAGER" == "ly" ]]; then
  msg "Login manager: ly (enabled above)"
else
  msg "Login: TTY, then run: uwsm start hyprland-uwsm.desktop   (or: Hyprland)"
fi

# ================================================================ [7/8] verify
msg "[7/8] Verifying installation…"
ERRORS=0
check_bin() { # check_bin <binary> <required-by>
  if command -v "$1" >/dev/null 2>&1; then log "ok: binary $1 ($2)";
  else warn "missing: $1 (required by $2)"; ERRORS=$((ERRORS + 1)); fi
}
check_file() { # check_file <path> <required-by>
  if [[ -e "$1" ]]; then log "ok: $1 ($2)";
  else warn "missing: $1 (required by $2)"; ERRORS=$((ERRORS + 1)); fi
}

check_bin Hyprland "hypr/hyprland.lua (compositor)"
check_bin hyprlock "hypr/hyprlock.conf, keybinds ALT+L, quickshell PowerMenu"
check_bin hypridle "hypr/hypridle.conf, autostarts.lua"
check_bin hyprctl "hypr scripts, keybinds, verification"
check_bin quickshell "quickshell/shell.qml (qs == quickshell)"
check_bin qs "hypr dynamic_keybinds.lua (qs ipc …)"
check_bin rofi "programs.lua menu, wallpaper/gif/emoji pickers"
check_bin foot "programs.lua terminal, mewsic-toggle.sh"
check_bin thunar "programs.lua fileManager"
check_bin wal "wallpaper scripts, colors-hyprland.conf/colors.json generation"
check_bin matugen "wallpaper scripts (gtk/kvantum/rofi themes)"
check_bin awww "startup.sh, wallpaper-backend.sh (wallpaper daemon)"
check_bin grim "keybinds Print-screen bindings"
check_bin slurp "keybinds region-screenshot bindings"
check_bin swappy "keybinds ALT+Print binding"
check_bin wl-copy "keybinds screenshot-to-clipboard bindings"
check_bin notify-send "wallpaper/screenshot feedback (libnotify)"
check_bin brightnessctl "brightness keys, quickshell brightness OSD"
check_bin playerctl "media keys, gestures"
check_bin wpctl "volume keybinds (pipewire)"
check_bin nmcli "quickshell Dashboard wifi UI (networkmanager)"
check_bin ffmpeg "wallpaper reindex conversion"
check_bin gnome-keyring-daemon "autostarts.lua secret store"
check_bin hyprpolkitagent "autostarts.lua privilege prompts"
check_bin dbus-update-activation-environment "autostarts.lua wayland env"
check_bin systemctl "autostarts.lua, PowerMenu actions"
check_bin loginctl "hypridle.conf lock/sleep commands"

check_file "$CONFIG_DIR/hypr/hyprland.lua" "Hyprland lua entry point"
check_file "$CONFIG_DIR/hypr/hyprlock.conf" "hyprlock configuration"
check_file "$CONFIG_DIR/hypr/hypridle.conf" "hypridle configuration"
check_file "$CONFIG_DIR/hypr/source-configs/monitors.lua" "hyprland.lua monitors require"
check_file "$CONFIG_DIR/hypr/source-configs/programs.lua" "hyprland.lua programs require"
check_file "$CONFIG_DIR/hypr/source-configs/autostarts.lua" "hyprland.lua autostart require"
check_file "$CONFIG_DIR/hypr/source-configs/statusbar.lua" "hyprland.lua statusbar require (launches quickshell)"
check_file "$CONFIG_DIR/quickshell/shell.qml" "quickshell entry point"
check_file "$CONFIG_DIR/rofi/launcher.rasi" "programs.lua menu theme"
check_file "$CONFIG_DIR/foot/foot.ini" "foot configuration"
check_file "$CONFIG_DIR/xdg-desktop-portal/hyprland-portals.conf" "portal backend selection"
check_file "$XDG_CACHE_HOME/wal/colors-hyprland.conf" "sourced by hyprland.conf"
check_file "$XDG_CACHE_HOME/wal/colors.json" "read by quickshell/shell.qml"

# Optional integrations: warned about, never fatal.
for opt in "cool-retro-term:keybind CTRL+SHIFT+RETURN" "hyprshutdown:keybind SUPER+SHIFT+Q fallback" \
           "eww:legacy widget reload hooks in wallpaper scripts" "spicetify:commented spotify theming"; do
  bin="${opt%%:*}"; by="${opt##*:}"
  command -v "$bin" >/dev/null 2>&1 && log "ok (optional): $bin" || log "optional, absent: $bin ($by)"
done
[[ -x "$HOME_DIR/.local/bin/lyricsmpris" ]] \
  && log "ok: ~/.local/bin/lyricsmpris (lyrics backend)" \
  || log "optional, absent: ~/.local/bin/lyricsmpris (lyrics pill stays idle)"
[[ -x "$HOME_DIR/.cargo/bin/mewsic_rs" ]] \
  && log "ok: mewsic_rs (SUPER+SHIFT+M)" \
  || log "optional, absent: mewsic_rs (SUPER+SHIFT+M has nothing to launch)"

# Validate the Hyprland configuration syntax without launching the compositor.
if run_as_user "HOME='$HOME_DIR' XDG_CONFIG_HOME='$CONFIG_DIR' timeout 60 Hyprland --verify-config" >>"$LOG_FILE" 2>&1; then
  grep -q "config ok" "$LOG_FILE" && log "Hyprland config parses cleanly" || log "verify-config ran (see log)"
else
  warn "Hyprland --verify-config reported errors (see $LOG_FILE)"
  ERRORS=$((ERRORS + 1))
fi

# ================================================================ [8/8] summary
msg "[8/8] Done."
{
echo ""
echo "=============== HYPR INSTALL SUMMARY ==============="
echo "User      : $USERNAME ($HOME_DIR)"
echo "Repo      : $REPO_DIR $([[ $IN_PLACE -eq 1 ]] && echo "(live ~/.config)" || echo "(copied into ~/.config)")"
echo "Display   : $DISPLAY_MANAGER"
echo "Backups   : $BACKUP_ROOT (only created when files were replaced)"
echo "Log       : $LOG_FILE"
echo "Validation errors: $ERRORS"
[[ ${#AUR_FAILED[@]} -gt 0 ]] && echo "Failed AUR pkgs: ${AUR_FAILED[*]}"
echo ""
echo "Installed: Hyprland, Hyprlock (+hypridle), Quickshell, portals,"
echo "  PipeWire/WirePlumber, NetworkManager, BlueZ, polkit agent,"
echo "  screenshot/clipboard tools, wallpaper pipeline (awww/wal/matugen),"
echo "  foot, thunar, rofi, fonts."
echo "Deployed: ~/.config/{hypr,quickshell,wal,rofi,foot,xdg-desktop-portal,uwsm,matugen}"
echo ""
echo "Next step:"
if [[ "$DISPLAY_MANAGER" == "ly" ]]; then
echo "  Reboot, log in via ly, select the Hyprland session."
else
echo "  Reboot, log in on TTY, then run: uwsm start hyprland-uwsm.desktop"
fi
echo "  (Wallpapers go in ~/Pictures/wallpapers/ — SUPER+apostrophe picks one.)"
echo "====================================================="
} | tee -a "$LOG_FILE"

if [[ $ERRORS -eq 0 ]]; then
  msg "Installation complete. Re-login, then start Hyprland."
else
  err "validation reported $ERRORS missing item(s) — see warnings above"
fi
