# 1. Konfigurasi Sistem & Jalur D-Bus (Untuk Fix Thunar & Waybar di Niri)
if status is-login
    if test -z "$DBUS_SESSION_BUS_ADDRESS"
        eval (dbus-launch --sh-syntax --exit-with-session | sed 's/; export.*//')
    end
end

# 2. Konfigurasi Interaktif Teminal Anda (Fastfetch)
if status is-interactive
    fastfetch
end

# Alias
alias aria-torrent='aria2c --max-concurrent-downloads=5 --file-allocation=falloc --enable-dht=true --bt-max-peers=100 --seed-ratio=1.0 --seed-time=120 --uri-selector=adaptive --server-stat-of=$HOME/.aria2_server_stat --bt-tracker="udp://tracker.opentrackr.org:1337/announce,udp://tracker.coppersurfer.tk:6969/announce,udp://open.stealth.si:80/announce,udp://tracker.leechers-paradise.org:6969/announce,udp://://desync.com"'
alias aria-fastest='aria2c -s 16 -x 16 -j 10 --uri-selector=adaptive --server-stat-of=$HOME/.aria2_server_stat'
