# LEGACY - prefer config.ini (shared Windows + Mac)
# Keep this file only if an old machine still uses config.ps1
# Device ID: http://127.0.0.1:8384 -> Action -> Show ID

function ConvertTo-WslPath {
    param([string]$WindowsPath)
    $normalized = $WindowsPath -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2]
        return "/mnt/$drive$rest"
    }
    return $normalized
}

# Machine running this script (defaults OK; edit later if needed).
$LocalMachineIp   = 'CHANGE-ME'
$LocalMachineName = $env:COMPUTERNAME

$PackConfig = @{
    SyncFolder           = Join-Path $env:USERPROFILE 'Documents\Sync'
    LocalMachineIp       = $LocalMachineIp
    LocalMachineName     = $LocalMachineName
    SyncthingFolderId    = 'documents-sync'
    SyncthingFolderLabel = 'Documents Sync'
    SyncthingPort        = 8384
    InstallDir           = "$env:LOCALAPPDATA\GKG-Syncthing"
}

# List of sync peers. Add a row when you have a 3rd, 4th machine...
$Peers = @(
    @{ Name = 'Other machine (example)'; TailscaleIp = 'CHANGE-ME'; SyncthingDeviceId = '' }
)

# Legacy SSH/Unison (legacy/) - uses first peer as remote only.
$SyncConfig = @{
    RemoteHost    = $Peers[0].TailscaleIp
    RemoteUser    = 'admin'
    LocalMachine  = $LocalMachineIp
    SyncFolder    = $PackConfig.SyncFolder
    WslSyncPath   = ConvertTo-WslPath $PackConfig.SyncFolder
    UnisonProfile = 'sync'
}

function Get-SyncthingConfigPath {
    return Join-Path $env:LOCALAPPDATA 'Syncthing\config.xml'
}

function Get-SyncthingGuiUrl {
    return "http://127.0.0.1:$($PackConfig.SyncthingPort)"
}

function Get-PeerList {
    param($Peers = $script:Peers)
    return $Peers
}

function Get-PeerDeviceIds {
    param($Peers = $script:Peers)
    return @($Peers | ForEach-Object { $_.SyncthingDeviceId.Trim() } | Where-Object { $_ })
}

function Get-SyncRemoteUri {
    param($Config = $script:SyncConfig)
    $winPath = $Config.SyncFolder -replace '\\', '/'
    return "ssh://$($Config.RemoteUser)@$($Config.RemoteHost)//$winPath"
}
