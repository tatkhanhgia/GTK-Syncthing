# Sync now - trigger folder membership sync immediately (no reinstall)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir 'load-config.ps1')
try {
    Import-GkgConfig -ScriptDir $ScriptDir
} catch {
    Write-Host ''
    Write-Host '[ERROR] No config.ini found. Run Cai-Dat-Sync.cmd first.' -ForegroundColor Red
    Write-Host ''
    exit 1
}
. (Join-Path $ScriptDir 'syncthing-setup.ps1')

if (-not (Test-SyncthingInstalled -Config $PackConfig)) {
    Write-Host ''
    Write-Host '[ERROR] Syncthing is not installed.' -ForegroundColor Red
    Write-Host 'Run Cai-Dat-Sync.cmd first.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host 'Syncing now...' -ForegroundColor Cyan

Start-SyncthingProcess -Config $PackConfig
Start-Sleep -Seconds 2

try {
    $configPath = Wait-SyncthingConfig
    $apiKey = Get-SyncthingApiKey -ConfigPath $configPath
    $myId = Get-LocalSyncthingDeviceId -ApiKey $apiKey

    if ($PackConfig.IsHub) {
        Write-Host 'Hub detected - syncing folder membership...' -ForegroundColor Cyan
        Sync-FolderMembership -ApiKey $apiKey -FolderId $PackConfig.SyncthingFolderId -SelfDeviceId $myId
    } else {
        Write-Host "Member machine (hub: $($PackConfig.IntroducerDeviceId)) - waiting for hub to share." -ForegroundColor Yellow
    }
} catch {
    Write-Host ('[Warning] Membership sync: ' + $_.Exception.Message) -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Done. Devices on this machine should now share the sync folder.' -ForegroundColor Green
Write-Host ''