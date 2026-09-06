#!/bin/bash

WALL_ROOT="$HOME/Pictures/wallpapers"
BRAVE_FILE="$HOME/.cache/current_wallpaper.png"
CACHE_FILE="$HOME/.cache/current_wallpaper"
SDDM_FILE="/usr/share/sddm/themes/hyprlock-match/backgrounds/wall.png"

MODE="$1"
TARGET="$2"

reindex_wallpapers() {
    local dir="$1"
    cd "$dir" || return

    local folder_name=$(basename "$dir")
    local prefix=$(echo "$folder_name" | tr ' ' '_')

    # Convert non-PNG wallpapers to PNG
    for f in *.{jpg,jpeg,JPG,JPEG,gif,GIF,webp,WEBP}; do
        [ -e "$f" ] || continue
        local ext="${f##*.}"
        local output="${f%.$ext}.png"
        ffmpeg -y -i "$f" "$output" &>/dev/null && rm -- "$f"
    done

    # Get all PNG files sorted by creation time (oldest -> newest)
    local files=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        files+=("$file")
    done < <(find . -maxdepth 1 -type f -name "*.png" -printf '%T@ %f\n' | sort -n | cut -d' ' -f2-)

    # First rename everything to temporary names to prevent filename collisions
    local count=1
    local tmp_files=()
    for file in "${files[@]}"; do
        local tmp_name=".reindex_tmp_$(printf '%04d' "$count").png"
        mv -- "$file" "$tmp_name"
        tmp_files+=("$tmp_name")
        ((count++))
    done

    # Rename according to creation/modification time
    count=1
    for file in "${tmp_files[@]}"; do
        local new_name=$(printf "%s%02d.png" "$prefix" "$count")
        mv -- "$file" "$new_name"
        ((count++))
    done
}

case "$MODE" in
    "reindex_all")
        for category_dir in "$WALL_ROOT"/*/; do
            [ -d "$category_dir" ] || continue
            reindex_wallpapers "$category_dir"
        done
        ;;
        
    "apply")
        WALL="$TARGET"
        wal -n -i "$WALL" -o ~/.local/src/pywalium/generate.sh
        
        matugen image "$WALL" \
            --source-color-index 0 \
            --type scheme-vibrant

        if pgrep -x "eww" > /dev/null; then
            eww -c "$HOME/.config/eww/visualizer" reload
            eww -c "$HOME/.config/eww/lyrics" reload
        fi

        awww img "$WALL" \
            --transition-type any \
            --transition-step 90 \
            --transition-fps 60

        cp "$WALL" "$CACHE_FILE"
        cp "$WALL" "$BRAVE_FILE"
        cp "$WALL" "$SDDM_FILE"
        ;;
        
    "delete")
        WALL="$TARGET"
        WALL_DIR=$(dirname "$WALL")
        
        rm -f "$WALL"
        reindex_wallpapers "$WALL_DIR"
        ;;
esac
