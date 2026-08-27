#!/bin/bash

# ------------------------------------------------------------
# GIF Wallpaper Picker (No Categories)
# ------------------------------------------------------------

# Root GIF directory
GIF_ROOT="$HOME/Pictures/gifs"

# Cache
BRAVE_FILE="$HOME/.cache/current_wallpaper.gif"
CACHE_FILE="$HOME/.cache/current_wallpaper"

# ------------------------------------------------------------
# Re-index Function (Runs on startup & deletion)
# ------------------------------------------------------------

reindex_gifs() {
    local dir="$1"
    cd "$dir" || return

    local folder_name=$(basename "$dir") # Will be "gifs"
    local prefix=$(echo "$folder_name" | tr ' ' '_')
    local count=1

    # Re-index and sequence all gif files chronologically
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        local new_name=$(printf "%s%02d.gif" "$prefix" "$count")

        if [ "$file" != "$new_name" ]; then
            mv -- "$file" "$new_name"
        fi

        ((count++))
    done < <(find . -maxdepth 1 -type f -iname "*.gif" -printf '%T@ %P\n' | sort -n | cut -d' ' -f2-)
}

# Run re-index on the root GIF directory
[ -d "$GIF_ROOT" ] && reindex_gifs "$GIF_ROOT"

# ------------------------------------------------------------
# GIF Selection Loop
# ------------------------------------------------------------

while true; do

    SELECTED_NAME=$(
        find "$GIF_ROOT" -maxdepth 1 -type f -iname "*.gif" -printf '%T@ %P\n' |
            sort -n |
            cut -d' ' -f2- |
            while read -r file; do
                [ -z "$file" ] && continue
                printf "%s\0icon\x1f%s\n" "$file" "$GIF_ROOT/$file"
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
                -theme-str 'textbox-prompt-colon { str: "󰵪 "; }'
    )

    ROFI_EXIT=$?

    case "$ROFI_EXIT" in
    1)
        # Escape pressed -> exit entirely
        exit 0
        ;;

    10)
        # Shift+Delete pressed

        [ -z "$SELECTED_NAME" ] && continue

        SELECTED_GIF="$GIF_ROOT/$SELECTED_NAME"

        CONFIRM=$(
            printf "󰜺 Cancel\n󰆴 Delete" |
                rofi -dmenu \
                    -theme ~/.config/rofi/launcher.rasi \
                    -theme-str 'window { width: 400px; }' \
                    -theme-str 'textbox-prompt-colon { str: "󰆴 "; }'
        )

        if [[ "$CONFIRM" == *Delete ]]; then
            rm -f "$SELECTED_GIF"
            reindex_gifs "$GIF_ROOT"
        fi

        # Loop back to GIF selection
        continue
        ;;
    esac

    # If empty selection for any other reason, exit
    [ -z "$SELECTED_NAME" ] && exit 0

    SELECTED_GIF="$GIF_ROOT/$SELECTED_NAME"

    # Selection made, break the loop and apply
    break

done

# ------------------------------------------------------------
# Generate Colors
# ------------------------------------------------------------

wal -n -i "$SELECTED_GIF" -o ~/.local/src/pywalium/generate.sh

matugen image "$SELECTED_GIF" \
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
# Apply GIF Wallpaper
# ------------------------------------------------------------

awww img "$SELECTED_GIF" \
    --transition-type any\
    --transition-step 90 \
    --transition-fps 60

# ------------------------------------------------------------
# Do the remaining process
# ------------------------------------------------------------

cp "$SELECTED_GIF" "$CACHE_FILE"
cp "$SELECTED_GIF" "$BRAVE_FILE"

# THEME=$(spicetify config current_theme)
# pywal-spicetify "$THEME"
