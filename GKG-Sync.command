#!/bin/bash
cd "$(dirname "$0")" || exit 1
chmod +x scripts/mac/menu.sh 2>/dev/null || true
exec bash scripts/mac/menu.sh