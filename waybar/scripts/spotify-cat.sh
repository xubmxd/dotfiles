#!/bin/bash

# Swaying Cat Animation
# Note the spaces added to the ends to keep the total width consistent
# so your Waybar modules don't jitter left and right!

FRAMES=(
    "_(=^ω^=)_"  # Paw down
    # "┌(=^ω^=)┌"  # Paw lifting
    "∩(=^ω^=)∩"  # Paw up
    # "┌(=^ω^=)┌"  # Paw lowering
)

FRAME_COUNT=${#FRAMES[@]}
i=0

while true; do
    STATUS=$(playerctl --player=spotify status 2>/dev/null)

    if [ "$STATUS" = "Playing" ]; then
        TEXT="${FRAMES[$i]}"
        echo "{\"text\": \"$TEXT\", \"class\": \"playing\"}"

        i=$(( (i + 1) % FRAME_COUNT ))

        # 0.4 seconds fits the swaying motion perfectly
        sleep 0.15
    else
        echo "{\"text\": \"\", \"class\": \"stopped\"}"
        sleep 2
    fi
done
