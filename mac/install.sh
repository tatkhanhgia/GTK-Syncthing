#!/usr/bin/env bash
# GKG-Syncthing - one-click installer (macOS)

set -euo pipefail

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GKG_ROOT="$(cd "$MAC_DIR/.." && pwd)"

# shellcheck source=load-config.sh
source "$MAC_DIR/load-config.sh"
# shellcheck source=syncthing-setup.sh
source "$MAC_DIR/syncthing-setup.sh"
# shellcheck source=preflight.sh
source "$MAC_DIR/preflight.sh"

show_banner() {
    echo ''
    echo '========================================'
    echo '   FILE SYNC - ONE-CLICK INSTALLER'
    echo '========================================'
    echo ''
    echo 'Just follow the step-by-step instructions.'
    echo ''
}

show_syncthing_result() {
    local device_id="$1"
    local gui_url="$2"
    local sync_folder="$3"
    local html_path

    html_path="$(write_install_result_html "$GKG_ROOT" "$device_id" "$sync_folder" "$gui_url")"

    echo ''
    echo '========================================'
    echo '   SETUP COMPLETE!'
    echo '========================================'
    echo ''
    write_ok "Sync folder: $sync_folder"
    echo ''
    write_info 'Result page opened — click “Copy Device ID” and send it to the other machine(s).'
    echo ''

    show_device_id_result "$device_id" "$html_path"
    open "$gui_url" 2>/dev/null || true
}

main() {
    load_gkg_config "$GKG_ROOT"
    clear_duplicate_local_device_id
    load_gkg_config "$GKG_ROOT"
    maybe_refresh_local_tailscale_ip
    show_banner
    ensure_tailscale

    local join_mode="false" join_hub_id=""
    local -a remote_ids=() wizard_ids=()
    local id line prefix value config_count=0

    if [[ "${1:-}" == "join" ]]; then
        join_mode="true"
        join_hub_id="${NET_INTRODUCER_ID:-}"
    fi

    while IFS= read -r id; do
        [[ -n "$id" ]] && remote_ids+=("$id")
    done < <(get_peer_device_ids)
    config_count=${#remote_ids[@]}

    if [[ $config_count -gt 0 ]]; then
        write_info "Using $config_count peer(s) from config.ini"
    fi

    if [[ -z "${NET_INTRODUCER_ID:-}" && $config_count -eq 0 ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            prefix="${line%%:*}"
            value="${line#*:}"
            value="$(echo "$value" | xargs)"
            if [[ "$prefix" == "JOIN" ]]; then
                join_mode="true"
                join_hub_id="$value"
            elif [[ "$prefix" == "PEER" ]]; then
                [[ -n "$value" ]] && is_valid_syncthing_device_id "$value" && wizard_ids+=("$value")
            fi
        done < <(invoke_setup_wizard)
        remote_ids=("${wizard_ids[@]}")
    fi

    if [[ "$join_mode" == "true" && -z "$join_hub_id" ]]; then
        while :; do
            join_hub_id="$(mac_ask 'GKG Sync' 'Paste the Hub Device ID:' '')"
            join_hub_id="$(echo "$join_hub_id" | xargs)"
            [[ -n "$join_hub_id" ]] && is_valid_syncthing_device_id "$join_hub_id" && break
        done
    fi

    echo ''
    write_info 'Installing... (this may take a few minutes)'

    local result device_id gui_url sync_folder
    if [[ "$join_mode" == "true" ]]; then
        NET_INTRODUCER_ID="$join_hub_id"
        result="$(install_syncthing_mode)"
    elif [[ -z "${remote_ids[*]-}" ]]; then
        result="$(install_syncthing_mode)"
    else
        result="$(install_syncthing_mode "${remote_ids[@]}")"
    fi

    device_id="$(echo "$result" | sed -n 's/^DEVICE_ID=//p')"
    gui_url="$(echo "$result" | sed -n 's/^GUI_URL=//p')"
    sync_folder="$(echo "$result" | sed -n 's/^SYNC_FOLDER=//p')"

    save_gkg_config_after_install "$device_id" "${wizard_ids[@]}"
    write_ok "Updated config.ini with this machine's Device ID"

    if [[ "$join_mode" == "true" && -n "$join_hub_id" ]]; then
        ini_set_in_section network introducer_device_id "$join_hub_id" "$CONFIG_INI"
    fi

    show_syncthing_result "$device_id" "$gui_url" "$sync_folder"
}

main "$@"
