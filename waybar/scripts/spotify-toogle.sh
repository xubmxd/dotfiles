#!/usr/bin/env bash

if pgrep -x spotify >/dev/null; then
    hyprctl dispatch togglespecialworkspace music
else
    spotify &
fi
