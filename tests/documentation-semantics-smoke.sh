#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }
contains() {
  grep -Fq -- "$2" "$ROOT/$1" || fail "$1 does not contain: $2"
}
not_contains() {
  if grep -Fq -- "$2" "$ROOT/$1"; then
    fail "$1 contains stale/forbidden text: $2"
  fi
}

# User-visible isolation is part of the product promise.
contains README.md 'не вызывает другие роли напрямую'
contains README.md 'История chat и скрытая память между ролями не передаются'
contains README.md 'current manifest'
contains README.md 'Поддерживаемый pull выполняется только операторским workflow'
not_contains README.md 'поддерживаемого pull, но VCS control-plane'
contains README.md '[v2.002.000](RELEASE_NOTES_v2.002.000.md)'
not_contains README.md 'Подготовленный platform release: [v2.001.001]'
contains README.md 'один frozen worker profile на execution plan'
contains README.md 'Workers не получают connected-memory snapshots'
contains CHANGELOG.md 'Project-scoped connected memory'
contains CHANGELOG.md 'bounded advisory workers'
contains CHANGELOG.md '## [2.002.000] — 2026-09-01'
contains CHANGELOG.md 'Full primary execution remains launcher-owned through `sdlc.sh`'
contains CHANGELOG.md '[Unreleased]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.002.000...HEAD'
contains CHANGELOG.md '[2.002.000]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.001.001...v2.002.000'
contains RELEASE_NOTES_v2.002.000.md 'status: PREPARED_NOT_PUBLISHED'
contains RELEASE_NOTES_v2.002.000.md 'Primary memory is runtime-independent'
contains RELEASE_NOTES_v2.002.000.md 'Workers do not receive connected-memory snapshots'
contains RELEASE_NOTES_v2.002.000.md 'Per-stage worker-profile routing is not included'
contains CLAUDE.md 'Интерактивный старт — общий'
contains CLAUDE.md 'resolve-compatible[-one]'
contains CLAUDE.md 'без glob fallback'

# The current release utility consumes Completion v2 and uses a generic external-action boundary.
contains cycle1-dev/s0-tracker/.claude/commands/release-notes.md 'CYCLE1_COMPLETION_V2.md'
contains cycle1-dev/s0-tracker/.claude/commands/release-notes.md 'CYCLE1-completion-v2.yaml'
not_contains cycle1-dev/s0-tracker/.claude/commands/release-notes.md 'CYCLE1_COMPLETION_V1.md'
not_contains cycle1-dev/s0-tracker/.claude/commands/release-notes.md 'CYCLE1-completion-v1.yaml'
contains _contract/RELEASE_NOTES_V1.md 'external_publication_action: not-performed'
not_contains _contract/RELEASE_NOTES_V1.md 'git_action:'
contains _contract/CYCLE1_COMPLETION_V2.md 'external_publication_status'
not_contains _contract/CYCLE1_COMPLETION_V2.md 'push_status'

# Every standalone frozen role/command must block direct execution in its own first lines.
frozen_count=0
while IFS= read -r -d '' file; do
  frozen_count=$((frozen_count + 1))
  head -n 9 "$file" | grep -Fq 'FROZEN / NOT READY / NOT SUPPORTED' ||
    fail "${file#"$ROOT/"} lacks a top-level frozen banner"
  head -n 9 "$file" | grep -Fq 'Do not execute' ||
    fail "${file#"$ROOT/"} lacks an explicit no-execution warning"
done < <(find "$ROOT/cycle2-deploy" "$ROOT/cycle3-ops" -type f -name '*.md' -print0)
[[ $frozen_count -eq 17 ]] || fail "expected 17 frozen Markdown files, got $frozen_count"

# Common role behavior has one canonical source; role files contain only deltas.
if rg -n '^## Интерактивный старт$|^## Хранение секретов$'   "$ROOT/cycle1-dev" "$ROOT/_tools" --glob 'CLAUDE.md'; then
  fail 'role CLAUDE.md duplicates common start or secret policy'
