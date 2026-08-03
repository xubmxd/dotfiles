#!/usr/bin/env bash

# Base directory for your wallpapers
WALLPAPER_DIR="/home/xubm/Pictures/wallpapers/images"

# Check if base directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Manager" "Directory not found: $WALLPAPER_DIR"
    exit 1
fi

# Function to re-index wallpapers in a given category directory
reindex_wallpapers() {
    local dir="$1"
    cd "$dir" || return

    local count=1
    local prefix=$(basename "$dir")

    # Special adjustment if you want 'rice_wals' to format as 'rice_wal' or similar, 
    # otherwise it uses the folder name directly.
    # Find all png files, sort by modification time (oldest first)
    find . -maxdepth 1 -type f -name "*.png" -printf '%T@ %P\n' | sort -n | while read -r timestamp filename; do
        local new_name=$(printf "%s%02d.png" "$prefix" "$count")

        if [ "$filename" != "$new_name" ]; then
            mv -- "$filename" "$new_name"
        fi

        ((count++))
    done
}

# Function to apply wallpaper (Change 'swww img' to your wallpaper setter if different, e.g., hyprpaper, feh)
apply_wallpaper() {
    local img_path="$1"
    if command -v swww &> /dev/null; then
        swww img "$img_path"
    elif command -v feh &> /dev/null; then
        feh --bg-scale "$img_path"
    elif command -v hyprpaper &> /dev/null; then
        hyprctl hyprpaper wallpaper " , $img_path"
    fi
}

# 1. Select Category
category=$(ls -p "$WALLPAPER_DIR" | grep / | tr -d '/' | rofi -dmenu -p "Collection")
[ -z "$category" ] && exit 0

TARGET_DIR="$WALLPAPER_DIR/$category"

while true; do
    # 2. List wallpapers in the selected category, sorted by modification time (oldest first)
    # We display just the filename in rofi
    selected_file=$(find "$TARGET_DIR" -maxdepth 1 -type f -name "*.png" -printf '%T@ %P\n' | sort -n | cut -d' ' -f2- | rofi -dmenu -p "Wallpapers" -kb-custom-1 "Shift+Delete")

    # Rofi exit code check or empty selection
    # In rofi, custom keybind 1 returns exit code 10
    rofi_exit_code=$?

    [ -z "$selected_file" ] && exit 0

    full_path="$TARGET_DIR/$selected_file"

    # Handle Shift+Delete (Custom Keybind 1)
    if [ $rofi_exit_code -eq 10 ]; then
        if [ -f "$full_path" ]; then
            rm -- "$full_path"
            reindex_wallpapers "$TARGET_DIR"
            notify-send "Wallpaper Manager" "Deleted and re-indexed $category"
        fi
        # Loop back to show updated list
        continue
    else
        # Regular selection applies the wallpaper
        if [ -f "$full_path" ]; then
            apply_wallpaper "$full_path"
        fi
        break
    fi
done
