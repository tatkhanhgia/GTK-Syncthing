#!/usr/bin/env bash
# Syncthing setup helpers for GKG-Syncthing (macOS)

set -euo pipefail

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
source "$MAC_DIR/load-config.sh"

write_info() { echo -e "\033[36m$*\033[0m" >&2; }
write_ok() { echo -e "\033[32m$*\033[0m" >&2; }
write_warn() { echo -e "\033[33m$*\033[0m" >&2; }
write_err() { echo -e "\033[31m$*\033[0m" >&2; }

ensure_sync_folder() {
    mkdir -p "$SYNC_FOLDER"
}

test_syncthing_installed() {
    if command -v syncthing >/dev/null 2>&1; then
        return 0
    fi
    [[ -x "$INSTALL_DIR/syncthing/syncthing" ]]
}

get_syncthing_exe() {
    if command -v syncthing >/dev/null 2>&1; then
        command -v syncthing
        return
    fi
    local portable="$INSTALL_DIR/syncthing/syncthing"
    if [[ -x "$portable" ]]; then
        echo "$portable"
    fi
}

install_syncthing_package() {
    write_info 'Installing Syncthing...'

    if command -v syncthing >/dev/null 2>&1; then
        write_ok 'Syncthing is already available.'
        return
    fi

    if command -v brew >/dev/null 2>&1; then
        echo 'Installing via Homebrew...'
        if brew list syncthing >/dev/null 2>&1; then
            write_ok 'Syncthing has already been installed via Homebrew.'
            return
        fi
        brew install syncthing
        write_ok 'Syncthing installed via Homebrew.'
        return
    fi

    local install_root="$INSTALL_DIR/syncthing"
    local exe_path="$install_root/syncthing"
    if [[ -x "$exe_path" ]]; then
        write_ok 'Syncthing portable is already present.'
        return
    fi

    echo 'Downloading Syncthing portable...'
    mkdir -p "$install_root"
    local zip_path arch url
    zip_path="$(mktemp /tmp/syncthing-macos.XXXXXX.zip)"
    arch="$(uname -m)"
    if [[ "$arch" == "arm64" ]]; then
        url='https://github.com/syncthing/syncthing/releases/download/v1.29.3/syncthing-macos-arm64-v1.29.3.zip'
    else
        url='https://github.com/syncthing/syncthing/releases/download/v1.29.3/syncthing-macos-amd64-v1.29.3.zip'
    fi
    curl -fsSL "$url" -o "$zip_path"
    ditto -x -k "$zip_path" "$install_root"
    rm -f "$zip_path"

    local extracted
    extracted="$(find "$install_root" -name syncthing -type f 2>/dev/null | head -n 1 || true)"
    if [[ -z "$extracted" ]]; then
        write_err 'Could not find syncthing after extracting.'
        exit 1
    fi
    cp "$extracted" "$exe_path"
    chmod +x "$exe_path"
    write_ok 'Syncthing portable downloaded.'
}

start_syncthing_process() {
    local exe
    exe="$(get_syncthing_exe)"
    if [[ -z "$exe" ]]; then
        write_err 'Syncthing is not installed.'
        exit 1
    fi

    if pgrep -x syncthing >/dev/null 2>&1; then
        write_ok 'Syncthing is already running.'
        return
    fi

    if command -v brew >/dev/null 2>&1 && brew services list 2>/dev/null | grep -q 'syncthing.*started'; then
        write_ok 'Syncthing is already running (brew services).'
        return
    fi

    write_info 'Starting Syncthing...'
    if command -v brew >/dev/null 2>&1 && [[ "$exe" == "$(command -v syncthing 2>/dev/null || true)" ]]; then
        brew services start syncthing >/dev/null 2>&1 || true
    else
        nohup "$exe" serve --no-browser --home "$HOME/Library/Application Support/Syncthing" >/dev/null 2>&1 &
    fi
    sleep 4
}

wait_syncthing_config() {
    local timeout="${1:-60}"
    local config_path
    config_path="$(get_syncthing_config_path)"
    local deadline=$((SECONDS + timeout))

    while (( SECONDS < deadline )); do
        if [[ -f "$config_path" ]]; then
            echo "$config_path"
            return
        fi
        sleep 2
    done
    write_err 'Could not find the Syncthing config file.'
    exit 1
}

get_syncthing_api_key() {
    local config_path="$1"
    sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$config_path" | head -n 1
}

invoke_syncthing_api() {
    local api_key="$1"
    local method="$2"
    local api_path="$3"
    local body="${4:-}"

    local url="http://127.0.0.1:${SYNCTHING_PORT}${api_path}"
    if [[ -n "$body" ]]; then
        curl -fsS -X "$method" \
            -H "X-API-Key: $api_key" \
            -H 'Content-Type: application/json' \
            -d "$body" \
            "$url"
    else
        curl -fsS -X "$method" \
            -H "X-API-Key: $api_key" \
            "$url"
    fi
}

