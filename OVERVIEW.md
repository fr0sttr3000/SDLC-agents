# Архитектура и workflow SDLC Agent System

## Слои системы

```text
User
  │
  ▼
sdlc.sh ── Project selector ── Project Console ── Preview / Journal
  │                                      │
  │                                      ├─ Cycle 1 (supported)
  │                                      ├─ Cycle 2/3 status (FROZEN / NOT READY)
  │                                      ├─ One Agent
  │                                      ├─ scoped Review / Repair
  │                                      └─ Utilities / Memory / Change Scope / Local Repositories
  ▼
runtime routing ── agent-run.sh ── Claude | Codex | Gemini | Local host
                                        │
                                        └─ subagent-run.sh: authorized bounded read-only worker
  │
  └─ memoryctl.sh ── Files | Qdrant | Mem0 OSS | Mem0 Platform
  ▼
canonical contracts: CLAUDE.md + _standards + command templates
  ▼
$SDLC_PROJECTS_DIR/{PROJECT}/ native artifacts + Markdown governance evidence
```

Launcher отвечает за Project/scope/routes/state. Runtime adapter отвечает за безопасный способ
выполнить prompt. Agent contract отвечает за роль/artifacts/gate contribution. Ни один adapter
не определяет собственную SDLC-логику.

## Project data model

```text
{PROJECT}/
├── Dashboard.md
├── stage1-planning/{inputs,outputs}/
├── stage2-requirements/{inputs,outputs}/
├── stage3-design/{inputs,outputs}/
├── stage4-dev/{inputs,outputs}/
├── stage5-testing/{inputs,outputs}/
├── stage6-deploy/{inputs,outputs}/   # historical, может отсутствовать
│   ├── outputs/DEVOPS-...
│   └── outputs/REL-...
├── stage7-ops/{inputs,outputs}/      # historical, может отсутствовать
│   ├── outputs/SRE-...
│   └── outputs/OPS-TDD-status.md
└── tracking/
    ├── SDLC-goals.md
    ├── quality-gates.md
    ├── quality-gates-history/revision-<N>.md
    ├── quality-characteristics-v1.tsv
    ├── quality-characteristics.md
    ├── product-ci-profile.yaml
    ├── evidence/v1/<evidence-id>.yaml
    ├── evidence/raw/<native-result>
    ├── risk-exceptions/<exception-id>.yaml
    ├── ai-routing.conf
    ├── runtime-routing
    ├── backlog.md / current-sprint.md / known-issues.md
    ├── current-artifacts-v1.tsv
    ├── current-change-scope-v1.yaml
    ├── change-scopes/<scope-id>/{intent,l1,s3,approved}/
    ├── completion/CYCLE1-completion-v2.yaml
    ├── releases/REL-vX.Y.Z-release-notes.md   # optional, prepared/not released
Launcher state (outside Project write scope):
  $XDG_STATE_HOME/sdlc-agents/execution-journal/projects/<project>-<digest>/runs/<run-id>/
```

Stage 6/7 сохраняются для совместимости со старыми Projects. Они принадлежат historical
Cycle 2/3 (`FROZEN / NOT READY`) и не являются writable outputs поддерживаемого launcher flow.

## Cycle 1: Development

Текущий Cycle 1 содержит 28 обязательных шагов плюс явно выбранные optional utilities.

Основной dependency flow:

```text
Kickoff
  → validated Product & CI Profile schema v5 (evidence + UX + S5 + quality applicability)
  → S1 PM / PMO / Finance / only-up thresholds + Quality Characteristics v1
  → S2 BA(BRD+NFR+RTM) / PO(backlog+UX/N-A+product UAT) / QA / Test Strategy / SG1
  → Gate 2 validator
  → S3 HLD+API-or-N/A / Threat model(CVSS) / Authorization / Data-or-N/A
  → Gate 3 validator
  → Change Intent → isolated L1 Project Map/impact → isolated S3 architecture/path impact
  → launcher path assembly → independent Human Change Scope Approval
  → S4 QA-TDD Red → Developer Green/Repair → full affected manifest + selected executor raw results
  → s0-validate: TDD Status v1 + Evidence v1 + quality coverage + only-up + SG3 + controls
  → five-dimension Tech Lead maintainability review → Gate 4
  → S5 Test Plan → owner-bound E2E/PERF/SG4 → human UAT + exploratory
  → single defects/test analysis → machine-verified Gate 5 Go/No-Go
  → full DoD approval + Cycle summary + launcher-owned 28-step execution proof
  → verified Cycle 1 Completion v2 manifest
  → optional `s0-tracker /release-notes vX.Y.Z` (Markdown only)
```