fi
if rg -n '^Все секреты хранятся ТОЛЬКО в pass'   "$ROOT/cycle1-dev" "$ROOT/_tools" --glob 'CLAUDE.md'; then
  fail 'role CLAUDE.md duplicates canonical secret policy'
fi
contains _standards/security.md 'plaintext `.env`'
not_contains _standards/security.md 'env-файле без pass'
not_contains _standards/data-formats.md 'TOKEN=xxx'

# Consumer DoR checks resolve logical ids rather than selecting history with wildcards.
if rg -n '^□ DoR.*\*.*существ' "$ROOT/cycle1-dev" "$ROOT/_tools" --glob 'CLAUDE.md'; then
  fail 'consumer DoR still selects artifacts by wildcard'
fi
for binding in   'cycle1-dev/s1-finance/CLAUDE.md|current logical id `feasibility-study`'   'cycle1-dev/s3-arch/CLAUDE.md|current `requirements-traceability`'   'cycle1-dev/s3-dba/CLAUDE.md|logical ids `business-requirements`'   'cycle1-dev/s4-qa-auto/CLAUDE.md|`test-strategy`'   'cycle1-dev/s5-qa/CLAUDE.md|current set `techlead-reviews`'; do
  file="${binding%%|*}"
  text="${binding#*|}"
  contains "$file" "$text"
done

# Data-format policy is fail-closed and domain/API-contract driven.
contains _standards/data-formats.md 'extra="forbid"'
contains _standards/data-formats.md 'scale не угадывать'
contains _standards/data-formats.md 'Формат ошибки API — только по project contract'
not_contains _standards/data-formats.md 'Стандартный формат ошибки API (обязательный)'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'Добавлять `extra="ignore"`'

# These are intentional public product/user surfaces.
contains _standards/company.md '## [ЗАПОЛНИ ЭТО]'
contains _standards/company.md '### Ставки сотрудников'
contains README.md 'Этот README — единая пользовательская документация системы'
contains OVERVIEW.md '| Текущее использование | `README.md`, `OVERVIEW.md` |'

# Workers are optional, bounded, read-only and use only digest-bound file handoff.
contains CLAUDE.md '`SDLC_SUBAGENTS=off|auto|cross-runtime`'
contains _contract/SUBAGENTS.md 'Launcher фиксирует exact read-manifest и route'
contains _contract/MEMORY_V1.md 'Long-term memory is an optional, project-scoped'

# Secret values are process-local only and never receive an at-rest exception.
contains cycle1-dev/l2-setup/CLAUDE.md 'Secret value передавай только process-local'
not_contains cycle1-dev/l2-setup/CLAUDE.md 'Временный secret-файл допустим'

# External standards are version-pinned and use their current models.
for metric in 'Change lead time' 'Deployment frequency' 'Failed deployment recovery time' 'Change fail rate' 'Deployment rework rate'; do
  contains _standards/quality.md "$metric"
