#!/usr/bin/env bash
# Run gdUnit4 suites through scripts/test.sh with a resident-memory cap.
#
# This WSL machine can run out of memory on large batches. A watchdog checks every
# process started by this run once a second and kills any that goes over CAP_MB.
# Only this run's own processes are watched, so other test runs on the machine are
# left alone.
#
# usage: CAP_MB=3500 LOG=/tmp/batch.log bash scripts/test_capped.sh \
#          res://test/unit/test_a.gd res://test/unit/test_b.gd
#
# Environment (all optional):
#   CAP_MB               kill threshold per process, in MB (default 3500)
#   LOG                  where test output goes (default: a new temp file)
#   TIMEOUT_S            wall-clock limit for the whole batch (default 900)
#   SOUL_METER_HEADLESS  default 1; set 0 for rendered or input suites (runs under Xvfb)
#
# Exit status: the test run's own status, or 137 when the watchdog killed anything
# (even if the run would otherwise have passed). The last line printed is a summary:
#   exit=<n> peak_rss_mb=<n> killed=<n> log=<path>
set -uo pipefail

if [ "$#" -eq 0 ]; then
	echo "usage: CAP_MB=3500 LOG=/tmp/batch.log bash scripts/test_capped.sh <suite> [<suite> ...]" >&2
	exit 2
fi

cap_mb="${CAP_MB:-3500}"
log="${LOG:-$(mktemp -t soul-meter-capped.XXXXXX.log)}"
timeout_s="${TIMEOUT_S:-900}"
headless="${SOUL_METER_HEADLESS:-1}"
data_dir="${SOUL_METER_TEST_DATA_DIR:-$(mktemp -d -t soul-meter-capped-data.XXXXXX)}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

suite_args=()
for suite in "$@"; do
	suite_args+=("-a" "$suite")
done

# The subshell keeps bash's own "Killed" job notice out of the output when the watchdog fires.
(
	LP_NUM_THREADS=1 SOUL_METER_HEADLESS="$headless" SOUL_METER_TEST_DATA_DIR="$data_dir" \
		timeout "$timeout_s" bash "$script_dir/test.sh" -c "${suite_args[@]}"
	exit $?
) > "$log" 2>&1 &
runner=$!

descendants() {
	local child
	for child in $(pgrep -P "$1" 2>/dev/null); do
		echo "$child"
		descendants "$child"
	done
}

peak=0
killed=0
while kill -0 "$runner" 2>/dev/null; do
	for pid in $(descendants "$runner"); do
		rss=$(awk '/VmRSS/{print int($2/1024)}' "/proc/$pid/status" 2>/dev/null)
		rss="${rss:-0}"
		if [ "$rss" -gt "$peak" ]; then
			peak="$rss"
		fi
		if [ "$rss" -gt "$cap_mb" ]; then
			echo "WATCHDOG killed pid $pid at ${rss} MB (cap ${cap_mb} MB)" >> "$log"
			kill -9 "$pid" 2>/dev/null
			killed=$((killed + 1))
		fi
	done
	sleep 1
done
wait "$runner"
status=$?

echo "exit=$status peak_rss_mb=$peak killed=$killed log=$log"
if [ "$killed" -gt 0 ]; then
	exit 137
fi
exit "$status"
