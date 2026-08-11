# GKG-Syncthing - one-click installer (Syncthing)

param(
    [ValidateSet('Syncthing', 'Ssh', 'Menu', 'Join')]
    [string]$Mode = 'Syncthing',
    [string[]]$RemoteDeviceIds = @(),
    [switch]$SkipPrompt
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GkgRoot = Split-Path (Split-Path $ScriptDir -Parent) -Parent

. (Join-Path $ScriptDir 'load-config.ps1')

$iniPath = Join-Path $GkgRoot 'config.ini'
Clear-DuplicateLocalDeviceId -IniPath $iniPath
Import-GkgConfig -ScriptDir $ScriptDir
Update-LocalTailscaleIpInConfig -IniPath $iniPath
Import-GkgConfig -ScriptDir $ScriptDir

. (Join-Path $ScriptDir 'syncthing-setup.ps1')
. (Join-Path $ScriptDir 'preflight.ps1')

function Show-Banner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Green
    Write-Host '   FILE SYNC - ONE-CLICK INSTALLER' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Just follow the step-by-step instructions.' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-SyncthingResult {
    param($Result)

    $htmlPath = Write-InstallResultHtml `
        -ScriptDir $GkgRoot `
        -DeviceId $Result.DeviceId `
        -SyncFolder $Result.SyncFolder `
        -GuiUrl $Result.GuiUrl

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Green
    Write-Host '   SETUP COMPLETE!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ''
    Write-Ok "Sync folder: $($Result.SyncFolder)"
    Write-Host ''
    Write-Host 'Result page opened — click Copy Device ID and send it to the other machine(s).' -ForegroundColor Cyan
    Write-Host ''

    Show-DeviceIdDialog -DeviceId $Result.DeviceId -HtmlPath $htmlPath

    try {
        Start-Process $Result.GuiUrl | Out-Null
    } catch {
        Write-Warn "Open browser manually: $($Result.GuiUrl)"
    }
}

function Install-SshMode {
    $legacyDir = Join-Path $GkgRoot 'legacy'
    Write-Info 'Advanced mode: SSH + Unison (legacy)'
    $installUnison = Join-Path $legacyDir 'install-unison.cmd'
    $setupSync = Join-Path $legacyDir 'setup-sync.cmd'

    if (-not (Test-Path $installUnison)) {
        throw "Not found: $installUnison"
    }

    Write-Host ''
    Write-Warn 'This mode requires WSL + Unison. Supports only 2 machines.'
    Write-Host ''

    cmd /c "`"$installUnison`""
    cmd /c "`"$setupSync`""

    Write-Host ''
    Write-Ok 'SSH sync is set up. Run sync with: legacy\sync-folder.cmd'
    Write-Host ''
}

Show-Banner
Ensure-Tailscale

$iniPath = Join-Path $GkgRoot 'config.ini'
Update-LocalTailscaleIpInConfig -IniPath $iniPath

$configPeerIds = @(Get-PeerDeviceIds)
$wizardPeerIds = @()
$joinHub = $false

if ($configPeerIds.Count -gt 0) {
    Write-Info "Using $($configPeerIds.Count) peer(s) from config.ini"
}

if ($Mode -eq 'Menu') {
    Write-Host 'Choose install mode:' -ForegroundColor Cyan
    Write-Host '  [1] Syncthing - default (automatic multi-machine sync)'
    Write-Host '  [2] SSH/Unison - advanced (legacy, 2 machines only)'
    Write-Host ''
    $choice = Read-Host 'Enter 1 or 2 (default: 1)'
    if (-not $choice -or $choice -eq '1') {
        $Mode = 'Syncthing'
    } else {
        $Mode = 'Ssh'
    }
}

if ($Mode -eq 'Join') {
    $hubId = $PackConfig.IntroducerDeviceId
    if (-not $SkipPrompt) {
        $hubId = Invoke-JoinHubWizard -DefaultHubId $hubId
    }

    if (-not $hubId) {
        throw 'Join Hub network: Hub Device ID is required. Choose Join network again and paste the Hub Device ID.'
    }

    Write-Host ''
    Write-Info "Joining hub network (hub: $hubId)"
    Write-Info 'Installing... (this may take a few minutes)'
    $result = Install-SyncthingMode -Config $PackConfig -IntroducerDeviceId $hubId
    Save-JoinNetworkConfig -IniPath $iniPath -IntroducerDeviceId $hubId
    Save-GkgConfigAfterInstall -IniPath $iniPath -DeviceId $result.DeviceId
    Write-Ok "Updated config.ini with this machine's Device ID and hub settings"
    Show-SyncthingResult -Result $result
    exit 0
}

if ($Mode -eq 'Syncthing') {
    $RemoteDeviceIds = @($configPeerIds)

    if ($RemoteDeviceIds.Count -eq 0) {
        if ($SkipPrompt) {
            $RemoteDeviceIds = @(Get-PeerDeviceIds)
        } else {
            $wizard = Invoke-SetupWizard -ExistingIds @(Get-PeerDeviceIds)
            $wizardPeerIds = @($wizard.PeerIds)
            if ($wizard.JoinHubDeviceId) {
                $RemoteDeviceIds = @($wizard.JoinHubDeviceId)
                $joinHub = $true
            } else {
                $RemoteDeviceIds = @($wizardPeerIds)
            }
        }
    }

    Write-Host ''
    Write-Info 'Installing... (this may take a few minutes)'
    if ($joinHub) {
        Write-Info "Joining hub network (hub: $($RemoteDeviceIds[0]))"
        $result = Install-SyncthingMode -Config $PackConfig -IntroducerDeviceId $RemoteDeviceIds[0]
        Save-JoinNetworkConfig -IniPath $iniPath -IntroducerDeviceId $RemoteDeviceIds[0]
        Save-GkgConfigAfterInstall -IniPath $iniPath -DeviceId $result.DeviceId -AddedPeerIds $wizardPeerIds
    } else {
        $result = Install-SyncthingMode -Config $PackConfig -RemoteDeviceIds $RemoteDeviceIds
        Save-GkgConfigAfterInstall -IniPath $iniPath -DeviceId $result.DeviceId -AddedPeerIds $wizardPeerIds
    }
    Write-Ok "Updated config.ini with this machine's Device ID"
    Show-SyncthingResult -Result $result
    exit 0
}

if ($Mode -eq 'Ssh') {
    Install-SshMode
    exit 0
}

throw "Invalid mode: $Mode"