Release notes также не являются условием validated result: Utilities → Release notes проверяет
immutable completion, показывает version/source/input/target в Preview и не выполняет external publication,
build, deploy или Cycle 2/3.

QA Requirements даёт `QA contribution: PASS|FAIL`, а не подписывает Gate 2 целиком. Gate 2
также требует BRD/NFR/RTM, backlog, test strategy и SG1.

Architecture/Data/Authorization artifacts applicability-based. API spec, SQL schema, RLS,
migration, queues, health checks и другие native artifacts создаются только при соответствующем
stack/scope; N/A фиксирует причину/evidence.

## Cycle 2/3: historical boundary

Cycle 2/3, их agents, goal profiles, Gate 6/7 и SG5 имеют статус `FROZEN / NOT READY`.
Launcher показывает status, но не строит Preview выполнения и не dispatch-ит frozen agents.
Существующий код не удалён, чтобы не потерять историю реализации до отдельного redesign.
Старые Stage 6/7 status-файлы не дают PASS и не блокируют Cycle 1.

## Runtime routing

Profile format хранит runtime и, для Local, exact host/provider/model/endpoint. Policies:

```text
single       one profile
per-stage    stage/cycle routes
per-agent    exact role overrides
ask          resolve every needed step before Preview
```

Missing route/profile = BLOCKED. Route не наследуется между разными Projects. Local Repositories
имеет собственный routing profile и не наследует последнего SDLC Agent.

Рекомендуемый пользовательский вход в систему — канонический `sdlc.sh`.

В Codex App канонический путь проходит через Local project и integrated terminal: terminal
запускает `sdlc.sh`/`localrun.sh`, а каждый автоматический task получает новый ephemeral
`codex exec --ignore-user-config --ephemeral` с exact Project scope. Вложенный интерактивный
Codex не поддерживается: launcher требует зарегистрированную команду и task mode. Worktree не
является default для Vault с внешними или
untracked Project files. Проверенные и `UNVERIFIED` compatibility claims находятся в
`_runtimes/adapters/codex.md`, единый пользовательский маршрут — в `README.md`.

Перед каждым primary cycle/tool launch общий dispatcher на поддерживаемом Linux устанавливает
Landlock-границу: source-checkout VCS metadata и checkout-local runtime-denied roots запрещены
для open/read/list/write. Публичный канон остаётся readable, а selected Project/notes scopes
сохраняют только runtime-contract access. Отсутствие enforcement блокирует запуск.

Stage 4 mutators используют `scoped-write`: весь exact Project readable, notes read-only, а
Landlock write capabilities вычисляются только для current agent/command из digest-bound Change
Scope. Для create/delete/rename launcher выдаёт минимальный существующий parent и компенсирует
гранулярность обязательным full-tree diff. `USE|LOCKED` paths дополнительно вычитаются. Scope
preparation всегда разделена на L1 и S3 процессы и завершается отдельным Human Approval.

### Supervisor + Worker

```text
Primary/Supervisor (sole writer and gate signer)
  └─ Worker Request + exact read/route authorization
       └─ isolated read-only worker ──> launcher-owned Worker Result
```

`off` остаётся default. В `auto|cross-runtime` worker стартует только при совпадении request,
read-manifest и route digests с launcher authorization. Весь Project не монтируется: Landlock
разрешает public canon, isolated scratch и exact read paths. Direct/mismatched dispatch,
Project/memory write, nested delegation и fallback блокируются. Primary runtime также
запускается с очищенным allowlist environment.

`auto` использует frozen profile соответствующего primary step. `cross-runtime` использует один
отдельный frozen worker profile на весь execution plan; независимой worker routing matrix по
этапам или ролям в MVP нет. Connected-memory snapshot и provider access worker-у не выдаются.

### Подключаемая память

Project profile включает только выбранные `planning|defects|architecture` collections.
`memoryctl.sh` держит provider credentials вне model process, проверяет role ACL и records,
создаёт immutable per-run snapshot, а agent write принимает только как Proposal v1. Provider
mutation выполняется после exact Human Approval и read-back; current artifacts/gates выше
памяти по приоритету.

## Scoped Review / Repair

Supported Review scopes: `project`, `cycle:1`, `stage:0..5`, `agent:<active-id>`. Launcher вызывает
`s0-validate /review scope=...` с `--access read-only`; Claude/Codex/Local codex-oss adapters
применяют реальные tool/sandbox restrictions. Валидные `REVIEW_FINDING` rows сохраняются вне
Project как immutable digest-bound findings, связанные с exact scope и Project snapshot.

