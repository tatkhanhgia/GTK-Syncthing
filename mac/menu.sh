#!/usr/bin/env bash
# GKG-Sync - Menu chinh (macOS)

set -euo pipefail

GKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC_DIR="$GKG_ROOT/mac"

# shellcheck source=load-config.sh
source "$MAC_DIR/load-config.sh" 2>/dev/null || true

mac_choose() {
    osascript <<'APPLESCRIPT'
set choices to {"1. Install / Add machine", "2. Restart sync", "3. Open Sync folder", "4. Guide", "5. Syncthing dashboard"}
set picked to choose from list choices with title "GKG Sync" with prompt "What do you want to do?" default items {"1. Install / Add machine"}
if picked is false then
    return "CANCEL"
else
    return item 1 of picked
end if
APPLESCRIPT
}

mac_alert() {
    osascript -e "display alert \"GKG Sync\" message \"$1\" as informational" 2>/dev/null || true
}

open_sync_folder() {
    if load_gkg_config "$GKG_ROOT" 2>/dev/null; then
        :
    else
        SYNC_FOLDER="$HOME/Documents/Sync"
    fi
    mkdir -p "$SYNC_FOLDER"
    open "$SYNC_FOLDER"
}

open_guide() {
    if [[ -f "$GKG_ROOT/START-HERE.html" ]]; then
        open "$GKG_ROOT/START-HERE.html"
    elif [[ -f "$GKG_ROOT/HUONG-DAN.html" ]]; then
        open "$GKG_ROOT/HUONG-DAN.html"
    fi
}

open_manage() {
    local port=8384
    if load_gkg_config "$GKG_ROOT" 2>/dev/null; then
        port="$SYNCTHING_PORT"
    fi
    open "http://127.0.0.1:${port}"
}

run_install() {
    chmod +x "$MAC_DIR"/*.sh "$GKG_ROOT"/*.command 2>/dev/null || true
    bash "$MAC_DIR/install.sh"
}

run_restart() {
    chmod +x "$MAC_DIR"/*.sh 2>/dev/null || true
    bash "$MAC_DIR/khoi-dong-sync.sh"
}

dispatch_action() {
    local choice="$1"
    case "$choice" in
        *"Install"*|*"1."*)
            run_install
            ;;
        *"Restart"*|*"2."*)
            run_restart
            ;;
        *"folder"*|*"3."*)
            open_sync_folder
            mac_alert "Opened Sync folder."
            ;;
        *"Guide"*|*"4."*)
            open_guide
            ;;
        *"dashboard"*|*"5."*)
            open_manage
            ;;
        CANCEL)
            exit 0
            ;;
        *)
            mac_alert "Unknown choice."
            exit 1
            ;;
    esac
}

main_menu_loop() {
    while true; do
        local choice
        choice="$(mac_choose)"
        if [[ "$choice" == "CANCEL" ]]; then
            exit 0
        fi
        dispatch_action "$choice"

        local again
        again="$(osascript -e 'button returned of (display alert "GKG Sync" message "Do you want to do another action?" buttons {"Close", "Next"} default button "Next")' 2>/dev/null || echo "Close")"
        if [[ "$again" != "Next" ]]; then
            exit 0
        fi
    done
}

# Goi truc tiep: bash menu.sh Install|Restart|OpenSync|Guide|Manage
case "${1:-Menu}" in
    Install)  run_install ;;
    Restart)  run_restart ;;
    OpenSync) open_sync_folder ;;
    Guide)    open_guide ;;
    Manage)   open_manage ;;
    Menu|*)   main_menu_loop ;;
esac
