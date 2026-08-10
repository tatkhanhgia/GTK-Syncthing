#!/usr/bin/env bash
# Start Syncthing and open the Sync folder (macOS)

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
write_info 'Starting Syncthing...'
start_syncthing_process
sleep 2

if [[ "${NET_IS_HUB:-false}" == "true" && -f "$(get_syncthing_config_path)" ]]; then
    write_info 'Hub detected — syncing folder membership...'
    api_key="$(get_syncthing_api_key "$(get_syncthing_config_path)")"
    my_id="$(get_local_syncthing_device_id "$api_key")"
    sync_folder_membership "$api_key" "$SYNCTHING_FOLDER_ID" "$my_id" || true
fi

write_ok 'Opening Sync folder...'
open "$SYNC_FOLDER" 2>/dev/null || true

url="$(get_syncthing_gui_url)"
write_ok "Syncthing management page: $url"
open "$url" 2>/dev/null || true

echo ''
write_ok 'Done. Files in the Sync folder will sync automatically.'
echo ''