Repair scopes совпадают и добавляют `structure`. `/repair` читает подтверждённые findings,
показывает files/excluded/tests, затем пишет только внутри scope как child Review run. Изменение
Project snapshot обязательно; после него launcher выполняет read-only re-review того же scope,
и только `CLEAN` считается success. Недостающий product decision не угадывается.

## Windows launcher adapter — experimental

`sdlc.ps1` и `localrun.ps1` — тонкие entrypoints к `_runtimes/windows-launcher.ps1`.
Adapter выбирает явный `SDLC_BASH` или Git for Windows Bash, преобразует project path в
MSYS-формат и запускает канонический `sdlc.sh`/`localrun.sh`. Workflow, gates и routes в
PowerShell не дублируются. Выполняются только platform-neutral static checks структуры wrappers;
реальный запуск на Windows не проверялся и не входит в поддерживаемый scope. Использование
Windows adapter — experimental, на свой страх и риск.

## Execution Journal internals

- `plan.md` immutable и содержит frozen step profiles/route sources.
- `state.md` записывается atomic rename; YAML-sensitive strings quoted.
- `events.jsonl` append-only SHA-256 hash chain с `sequence`, `prev_hash` и `event_hash`;
  удаление, вставка, reorder или изменение любой строки блокирует resume/completion.
- Secret-like custom prompt отклоняется shared runtime boundary до Preview/argv и не echo-ится.
- `lease` сверяет PID + process start time.
- Runtime exit `0` фиксируется как `PROCESS_OK`, но не завершает шаг.
- Mutating-шаг продвигается только после `ARTIFACT_VERIFIED`: изменился каждый declared output
  group задачи. Read-only команда запускается с принудительным read-only access и получает
  отдельный `READ_ONLY_VERIFIED`.
- Stage 4 дополнительно требует current approved Change Scope, exact runtime-table digest и
  совпадение полного before/after Project manifest; нарушение сохраняется launcher-ом и
  блокирует последующие writes без автоматического rollback.
- `_contract/command-capabilities-v1.tsv` классифицирует все active commands; generic One Agent
  не показывает `orchestrated-special` операции.
- Tracker mutators dispatch-ятся только из Utilities → Tracker: launcher связывает exact
  task/sprint arguments с Preview/Journal и registry-named postcondition verifier.
- Автоматизируемая часть DoD фиксируется как `DOD_AUTO_PASS`; полный `DOD_PASS` требует
  independently validated Human Approval v1, exact `DOD-1`–`DOD-11` и digest-bound current
  Tech Lead reviews. Gate verdict фиксируется отдельно как `GATE_PASS`.
- Resume point принимает anchored result только вместе со всеми зарегистрированными для шага
  Gate/DoD/completion hooks.
- Retry создаёт linked child run с exact frozen suffix; исходный plan/history не
  переписываются. Completion связывает root и все Retry children launcher-owned chain proof.

## Local Repositories internals

Internal agents `l1-analyze`, `l2-setup`, `l3-build`, `l4-run` обслуживают code repository и
технические заметки. Это не SDLC Stage. Secrets не source/eval из repository `.env`, password
не переносятся в config, build не пропускает tests. Full pipeline прекращается как incomplete при
skip/failure. Для каждого L-agent launcher сравнивает fingerprint его exact note и требует
changed non-empty `overview.md|setup.md|build.md|run.md`; exit `0` без output не является success.
Pull требует чистого working tree и Preview; push запрещён. Batch update заметок
тоже показывает exact scope до запуска и прекращается на первом skip/failure.

Primary agent runtimes могут изменять файлы только в exact Project/notes scope, но не repository
history, remotes или branches и не создают commits, pushes, pull requests или tags. VCS
control-plane остаётся launcher/operator action вне agent dispatch.

## Документационное управление

| Тип информации | Источник |
|---|---|
| Устойчивые принципы | `plans/principles.md` |
| Активный/future backlog | `plans/roadmap.md` |
| Gates/engineering rules | `_standards/*.md` |
| Runtime invariants | `_contract/*.md` |
| Роли/команды | agent `CLAUDE.md`, `.claude/commands/*.md` |
| Текущее использование | `README.md`, `OVERVIEW.md` |
| Подготовленные релизы | `CHANGELOG.md`, `RELEASE_NOTES_v*.md` |

Исполняемые shell scripts — реализация, не документация. Исторические release notes immutable.

Root `RELEASE_NOTES_v*.md` описывают platform release этого repository. Project artifact
`tracking/releases/REL-vX.Y.Z-release-notes.md` — другой, post-Cycle-1 handoff: он создаётся
только для exact Project completion и сам по себе не публикует platform или Project release.
