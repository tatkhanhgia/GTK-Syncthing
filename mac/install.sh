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
    echo '   DONG BO FILE - TU DONG CAI DAT'
    echo '========================================'
    echo ''
    echo 'Chi can lam theo huong dan tung buoc.'
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
    echo '   CAI DAT XONG!'
    echo '========================================'
    echo ''
    write_ok "Thu muc sync: $sync_folder"
    echo ''
    write_info 'Trang ket qua dang mo — bam Copy Device ID va gui cho may KIA.'
    echo ''

    show_device_id_result "$device_id" "$html_path"
    open "$gui_url" 2>/dev/null || true
}

main() {
    load_gkg_config "$GKG_ROOT"
    show_banner
    ensure_tailscale

    local remote_ids=()
    local id

    while IFS= read -r id; do
        [[ -n "$id" ]] && remote_ids+=("$id")
    done < <(get_peer_device_ids)

    if [[ ${#remote_ids[@]} -eq 0 ]]; then
        while IFS= read -r id; do
            [[ -n "$id" ]] && remote_ids+=("$id")
        done < <(invoke_setup_wizard "${remote_ids[@]}")
    fi

    echo ''
    write_info 'Dang cai dat... (cho vai phut)'

    local result device_id gui_url sync_folder
    result="$(install_syncthing_mode "${remote_ids[@]}")"
    device_id="$(echo "$result" | sed -n 's/^DEVICE_ID=//p')"
    gui_url="$(echo "$result" | sed -n 's/^GUI_URL=//p')"
    sync_folder="$(echo "$result" | sed -n 's/^SYNC_FOLDER=//p')"

    show_syncthing_result "$device_id" "$gui_url" "$sync_folder"
}

main "$@"
