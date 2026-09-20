#!/usr/bin/env bash
#
# run_workflow.sh — Automates the Implementer + Reviewer workflow.
#
# - Multiple fix candidates are evaluated in PARALLEL (& + wait).
# - Each candidate gets an ISOLATED git worktree checkout.
# - The Implementer step = writing this candidate's fix into the worktree.
# - The Reviewer step  = running reviewer.py inside that worktree.
# - The REVIEWER'S EXIT CODE is the checker: 0 => PASS, non-zero => FAIL.
#
# STATELESS BY DESIGN: every run uses a fresh, unique temp directory and
# fresh detached worktrees. No progress file / heartbeat is read or written,
# so a second run in a new terminal behaves exactly like the first.
# (See the commented-out PROGRESS_FILE section below to make it stateful.)

set -u  # intentionally NO `set -e` — exit codes are collected manually

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEWER="$SCRIPT_DIR/reviewer.py"
WORK_BRANCH="fix/bug-fix"

# ---- State hooks (commented out on purpose — keeps script stateless) ----
# PROGRESS_FILE="$SCRIPT_DIR/.workflow_progress.md"
# HEARTBEAT_FILE="$SCRIPT_DIR/.workflow_heartbeat"

# Unique temp area per run -> nothing is remembered across runs.
WORK_BASE="$SCRIPT_DIR/.workflow_tmp_$$_$(date +%s)"
LOG_DIR="$WORK_BASE/logs"
mkdir -p "$LOG_DIR"

cleanup() {
    for wt in "$WORK_BASE"/wt_*; do
        [ -d "$wt" ] && git -C "$SCRIPT_DIR" worktree remove --force "$wt" >/dev/null 2>&1
    done
    rm -rf "$WORK_BASE"
}
trap cleanup EXIT

# Drop stale worktree metadata from any crashed previous run (hygiene only).
git -C "$SCRIPT_DIR" worktree prune

# ---------------------------------------------------------------------------
# Candidate pool: "id|implementation_line|human label"
# These simulate the Implementer's proposed fixes.
# ---------------------------------------------------------------------------
CANDIDATES=(
    "cand_1|return s[::-1]|correct slicing"
    "cand_2|return s[1:] + s[:1]|subtle left-rotate bug (bad)"
    "cand_3|return ''.join(reversed(s))|correct via reversed()"
    "cand_4|return s|no reversal at all (bad)"
)

# ---------------------------------------------------------------------------
# Implementer step: write a candidate fix into an isolated worktree.
# ---------------------------------------------------------------------------
write_implementation() {
    local wt="$1"
    local impl="$2"
    python - "$wt" "$impl" <<'PY'
import sys
wt, impl = sys.argv[1], sys.argv[2]
content = (
    '"""Utility functions for string manipulation."""\n\n\n'
    'def reverse_string(s):\n'
    '    """Return the input string with its characters reversed."""\n'
    f'    {impl}\n\n\n'
    'def is_palindrome(text):\n'
    '    """Return True if the text reads the same forwards and backwards."""\n'
    '    cleaned = text.lower().replace(" ", "")\n'
    '    return cleaned == reverse_string(cleaned)\n'
)
with open(f"{wt}/string_utils.py", "w", encoding="utf-8") as f:
    f.write(content)
PY
}

echo "============================================================"
echo " run_workflow.sh  |  branch: $WORK_BRANCH"
echo " isolated worktrees:   $WORK_BASE"
echo "============================================================"

ids=()
pids=()
i=0
for cand in "${CANDIDATES[@]}"; do
    i=$((i + 1))
    id="${cand%%|*}"
    rest="${cand#*|}"
    impl="${rest%%|*}"
    label="${rest#*|}"

    wt="$WORK_BASE/wt_$i"
    git -C "$SCRIPT_DIR" worktree add --detach "$wt" "$WORK_BRANCH" >/dev/null 2>&1
    write_implementation "$wt" "$impl"

    # Reviewer step runs in PARALLEL: background subshell, logs, then &
    # NOTE: reviewer.py is COPIED into the worktree and run from there,
    # so Python imports the worktree's OWN string_utils.py (isolated review).
    (
        cp "$REVIEWER" "$wt/reviewer.py"
        cd "$wt" && python reviewer.py > "$LOG_DIR/$id.log" 2>&1
    ) &
    ids[$i]="$id"
    labels[$i]="$label"
    pids[$i]=$!
    echo "  launched candidate '$id' ($label) as PID ${pids[$i]}"
done

echo "------------------------------------------------------------"
echo " waiting for all reviewers to finish ($i parallel jobs)..."
echo "------------------------------------------------------------"

PASS_COUNT=0
FAIL_COUNT=0

# Collect finish statuses in submission order; `wait` yields each exit code.
for ((n = 1; n <= i; n++)); do
    wait "${pids[$n]}"
    rc=$?
    id="${ids[$n]}"
    label="${labels[$n]}"

    if [ "$rc" -eq 0 ]; then
        verdict="PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        verdict="FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    first_line=$(head -n 1 "$LOG_DIR/$id.log")
    printf '  %-8s | %-32s | %s (exit code %s)\n' "$id" "$label" "$verdict" "$rc"
    printf '           reviewer said: %s\n' "$first_line"
done

echo "------------------------------------------------------------"
echo " SUMMARY: $PASS_COUNT PASS, $FAIL_COUNT FAIL (out of $i candidates)"
echo "------------------------------------------------------------"