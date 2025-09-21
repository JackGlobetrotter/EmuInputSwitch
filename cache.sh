#!/usr/bin/env bash
set -e

CACHE_DIR="$HOME/.cache/inputswitch"
SWITCH_JSON="$CACHE_DIR/titles_switch.json"
WIIU_JSON="$CACHE_DIR/titles_wiiu.json"
SWITCH_INDEX="$CACHE_DIR/index_switch.json"
WIIU_INDEX="$CACHE_DIR/index_wiiu.json"
TINFOIL_API="https://tinfoil.media/Title/ApiJson/?rating_content=&language=&category=&region=us"
WIIU_API="https://raw.githubusercontent.com/bendevnull/linktag-data/master/ids/cemu.json"

SEARCH=""
CONSOLE="switch"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--console)
            CONSOLE="$2"
            shift 2
            ;;
        -s|--search)
            SEARCH="$2"
            shift 2
            ;;
        *)
            # Treat any extra args as part of the search string
            if [ -z "$SEARCH" ]; then
                SEARCH="$1"
            else
                SEARCH="$SEARCH $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$SEARCH" ]; then
    echo "Usage: $0 [-c switch|wiiu] \"search string\"" >&2
    exit 1
fi

mkdir -p "$CACHE_DIR"

# Set cache & API based on console
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
if [ ! -f "$JSON" ] || [ $(find "$JSON" -mtime +7) ]; then
    echo "Downloading $CONSOLE JSON..."
    curl -s "$API_URL" -o "$JSON"
fi

# Preprocess index if missing or JSON is newer
if [ ! -f "$INDEX" ] || [ "$JSON" -nt "$INDEX" ]; then
    echo "Building normalized index for $CONSOLE..."
    if [[ "$CONSOLE" == "wiiu" ]]; then
        # cemu.json format: assume {"id":"...","title":"..."} for each entry
        jq -c '
        to_entries[]
        | {
            title: .key,
            id: (.value[] | .[]),      # flatten all regional IDs into individual entries
            normalized: (.key
                | gsub("\\n"; " ")
                | gsub("[™©®]"; "")
                | ascii_downcase
                | gsub("[^a-z0-9 ]"; "")
                | gsub(" +"; " ")
            )
        }
        ' "$JSON" > "$INDEX"
    else
        # switch/Tinfoil
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
NORM_SEARCH=$(echo "$SEARCH" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')

# Search and return IDs
jq -r --arg s "$NORM_SEARCH" 'select(.normalized | contains($s)) | .id' "$INDEX"
