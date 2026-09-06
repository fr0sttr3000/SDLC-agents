#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUNNER="$ROOT/_runtimes/agent-run.sh"
WORKER_RUNNER="$ROOT/_runtimes/subagent-run.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-stage0a-runtime.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT_ONE="$TMP_DIR/projects/Alpha"
PROJECT_TWO="$TMP_DIR/projects/Beta"
NOTES_ONE="$TMP_DIR/notes/Alpha"
AMBIENT_HOME="$TMP_DIR/ambient-home"
AMBIENT_HOME_ALIAS="$TMP_DIR/ambient-home-alias"
mkdir -p "$PROJECT_ONE" "$PROJECT_TWO" "$NOTES_ONE" "$AMBIENT_HOME"
ln -s "$AMBIENT_HOME" "$AMBIENT_HOME_ALIAS"
CODEX_ONE_CAPTURE="$PROJECT_ONE/.fake-codex.capture"
CODEX_TWO_CAPTURE="$PROJECT_TWO/.fake-codex.capture"
CLAUDE_ONE_CAPTURE="$PROJECT_ONE/.fake-claude.capture"

failures=0

record_failure() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_contains_file() {
  local file="$1" expected="$2" label="$3"
  grep -Fq -- "$expected" "$file" ||
    record_failure "$label: output does not contain '$expected'"
}

assert_not_contains_file() {
  local file="$1" unexpected="$2" label="$3"
  if grep -Fq -- "$unexpected" "$file"; then
    record_failure "$label: output unexpectedly contains '$unexpected'"
  fi
}

assert_arg_pair() {
  local file="$1" flag="$2" value="$3" label="$4"
  if ! awk -v first="ARG=$flag" -v second="ARG=$value" '
    previous == first && $0 == second { found = 1 }
    { previous = $0 }
    END { exit(found ? 0 : 1) }
  ' "$file"; then
    record_failure "$label: missing adjacent arguments '$flag' '$value'"
  fi
}

assert_no_arg_pair() {
  local file="$1" flag="$2" value="$3" label="$4"
  if awk -v first="ARG=$flag" -v second="ARG=$value" '
    previous == first && $0 == second { found = 1 }
    { previous = $0 }
    END { exit(found ? 0 : 1) }
  ' "$file"; then
    record_failure "$label: forbidden adjacent arguments '$flag' '$value'"
  fi
}

check_rejected() {
  local label="$1" output="$2" expected="$3"
  shift 3
  if "$@" >"$output" 2>&1; then
    record_failure "$label: command succeeded"
    return
  fi
  assert_contains_file "$output" "$expected" "$label"
}

check_accepted() {
  local label="$1" output="$2"
  shift 2
  if ! "$@" >"$output" 2>&1; then
    record_failure "$label: command was rejected"
  fi
}

FAKE_CODEX="$TMP_DIR/fake-codex"
cat > "$FAKE_CODEX" <<'FAKE'
#!/usr/bin/env bash
capture_file="$SDLC_PROJECT_DIR/.fake-codex.capture"
{
  printf 'CALL\n'
  printf 'ARG=%s\n' "$@"
  printf 'SECRET=%s\n' "${TOP_SECRET_SENTINEL:-absent}"
  printf 'NESTING=%s\n' "${CODEX_THREAD_ID:-absent}"
  printf 'VAULT=%s\n' "${SDLC_VAULT:-absent}"
  printf 'PROJECTS=%s\n' "${SDLC_PROJECTS_DIR:-absent}"
  printf 'PROJECT_DIR=%s\n' "${SDLC_PROJECT_DIR:-absent}"
} > "$capture_file"
FAKE
chmod +x "$FAKE_CODEX"

FAKE_CLAUDE="$TMP_DIR/fake-claude"
cat > "$FAKE_CLAUDE" <<'FAKE'
#!/usr/bin/env bash
capture_file="$SDLC_PROJECT_DIR/.fake-claude.capture"
{
  printf 'CALL\n'
  printf 'ARG=%s\n' "$@"
  printf 'SECRET=%s\n' "${TOP_SECRET_SENTINEL:-absent}"
  printf 'SESSION=%s\n' "${CLAUDE_CODE_SESSION_ID:-absent}"
  printf 'VAULT=%s\n' "${SDLC_VAULT:-absent}"
  printf 'PROJECTS=%s\n' "${SDLC_PROJECTS_DIR:-absent}"
  printf 'PROJECT_DIR=%s\n' "${SDLC_PROJECT_DIR:-absent}"
} >> "$capture_file"
FAKE
chmod +x "$FAKE_CLAUDE"

ACTIVE_AGENT="$ROOT/cycle1-dev/s1-pm"
ACTIVE_TOOL="$ROOT/_tools/s0-secrets"
FROZEN_CYCLE2="$ROOT/cycle2-deploy/s4-devops"
FROZEN_CYCLE3="$ROOT/cycle3-ops/s6-sre"

