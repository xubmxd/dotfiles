#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
THEMES_DIR="$WAYBAR_DIR/themes"

themes=$(ls -1 "$THEMES_DIR")

if [ -z "$themes" ]; then
    notify-send "Waybar Selector" "No themes found in $THEMES_DIR"
    exit 1
fi

choice=$(echo -e "$themes" | rofi -dmenu -i -p "Select Waybar Theme:" -theme-str 'window {width: 300px;}')

if [[ -z "$choice" ]]; then
    exit 0
fi

SELECTED_DIR="$THEMES_DIR/$choice"
CONFIG_FILE="$SELECTED_DIR/config.jsonc"
STYLE_FILE="$SELECTED_DIR/style.css"

if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$STYLE_FILE" ]; then
    notify-send "Waybar Selector" "Missing config or style.css in $choice"
    exit 1
fi

killall waybar
sleep 0.2
waybar -c "$CONFIG_FILE" -s "$STYLE_FILE" &
