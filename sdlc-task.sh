#!/usr/bin/env bash
# Non-vendor-specific entry point for explicit memory and worker handoffs.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  cat >&2 <<'USAGE'
usage:
  sdlc-task.sh memory <status|configure|disable|profile-check|doctor|proposal-check|apply|snapshot> [options]
  sdlc-task.sh worker [subagent-run.sh options]

This CLI is the same from a terminal, Codex, Claude Code, Gemini CLI or an outer ChatGPT/Codex UI.
USAGE
  exit 2
}

case "${1:-}" in
  memory)
    shift
    [[ $# -gt 0 ]] || usage
    exec "$ROOT/_runtimes/memory/memoryctl.sh" "$@"
    ;;
  worker)
    shift
    [[ $# -gt 0 ]] || usage
    exec "$ROOT/_runtimes/subagent-run.sh" "$@"
    ;;
  -h|--help|help) usage ;;
  *) usage ;;
esac
