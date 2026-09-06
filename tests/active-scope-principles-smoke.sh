#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

mapfile -t agents < <(cd "$ROOT" && rg --files cycle1-dev _tools -g 'CLAUDE.md' | sort)
[[ "${#agents[@]}" -eq 29 ]] || fail "expected 29 active agent contracts, got ${#agents[@]}"

for relative in "${agents[@]}"; do
  dir="$ROOT/${relative%/CLAUDE.md}"
  for adapter in AGENTS.md GEMINI.md; do
    [[ -L "$dir/$adapter" && "$(readlink "$dir/$adapter")" == CLAUDE.md ]] ||
      fail "$relative: invalid canonical $adapter adapter"
  done
done

mapfile -t commands < <(cd "$ROOT" && rg --hidden --files . \
  -g 'cycle1-dev/**/.claude/commands/*.md' \
  -g '_tools/**/.claude/commands/*.md' \
  -g '!cycle2-deploy/**' -g '!cycle3-ops/**' | sort)
[[ "${#commands[@]}" -eq 67 ]] || fail "expected 67 active command templates, got ${#commands[@]}"

for command_file in "${commands[@]}"; do
  command_file="$ROOT/${command_file#./}"
  [[ "$(sed -n '1p' "$command_file")" == '---' ]] || fail "$command_file: missing frontmatter"
  grep -Eq '^description:[[:space:]]*[^[:space:]].*$' "$command_file" ||
    fail "$command_file: missing description"
done

for stale in \
  's6-release может начинать' \
  'cycle:1|2|3' \
  'stage:0..7' \
  'delivery_scope:' \
  'operational.tier' \
  'stage6-deploy/inputs stage6-deploy/outputs' \
  'stage7-ops/inputs stage7-ops/outputs'; do
  if rg --hidden -Fq -- "$stale" "$ROOT/cycle1-dev" "$ROOT/_tools"; then
    fail "active agent tree contains stale contract: $stale"
  fi
done

if rg --hidden -Fq -- '`topology`' \
  "$ROOT/cycle1-dev/s0-quality-gates/.claude/commands/configure.md"; then
  fail 'quality-gates configure consumes an absent topology field'
fi

grep -Fq 'Cycle 2/3 delivery/operations tooling не собирается' \
  "$ROOT/cycle1-dev/s0-kickoff/CLAUDE.md" || fail 'kickoff does not exclude frozen tooling'
grep -Fq 'criticality_tier:' "$ROOT/cycle1-dev/s1-pmo/CLAUDE.md" ||
  fail 'PMO handoff has no Cycle 1 criticality tier'
grep -Fq 'FROZEN / NOT READY' "$ROOT/cycle1-dev/s0-validate/.claude/commands/repair.md" ||
  fail 'repair contract does not reject frozen scope'

grep -Fq '## Delivered baseline' "$ROOT/plans/roadmap.md" ||
  fail 'roadmap has no delivered baseline reference'
grep -Fq '## Now' "$ROOT/plans/roadmap.md" || fail 'roadmap has no current outcome horizon'
grep -Fq '## Next' "$ROOT/plans/roadmap.md" || fail 'roadmap has no next outcome horizon'
grep -Fq '## Later / Decision gates' "$ROOT/plans/roadmap.md" ||
  fail 'roadmap has no future decision gates'
! grep -Fq '## 3. Доступные возможности' "$ROOT/plans/roadmap.md" ||
  fail 'roadmap still contains a delivered capability dump'
grep -Fq '`SDLC_SUBAGENTS=off` остаётся default' "$ROOT/README.md" ||
  fail 'README omits fail-safe default worker mode'
! grep -Fq 'Worker profile отклонён: используйте Claude' "$ROOT/README.md" ||
  fail 'stale runtime-switch worker advice remains'
grep -Fq 'subagent-run.sh: authorized bounded read-only worker' "$ROOT/OVERVIEW.md" ||
  fail 'overview diagram omits the bounded worker boundary'
grep -Fq '| 5 — Тестирование | `s5-security` |' "$ROOT/CLAUDE.md" ||
  fail 'root role table omits mandatory s5-security'
grep -Fq 'Authorization Designer — stack-neutral роли, права и enforcement model' "$ROOT/sdlc.sh" ||
  fail 'launcher retains a stack-specific RBAC label'
grep -Fq 's0-tracker /release-notes vX.Y.Z' "$ROOT/README.md" ||
  fail 'README does not expose the real release-notes route'
grep -Fq 'RELEASE_NOTES_V1.md' "$ROOT/_contract/README.md" ||
  fail 'release-notes contract is absent from canonical index'
! grep -Fq 'отдельный owner/contract будет определён' "$ROOT/_standards/quality.md" ||
  fail 'quality standard still describes release-notes owner as planned'

echo 'PASS: active-scope principles smoke'
