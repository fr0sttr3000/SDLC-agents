#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-public-root-inventory.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

check_root() {
  local root="$1" name
  while IFS= read -r name; do
    case "$name" in
      .gitignore|AGENTS.md|CHANGELOG.md|CLAUDE.md|GEMINI.md|OVERVIEW.md|README.md|\
      RELEASE_NOTES_v*.md|localrun.ps1|localrun.sh|sdlc.ps1|sdlc.sh|sdlc-task.sh) ;;
      *) echo "ROOT INVENTORY BLOCKED: unexpected public root file: $name" >&2; return 1 ;;
    esac
    [[ -s "$root/$name" ]] || {
      echo "ROOT INVENTORY BLOCKED: empty public root file: $name" >&2
      return 1
    }
  done < <(find "$root" -maxdepth 1 -type f -printf '%f\n' | sort)

  while IFS= read -r name; do
    echo "ROOT INVENTORY BLOCKED: unsupported public root entry type: $name" >&2
    return 1
  done < <(find "$root" -maxdepth 1 -mindepth 1 ! -type f ! -type d -printf '%f\n' | sort)

  for launcher in sdlc.sh localrun.sh sdlc-task.sh; do
    [[ -x "$root/$launcher" ]] || {
      echo "ROOT INVENTORY BLOCKED: launcher is not executable: $launcher" >&2
      return 1
    }
  done
}

expect_blocked() {
  local expected="$1" output
  if output="$(check_root "$FIXTURE" 2>&1)"; then
    fail "fixture was accepted; expected: $expected"
  fi
  [[ "$output" == *"$expected"* ]] || fail "wrong blocker: $output"
}

check_root "$ROOT" || fail 'real public root inventory is invalid'

FIXTURE="$TMP_DIR/root"
mkdir -p "$FIXTURE"
printf '%s\n' '# fixture' > "$FIXTURE/README.md"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FIXTURE/sdlc.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FIXTURE/localrun.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$FIXTURE/sdlc-task.sh"
chmod +x "$FIXTURE/sdlc.sh" "$FIXTURE/localrun.sh" "$FIXTURE/sdlc-task.sh"
check_root "$FIXTURE" || fail 'known root names were rejected'

: > "$FIXTURE/README.md"
expect_blocked 'empty public root file: README.md'
printf '%s\n' '# fixture' > "$FIXTURE/README.md"

: > "$FIXTURE/fragment"
expect_blocked 'unexpected public root file: fragment'
rm -f "$FIXTURE/fragment"

printf '%s\n' 'unexpected' > "$FIXTURE/rogue.bin"
expect_blocked 'unexpected public root file: rogue.bin'
rm -f "$FIXTURE/rogue.bin"

mkfifo "$FIXTURE/unexpected.fifo"
expect_blocked 'unsupported public root entry type: unexpected.fifo'
rm -f "$FIXTURE/unexpected.fifo"

ln -s /etc/passwd "$FIXTURE/unsafe-link"
expect_blocked 'unsupported public root entry type: unsafe-link'
rm -f "$FIXTURE/unsafe-link"

echo 'PASS: public root inventory smoke'
