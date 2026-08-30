#!/bin/bash

# ------------------------------------------------------------
# Wallpaper Picker
# ------------------------------------------------------------

# Root wallpaper directory
WALL_ROOT="$HOME/Pictures/wallpapers"

# Cache
BRAVE_FILE="$HOME/.cache/current_wallpaper.png"
CACHE_FILE="$HOME/.cache/current_wallpaper"

# ------------------------------------------------------------
# Re-index & Convert Function (Runs on startup & deletion)
# ------------------------------------------------------------

reindex_wallpapers() {
    local dir="$1"
    cd "$dir" || return

    local folder_name=$(basename "$dir")
    local prefix=$(echo "$folder_name" | tr ' ' '_')
    local count=1

    # 1. Convert any stray .jpg/.jpeg/.gif to .png first using ffmpeg
    for f in *.{jpg,jpeg,JPG,JPEG,gif,GIF,webp,WEBP}; do
        [ -e "$f" ] || continue
        local ext="${f##*.}"
        ffmpeg -y -i "$f" "${f%.$ext}.png" &>/dev/null && rm -- "$f"
    done

    # 2. Re-index and sequence all png files chronologically
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        local new_name=$(printf "%s%02d.png" "$prefix" "$count")

        if [ "$file" != "$new_name" ]; then
            mv -- "$file" "$new_name"
        fi

        ((count++))
        done < <(find "$WALL_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
}

# Run re-index on all category folders automatically when launcher starts
for category_dir in "$WALL_ROOT"/*/; do
    [ -d "$category_dir" ] || continue
    reindex_wallpapers "$category_dir"
done

# ------------------------------------------------------------
# Category Icons
# ------------------------------------------------------------

display_name() {
    case "$1" in
    anime)   echo "▷  Anime" ;;
    scenic)  echo "⌇  Scenic" ;;
    "2D")    echo "◇  2D" ;;
    lofi)    echo "☾  lofi" ;;
    space)   echo "✧  Space" ;;
    gaming)  echo "󰊗  Gaming" ;;
    rice)    echo "󰣇  Rice" ;;
    cars)    echo "󰭮  Cars" ;;
    pixel)   echo "▦  Pixel" ;;
    minimal) echo "□  Minimal" ;;
    nature)  echo "♧  Nature" ;;
    *) echo "󰉋  ${1^}" ;;
    esac
}

# ------------------------------------------------------------
# Build Category List
# ------------------------------------------------------------

declare -A CATEGORY_MAP
CATEGORY_LIST=""

while IFS= read -r dir; do
    folder=$(basename "$dir")
    display=$(display_name "$folder")

    CATEGORY_MAP["$display"]="$folder"
    CATEGORY_LIST+="$display"$'\n'

done < <(find "$WALL_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | sort)

while true; do

    # ------------------------------------------------------------
    # Category Selection
    # ------------------------------------------------------------

    SELECTED_DISPLAY=$(printf "%s" "$CATEGORY_LIST" |
        rofi -dmenu -i \
            -theme ~/.config/rofi/launcher.rasi \
            -theme-str 'textbox-prompt-colon { str: "󰉋 "; }')

    [ -z "$SELECTED_DISPLAY" ] && exit

    CATEGORY="${CATEGORY_MAP[$SELECTED_DISPLAY]}"
    WALL_DIR="$WALL_ROOT/$CATEGORY"

    # ------------------------------------------------------------
    # Wallpaper Selection (Grid View)
    # ------------------------------------------------------------

    SELECTED_NAME=$(
        find "$WALL_DIR" -type f -name "*.png" -printf '%T@ %P\n' |
            sort -n |
            cut -d' ' -f2- |
            while read -r file; do
                [ -z "$file" ] && continue
                printf "%s\0icon\x1f%s\n" "$file" "$WALL_DIR/$file"
            done |
            rofi -dmenu -i \
                -kb-delete-entry "" \
                -kb-custom-1 Shift+Delete \
                -theme ~/.config/rofi/launcher.rasi \
                -theme-str 'window { width: 1000px; }' \
                -theme-str 'listview { columns: 3; lines: 2; spacing: 30px; }' \
                -theme-str 'element { orientation: vertical; padding: 16px; border-radius: 12px; }' \
                -theme-str 'element-icon { size: 250px; padding: 0px; }' \
                -theme-str 'element-text { horizontal-align: 0.5; margin: 10px 0px 0px 0px; }' \
                -theme-str 'textbox-prompt-colon { str: "󰸉 "; }'
    )

    ROFI_EXIT=$?

    # Escape in wallpaper menu -> go back
    case "$ROFI_EXIT" in
    1)
        # Escape
        continue
        ;;

    10)
        # Shift+Delete

        [ -z "$SELECTED_NAME" ] && continue

        WALL="$WALL_DIR/$SELECTED_NAME"

        CONFIRM=$(
            printf "󰜺 Cancel\n󰆴 Delete" |
                rofi -dmenu \
                    -theme ~/.config/rofi/launcher.rasi \
                    -theme-str 'window { width: 400px; }' \
                    -theme-str 'textbox-prompt-colon { str: "󰆴 "; }'
        )

        if [[ "$CONFIRM" == *Delete ]]; then
            rm -f "$WALL"
            reindex_wallpapers "$WALL_DIR"
        fi

        continue
        ;;
    esac

    [ -z "$SELECTED_NAME" ] && continue

    WALL="$WALL_DIR/$SELECTED_NAME"

    break

done

# ------------------------------------------------------------
# Generate Colors
# ------------------------------------------------------------

wal -n -i "$WALL" -o ~/.local/src/pywalium/generate.sh

matugen image "$WALL" \
    --source-color-index 0 \
    --type scheme-vibrant

# ------------------------------------------------------------
# Reload Eww (if running)
# ------------------------------------------------------------
if pgrep -x "eww" > /dev/null; then
    eww -c "$HOME/.config/eww/visualizer" reload
    eww -c "$HOME/.config/eww/lyrics" reload
fi

# ------------------------------------------------------------
# Apply Wallpaper
# ------------------------------------------------------------

awww img "$WALL" \
    --transition-type any\
    --transition-step 90 \
    --transition-fps 60

# ------------------------------------------------------------
# Reload Active Status Bar (Waybar or Quickshell)
# ------------------------------------------------------------

if pgrep -x "waybar" > /dev/null; then
    killall waybar && waybar &
elif pgrep -x "quickshell" > /dev/null; then
    true
fi

# ------------------------------------------------------------
# Do the remaining process
# ------------------------------------------------------------

cp "$WALL" "$CACHE_FILE"
cp "$WALL" "$BRAVE_FILE"

# THEME=$(spicetify config current_theme)
# pywal-spicetify "$THEME"
