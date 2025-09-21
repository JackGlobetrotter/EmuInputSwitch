#!/bin/bash
set -e

MAC="E4:17:D8:2E:84:E3"

PROFILE_DIR_CEMU="/home/deck/.config/Cemu/gameProfiles"
PROFILE_DIR_EDEN="/home/deck/.config/eden/custom/"
PROFILE_DIR_YUZU="/home/deck/.config/yuzu/custom/"

WL_CONTROLLER_PROFILE="8bitdo"
STEAMDECK_CONTROLLER_PROFILE="steamdeck"

# Array for extra args
ARGS=()

CACHE_SCRIPT="./cache.sh"

update_controller_cemu() {
    local FILE="$1"
    sed -i -E '$c\controller1 = '"$CONTROLLER_PROFILE" "$FILE"
}


update_controller_yuzu() {
    local FILE="$1"
    sed -i -E 's/^(player_[0-9]+_profile_name)=.*/\1='"$CONTROLLER_PROFILE"'/' "$FILE"
}

update_controller() {
    local LAUNCHER="$1"
    shift
    local TITLE_IDS=("$@")
    
    local BASE_DIR
    case "$LAUNCHER" in
        yuzu)
            BASE_DIR="$PROFILE_DIR_YUZU"
            ;;
        cemu)
            BASE_DIR="$PROFILE_DIR_CEMU"
            ;;
        eden)
            BASE_DIR="$PROFILE_DIR_EDEN"
            ;;
        *)
            echo "Unknown launcher: $LAUNCHER" >&2
            return 1
            ;;
    esac

    # Loop over IDs and call the appropriate function
    for id in "${TITLE_IDS[@]}"; do
        local FILE="$BASE_DIR/${id}.ini"
        if [[ -f "$FILE" ]]; then
            echo "Updating controller for $FILE"
            case "$LAUNCHER" in
                yuzu|eden)
                    update_controller_yuzu "$FILE"
                    ;;
                cemu)
                    update_controller_cemu "$FILE"
                    ;;
            esac
        fi
    done
}
    


# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--launcher)
            LAUNCHER="$2"
            shift 2
            ;;
        -t|--title)
            TITLE="$2"
            shift 2
            ;;
        -g|--game)
            GAME="$2"
            ARGS+=("$1" "$2")  # keep flag and value for passing through
            shift 2
            ;;
        *)
            # Everything else goes to ARGS
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Require launcher
if [ -z "$LAUNCHER" ]; then
    echo "Usage: $0 -l <launcher> [-t <title>] [args...]" >&2
    exit 1
fi

if [ "$LAUNCHER" = "cemu" ]; then
    CONSOLE="wiiu"
else
    CONSOLE="switch"
fi

# Derive TITLE if not provided
if [ -z "$TITLE" ]; then
    if [ -n "$GAME" ]; then
        # Use game file if provided
        TITLE="$(basename "$GAME")"
        TITLE="${TITLE%.*}"
    elif [ ${#ARGS[@]} -gt 0 ]; then
        # Fallback: last ARGS element
        LAST_ARG="${ARGS[-1]}"
        TITLE="$(basename "$LAST_ARG")"
        TITLE="${TITLE%.*}"
    else
        echo "No title provided and no game file specified" >&2
        exit 1
    fi
fi

# Normalize title (same as in cache.sh)
NORM_TITLE=$(echo "$TITLE" \
    | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]//g' \
    | tr -s ' ')

# Call cache.sh to get the IDs
# Assume cache.sh can take a normalized search string as 1st arg
TITLE_IDS=$("$CACHE_SCRIPT" -s "$NORM_TITLE" -c "$CONSOLE")

# Global variable to store the currently connected controller profile
if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
    CONTROLLER_PROFILE="$WL_CONTROLLER_PROFILE"
else
    CONTROLLER_PROFILE="$STEAMDECK_CONTROLLER_PROFILE"
fi


update_controller "$LAUNCHER" $TITLE_IDS    

"/home/deck/games/Emulation/tools/launchers/${LAUNCHER}.sh" "${ARGS[@]}"