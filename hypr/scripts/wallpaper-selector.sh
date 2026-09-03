#!/bin/bash

WALL_ROOT="$HOME/Pictures/wallpapers"

BRAVE_FILE="$HOME/.cache/current_wallpaper.png"
CACHE_FILE="$HOME/.cache/current_wallpaper"

reindex_wallpapers() {
    local dir="$1"
    cd "$dir" || return

    local folder_name
    folder_name=$(basename "$dir")

    local prefix
    prefix=$(echo "$folder_name" | tr ' ' '_')

    # Convert non-PNG wallpapers to PNG without overwriting
    for f in *.{jpg,jpeg,JPG,JPEG,gif,GIF,webp,WEBP}; do
        [ -e "$f" ] || continue

        local ext="${f##*.}"
        local output="${f%.$ext}.png"

        # If the PNG already exists, don't overwrite it
        if [ -e "$output" ]; then
            echo "Skipping conversion: $output already exists"
            continue
        fi

        if ffmpeg -y -i "$f" "$output" &>/dev/null; then
            rm -- "$f"
        fi
    done

    # First rename EVERYTHING to temporary names
    local count=1
    local tmp_files=()

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local tmp_name
        tmp_name=".reindex_tmp_$(printf '%04d' "$count").png"

        mv -- "$file" "$tmp_name"

        tmp_files+=("$tmp_name")
        ((count++))
    done < <(find . -maxdepth 1 -type f -name "*.png" -printf "%f\n" | sort)

    # Now rename temporary files to final sequential names
    count=1

    for file in "${tmp_files[@]}"; do
        local new_name
        new_name=$(printf "%s%02d.png" "$prefix" "$count")

        mv -- "$file" "$new_name"

        ((count++))
    done
}

for category_dir in "$WALL_ROOT"/*/; do
    [ -d "$category_dir" ] || continue
    reindex_wallpapers "$category_dir"
done

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

declare -A CATEGORY_MAP
CATEGORY_LIST=""

while IFS= read -r dir; do
    folder=$(basename "$dir")
    display=$(display_name "$folder")

    CATEGORY_MAP["$display"]="$folder"
    CATEGORY_LIST+="$display"$'\n'

done < <(find "$WALL_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | sort)

while true; do

    SELECTED_DISPLAY=$(printf "%s" "$CATEGORY_LIST" |
        rofi -dmenu -i \
            -theme ~/.config/rofi/launcher.rasi \
            -theme-str 'textbox-prompt-colon { str: "󰉋 "; }')

    [ -z "$SELECTED_DISPLAY" ] && exit

    CATEGORY="${CATEGORY_MAP[$SELECTED_DISPLAY]}"
    WALL_DIR="$WALL_ROOT/$CATEGORY"

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

    case "$ROFI_EXIT" in
    1)
        continue
        ;;

    10)
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

wal -n -i "$WALL" -o ~/.local/src/pywalium/generate.sh

matugen image "$WALL" \
    --source-color-index 0 \
    --type scheme-vibrant

if pgrep -x "eww" > /dev/null; then
    eww -c "$HOME/.config/eww/visualizer" reload
    eww -c "$HOME/.config/eww/lyrics" reload
fi

awww img "$WALL" \
    --transition-type any\
    --transition-step 90 \
    --transition-fps 60

cp "$WALL" "$CACHE_FILE"
cp "$WALL" "$BRAVE_FILE"
