#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Clone LaunchDarkly SDK repos (and Relay Proxy) from GitHub.

Defaults:
  - clones into ./launchdarkly-repos
  - matches repo names containing: sdk | relay-proxy | ld-relay
  - skips archived repos
  - uses shallow clones (depth 1) to keep it fast

Usage:
  scripts/clone_launchdarkly_sdks_and_relay.sh [options]

Options:
  --dest DIR              Destination directory (default: launchdarkly-repos)
  --pattern REGEX         Regex to select repos by name
                          (default: '(sdk|relay[-_]?proxy|ld[-_]?relay)')
  --org ORG               GitHub org/user to list from (default: launchdarkly)
  --include-archived      Include archived repos (default: no)
  --depth N               Shallow clone depth (default: 1). Use 0 for full clone.
  --jobs N                Parallel clone jobs (default: 4)
  --update                If repo exists, run 'git fetch' instead of skipping
  --dry-run               Print what would be cloned, then exit
  -h, --help              Show this help

Examples:
  scripts/clone_launchdarkly_sdks_and_relay.sh
  scripts/clone_launchdarkly_sdks_and_relay.sh --depth 0 --jobs 2
  scripts/clone_launchdarkly_sdks_and_relay.sh --dest /tmp/ld --dry-run
EOF
}

DEST="launchdarkly-repos"
PATTERN='(sdk|relay[-_]?proxy|ld[-_]?relay)'
ORG="launchdarkly"
INCLUDE_ARCHIVED=0
DEPTH=1
JOBS=4
UPDATE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="${2:-}"; shift 2 ;;
    --pattern) PATTERN="${2:-}"; shift 2 ;;
    --org) ORG="${2:-}"; shift 2 ;;
    --include-archived) INCLUDE_ARCHIVED=1; shift ;;
    --depth) DEPTH="${2:-}"; shift 2 ;;
    --jobs) JOBS="${2:-}"; shift 2 ;;
    --update) UPDATE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing 'gh' (GitHub CLI). Install it or run in an environment with gh configured." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "Missing 'git'." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing 'python3' (used for filtering)." >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEST_PATH="$DEST"
if [[ "$DEST_PATH" != /* ]]; then
  DEST_PATH="$ROOT/$DEST_PATH"
fi
mkdir -p "$DEST_PATH"

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

# Fetch repo list once.
gh repo list "$ORG" --limit 1000 --json name,isArchived,isFork --jq \
  '[.[] | select(.isFork==false) | {name, isArchived}]' > "$TMP_JSON"

REPO_LIST="$DEST_PATH/_launchdarkly_repo_list.txt"

python3 - <<PY > "$REPO_LIST"
import json, re
org = ${ORG!r}
pattern = re.compile(${PATTERN!r}, re.I)
include_archived = bool(${INCLUDE_ARCHIVED})

data = json.load(open(${TMP_JSON!r}, "r", encoding="utf-8"))
names = []
for r in data:
    name = r["name"]
    if not pattern.search(name):
        continue
    if (not include_archived) and r.get("isArchived"):
        continue
    names.append(name)

names.sort(key=str.lower)
for n in names:
    print(f"{org}/{n}")
PY

COUNT="$(wc -l < "$REPO_LIST" | tr -d ' ')"
echo "Selected $COUNT repos into: $REPO_LIST"

if [[ "$DRY_RUN" == "1" ]]; then
  cat "$REPO_LIST"
  exit 0
fi

clone_one() {
  local full="$1" dest_dir="$2" update="$3" depth="$4"
  local org_repo="${full}"
  local name="${org_repo#*/}"
  local target="$dest_dir/$name"

  if [[ -d "$target/.git" ]]; then
    if [[ "$update" == "1" ]]; then
      echo "[update] $org_repo"
      git -C "$target" fetch --prune
    else
      echo "[skip]   $org_repo (already exists)"
    fi
    return 0
  fi

  echo "[clone]  $org_repo"
  if [[ "$depth" == "0" ]]; then
    git clone "https://github.com/$org_repo.git" "$target"
  else
    git clone --depth "$depth" "https://github.com/$org_repo.git" "$target"
  fi
}
export -f clone_one

# shellcheck disable=SC2016
cat "$REPO_LIST" | xargs -n 1 -P "$JOBS" -I '{}' bash -lc \
  'clone_one "$1" "$2" "$3" "$4"' _ '{}' "$DEST_PATH" "$UPDATE" "$DEPTH"

echo "Done. Repos are in: $DEST_PATH"
