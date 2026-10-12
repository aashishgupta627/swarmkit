#!/usr/bin/env bash
# SwarmKit control script (bash/POSIX). Same verbs and output contract as
# swarm.ps1. Invoke as: swarmkit/.swarm/scripts/swarm.sh <verb> -Task <name>
set -euo pipefail

VERB="${1:-}"; shift || true
TASK=""
PHASE_ID=""
TITLE=""
FORCE=""

while [ $# -gt 0 ]; do
  case "$1" in
    -Task|-t)     TASK="$2"; shift 2 ;;
    -PhaseId)     PHASE_ID="$2"; shift 2 ;;
    -Title)       TITLE="$2"; shift 2 ;;
    -Force|-f)    FORCE="1"; shift ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 2 ;;
  esac
done

[ -n "$VERB" ] || { echo "ERROR: verb required" >&2; exit 2; }
[ -n "$TASK" ] || { echo "ERROR: -Task required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM="$(dirname "$SCRIPT_DIR")"
# Kit may be nested (swarmkit/.swarm); resolve the real git toplevel.
REPO="$(git -C "$SWARM" rev-parse --show-toplevel 2>/dev/null || dirname "$SWARM")"
STATE_DIR="$SWARM/state"; LOCK_DIR="$SWARM/locks"; LOG_DIR="$SWARM/logs"
PLAN_DIR="$SWARM/plans/$TASK"
STATE_FILE="$STATE_DIR/$TASK.json"
LOCK_FILE="$LOCK_DIR/$TASK.lock"
TASK_LOG="$LOG_DIR/$TASK"
mkdir -p "$STATE_DIR" "$LOCK_DIR" "$LOG_DIR"

session_id() { echo "orch-$$-$(date +%s)"; }
proc_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
head_sha() { git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo '0000000'; }

write_json() { printf '%s' "$1" > "$STATE_FILE"; }

case "$VERB" in
  init)
    if [ -f "$STATE_FILE" ] && [ -z "$FORCE" ]; then echo "EXISTS: $STATE_FILE (use -Force)"; exit 1; fi
    mkdir -p "$PLAN_DIR"
    HEAD_SHA="$(head_sha)"
    cat > "$STATE_FILE" <<JSON
{
  "schema_version": 2,
  "task": "$TASK",
  "status": "PENDING",
  "stage": "created",
  "head": "$HEAD_SHA",
  "plan_dir": "swarmkit/.swarm/plans/$TASK",
  "artifacts": {
    "task": "swarmkit/.swarm/tasks/$TASK.md",
    "plan": "swarmkit/.swarm/plans/$TASK/00-plan.md",
    "review": "swarmkit/.swarm/reviews/$TASK.md"
  },
  "done": [], "remaining": [], "blockers": [],
  "events": [
    { "at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "stage": "INIT", "detail": "State v2 created by swarm.sh init." }
  ],
  "decisions": [],
  "baseline": {},
  "env": {},
  "lock": { "holder": "", "since": "", "pid": null }
}
JSON
    echo "OK init task=$TASK state=$STATE_FILE"
    echo "NEXT: write swarmkit/.swarm/tasks/$TASK.md, then dispatch architect for $PLAN_DIR/00-plan.md"
    ;;

  new-phase)
    [ -n "$PHASE_ID" ] && [ -n "$TITLE" ] || { echo "ERROR: new-phase requires -PhaseId and -Title"; exit 2; }
    mkdir -p "$PLAN_DIR"
    SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')"
    FILE="$PLAN_DIR/$PHASE_ID-$SLUG.md"
    [ -f "$FILE" ] && [ -z "$FORCE" ] && { echo "EXISTS: $FILE"; exit 1; }
    cat > "$FILE" <<TPL
# $PHASE_ID - $TITLE

**Depends on:** <phase ids>
**Unblocks:** <phase ids>
**Status:** planned

## Scope

