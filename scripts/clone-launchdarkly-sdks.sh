#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Clone LaunchDarkly SDK repositories (and Relay Proxy) into a local folder.

Requirements:
  - gh (GitHub CLI), authenticated
  - git

Usage:
  scripts/clone-launchdarkly-sdks.sh [--org ORG] [--dest DIR] [--method https|ssh] [--depth N|--full]
                                    [--include-archived] [--include-forks]
                                    [--pattern BASH_REGEX]
                                    [--list] [--dry-run]

Defaults:
  --org      launchdarkly
  --dest     launchdarkly-repos
  --method   https
  --depth    1     (shallow clone)
  --pattern  (sdk|sdks|^ld-relay($|-))

Examples:
  # Just list repos that would be cloned
  scripts/clone-launchdarkly-sdks.sh --list

  # Shallow clone into the default folder
  scripts/clone-launchdarkly-sdks.sh

  # Full history clone over SSH into a custom folder
  scripts/clone-launchdarkly-sdks.sh --method ssh --full --dest /tmp/ld
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

ORG="${LD_ORG:-launchdarkly}"
DEST="launchdarkly-repos"
METHOD="https"
DEPTH="1"
INCLUDE_ARCHIVED="false"
INCLUDE_FORKS="false"
PATTERN='(sdk|sdks|^ld-relay($|-))'
DO_LIST="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --org)
      ORG="${2:-}"; shift 2
      ;;
    --dest)
      DEST="${2:-}"; shift 2
      ;;
    --method)
      METHOD="${2:-}"; shift 2
      ;;
    --depth)
      DEPTH="${2:-}"; shift 2
      ;;
    --full)
      DEPTH="0"; shift 1
      ;;
    --include-archived)
      INCLUDE_ARCHIVED="true"; shift 1
      ;;
    --include-forks)
      INCLUDE_FORKS="true"; shift 1
      ;;
    --pattern)
      PATTERN="${2:-}"; shift 2
      ;;
    --list)
      DO_LIST="true"; shift 1
      ;;
    --dry-run)
      DRY_RUN="true"; shift 1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$DEST" ]]; then
  echo "--dest cannot be empty" >&2
  exit 2
fi
if [[ "$METHOD" != "https" && "$METHOD" != "ssh" ]]; then
  echo "--method must be 'https' or 'ssh' (got: $METHOD)" >&2
  exit 2
fi
if ! [[ "$DEPTH" =~ ^[0-9]+$ ]]; then
  echo "--depth must be a non-negative integer (got: $DEPTH)" >&2
  exit 2
fi

need_cmd gh
need_cmd git

mkdir -p "$DEST"

shopt -s nocasematch

selected=()
while IFS=$'\t' read -r name url sshUrl isArchived isFork; do
  [[ -n "$name" ]] || continue

  if [[ "$INCLUDE_ARCHIVED" != "true" && "$isArchived" == "true" ]]; then
    continue
  fi
  if [[ "$INCLUDE_FORKS" != "true" && "$isFork" == "true" ]]; then
    continue
  fi

  if [[ "$name" =~ $PATTERN ]]; then
    if [[ "$METHOD" == "ssh" ]]; then
      selected+=("$name"$'\t'"$sshUrl")
    else
      selected+=("$name"$'\t'"$url")
    fi
  fi
done < <(gh repo list "$ORG" --limit 2000 --json name,url,sshUrl,isArchived,isFork --jq '.[] | "\(.name)\t\(.url)\t\(.sshUrl)\t\(.isArchived)\t\(.isFork)"')

if [[ "${#selected[@]}" -eq 0 ]]; then
  echo "No repos matched pattern: $PATTERN" >&2
  exit 1
fi

printf '%s\n' "${selected[@]}" | LC_ALL=C sort | while IFS=$'\t' read -r name cloneUrl; do
  if [[ "$DO_LIST" == "true" ]]; then
    echo "$name	$cloneUrl"
    continue
  fi

  target="$DEST/$name"
  if [[ -d "$target/.git" ]]; then
    echo "Already cloned: $name"
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would clone: $cloneUrl -> $target"
    continue
  fi

  if [[ "$DEPTH" == "0" ]]; then
    echo "Cloning (full): $name"
    git clone "$cloneUrl" "$target"
  else
    echo "Cloning (depth=$DEPTH): $name"
    git clone --depth "$DEPTH" "$cloneUrl" "$target"
  fi
done

