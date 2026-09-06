#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-contract-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT_DIR="$TMP_DIR/project"
mkdir -p "$PROJECT_DIR"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$ROOT/$1" ]] || fail "missing file: $1"
}

assert_contains() {
  local file="$1" text="$2"
  grep -Fq -- "$text" "$ROOT/$file" || fail "$file does not contain: $text"
}

assert_order() {
  local file="$1" first="$2" second="$3" first_line second_line
  first_line="$(grep -nF -- "$first" "$ROOT/$file" | head -1 | cut -d: -f1)"
  second_line="$(grep -nF -- "$second" "$ROOT/$file" | head -1 | cut -d: -f1)"
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] || \
    fail "$file order violation: '$first' must be before '$second'"
}

assert_file "_standards/tdd.md"
assert_file "_standards/artifact-metadata.md"
assert_file "_contract/SUBAGENTS.md"
assert_file "_contract/WORKER_HANDOFF_V1.md"
assert_file "_contract/MEMORY_V1.md"
assert_file "_contract/MEMORY_USER_GUIDE.md"
assert_file "_contract/memory-role-access-v1.tsv"
assert_file "_contract/memory-command-access-v1.tsv"

while IFS= read -r -d '' canonical; do
  agent_dir="${canonical%/CLAUDE.md}"
  for adapter in AGENTS.md GEMINI.md; do
    [[ -L "$agent_dir/$adapter" ]] ||
      fail "${agent_dir#"$ROOT/"}: $adapter is not a canonical symlink"
    [[ "$(readlink "$agent_dir/$adapter")" == 'CLAUDE.md' ]] ||
      fail "${agent_dir#"$ROOT/"}: $adapter does not point to CLAUDE.md"
  done
done < <(find "$ROOT/cycle1-dev" "$ROOT/cycle2-deploy" "$ROOT/cycle3-ops" "$ROOT/_tools" \
  -mindepth 2 -maxdepth 2 -name CLAUDE.md -type f -print0)
assert_file "_runtimes/adapters/local.md"
assert_file "_runtimes/local-hosts/codex-oss"
assert_file "_runtimes/local-hosts/openai-api"
assert_file "_runtimes/memory/memoryctl.sh"
assert_file "sdlc-task.sh"
assert_file "tests/codex-app-launcher-compat-smoke.sh"
assert_file "_runtimes/subagent-run.sh"
assert_file "_runtimes/runtime-boundary.sh"
assert_file "_runtimes/cycle-landlock.c"
assert_file "tests/cycle-agent-read-boundary-smoke.sh"
assert_file "cycle1-dev/s2-test-strategy/CLAUDE.md"
assert_file "cycle1-dev/s4-qa-auto/CLAUDE.md"
assert_file "cycle1-dev/s4-qa-auto/.claude/commands/write-tests.md"
assert_file "cycle1-dev/s4-qa-auto/.claude/commands/run-tests.md"
assert_file "_contract/S5_VALIDATION_V1.md"
assert_file "_contract/RISK_EXCEPTION_V3.md"
assert_file "_contract/quality-policy-v1.tsv"
assert_file "_contract/QUALITY_METRIC_EVIDENCE_V1.md"
assert_file "cycle1-dev/s0-validate/s5-validation-check.sh"
assert_file "_contract/CYCLE1_COMPLETION_V1.md"
assert_file "_contract/CYCLE1_COMPLETION_V2.md"
assert_file "_contract/COMMAND_CAPABILITIES_V1.md"
assert_file "_contract/command-capabilities-v1.tsv"
assert_file "_contract/CHANGE_SCOPE_V1.md"
assert_file "cycle1-dev/s0-validate/change-scope-v1.sh"
assert_file "cycle1-dev/l1-analyze/.claude/commands/impact.md"
assert_file "cycle1-dev/s3-arch/.claude/commands/change-impact.md"
assert_file "_contract/cycle1-steps-v1.tsv"
assert_file "cycle1-dev/s0-validate/cycle1-completion-check.sh"
assert_file "cycle1-dev/s0-validate/structure-check.sh"
assert_file "cycle1-dev/s0-validate/legacy-migration-report.sh"

