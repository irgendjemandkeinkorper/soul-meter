#!/usr/bin/env bash
# Uploads an exported build to a Steam depot with steamcmd (issue #299).
# App id, depot id and credentials come from the environment and are never
# committed. See docs/steam-integration.md.
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage: tools/steam_upload.sh [--preview] [--content-root PATH]

Required environment:
  STEAM_APP_ID        Steamworks app id
  STEAM_DEPOT_ID      depot id that receives the build
  STEAM_USERNAME      Steamworks build account (use a dedicated upload account)

Optional environment:
  STEAM_PASSWORD      password; omit to reuse steamcmd's cached login
  STEAM_CONTENT_ROOT  exported build directory (default: build/windows)
  STEAM_BUILD_DESC    build description (default: current git commit)
  STEAM_SET_LIVE      branch to set live after upload (default: none; never "default")
  STEAMCMD_BIN        steamcmd executable (default: steamcmd)

--preview runs a steamcmd preview build: nothing is uploaded.
USAGE
}

fail() {
	echo "STEAM UPLOAD: $*" >&2
	exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
template_dir="$script_dir/steam"
content_root="${STEAM_CONTENT_ROOT:-$repo_root/build/windows}"
preview=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--preview)
			preview=1
			shift
			;;
		--content-root)
			[[ $# -ge 2 ]] || fail "--content-root requires a path"
			content_root="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			fail "unknown argument: $1"
			;;
	esac
done

missing=()
for name in STEAM_APP_ID STEAM_DEPOT_ID STEAM_USERNAME; do
	if [[ -z "${!name:-}" ]]; then
		missing+=("$name")
	fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
	fail "missing required environment variable(s): ${missing[*]}"
fi

[[ "$STEAM_APP_ID" =~ ^[0-9]+$ ]] || fail "STEAM_APP_ID must be numeric"
[[ "$STEAM_DEPOT_ID" =~ ^[0-9]+$ ]] || fail "STEAM_DEPOT_ID must be numeric"

set_live="${STEAM_SET_LIVE:-}"
[[ "$set_live" != "default" ]] \
	|| fail "refusing to set the default branch live from a script; promote it on the partner site"
[[ "$set_live" =~ ^[A-Za-z0-9_.-]*$ ]] || fail "STEAM_SET_LIVE has unsupported characters"

[[ -d "$content_root" ]] || fail "content root not found: $content_root (export the build first)"
content_root="$(cd "$content_root" && pwd)"
[[ -n "$(find "$content_root" -mindepth 1 -print -quit)" ]] \
	|| fail "content root is empty: $content_root"

steamcmd_bin="${STEAMCMD_BIN:-steamcmd}"
command -v "$steamcmd_bin" >/dev/null 2>&1 || fail "steamcmd not found (set STEAMCMD_BIN)"

build_desc="${STEAM_BUILD_DESC:-$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo manual)}"
# Keep the description safe for both the VDF quoting and the sed substitution.
build_desc="${build_desc//[^A-Za-z0-9 _.:+-]/_}"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
mkdir -p "$work_dir/output"

render() {
	sed \
		-e "s|@STEAM_APP_ID@|$STEAM_APP_ID|g" \
		-e "s|@STEAM_DEPOT_ID@|$STEAM_DEPOT_ID|g" \
		-e "s|@STEAM_BUILD_DESC@|$build_desc|g" \
		-e "s|@STEAM_PREVIEW@|$preview|g" \
		-e "s|@STEAM_SET_LIVE@|$set_live|g" \
		-e "s|@STEAM_CONTENT_ROOT@|$content_root|g" \
		-e "s|@STEAM_BUILD_OUTPUT@|$work_dir/output|g" \
		-e "s|@STEAM_DEPOT_VDF@|$work_dir/depot_build.vdf|g" \
		"$1" > "$2"
}

case "$content_root" in
	*'|'*|*'"'*) fail "content root path contains an unsupported character" ;;
esac

render "$template_dir/depot_build.vdf.template" "$work_dir/depot_build.vdf"
render "$template_dir/app_build.vdf.template" "$work_dir/app_build.vdf"

login_args=("$STEAM_USERNAME")
if [[ -n "${STEAM_PASSWORD:-}" ]]; then
	login_args+=("$STEAM_PASSWORD")
fi

echo "STEAM UPLOAD: app $STEAM_APP_ID depot $STEAM_DEPOT_ID from $content_root (preview=$preview, set live: ${set_live:-none})"
"$steamcmd_bin" +login "${login_args[@]}" +run_app_build "$work_dir/app_build.vdf" +quit
echo "STEAM UPLOAD: done"
