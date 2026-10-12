#!/usr/bin/env bash
# Install SwarmKit into a target repository (macOS/Linux).
#   ./install.sh /path/to/repo [-f] [-t task-name]
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET=""; FORCE=""; TASK=""

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force) FORCE="1"; shift ;;
    -t|--task)  TASK="$2"; shift 2 ;;
    *)          TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || { echo "ERROR: target required. Usage: ./install.sh <repo> [-f] [-t task]" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "ERROR: target does not exist: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"

copy_tree() {
  local src="$1" dst="$2" label="$3"
  [ -d "$src" ] || { echo "  skip  $label (missing)"; return; }
  if [ -d "$dst" ] && [ -z "$FORCE" ]; then
    local conflicts
    conflicts="$(cd "$src" && find . -type f | while read -r f; do
      [ -e "$dst/$f" ] && echo "${f#./}"
    done)"
    if [ -n "$conflicts" ]; then
      echo "  CONFLICT $label - already present, will NOT overwrite:"
      echo "$conflicts" | sed 's/^/           /'
      echo "           re-run with -f to replace."
      return
    fi
  fi
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
  echo "  ok    $label ($(find "$src" -type f | wc -l | tr -d ' ') files)"
}

echo "Installing SwarmKit into: $TARGET"
echo
echo "opencode/ -> $TARGET/.opencode"
copy_tree "$KIT/opencode" "$TARGET/.opencode" 'agents + commands'
echo
echo ".swarm/ -> $TARGET/.swarm"
for sub in tasks plans adr reviews state logs locks scripts templates; do
  copy_tree "$KIT/.swarm/$sub" "$TARGET/.swarm/$sub" ".swarm/$sub"
done
copy_tree "$KIT/schema" "$TARGET/.swarm/schema" ".swarm/schema"

GI="$TARGET/swarmkit/.swarm/.gitignore"
[ -f "$GI" ] || cat > "$GI" <<'GITIGNORE'
# Runtime swarm state. The plan, ADRs, reviews and log files ARE tracked;
# the lease and machine-local noise are not.
locks/*.lock
state/*.tmp
GITIGNORE
echo "  ok    swarmkit/.swarm/.gitignore"

echo
if [ -n "$TASK" ]; then
  "$TARGET/swarmkit/.swarm/scripts/swarm.sh" init -Task "$TASK"
fi

echo "Next:"
echo "  1. Write the task:   $TARGET/swarmkit/.swarm/tasks/$TASK.md"
echo "  2. Run the swarm:    /swarm-run $TASK"
echo "  3. Check the budget: $TARGET/swarmkit /.swarm/scripts/swarm.sh validate -Task $TASK"
