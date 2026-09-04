#!/usr/bin/env bash
set -euo pipefail

# Scans open Pull Requests for overlapping file changes with the current branch/PR.
# Exit code 3: Overlap detected (refused_overlap).
# Exit code 0: No overlapping file changes detected.

REPO="${GITHUB_REPOSITORY:-}"
BASE_REF="${GITHUB_BASE_REF:-main}"
PR_NUMBER="${PR_NUMBER:-${GITHUB_EVENT_PULL_REQUEST_NUMBER:-${1:-}}}"

if [ -z "$REPO" ]; then
	REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's/.*github\.com[:\/](.*)\.git/\1/; s/\.git$//' || true)
fi

if [ -z "$REPO" ]; then
	echo "FORGE OVERLAP: Repository not specified and could not be determined. Skipping."
	exit 0
fi

# Get list of changed files in current worktree / PR
CHANGED_FILES=""
if git rev-parse --verify "origin/$BASE_REF" >/dev/null 2>&1; then
	CHANGED_FILES=$(git diff --name-only "origin/$BASE_REF"...HEAD || true)
elif git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
	CHANGED_FILES=$(git diff --name-only "$BASE_REF"...HEAD || true)
else
	CHANGED_FILES=$(git status --porcelain | awk '{print $2}')
fi

if [ -z "$CHANGED_FILES" ]; then
	echo "FORGE OVERLAP: No changed files in current branch."
	exit 0
fi

echo "FORGE OVERLAP: Checking changed files for repository $REPO:"
echo "$CHANGED_FILES" | sed 's/^/  /'

# Query open PRs from GitHub API
PRS_JSON=""
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if command -v gh >/dev/null 2>&1 && [ -n "$TOKEN" ]; then
	PRS_JSON=$(gh api "repos/$REPO/pulls?state=open&per_page=100" 2>/dev/null || true)
elif command -v curl >/dev/null 2>&1; then
	AUTH_HEADER=()
	if [ -n "$TOKEN" ]; then
		AUTH_HEADER=(-H "Authorization: Bearer $TOKEN")
	fi
	PRS_JSON=$(curl -s "${AUTH_HEADER[@]}" "https://api.github.com/repos/$REPO/pulls?state=open&per_page=100" 2>/dev/null || true)
fi

if [ -z "$PRS_JSON" ] || ! echo "$PRS_JSON" | jq -e '. | is_array' >/dev/null 2>&1; then
	echo "FORGE OVERLAP: Unable to query open PRs from GitHub API (or no auth). Skipping overlap check."
	exit 0
fi

OVERLAP_FOUND=0

OPEN_PR_NUMBERS=$(echo "$PRS_JSON" | jq -r '.[] | .number' 2>/dev/null || true)

for pr_num in $OPEN_PR_NUMBERS; do
	if [ -n "$PR_NUMBER" ] && [ "$pr_num" -eq "$PR_NUMBER" ] 2>/dev/null; then
		continue
	fi

	PR_FILES=""
	if command -v gh >/dev/null 2>&1 && [ -n "$TOKEN" ]; then
		PR_FILES=$(gh api "repos/$REPO/pulls/$pr_num/files" --jq '.[].filename' 2>/dev/null || true)
	elif command -v curl >/dev/null 2>&1; then
		AUTH_HEADER=()
		if [ -n "$TOKEN" ]; then
			AUTH_HEADER=(-H "Authorization: Bearer $TOKEN")
		fi
		PR_FILES=$(curl -s "${AUTH_HEADER[@]}" "https://api.github.com/repos/$REPO/pulls/$pr_num/files" | jq -r '.[].filename' 2>/dev/null || true)
	fi

	if [ -z "$PR_FILES" ]; then
		continue
	fi

	OVERLAPS=$(comm -12 <(echo "$CHANGED_FILES" | sort) <(echo "$PR_FILES" | sort) || true)
	if [ -n "$OVERLAPS" ]; then
		echo "FORGE OVERLAP ERROR: Overlapping file changes detected with PR #$pr_num:" >&2
		echo "$OVERLAPS" | sed 's/^/  /' >&2
		OVERLAP_FOUND=1
	fi
done

if [ "$OVERLAP_FOUND" -eq 1 ]; then
	echo "FORGE OVERLAP: Refused due to overlapping PR file changes (exit code 3)." >&2
	exit 3
fi

echo "FORGE OVERLAP: No overlapping file changes detected."
exit 0
