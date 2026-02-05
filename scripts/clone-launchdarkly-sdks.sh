#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Clone every LaunchDarkly GitHub repo with "sdk" in its name, plus the Relay Proxy.

Usage:
  scripts/clone-launchdarkly-sdks.sh [options]

Options:
  --dir <path>            Target directory (default: launchdarkly-repos)
  --depth <n>             Shallow clone depth (default: 1). Use 0 for full history.
  --full                  Same as --depth 0
  --ssh                   Use SSH URLs instead of HTTPS
  --include-archived      Include archived repositories
  --list                  Only list selected repositories (no cloning)
  --update                If repo already exists, pull latest (ff-only)
  -h, --help              Show help

Examples:
  scripts/clone-launchdarkly-sdks.sh
  scripts/clone-launchdarkly-sdks.sh --dir /tmp/ld --full --update
  scripts/clone-launchdarkly-sdks.sh --list
EOF
}

TARGET_DIR="launchdarkly-repos"
DEPTH="1"
USE_SSH="0"
INCLUDE_ARCHIVED="0"
LIST_ONLY="0"
UPDATE_EXISTING="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      TARGET_DIR="${2:-}"; shift 2 ;;
    --depth)
      DEPTH="${2:-}"; shift 2 ;;
    --full)
      DEPTH="0"; shift ;;
    --ssh)
      USE_SSH="1"; shift ;;
    --include-archived)
      INCLUDE_ARCHIVED="1"; shift ;;
    --list)
      LIST_ONLY="1"; shift ;;
    --update)
      UPDATE_EXISTING="1"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -z "${TARGET_DIR}" ]]; then
  echo "--dir cannot be empty" >&2
  exit 2
fi

mkdir -p "${TARGET_DIR}"

if ! command -v gh >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Error: GitHub CLI (gh) is required to discover all LaunchDarkly SDK repos automatically.
Install it from https://cli.github.com/ or run with a manually curated list.
EOF
  exit 1
fi

echo "Discovering LaunchDarkly repos via GitHub API..."

# Uses gh's built-in jq query support (-q). We select:
# - Any repo containing "sdk" in the name
# - The Relay Proxy repo ("ld-relay") and related relay repos (names containing "relay")
QUERY='
  .[]
  | select(('"${INCLUDE_ARCHIVED}"' == 1) or (.archived == false))
  | .name
'

mapfile -t ALL_REPOS < <(gh api orgs/launchdarkly/repos --paginate -q "${QUERY}")

SELECTED=()
for name in "${ALL_REPOS[@]}"; do
  if [[ "${name}" == *sdk* ]] || [[ "${name}" == "ld-relay" ]] || [[ "${name}" == ld-relay-* ]] || [[ "${name}" == *relay* ]]; then
    SELECTED+=("${name}")
  fi
done

# Ensure Relay Proxy is present even if filtering changes.
if [[ ! " ${SELECTED[*]} " =~ " ld-relay " ]]; then
  SELECTED+=("ld-relay")
fi

# De-duplicate + stable-ish output.
mapfile -t SELECTED < <(printf '%s\n' "${SELECTED[@]}" | awk '!seen[$0]++' | sort)

echo "Selected ${#SELECTED[@]} repositories."

if [[ "${LIST_ONLY}" == "1" ]]; then
  printf '%s\n' "${SELECTED[@]}"
  exit 0
fi

clone_url() {
  local repo="$1"
  if [[ "${USE_SSH}" == "1" ]]; then
    printf 'git@github.com:launchdarkly/%s.git' "${repo}"
  else
    printf 'https://github.com/launchdarkly/%s.git' "${repo}"
  fi
}

git_clone_args=()
if [[ "${DEPTH}" != "0" ]]; then
  git_clone_args+=(--depth "${DEPTH}")
fi

for repo in "${SELECTED[@]}"; do
  dest="${TARGET_DIR}/${repo}"
  url="$(clone_url "${repo}")"

  if [[ -d "${dest}/.git" ]]; then
    echo "Exists: ${repo}"
    if [[ "${UPDATE_EXISTING}" == "1" ]]; then
      echo "Updating: ${repo}"
      git -C "${dest}" pull --ff-only
    fi
    continue
  fi

  echo "Cloning: ${repo}"
  git clone "${git_clone_args[@]}" "${url}" "${dest}"
done

echo "Done. Repos are in: ${TARGET_DIR}"

