#!/bin/bash
set -e

BASE_DIR="/home/deck/games/Emulation/tools/inputswitch"

source "$BASE_DIR/functions/controllers.sh"
source "$BASE_DIR/functions/cache.sh"
source "$BASE_DIR/functions/launcher.sh"

CONFIG_FILE="$HOME/.config/inputswitch/controllers.conf"

# Array for extra args
ARGS=()

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


TITLE_IDS=($(get_title_ids "$NORM_TITLE" "$CONSOLE"))

load_controller_config

PROFILE=$(get_controller_profile)

update_launcher_config "$LAUNCHER" "$PROFILE" "${TITLE_IDS[@]}"
echo "calling /home/deck/games/Emulation/tools/launchers/${LAUNCHER}.sh with args: ${ARGS[*]}"
"/home/deck/games/Emulation/tools/launchers/${LAUNCHER}.sh" "${ARGS[@]}"
