#!/bin/bash
# Shared wallpaper-theming step used by all hypr wallpaper scripts.
#
#   apply-theme.sh <image>
#
# Runs pywal (with the optional pywalium hook when present) and matugen so
# every entry point produces the same generated files:
#   ~/.cache/wal/colors.json + colors-hyprland.conf (read by Hyprland/Quickshell)
#   matugen outputs (gtk, kvantum, rofi, ...)
#
# The pywalium hook lives outside this repo (~/.local/src/pywalium); on a
# fresh installation it does not exist yet, and `wal -o <missing>` exits
# non-zero — so it is only passed when executable.
set -u

WALL="${1:?usage: apply-theme.sh <image>}"
HOOK="$HOME/.local/src/pywalium/generate.sh"

if [ -x "$HOOK" ]; then
    wal -n -i "$WALL" -o "$HOOK"
else
    wal -n -i "$WALL"
fi

matugen image "$WALL" \
    --source-color-index 0 \
    --type scheme-vibrant