check_accepted 'active Cycle 1 agent' "$TMP_DIR/active-agent.out" \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_accepted 'active utility agent' "$TMP_DIR/active-tool.out" \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_TOOL" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_rejected 'direct Cycle 2 dispatch' "$TMP_DIR/frozen-cycle2.out" 'FROZEN / NOT READY' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$FROZEN_CYCLE2" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_rejected 'direct Cycle 3 dispatch' "$TMP_DIR/frozen-cycle3.out" 'FROZEN / NOT READY' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$FROZEN_CYCLE3" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_rejected 'path traversal to Cycle 2' "$TMP_DIR/frozen-traversal.out" 'FROZEN / NOT READY' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ROOT/cycle1-dev/../cycle2-deploy/s4-devops" \
  --project-dir "$PROJECT_ONE" --mode task --access write --prompt smoke

ln -s "$FROZEN_CYCLE3" "$TMP_DIR/frozen-agent-link"
check_rejected 'symlink to Cycle 3' "$TMP_DIR/frozen-symlink.out" 'FROZEN / NOT READY' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$TMP_DIR/frozen-agent-link" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_rejected 'missing project write scope' "$TMP_DIR/missing-project.out" \
  '--project-dir is required' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --mode task --access write --prompt smoke

check_rejected 'filesystem root used as project scope' "$TMP_DIR/root-project.out" \
  'must be a bounded directory, not filesystem root or HOME' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir / \
  --mode task --access write --prompt smoke

check_rejected 'canonical HOME alias used as project scope' "$TMP_DIR/home-alias-project.out" \
  'must be a bounded directory, not filesystem root or HOME' \
  env HOME="$AMBIENT_HOME_ALIAS" AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" \
  SDLC_SUBAGENTS=off "$RUNNER" --agent-dir "$ACTIVE_AGENT" \
  --project-dir "$AMBIENT_HOME" --mode task --access write --prompt smoke

check_rejected 'agent system used as project write scope' "$TMP_DIR/system-project.out" \
  'must be outside the SDLC agent system' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$ACTIVE_AGENT" \
  --mode task --access write --prompt smoke

check_rejected 'missing notes write scope' "$TMP_DIR/missing-notes.out" \
  '--notes-dir must point to an existing directory' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --notes-dir "$TMP_DIR/notes/does-not-exist" --mode task --access write --prompt smoke

rm -f "$CODEX_ONE_CAPTURE"
check_accepted 'Codex exact scopes for project Alpha' "$TMP_DIR/codex-alpha.out" \
  env TOP_SECRET_SENTINEL=must-not-reach-runtime CODEX_THREAD_ID=must-not-reach-runtime \
  AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --notes-dir "$NOTES_ONE" --mode task --access write --prompt smoke

CODEX_CAPTURE="$CODEX_ONE_CAPTURE"
if [[ ! -f "$CODEX_CAPTURE" ]]; then
  record_failure 'Codex exact scopes: fake runtime was not invoked'
else
  assert_arg_pair "$CODEX_CAPTURE" '--sandbox' 'workspace-write' 'Codex write sandbox'
  assert_contains_file "$CODEX_CAPTURE" 'ARG=--ephemeral' 'Codex task session isolation'
  assert_contains_file "$CODEX_CAPTURE" 'ARG=--ignore-user-config' 'Codex ambient user config isolation'
  assert_arg_pair "$CODEX_CAPTURE" '--cd' "$PROJECT_ONE" 'Codex project scope'
  assert_arg_pair "$CODEX_CAPTURE" '--add-dir' "$NOTES_ONE" 'Codex notes scope'
  assert_no_arg_pair "$CODEX_CAPTURE" '--cd' "$ACTIVE_AGENT" 'Codex agent directory isolation'
  assert_contains_file "$CODEX_CAPTURE" 'SECRET=absent' 'Codex secret env isolation'
  assert_contains_file "$CODEX_CAPTURE" 'NESTING=absent' 'Codex nesting env isolation'
  assert_contains_file "$CODEX_CAPTURE" "VAULT=$(dirname "$ROOT")" "Codex canonical vault"
  assert_contains_file "$CODEX_CAPTURE" "PROJECTS=$TMP_DIR/projects" "Codex canonical projects parent"
  assert_contains_file "$CODEX_CAPTURE" "PROJECT_DIR=$PROJECT_ONE" "Codex exact project"
fi

rm -f "$CODEX_TWO_CAPTURE"
check_accepted 'Codex exact scope for project Beta' "$TMP_DIR/codex-beta.out" \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_TWO" \
  --mode task --access write --prompt smoke