assert_contains "sdlc.sh" 'CYCLE1_STEPS_FILE'
assert_contains "_contract/cycle1-steps-v1.tsv" $'11\ts2-test-strategy\t/strategy'
assert_contains "_contract/cycle1-steps-v1.tsv" $'18\ts3-dba\t/migration'
assert_contains "_contract/cycle1-steps-v1.tsv" $'19\ts4-qa-auto\t/write-tests'
assert_contains "_contract/cycle1-steps-v1.tsv" $'21\ts4-qa-auto\t/run-tests'
assert_contains "sdlc.sh" "run_tdd_repair_loop"
assert_contains "_contract/current-artifact-groups-v1.tsv" "tracking/validation/S5-validation-v1.tsv"
assert_contains "cycle1-dev/s0-validate/cycle1-completion-check.sh" "tracking/validation/S5-validation-v1.tsv"
assert_contains "sdlc.sh" "cycle1_completion_after_entry"
assert_contains "sdlc.sh" "SDLC_RUNTIME_ROUTING"
assert_contains "sdlc.sh" "resolve_step_runtime"
assert_contains "sdlc.sh" "LOCAL_AGENT_HOST"
assert_contains "sdlc.sh" 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]'
assert_contains "localrun.sh" "LOCAL_AGENT_HOST"
assert_contains "localrun.sh" "resolve_step_runtime"
assert_contains "localrun.sh" "SDLC_SUBAGENTS"
assert_contains "localrun.sh" 'SDLC_SUBAGENT_PROFILE=""'
assert_contains "localrun.sh" 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]'
assert_order "_contract/cycle1-steps-v1.tsv" $'s4-qa-auto\t/write-tests' $'s4-dev\t/dev-report'
assert_order "_contract/cycle1-steps-v1.tsv" $'s4-dev\t/dev-report' $'s4-qa-auto\t/run-tests'
assert_order "_contract/cycle1-steps-v1.tsv" $'s3-dba\t/migration' $'s4-qa-auto\t/write-tests'
bash -c 'source "$1"; [[ "${#CYCLE1_AGENTS[@]}" -eq 28 ]]' _ "$ROOT/sdlc.sh" || fail "Cycle 1 must contain exactly 28 mandatory steps"

assert_contains "cycle1-dev/s0-kickoff/CLAUDE.md" "Cycle 2/3 delivery/operations tooling не собирается"
assert_contains "cycle1-dev/s0-kickoff/CLAUDE.md" "Reliability / observability NFR Cycle 1"
assert_contains "_standards/quality.md" "Alert Deduplication"
assert_contains "cycle1-dev/s0-validate/dod-check.sh" "N/A для active Cycle 1"
assert_contains "cycle1-dev/s0-validate/CLAUDE.md" "сообщает N/A в active Cycle 1"
assert_contains "cycle2-deploy/s4-devops/CLAUDE.md" "dedup_key"
assert_contains "cycle2-deploy/s4-devops/CLAUDE.md" "idempotency test (Red)"
assert_contains "cycle3-ops/s6-sre/CLAUDE.md" "один incident/notification"
assert_contains "cycle3-ops/s6-sre/CLAUDE.md" "failure-injection scenario (Red)"

# Active documentation must describe the implemented baseline, not the previous one.
assert_contains "CLAUDE.md" "28 обязательных шагов"
assert_contains "README.md" "Cycle 2/3 сохранены как historical code"
assert_contains "README.md" "./sdlc.ps1"
assert_contains "README.md" "AGENT_RUNTIME=local"
assert_contains "README.md" "28 обязательных шагов"
assert_contains "OVERVIEW.md" "28 обязательных шагов"
assert_contains "plans/roadmap.md" "## Delivered baseline"
assert_contains "plans/principles.md" "### Явное и fail-closed исполнение"
assert_contains "plans/principles.md" "### Test-driven development"
assert_contains "plans/principles.md" "### Границы изменения предшествуют реализации"
assert_contains "README.md" "u → Change Scope"
assert_contains "OVERVIEW.md" 'Stage 4 mutators используют `scoped-write`'
assert_contains "CLAUDE.md" "fail-closed"
assert_contains "_contract/SUBAGENTS.md" "BLOCKED"
assert_contains "_contract/EXECUTION_JOURNAL.md" "worker"
assert_contains "plans/principles.md" "### Ответственный primary и ограниченные помощники"
assert_contains "CLAUDE.md" "Landlock"
assert_contains "_contract/GLOBAL.md" "runtime-denied"
assert_contains "_runtimes/adapters/codex.md" "Landlock"
assert_contains "plans/roadmap.md" "## Later / Decision gates"
assert_contains "_contract/README.md" "_runtimes/adapters/local.md"
assert_contains "CLAUDE.md" "_standards/artifact-metadata.md"
assert_contains "_contract/S5_VALIDATION_V1.md" "artifact-metadata-check.sh"

