# Build distribution zip (run from project root)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutZip = Join-Path $env:USERPROFILE 'Documents\Sync\GKG-Syncthing.zip'

$include = @(
    'README.txt', 'README.md',
    'GKG-Sync.cmd', 'GKG-Sync.command', 'menu.ps1',
    'Bat-Dau-O-Day.cmd', 'Cai-Dat-Sync.cmd', 'Cai-Dat-Cho-Mac.command',
    'Huong-Dan.cmd', 'Khoi-Dong-Sync.cmd',
    'START-HERE.html', 'HUONG-DAN.html',
    'config.example.ini', 'config.example.ps1', 'load-config.ps1', 'preflight.ps1',
    'install.ps1', 'syncthing-setup.ps1', 'khoi-dong-sync.ps1', 'mac', 'legacy'
)
$OutDir = Split-Path $OutZip -Parent

$staging = Join-Path $env:TEMP "GKG-Syncthing-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Force -Path $staging | Out-Null

foreach ($name in $include) {
    $src = Join-Path $ScriptDir $name
    if (Test-Path $src) {
        Copy-Item -Recurse -Force $src (Join-Path $staging $name)
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (Test-Path $OutZip) { Remove-Item -Force $OutZip }
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $OutZip -Force
Remove-Item -Recurse -Force $staging

Write-Host "Created: $OutZip" -ForegroundColor Green
Get-Item $OutZip | Select-Object FullName, Length, LastWriteTime