if [[ -f "$CODEX_TWO_CAPTURE" ]]; then
  assert_arg_pair "$CODEX_TWO_CAPTURE" '--sandbox' 'workspace-write' 'Codex second write sandbox'
  assert_contains_file "$CODEX_TWO_CAPTURE" 'ARG=--ephemeral' 'Codex second task session isolation'
  assert_arg_pair "$CODEX_TWO_CAPTURE" '--cd' "$PROJECT_TWO" 'Codex second project scope'
  assert_not_contains_file "$CODEX_TWO_CAPTURE" "ARG=$PROJECT_ONE" 'Codex cross-project isolation'
  assert_not_contains_file "$CODEX_TWO_CAPTURE" "ARG=$NOTES_ONE" 'Codex stale notes isolation'
else
  record_failure 'Codex second project scope: fake runtime was not invoked'
fi

rm -f "$CODEX_ONE_CAPTURE"
check_rejected 'Codex interactive ambient-config isolation' "$TMP_DIR/codex-interactive.out" \
  'BLOCKED: interactive Codex cannot disable ambient user configuration' \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --mode interactive --access write --prompt smoke
[[ ! -e "$CODEX_ONE_CAPTURE" ]] ||
  record_failure 'Codex interactive ambient-config isolation: fake runtime was invoked'

rm -f "$CLAUDE_ONE_CAPTURE"
check_accepted 'Claude isolated interactive launch' "$TMP_DIR/claude-interactive.out" \
  env TOP_SECRET_SENTINEL=must-not-reach-runtime CLAUDE_CODE_SESSION_ID=must-not-reach-runtime \
  AGENT_RUNTIME=claude CLAUDE_BIN="$FAKE_CLAUDE" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --mode interactive --access write --prompt smoke
if [[ -f "$CLAUDE_ONE_CAPTURE" ]]; then
  call_count="$(grep -Fc 'CALL' "$CLAUDE_ONE_CAPTURE")"
  [[ "$call_count" == 1 ]] ||
    record_failure "Claude interactive isolation: expected one runtime call, got $call_count"
  assert_not_contains_file "$CLAUDE_ONE_CAPTURE" 'ARG=--continue' 'Claude interactive isolation'
  assert_contains_file "$CLAUDE_ONE_CAPTURE" 'SECRET=absent' 'Claude secret env isolation'
  assert_contains_file "$CLAUDE_ONE_CAPTURE" 'SESSION=absent' 'Claude session env isolation'
  assert_contains_file "$CLAUDE_ONE_CAPTURE" "VAULT=$(dirname "$ROOT")" "Claude canonical vault"
  assert_contains_file "$CLAUDE_ONE_CAPTURE" "PROJECTS=$TMP_DIR/projects" "Claude canonical projects parent"
  assert_contains_file "$CLAUDE_ONE_CAPTURE" "PROJECT_DIR=$PROJECT_ONE" "Claude exact project"
else
  record_failure 'Claude interactive isolation: fake runtime was not invoked'
fi

check_rejected 'unbound continue mode' "$TMP_DIR/continue.out" 'unbound continue is disabled' \
  env AGENT_RUNTIME=claude CLAUDE_BIN="$FAKE_CLAUDE" SDLC_SUBAGENTS=off \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --mode continue --access write --prompt smoke

check_accepted 'automatic worker policy on primary' "$TMP_DIR/workers-auto.out" \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=auto \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_accepted 'cross-runtime worker policy on primary' "$TMP_DIR/workers-cross.out" \
  env AGENT_RUNTIME=codex CODEX_BIN="$FAKE_CODEX" SDLC_SUBAGENTS=cross-runtime \
  SDLC_SUBAGENT_PROFILE='codex||||' SDLC_SUBAGENT_TASKS=analysis \
  "$RUNNER" --agent-dir "$ACTIVE_AGENT" --project-dir "$PROJECT_ONE" \
  --mode task --access write --prompt smoke

check_rejected 'direct active worker invocation' "$TMP_DIR/worker-active.out" \
  'unknown argument' \
  env SDLC_PROJECTS_DIR="$TMP_DIR/projects" SDLC_SUBAGENT_PROFILE='codex||||' \
  SDLC_SUBAGENT_TASKS=analysis CODEX_BIN="$FAKE_CODEX" \
  "$WORKER_RUNNER" --agent-dir "$ACTIVE_AGENT" --kind analysis --task inspect \
  --read-scope "$PROJECT_ONE" --response-format Markdown

check_rejected 'direct frozen worker target' "$TMP_DIR/worker-frozen.out" \
  'unknown argument' \
  env SDLC_PROJECTS_DIR="$TMP_DIR/projects" SDLC_SUBAGENT_PROFILE='codex||||' \
  SDLC_SUBAGENT_TASKS=analysis CODEX_BIN="$FAKE_CODEX" \
  "$WORKER_RUNNER" --agent-dir "$FROZEN_CYCLE2" --kind analysis --task inspect \
  --read-scope "$PROJECT_ONE" --response-format Markdown

if (( failures > 0 )); then
  echo "RED: Stage 0A runtime boundary has $failures unmet contract(s)" >&2
  exit 1
fi

echo 'PASS: Stage 0A runtime boundary smoke'