mkdir -p "$PROJECT_DIR/.test-bin"
FAKE_CODEX="$PROJECT_DIR/.test-bin/fake-codex"
cat > "$FAKE_CODEX" <<'FAKE'
#!/usr/bin/env bash
{
  printf 'ARG=%s\n' "$@"
  printf 'SUBAGENTS=%s\n' "${SDLC_SUBAGENTS:-}"
  printf 'SUBAGENT_MAX=%s\n' "${SDLC_SUBAGENT_MAX:-}"
} > "${0}.capture"
FAKE
chmod +x "$FAKE_CODEX"
CAPTURE="$FAKE_CODEX.capture"

AGENT_RUNTIME=local \
LOCAL_AGENT_HOST=codex-oss \
LOCAL_MODEL_PROVIDER=ollama \
LOCAL_MODEL=test-model:latest \
LOCAL_CODEX_BIN="$FAKE_CODEX" \
SDLC_SUBAGENTS=off \
SDLC_SUBAGENT_MAX=2 \
  "$ROOT/_runtimes/agent-run.sh" \
    --agent-dir "$ROOT/cycle1-dev/s1-pm" \
    --project-dir "$PROJECT_DIR" \
    --mode task \
    --prompt "contract smoke"

grep -Fq 'ARG=--oss' "$CAPTURE" || fail "local runtime did not pass --oss"
grep -Fq 'ARG=--local-provider' "$CAPTURE" || fail "local runtime did not pass provider flag"
grep -Fq 'ARG=ollama' "$CAPTURE" || fail "local runtime did not pass ollama provider"
grep -Fq 'ARG=-m' "$CAPTURE" || fail "local runtime did not pass model flag"
grep -Fq 'ARG=test-model:latest' "$CAPTURE" || fail "local runtime did not pass exact model"
grep -Fq 'ARG=--ephemeral' "$CAPTURE" || fail "local Codex task did not isolate session state"
grep -Fq 'ARG=--ignore-user-config' "$CAPTURE" || fail "local Codex task inherited ambient user config"
grep -Fq 'SUBAGENTS=off' "$CAPTURE" || fail "fail-closed worker mode not propagated"
grep -Fq 'SUBAGENT_MAX=2' "$CAPTURE" || fail "subagent max not propagated"
grep -Fq "ARG=$PROJECT_DIR" "$CAPTURE" || fail "local runtime did not receive exact project scope"

if AGENT_RUNTIME=local LOCAL_AGENT_HOST=codex-oss LOCAL_MODEL_PROVIDER=ollama LOCAL_CODEX_BIN="$FAKE_CODEX" \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" --mode task --prompt smoke \
  --project-dir "$PROJECT_DIR" \
  >"$TMP_DIR/missing-model.out" 2>&1; then
  fail "local runtime accepted an empty LOCAL_MODEL"
fi

if AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_SUBAGENTS=auto SDLC_SUBAGENT_MAX=08 \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
  --project-dir "$PROJECT_DIR" --mode task --prompt smoke >"$TMP_DIR/invalid-worker-max.out" 2>&1; then
  fail "runtime accepted a non-canonical worker max with a leading zero"
fi
grep -Fq 'must be an integer from 1 to 16' "$TMP_DIR/invalid-worker-max.out" ||
  fail 'invalid worker max did not return a controlled validation error'

if AGENT_RUNTIME=local LOCAL_MODEL_PROVIDER=ollama LOCAL_MODEL=test-model:latest \
  LOCAL_CODEX_BIN="$FAKE_CODEX" \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
  --project-dir "$PROJECT_DIR" --mode task --prompt smoke \
  >"$TMP_DIR/missing-host.out" 2>&1; then
  fail "local runtime accepted an empty LOCAL_AGENT_HOST"
fi

