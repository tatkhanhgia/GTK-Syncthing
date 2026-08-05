#!/bin/bash
cd "$(dirname "$0")" || exit 1
chmod +x mac/menu.sh mac/*.sh 2>/dev/null || true
exec bash mac/menu.sh
