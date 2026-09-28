#!/bin/bash

# ------------------------------------------------------------
# Random Wallpaper Picker (Across All Categories)
# ------------------------------------------------------------

WALL_ROOT="$HOME/Pictures/wallpapers/"
CACHE_FILE="$HOME/.cache/current_wallpaper"
BRAVE_FILE="$HOME/.cache/current_wallpaper.png"
SDDM_FILE="/usr/share/sddm/themes/hyprlock-match/backgrounds/wall.png"


# Find a random .png file from any subcategory directory
wall=$(find "$WALL_ROOT" -mindepth 2 -type f -name "*.png" | shuf -n 1)

# Ensure a wallpaper was found before proceeding
if [ -z "$wall" ]; then
    notify-send "Random Wallpaper" "No PNG wallpapers found in $WALL_ROOT"
    exit 1
fi

# Generating colors (pywal + matugen via shared helper)
"$(dirname "$0")/apply-theme.sh" "$wall"

# ------------------------------------------------------------
# Reload Eww (if running)
# ------------------------------------------------------------
if pgrep -x "eww" > /dev/null; then
    eww -c "$HOME/.config/eww/visualizer" reload
    eww -c "$HOME/.config/eww/lyrics" reload
fi

# Setting wallpaper
awww img "$wall" --transition-type any --transition-step 90 --transition-fps 60

notify-send "Wallpaper Changed"

# Copying Selected wallpaper to .cache as current wallpaper
cp "$wall" "$CACHE_FILE"
cp "$wall" "$BRAVE_FILE"
# Optional login-manager theme sync (only when that theme directory exists)
[ -d "$(dirname "$SDDM_FILE")" ] && cp "$wall" "$SDDM_FILE" 2>/dev/null || true


# ------Spotify--------

# Getting theme name
# theme=$(spicetify config current_theme)
# pywal-spicetify "$theme"
#
