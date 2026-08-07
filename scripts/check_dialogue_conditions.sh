#!/usr/bin/env bash
set -euo pipefail

# Guards the Dialogue Manager response-condition defect recorded in
# DEPENDENCIES.md: `[if expr]` silently no-ops, while `[if expr /]` works.
# A broken consequence check is otherwise indistinguishable from a working one.
#
# Deliberately pure Python: it never invokes Godot, so its exit code is
# trustworthy. `godot --headless --script` aborts at teardown 20-30% of the
# time in this environment, which is why CI must judge tool OUTPUT rather than
# a raw Godot exit code. This check is exempt from that rule because no Godot
# process is involved.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 tools/lint_dialogue_conditions.py "$@"
