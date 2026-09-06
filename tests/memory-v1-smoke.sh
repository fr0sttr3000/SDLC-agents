#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-memory-v1.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

MEMORYCTL="$ROOT/_runtimes/memory/memoryctl.sh"
PROJECT="$TMP_DIR/projects/Alpha"
STORE="$TMP_DIR/store"
RUN_DIR="$TMP_DIR/state/run-1"

fail() { echo "FAIL: $*" >&2; exit 1; }

required_files=("$ROOT/_contract/MEMORY_V1.md" "$ROOT/_contract/memory-role-access-v1.tsv" "$MEMORYCTL")
for required in "${required_files[@]}"; do
  [[ -f "$required" ]] || fail "missing memory contract/runtime: $required"
done
[[ -x "$MEMORYCTL" ]] || fail 'memoryctl is not executable'

mkdir -p "$PROJECT/tracking/memory/proposals" "$PROJECT/stage1-planning/outputs" "$STORE" "$RUN_DIR"
printf '%s\n' 'current product vision' >"$PROJECT/stage1-planning/outputs/PM-vision.md"
source_sha="$(sha256sum "$PROJECT/stage1-planning/outputs/PM-vision.md" | awk '{print $1}')"

"$MEMORYCTL" configure --project "$PROJECT" --provider files-v1 --endpoint "$STORE" \
  --credential-ref none --namespace alpha --read-approval profile \
  --collections planning,defects,architecture --retention-days 3650 >/dev/null

title_b64="$(printf '%s' 'Validated product direction' | base64 | tr -d '\n')"
body_b64="$(printf '%s' 'Prefer the current verified product vision over historical assumptions.' | base64 | tr -d '\n')"
proposal="$PROJECT/tracking/memory/proposals/planning.tsv"
printf '%s\n' $'schema_version\toperation\tcollection\trecord_id\ttitle_b64\tbody_b64\ttags\tsource_ref\tsource_sha256\tsupersedes' >"$proposal"
printf '1\tadd\tplanning\tMEM-PLANNING-001\t%s\t%s\tvision,validated\t%s\t%s\tnone\n' "$title_b64" "$body_b64" 'stage1-planning/outputs/PM-vision.md' "$source_sha" >>"$proposal"

"$MEMORYCTL" profile-check --project "$PROJECT" >/dev/null || fail 'valid profile rejected'
"$MEMORYCTL" proposal-check --project "$PROJECT" --agent s1-pm --command /vision --proposal "$proposal" >/dev/null || fail 'valid proposal rejected'
cp "$proposal" "$TMP_DIR/outside-proposal.tsv"
if "$MEMORYCTL" proposal-check --project "$PROJECT" --agent s1-pm --command /vision --proposal "$TMP_DIR/outside-proposal.tsv" >"$TMP_DIR/outside-proposal.out" 2>&1; then
  fail 'proposal outside canonical Project was accepted'
fi
grep -Fq 'inside the canonical Project' "$TMP_DIR/outside-proposal.out" || fail 'outside-proposal rejection is unclear'
if "$MEMORYCTL" proposal-check --project "$PROJECT" --agent s1-pm --command /unknown --proposal "$proposal" >"$TMP_DIR/unknown-command.out" 2>&1; then
  fail 'unknown command inherited role-level memory write access'
fi
grep -Fq 'ACL BLOCKED' "$TMP_DIR/unknown-command.out" || fail 'unknown-command rejection is unclear'

approval_id='APPROVAL-MEMORY-WRITE-TEST'
printf '%s\n' tester APPROVE 'approved memory write for smoke test' "APPROVE $approval_id" | XDG_STATE_HOME="$TMP_DIR/state" "$MEMORYCTL" apply --project "$PROJECT" --agent s1-pm --command /vision --proposal "$proposal" --approval-id "$approval_id" >"$TMP_DIR/apply.out" || fail 'approved proposal was not applied'
grep -Fq 'MEMORY APPLIED' "$TMP_DIR/apply.out" || fail 'apply receipt was not reported'

snapshot="$RUN_DIR/memory/snapshot.md"
SDLC_EXECUTION_RUN_DIR="$RUN_DIR" XDG_STATE_HOME="$TMP_DIR/state" "$MEMORYCTL" snapshot --project "$PROJECT" --agent s1-pm --command /vision --collections planning --output "$snapshot" >/dev/null || fail 'approved planning snapshot failed'
grep -Fq 'Validated product direction' "$snapshot" || fail 'snapshot omitted the record title'
grep -Fq 'untrusted reference data' "$snapshot" || fail 'snapshot lacks its trust boundary'
if SDLC_EXECUTION_RUN_DIR="$RUN_DIR" "$MEMORYCTL" snapshot --project "$PROJECT" --agent s1-pm --command /vision --collections planning --output "$TMP_DIR/outside-snapshot.md" >"$TMP_DIR/outside-snapshot.out" 2>&1; then
  fail 'snapshot outside launcher-owned memory directory was accepted'
