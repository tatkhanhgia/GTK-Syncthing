#!/usr/bin/env bash
# Pre-install checks (macOS)

test_tailscale_ready() {
    command -v tailscale >/dev/null 2>&1 || return 1
    tailscale status >/dev/null 2>&1
}

ensure_tailscale() {
    if test_tailscale_ready; then
        write_ok 'Tailscale: OK'
        return
    fi

    echo ''
    write_warn 'Tailscale is not running.'
    echo 'Install Tailscale and sign in with the same account on every machine.'
    echo ''
    write_info 'Opening the Tailscale download page...'
    open 'https://tailscale.com/download/macos' 2>/dev/null || true
    echo ''
    echo 'After installing Tailscale, press Enter to continue...'
    read -r _
}

copy_device_id_to_clipboard() {
    local device_id="$1"
    [[ -z "$device_id" ]] && return
    if printf '%s' "$device_id" | pbcopy 2>/dev/null; then
        write_ok 'Device ID copied to clipboard (paste with Cmd+V).'
    fi
}

mac_ask() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    osascript -e "display dialog \"$prompt\" with title \"$title\" default answer \"$default\" buttons {\"Cancel\", \"OK\"} default button \"OK\"" -e 'text returned of result' 2>/dev/null || true
}

mac_alert() {
    local title="$1"
    local message="$2"
    osascript -e "display dialog \"$message\" with title \"$title\" buttons {\"OK\"} default button \"OK\"" 2>/dev/null || true
}

invoke_setup_wizard() {
    local -a ids=("$@")
    local role line trimmed dup choice new_id

    echo '' >&2
    echo '--- Step 1: Machine type ---' >&2
    choice="$(mac_ask 'GKG Sync' 'Are you setting up a NEW machine (1), EXISTING machine (2), or joining a Hub network (3)?\n\n1 = Add this new machine\n2 = This machine was already synced\n3 = Only need the Hub Device ID' '1')"
    choice="$(echo "$choice" | xargs)"

    if [[ "$choice" == "3" ]]; then
        echo '' >&2
        echo '--- Step 2: Hub Device ID ---' >&2
        while :; do
            hub_id="$(mac_ask 'GKG Sync' 'Paste the Hub machine Device ID (required):' '')"
            hub_id="$(echo "$hub_id" | xargs)"
            if [[ -z "$hub_id" ]]; then
                mac_alert 'GKG Sync' 'Hub Device ID cannot be empty. Paste it and press OK.'
                continue
            fi
            if ! is_valid_syncthing_device_id "$hub_id"; then
                mac_alert 'GKG Sync' 'Hub Device ID is invalid (7 groups of 7 with dashes). Paste again.'
                continue
            fi
            break
        done
        echo "JOIN:$hub_id"
        return
    elif [[ "$choice" == "2" ]]; then
        role=2
    else
        role=1
    fi

    if [[ "$role" -eq 2 ]]; then
        echo '' >&2
        echo '--- Step 2: New machine Device ID ---' >&2
        new_id="$(mac_ask 'GKG Sync' 'Paste the NEW machine''s Device ID that it will share with you:\n(Leave blank and press OK if none)' '')"
        new_id="$(echo "$new_id" | xargs)"
        if [[ -n "$new_id" ]]; then
            ids+=("$new_id")
        fi
    else
        echo '' >&2
        echo '--- Step 2: Existing machine Device IDs (if any) ---' >&2
        while true; do
            line="$(mac_ask 'GKG Sync' 'Paste the Device ID of an EXISTING machine.\nPress Cancel when finished.' '')"
            line="$(echo "$line" | xargs)"
            [[ -z "$line" ]] && break
            dup=0
            for trimmed in "${ids[@]}"; do
                if [[ "$trimmed" == "$line" ]]; then
                    dup=1
                    break
                fi
            done
            if [[ $dup -eq 1 ]]; then
                write_warn 'Already added; skipping.'
                continue
            fi
            ids+=("$line")
        done
    fi

    for tmp in "${ids[@]}"; do
        echo "PEER:$tmp"
    done
}

write_install_result_html() {
    local root="$1"
    local device_id="$2"
    local sync_folder="$3"
    local gui_url="$4"
    local out_path="$root/KET-QUA-CAI-DAT.html"

    cat > "$out_path" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Setup complete - GKG Sync</title>
<style>
  body{font-family:system-ui,sans-serif;max-width:640px;margin:40px auto;padding:0 20px;background:#f0fdf4;color:#0f172a}
  .card{background:#fff;border:2px solid #16a34a;border-radius:16px;padding:28px;box-shadow:0 4px 20px rgba(0,0,0,.08)}
  h1{color:#16a34a;margin:0 0 8px;font-size:26px}
  .id{font-family:Consolas,monospace;font-size:15px;background:#f1f5f9;padding:16px;border-radius:10px;word-break:break-all;margin:16px 0}
  button{background:#2563eb;color:#fff;border:none;padding:14px 24px;font-size:16px;border-radius:10px;cursor:pointer;width:100%;margin:8px 0}
  button.secondary{background:#64748b}
  p{line-height:1.6}
  .step{background:#eff6ff;border-left:4px solid #2563eb;padding:12px 16px;margin:12px 0;border-radius:0 8px 8px 0}
</style>
</head>
<body>
<div class="card">
  <h1>Setup complete!</h1>
  <p>Sync folder: <b>${sync_folder}</b></p>
  <p><b>YOUR DEVICE ID</b> — send this to the other user:</p>
  <div class="id" id="did">${device_id}</div>
  <button type="button" onclick="copyId()">Copy Device ID</button>
  <button type="button" class="secondary" onclick="location.href='${gui_url}'">Open Syncthing management page</button>
  <div class="step"><b>Next:</b> On the other machine, run <b>Cai-Dat-Sync</b> (Windows) or <b>Cai-Dat-Cho-Mac</b> (Mac), then paste the Device ID above.</div>
  <div class="step">Then add files into the Sync folder — the machines will sync automatically.</div>
</div>
<script>
function copyId(){
  var t=document.getElementById('did').innerText;
  navigator.clipboard.writeText(t).then(function(){
    alert('Device ID copied! Paste it on the other machine.');
  }).catch(function(){
    prompt('Copy manually:', t);
  });
}
copyId();
</script>
</body>
</html>
HTMLEOF
    echo "$out_path"
}

show_device_id_result() {
    local device_id="$1"
    local html_path="$2"

    copy_device_id_to_clipboard "$device_id"

    if [[ -f "$html_path" ]]; then
        open "$html_path" 2>/dev/null || true
    fi

    mac_alert 'GKG Sync - Setup complete' "YOUR DEVICE ID (copied):\n\n${device_id}\n\nSend it to the other user."
}