FAKE_HOST="$PROJECT_DIR/.test-bin/fake-local-host"
CUSTOM_CAPTURE="$FAKE_HOST.capture"
cat > "$FAKE_HOST" <<'FAKE'
#!/usr/bin/env bash
capture="$(readlink -f "$0").capture"
{
  printf 'ARG=%s\n' "$@"
  printf 'PROVIDER=%s\n' "${LOCAL_MODEL_PROVIDER:-}"
  printf 'MODEL=%s\n' "${LOCAL_MODEL:-}"
} > "$capture"
FAKE
chmod +x "$FAKE_HOST"

AGENT_RUNTIME=local \
LOCAL_AGENT_HOST=custom-smoke \
LOCAL_MODEL_PROVIDER=openai-compatible \
LOCAL_MODEL=org/exact-model \
LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
  bash -c '
    mkdir -p "$LOCAL_HOST_REGISTRY"
    ln -s "$1" "$LOCAL_HOST_REGISTRY/custom-smoke"
    exec "$2" --agent-dir "$3" --project-dir "$4" --mode task --prompt "custom adapter smoke"
  ' _ "$FAKE_HOST" "$ROOT/_runtimes/agent-run.sh" "$ROOT/cycle1-dev/s1-pm" "$PROJECT_DIR"

grep -Fq 'PROVIDER=openai-compatible' "$CUSTOM_CAPTURE" || fail "custom host did not receive provider"
grep -Fq 'MODEL=org/exact-model' "$CUSTOM_CAPTURE" || fail "custom host did not receive exact model"

ROUTING_FILE="$TMP_DIR/routing.conf"
cat > "$ROUTING_FILE" <<'ROUTING'
agent:s4-dev=local|openai-compatible|org/exact-model|custom-smoke|http://127.0.0.1:8000/v1
ROUTING

AGENT_RUNTIME=codex \
CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING=per-agent \
SDLC_SUBAGENTS=off \
SDLC_SUBAGENT_MAX=2 \
LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
SDLC_ROUTING_FILE="$ROUTING_FILE" \
  bash -c '
    source "$1"
    BASE_PROFILE="codex||||"
    resolve_step_runtime s4-dev
    [[ "$AGENT_RUNTIME" == "local" ]]
    [[ "$LOCAL_AGENT_HOST" == "custom-smoke" ]]
    [[ "$LOCAL_MODEL_PROVIDER" == "openai-compatible" ]]
    [[ "$LOCAL_MODEL" == "org/exact-model" ]]
  ' _ "$ROOT/sdlc.sh" || fail "per-agent route did not apply the exact local profile"

if AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=per-agent \
  SDLC_SUBAGENTS=off SDLC_SUBAGENT_MAX=2 \
  LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" SDLC_ROUTING_FILE="$ROUTING_FILE" \
  bash -c 'source "$1"; BASE_PROFILE="codex||||"; resolve_step_runtime s3-arch' _ "$ROOT/sdlc.sh" \
  >"$TMP_DIR/missing-route.out" 2>&1; then
  fail "per-agent routing silently fell back when route was missing"
fi

if AGENT_RUNTIME=local LOCAL_AGENT_HOST=not-registered \
  LOCAL_MODEL_PROVIDER=openai-compatible LOCAL_MODEL=org/exact-model \
  LOCAL_HOST_REGISTRY="$TMP_DIR/local-hosts" \
  "$ROOT/_runtimes/agent-run.sh" --agent-dir "$ROOT/cycle1-dev/s1-pm" \
  --project-dir "$PROJECT_DIR" --mode task --prompt smoke \
  >"$TMP_DIR/unregistered-host.out" 2>&1; then
  fail "local runtime accepted an unregistered agent host"
fi

assert_contains "_contract/GLOBAL.md" "single|per-stage|per-agent|ask"
assert_contains "_contract/GLOBAL.md" "silent fallback"
assert_contains "_runtimes/adapters/local.md" "vLLM"
assert_contains "_runtimes/adapters/local.md" "llama.cpp"

