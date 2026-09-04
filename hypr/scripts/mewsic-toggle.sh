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
# Check if ANY mewsic instance is running
# ---------------------------------------------------------
if hyprctl clients | grep -qE "class: ${APP_ID}|title: ${WINDOW_TITLE}"; then
    
    # Try moving it by class (catches script-launched instances)
    hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:music', window = 'class:^${APP_ID}$', silent = true })" 2>/dev/null
    
    # Try moving it by title (catches manually-launched instances)
    hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:music', window = 'title:^${WINDOW_TITLE}$', silent = true })" 2>/dev/null

    # Toggle the workspace on and off
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("music")'
    exit 0
fi

# ---------------------------------------------------------
# Launch a new dedicated Foot instance & Eww Widgets
# ---------------------------------------------------------

# 1. Start the visualizer and lyrics widgets
# eww -c "$HOME/.config/eww/visualizer" open cava_visualizer

# 2. Launch Foot
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

# Move it to the special workspace AND automatically pull the workspace down
hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:music', window = 'class:^${APP_ID}$', silent = false })"

# ---------------------------------------------------------
# The Background Watcher
# ---------------------------------------------------------
(
    # Give the window a second to fully register in Hyprland
    sleep 2
    
    # Continuously check if the Mewsic window exists in Hyprland
    while hyprctl clients | grep -q "class: ${APP_ID}"; do
        # Check every 1 second
        sleep 1
    done
    
    # Once the loop breaks, trigger cleanup for both widgets and cava
    eww -c "$HOME/.config/eww/visualizer" close cava_visualizer
    # eww -c "$HOME/.config/eww/lyrics" close mewsic_lyrics
    killall cava
) &
