#!/usr/bin/env bash
# Build distribution zip (run from project root or anywhere) - macOS equivalent of tao-goi-cai.ps1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GKG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TAG="$(git -C "$GKG_ROOT" describe --tags --abbrev=0 2>/dev/null || echo '0.0.0')"
OUT_ZIP="$GKG_ROOT/GKG-Syncthing-${TAG#v}.zip"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

copy_to_staging() {
    local name="$1"
    local src="$GKG_ROOT/$name"
    if [[ -e "$src" ]]; then
        mkdir -p "$(dirname "$STAGING/$name")"
        cp -R "$src" "$STAGING/$name"
    else
        echo "WARN: missing: $src" >&2
    fi
}

copy_to_staging README.txt
copy_to_staging README.md
copy_to_staging GKG-Sync.cmd
copy_to_staging GKG-Sync.command
copy_to_staging START-HERE.html
copy_to_staging HUONG-DAN.html
copy_to_staging config.example.ini
copy_to_staging config.example.ps1
copy_to_staging "scripts/win/menu.ps1"
copy_to_staging "scripts/win/install.ps1"
copy_to_staging "scripts/win/load-config.ps1"
copy_to_staging "scripts/win/preflight.ps1"
copy_to_staging "scripts/win/syncthing-setup.ps1"
copy_to_staging "scripts/win/khoi-dong-sync.ps1"
copy_to_staging "scripts/win/sync-now.ps1"
copy_to_staging "scripts/mac"
copy_to_staging "shortcuts"
copy_to_staging "legacy"

rm -f "$OUT_ZIP"
(cd "$STAGING" && zip -r -q "$OUT_ZIP" .)

echo "Created: $OUT_ZIP"
ls -l "$OUT_ZIP"