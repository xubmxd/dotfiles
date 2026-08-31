#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
THEMES_DIR="$WAYBAR_DIR/themes"
HYPR_ANIM_FILE="$HOME/.config/hypr/source-configs/waybar_anim.lua"

ROFI_THEME="$HOME/.config/rofi/launcher.rasi"


# ============================================================
# MAIN BAR SELECTOR LOOP
# ============================================================

while true; do

    # --------------------------------------------------------
    # SELECT BAR
    # --------------------------------------------------------

    bar_choice=$(printf "Waybar\nQuickshell" | rofi -dmenu -i \
        -theme "$ROFI_THEME" \
        -theme-str 'window {width: 300px;}' \
        -theme-str 'textbox-prompt-colon { str: "󰖲 "; }')


    # ESC from main menu = exit script
    if [[ -z "$bar_choice" ]]; then
        exit 0
    fi


    # ========================================================
    # QUICKSHELL
    # ========================================================

    if [[ "$bar_choice" == "Quickshell" ]]; then

        # Stop Waybar
        killall waybar 2>/dev/null

        # Start Quickshell only if it isn't already running
        if ! pgrep -x quickshell >/dev/null; then
            quickshell &
        fi

        notify-send "Bar Selector" "Quickshell activated"

        exit 0
    fi


    # ========================================================
    # WAYBAR
    # ========================================================

    if [[ "$bar_choice" == "Waybar" ]]; then

        # Get only directories from themes folder
        themes=$(find "$THEMES_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%f\n' | sort)


        if [[ -z "$themes" ]]; then
            notify-send "Waybar Selector" \
                "No themes found in $THEMES_DIR"

            # Return to main selector
            continue
        fi


        # ----------------------------------------------------
        # SELECT WAYBAR THEME
        # ----------------------------------------------------

        choice=$(printf "%s\n" "$themes" | rofi -dmenu -i \
            -theme "$ROFI_THEME" \
            -theme-str 'window {width: 300px;}' \
            -theme-str 'textbox-prompt-colon { str: " "; }')


        # ESC from theme selector = back to main selector
        if [[ -z "$choice" ]]; then
            continue
        fi


        SELECTED_DIR="$THEMES_DIR/$choice"
        CONFIG_FILE="$SELECTED_DIR/config.jsonc"
        STYLE_FILE="$SELECTED_DIR/style.css"


        # ----------------------------------------------------
        # VALIDATE THEME
        # ----------------------------------------------------

        if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -f "$STYLE_FILE" ]]; then

            notify-send "Waybar Selector" \
                "Missing config.jsonc or style.css in $choice"

            # Return to main selector
            continue
        fi


        # ====================================================
        # STOP QUICKSHELL
        # ====================================================

        killall quickshell 2>/dev/null


        # ====================================================
        # APPLY WAYBAR THEME
        # ====================================================

        cp "$CONFIG_FILE" "$WAYBAR_DIR/config.jsonc"
        cp "$STYLE_FILE" "$WAYBAR_DIR/style.css"


        # ====================================================
        # APPLY HYPRLAND WORKSPACE ANIMATION
        # ====================================================

        mkdir -p "$(dirname "$HYPR_ANIM_FILE")"

        choice_lower=$(printf "%s" "$choice" | tr '[:upper:]' '[:lower:]')


        if [[ "$choice_lower" == *"vertical"* ]]; then

            echo 'hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slidevert" })' \
                > "$HYPR_ANIM_FILE"

            hyprctl eval \
                'hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slidevert" })'


        elif [[ "$choice_lower" == *"horizontal"* ]]; then

            echo 'hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slide" })' \
                > "$HYPR_ANIM_FILE"

            hyprctl eval \
                'hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slide" })'

        fi


        # ====================================================
        # RESTART WAYBAR
        # ====================================================

        killall waybar 2>/dev/null

        sleep 0.2

        waybar &


        notify-send \
            "Bar Selector" \
            "Waybar activated: $choice"


        # Theme successfully selected → exit selector
        exit 0

    fi

done
