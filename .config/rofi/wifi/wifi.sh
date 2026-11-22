#!/bin/bash

# Remove 'set -e' so the script doesn't crash if a connection fails initially
set -u

notify_id=$(if pgrep -x "swaync" >/dev/null; then echo "-h string:x-canonical-private-synchronous:wifimanager"; else echo "-r 3455"; fi)

# Notify user about the script launch
notify-send $notify_id -t 3000 "       Checking for Networks & VPNs..."

# --- Configuration ---
LIST_THEME="$HOME/.config/rofi/wifi/list.rasi"
ENABLE_THEME="$HOME/.config/rofi/wifi/enable.rasi"
SSID_THEME="$HOME/.config/rofi/wifi/ssid.rasi"
PASSWORD_THEME="$HOME/.config/rofi/wifi/password.rasi"

# --- Functions ---

enable_wifi_menu() {
    echo -e "   Enable Wi-Fi" | rofi -dmenu -theme "$ENABLE_THEME" || true
}

prompt_ssid() {
    rofi -dmenu -p "SSID" -theme "$SSID_THEME" || true
}

prompt_password() {
    local msg="$1"
    if [[ -n "$msg" ]]; then
        rofi -dmenu -p "Password (Retry)" -mesg "<b>Error:</b> $msg" -theme "$PASSWORD_THEME" || true
    else
        rofi -dmenu -p "Password" -theme "$PASSWORD_THEME" || true
    fi
}

prompt_vpn_password() {
    local msg="$1"
    if [[ -n "$msg" ]]; then
        rofi -dmenu -p "VPN Password (Retry)" -mesg "<b>Error:</b> $msg" -theme "$PASSWORD_THEME" || true
    else
        rofi -dmenu -p "VPN Password" -theme "$PASSWORD_THEME" || true
    fi
}

manage_network_options() {
    local target_ssid="$1"
    while true; do
        # Check if network connected
        local is_active
        is_active=$(nmcli -t -f NAME connection show --active | grep -x "$target_ssid" || true)

        # Cek status autoconnect saat ini
        local auto_status
        auto_status=$(nmcli -g connection.autoconnect connection show "$target_ssid" 2>/dev/null || echo "no")

        local auto_label
        if [[ "$auto_status" == "yes" ]]; then
            auto_label="   Autoconnect: Enabled (Click to Disable)"
        else
            auto_label="󰜺     Autoconnect: Disabled (Click to Enable)"
        fi

        # list menu
        local menu_options="   Back\n${auto_label}"
        if [[ -n "$is_active" ]]; then
            menu_options="${menu_options}\n<span size='large' weight='bold'></span>    Disconnect"
        else
            menu_options="${menu_options}\n<span size='large' weight='bold'> </span>  Connect"
        fi
        menu_options="${menu_options}\n    Forget Network"

        local choice
        choice=$(echo -e "$menu_options" | rofi -markup-rows -dmenu -p "$target_ssid" -theme "$LIST_THEME" || true)

        case "$choice" in
            ""|*"Back"*)
                break
                ;;
            *"Autoconnect: Enabled"*)
                nmcli connection modify "$target_ssid" connection.autoconnect no
                notify-send $notify_id -t 2000 " 󰜺       Autoconnect disabled for \"$target_ssid\""
                ;;
            *"Autoconnect: Disabled"*)
                nmcli connection modify "$target_ssid" connection.autoconnect yes
                notify-send $notify_id -t 2000 "       Autoconnect enabled for \"$target_ssid\""
                ;;
            *"Disconnect"*)
                nmcli connection down id "$target_ssid" >/dev/null 2>&1
                notify-send $notify_id -t 3000 "󰖪    Disconnected from \"$target_ssid\""
                ;;
            *"Connect"*)
                notify-send $notify_id -t 3000 "       Connecting to \"$target_ssid\"..."
                if nmcli connection up id "$target_ssid" >/dev/null 2>&1; then
                    notify-send $notify_id -t 3000 "       Connected to \"$target_ssid\""
                else
                    notify-send $notify_id -t 3000 "       Failed to connect to \"$target_ssid\""
                fi
                ;;
            *"Forget Network"*)
                nmcli connection delete id "$target_ssid" >/dev/null 2>&1
                notify-send $notify_id -t 3000 "       Forgot network \"$target_ssid\""
                break
                ;;
        esac
    done
}