done
contains _standards/quality.md 'Время от commit в version control до успешного production deployment'
contains _standards/quality.md 'Доля незапланированных deployments вследствие production incident'
not_contains _standards/quality.md 'Время от начала работы над изменением до его успешного запуска в production'
contains _standards/quality.md 'version-control commit → successful production deployment'
not_contains _standards/quality.md 'change start → successful production deployment'
contains _standards/quality.md 'Без production observation метрика получает `NOT_OBSERVED / deferred`'
not_contains _standards/quality.md 'Тренд по каждой метрике помечается'
contains cycle1-dev/s0-tracker/CLAUDE.md 'DORA delivery performance metrics, Reliability и production Escaped Defects'
not_contains cycle1-dev/s0-tracker/CLAUDE.md 'MTTR/Change Failure Rate/Reliability'
contains cycle1-dev/s0-tracker/.claude/commands/report.md 'Evidence ref'
contains cycle1-dev/s0-tracker/.claude/commands/report.md 'NOT_DEFINED / observational'
contains cycle1-dev/s0-tracker/.claude/commands/report.md 'quality-policy-read.sh PROJECT METRIC_ID'
contains cycle1-dev/s0-tracker/.claude/commands/report.md 'metric definition, unit, subject и observation scope'
not_contains cycle1-dev/s0-tracker/.claude/commands/report.md 'DRE < 90%'
not_contains cycle1-dev/s0-tracker/.claude/commands/report.md '≥ 95%'
report_contract="$ROOT/cycle1-dev/s0-tracker/.claude/commands/report.md"
completion_build_line="$(grep -n '^3\. Сформируй current Completion v2' "$report_contract" | cut -d: -f1)"
report_build_line="$(grep -n '^4\. Сформируй отчёт и сохрани' "$report_contract" | cut -d: -f1)"
[[ "$completion_build_line" =~ ^[0-9]+$ && "$report_build_line" =~ ^[0-9]+$ &&
  "$completion_build_line" -lt "$report_build_line" ]] ||
  fail 'Tracker report must validate Completion v2 before rendering the cycle summary'
contains _standards/quality.md 'Reliability — отдельная operational performance characteristic'
not_contains _standards/quality.md 'Целевой уровень: **High**'
not_contains _standards/quality.md 'MTTR (восстановление)'

contains _standards/security.md 'OWASP Top 10:2025'
for category in 'A01 Broken Access Control' 'A02 Security Misconfiguration' \
  'A03 Software Supply Chain Failures' 'A04 Cryptographic Failures' 'A05 Injection' \
  'A06 Insecure Design' 'A07 Authentication Failures' \
  'A08 Software or Data Integrity Failures' 'A09 Security Logging and Alerting Failures' \
  'A10 Mishandling of Exceptional Conditions'; do
  contains _standards/security.md "$category"
done
not_contains _standards/security.md 'A06 Vulnerable Components'
not_contains _standards/security.md 'A02 Crypto'

contains _standards/security.md 'OWASP ASVS 5.0.0'
contains _standards/security.md 'NIST SSDF v1.1 / SP 800-218 final'
contains cycle1-dev/s2-security/CLAUDE.md 'asvs_version: 5.0.0'
contains cycle1-dev/s2-security/CLAUDE.md 'v5.0.0-X.Y.Z'
contains cycle1-dev/s3-security/CLAUDE.md 'asvs_version'

contains _standards/quality.md 'ISO/IEC 25010:2023 — девять product-quality characteristics'
contains _standards/quality.md 'ISO/IEC 25019:2023 — quality-in-use'
contains _standards/quality.md 'отдельную модель из трёх'
contains _standards/quality.md 'characteristics, далее разделённых на sub-characteristics'
not_contains _standards/quality.md 'effectiveness / efficiency / satisfaction / freedom from risk / context coverage'
not_contains _standards/quality.md '| **Accessibility** |'
contains _standards/quality.md 'Это не десятая самостоятельная characteristic ISO/IEC 25010:2023'
contains _contract/QUALITY_CHARACTERISTICS_V1.md '11 project quality controls'
contains _contract/README.md '11 project quality controls'
not_contains _contract/README.md '11 quality characteristics'

# Nested Codex must not inherit ambient user configuration. The installed CLI can enforce
# this for exec/task mode only, so direct nested interactive Codex is fail-closed.
contains _contract/GLOBAL.md 'Codex task processes must ignore ambient user configuration'
contains CLAUDE.md 'Codex task processes must ignore ambient user configuration'
contains README.md 'Codex и встроенный `codex-oss` работают только в task mode'
contains OVERVIEW.md '`codex exec --ignore-user-config --ephemeral`'
contains _contract/README.md '`codex exec --ignore-user-config --ephemeral`'
contains _runtimes/adapters/codex.md '`--ignore-user-config`'
contains _runtimes/adapters/codex.md 'interactive Codex is not supported'
contains _runtimes/agent-run.sh '--ignore-user-config'
contains _runtimes/local-hosts/codex-oss '--ignore-user-config'
for file in _runtimes/agent-run.sh _runtimes/local-hosts/codex-oss sdlc.sh localrun.sh; do
  contains "$file" 'BLOCKED: interactive Codex cannot disable ambient user configuration'
