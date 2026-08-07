#!/usr/bin/env bash
set -euo pipefail

guard_path="addons/net.yarvis.pixel_pen/.gdignore"

if [[ ! -f "$guard_path" ]]; then
	echo "PIXELPEN: missing $guard_path; keep PixelPen parked on Linux/WSL (issue #83; see DEPENDENCIES.md)." >&2
	exit 1
fi

echo "PIXELPEN: Linux/WSL .gdignore parking guard present"
