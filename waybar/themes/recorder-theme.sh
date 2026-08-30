#!/bin/bash

THEMES_DIR="$HOME/.config/waybar/themes"
cd "$THEMES_DIR" || exit 1

TARGET="$1"
NEW_POS="$2"

if [ -z "$TARGET" ] || [ -z "$NEW_POS" ]; then
    echo "Usage: ./reorder-themes.sh <target_directory> <new_position>"
    echo "Example: ./reorder-themes.sh test 5"
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Error: Directory '$TARGET' not found in $THEMES_DIR"
    exit 1
fi

declare -a ordered_themes
for dir in $(ls -v); do
    if [ -d "$dir" ] && [ "$dir" != "$TARGET" ]; then
        ordered_themes+=("$dir")
    fi
done

idx=$((NEW_POS - 1))
declare -a final_themes

for (( i=0; i<${#ordered_themes[@]}; i++ )); do
    if [ $i -eq $idx ]; then
        final_themes+=("$TARGET")
    fi
    final_themes+=("${ordered_themes[$i]}")
done

if [ $idx -ge ${#ordered_themes[@]} ]; then
    final_themes+=("$TARGET")
fi

count=1
declare -a tmp_names
for dir in "${final_themes[@]}"; do
    basename=$(echo "$dir" | sed -E 's/^[0-9]+-//')
    tmp_name=".tmp_${count}_${basename}"
    mv "$dir" "$tmp_name"
    tmp_names+=("$tmp_name")
    ((count++))
done

count=1
for tmp_dir in "${tmp_names[@]}"; do
    basename=$(echo "$tmp_dir" | sed -E 's/^\.tmp_[0-9]+_//')
    final_name=$(printf "%02d-%s" "$count" "$basename")
    mv "$tmp_dir" "$final_name"
    echo "✔ Set $final_name"
    ((count++))
done

echo "Theme reordering complete!"
