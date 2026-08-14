#!/bin/bash
# Run Cava and pipe the output
cava -p ~/.config/eww/visualizer/cava.conf | while read -r line; do
    # Remove the trailing semicolon
    line="${line%;}"
    # Replace remaining semicolons with commas and wrap in JSON brackets
    echo "[${line//;/,}]"
done
