#!/usr/bin/env bash

BT_THEME="$HOME/.config/rofi/bluetooth/list.rasi"
rofi_extra_args=("$@")

run_rofi() {
    rofi -dmenu -markup-rows -i -theme "$BT_THEME" "${rofi_extra_args[@]}" "$@"
}

readonly CONTROLLER_PROPERTY_POWER="Power"
readonly CONTROLLER_PROPERTY_SCAN="Scan"
readonly CONTROLLER_PROPERTY_PAIRABLE="Pairable"
readonly CONTROLLER_PROPERTY_DISCOVERABLE="Discoverable"
readonly CONTROLLER_OPTION_RESTART_AGENT="Restart pairing agent"

readonly DEVICE_PROPERTY_CONNECTED="Connected"
readonly DEVICE_PROPERTY_PAIRED="Paired"
readonly DEVICE_PROPERTY_TRUSTED="Trusted"
readonly DEVICE_OPTION_REMOVE="Remove"

readonly OPTION_EXIT="Exit"
readonly OPTION_BACK="Back"

declare -A devices

get_available_devices() {
    devices=()
    local line mac name
    while IFS= read -r line; do
        mac="$(cut -d' ' -f2 <<< "$line")"
        name="$(cut -d' ' -f3- <<< "$line")"
        [[ -n "$mac" ]] && devices["$mac"]="$name"
    done < <(bluetoothctl devices | sed $'s/\033\\[[0-9;]*m//g')
}

get_property_state_string() {
    local property="$1"
    local expected_string

    case "$property" in
        "$CONTROLLER_PROPERTY_POWER")        expected_string="PowerState: on\|Powered: yes" ;;
        "$CONTROLLER_PROPERTY_SCAN")         expected_string="Discovering: yes" ;;
        "$CONTROLLER_PROPERTY_PAIRABLE")     expected_string="Pairable: yes" ;;
        "$CONTROLLER_PROPERTY_DISCOVERABLE") expected_string="Discoverable: yes" ;;
        *) return 1 ;;
    esac

    if bluetoothctl show | grep -q "$expected_string"; then
        echo "$property: on"
    else
        echo "$property: off"
    fi
}

get_device_property_state_string() {
    local mac="$1"
    local property="$2"
    [[ -z "$mac" || -z "$property" ]] && return 1

    if bluetoothctl info "$mac" | grep -q "$property: yes"; then
        echo "$property: yes"
    else
        echo "$property: no"
    fi
}

get_mac_address() {
    local target_name="$1"
    local mac
    for mac in "${!devices[@]}"; do
        if [[ "${devices[$mac]}" == "$target_name" ]]; then
            echo "$mac"
            return 0
        fi
    done
    return 1
}

strip_prefix() {
    echo "$1" | sed 's/^[^ ]*   //'
}

open_device_menu() {
    local mac_address="$1"
    [[ -z "$mac_address" ]] && return 1

    local conn_state pair_state trust_state
    conn_state=$(get_device_property_state_string "$mac_address" "$DEVICE_PROPERTY_CONNECTED")
    pair_state=$(get_device_property_state_string "$mac_address" "$DEVICE_PROPERTY_PAIRED")
    trust_state=$(get_device_property_state_string "$mac_address" "$DEVICE_PROPERTY_TRUSTED")

    local rofi_options=()
    [[ "$conn_state" == *": yes" ]] && rofi_options+=("   $conn_state") || rofi_options+=("   $conn_state")
    [[ "$pair_state" == *": yes" ]] && rofi_options+=("   $pair_state") || rofi_options+=("   $pair_state")
    [[ "$trust_state" == *": yes" ]] && rofi_options+=("   $trust_state") || rofi_options+=("   $trust_state")
    rofi_options+=("   $DEVICE_OPTION_REMOVE")
    rofi_options+=("--- NAVIGATION ---")
    rofi_options+=("   $OPTION_BACK")
    rofi_options+=("   $OPTION_EXIT")

    local choice
    choice=$(printf '%s\n' "${rofi_options[@]}" | run_rofi)
    [[ -z "$choice" ]] && exit 0

    local clean_choice
    clean_choice=$(strip_prefix "$choice")

    case "$clean_choice" in
        "$DEVICE_PROPERTY_CONNECTED: yes")
            bluetoothctl disconnect "$mac_address"
            open_device_menu "$mac_address"
            ;;
        "$DEVICE_PROPERTY_CONNECTED: no")
            bluetoothctl connect "$mac_address"
            open_device_menu "$mac_address"
            ;;
        "$DEVICE_PROPERTY_PAIRED: yes")
            bluetoothctl unpair "$mac_address"
            open_device_menu "$mac_address"
            ;;
        "$DEVICE_PROPERTY_PAIRED: no")
            bluetoothctl pair "$mac_address"
            open_device_menu "$mac_address"
            ;;
        "$DEVICE_PROPERTY_TRUSTED: yes")
            bluetoothctl untrust "$mac_address"
            open_device_menu "$mac_address"
            ;;
        "$DEVICE_PROPERTY_TRUSTED: no")
            bluetoothctl trust "$mac_address"
            open_device_menu "$mac_address"
            ;;
        "$DEVICE_OPTION_REMOVE")
            bluetoothctl remove "$mac_address"
            open_main_menu
            ;;
        "$OPTION_BACK")
            open_main_menu
            ;;
        "$OPTION_EXIT")
            exit 0
            ;;
        *)
            open_device_menu "$mac_address"
            ;;
    esac
}

