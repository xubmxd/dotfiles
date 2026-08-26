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
# Load Pywal Colors
# ------------------------------------------------------------

if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    source "$HOME/.cache/wal/colors.sh"
else
    color0="#11111b"
    color4="#89b4fa"
    color6="#cba6f7"
    color7="#ffffff"
    foreground="#cdd6f4"
fi

# ------------------------------------------------------------
# Delete Confirmation Theme (Reusing your Category Theme)
# ------------------------------------------------------------

CATEGORY_THEME="
* {
    bg-col: ${color0}cc;
    border-col: ${color4};
    selected-col: ${color6};
    fg-col: ${foreground};
}

window {
    width: 700px;
    border: 2px solid;
    border-radius: 20px;
    border-color: @border-col;
    background-color: @bg-col;
    padding: 25px;
}

mainbox {
    children: [inputbar, listview];
    spacing: 20px;
}

inputbar {
    background-color: ${color0}80;
    border-radius: 12px;
    padding: 6px;
    children: [prompt, entry];
}

prompt {
    background-color: @selected-col;
    text-color: ${color0};
    border-radius: 8px;
    padding: 8px 16px;
    font: \"JetBrainsMono Nerd Font Bold 12\";
}

entry {
    background-color: transparent;
    text-color: @fg-col;
    padding: 8px 16px;
}

listview {
    columns: 3;
    lines: 2;

    spacing: 30px;

    cycle: true;
    dynamic: true;
    scrollbar: false;
}

element {
    orientation: horizontal;

    horizontal-align: 0.5;
    vertical-align: 0.5;

    background-color: transparent;

    padding: 16px;

    border-radius: 12px;
}

element-text {
    font: \"JetBrainsMono Nerd Font Bold 18\";
    text-color: @fg-col;
}

element selected.normal {
    background-color: ${color4}30;
    border: 2px solid;
    border-color: @selected-col;
}
"

# ------------------------------------------------------------
# Gallery Theme
# ------------------------------------------------------------
ROFI_THEME="
* {
    bg-col: ${color0}dd;
    border-col: ${color4};
    selected-col: ${color4};
    fg-col: ${foreground};
}
window {
    width: 1200px;
    height: 540px;

    border: 2px solid;
    border-color: @border-col;
    border-radius: 28px;

    background-color: @bg-col;

    padding: 38px;
}

mainbox {
    background-color: transparent;
    children: [ inputbar, listview ];
    spacing: 34px;
}

inputbar {
    background-color: ${color0}80;

    border-radius: 18px;

    margin: 0px 20% 0px 20%;

    padding: 10px;

    children: [ prompt, entry ];
}

prompt {
    background-color: @selected-col;

    text-color: ${color0};

    border-radius: 10px;

    padding: 8px 16px;

    font: \"JetBrainsMono Nerd Font Bold 12\";
}

entry {
    expand: true;

    background-color: transparent;

    text-color: @fg-col;

    placeholder: \"Search GIFs...\";

    placeholder-color: ${color7}70;

    padding: 10px;
}

listview {

    background-color: transparent;

    columns: 3;

    lines: 2;

    spacing: 42px;

    cycle: true;

    dynamic: true;

    scrollbar: false;
}

element {
    orientation: vertical;

    background-color: transparent;

    padding: 10px;

    border-radius: 22px;

    border: 2px solid;
    border-color: transparent;
}

element-icon {
    size: 250px;

    horizontal-align: 0.5;
    vertical-align: 0.5;

    background-color: transparent;
}

element-text {

    horizontal-align: 0.5;

    vertical-align: 0.5;

    margin: 18px 0px 0px 0px;

    text-color: @fg-col;

    font: \"JetBrainsMono Nerd Font 11\";
}

element normal.normal,
element alternate.normal {

    background-color: transparent;
}

element selected.normal {

    background-color: ${color4}12;

    border-color: @selected-col;
}
"

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
            rofi \
                -dmenu \
                -i \
                -kb-delete-entry "" \
                -kb-custom-1 Shift+Delete \
                -p "󰵪 GIFs" \
                -theme-str "$ROFI_THEME"
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
                rofi \
                    -dmenu \
                    -p "Delete \"$(basename "$SELECTED_GIF")\"?" \
                    -theme-str "$CATEGORY_THEME"
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