fi
grep -Fq 'exact launcher memory directory' "$TMP_DIR/outside-snapshot.out" || fail 'outside-snapshot rejection is unclear'

updated_body_b64="$(printf '%s' 'Use the current verified direction; the previous formulation is superseded.' | base64 | tr -d '\n')"
supersede="$PROJECT/tracking/memory/proposals/supersede.tsv"
head -n 1 "$proposal" >"$supersede"
printf '1\tsupersede\tplanning\tMEM-PLANNING-002\t%s\t%s\tvision,validated\t%s\t%s\tMEM-PLANNING-001\n' "$title_b64" "$updated_body_b64" 'stage1-planning/outputs/PM-vision.md' "$source_sha" >>"$supersede"
supersede_approval='APPROVAL-MEMORY-SUPERSEDE-TEST'
printf '%s\n' tester APPROVE 'approved supersede for smoke test' "APPROVE $supersede_approval" | XDG_STATE_HOME="$TMP_DIR/state" "$MEMORYCTL" apply --project "$PROJECT" --agent s1-pm --command /vision --proposal "$supersede" --approval-id "$supersede_approval" >/dev/null || fail 'append-only supersede failed'
superseded_snapshot="$RUN_DIR/memory/superseded.md"
SDLC_EXECUTION_RUN_DIR="$RUN_DIR" XDG_STATE_HOME="$TMP_DIR/state" "$MEMORYCTL" snapshot --project "$PROJECT" --agent s1-pm --command /vision --collections planning --output "$superseded_snapshot" >/dev/null || fail 'snapshot after supersede failed'
grep -Fq 'previous formulation is superseded' "$superseded_snapshot" || fail 'snapshot omitted superseding record'
! grep -Fq 'historical assumptions' "$superseded_snapshot" || fail 'snapshot exposed superseded record'

if SDLC_EXECUTION_RUN_DIR="$RUN_DIR" "$MEMORYCTL" snapshot --project "$PROJECT" --agent s3-arch --command /hld --collections planning --output "$RUN_DIR/memory/cross-role.md" >"$TMP_DIR/cross-role.out" 2>&1; then
  fail 'architecture role read planning memory'
fi
grep -Fq 'ACL BLOCKED' "$TMP_DIR/cross-role.out" || fail 'cross-role rejection is unclear'

secret_field='api'
secret_field+='_key'
secret_fixture='sk-'
secret_fixture+='example-secret-value'
secret_body="$(printf '%s=%s' "$secret_field" "$secret_fixture" | base64 | tr -d '\n')"
secret_proposal="$PROJECT/tracking/memory/proposals/secret.tsv"
head -n 1 "$proposal" >"$secret_proposal"
printf '1\tadd\tplanning\tMEM-PLANNING-003\t%s\t%s\tsecurity\t%s\t%s\tnone\n' "$title_b64" "$secret_body" 'stage1-planning/outputs/PM-vision.md' "$source_sha" >>"$secret_proposal"
if "$MEMORYCTL" proposal-check --project "$PROJECT" --agent s1-pm --command /vision --proposal "$secret_proposal" >"$TMP_DIR/secret.out" 2>&1; then
  fail 'secret-like memory proposal was accepted'
fi
grep -Fq 'secret-like' "$TMP_DIR/secret.out" || fail 'secret rejection is unclear'

record="$(find "$STORE" -type f -name '*.record' -print -quit)"
[[ -n "$record" ]] || fail 'files provider did not persist a record'
printf '%s\n' 'tampered=true' >>"$record"
if SDLC_EXECUTION_RUN_DIR="$RUN_DIR" "$MEMORYCTL" snapshot --project "$PROJECT" --agent s1-pm --command /vision --collections planning --output "$RUN_DIR/memory/tampered.md" >"$TMP_DIR/tampered.out" 2>&1; then
  fail 'tampered provider record was accepted'
fi
grep -Fq 'digest mismatch' "$TMP_DIR/tampered.out" || fail 'tamper rejection is unclear'

OTHER_PROJECT="$TMP_DIR/projects/Beta"
mkdir -p "$OTHER_PROJECT/tracking/memory"
cp "$PROJECT/tracking/memory/profile-v1.yaml" "$OTHER_PROJECT/tracking/memory/profile-v1.yaml"
if "$MEMORYCTL" profile-check --project "$OTHER_PROJECT" >"$TMP_DIR/copied-profile.out" 2>&1; then
  fail 'copied profile enabled cross-project namespace reuse'
fi
grep -Fq 'not bound to this canonical Project' "$TMP_DIR/copied-profile.out" || fail 'copied-profile rejection is unclear'

echo 'PASS: memory v1 smoke'