done

# Product agents may edit the selected Project, but repository control-plane actions are not
# part of agent dispatch. PR/source ids remain evidence inputs, not authority to create them.
contains _contract/GLOBAL.md 'primary agent runtimes do not mutate repository history or remotes'
contains CLAUDE.md 'Primary agent runtimes do not mutate repository history or remotes'
contains README.md 'Primary agents не изменяют repository history, remotes или branches'
contains cycle1-dev/s4-dev/CLAUDE.md 'PR/source identifiers are evidence inputs'
not_contains cycle1-dev/s4-dev/CLAUDE.md '## Conventional Commits'
if rg -n -F 'Git — только по явному запросу пользователя' \
  "$ROOT/cycle1-dev" "$ROOT/_tools" --glob 'CLAUDE.md'; then
  fail 'active product role still conditionally authorizes Git control-plane actions'
fi
contains CHANGELOG.md 'Codex and built-in `codex-oss` primary tasks ignore ambient user configuration'
contains CHANGELOG.md 'VCS control-plane actions remain outside primary agent dispatch'
contains CHANGELOG.md 'Change lead time starts at the version-control commit'
contains CHANGELOG.md 'three-characteristic ISO/IEC 25019:2023 model'

# Gate prose consumes authoritative metric IDs and current artifact bindings.
contains _standards/quality.md 'test_pass_rate_percent'
contains _standards/quality.md 'e2e_automation_percent'
not_contains _standards/quality.md 'Pass Rate ≥ 98%'
not_contains _standards/quality.md '≥ 95% автоматизировано'
contains cycle1-dev/s4-dev/CLAUDE.md 'current logical id `authorization-model`'
contains cycle1-dev/s4-dev/CLAUDE.md 'current logical id `authorization-matrix`'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'RBAC-*'
contains cycle1-dev/s4-dev/CLAUDE.md 'OWNER_MODELS'
contains cycle1-dev/s4-dev/CLAUDE.md 'select(1)'
contains cycle1-dev/s4-dev/CLAUDE.md 'Denied owner check for unknown resource type'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'FROM {table}'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'text(f"'
contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'quality-policy-read.sh PROJECT METRIC_ID'
contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'branch_coverage_percent'
contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'mutation_score_percent'
not_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'unit_branch_coverage_percent'
quality_registry="$ROOT/_contract/quality-policy-v1.tsv"
while IFS= read -r metric_id; do
  awk -F'\t' -v metric_id="$metric_id" \
    'NR > 1 && $1 == metric_id { found=1 } END { exit(found ? 0 : 1) }' \
    "$quality_registry" || fail "dev-report uses unregistered quality metric: $metric_id"
done < <(
  awk -F'|' '/^\| [a-z][a-z0-9_]* \|/ {
    metric=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", metric); print metric
  }' "$ROOT/cycle1-dev/s4-dev/.claude/commands/dev-report.md"
)
if awk -F'\t' '$1 == "unit_branch_coverage_percent" { found=1 } END { exit(found ? 0 : 1) }' \
  "$quality_registry"; then
  fail 'quality registry unexpectedly accepts the historical metric typo'
fi

