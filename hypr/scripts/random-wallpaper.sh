#!/bin/bash

# ------------------------------------------------------------
# Random Wallpaper Picker (Across All Categories & GIFs)
# ------------------------------------------------------------

WALL_ROOT="/home/xubm/Pictures/wallpapers/"
CACHE_FILE="$HOME/.cache/current_wallpaper"
BRAVE_FILE="$HOME/.cache/current_wallpaper.png"

# Find a random .png or .gif file from any subcategory directory
wall=$(find "$WALL_ROOT" -mindepth 2 -type f \( -name "*.png" -o -name "*.gif" \) | shuf -n 1)

# Ensure a wallpaper was found before proceeding
if [ -z "$wall" ]; then
    notify-send "Random Wallpaper" "No PNG or GIF wallpapers found in $WALL_ROOT"
    exit 1
fi

# Setting wallpaper
awww img "$wall" --transition-type any --transition-step 90 --transition-fps 60

# Copying Selected wallpaper to .cache as current wallpaper
cp "$wall" "$CACHE_FILE"
cp "$wall" "$BRAVE_FILE"

# Generating colors
wal -n -i "$wall" -o ~/.local/src/pywalium/generate.sh

# Color for gtk using matugen
matugen image "$wall" --source-color-index 0 --type scheme-vibrant

# ------Spotify--------

# Getting theme name
theme=$(spicetify config current_theme)
pywal-spicetify "$theme"
