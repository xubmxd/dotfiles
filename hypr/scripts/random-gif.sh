#!/bin/bash

# ------------------------------------------------------------
# Random Wallpaper Picker (Across All Categories)
# ------------------------------------------------------------

GIF_ROOT="/home/xubm/Pictures/gifs/"
CACHE_FILE="$HOME/.cache/current_wallpaper"
BRAVE_FILE="$HOME/.cache/current_wallpaper.png"

# Find a random .png file from any subcategory directory
gif=$(find "$GIF_ROOT" -type f -name "*.gif" | shuf -n 1)

# Ensure a gif was found before proceeding
if [ -z "$gif" ]; then
    notify-send "Random Gif" "No GIF wallpapers found in $WALL_ROOT"
    exit 1
fi

# Generating colors
wal -n -i "$gif" -o ~/.local/src/pywalium/generate.sh

# Color for gtk using matugen
matugen image "$gif" --source-color-index 0 --type scheme-vibrant

# ------------------------------------------------------------
# Reload Eww (if running)
# ------------------------------------------------------------
if pgrep -x "eww" > /dev/null; then
    eww -c "$HOME/.config/eww/visualizer" reload
    eww -c "$HOME/.config/eww/lyrics" reload
fi

# Setting wallpaper
awww img "$gif" --transition-type any --transition-step 90 --transition-fps 60

# Copying Selected wallpaper to .cache as current wallpaper
cp "$gif" "$CACHE_FILE"
cp "$gif" "$BRAVE_FILE"

# ------Spotify--------

# Getting theme name
# theme=$(spicetify config current_theme)
# pywal-spicetify "$theme"

