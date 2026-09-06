#!/usr/bin/env bash

set -euo pipefail
shopt -s nocasematch

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-documentation-contract.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

relative() {
  printf '%s\n' "${1#"$ROOT/"}"
}

strip_code() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fenced = !fenced; next }
    fenced { next }
    {
      line = $0
      while (match(line, /`[^`]*`/)) {
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }
      print line
    }
  ' "$1"
}

resolve_link() {
  local source="$1" target="$2" candidate base name rel
  target="${target#<}"
  target="${target%>}"
  target="${target%%\?*}"
  [[ -n "$target" ]] || { printf '%s\n' "$source"; return 0; }
  [[ "$target" == *.md ]] || target="$target.md"

  for candidate in "$(dirname "$source")/$target" "$ROOT/$target"; do
    if [[ -f "$candidate" ]]; then
      realpath "$candidate"
      return 0
    fi
  done

  base="$(basename "$target")"
  matches=()
  for candidate in "${markdown_files[@]}"; do
    [[ "$(basename "$candidate")" == "$base" ]] || continue
    matches+=("$candidate")
  done
  [[ ${#matches[@]} -eq 1 ]] || return 1
  printf '%s\n' "${matches[0]}"
}

anchor_exists() {
  local file="$1" wanted="$2" heading slug
  wanted="${wanted#\#}"
  wanted="${wanted//%20/ }"
  while IFS= read -r heading; do
    heading="${heading#\#}"
    while [[ "$heading" == \#* ]]; do heading="${heading#\#}"; done
    heading="${heading# }"
    [[ "$heading" == "$wanted" ]] && return 0
    slug="$(printf '%s' "$heading" | tr '[:upper:]' '[:lower:]' | \
      sed -E 's/<[^>]+>//g; s/[^[:alnum:] _-]//g; s/[ _]+/-/g; s/^-+//; s/-+$//')"
    [[ "$slug" == "$wanted" ]] && return 0
  done < <(rg '^#{1,6}[[:space:]]+' "$file" || true)
  return 1
}

markdown_files=()
root_markdown=(
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  README.md
  OVERVIEW.md
  CHANGELOG.md
)
public_markdown_roots=(
  _standards
  _contract
  _runtimes
  _tools
  plans
  cycle1-dev
  tests
  .github
)
for rel in "${root_markdown[@]}"; do
  [[ -f "$ROOT/$rel" && ! -L "$ROOT/$rel" ]] || fail "missing public root Markdown: $rel"
  markdown_files+=("$ROOT/$rel")
done
for rel in "${public_markdown_roots[@]}"; do
  [[ -d "$ROOT/$rel" ]] || continue
  while IFS= read -r -d '' candidate; do
    markdown_files+=("$candidate")
  done < <(find "$ROOT/$rel" -type f -name '*.md' -print0 | sort -z)
done

[[ ${#markdown_files[@]} -gt 0 ]] || fail 'current Markdown inventory is empty'

link_count=0
for source in "${markdown_files[@]}"; do
  rel="$(relative "$source")"
  iconv -f UTF-8 -t UTF-8 "$source" >/dev/null 2>&1 || fail "$rel is not valid UTF-8"
  cmp -s "$source" <(tr -d '\000' < "$source") || fail "$rel contains NUL"
  ! LC_ALL=C grep -q $'\r' "$source" || fail "$rel contains CR/CRLF"
  ! rg -n '[[:blank:]]+$' "$source" >/dev/null || fail "$rel contains trailing whitespace"
  [[ ! -s "$source" || "$(tail -c 1 "$source" | od -An -t u1 | tr -d ' ')" == 10 ]] || \
    fail "$rel has no final newline"
  awk '
    /^[[:space:]]*```/ { ticks++ }
    /^[[:space:]]*~~~/ { tildes++ }
    END { exit((ticks % 2 == 0 && tildes % 2 == 0) ? 0 : 1) }
  ' "$source" || fail "$rel has unbalanced fenced code"

  clean="$TMP_DIR/clean-$link_count.md"
  strip_code "$source" > "$clean"

  while IFS= read -r raw; do
    [[ -n "$raw" ]] || continue
    link="${raw#\[\[}"
    link="${link%\]\]}"
    link="${link%%|*}"
    target="${link%%#*}"
    [[ "$link" == *'#'* ]] && anchor="${link#*#}" || anchor=''
    resolved="$(resolve_link "$source" "$target")" || fail "$rel: unresolved wiki target $target"
    [[ -z "$anchor" ]] || anchor_exists "$resolved" "$anchor" || \
      fail "$rel: broken wiki anchor $target#$anchor"
    link_count=$((link_count + 1))
  done < <(rg -o '\[\[[^]]+\]\]' "$clean" || true)

  while IFS= read -r raw; do
    [[ -n "$raw" ]] || continue
    link="${raw#*](}"
    link="${link%)}"
    link="${link%% \"*}"
    case "$link" in
      http://*|https://*|mailto:*|app://*|\#*) continue ;;
    esac
    target="${link%%#*}"
    [[ "$link" == *'#'* ]] && anchor="${link#*#}" || anchor=''
    resolved="$(resolve_link "$source" "$target")" || fail "$rel: unresolved Markdown target $target"
    [[ -z "$anchor" ]] || anchor_exists "$resolved" "$anchor" || \
      fail "$rel: broken Markdown anchor $target#$anchor"
    link_count=$((link_count + 1))
  done < <(rg -o '\[[^]]+\]\([^)]+\)' "$clean" || true)
done

mapfile -d '' -t roles < <(find "$ROOT/cycle1-dev" "$ROOT/_tools" \
  -mindepth 2 -maxdepth 2 -name CLAUDE.md -type f -print0 | sort -z)
[[ ${#roles[@]} -eq 29 ]] || fail "active role inventory changed: expected=29 actual=${#roles[@]}"

mapfile -d '' -t commands < <(find "$ROOT/cycle1-dev" "$ROOT/_tools" \
  -path '*/.claude/commands/*.md' -type f -print0 | sort -z)
[[ ${#commands[@]} -eq 67 ]] || fail "active command inventory changed: expected=67 actual=${#commands[@]}"
for command in "${commands[@]}"; do
  rel="$(relative "$command")"
  [[ "$(sed -n '1p' "$command")" == '---' ]] || fail "$rel has no opening frontmatter fence"
  awk 'NR == 1 { next } /^---$/ { closed=1; exit } END { exit(closed ? 0 : 1) }' "$command" || \
    fail "$rel has no closing frontmatter fence"
  awk 'NR == 1 { next } /^---$/ { exit } /^description:[[:space:]]*[^[:space:]].*/ { found=1 } END { exit(found ? 0 : 1) }' "$command" || \
    fail "$rel has no non-empty flat description"
done

metadata_producers=(
  s0-quality-gates s0-tracker s1-pm s1-pmo s1-finance s2-ba s2-po s2-qa-req
  s2-test-strategy s2-security s3-arch s3-security s3-rbac s3-dba s4-qa-auto
  s4-dev s4-techlead s5-qa s5-qa-auto s5-perf s5-security
)
for producer in "${metadata_producers[@]}"; do
  grep -Fq '_standards/artifact-metadata.md' "$ROOT/cycle1-dev/$producer/CLAUDE.md" ||
    fail "$producer role does not read the common Artifact Metadata contract"
done
mapfile -t metadata_command_producers < <(bash -c '
  root="$1"
  source "$root/sdlc.sh"
  while IFS= read -r -d "" command; do
    relative="${command#"$root/cycle1-dev/"}"
    agent="${relative%%/*}"
    task="/${command##*/}"
    task="${task%.md}"
    [[ "$task" != /release-notes ]] || task="/release-notes v0.0.0"
    groups="$(cycle1_declared_output_groups "$agent" "$task" 2>/dev/null || true)"
    [[ "$groups" == *".md"* ]] && printf "%s\n" "$command"
  done < <(find "$root/cycle1-dev" -path "*/.claude/commands/*.md" -type f -print0 | sort -z)
' _ "$ROOT")
[[ ${#metadata_command_producers[@]} -eq 32 ]] ||
  fail "declared Markdown command inventory changed: expected=32 actual=${#metadata_command_producers[@]}"
for producer in "${metadata_command_producers[@]}"; do
  rel="$(relative "$producer")"
  grep -Fq '_standards/artifact-metadata.md' "$producer" ||
    fail "$rel command does not read the common Artifact Metadata contract"
done
for validator in product-acceptance-check.sh architecture-decision-trace-check.sh \
  tdd-status-check.sh cycle1-completion-check.sh s5-validation-check.sh; do
  grep -Fq 'artifact-metadata-check.sh' "$ROOT/cycle1-dev/s0-validate/$validator" ||
    fail "$validator does not compose the common metadata validator"
done
grep -Fq 'artifact-metadata-check.sh' "$ROOT/sdlc.sh" ||
  fail 'launcher does not validate every changed Project Markdown output'

mapfile -d '' -t adapters < <(find "$ROOT/cycle1-dev" "$ROOT/cycle2-deploy" \
  "$ROOT/cycle3-ops" "$ROOT/_tools" -type l -print0 | sort -z)
[[ ${#adapters[@]} -eq 64 ]] || fail "canonical adapter inventory changed: expected=64 actual=${#adapters[@]}"
for adapter in "${adapters[@]}"; do
  rel="$(relative "$adapter")"
  [[ "$(readlink "$adapter")" == CLAUDE.md ]] || fail "$rel does not point to sibling CLAUDE.md"
  [[ -f "$(dirname "$adapter")/CLAUDE.md" ]] || fail "$rel has no canonical sibling CLAUDE.md"
  [[ "$(realpath "$adapter")" == "$(realpath "$(dirname "$adapter")/CLAUDE.md")" ]] || \
    fail "$rel resolves outside its canonical role root"
done

bash -c 'source "$1"; [[ "${#CYCLE1_AGENTS[@]}" -eq 28 ]]' _ "$ROOT/sdlc.sh" || \
  fail 'Cycle 1 mandatory DAG must contain exactly 28 steps'

echo "INFO: current Markdown=${#markdown_files[@]} links=$link_count active_roles=${#roles[@]} active_commands=${#commands[@]} metadata_commands=${#metadata_command_producers[@]} canonical_adapters=${#adapters[@]} mandatory_steps=28"
echo 'INFO: inventory=filesystem-public-allowlist-current-Markdown; exclusions=frozen-cycle2-cycle3,historical-release-notes'
echo 'PASS: documentation contract smoke'