Files to create or change. Be specific: path -> what changes and why.

## Design

The part of the design this phase needs. Reference 00-plan.md for the
overall architecture; do not restate it here.

## Tests

Every test this phase must land, each mapped to an acceptance criterion.
A phase is not complete until its tests exist. Code without tests is not a
committable unit.

## Exit gate

The single check that decides whether this phase is DONE. Must be runnable
and must have been run.

## Escalation triggers

Stop and ask rather than absorb, if any of these occur.
TPL
    echo "OK new-phase $PHASE_ID -> $FILE"
    ;;

  log)
    [ -n "$PHASE_ID" ] || { echo "ERROR: log requires -PhaseId"; exit 2; }
    mkdir -p "$TASK_LOG"
    N=$(find "$TASK_LOG" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    FILE="$TASK_LOG/$(printf '%03d' $((N+1)))-$PHASE_ID.md"
    printf '# Log %s - %s - %s\n\n' "$PHASE_ID" "$TASK" "$(date +'%Y-%m-%d %H:%M')" > "$FILE"
    echo "OK log $FILE"
    ;;

  lock)
    [ -f "$STATE_FILE" ] || { echo "ERROR: no state for '$TASK'. Run init first."; exit 2; }
    HOLDER="$(grep -o '"holder"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*: *"//; s/"$//')"
    HPID="$(grep -o '"pid"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | tail -1 | sed 's/.*: *//')"
    if [ -n "$HOLDER" ]; then
      if proc_alive "$HPID"; then
        echo "LOCKED task=$TASK holder=$HOLDER pid=$HPID alive=true"
        echo "HALT: another swarm session holds the write lease. Do not proceed."
        exit 3
      fi
      if [ -z "$FORCE" ]; then
        echo "STALE_LOCK task=$TASK holder=$HOLDER pid=$HPID alive=false"
        echo "HALT: holder is gone but the lock was not released. Re-run with -Force after confirming."
        exit 3
      fi
    fi
    SID="$(session_id)"
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    sed -i.bak "s/\"holder\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"holder\": \"$SID\"/" "$STATE_FILE"
    sed -i.bak2 "s/\"pid\"[[:space:]]*:[[:space:]]*[0-9]*/\"pid\": $$/" "$STATE_FILE"
    rm -f "$STATE_FILE.bak" "$STATE_FILE.bak2"
    printf '{\n  "task": "%s",\n  "holder": "%s",\n  "pid": %s,\n  "since": "%s",\n  "repo": "%s"\n}\n' \
      "$TASK" "$SID" "$$" "$NOW" "$REPO" > "$LOCK_FILE"
    echo "OK lock task=$TASK holder=$SID"
    ;;

  unlock)
    sed -i.bak "s/\"holder\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"holder\": \"\"/" "$STATE_FILE"
    sed -i.bak2 "s/\"pid\"[[:space:]]*:[[:space:]]*[0-9]*/\"pid\": null/" "$STATE_FILE"
    rm -f "$STATE_FILE.bak" "$STATE_FILE.bak2"
    rm -f "$LOCK_FILE"
    echo "OK unlock task=$TASK"
    ;;

  status)
    [ -f "$STATE_FILE" ] || { echo "ERROR: no state for '$TASK'"; exit 2; }
    grep -q '"schema_version"[[:space:]]*:[[:space:]]*2' "$STATE_FILE" || {
      echo "ERROR: state is not schema v2."
      echo "      v1 state files are not resumable. Follow docs/MIGRATING.md:"
      echo "        1. archive it to swarmkit/.swarm/logs/$TASK/000-legacy-state-v1.json"
      echo "        2. split the plan into swarmkit/.swarm/plans/$TASK/00-plan.md plus phase files"
      echo "        3. re-run 'init -Force' and rebuild done[]/remaining[] from git"
      exit 2
    }
    LIVE="$(grep -o '"head"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*: *"//; s/"$//)')"
    ACTUAL="$(head_sha)"
    [ "$LIVE" = "$ACTUAL" ] && DRIFT="no" || DRIFT="YES ($LIVE -> $ACTUAL)"
    printf 'task=%s status=%s\n' \
      "$(grep -o '"task"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*: *"//; s/"$//')" \
      "$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*: *"//; s/"$//')"
    echo "head=$LIVE drift=$DRIFT"
    echo "plan=$([ -f "$PLAN_DIR/00-plan.md" ] && echo "$PLAN_DIR/00-plan.md" || echo 'MISSING 00-plan.md')"
    echo "todo (authoritative builder input):"
    grep -o '"phase_file"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*: *"//; s/"$//' | sed 's/^/  /'
    ;;

  validate-findings)
    command -v python3 >/dev/null 2>&1 || { echo "ERROR: validate-findings needs python3 on this platform"; exit 2; }
    [ -f "$SCRIPT_DIR/validate-findings.py" ] || { echo "ERROR: missing $SCRIPT_DIR/validate-findings.py"; exit 2; }
    exec python3 "$SCRIPT_DIR/validate-findings.py" "$TASK" "$SWARM"
    ;;

  validate)
    ERR=0
    SZ=$(wc -c < "$STATE_FILE" | tr -d ' ')
    [ "$SZ" -le 4096 ] || { echo "ERROR state is $SZ bytes > 4096 budget. Fold detail into $TASK_LOG/"; ERR=1; }
    grep -q '"schema_version"[[:space:]]*:[[:space:]]*2' "$STATE_FILE" || { echo "ERROR not schema v2"; ERR=1; }
    # Reserved, optional fields. Absent means autonomy=supervised and cycle 0.
    if grep -Eq '"autonomy"[[:space:]]*:' "$STATE_FILE"; then
      AUT="$(grep -o '"autonomy"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | head -1 | sed 's/.*: *"//; s/"$//' || true)"
      case "$AUT" in
        supervised|auto) ;;
        *) echo "ERROR autonomy must be 'supervised' or 'auto', got '$AUT'"; ERR=1 ;;
      esac
    fi
    if grep -Eq '"heal"[[:space:]]*:' "$STATE_FILE"; then
      tr -d '\r\n' < "$STATE_FILE" | grep -Eq '"heal"[[:space:]]*:[[:space:]]*\{[^}]*"cycle"[[:space:]]*:[[:space:]]*[0-9]+' \
        || { echo "ERROR heal must be an object with an integer cycle >= 0"; ERR=1; }
    fi
    LONG=$(grep -o '"detail"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" \
           | awk '{ if (length($0) > 200) print }' | wc -l | tr -d ' ')
    [ "$LONG" -eq 0 ] || { echo "ERROR $LONG event detail(s) exceed the 180-char cap"; ERR=1; }
    P0="$PLAN_DIR/00-plan.md"
    if [ -f "$P0" ]; then
      PL=$(wc -l < "$P0" | tr -d ' ')
      [ "$PL" -le 300 ] || { echo "ERROR 00-plan.md is $PL lines > 300. Move detail to per-phase files."; ERR=1; }
    fi
    if [ "$ERR" -eq 0 ]; then echo "OK validate task=$TASK bytes=$SZ"; else exit 1; fi
    ;;

  compact)
    [ -f "$STATE_FILE" ] || { echo "ERROR: no state"; exit 2; }
    mkdir -p "$TASK_LOG"
    N=$(find "$TASK_LOG" -name '*.md' | wc -l | tr -d ' ')
    sed -n 's/.*"detail"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -n -10 >> "$TASK_LOG/$(printf '%03d' $((N+1)))-events-fold.md"
    echo "NOTE: compact on bash rewrites events manually; prefer running the PowerShell version on Windows."
    ;;

  *) echo "ERROR: unhandled verb $VERB"; exit 2 ;;
esac
