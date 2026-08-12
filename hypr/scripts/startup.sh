#!/usr/bin/env bash

until awww query >/dev/null 2>&1; do
    sleep 0.05
done

awww img ~/.cache/current_wallpaper \
    --transition-type any \
    --transition-step 90 \
    --transition-fps 60
