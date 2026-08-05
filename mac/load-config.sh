#!/usr/bin/env bash
# Doc config.ini chung (macOS + Windows)

set -euo pipefail

GKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ini_get() {
    local section="$1"
    local key="$2"
    local file="$3"
    awk -F= -v section="$section" -v key="$key" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\[/ {
            current = trim(substr($0, 2, length($0) - 2))
            next
        }
        current == section && $0 !~ /^[ \t]*[;#]/ && index($0, "=") > 0 {
            k = trim($1)
            v = trim(substr($0, index($0, "=") + 1))
            if (k == key) {
                print v
                exit
            }
        }
    ' "$file"
}

ini_list_peer_sections() {
    local file="$1"
    awk '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\[/ {
            section = trim(substr($0, 2, length($0) - 2))
            if (section ~ /^peer\./) {
                print section
            }
        }
    ' "$file" | sort
}

expand_home_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        echo ""
        return
    fi
    if [[ "$path" == "~"* ]]; then
        path="${path/#\~/$HOME}"
    fi
    echo "$path"
}

load_gkg_config() {
    local root="${1:-$GKG_ROOT}"
    local ini_path="$root/config.ini"
    local example_path="$root/config.example.ini"

    if [[ ! -f "$ini_path" ]]; then
        if [[ ! -f "$example_path" ]]; then
            echo "[LOI] Khong tim thay config.ini hoac config.example.ini" >&2
            return 1
        fi
        cp "$example_path" "$ini_path"
        echo "Da tao config.ini tu config.example.ini"
        echo ""
    fi

    CONFIG_INI="$ini_path"

    LOCAL_MACHINE_NAME="$(ini_get local machine_name "$ini_path")"
    if [[ -z "$LOCAL_MACHINE_NAME" ]]; then
        LOCAL_MACHINE_NAME="$(hostname -s 2>/dev/null || hostname)"
    fi

    LOCAL_MACHINE_IP="$(ini_get local tailscale_ip "$ini_path")"
    if [[ -z "$LOCAL_MACHINE_IP" ]]; then
        LOCAL_MACHINE_IP="CHANGE-ME"
    fi

    SYNC_FOLDER="$(ini_get local sync_folder "$ini_path")"
    SYNC_FOLDER="$(expand_home_path "$SYNC_FOLDER")"
    if [[ -z "$SYNC_FOLDER" ]]; then
        SYNC_FOLDER="$HOME/Documents/Sync"
    fi

    SYNCTHING_FOLDER_ID="$(ini_get syncthing folder_id "$ini_path")"
    if [[ -z "$SYNCTHING_FOLDER_ID" ]]; then
        SYNCTHING_FOLDER_ID="documents-sync"
    fi

    SYNCTHING_FOLDER_LABEL="$(ini_get syncthing folder_label "$ini_path")"
    if [[ -z "$SYNCTHING_FOLDER_LABEL" ]]; then
        SYNCTHING_FOLDER_LABEL="Documents Sync"
    fi

    SYNCTHING_PORT="$(ini_get syncthing port "$ini_path")"
    if [[ -z "$SYNCTHING_PORT" ]]; then
        SYNCTHING_PORT="8384"
    fi

    INSTALL_DIR="$HOME/Library/Application Support/GKG-Syncthing"

    PEER_NAMES=()
    PEER_IPS=()
    PEER_DEVICE_IDS=()

    while IFS= read -r section; do
        [[ -z "$section" ]] && continue
        PEER_NAMES+=("$(ini_get "$section" name "$ini_path")")
        PEER_IPS+=("$(ini_get "$section" tailscale_ip "$ini_path")")
        PEER_DEVICE_IDS+=("$(ini_get "$section" device_id "$ini_path")")
    done < <(ini_list_peer_sections "$ini_path")
}

get_peer_device_ids() {
    local ids=()
    local id
    for id in "${PEER_DEVICE_IDS[@]:-}"; do
        id="$(echo "$id" | xargs)"
        if [[ -n "$id" ]]; then
            ids+=("$id")
        fi
    done
    if [[ ${#ids[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%s\n' "${ids[@]}"
}

get_syncthing_config_path() {
    echo "$HOME/Library/Application Support/Syncthing/config.xml"
}

get_syncthing_gui_url() {
    echo "http://127.0.0.1:${SYNCTHING_PORT}"
}