# Stage ownership and applicability are contract-driven, never inferred from a tier or prose default.
not_contains cycle1-dev/s4-dev/CLAUDE.md 'Функции: максимум 20 строк'
contains cycle1-dev/s4-dev/CLAUDE.md 'размер не является отдельным quality threshold'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'Авторизация на каждом endpoint'
contains cycle1-dev/s4-dev/CLAUDE.md 'public/unprotected endpoint'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'стандартный формат {error, detail}'
contains cycle1-dev/s4-dev/CLAUDE.md 'точно соответствуют current `api-contract`'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'API-доки — обновить ARCH-api-spec.yaml'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'создай/обнови ADR в stage3-design/outputs/'
contains cycle1-dev/s4-dev/CLAUDE.md 's4-dev не изменяет Stage 3 HLD, API contract или ADR'
contains cycle1-dev/s4-dev/CLAUDE.md 'fresh Change Scope'
not_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'API-spec обновлён (если менялись endpoints)'
contains cycle1-dev/s4-dev/.claude/commands/update-notes.md 'Stage 3 artifacts: не изменяются этой командой'
not_contains cycle1-dev/s1-pm/.claude/commands/feasibility.md '{/health endpoint (liveness) — если Tier ≥ 1}'
not_contains cycle1-dev/s1-pm/.claude/commands/feasibility.md '{добавить /metrics в API spec — если Tier ≥ 2}'
not_contains cycle1-dev/s1-pm/.claude/commands/feasibility.md 'monitoring_stack:'
not_contains cycle1-dev/s1-pm/.claude/commands/feasibility.md 'runbook: {обязателен если Tier ≥ 1}'
contains cycle1-dev/s1-pm/.claude/commands/feasibility.md 'confirmed long-running network service'
contains cycle1-dev/s1-pm/.claude/commands/feasibility.md 'interface: "CONFIRMED from Project facts/NFR/HLD | UNSPECIFIED"'
contains cycle1-dev/s1-pm/.claude/commands/feasibility.md 'Tier не определяет interface, protocol, stack или runbook applicability'
not_contains cycle1-dev/s1-pmo/CLAUDE.md 'все сервисы обязаны экспортировать /health если Tier ≥ 1'
contains cycle1-dev/s1-pmo/CLAUDE.md 'Tier используется только для risk classification'
contains cycle1-dev/s4-dev/.claude/commands/update-notes.md 'CHANGELOG/release notes: не изменяются этой командой'
not_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'coverage >= 80'
not_contains cycle1-dev/s4-dev/.claude/commands/dev-report.md 'mutation >= 60'
contains cycle1-dev/s0-validate/.claude/commands/profile-check.md 'Schema version 5 — current'
not_contains cycle1-dev/s0-validate/.claude/commands/profile-check.md 'требует новую revision'
not_contains cycle1-dev/s0-validate/.claude/commands/review.md 'Ожидаемый scope: `ai-routes`'

# A blocked role returns control to the user and launcher instead of invoking another role.
contains cycle1-dev/s1-pm/CLAUDE.md 'попросить пользователя'
contains cycle1-dev/s1-pm/CLAUDE.md 'открыть launcher и запустить'
not_contains cycle1-dev/s1-pm/CLAUDE.md 'сообщить пользователю, запустить s0-kickoff'
contains cycle1-dev/s4-dev/CLAUDE.md 'попроси пользователя через launcher'
not_contains cycle1-dev/s4-dev/CLAUDE.md 'Изменения в RBAC требуют обновления RBAC артефактов (через s3-rbac)'

# Documentation inventory is filesystem-only and test scratch honors TMPDIR.
not_contains tests/documentation-contract-smoke.sh 'git -C "$ROOT" ls-files'
contains tests/documentation-contract-smoke.sh 'filesystem-public-allowlist-current-Markdown'
hardcoded_tmp='/tmp/'
hardcoded_tmp+='sdlc-'
if rg -n "$hardcoded_tmp" "$ROOT/tests" --glob '*.sh'; then
  fail 'test scripts contain a hardcoded /tmp scratch path instead of TMPDIR'
fi

echo 'PASS: documentation semantics smoke'
