#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-worker-request-v1.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT="$TMP_DIR/projects/Alpha"
RUN_DIR="$TMP_DIR/state/run-1"
WORKERS="$RUN_DIR/workers"
FAKE_CODEX="$TMP_DIR/fake-codex"
REQUEST="$WORKERS/request-step-1.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$PROJECT" "$WORKERS"
printf '%s\n' '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'task_b64="$(printf %s "Review the bounded input." | base64 | tr -d "\n")"' \
  'printf "%s\n" "schema_version: 1" "request_id: REQ-CHANNEL-001" "primary_run_id: ${SDLC_EXECUTION_RUN_ID}" "supervisor_agent: s1-pm" "worker_agent: s1-pm" "kind: review" "task_b64: ${task_b64}" "response_format: markdown" >"${SDLC_WORKER_REQUEST_OUT}"' \
  'printf "%s\n" "primary completed"' >"$FAKE_CODEX"
chmod +x "$FAKE_CODEX"

SDLC_EXECUTION_RUN_DIR="$RUN_DIR" \
SDLC_EXECUTION_RUN_ID=run-1 \
AGENT_RUNTIME=codex \
CODEX_BIN="$FAKE_CODEX" \
SDLC_SUBAGENTS=auto \
SDLC_SUBAGENT_MAX=2 \
SDLC_SUBAGENT_TASKS=review \
  "$ROOT/_runtimes/agent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --project-dir "$PROJECT" \
    --mode task \
    --access write \
    --worker-request-out "$REQUEST" \
    --prompt 'worker request channel smoke' >"$TMP_DIR/run.out"

[[ -f "$REQUEST" && ! -L "$REQUEST" ]] || fail 'validated Worker Request was not published'
[[ "$(stat -c '%a' "$REQUEST")" == 600 ]] || fail 'published Worker Request permissions are not 0600'
grep -Fq 'request_id: REQ-CHANNEL-001' "$REQUEST" || fail 'published Worker Request changed identity'
grep -Fq 'kind: review' "$REQUEST" || fail 'published Worker Request changed kind'
grep -Eq 'WORKER REQUEST READY: .*sha256=[0-9a-f]{64}' "$TMP_DIR/run.out" || fail 'publication receipt is missing'
[[ ! -e "$PROJECT/worker-request.yaml" ]] || fail 'Worker Request escaped into Project'

echo 'PASS: worker request channel smoke'
