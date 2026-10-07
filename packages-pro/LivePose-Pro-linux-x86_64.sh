#!/bin/bash
# Launcher script for LivePose Pro
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/LivePose-Pro-linux-x86_64.AppImage" "$@"
