#!/usr/bin/env bash
# Arch Hyprland desktop — fresh-install replication script
# Source system: sphynx (archinstall 2026-03-18, systemd-boot, btrfs, Intel TigerLake, Hyprland)
# Scope: MINIMAL DESKTOP ONLY (no BlackArch pentest tools)
# Dotfiles: git@github.com:xubmxd/dotfiles.git (this repo IS ~/.config)
#
# Usage on a FRESH Arch (archinstall base + user in wheel + internet):
#   git clone <this-repo> ~/dotfiles-tmp
#   cd ~/dotfiles-tmp  # or copy install.sh + pkglist-*.txt + flatpak-list.txt together
#   chmod +x install.sh
#   ./install.sh
#
# Expected pre-conditions (do these in archinstall):
#   - partitions: 1G vfat /boot + btrfs rest with subvolumes @, @home, @pkg, @log
#     (mount opts: compress=zstd:3,ssd,discard=async,space_cache=v2 — see fstab note below)
#   - kernels: linux + linux-lts + intel-ucode, bootloader: systemd-boot
#   - user: created in archinstall; groups + shell are set by this script
#     (override detection with USERNAME=someuser ./install.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Target user: explicit USERNAME=foo override wins, then the sudo-invoking user,
# then first human account (UID>=1000). Never silently configure root.
USERNAME="${USERNAME:-${SUDO_USER:-${USER:-}}}"
if [[ -z "${USERNAME:-}" || "$USERNAME" == "root" ]]; then
  USERNAME="$(awk -F: '$3>=1000 && $3<60000 {print $1; exit}' /etc/passwd 2>/dev/null || true)"
fi
[[ -n "${USERNAME:-}" && "$USERNAME" != "root" ]] || { echo "[-] cannot detect non-root user; re-run as USERNAME=youruser ./install.sh" >&2; exit 1; }
HOME_DIR="/home/$USERNAME"

PACMAN_LIST="$SCRIPT_DIR/pkglist-desktop.txt"
AUR_LIST="$SCRIPT_DIR/pkglist-aur.txt"
FLATPAK_LIST="$SCRIPT_DIR/flatpak-list.txt"