open_main_menu() {
    local rofi_options=()
    local power_state
    power_state=$(get_property_state_string "$CONTROLLER_PROPERTY_POWER")

    if [[ "$power_state" == "$CONTROLLER_PROPERTY_POWER: on" ]]; then
        rofi_options+=("󰂲  Disable Bluetooth")
        get_available_devices

        if (( ${#devices[@]} > 0 )); then
            local mac dev_name
            for mac in "${!devices[@]}"; do
                dev_name="${devices[$mac]}"
                if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                    rofi_options+=("   $dev_name")
                else
                    rofi_options+=("   $dev_name")
                fi
            done
        fi

        rofi_options+=("   $CONTROLLER_PROPERTY_SCAN")
        rofi_options+=("   $(get_property_state_string "$CONTROLLER_PROPERTY_PAIRABLE")")
        rofi_options+=("   $(get_property_state_string "$CONTROLLER_PROPERTY_DISCOVERABLE")")
        rofi_options+=("   $CONTROLLER_OPTION_RESTART_AGENT")
    else
        rofi_options+=("   Enable Bluetooth")
    fi

    local choice
    choice=$(printf '%s\n' "${rofi_options[@]}" | run_rofi)
    [[ -z "$choice" ]] && exit 0

    local clean_choice
    clean_choice=$(strip_prefix "$choice")

    local clean_choice
    clean_choice=$(strip_prefix "$choice")

    case "$clean_choice" in
        *"Disable Bluetooth"*)
            bluetoothctl power off
            open_main_menu
            ;;
        *"Enable Bluetooth"*)
            rfkill unblock bluetooth 2>/dev/null
            bluetoothctl power on
            sleep 0.5
            open_main_menu
            ;;
        "$CONTROLLER_PROPERTY_SCAN")
            notify-send -t 3000 "       Scanning for Bluetooth devices..."
            bluetoothctl --timeout 5 scan on
            open_main_menu
            ;;
        "$CONTROLLER_PROPERTY_PAIRABLE: on")
            bluetoothctl pairable off
            open_main_menu
            ;;
        "$CONTROLLER_PROPERTY_PAIRABLE: off")
            bluetoothctl pairable on
            open_main_menu
            ;;
        "$CONTROLLER_PROPERTY_DISCOVERABLE: on")
            bluetoothctl discoverable off
            open_main_menu
            ;;
        "$CONTROLLER_PROPERTY_DISCOVERABLE: off")
            bluetoothctl discoverable on
            open_main_menu
            ;;
        "$CONTROLLER_OPTION_RESTART_AGENT")
            bluetoothctl <<< $'agent off\nagent on\ndefault-agent'
            open_main_menu
            ;;
        *)
            local target_mac
            target_mac=$(get_mac_address "$clean_choice")
            if [[ -n "$target_mac" ]]; then
                open_device_menu "$target_mac"
            else
                exit 1
            fi
            ;;
    esac
}

open_main_menu

