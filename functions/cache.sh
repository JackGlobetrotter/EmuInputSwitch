#!/usr/bin/env bash
set -e

# ---- cache.sh ----
# Usage in main script:
#   source cache.sh
#   TITLE_IDS=$(get_title_ids "search string" "switch")  # optional console

CACHE_DIR="$HOME/.cache/inputswitch"
SWITCH_JSON="$CACHE_DIR/titles_switch.json"
WIIU_JSON="$CACHE_DIR/titles_wiiu.json"
SWITCH_INDEX="$CACHE_DIR/index_switch.json"
WIIU_INDEX="$CACHE_DIR/index_wiiu.json"
TINFOIL_API="https://tinfoil.media/Title/ApiJson/?rating_content=&language=&category=&region=us"
WIIU_API="https://raw.githubusercontent.com/bendevnull/linktag-data/master/ids/cemu.json"

get_title_ids() {
    local SEARCH="$1"
    local CONSOLE="${2:-switch}"  # default to switch if not provided

    if [ -z "$SEARCH" ]; then
        echo "Usage: get_title_ids <search string> [switch|wiiu]" >&2
        return 1
    fi

    mkdir -p "$CACHE_DIR"

    # Select JSON and INDEX
    local JSON INDEX API_URL
    if [[ "$CONSOLE" == "wiiu" ]]; then
        JSON="$WIIU_JSON"
        INDEX="$WIIU_INDEX"
        API_URL="$WIIU_API"
    else
        JSON="$SWITCH_JSON"
        INDEX="$SWITCH_INDEX"
        API_URL="$TINFOIL_API"
    fi

    # Download JSON if missing or older than 7 days
    if [[ ! -f "$JSON" || $(find "$JSON" -mtime +7) ]]; then
        echo "Downloading $CONSOLE JSON..."
        curl -s "$API_URL" -o "$JSON"
    fi

    # Build normalized index
    if [[ ! -f "$INDEX" || "$JSON" -nt "$INDEX" ]]; then
        echo "Building normalized index for $CONSOLE..."
        if [[ "$CONSOLE" == "wiiu" ]]; then
            jq -c '
                to_entries[]
                | {title: .key}
                | .ids = (.value[] | .[] )
                | .normalized = (.title
                    | gsub("\\n"; " ")
                    | gsub("[™©®]"; "")
                    | ascii_downcase
                    | gsub("[^a-z0-9 ]"; "")
                    | gsub(" +"; " ")
                )
                | .ids[] as $id | {title: .title, id: $id, normalized: .normalized}
            ' "$JSON" > "$INDEX"
        else
            jq -c '
                .data[]
                | {
                    id: .id,
                    title: .name,
                    normalized: (
                        .name
                        | gsub("<[^>]+>"; "")
                        | gsub("[™©®]"; "")
                        | @text
                        | ascii_downcase
                        | gsub("[^a-z0-9 ]"; "")
                        | gsub(" +"; " ")
                    )
                }
            ' "$JSON" > "$INDEX"
        fi
    fi

    # Normalize search string
    local NORM_SEARCH
    NORM_SEARCH=$(echo "$SEARCH" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')

    # Return matching IDs, one per line
    jq -r --arg s "$NORM_SEARCH" 'select(.normalized | contains($s)) | .id' "$INDEX"
}
