#!/bin/bash

# Getting wallpaper
wall=$(find /home/xubm/Pictures/wallpapers/images/dark -type f -iname "*.jpg" -o -iname "*.jpeg" | shuf -n 1)

# Copying Selected wallpaper to .cache as current wallpaper
cp "$wall" ~/.cache/current_wallpaper

# Generating colors
wal -i $wall -o ~/.local/src/pywalium/generate.sh

# Color for gtk using matugen
matugen image $wall

# setting wallpaper
swww img $wall --transition-type fade --transition-step 90 --transition-fps 60

# ------Spotify--------

# Getting theme name
theme=$(spicetify config current_theme)
pywal-spicetify $theme