manage_known_networks() {
    while true; do
        local known_list
        known_list=$(nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1 | awk '{printf "   %s\n", $0}')

        local menu_items="   Back"
        if [[ -n "$known_list" ]]; then
            menu_items="${menu_items}\n${known_list}"
        fi

        local chosen
        chosen=$(echo -e "$menu_items" | rofi -markup-rows -dmenu -p "Manage Networks" -theme "$LIST_THEME" || true)

        if [[ -z "$chosen" || "$chosen" == *"Back"* ]]; then
            exec "$0" "$@"
        fi

        local selected_ssid
        selected_ssid=$(echo "$chosen" | sed 's/^[^ ]*   //')
        manage_network_options "$selected_ssid"
    done
}

list_wifi_menu() {
    echo -e "󰤮  Disable Wi-Fi\n󱚾    Manage Known Networks\n${connection_status}\n   Rescan\n   Manual Setup\n${wifi_list}\n${vpn_section_header}${vpn_list}" | rofi -markup-rows -dmenu -theme "$LIST_THEME" || true
}

connect_secure_loop() {
    local target_ssid="$1"
    local error_output=""

    while true; do
        local pass
        pass=$(prompt_password "$error_output")

        if [[ -z "$pass" ]]; then
            exit 0
        fi

        notify-send $notify_id -t 3000 " 󱛆      Connecting to \"$target_ssid\""
        nmcli connection delete id "$target_ssid" &>/dev/null

        local output
        output=$(nmcli dev wifi connect "$target_ssid" password "$pass" 2>&1)

        if [[ $? -eq 0 ]]; then
            notify-send $notify_id -t 3000 "       Connected to \"$target_ssid\""
            break
        else
            error_output=$(echo "$output" | sed 's/Error: //')
            notify-send $notify_id -t 3000 "       Connection Failed" "Retrying..."
        fi
    done
}

connect_vpn_secure_loop() {
    local vpn_name="$1"
    local error_output=""

    while true; do
        local pass
        pass=$(prompt_vpn_password "$error_output")

        if [[ -z "$pass" ]]; then
            exit 0
        fi

        notify-send $notify_id -t 3000 "       Connecting to VPN: \"$vpn_name\""
        local output
        output=$(echo "vpn.secrets.password:$pass" | nmcli connection up id "$vpn_name" passwd-file /dev/stdin 2>&1)

        if [[ $? -eq 0 ]]; then
            notify-send $notify_id -t 3000 "       VPN Connected: \"$vpn_name\""
            break
        else
            error_output=$(echo "$output" | sed 's/Error: //')
            notify-send $notify_id -t 3000 "       VPN Connection Failed" "Retrying..."
        fi
    done
}

# --- Main Logic ---

# Check Wi-Fi status
wifi_status=$(nmcli -t -f WIFI general | tail -n1)

if [[ "$wifi_status" == "disabled" ]]; then
    choice=$(enable_wifi_menu)
    [[ -z "$choice" ]] && exit 0
    nmcli radio wifi on
    notify-send $notify_id "         Wi-Fi Enabled..."
    exit 0
fi

# Get currently connected SSID
connected_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2- || true)

