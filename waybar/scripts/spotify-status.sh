#!/usr/bin/env bash

if playerctl -p spotify status &>/dev/null; then
    artist=$(playerctl -p spotify metadata artist)
    title=$(playerctl -p spotify metadata title)

    echo "{\"text\":\"\",\"tooltip\":\"$artist - $title\"}"
else
    echo "{\"text\":\"\",\"tooltip\":\"\"}"
fi
