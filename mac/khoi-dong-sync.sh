#!/usr/bin/env bash
# Khoi dong Syncthing va mo thu muc sync (macOS)

set -euo pipefail

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GKG_ROOT="$(cd "$MAC_DIR/.." && pwd)"

# shellcheck source=load-config.sh
source "$MAC_DIR/load-config.sh"
# shellcheck source=syncthing-setup.sh
source "$MAC_DIR/syncthing-setup.sh"

if ! load_gkg_config "$GKG_ROOT"; then
    echo ''
    write_err 'Chua co config.ini. Chay mac/cai-dat-sync.command truoc.'
    echo ''
    exit 1
fi

if ! test_syncthing_installed; then
    echo ''
    write_err 'Syncthing chua duoc cai.'
    echo 'Chay mac/cai-dat-sync.command truoc.'
    echo ''
    exit 1
fi

echo ''
write_info 'Dang khoi dong Syncthing...'
start_syncthing_process
sleep 2

write_ok 'Mo thu muc sync...'
open "$SYNC_FOLDER" 2>/dev/null || true

url="$(get_syncthing_gui_url)"
write_ok "Trang quan ly: $url"
open "$url" 2>/dev/null || true

echo ''
write_ok 'Xong. File trong thu muc Sync se tu dong dong bo.'
echo ''