# Get list of networks
wifi_list=$(nmcli -t -f ssid,security dev wifi | awk -F: '
{
    icon = ($2 ~ /WPA|WEP|802\.1X/) ? "󱚿" : "󱛀";
    if ($1 != "") {
        printf "%s   %s\n", icon, $1
    }
}' | sort -u)

# Compose status line
if [[ -n "$connected_ssid" ]]; then
    connection_status="   Connected to $connected_ssid"
else
    connection_status="󰖪  Wi-Fi not connected"
fi

#VPN
vpn_profiles=$(nmcli -t -f NAME,TYPE connection show | grep ':vpn$' | cut -d: -f1 || true)
active_vpn=$(nmcli -t -f NAME,TYPE connection show --active | grep ':vpn$' | cut -d: -f1 | head -n1 || true)

vpn_list=""
vpn_section_header=""
if [[ -n "$vpn_profiles" ]]; then

    vpn_section_header="--- VPN PROFILES ---\n"
    vpn_list=$(echo "$vpn_profiles" | awk -v active="$active_vpn" '
    {
        if ($0 == active) {
            printf "󰳈   [VPN Active] %s\n", $0
        } else {
            printf "󰦜  [VPN] %s\n", $0
        }
    }')
fi

# Show Rofi Menu
choice=$(list_wifi_menu)
[[ -z "$choice" ]] && exit 0

raw_choice="$choice"

if [[ "$raw_choice" == *"[VPN]"* || "$raw_choice" == *"[VPN Active]"* ]]; then
    vpn_target=$(echo "$choice" | sed -E 's/^.*\[VPN( Active)?\] //')
    
    if [[ "$vpn_target" == "$active_vpn" ]]; then
        nmcli connection down id "$vpn_target"
        notify-send $notify_id -t 3000 "         Disconnected from VPN: \"$vpn_target\""
    else
        notify-send $notify_id -t 3000 " 󰳈      Connecting to VPN: \"$vpn_target\"..."
        if nmcli connection up id "$vpn_target" >/dev/null 2>&1; then
            notify-send $notify_id -t 3000 "       VPN Connected to \"$vpn_target\""
        else
            connect_vpn_secure_loop "$vpn_target"
        fi
    fi
    exit 0
fi

ssid_name=$(echo "$choice" | sed 's/^[^ ]*   //')

case "$raw_choice" in
"--- VPN PROFILES ---")
    exit 0
    ;;

*"Disable Wi-Fi"*)
    nmcli radio wifi off
    notify-send $notify_id "         Wi-Fi Disabled..."
    ;;

*"Manage Known Networks"*)
    manage_known_networks "$@"
    ;;

*"Manual Setup"*)
    manual_ssid=$(prompt_ssid)
    [[ -z "$manual_ssid" ]] && exit 0
    manual_password=$(prompt_password)
    nmcli dev wifi connect "$manual_ssid" hidden yes password "$manual_password"
    ;;

*"Rescan"*)
    notify-send $notify_id -t 3000 "       Rescanning Wi-Fi networks..."
    nmcli dev wifi rescan >/dev/null 2>&1 || true
    sleep 1
    exec "$0" "$@"
    ;;

*"Connected to"*)
    nmcli connection down "$connected_ssid"
    notify-send $notify_id -t 3000 "         Disconnected from \"$connected_ssid\""
    ;;

*"Wi-Fi not connected"*)
    exit 0
    ;;

*)
    saved_profile_exists=false
    if nmcli -t -f NAME connection show | grep -q -x "$ssid_name"; then
        saved_profile_exists=true
    fi

    if [[ "$saved_profile_exists" == "true" ]]; then
        notify-send $notify_id -t 3000 "  ...    Connecting to saved network: \"$ssid_name\""
        if nmcli dev wifi connect "$ssid_name" >/dev/null 2>&1; then
            notify-send $notify_id -t 3000 "       Connected to \"$ssid_name\""
            exit 0
        else
            notify-send $notify_id -t 3000 "       Login failed. Retrying with password..."
        fi
    fi

    if [[ "$raw_choice" == *"  "* ]]; then
        connect_secure_loop "$ssid_name"
    else
        notify-send $notify_id -t 3000 " ...  Connecting to \"$ssid_name\""
        if nmcli dev wifi connect "$ssid_name" >/dev/null 2>&1; then
            notify-send $notify_id -t 3000 "       Connected to \"$ssid_name\""
        else
            notify-send $notify_id -t 3000 "       Connection Failed..."
        fi
    fi
    ;;
esac
