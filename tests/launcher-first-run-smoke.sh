#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-first-run-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

XDG_CONFIG_HOME="$TMP_DIR/config-home" \
AGENT_RUNTIME=codex \
CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING= \
SDLC_SUBAGENTS= \
SDLC_SUBAGENT_MAX= \
  bash -c '
    set -euo pipefail
    source "$1"

    is_first_run
    initialize_first_run_execution_policy

    [[ "$SDLC_RUNTIME_ROUTING" == "single" ]]
    [[ "$SDLC_SUBAGENTS" == "off" ]]
    [[ "$SDLC_SUBAGENT_MAX" == "2" ]]
    [[ "$(read_config_value SDLC_RUNTIME_ROUTING)" == "single" ]]
    [[ "$(read_config_value SDLC_SUBAGENTS)" == "off" ]]
    [[ "$(read_config_value SDLC_SUBAGENT_MAX)" == "2" ]]

    output="$(
      render_first_run_step 1 "Runtime"
      render_first_run_step 2 "Projects"
      render_first_run_step 3 "View"
    )"
    [[ "$output" == *"Что сейчас произойдёт"* ]]
    [[ "$output" == *"Настройка ничего не запускает"* ]]
    [[ "$output" == *"ПЕРВЫЙ ЗАПУСК · ШАГ 1 ИЗ 3"* ]]
    [[ "$output" == *"ПЕРВЫЙ ЗАПУСК · ШАГ 2 ИЗ 3"* ]]
    [[ "$output" == *"ПЕРВЫЙ ЗАПУСК · ШАГ 3 ИЗ 3"* ]]
    [[ "$output" == *"Зачем:"* ]]
    [[ "$output" == *"Что изменится:"* ]]
    [[ "$output" == *"Что дальше:"* ]]
  ' _ "$ROOT/sdlc.sh" || fail "clean config did not initialize the three-step first run"

XDG_CONFIG_HOME="$TMP_DIR/explicit-config-home" \
AGENT_RUNTIME=codex \
CODEX_BIN=/bin/true \
SDLC_RUNTIME_ROUTING=per-agent \
SDLC_SUBAGENTS=off \
SDLC_SUBAGENT_MAX=4 \
  bash -c '
    set -euo pipefail
    source "$1"
    initialize_first_run_execution_policy
    [[ "$SDLC_RUNTIME_ROUTING" == "per-agent" ]]
    [[ "$SDLC_SUBAGENTS" == "off" ]]
    [[ "$SDLC_SUBAGENT_MAX" == "4" ]]
  ' _ "$ROOT/sdlc.sh" || fail "explicit execution settings were overwritten"

if ! XDG_CONFIG_HOME="$TMP_DIR/worker-config-home" \
  AGENT_RUNTIME=codex CODEX_BIN=/bin/true SDLC_RUNTIME_ROUTING=single \
  SDLC_SUBAGENTS=auto SDLC_SUBAGENT_MAX=2 \
  bash -c 'source "$1"; initialize_first_run_execution_policy' _ "$ROOT/sdlc.sh" \
  >"$TMP_DIR/workers-auto.out" 2>&1; then
  fail 'first run rejected bounded auto worker policy'
fi

echo "PASS: launcher first-run smoke"
