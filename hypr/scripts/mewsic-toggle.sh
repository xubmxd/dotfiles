#!/bin/bash

# Configuration
TERMINAL="foot"
APP_ID="mewsic"
WINDOW_TITLE="mewsic"

# Path to your compiled Rust binary (Release build recommended)
MEWSIC_BIN="/home/xubm/.cargo/bin/mewsic_rs"

# Fallback to the debug binary if the release one doesn't exist yet
[ -x "$MEWSIC_BIN" ] || MEWSIC_BIN="/home/xubm/.dev/rs/mewsic_rs/target/debug/mewsic_rs"

# ---------------------------------------------------------
# Check if ANY mewsic instance is running (by class OR title)
# ---------------------------------------------------------
if hyprctl clients | grep -qE "class: ${APP_ID}|title: ${WINDOW_TITLE}"; then
    
    # Try moving it by class (catches script-launched instances)
    hyprctl dispatch movetoworkspacesilent "special:music,class:^${APP_ID}$" 2>/dev/null
    
    # Try moving it by title (catches manually-launched instances in other terminals)
    hyprctl dispatch movetoworkspacesilent "special:music,title:^${WINDOW_TITLE}$" 2>/dev/null

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
    "$MEWSIC_BIN" &

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
