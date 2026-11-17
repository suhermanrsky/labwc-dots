#!/bin/bash

#####################################
## author @Harsh-bin Github #########
#####################################

# CONFIGURATION
icon_dir="$HOME/.config/dunst/brightness-icon"
# Menggunakan ID notifikasi yang konsisten untuk Dunst agar tidak menumpuk (-r 3456)
notify_id="-r 3456"

if [[ -z "$1" ]] || [[ ! "$1" =~ ^[0-9]+[+-]$ ]]; then
    echo "Usage:"
    echo "   $(basename "$0") 1+   (Increase brightness by 1%)"
    echo "   $(basename "$0") 1-   (Decrease brightness by 1%)"
    exit 1
fi

# Parse Input
step="${1//[^0-9]/}" # Hapus semua yang bukan angka
sign="${1//[0-9]/}"  # Hapus semua yang bukan tanda + atau -

# PERBAIKAN: Mengambil nilai kecerahan SAAT INI terlebih dahulu sebelum kalkulasi
current_brightness=$(brightnessctl -m | cut -d, -f4 | tr -d '%')

if [ "$sign" == "+" ]; then
    brightnessctl set "${step}%+" -q
elif [ "$sign" == "-" ]; then
    # Sekarang matematika berjalan mulus karena 'current_brightness' sudah ada nilainya
    if [ $((current_brightness - step)) -le 0 ]; then
        brightnessctl set 1% -q
    else
        brightnessctl set "${step}%-" -q
    fi
fi

# Mengambil nilai kecerahan layar terbaru setelah diubah
brightness=$(brightnessctl -m | cut -d, -f4 | tr -d '%')

# Memilih ikon berdasarkan persentase kecerahan
if [ "$brightness" -lt 34 ]; then
    icon="$icon_dir/brightness-low.png"
elif [ "$brightness" -lt 67 ]; then
    icon="$icon_dir/brightness-mid.png"
else
    icon="$icon_dir/brightness-high.png"
fi

text="Brightness: ${brightness}%"

# NOTIFIKASI (Dioptimalkan untuk Dunst dengan progress bar)
notify-send -t 3000 $notify_id -u low -i "$icon" "$text" -h int:value:"$brightness"
