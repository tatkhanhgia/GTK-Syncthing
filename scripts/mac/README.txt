macOS scripts for GTK-Syncthing
===============================

These are the macOS engine scripts. Launch them from the project root
(GKG-Sync.command) or from the shortcuts/ folder.

Main entry:
  ../../GKG-Sync.command      menu (recommended)
  ../shortcuts/cai-dat-sync.command    Install / add this Mac
  ../shortcuts/khoi-dong-sync.command  Restart Syncthing
  ../shortcuts/huong-dan.command       Open HUONG-DAN.html

Latest: use the menu -> item "6. Join network" to auto-connect
this Mac to a hub machine with just the Hub Device ID (no manual config.ini editing).

First time on Mac:
  chmod +x GKG-Sync.command scripts/mac/*.sh

Shared config with Windows: ../../config.ini