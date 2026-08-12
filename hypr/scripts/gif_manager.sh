#!/usr/bin/env bash

# Dedicated GIF directory
GIF_DIR="/home/xubm/Pictures/wallpapers/gifs"

if [ ! -d "$GIF_DIR" ]; then
    notify-send "GIF Manager" "Directory not found: $GIF_DIR"
    exit 1
fi

# Function to apply GIF (swww supports animated gifs perfectly)
apply_gif() {
    local img_path="$1"
    if command -v swww &> /dev/null; then
        swww img "$img_path"
    else
        notify-send "GIF Manager" "swww is required to play animated GIFs."
    fi
}

while true; do
    # List GIFs sorted by modification time
    selected_file=$(find "$GIF_DIR" -maxdepth 1 -type f -name "*.gif" -printf '%T@ %P\n' | sort -n | cut -d' ' -f2- | rofi -dmenu -p "GIFs" -kb-custom-1 "Shift+Delete")

    rofi_exit_code=$?
    [ -z "$selected_file" ] && exit 0

    full_path="$GIF_DIR/$selected_file"

    # Handle Shift+Delete
    if [ $rofi_exit_code -eq 10 ]; then
        if [ -f "$full_path" ]; then
            rm -- "$full_path"
            notify-send "GIF Manager" "Deleted GIF: $selected_file"
        fi
        continue
    else
        # Regular selection applies the GIF
        if [ -f "$full_path" ]; then
            apply_gif "$full_path"
        fi
        break
    fi
done
