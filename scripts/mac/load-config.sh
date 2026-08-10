#!/usr/bin/env bash
# Shared config.ini loader (macOS + Windows)

set -euo pipefail

GKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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
            echo "[ERROR] Could not find config.ini or config.example.ini" >&2
            return 1
        fi
        cp "$example_path" "$ini_path"
        echo "Created config.ini from config.example.ini"
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

    NET_IS_HUB="$(ini_get network is_hub "$ini_path" | xargs)"
    if [[ "$NET_IS_HUB" != "true" ]]; then
        NET_IS_HUB="false"
    fi

    NET_INTRODUCER_ID="$(ini_get network introducer_device_id "$ini_path" | xargs)"
    if [[ "$NET_IS_HUB" == "true" && -n "$NET_INTRODUCER_ID" ]]; then
        echo "[network] is_hub=true & co introducer_device_id — bo qua (hub khong can)." >&2
        NET_INTRODUCER_ID=""
    fi

    LOCAL_DEVICE_ID="$(ini_get local device_id "$ini_path" | xargs)"
    if [[ -n "$NET_INTRODUCER_ID" && -n "$LOCAL_DEVICE_ID" && "$NET_INTRODUCER_ID" == "$LOCAL_DEVICE_ID" ]]; then
        echo "[network] introducer_device_id trung voi Device ID may nay — bo qua." >&2
        NET_INTRODUCER_ID=""
    fi

    NET_AUTO_SHARE="$(ini_get network auto_share "$ini_path" | xargs)"
    if [[ -z "$NET_AUTO_SHARE" || "$NET_AUTO_SHARE" == "false" ]]; then
        NET_AUTO_SHARE="false"
    else
        NET_AUTO_SHARE="true"
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

is_valid_syncthing_device_id() {
    local id="$1"
    [[ "$id" =~ ^[A-Z0-9]{7}(-[A-Z0-9]{7}){6}$ ]]
}

get_local_tailscale_ip() {
    if ! command -v tailscale >/dev/null 2>&1; then
        return 1
    fi
    local ip
    ip="$(tailscale ip -4 2>/dev/null | head -n 1 | xargs || true)"
    [[ -n "$ip" ]] || return 1
    echo "$ip"
}

ini_set_in_section() {
    local section="$1"
    local key="$2"
    local value="$3"
    local file="$4"
    local tmp found_section found_key
    tmp="$(mktemp)"
    found_section=0
    found_key=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\][[:space:]]*$ ]]; then
            if [[ $found_section -eq 1 && $found_key -eq 0 ]]; then
                echo "${key}=${value}"
                found_key=1
            fi
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                found_section=1
            else
                found_section=0
            fi
            echo "$line"
            continue
        fi

        if [[ $found_section -eq 1 && "$line" =~ ^[[:space:]]*${key}[[:space:]]*= ]]; then
            echo "${key}=${value}"
            found_key=1
            continue
        fi

        echo "$line"
    done < "$file" > "$tmp"

    if [[ $found_section -eq 1 && $found_key -eq 0 ]]; then
        echo "${key}=${value}" >> "$tmp"
        found_key=1
    fi

    if [[ $found_section -eq 0 ]]; then
        {
            cat "$tmp"
            echo ""
            echo "[$section]"
            echo "${key}=${value}"
        } > "$file"
    else
        cp "$tmp" "$file"
    fi
    rm -f "$tmp"
}

ini_peer_device_exists() {
    local device_id="$1"
    local file="$2"
    local section
    while IFS= read -r section; do
        [[ -z "$section" ]] && continue
        if [[ "$(ini_get "$section" device_id "$file" | xargs)" == "$device_id" ]]; then
            return 0
        fi
    done < <(ini_list_peer_sections "$file")
    return 1
}

clear_duplicate_local_device_id() {
    local ini_path="$CONFIG_INI"
    local local_id
    [[ -f "$ini_path" ]] || return 0
    local_id="$(ini_get local device_id "$ini_path" | xargs)"
    [[ -z "$local_id" ]] || return 0
    ini_peer_device_exists "$local_id" "$ini_path" || return 0
    ini_set_in_section local device_id "" "$ini_path"
}

ini_next_peer_index() {
    local file="$1"
    local max=0 n
    while IFS= read -r section; do
        [[ "$section" =~ ^peer\.([0-9]+)$ ]] || continue
        n="${BASH_REMATCH[1]}"
        if (( n > max )); then max=$n; fi
    done < <(ini_list_peer_sections "$file")
    echo $((max + 1))
}

save_gkg_config_after_install() {
    local device_id="$1"
    shift
    local -a added_peer_ids=("$@")
    local ini_path="$CONFIG_INI"
    local ts_ip name id next_idx

    [[ -f "$ini_path" ]] || return 0

    name="${LOCAL_MACHINE_NAME:-$(hostname -s 2>/dev/null || hostname)}"
    ini_set_in_section local machine_name "$name" "$ini_path"

    ts_ip="$(get_local_tailscale_ip 2>/dev/null || true)"
    if [[ -n "$ts_ip" ]]; then
        ini_set_in_section local tailscale_ip "$ts_ip" "$ini_path"
    fi

    ini_set_in_section local device_id "$device_id" "$ini_path"

    for id in "${added_peer_ids[@]}"; do
        id="$(echo "$id" | xargs)"
        [[ -z "$id" || "$id" == "$device_id" ]] && continue
        is_valid_syncthing_device_id "$id" || continue
        ini_peer_device_exists "$id" "$ini_path" && continue
        next_idx="$(ini_next_peer_index "$ini_path")"
        {
            echo ""
            echo "[peer.${next_idx}]"
            echo "name=Remote device ${next_idx}"
            echo "tailscale_ip=CHANGE-ME"
            echo "device_id=${id}"
        } >> "$ini_path"
    done
}

maybe_refresh_local_tailscale_ip() {
    local ini_path="$CONFIG_INI"
    local current ts_ip
    [[ -f "$ini_path" ]] || return 0
    current="$(ini_get local tailscale_ip "$ini_path" | xargs)"
    if [[ -n "$current" && "$current" != "CHANGE-ME" ]]; then
        return 0
    fi
    ts_ip="$(get_local_tailscale_ip 2>/dev/null || true)"
    [[ -n "$ts_ip" ]] || return 0
    ini_set_in_section local tailscale_ip "$ts_ip" "$ini_path"
}

get_peer_device_ids() {
    local ids=()
    local id self_id
    self_id="$(ini_get local device_id "${CONFIG_INI:-}" 2>/dev/null | xargs || true)"
    for id in "${PEER_DEVICE_IDS[@]:-}"; do
        id="$(echo "$id" | xargs)"
        [[ -z "$id" ]] && continue
        is_valid_syncthing_device_id "$id" || continue
        [[ -n "$self_id" && "$id" == "$self_id" ]] && continue
        ids+=("$id")
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
