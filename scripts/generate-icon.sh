#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift Assets/generate-icon.swift Assets
for ICON in AppIcon AppIcon-DEV; do
    iconutil -c icns "Assets/$ICON.iconset" -o "Assets/$ICON.icns"
    rm -rf "Assets/$ICON.iconset"
done
ls -d "$ROOT"/Assets/AppIcon*