build_folder_json() {
    local device_ids=("$@")
    local devices_json='['
    local first=1
    local id trimmed

    for id in "${device_ids[@]}"; do
        trimmed="$(echo "$id" | xargs)"
        [[ -z "$trimmed" ]] && continue
        if [[ $first -eq 0 ]]; then
            devices_json+=','
        fi
        devices_json+="{\"deviceID\":\"$trimmed\"}"
        first=0
    done
    devices_json+=']'

    cat <<EOF
{
  "id": "$SYNCTHING_FOLDER_ID",
  "label": "$SYNCTHING_FOLDER_LABEL",
  "path": "$SYNC_FOLDER",
  "type": "sendreceive",
  "devices": $devices_json,
  "rescanIntervalS": 3600,
  "fsWatcherEnabled": true,
  "fsWatcherDelayS": 10,
  "versioning": { "type": "" },
  "ignorePatterns": []
}
EOF
}

ensure_syncthing_folder() {
    local api_key="$1"
    shift
    local device_ids=("$@")

    local folders existing folder_json
    folders="$(invoke_syncthing_api "$api_key" GET '/rest/config/folders')"
    existing="$(echo "$folders" | grep -o "\"id\"[[:space:]]*:[[:space:]]*\"${SYNCTHING_FOLDER_ID}\"" || true)"

    folder_json="$(build_folder_json "${device_ids[@]}")"

    if [[ -n "$existing" ]]; then
        invoke_syncthing_api "$api_key" PUT "/rest/config/folders/${SYNCTHING_FOLDER_ID}" "$folder_json" >/dev/null
    else
        invoke_syncthing_api "$api_key" POST '/rest/config/folders' "$folder_json" >/dev/null
    fi
}

add_syncthing_remote_device() {
    local api_key="$1"
    local device_id="$2"
    local name="${3:-Remote device}"

    device_id="$(echo "$device_id" | xargs)"
    [[ -z "$device_id" ]] && return 0

    local devices existing
    devices="$(invoke_syncthing_api "$api_key" GET '/rest/config/devices')"
    existing="$(echo "$devices" | grep -o "$device_id" || true)"
    if [[ -n "$existing" ]]; then
        return 0
    fi

    local body
    body="$(cat <<EOF
{
  "deviceID": "$device_id",
  "name": "$name",
  "addresses": ["dynamic"],
  "compression": "metadata",
  "introducer": false,
  "skipIntroductionRemovals": false,
  "paused": false
}
EOF
)"
    invoke_syncthing_api "$api_key" POST '/rest/config/devices' "$body" >/dev/null
}

get_local_syncthing_device_id() {
    local api_key="$1"
    local status my_id
    status="$(invoke_syncthing_api "$api_key" GET '/rest/system/status')"
    my_id="$(echo "$status" | sed -n 's/.*"myID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    echo "$my_id"
}

register_syncthing_startup() {
    local exe
    exe="$(get_syncthing_exe)"
    [[ -z "$exe" ]] && return 0

    if command -v brew >/dev/null 2>&1 && [[ "$exe" == "$(command -v syncthing 2>/dev/null || true)" ]]; then
        brew services start syncthing >/dev/null 2>&1 || true
        write_ok 'Registered Syncthing to start automatically (brew services).'
        return
    fi

    local plist="$HOME/Library/LaunchAgents/net.syncthing.syncthing.plist"
    if [[ -f "$plist" ]]; then
        return
    fi

    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>net.syncthing.syncthing</string>
  <key>ProgramArguments</key>
  <array>
    <string>$exe</string>
    <string>serve</string>
    <string>--no-browser</string>
    <string>--home</string>
    <string>$HOME/Library/Application Support/Syncthing</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
    launchctl load "$plist" 2>/dev/null || true
    write_ok 'Added Syncthing to macOS startup.'
}

new_sync_folder_shortcut() {
    local alias_path="$HOME/Desktop/Sync - GKG"
    ln -sfn "$SYNC_FOLDER" "$alias_path" 2>/dev/null || true
}

install_syncthing_mode() {
    local remote_ids=("$@")

    ensure_sync_folder
    install_syncthing_package
    start_syncthing_process

    local config_path api_key shared_devices=() id trimmed
    config_path="$(wait_syncthing_config)"
    api_key="$(get_syncthing_api_key "$config_path")"

    for id in "${remote_ids[@]}"; do
        trimmed="$(echo "$id" | xargs)"
        if [[ -n "$trimmed" ]]; then
            add_syncthing_remote_device "$api_key" "$trimmed" 'Remote device'
            shared_devices+=("$trimmed")
        fi
    done

    ensure_syncthing_folder "$api_key" "${shared_devices[@]}"
    register_syncthing_startup
    new_sync_folder_shortcut

    local my_id
    my_id="$(get_local_syncthing_device_id "$api_key")"
    echo "DEVICE_ID=$my_id"
    echo "GUI_URL=$(get_syncthing_gui_url)"
    echo "SYNC_FOLDER=$SYNC_FOLDER"
}
