#!/bin/bash

# Hentikan sementara semua pemutar media
playerctl --all-players pause >/dev/null 2>&1 &

# Redupkan layar secara sinkron sebelum tidur
"$HOME/.config/labwc/idle/brightness_ctrl.sh" --fade-out

exit 0
