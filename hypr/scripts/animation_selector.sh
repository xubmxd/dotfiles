#!/bin/bash

ANIM_FILE="$HOME/.config/hypr/waybar_anim.lua"

choice=$(printf "Vertical\nHorizontal" | rofi -dmenu -i \
    -theme ~/.config/rofi/launcher.rasi \
    -theme-str 'window {width: 320px;}' \
    -theme-str 'textbox-prompt-colon { str: "󱕎 "; }')

if [[ -z "$choice" ]]; then
    exit 0
fi

choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

if [[ "$choice_lower" == *"vertical"* ]]; then
    style="slidevert"
else
    style="slide"
fi

lua_line="hl.animation({ leaf = \"workspaces\", enabled = true, speed = 4, bezier = \"smooth\", style = \"$style\" })"

echo "$lua_line" > "$ANIM_FILE"
hyprctl eval "$lua_line"