msg()  { printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[1;31m[-] %s\033[0m\n' "$*" >&2; exit 1; }

require_root_or_sudo() {
  if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null || err "run as root or install sudo first"
  fi
}
srun() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# ---------------------------------------------------------------- 0. sanity
require_root_or_sudo
[[ -f "$PACMAN_LIST" ]] || err "missing $PACMAN_LIST"
[[ -f "$AUR_LIST" ]] || err "missing $AUR_LIST"
command -v pacman >/dev/null || err "not an Arch system"
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || warn "no internet? continuing anyway"

# ------------------------------------------------- 1. pacman conf + repos
msg "Configuring pacman (multilib, ParallelDownloads)…"
srun cp -n /etc/pacman.conf /etc/pacman.conf.bak 2>/dev/null || true
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
  if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    # uncomment the [multilib] block shipped by archinstall/ISO
    srun sed -i '/^#\[multilib\]/,/^#Include.*mirrorlist/{s/^#//}' /etc/pacman.conf
  else
    # minimal pacman.conf (e.g. docker images) has no multilib block at all
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | srun tee -a /etc/pacman.conf >/dev/null
  fi
fi
srun sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf || true
grep -q "^\[multilib\]" /etc/pacman.conf || warn "multilib not enabled — check /etc/pacman.conf manually"

msg "Adding Chaotic-AUR repo (needed for: ags-hyprpanel-git, brave-bin, eww, …)…"
if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
  srun pacman-key --init
  srun pacman-key --recv-keys 3056513887B78AEB --keyserver keyserver.ubuntu.com
  srun pacman-key --lsign-key 3056513887B78AEB
  srun pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' | srun tee -a /etc/pacman.conf >/dev/null
fi

msg "Syncing databases + upgrading base…"
srun pacman -Syyu --noconfirm

# ------------------------------------------------- 2. yay (AUR helper)
if ! command -v yay >/dev/null; then
  msg "Installing yay…"
  srun pacman -S --needed --noconfirm base-devel git curl
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
else
  msg "yay already installed"
fi

# ------------------------------------------------- 3. desktop packages (official + chaotic)
msg "Installing desktop packages from pkglist-desktop.txt ($(wc -l <"$PACMAN_LIST") pkgs)…"
# shellcheck disable=SC2046
srun pacman -S --needed --noconfirm $(grep -v '^\s*#' "$PACMAN_LIST" | grep -v '^\s*$' | tr '\n' ' ')

# ------------------------------------------------- 4. AUR packages
msg "Installing AUR packages from pkglist-aur.txt ($(wc -l <"$AUR_LIST") pkgs)…"
# shellcheck disable=SC2046
yay -S --needed --noconfirm $(grep -v '^\s*#' "$AUR_LIST" | grep -v '^\s*$' | tr '\n' ' ')

# ------------------------------------------------- 5. locale / time / hosts
msg "Locale, timezone, hosts…"
grep -q "^en_US.UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" | srun tee -a /etc/locale.gen >/dev/null
srun locale-gen
echo "LANG=en_US.UTF-8" | srun tee /etc/locale.conf >/dev/null
printf 'FONT=default8x16\nKEYMAP=us\n' | srun tee /etc/vconsole.conf >/dev/null
srun timedatectl set-ntp true 2>/dev/null || srun systemctl enable --now systemd-timesyncd.service 2>/dev/null || true
srun hostnamectl set-hostname sphynx 2>/dev/null || echo sphynx | srun tee /etc/hostname >/dev/null
grep -q "xubm.local" /etc/hosts || echo "127.0.1.1  sphynx.localdomain sphynx xubm.local" | srun tee -a /etc/hosts >/dev/null

# ------------------------------------------------- 6. mkinitcpio (touchpad modules from source)
msg "mkinitcpio touchpad modules + hooks (source: MODULES=i2c_hid i2c_hid_acpi hid_multitouch)…"
if [[ -f /etc/mkinitcpio.conf ]]; then
  srun cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak 2>/dev/null || true
  srun sed -i 's/^MODULES=.*/MODULES=( i2c_hid i2c_hid_acpi hid_multitouch )/' /etc/mkinitcpio.conf
  srun sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
  srun mkinitcpio -P
else
  msg "no /etc/mkinitcpio.conf found — skipping initramfs config"
fi

# ------------------------------------------------- 6b. zram (source: 4G zstd, active swap)
msg "zram config (matches source /etc/systemd/zram-generator.conf)…"
if command -v systemd-zram-generator >/dev/null || pacman -Q zram-generator 2>/dev/null | grep -q .; then
  printf '[zram0]\nzram-size = 4096\ncompression-algorithm = zstd\n' | srun tee /etc/systemd/zram-generator.conf >/dev/null
else
  warn "zram-generator not installed — skipping zram config"
fi

# ------------------------------------------------- 6c. bootloader kernel cmdline (laptop quirks)
# Source boot options, minus install-specific root=/rootflags:
#   zswap.enabled=0 intel_pstate=disable usbcore.autosuspend=-1 idle=nomwait
#   processor.max_cstate=1 i2c_designware.clocks_kd=1 pcie_aspm=off
QUIRKS="zswap.enabled=0 intel_pstate=disable usbcore.autosuspend=-1 idle=nomwait processor.max_cstate=1 i2c_designware.clocks_kd=1 pcie_aspm=off"
BOOTLOADER="${BOOTLOADER:-auto}"
if [[ "$BOOTLOADER" == "auto" ]]; then
  if [[ -f /etc/default/grub ]]; then BOOTLOADER=grub
  elif compgen -G "/boot/loader/entries/*.conf" > /dev/null; then BOOTLOADER=systemd-boot
  else BOOTLOADER=none
  fi
fi
case "$BOOTLOADER" in
  grub)
    msg "GRUB detected — merging laptop quirks into GRUB_CMDLINE_LINUX_DEFAULT…"
    srun pacman -S --needed --noconfirm grub efibootmgr os-prober
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
      line="$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)"
      current="${line#*=}"; current="${current#\"}"; current="${current%\"}"
      # shellcheck disable=SC2086
      for q in $QUIRKS; do [[ "$current" == *"$q"* ]] || current="$current $q"; done
      srun sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$current\"|" /etc/default/grub
    else
      echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$QUIRKS\"" | srun tee -a /etc/default/grub >/dev/null
    fi
    # os-prober finds Windows on dual boot (disabled by default in recent GRUB)
    if grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
      srun sed -i 's|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub
    else
      echo 'GRUB_DISABLE_OS_PROBER=false' | srun tee -a /etc/default/grub >/dev/null
    fi
    srun grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed — rerun manually: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    ;;
  systemd-boot)
    msg "systemd-boot detected — patching entry options with laptop quirks…"
    # shellcheck disable=SC2086
    for entry in /boot/loader/entries/*.conf; do
      for q in $QUIRKS; do
        grep -Fq -- "$q" "$entry" || srun sed -i "/^options / s|$| $q|" "$entry"
      done
    done
    ;;
  *)
    warn "no bootloader config found (BOOTLOADER=$BOOTLOADER) — add kernel quirks manually (see checklist)"
    ;;
esac

# ------------------------------------------------- 7. services (exact enabled set from source)
msg "Enabling system services…"
srun systemctl enable NetworkManager.service NetworkManager-dispatcher.service bluetooth.service \
  systemd-resolved.service systemd-timesyncd.service paccache.timer cups-lpd.socket 2>/dev/null || true
# display manager: source boots to TTY (neither ly nor sddm was enabled).
# Enable ly (lightweight, config lives in dotfiles-adjacent /etc/ly). Swap for sddm if you prefer it.
srun systemctl enable ly@tty2.service 2>/dev/null || warn "ly enable failed — enable ly or sddm manually"
#  ^ alternative: sudo systemctl enable sddm.service

msg "Enabling user services (pipewire audio — exact set from source)…"
srun -u "$USERNAME" systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service \
  xdg-user-dirs.service pipewire.socket pipewire-pulse.socket 2>/dev/null || \
  warn "user services need one login as $USERNAME, then re-run: systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service xdg-user-dirs.service pipewire.socket pipewire-pulse.socket"

# ------------------------------------------------- 8. user groups + shell
msg "Groups + zsh shell for $USERNAME…"
for grp in wheel input docker video audio storage power network; do
  if getent group "$grp" >/dev/null; then
    srun usermod -aG "$grp" "$USERNAME"
  else
    warn "group $grp does not exist (package not installed?) — skipping"
  fi
done
command -v zsh >/dev/null && srun chsh -s /usr/bin/zsh "$USERNAME" || warn "zsh missing?"
if [[ ! -d "$HOME_DIR/.oh-my-zsh" ]]; then
  if command -v zsh >/dev/null; then
    msg "Installing oh-my-zsh (theme: bureau, plugin: git)…"
    srun -u "$USERNAME" sh -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' \
      || warn "oh-my-zsh install failed — re-run this step manually later"
  else
    warn "skipping oh-my-zsh — zsh not installed yet"
  fi
fi

# ------------------------------------------------- 9. docker
if command -v docker >/dev/null; then
  msg "Enabling docker…"
  srun systemctl enable --now docker.socket 2>/dev/null || srun systemctl enable --now docker.service 2>/dev/null || true
fi

# ------------------------------------------------- 10. flatpak apps
if [[ -f "$FLATPAK_LIST" ]] && command -v flatpak >/dev/null; then
  msg "Installing Flatpaks…"
  srun flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  while read -r app _; do
    [[ -z "$app" || "$app" == \#* ]] && continue
    srun flatpak install -y flathub "$app"
  done < "$FLATPAK_LIST"
fi

# ------------------------------------------------- 11. dotfiles (this repo IS ~/.config)
msg "Dotfiles…"
if [[ "$SCRIPT_DIR" != "$HOME_DIR/.config" ]]; then
  warn "script not running from ~/.config — syncing tracked files to $HOME_DIR/.config"
  srun -u "$USERNAME" mkdir -p "$HOME_DIR/.config"
  # copy only versioned essentials; full restore = git clone git@github.com:xubmxd/dotfiles.git ~/.config
  echo "  Full restore: git clone git@github.com:xubmxd/dotfiles.git $HOME_DIR/.config"
else
  msg "~/.config is already the dotfiles repo — pulling latest"
  srun -u "$USERNAME" git -C "$HOME_DIR/.config" pull --ff-only 2>/dev/null || warn "git pull failed (offline or dirty tree)"
fi
# shell extras live outside ~/.config — recreate symlinks/notes:
#   ~/.zshrc, ~/.zprofile (PATH+=~/.local/bin), ~/.xprofile (touchpad), ~/.xinitrc (dwm legacy)
warn "~/.zshrc / ~/.zprofile / ~/.local/bin are NOT in ~/.config — copy them from backup if needed"

# ------------------------------------------------- 12. leftover manual notes
cat <<'EOF'

================ MANUAL CHECKLIST (not scriptable) ================
1. fstab (btrfs subvolumes, source):
     UUID=<nvme0n1p2> /     btrfs rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@ 0 0
     UUID=<nvme0n1p2> /home btrfs rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@home 0 0
     UUID=<nvme0n1p2> /var/cache/pacman/pkg btrfs …subvol=/@pkg 0 0
     UUID=<nvme0n1p2> /var/log btrfs …subvol=/@log 0 0
     UUID=<boot>      /boot vfat defaults 0 2
2. Kernel cmdline quirks are merged automatically (GRUB: /etc/default/grub;
   systemd-boot: /boot/loader/entries/*.conf). Verify with: cat /proc/cmdline
   Dual-boot notes: do NOT format the existing EFI partition (mount it at /boot),
   disable Windows Fast Startup, and if the clock drifts set Windows to UTC
   or run: timedatectl set-local-rtc 1. BitLocker may ask for recovery key
   after boot-entry changes — have it ready.
3. Login once as user, then: systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service xdg-user-dirs.service pipewire.socket pipewire-pulse.socket
   (verify audio: wpctl status — sinks come from pipewire-audio + alsa-ucm-conf, both installed)
4. Groups take effect after re-login. Docker without sudo needs re-login too.
5. Interactive logins (not scriptable): sudo tailscale up, proton-vpn-gtk-app login, windscribe login.
   ly@tty2 is enabled (ly ships only the ly@.service template — instance on tty2 is correct).
   If no login prompt: sudo systemctl enable sddm.service instead.
5. Secrets in ~/.zshrc (GROQ_API_KEY) and VPN profiles (~/Desktop/ctfs/*.ovpn)
   are NOT in git — restore from backup.
6. Full package manifests for audit: pacman -Qqe / -Qqm / flatpak list
===================================================================
EOF
msg "Done. Reboot, log in, run: Hyprland (via ly/TTY/uwsm)"
