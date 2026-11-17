#!/bin/bash

IFS=, read -r _ _ _ value _ < <(brightnessctl -m)
current_val=${value%%%}

fade_out_screen() {
    if [ "$current_val" -gt "0" ]; then
        brightnessctl -sq set 0%
    fi
}

fade_in_screen() {
    sleep 0.3
    brightnessctl -rq
    # Pengaman: jika brightness masih 0% setelah bangun, paksa naik ke 50%
    IFS=, read -r _ _ _ new_val _ < <(brightnessctl -m)
    if [ "${new_val%%%}" -eq "0" ]; then
        brightnessctl -q set 50%
    fi
}

case $1 in
    "--fade-out") fade_out_screen ;;
    "--fade-in") fade_in_screen ;;
    *) echo "Usage: $0 --fade-out or --fade-in"; exit 0 ;;
esac
