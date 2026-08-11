# Pre-install checks (Windows)

function Test-TailscaleReady {
    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        $status = & tailscale status 2>&1
        if ($LASTEXITCODE -eq 0 -and $status) {
            return $true
        }
    }
    return $false
}

function Ensure-Tailscale {
    if (Test-TailscaleReady) {
        Write-Host 'Tailscale: OK' -ForegroundColor Green
        return
    }

    Write-Host ''
    Write-Host 'Tailscale is not running.' -ForegroundColor Yellow
    Write-Host 'Install Tailscale and sign in with the same account on every machine.'
    Write-Host ''
    Write-Host 'Opening the Tailscale download page...' -ForegroundColor Cyan
    Start-Process 'https://tailscale.com/download/windows' | Out-Null
    Write-Host ''
    Write-Host 'After installing Tailscale, press Enter to continue...' -ForegroundColor Yellow
    Read-Host | Out-Null

    if (-not (Test-TailscaleReady)) {
        Write-Warn 'Tailscale still not detected. Continuing Syncthing setup — you can connect later.'
    }
}

function Copy-DeviceIdToClipboard {
    param([string]$DeviceId)
    if (-not $DeviceId) { return }

    try {
        Set-Clipboard -Value $DeviceId
        Write-Ok 'Device ID copied to clipboard (paste with Ctrl+V).'
    } catch {
        Write-Warn 'Could not copy automatically — copy manually from the result screen.'
    }
}

function Show-DeviceIdDialog {
    param(
        [string]$DeviceId,
        [string]$HtmlPath
    )

    Copy-DeviceIdToClipboard -DeviceId $DeviceId

    if ($HtmlPath -and (Test-Path $HtmlPath)) {
        Start-Process $HtmlPath | Out-Null
        return
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "YOUR DEVICE ID (copied to clipboard):`n`n$DeviceId`n`nSend this to the other user, then run Cai-Dat-Sync on that machine.",
            'GKG Sync - Setup complete',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Write-Host 'YOUR DEVICE ID:' -ForegroundColor Yellow
        Write-Host $DeviceId -ForegroundColor White
    }
}

function Invoke-JoinHubWizard {
    param([string]$DefaultHubId = '')

    Write-Host ''
    Write-Host '--- Join Hub network ---' -ForegroundColor Cyan
    Write-Host 'Paste the Hub machine Device ID (from the hub result page or Syncthing dashboard):'
    if ($DefaultHubId) {
        Write-Host "Current config: $DefaultHubId" -ForegroundColor DarkGray
    }
    while ($true) {
        $hubId = Read-Host 'Hub Device ID'
        $hubId = if ($hubId) { $hubId.Trim() } else { '' }
        if (-not $hubId -and $DefaultHubId) {
            $hubId = $DefaultHubId.Trim()
        }
        if (-not $hubId) {
            Write-Warn 'Hub Device ID is required. Paste the ID and press Enter.'
            continue
        }
        if (-not (Test-SyncthingDeviceId -DeviceId $hubId)) {
            Write-Warn 'Invalid Hub Device ID (8 groups of 7 letters/digits, separated by -). Try again.'
            continue
        }
        return $hubId
    }
}

function Invoke-SetupWizard {
    param([string[]]$ExistingIds = @())

    Write-Host ''
    Write-Host '--- Step 1: Machine type ---' -ForegroundColor Cyan
    Write-Host '  1 = NEW machine   (adding this machine for the first time)'
    Write-Host '  2 = EXISTING machine   (other machines already sync; connecting this one)'
    Write-Host '  3 = Join Hub network   (only need the Hub Device ID)'
    Write-Host ''
    $role = Read-Host 'Choose 1, 2, or 3'

    $ids = [System.Collections.ArrayList]@($ExistingIds)

    if ($role -eq '3') {
        $hubId = Invoke-JoinHubWizard
        return @{
            PeerIds          = @($ids | Select-Object -Unique)
            JoinHubDeviceId  = $hubId
            JoinMode         = $true
        }
    }

    if ($role -eq '2') {
        Write-Host ''
        Write-Host '--- Step 2: New machine Device ID ---' -ForegroundColor Cyan
        Write-Host 'The NEW machine user will send you a long string (Device ID).'
        Write-Host 'Paste it here (Enter if none yet):'
        $newId = Read-Host 'New machine Device ID'
        if ($newId -and $newId.Trim()) {
            [void]$ids.Add($newId.Trim())
        }
    } else {
        Write-Host ''
        Write-Host '--- Step 2: Existing machine Device IDs (if any) ---' -ForegroundColor Cyan
        Write-Host 'If an existing machine sent a Device ID — paste it. Press Enter to skip.'
        while ($true) {
            $line = Read-Host 'Existing machine Device ID (Enter = done)'
            if (-not $line) { break }
            $trimmed = $line.Trim()
            if ($ids -contains $trimmed) {
                Write-Warn 'Already added; skipping.'
                continue
            }
            [void]$ids.Add($trimmed)
        }
    }

    return @{
        PeerIds         = @($ids | Select-Object -Unique)
        JoinHubDeviceId = ''
        JoinMode        = $false
    }
}

function Write-InstallResultHtml {
    param(
        [string]$ScriptDir,
        [string]$DeviceId,
        [string]$SyncFolder,
        [string]$GuiUrl
    )

    $outPath = Join-Path $ScriptDir 'KET-QUA-CAI-DAT.html'
    $safeId = [System.Net.WebUtility]::HtmlEncode($DeviceId)
    $safeFolder = [System.Net.WebUtility]::HtmlEncode($SyncFolder)
    $safeUrl = [System.Net.WebUtility]::HtmlEncode($GuiUrl)

    @"
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
  <p>Sync folder: <b>$safeFolder</b></p>
  <p><b>YOUR DEVICE ID</b> — send this to the other user:</p>
  <div class="id" id="did">$safeId</div>
  <button type="button" onclick="copyId()">Copy Device ID</button>
  <button type="button" class="secondary" onclick="location.href='$safeUrl'">Open Syncthing management page</button>
  <div class="step"><b>Next:</b> On the other machine, run <b>Cai-Dat-Sync</b> (Windows) or <b>Cai-Dat-Cho-Mac</b> (Mac), paste the Device ID above, then press Enter.</div>
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
"@ | Set-Content -LiteralPath $outPath -Encoding UTF8

    return $outPath
}
