#!/bin/bash

# Regenerate color for current wallpaper
wal -i ~/.cache/current_wallpaper

killall waybar
waybar &

