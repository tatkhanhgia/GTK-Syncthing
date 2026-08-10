#!/usr/bin/env bash
# Sync now - trigger folder membership sync immediately (macOS)

set -euo pipefail

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GKG_ROOT="$(cd "$MAC_DIR/../.." && pwd)"

# shellcheck source=load-config.sh
source "$MAC_DIR/load-config.sh"
# shellcheck source=syncthing-setup.sh
source "$MAC_DIR/syncthing-setup.sh"

if ! load_gkg_config "$GKG_ROOT"; then
    echo ''
    write_err 'No config.ini found. Run GKG-Sync.command first.'
    echo ''
    exit 1
fi

if ! test_syncthing_installed; then
    echo ''
    write_err 'Syncthing is not installed.'
    echo 'Run GKG-Sync.command first.'
    echo ''
    exit 1
fi

echo ''
write_info 'Syncing now...'

start_syncthing_process
sleep 2

if [[ -f "$(get_syncthing_config_path)" ]]; then
    api_key="$(get_syncthing_api_key "$(get_syncthing_config_path)")"
    my_id="$(get_local_syncthing_device_id "$api_key")"

    if [[ "${NET_IS_HUB:-false}" == "true" ]]; then
        write_info 'Hub detected - syncing folder membership...'
        sync_folder_membership "$api_key" "$SYNCTHING_FOLDER_ID" "$my_id" || true
    else
        write_warn "Member machine (hub: ${NET_INTRODUCER_ID:-none}) - waiting for hub to share."
    fi
fi

echo ''
write_ok 'Done. Devices on this machine should now share the sync folder.'
echo ''