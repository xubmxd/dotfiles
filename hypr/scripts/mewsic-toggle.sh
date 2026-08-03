#!/bin/bash

# Configuration
TERMINAL="foot"
APP_ID="mewsic"
WINDOW_TITLE="mewsic"

PYTHON_VENV="/home/xubm/.dev/mewsic/venv/bin/python"
SCRIPT_PATH="/home/xubm/.dev/mewsic/mewsic.py"

# Fallback to system python
[ -x "$PYTHON_VENV" ] || PYTHON_VENV="python"

# ---------------------------------------------------------
# Check if ANY mewsic instance is running (by class OR title)
# ---------------------------------------------------------
# grep -E allows us to check for either condition simultaneously
if hyprctl clients | grep -qE "class: ${APP_ID}|title: python mewsic\.py"; then
    
    # Try moving it by class (catches script-launched instances)
    hyprctl dispatch movetoworkspacesilent "special:music,class:^${APP_ID}$" 2>/dev/null
    
    # Try moving it by title (catches manually-launched instances)
    hyprctl dispatch movetoworkspacesilent "special:music,title:^python mewsic\.py$" 2>/dev/null

    # Toggle the workspace on and off
    hyprctl dispatch togglespecialworkspace music
    exit 0
fi

# ---------------------------------------------------------
# Launch a new dedicated Foot instance
# ---------------------------------------------------------
"$TERMINAL" \
    --app-id "$APP_ID" \
    --title "$WINDOW_TITLE" \
    "$PYTHON_VENV" "$SCRIPT_PATH" &

# Wait for the window to appear
for _ in {1..50}; do
    if hyprctl clients | grep -q "class: ${APP_ID}"; then
        break
    fi
    sleep 0.1
done

# Move it to the special workspace
hyprctl dispatch movetoworkspacesilent "special:music,class:^${APP_ID}$"

# Show the workspace
hyprctl dispatch togglespecialworkspace music
