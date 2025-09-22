#!/bin/bash
set -e

# Declare launcher styles
get_launcher_style() {
    local launcher="$1"
    case "$launcher" in
        cemu)
            echo "cemu"
            ;;
        yuzu|eden|citron)
            echo "yuzu"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Base dir resolver
get_base_dir() {
    local launcher="$1"
    local style="$2"
    case "$style" in
        cemu)
            echo "$HOME/.config/Cemu/gameProfiles"
            ;;
        yuzu)
            echo "$HOME/.config/$launcher/custom"
            ;;
        *)
            echo ""
            ;;
    esac
}

update_launcher_cemu() {
    local FILE="$1"
    local CONTROLLER_PROFILE="$2"
    sed -i -E '$c\controller1 = '"$CONTROLLER_PROFILE" "$FILE"
}


update_launcher_yuzu() {
    local FILE="$1"
    local CONTROLLER_PROFILE="$2"
    sed -i -E 's/^(player_[0-9]+_profile_name)=.*/\1='"$CONTROLLER_PROFILE"'/' "$FILE"
}


update_launcher_config() {
    local LAUNCHER="$1"
    local PROFILE="$2"
    shift 2
    local TITLE_IDS=("$@")

    local STYLE
    STYLE=$(get_launcher_style "$LAUNCHER")

    if [ "$STYLE" = "unknown" ]; then
        echo "Unknown launcher: $LAUNCHER" >&2
        return 1
    fi

    local BASE_DIR
    BASE_DIR=$(get_base_dir "$LAUNCHER" "$STYLE")

    # Loop over IDs and call the appropriate updater
    for id in "${TITLE_IDS[@]}"; do
        local FILE="$BASE_DIR/${id}.ini"
        if [[ -f "$FILE" ]]; then
            echo "Updating controller for $FILE"
            case "$STYLE" in
                yuzu)
                    update_launcher_yuzu "$FILE" "$PROFILE"
                    ;;
                cemu)
                    update_launcher_cemu "$FILE" "$PROFILE"
                    ;;
            esac
        fi
    done
}