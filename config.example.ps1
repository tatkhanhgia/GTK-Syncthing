# LEGACY - uu tien dung config.ini (chung Windows + Mac)
# Chi giu file nay neu may cu van dung config.ps1
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

# May dang chay script (co the de mac dinh, chinh sau neu can).
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

# Danh sach may dong bo. Them dong moi khi co may thu 3, 4, ...
$Peers = @(
    @{ Name = 'May khac (vi du)'; TailscaleIp = 'CHANGE-ME'; SyncthingDeviceId = '' }
)

# Legacy SSH/Unison (legacy/) - chi dung peer dau tien lam remote.
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
