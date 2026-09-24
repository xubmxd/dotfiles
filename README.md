# dotfiles — sphynx (Arch + Hyprland)

Daily-driver config for `sphynx`: Arch Linux (systemd-boot, btrfs on NVMe),
Hyprland compositor, Intel TigerLake graphics. Shell is zsh
(oh-my-zsh, `bureau` theme) with fish also installed.

> **This repo IS `~/.config`.** It is cloned directly to `$HOME/.config`,
> not symlinked with stow.

## Fresh install

On a fresh Arch (archinstall base, systemd-boot, one user in `wheel`, internet):

```bash
git clone git@github.com:xubmxd/dotfiles.git ~/.config
cd ~/.config
chmod +x install.sh
./install.sh            # or: USERNAME=someuser ./install.sh
```

`install.sh` (tested in a clean `archlinux` container, idempotent, exits 0
on re-run) does:

1. Enables `multilib` + adds the **Chaotic-AUR** repo (keyring included)
2. Bootstraps `yay-bin`, installs `pkglist-desktop.txt` (repo packages)
   and `pkglist-aur.txt` (AUR packages)
3. Sets locale `en_US.UTF-8`, `KEYMAP=us`, hostname `sphynx`, NTP
4. Applies the touchpad fix to mkinitcpio
   (`MODULES=(i2c_hid i2c_hid_acpi hid_multitouch)`) and rebuilds initramfs
5. Enables the exact service set: NetworkManager, bluetooth, resolved,
   timesyncd, `paccache.timer`, `cups-lpd.socket`, `ly@tty2`, pipewire user units
6. Adds the user to `wheel,input,docker,video,…`, sets zsh as login shell,
   installs oh-my-zsh, enables docker, installs Flatpaks from `flatpak-list.txt`

Scope is the **desktop only** — no BlackArch pentest tools.

### Package lists

| File | Contents |
| --- | --- |
| `pkglist-desktop.txt` | 242 repo/chaotic packages (Hyprland stack, pipewire, browsers, editors, docker, …) |
| `pkglist-aur.txt` | 24 AUR packages (librewolf, matugen, waypaper, windscribe, …) |
| `flatpak-list.txt` | 5 Flatpak apps (Flatseal, Heroic, ProtonPlus, Lutris, Jellyfin) |

Regenerate from a live system with:

```bash
pacman -Qqe > pkglist-desktop.txt   # then drop AUR + pentest entries
pacman -Qqm > pkglist-aur.txt
flatpak list --app --columns=application > flatpak-list.txt
```

## What's configured

| Directory | App |
| --- | --- |
| `hypr/` | Hyprland (Lua-based config: `hyprland.lua` + `source-configs/`, helper `scripts/`) |
| `waybar/`, `eww/`, `hyprpanel/` | Bars / widgets |
| `rofi/`, `wofi/` | Launchers (`rofi-emoji-git` for emoji) |
| `foot/`, `kitty/` | Terminals |
| `fish/`, `zsh/` | Shells (active default: zsh + oh-my-zsh) |
| `nvim/`, `zed/` | Editors |
| `fastfetch/`, `btop/`, `cava/` | System info / monitors |
| `yazi/` | File manager (plus `dolphin/`, `thunar/`) |
| `vesktop/`, `discord/` | Chat |
| `spicetify/` | Spotify theming (pywal) |
| `swaync/`, `dunst/` | Notifications |
| `sddm/` config via `sddm-theme-corners-git` | Alt. login manager (not enabled; `ly` is) |

Display manager: boots to TTY, `ly@tty2` enabled; Hyprland starts from
there (uwsm available). `sddm` is installed as an alternative.

## Manual checklist (not scriptable)

Printed by `install.sh` at the end of every run:

- btrfs subvolumes `@ @home @pkg @log` with `compress=zstd:3` (see script output for fstab lines)
- systemd-boot kernel cmdline laptop quirks
  (`intel_pstate=disable … pcie_aspm=off`)
- `systemctl --user enable pipewire pipewire-pulse wireplumber` after first login
- Secrets are **not** in git: `~/.zshrc` API keys, `~/Desktop/ctfs/*.ovpn`,
  `~/.local/bin`, `~/.zprofile`, `~/.xprofile` — restore from backup

## Notes

- `.gitignore` excludes volatile app caches (vesktop GPU/blob caches, …).
  Browser profile dirs (`BraveSoftware/`, `Caido/`, …) are untracked on purpose.
- `pacman.conf` on the source also carries the **BlackArch** repo
  (`blackarch-mirrorlist`); it is intentionally *not* added by `install.sh`
  since the desktop scope excludes those tools.
