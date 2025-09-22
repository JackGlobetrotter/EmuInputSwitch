#!/bin/bash
set -e

declare -A CONTROLLER_MAP
BLACKLIST_CONTROLLERS=()
DEFAULT_PROFILE="SteamDeckPad"


load_controller_config() {
    while IFS='=' read -r key value; do
        # Strip whitespace and carriage returns
        key="$(echo "$key" | tr -d '\r' | xargs)"
        value="$(echo "$value" | tr -d '\r' | xargs)"

        # Skip comments and empty lines
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        if [[ "$key" == DEFAULT ]]; then
            DEFAULT_PROFILE="$value"
        elif [[ "$key" == \!* ]]; then
            BLACKLIST_CONTROLLERS+=("${key:1}")
        else
            CONTROLLER_MAP["$key"]="$value"
        fi
    done < "$CONFIG_FILE"
}

get_controller_profile() {
    for key in "${!CONTROLLER_MAP[@]}"; do
        local profile="${CONTROLLER_MAP[$key]}"

        # Skip blacklisted
        for bad in "${BLACKLIST_CONTROLLERS[@]}"; do
            [[ "$key" == "$bad" ]] && continue 2
        done

        key="${key//$'\r'/}"         # remove carriage return
        profile="${profile//$'\r'/}" # remove carriage return


        if [[ "$key" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            # MAC address
            if bluetoothctl info "$key" 2>/dev/null | grep -q "Connected: yes"; then
                echo "$profile"
                return 0
            fi
        else
            # Device name: check all connected devices
            if bluetoothctl info | grep -i "Name: $key" | grep -q "Connected: yes"; then
                echo "Matched Name: $key -> $profile"
                return 0
            fi
        fi
    done

    echo "$DEFAULT_PROFILE"
}
