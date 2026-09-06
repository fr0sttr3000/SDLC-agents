#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-workers-v1.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

RUNNER="$ROOT/_runtimes/subagent-run.sh"
PROJECT="$TMP_DIR/projects/Alpha"
RUN_DIR="$TMP_DIR/state/run-1"
FAKE_CODEX="$TMP_DIR/fake-codex"

fail() { echo "FAIL: $*" >&2; exit 1; }

required_files=("$ROOT/_contract/WORKER_HANDOFF_V1.md" "$RUNNER")
for required in "${required_files[@]}"; do
  [[ -f "$required" ]] || fail "missing worker contract/runtime: $required"
done

mkdir -p "$PROJECT/stage1-planning/inputs" "$PROJECT/stage1-planning/outputs" "$RUN_DIR/workers"
printf '%s\n' 'allowed input' >"$PROJECT/stage1-planning/inputs/idea.md"
printf '%s\n' 'FORBIDDEN-CANARY' >"$PROJECT/stage1-planning/outputs/private.md"

request="$RUN_DIR/workers/request-step-1.yaml"
task_b64="$(printf '%s' 'Review the allowed project input.' | base64 | tr -d '\n')"
printf '%s\n' 'schema_version: 1' 'request_id: WORKER-REQ-001' 'primary_run_id: run-1' 'supervisor_agent: s1-pm' 'worker_agent: s1-pm' 'kind: review' "task_b64: $task_b64" 'response_format: markdown' >"$request"
request_sha="$(sha256sum "$request" | awk '{print $1}')"

scope="$RUN_DIR/workers/read-scope-step-1.tsv"
printf '%s\n' $'schema_version\tpath' $'1\tstage1-planning/inputs/idea.md' >"$scope"
scope_sha="$(sha256sum "$scope" | awk '{print $1}')"

authorization="$RUN_DIR/workers/authorization-step-1.tsv"
route_sha="$(printf '%s' 'codex|||||' | sha256sum | awk '{print $1}')"
printf '%s\n' $'schema_version\trequest_sha256\tread_scope_sha256\troute_sha256' >"$authorization"
printf '1\t%s\t%s\t%s\n' "$request_sha" "$scope_sha" "$route_sha" >>"$authorization"
authorization_sha="$(sha256sum "$authorization" | awk '{print $1}')"

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'if cat stage1-planning/outputs/private.md >/dev/null 2>&1; then echo FORBIDDEN-CANARY; fi' 'if printf write-escape >stage1-planning/inputs/worker-write.md 2>/dev/null; then echo WRITE-ESCAPE; fi' "printf 'Worker saw: '" 'cat stage1-planning/inputs/idea.md' >"$FAKE_CODEX"
chmod +x "$FAKE_CODEX"

result="$RUN_DIR/workers/result-step-1.yaml"
SDLC_EXECUTION_RUN_DIR="$RUN_DIR" AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=cross-runtime SDLC_SUBAGENT_MAX=2 SDLC_SUBAGENT_TASKS=review "$RUNNER" --runtime codex --agent-dir "$ROOT/cycle1-dev/s1-pm" --project-dir "$PROJECT" --request-file "$request" --request-sha256 "$request_sha" --read-scope-file "$scope" --read-scope-sha256 "$scope_sha" --authorization-file "$authorization" --authorization-sha256 "$authorization_sha" --result-file "$result" >"$TMP_DIR/worker.out" || fail 'authorized worker failed'

[[ -f "$result" ]] || fail 'worker result file missing'
grep -Fq 'request_sha256:' "$result" || fail 'worker result is not request-bound'
grep -Fq 'output_sha256:' "$result" || fail 'worker result lacks output digest'
decoded="$(awk -F': ' '$1 == "output_b64" {print $2}' "$result" | base64 -d)"
[[ "$decoded" == *'Worker saw: allowed input'* ]] || fail 'worker did not read allowed input'
[[ "$decoded" != *'FORBIDDEN-CANARY'* ]] || fail 'worker read outside exact scope'
[[ "$decoded" != *'WRITE-ESCAPE'* ]] || fail 'worker wrote to Project'
[[ ! -e "$PROJECT/stage1-planning/inputs/worker-write.md" ]] || fail 'worker write persisted'

if SDLC_EXECUTION_RUN_DIR="$RUN_DIR" AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" "$RUNNER" --runtime codex --agent-dir "$ROOT/cycle1-dev/s1-pm" --project-dir "$PROJECT" --request-file "$request" --request-sha256 "$request_sha" --read-scope-file "$scope" --read-scope-sha256 "$scope_sha" --result-file "$TMP_DIR/direct.yaml" >"$TMP_DIR/direct.out" 2>&1; then
  fail 'direct worker invocation bypassed launcher authorization'
fi
grep -Fq 'authorization' "$TMP_DIR/direct.out" || fail 'direct worker rejection is unclear'

echo 'PASS: supervisor worker subagents smoke'
