#!/bin/bash

# Configuration
TERMINAL="kitty"
# We give the window a unique custom title right at launch
CUSTOM_TITLE="mewsic-tui-app"
PYTHON_VENV="/home/xubm/.dev/mewsic/venv/bin/python"
SCRIPT_PATH="/home/xubm/.dev/mewsic/mewsic.py"

# Fallback to system python if venv doesn't exist at that path
if [ ! -f "$PYTHON_VENV" ]; then
    PYTHON_VENV="python"
fi

if pgrep -f "mewsic.py" > /dev/null; then
    # If mewsic is already running, just toggle the special workspace
    hyprctl dispatch togglespecialworkspace music
else
    # Launch kitty with a explicit title flag (-T)
    $TERMINAL --class "kitty" -T "$CUSTOM_TITLE" -e "$PYTHON_VENV" "$SCRIPT_PATH" &

    # Wait for the window with our custom title to appear (timeout after 5 seconds)
    count=0
    while [ $count -lt 50 ]; do
        if hyprctl clients | grep -q "title: $CUSTOM_TITLE"; then
            break
        fi
        sleep 0.1
        ((count++))
    done

    # Force move the window to the special workspace using its exact unique title
    hyprctl dispatch movetoworkspacesilent "special:music,title:^($CUSTOM_TITLE)$"

    # Show the special workspace
    hyprctl dispatch togglespecialworkspace music
fi
