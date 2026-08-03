#!/bin/bash

# ------------------------------------------------------------
# Wallpaper Picker
# ------------------------------------------------------------

# Root wallpaper directory
WALL_ROOT="$HOME/Pictures/wallpapers/images"

# Cache
BRAVE_FILE="$HOME/.cache/current_wallpaper.png"
CACHE_FILE="$HOME/.cache/current_wallpaper"

# ------------------------------------------------------------
# Re-index Function (Download time sort, prefix based on folder name, .png format)
# ------------------------------------------------------------

reindex_wallpapers() {
    local dir="$1"
    cd "$dir" || return

    local prefix=$(basename "$dir")
    local count=1

    # Read files sorted by modification time (oldest first) into an array safely
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Format new filename (e.g., anime01.png, anime02.png)
        local new_name=$(printf "%s%02d.png" "$prefix" "$count")

        if [ "$file" != "$new_name" ]; then
            mv -- "$file" "$new_name"
        fi

        ((count++))
    done < <(find . -maxdepth 1 -type f -name "*.png" -printf '%T@ %P\n' | sort -n | cut -d' ' -f2-)
}

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
# Category Theme
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

    placeholder: \"Search wallpapers...\";

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
# Category Icons
# ------------------------------------------------------------

display_name() {
	case "$1" in
	anime) echo "󰑈  Anime" ;;
	scenic) echo "󰉔  Scenic" ;;
	dark) echo "󰌪  Dark" ;;
	space) echo "󰠱  Space" ;;
	gaming) echo "󰊗  Gaming" ;;
	city) echo "󰣇  City" ;;
	cars) echo "󰭮  Cars" ;;
	abstract) echo "󰝤  Abstract" ;;
	minimal) echo "󰈔  Minimal" ;;
	nature) echo "󰔉  Nature" ;;
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

done < <(find "$WALL_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

while true; do

	# ------------------------------------------------------------
	# Category Selection
	# ------------------------------------------------------------

	SELECTED_DISPLAY=$(printf "%s" "$CATEGORY_LIST" |
		rofi \
			-dmenu \
			-i \
			-p "󰉋 Collection" \
			-theme-str "$CATEGORY_THEME")

	[ -z "$SELECTED_DISPLAY" ] && exit

	CATEGORY="${CATEGORY_MAP[$SELECTED_DISPLAY]}"
	WALL_DIR="$WALL_ROOT/$CATEGORY"

	# ------------------------------------------------------------
	# Wallpaper Selection
	# ------------------------------------------------------------

	SELECTED_NAME=$(
		find "$WALL_DIR" -type f -name "*.png" -printf '%T@ %P\n' |
			sort -n |
			cut -d' ' -f2- |
			while read -r file; do
				[ -z "$file" ] && continue
				printf "%s\0icon\x1f%s\n" "$file" "$WALL_DIR/$file"
			done |
			rofi \
				-dmenu \
				-i \
				-kb-delete-entry "" \
				-kb-custom-1 Shift+Delete \
				-p "󰸉 Wallpapers" \
				-theme-str "$ROFI_THEME"
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
				rofi \
					-dmenu \
					-p "Delete \"$(basename "$WALL")\"?" \
					-theme-str "$CATEGORY_THEME"
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
# Apply Wallpaper
# ------------------------------------------------------------

awww img "$WALL" \
	--transition-type fade \
	--transition-step 90 \
	--transition-fps 60

wal -n -i "$WALL" -o ~/.local/src/pywalium/generate.sh

matugen image "$WALL" \
	--source-color-index 0 \
	--type scheme-vibrant

cp "$WALL" "$CACHE_FILE"
cp "$WALL" "$BRAVE_FILE"

THEME=$(spicetify config current_theme)
pywal-spicetify "$THEME"
