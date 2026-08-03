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
# Check if a window running mewsic already exists
# ---------------------------------------------------------
if hyprctl clients | grep -q "title: python mewsic.py"; then
    # Move the existing window to the special workspace
    hyprctl dispatch movetoworkspacesilent "special:music,title:^python mewsic\.py$"

    # Toggle the workspace
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
