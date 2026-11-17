#!/bin/bash

STEP="1%"

if [ "$1" = "up" ]; then
    pactl set-sink-volume @DEFAULT_SINK@ +"$STEP"
elif [ "$1" = "down" ]; then
    pactl set-sink-volume @DEFAULT_SINK@ -"$STEP"
elif [ "$1" = "--toggle-mute" ]; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
fi

VOLUME=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '{print $5}' | head -n 1 | tr -d '%')
IS_MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')

if [ "$IS_MUTED" = "yes" ] || [ "$VOLUME" -le 0 ]; then
    ICON="/home/saint/.config/dunst/volume-icon/mute.png"
    TEXT="Muted"
elif [ "$VOLUME" -le 30 ]; then
    ICON="/home/saint/.config/dunst/volume-icon/vol-low.png"
    TEXT="$VOLUME%"
elif [ "$VOLUME" -le 70 ]; then
    ICON="/home/saint/.config/dunst/volume-icon/vol-mid.png"
    TEXT="$VOLUME%"
else
    ICON="/home/saint/.config/dunst/volume-icon/vol-high.png"
    TEXT="$VOLUME%"
fi

notify-send -h string:x-canonical-private-synchronous:volume_change \
            -h int:value:"$VOLUME" \
            -t 1000 \
            -i "$ICON" \
            "Volume" "$TEXT"