bash "$ROOT/tests/tdd-orchestration-smoke.sh"
bash "$ROOT/tests/cycle23-goal-orchestration-smoke.sh"
bash "$ROOT/tests/launcher-ui-navigation-smoke.sh"
bash "$ROOT/tests/launcher-preview-dispatch-smoke.sh"
bash "$ROOT/tests/launcher-runtime-scopes-smoke.sh"
bash "$ROOT/tests/launcher-execution-journal-smoke.sh"
bash "$ROOT/tests/launcher-gate-orchestration-smoke.sh"
bash "$ROOT/tests/local-repositories-ux-smoke.sh"
bash "$ROOT/tests/local-repositories-product-smoke.sh"
bash "$ROOT/tests/launcher-advanced-parity-smoke.sh"
bash "$ROOT/tests/review-repair-journal-smoke.sh"
bash "$ROOT/tests/launcher-first-run-smoke.sh"
bash "$ROOT/tests/memory-v1-smoke.sh"
bash "$ROOT/tests/memory-acl-smoke.sh"
bash "$ROOT/tests/memory-provider-adapters-smoke.sh"
bash "$ROOT/tests/openai-api-host-smoke.sh"
bash "$ROOT/tests/supervisor-worker-subagents-smoke.sh"
bash "$ROOT/tests/worker-request-channel-smoke.sh"
bash "$ROOT/tests/stage0a-runtime-boundary-smoke.sh"
bash "$ROOT/tests/runtime-capability-matrix-smoke.sh"
bash "$ROOT/tests/scoped-write-runtime-smoke.sh"
bash "$ROOT/tests/change-scope-v1-smoke.sh"
bash "$ROOT/tests/secret-boundary-smoke.sh"
bash "$ROOT/tests/cycle-agent-read-boundary-smoke.sh"
bash "$ROOT/tests/windows-launcher-adapter-smoke.sh"
bash "$ROOT/tests/codex-app-launcher-compat-smoke.sh"
bash "$ROOT/tests/gate-validator-behavior-smoke.sh"
bash "$ROOT/tests/qa-requirements-current-artifact-smoke.sh"
bash "$ROOT/tests/active-scope-principles-smoke.sh"
bash "$ROOT/tests/principles-consistency-smoke.sh"
bash "$ROOT/tests/active-links-smoke.sh"
bash "$ROOT/tests/documentation-contract-smoke.sh"
bash "$ROOT/tests/documentation-semantics-smoke.sh"
bash "$ROOT/tests/public-root-inventory-smoke.sh"
bash "$ROOT/tests/gate4-s5-contract-smoke.sh"
bash "$ROOT/tests/data-formats-contract-smoke.sh"
bash "$ROOT/tests/product-ci-profile-smoke.sh"
bash "$ROOT/tests/evidence-v1-smoke.sh"
bash "$ROOT/tests/quality-only-up-smoke.sh"
bash "$ROOT/tests/quality-characteristics-v1-smoke.sh"
bash "$ROOT/tests/sg3-policy-smoke.sh"
bash "$ROOT/tests/pr-evidence-gate-smoke.sh"
bash "$ROOT/tests/product-acceptance-smoke.sh"
bash "$ROOT/tests/ba-requirements-taxonomy-smoke.sh"
bash "$ROOT/tests/architecture-decision-trace-smoke.sh"
bash "$ROOT/tests/runtime-constraints-v1-smoke.sh"
bash "$ROOT/tests/tdd-status-v1-smoke.sh"
bash "$ROOT/tests/artifact-metadata-v1-smoke.sh"
bash "$ROOT/tests/command-capabilities-v1-smoke.sh"
bash "$ROOT/tests/markdown-output-contract-smoke.sh"
bash "$ROOT/tests/collection-structure-dispatch-smoke.sh"
bash "$ROOT/tests/current-artifact-v1-smoke.sh"
bash "$ROOT/tests/human-approval-origin-smoke.sh"
bash "$ROOT/tests/sg1-sg2-validation-smoke.sh"
bash "$ROOT/tests/s5-validation-v1-smoke.sh"
bash "$ROOT/tests/known-issue-lifecycle-smoke.sh"
bash "$ROOT/tests/cycle1-completion-v2-smoke.sh"
bash "$ROOT/tests/task-dod-lifecycle-smoke.sh"
bash "$ROOT/tests/release-notes-utility-smoke.sh"
bash "$ROOT/tests/additive-migration-smoke.sh"
bash "$ROOT/tests/plans-consolidation-smoke.sh"
bash "$ROOT/tests/active-documentation-boundary-smoke.sh"

echo "PASS: system contract smoke"
