# Build distribution zip (run from project root)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GkgRoot = Split-Path (Split-Path $ScriptDir -Parent) -Parent
$OutZip = Join-Path $GkgRoot 'GKG-Syncthing.zip'

$include = @(
    'README.txt', 'README.md',
    'GKG-Sync.cmd', 'GKG-Sync.command',
    'START-HERE.html', 'HUONG-DAN.html',
    'config.example.ini', 'config.example.ps1',
    'scripts\win\menu.ps1', 'scripts\win\install.ps1', 'scripts\win\load-config.ps1',
    'scripts\win\preflight.ps1', 'scripts\win\syncthing-setup.ps1',
    'scripts\win\khoi-dong-sync.ps1', 'scripts\win\sync-now.ps1',
    'scripts\mac', 'shortcuts', 'legacy'
)

$staging = Join-Path $env:TEMP "GKG-Syncthing-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Force -Path $staging | Out-Null

foreach ($name in $include) {
    $src = Join-Path $GkgRoot $name
    if (Test-Path $src) {
        $dest = Join-Path $staging $name
        $destParent = Split-Path $dest -Parent
        if ($destParent -and -not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        }
        Copy-Item -Recurse -Force $src $dest
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutZip -Parent) | Out-Null
if (Test-Path $OutZip) { Remove-Item -Force $OutZip }
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $OutZip -Force
Remove-Item -Recurse -Force $staging

Write-Host "Created: $OutZip" -ForegroundColor Green
Get-Item $OutZip | Select-Object FullName, Length, LastWriteTime
