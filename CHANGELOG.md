---
date: 2026-09-01
tags:
  - docs
  - changelog
---

# CHANGELOG — Claude SDLC Agents

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

Пока без записей.

## [2.002.000] — 2026-09-01

### Added

- Project-scoped connected memory MVP for user-approved planning/project-vision, architecture
  and known-defect records. The broker provides ACL-filtered snapshots, proposal/approval flow,
  canonical read-back and a dedicated `s0-defects` role without sharing hidden chat context.
- Optional bounded advisory workers for Claude, Codex, local `codex-oss` and the read-only OpenAI
  Responses API host. Primary and worker providers can be selected independently where the
  capability registry permits that route.
- `sdlc-task.sh` as the vendor-neutral explicit CLI for memory and worker handoffs from Codex,
  Claude Code, Gemini or another supported task shell. Full primary execution remains launcher-owned through `sdlc.sh`.

### Security

- Connected memory remains disabled by default. Provider credentials stay launcher-side; model
  runtimes receive only approved, role-filtered file snapshots and submit writes as proposals.
- Worker handoff is restricted to an exact digest-bound read manifest. Workers cannot write
  Project artifacts, approve memory, sign gates, inherit chat history or trigger another agent.
- Primary memory is runtime-independent, while workers receive neither connected-memory snapshots
  nor direct memory-provider access.
- OpenAI advisory requests now have bounded connection time, total time and response size.

### Fixed

- Mem0 Platform v3 writes accept the current `SUCCEEDED` terminal status while missing, failed or
  unknown statuses remain fail-closed before canonical read-back.
- Mem0 OSS and Platform adapters preserve padded canonical base64 fields when extracting record
  content for exact-storage requests.
- Corrected the README description of the operator-only pull workflow.

### Compatibility

- `files-v1` is the local baseline. `qdrant-v1`, `mem0-oss-v1` and `mem0-platform-v1` are
  supported adapters subject to deployment-specific live validation described in the user guide.
- Gemini remains primary-only in this MVP. Live external-memory deployments, live Codex App E2E
  and real Windows execution remain outside the verified compatibility matrix.

## [2.001.001] — 2026-08-23

### Added

- Change Scope v1 preparation: exact Change Intent, isolated L1 Project Map/impact, independent
  S3 architecture/path review and digest-bound Human Approval before Stage 4 mutation.
- `scoped-write` runtime capabilities plus full Project entry/type/mode/content/symlink manifests
  and persistent launcher-owned scope-violation evidence.

### Changed

- All five Stage 4 mutating commands now require the current approved per-owner path table and a
  combined full-diff + declared-output verifier. The canonical 28-step Cycle 1 sequence is unchanged.
- TDD repair iterations use the same scope preparation and postflight checks as their original
  Stage 4 commands.
- KISS is now mandatory for implementation-writing roles (`s4-dev`, plus Local Repositories
  setup/build/run when they modify a repository): prefer the smallest sufficient change without
  weakening architecture, quality, security, reliability or test controls. Function size follows
  SRP and the effective complexity policy rather than a separate prose-only line limit.
- Stage 4 documentation updates are limited to exact approved source-local paths. Changes to HLD,
  API contracts or ADRs return to the Stage 3 owner and require a fresh approved Change Scope.
- Feasibility handoff records confirmed recovery/observability outcomes and applicability without
  deriving HTTP endpoints, monitoring stacks or executable runbooks from criticality tier.

### Fixed

- Gate 2/3 architecture and QA consumers now resolve only manifest-selected current artifacts;
  retained history is excluded and a stale/missing manifest row cannot fall back to a glob or fixed name.
- QA decision records must bind the exact current requirements review and digest.
- The Stage 4 Dev Report uses the registered `branch_coverage_percent` metric id, and semantic
  regression checks reject metric ids absent from the authoritative quality-policy registry.
- Change Scope rejects native Stage 4 rows that match or contain registry-owned governance outputs;
  those paths can enter a scope only as launcher-owned `declared-output` alternatives.

### Security

- `USE|LOCKED`, notes, unspecified Project paths, ambient home, sibling Projects and VCS metadata
  remain unwritable during Stage 4; tampered/stale scope digests fail before runtime dispatch.
- Out-of-scope changes block further mutation without automatic rollback until the Project is
  restored or a fresh Change Scope is separately approved.

## [2.001.000] — 2026-08-19

### Added

- Cycle 1 machine contracts for Product Profile v5, quality characteristics, product acceptance,
  architecture trace, Evidence/SG3, TDD status, S5 validation and completion manifests.
- Shared Artifact Metadata v1 with Obsidian link validation and additive legacy migration report.
- Experimental PowerShell launchers delegating to canonical Bash; not tested on Windows and
  not included in the supported platform scope.
- Fail-closed completion evidence and Current Artifacts history.
- Capability registries for command access, declared outputs, runtime scopes and exact
  postcondition verifiers.
- Digest-bound Human Approval, Gate 1 planning, PR-set, risk-exception and release-notes
  contracts with dedicated validators.
- Dedicated Tracker utility routes for task and sprint mutations, including exact
  active-ledger cardinality checks and Tech Debt materialization.

### Changed

- Cycle 1 is the only supported route; Cycle 2/3 are preserved as `FROZEN / NOT READY`.
- Workers fail closed until capability-enforced bounded read scope is proven.
- Runtime/model/technology applicability is explicit; missing facts never trigger silent fallback.
- New/refreshed projects write Product Profile v5 and exact-source machine evidence.
- DORA uses the current five delivery metrics. Change lead time starts at the version-control commit;
  reliability is separate, and production-only metrics remain `NOT_OBSERVED / deferred`
  without exact production evidence.
- Security guidance is pinned to OWASP Top 10:2025, OWASP ASVS 5.0.0 and the final
  NIST SSDF v1.1 baseline.
- Product quality follows the nine-characteristic ISO/IEC 25010:2023 model, with accessibility
  retained as an explicit control; quality-in-use follows the separate three-characteristic ISO/IEC 25019:2023 model.
- Stage 4 authorization consumers resolve exact current logical IDs instead of RBAC history globs.
- Codex and built-in `codex-oss` primary tasks ignore ambient user configuration and use
  task-only ephemeral dispatch; unsupported nested interactive Codex fails closed.
- VCS control-plane actions remain outside primary agent dispatch; Project PR/source identifiers
  are evidence inputs rather than authority to create commits, pushes, pull requests or tags.
- Runtime exit code `0` now means only `PROCESS_OK`; mutating commands require changed
  declared output groups and a registry-named verifier before `ARTIFACT_VERIFIED`.
- Software DoD separates machine `DOD_AUTO_PASS` from the full approval-backed `DOD_PASS`.
- Documentation is consolidated around one README, one architectural overview, stable
  principles and one current roadmap; delivered work moves to changelog/release notes.

### Security

- Secret-like prompt values are rejected before terminal Preview and runtime argv without echoing
  the rejected value.
- Evidence validation rejects untrusted producer, stale revision, wrong subject and raw tampering.
- SG1/SG2 validation rejects missing, mismatched or unversioned ASVS evidence.
- Local setup passes secret values only process-locally; plaintext temporary secret files are
  not an allowed exception.
- Supported Linux dispatch applies the capability-enforced runtime access matrix and blocks
  execution if its boundary cannot be established.
- Approval, exception and current-artifact decisions are bound to exact subject/source digests;
  stale or self-attested Markdown cannot promote a gate.

### Fixed

- Removed stale wording that allowed read-only workers despite the active fail-closed mode.
- Blocked roles now return control to the user for launcher-mediated transitions.
- Gate prose consumes authoritative quality metric IDs instead of duplicating numeric thresholds.
- Documentation regression checks use an explicit filesystem allowlist, validate the corrected
  semantics and honor the caller-provided temporary directory.
- Gate 1, Gate 4 PR-set, SG1/SG2, S5 and Cycle 1 completion validators now reject incomplete,
  stale, wrong-version and wrong-subject evidence consistently.
- Known Issue and Risk Exception parsing now handles canonical severity/lifecycle formats without
  silently accepting legacy ambiguity.
- TDD/DoD checks cover native test and secret-result formats, migration round trips and
  full affected regression evidence.
- Tracker postconditions ignore historical closed sprint copies while still requiring the exact
  active task copies to reach the requested state.
- Cycle reports no longer publish a completion summary before completion verification, and
  environment setup failures are no longer mislabeled as a valid RED test result.

### Compatibility

- Existing Claude, Codex, Gemini and registered Local profiles remain available as primary
  runtimes; no default model or silent fallback was added.
- Worker execution remains fail-closed with `SDLC_SUBAGENTS=off` as the only supported mode.
- Linux/WSL2 remains the supported execution environment. Windows wrappers and CI scenarios are
  present, but real Windows execution is unverified and the adapter remains experimental.

---

## [2.000.004] — 2026-07-22

### Added

- Scoped Project/Cycle/Stage/Agent Review and Repair with exact Preview boundaries.
- Capability-enforced read-only execution for Claude, Codex and Local `codex-oss` workers.
- Behavioral validator, principles-consistency, worker-security, journal and Local Repositories regressions.
- Missing shared commands: validator Review/Repair/DoR/DoD, Architecture API spec,
  Kickoff context review, Tracker `/task-block`/`/backlog`, GitHub `/branch`.

### Changed

- Canon now defines Markdown-first governance while preserving native code/test/API/SQL/IaC formats.
- Gate/DoR/DoD ownership and paths are aligned across Stage 1–7; Cycle 2 owns Stage 6,
  Cycle 3 owns Stage 7, and `s6-release` signs Gate 6.
- Agent contracts are applicability/stack-aware; threat severity is CVSS, migrations are
  design-only in Stage 3, and QA Requirements contributes to rather than signs all of Gate 2.
- Applicability contracts now cover non-API, non-DB, CLI/library, images-only and
  operations-artifacts-only projects without hidden stack defaults.
- README, GETTING_STARTED, OVERVIEW, root contract, adapters, roadmap and document map were
  synchronized with the implemented Project Console and three active test-first cycles.

### Fixed

- DoR/DoD validators no longer abort on the first counter increment and now validate correct
  Gate 1–6 artifacts, release context and Stage 6/7 infrastructure evidence.
- Review menu choices no longer execute the same shallow scan; Review is truly read-only.
- Worker scopes cannot be `/`, HOME or outside the configured project root; unsupported worker
  adapters fail instead of relying on prompt-only restrictions.
- Execution Journal quotes YAML-sensitive values, rejects evidence-text step injection and
  protects leases against PID reuse while preserving the exact failing step, agent and task.
- Launcher menus reject unsafe indexes instead of dispatching an unintended action.
- Local Repositories notes update now has an exact Preview, and the first skipped or failed
  mandatory step returns incomplete instead of false success.
- Unsafe `.env` source/eval/persistence, secret exposure guidance and build skip-tests defaults
  were removed from active contracts/commands.

### Compatibility

- Claude, Codex, Gemini and registered Local hosts remain supported as primary profiles.
- Gemini/custom Local profiles are primary-only until an enforceable read-only worker adapter exists.
- No default model or runtime fallback was introduced.

---

## [2.000.003] — 2026-07-03

### Added

#### Universal Runtime Contract — Claude / Codex / Gemini
- Добавлен `_contract/GLOBAL.md` и `_contract/README.md`: vendor-neutral контракт, где канон = `_standards/*.md`, root `CLAUDE.md`, agent `CLAUDE.md`, `.claude/commands/*.md`, `projects/`
- Добавлен `_runtimes/agent-run.sh` — единый dispatcher для `claude`, `codex`, `gemini`
- Добавлены runtime adapter docs: `_runtimes/adapters/claude.md`, `codex.md`, `gemini.md`
- Добавлены `AGENTS.md` (Codex bridge), `GEMINI.md` (Gemini bridge), `.codex/config.toml`
- Добавлена явная настройка проектов: first-run wizard поддерживает каталог с несколькими SDLC-проектами и папку одного проекта; launcher не выбирает каталог проектов автоматически

### Changed

- `sdlc.sh` запускает агентов через runtime dispatcher; runtime выбирается явно через `AGENT_RUNTIME=claude|codex|gemini`, сохранённый config, first-run wizard или меню `Настройки`; автоматического выбора Claude нет
- `localrun.sh` также использует runtime dispatcher, раскрывает `.claude/commands/*.md` в обычный prompt до передачи в runtime и показывает/позволяет менять каталог локальных проектов
- Документация обновлена под multi-runtime режим: `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, `CLAUDE.md`, `plans/principles.md`, `plans/roadmap.md`
- Агентские файловые контракты переведены с `$SDLC_VAULT/projects/{PROJECT}` на `$SDLC_PROJECTS_DIR/{PROJECT}`

### Compatibility

- Claude workflow сохранён как явный runtime: `AGENT_RUNTIME=claude bash sdlc.sh` или выбор Claude в настройках; чистый `bash sdlc.sh` сначала спрашивает runtime
- Новые Codex/Gemini adapters не являются источником SDLC-логики; новые правила должны добавляться в канонические markdown-файлы

---

## [2.000.002] — 2026-06-21

### Added

#### Security-трек SG1–SG5
- Добавлен `_standards/security.md`: CVSS severity, ASVS по tier, Security Gates SG1–SG5, DevSecOps controls, privacy/data protection при PII
- Добавлены агенты `s2-security` (SG1), `s5-security` (SG4), `s0-quality-gates` (проектные пороги gates)
- `s3-security` назначен владельцем SG2/SG3

#### Quality Gates overhaul
- Добавлена пирамида тестов: branch coverage, mutation score, integration, contract, E2E, performance
- Добавлен маппинг ISO/IEC 25010, Functional Suitability в Gate 5, DORA + Reliability и defect-метрики
- Добавлен Known Issues operational contract / KEDB: `known-issues.md`, per-KI runbook, alert join-key, Patch SLA

### Changed

- `quality.md` разделён с `security.md`: переход этапа требует зелёный Quality Gate и соответствующий Security Gate
- `sdlc.sh`, `README.md`, `OVERVIEW.md`, `CLAUDE.md`, `plans/roadmap.md` синхронизированы с 24 шагами Цикла 1 и security/quality overhaul

---

## [2.000.001] — 2026-06-01

Багфикс-релиз поверх 2.000.000: переносимость путей, доведение лаунчера до модели 3 циклов,
навигация «Назад» и правила из обезличенных production incidents. Один большой багфикс — без
новой функциональности для пользователя.

### Fixed

#### Переносимость — убраны захардкоженные абсолютные пути (BLOCKER)
- `sdlc.sh` и `localrun.sh` вычисляют пути от расположения скрипта (`BASH_SOURCE`), `PATH`
  использует `$HOME` вместо machine-specific absolute home path
- Лаунчеры экспортируют `SDLC_VAULT` и `LOCALRUN_PROJECTS` в окружение агентов
- Во всех `CLAUDE.md` и slash-командах агентов абсолютные пути заменены на `$SDLC_VAULT` / `$AGENT_DIR`
- В документации (`CLAUDE.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, `README.md`) пути заменены на env-переменные / `<vault-root>`
- `CLAUDE.md` — добавлен раздел «Пути проекта (env-переменные)» с таблицей `AGENT_DIR` / `SDLC_VAULT` / `LOCALRUN_PROJECTS` и фолбэком при пустой переменной

#### localrun.sh — настраиваемый путь к локальным проектам
- Project root больше не привязан к machine-specific absolute path
- Приоритет: env `LOCALRUN_PROJECTS` → config-файл `~/.config/sdlc-agents/config` → first-run wizard
- При первом запуске мастер спрашивает каталог и сохраняет его в config

#### sdlc.sh — лаунчер приведён к модели 3 циклов
- `CYCLE_AGENTS` разделён на `CYCLE1_AGENTS` (22 шага), `CYCLE2_AGENTS`, `CYCLE3_AGENTS`
- Из Цикла 1 убраны шаги Циклов 2/3 (`s4-devops`, `s6-release`, `s6-sre`); Цикл 1 завершается `s0-tracker:/report`
- `gate7` убран из необязательных шагов (его место — Цикл 3)
- Циклы 2/3 — заглушки «⏳ в разработке» с перечнем запланированных агентов

#### Правила из обезличенных production incidents
- `CLAUDE.md` — git не используется для отката, запись выполняет основной агент, запрос
  «все» означает полный вывод, deployment constraints обязательны, директория проверяется
  перед записью
- `s4-dev/CLAUDE.md` — `assert` запрещён в production-коде, удаляются неиспользуемые импорты,
  `server_default` использует строковый литерал, функциональные индексы требуют
  IMMUTABLE-выражений
- `s4-techlead/CLAUDE.md` — `[BLOCKER]` на `assert` в production, `[MINOR]` на неиспользуемые
  импорты и выпуск `PROC-*` в фазе разработки

### Changed

#### Навигация и UX лаунчеров
- В `sdlc.sh` и `localrun.sh` во все меню добавлен пункт `b) Назад`
- Главное меню `sdlc.sh`: пункт 1 — «Запустить цикл» (подменю Разработка / Деплой / Эксплуатация / Всё сразу), пункт 2 — «Запустить один агент»
- Меню одиночного запуска сгруппировано по циклам + Tools + Local Run
- Пустой ввод имени проекта трактуется как отмена, а не ошибка

#### Документация
- `CHANGELOG.md`, `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md`, `plans/roadmap.md` — синхронизированы с новой структурой меню (22 шага Цикла 1, новая нумерация пунктов), `CYCLE_AGENTS` → `CYCLE1_AGENTS`/`CYCLE2_AGENTS`

---

## [2.000.000] — 2026-05-29

### Added
- `plans/principles.md` — принципы проекта (3 цикла, SDD, TDD, Shift Left, Markdown-first, Obsidian, Secrets via pass, Quality Gates только вверх, DoR/DoD, Трассируемость)
- `plans/roadmap.md` — roadmap изменений системы
- `cycle1-dev/s0-tracker/CLAUDE.md` — добавлен DoD (sprint-close, task-done, report)
- `find_agent_dir()` в `sdlc.sh` и `localrun.sh` — поиск агентов в подпапках циклов

### Changed
- Архитектура: монолитный SDLC разделён на 3 цикла (Dev / Deploy / Ops)
- Директории агентов реструктурированы: `cycle1-dev/`, `cycle2-deploy/`, `cycle3-ops/`, `_tools/`, `plans/`
- `_standards/company.md` — удалена методология разработки (перенесена в `plans/principles.md`), исправлена ссылка на секреты
- Обновлена документация: `CLAUDE.md`, `README.md`, `OVERVIEW.md`, `GETTING_STARTED.md` (новая структура, перекрёстные ссылки)

### Fixed
- `cycle1-dev/s0-validate/CLAUDE.md` — исправлены абсолютные пути к `dod-check.sh` и `dor-check.sh`
- `cycle1-dev/s0-kickoff/CLAUDE.md` — исправлен путь к `s1-pm`

---

## [1.7.1] — 2026-05-23

### Added

#### sdlc.sh — s3-arch:/adr добавлен в CYCLE_AGENTS как отдельный шаг
- Команда `/adr` существовала в `s3-arch/.claude/commands/adr.md`, но не была включена в автоматизированный цикл
- Добавлена сразу после `/hld` (шаг 11 → ADR генерируется автоматически после HLD)
- Цикл расширен с 26 до **27 обязательных шагов**

#### sdlc.sh — s6-sre:/gate7 добавлен как необязательный шаг (после цикла)
- Gate 7 нельзя автоматизировать в линейном цикле (выполняется через 7 дней после деплоя)
- Добавлен в `OPTIONAL_AGENTS_DEF` с позицией `after` — пользователь включает через toggle-меню
- Описание: "Gate 7 — мониторинг + auto-heal + SLO Review (через 7 дней после деплоя)"

### Fixed

#### localrun.sh — изоляция L-агентов (BLOCKER)
- **Проблема**: `run_agent` в `localrun.sh` запускал claude без `AGENT_DIR` и без `env -u` флагов, в отличие от `sdlc.sh`
- L-агенты не получали `AGENT_DIR` → не могли строить абсолютные пути к своим файлам
- Claude запускался внутри родительской сессии (вложенный вызов без изоляции)
- **Исправлено**: все 5 вызовов claude в `run_agent` теперь используют `AGENT_DIR="$agent_dir" env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT`

---

## [1.7.0] — 2026-05-23

### Added

#### s0-kickoff — расширение интервью до 5 блоков, 26 вопросов (было 4 блока, 19 вопросов)
- **Блок 1 переориентирован на проблему**: Q1.2=pain point → Q1.3=As-Is → Q1.4=To-Be → Q1.5=продукт (было наоборот)
- **Правило 5 Whys**: если ответ на Q1.2 звучит как симптом — задавать "почему?" до корневой причины
- **Блок 3 расширен** до 11 вопросов: добавлены Q3.6 (топология деплоя), Q3.7 (ожидание восстановления), Q3.7b (канал алертов — условный), Q3.8 (мониторинг), Q3.9 (delivery scope), Q3.10 (существующий мониторинг — условный)
- **Блок 4 расширен**: добавлены Q4.1 (критерии успеха → North Star), Q4.2 (kill criteria — когда проект надо остановить)
- **Блок 5 "Неизвестное"** (новый): Q5.1 (что не знаем), Q5.2 (что может остановить проект)
- **idea.md шаблон** обновлён: добавлены поля As-Is, To-Be, Deployment Constraint, Recovery Expectation, Alert Channel, Monitoring Expectation, Existing Monitoring, Delivery Scope, Kill Criteria, Критерии успеха, Неизвестное, Риски и стопперы

#### s1-pm — Operational Tier Selection и Veto Protocol
- **Таблица использования полей idea.md**: 11 полей → где применяются в Feasibility/Vision (явное правило: данные стейкхолдера приоритетнее предположений)
- **Operational Tier Selection** (матрица Tier 0–3):
  - Topology × Recovery → базовый тир
  - Описание каждого тира (что включено, для чего подходит)
  - Корректировка по Q3.8 (Monitoring), Q3.9 (Delivery Scope), Q3.10 (Existing Monitoring)
  - Валидация противоречий: 4 противоречия с сообщениями стейкхолдеру
- **Протокол Вето** (Stakeholder Gate): презентация плана → чекпоинт после каждой секции → veto/edit/stop/restart — агент адаптирует ВЕРДИКТ при пропуске секций
- **Параметрические флаги**: skip:legal/finance/operational/technical, budget:N, mode:auto, scope:minimal
- **DoR обновлён**: добавлены проверки Q3.6/Q3.7/Q3.8/Q3.9 в idea.md

#### s1-pm/feasibility.md — полная переработка slash-команды
- 4-шаговая структура: разбор аргументов → чтение входных данных → презентация плана с вето → создание артефакта
- Чекпоинт-протокол после каждой секции (Technical/Economic/Operational/Legal/Риски/Вердикт)
- **`## → Handoff`** — структурированный YAML в конце артефакта:
  - `decisions`: verdict, operational_tier, deployment_topology, delivery_scope, alert_channel, existing_monitoring
  - `inherited_nfr`: список NFR-требований для перевода в BA-NFR.md
  - `architectural_constraints`: ограничения для проектирования HLD
  - `infrastructure_constraints`: требования для реализации DevOps
  - `open_issues`, `skipped_sections`

#### s1-pmo — PMO-constraints.md как обязательный выход
- Новый обязательный артефакт: `tracking/PMO-constraints.md` (без даты в имени, перезаписывается)
- Формат файла: scope, budget, operational, critical_risks, open_issues, mandatory_standards
- Правило: читать `PM-Feasibility → Handoff` ПЕРВЫМ до основного текста
- DoD обновлён: добавлена проверка tracking/PMO-constraints.md

#### Единый файл ограничений — PMO-constraints.md читается всеми downstream агентами первым
- **s2-ba**: PMO-constraints.md → первый в списке чтения; `Handoff → inherited_nfr` → каждый пункт = NFR с числовым порогом
- **s3-arch**: PMO-constraints.md → первый; `architectural_constraints` → учесть при проектировании HLD
- **s3-security**: PMO-constraints.md → первый; `critical_risks` → помечать `[PMO-RISK-N]` в Threat Model
- **s4-devops**: PMO-constraints.md → первый; DoR проверяет что все OI с `blocker_for: s4-devops` закрыты

### Fixed

#### Изоляция агентов — 9 нарушений устранено
Ключи Handoff YAML содержали имена агентов — s1-pm знал об их существовании:
- `nfr_for_s2ba` → `inherited_nfr` (semantic, agent-agnostic)
- `constraints_for_s3arch` → `architectural_constraints`
- `constraints_for_s4devops` → `infrastructure_constraints`
- Комментарий `# s2-ba обязан...` → нейтральный
- Комментарий `# s3-arch учитывает...` → нейтральный
- Комментарий `# s4-devops реализует...` → нейтральный
- HTML-комментарий «читается следующими агентами» → удалён
- `owner: "s2-ba / s3-arch"` в open_issues → `owner: "роль / стейкхолдер"`
- `s1-pmo`: «Читай от s1-pm» → «Читай PM-Feasibility:»

---

## [1.6.0] — 2026-05-23

### Added

#### Методология выбора архитектурных паттернов (s3-arch) — 7 правил
- **Правило 1**: паттерн только при наличии проблемы — запрещено добавлять "про запас"
- **Правило 2**: цепочка QA → Tactic → Pattern — каждый паттерн проходит путь через Quality Attribute из NFR (таблица 10 QA → 30+ паттернов)
- **Правило 3**: NFR-порог → Паттерн — таблица: availability, error_rate, RPO, RTO, наличие внешних API → обязательный набор паттернов
- **Правило 4**: топология деплоя → фильтр паттернов — single-container / multi-instance / serverless × 9 паттернов
- **Правило 5**: выбор архитектурного стиля — условие из BRD → Monolith / Microservices / CQRS / Saga / Event-Driven / BFF / API Gateway
- **Правило 6**: выбор протокола — условие → REST / GraphQL / gRPC / Message Queue / WebSocket с обоснованием
- **Правило 7**: трейдофф обязателен (ATAM) — таблица "выигрываем / платим" для 6 паттернов; без трейдоффа ADR не засчитывается

#### Методология выбора контролей безопасности (s3-security)
- **STRIDE → Security Control**: каждой угрозе — конкретная контрмера (Spoofing→Auth, Tampering→TLS+HMAC, Repudiation→AuditLog, InfoDisclosure→Encryption+RLS, DoS→RateLimit+CB, EoP→RBAC+DenyByDefault)
- **DREAD score → действие**: Critical(>8) блокирует Gate 3; High(6-8) контрмера до Gate 3; Medium → митигация в спринте; Low → ADR
- **Выбор механизма аутентификации**: OAuth2 / mTLS / JWT / MFA — по условию из BRD

#### Методология выбора технологии хранения (s3-dba)
- **Характеристики данных → Технология**: PostgreSQL (default) / Redis (кэш) / MongoDB (только с ADR) / FTS / TimescaleDB — с условием "когда НЕ использовать"
- **NFR → Паттерн доступа**: CQRS+ReadReplica / Event Sourcing / Partitioning / ConnectionPool+Cache / Expand-Contract / RLS (мультитенантность)

#### Deployment Constraint — новая обязательная категория NFR (s2-ba)
- Категория "Deployment" добавлена в список NFR: `DC-1: Deployment Constraint = single-container | multi-instance | serverless`
- Фиксируется в `BA-NFR.md` до начала `s3-arch`; определяет применимость паттернов в Gate 6
- Добавлен в Quality Gate checklist s2-ba; если не указано явно — уточнять у стейкхолдера

#### Topology-Aware Auto-Heal (s4-devops + quality.md §5.5)
- Все пункты Auto-Heal чеклиста помечены `[SC]` / `[MI]` / `[SL]` по топологии
- Readiness Probe: применима только для `[MI]` (multi-instance)
- Circuit Breaker / Watchdog / DLQ: добавлены условия применимости (только если есть deps/воркеры/очереди)
- Неприменимый пункт ≠ BLOCKER, но требует документирования причины в runbook
- `quality.md §8` — три новых запрета: паттерн без QA-обоснования, паттерн "про запас", отсутствие Deployment Constraint

### Fixed

#### Изоляция агентов — 3 нарушения в s3-dba (внесённые в этом цикле)
- `s3-dba:25` `"согласованием s3-arch"` → `"ARCH-ADR в stage3-design/outputs/"`
- `s3-dba:33` `"s3-arch проектирует, s3-dba реализует"` → `"если ARCH-HLD.md содержит CQRS"`
- `s3-dba:109` `"согласования с s3-security"` → `"из SEC-*-threat-model.md"`

---

## [1.5.0] — 2026-05-22

### Added

#### DoR — полная реализация 7 лучших практик
- **`quality.md §1`** полностью переработан: бинарность, колонки "Кто обеспечивает / Кто проверяет / Этап / Проверка", дедлайны готовности, правило возврата (4 шага), таблица сброса DoR при Change Request
- **DoR добавлен в 4 агента** (ранее отсутствовал): `s3-arch` (Gate 2, 6 пунктов), `s5-qa` (Gate 4, 7 пунктов), `s6-release` (Gate 5, 7 пунктов), `s6-sre` (Gate 6 + Gate 7, 11 пунктов)
- **`_standards/dor-violations-template.md`** — шаблон журнала нарушений DoR с форматом записи (дата, агент, нарушенные пункты, статус, дата устранения)
- **`s0-kickoff /cr`** — новый режим Change Request: структурированное интервью, Impact Analysis, сброс затронутых DoR-пунктов, CR-файл в inputs/, запись в dor-violations.md
- **`s0-validate /dor-check [N]`** — автоматическая проверка DoR перед переходом на Gate N
- **`dor-check.sh`** — bash-скрипт автопроверки: DoR-1 (файлы), DoR-2 (маркеры), DoR-3 (Given/When/Then), DoR-4 (числа в NFR), DoR-5 (BLOCKER grep), DoR-7 (threat model), DoR-8 (rollback)

#### DoD — полная реализация 8 лучших практик
- **`quality.md §2`** полностью переработан: бинарность, колонки "Кто обеспечивает / Кто проверяет / Проверка", матрица применимости по 3 типам артефактов, связь DoD-10 → DoR-1, правило технического долга
- **Типы артефактов DoD**: Тип К (Код, все 11 пунктов), Тип Д (Документ, 6 пунктов), Тип И (Инфраструктура, 9 пунктов)
- **Связь DoD → DoR**: DoD-10 выполнен = DoR-1 следующего этапа выполнен автоматически (таблица по всем 6 переходам)
- **Технический долг**: правило фиксации осознанных пропусков DoD, блокировки при > 3 открытых TD
- **`_standards/tech-debt-template.md`** — шаблон журнала техдолга с форматом TD-записи (причина, кто одобрил, план устранения, дедлайн)
- **`s0-validate /dod-check [TYPE] [STAGE] [PR]`** — автоматическая проверка DoD по типу артефакта
- **`dod-check.sh`** — bash-скрипт: DoD-1 (complexity прокси), DoD-2 (coverage report / тест миграций), DoD-3 (TL-review файл), DoD-5 (CHANGELOG), DoD-6 (update notes), DoD-8 (secrets grep), DoD-10 (outputs/), DoD-11 (тесты форматов)

#### s0-tracker — контроль техдолга и возвратов DoR
- Инициализация `dor-violations.md` и `tech-debt.md` при первом `/sprint-init`
- При `/sprint-close`: блокировка если есть просроченные TD
- При `/sprint-init`: сводка открытых TD
- При `> 3` открытых TD: блокировка старта следующего спринта

### Fixed

#### Изоляция агентов — 8 нарушений принципа устранено
Все формулировки прямой межагентной коммуникации заменены на файловую передачу данных через `tracking/`:
- `quality.md §1` — "Вернуть список агенту-поставщику" → "Записать в dor-violations.md"
- `quality.md §2` — "Артефакт передан следующему агенту" → "Артефакт записан в outputs/"
- `s5-qa` — "вернуть задачу в s4-dev" → "зафиксировать в dor-violations.md, пользователь перезапускает"
- `s6-release` — аналогично для s5-qa
- `s6-sre` — аналогично для s6-release
- `s0-kickoff CR` — "Агенты к уведомлению" → "Пользователю перезапустить (через sdlc.sh)"
- `dod-check.sh` — "не передан следующему агенту" → "не записан в outputs/"

---

## [1.4.0] — 2026-05-11

### Added

#### Skills (slash-команды) для 11 агентов — 18 новых команд
Все агенты теперь имеют slash-команды. Ни один агент не требует задачи «свободным текстом».

| Агент | Новые команды |
|-------|--------------|
| `s1-finance` | `/business-case` — Business Case (NPV, ROI, TCO, сценарный анализ) |
| `s2-qa-req` | `/testability-review` — Testability Review + Gate 2 вердикт |
| `s3-dba` | `/schema` — DB Schema (PostgreSQL, UUID v4, TIMESTAMPTZ) |
| `s3-dba` | `/migration` — Alembic Migration Runbook (upgrade + downgrade) |
| `s3-security` | `/threat-model` — Threat Model (STRIDE + DREAD + OWASP Top 10) |
| `s4-dev` | `/dev-report` — Dev Report по завершённому PR |
| `s4-dev` | `/update-notes` — Update Notes для PR (обязательно после каждого PR) |
| `s4-techlead` | `/review` — Code Review с DoD checklist + Gate 4 вердикт |
| `s4-devops` | `/pipeline` — CI/CD pipeline (lint→test→build→SAST→secrets-scan) |
| `s4-devops` | `/runbook` — Runbook деплоя с rollback-процедурой и observability |
| `s5-qa` | `/test-plan` — Test Plan с тест-кейсами (IEEE 829) |
| `s5-qa` | `/go-no-go` — Go/No-Go решение + Gate 5 вердикт |
| `s5-qa-auto` | `/e2e-report` — E2E/API Automation Report + coverage |
| `s5-perf` | `/load-test` — Load Test (smoke/load/stress/soak) + вердикт |
| `s6-sre` | `/post-deploy` — Post-Deploy Report (мониторинг T+0..T+60) |
| `s6-sre` | `/gate7` — Gate 7: SLO Review + Auto-Heal + Incident Runbooks |

#### CYCLE_AGENTS — полный переход на slash-команды
- Все шаги полного цикла теперь используют `/slash-команды` вместо свободного текста
- Добавлены ранее отсутствующие шаги: `/runbook` (s4-devops), `/release-notes` (s6-release), `/gate7` (s6-sre)
- Цикл расширен с 23 до 26 шагов

### Fixed

#### Bash cwd drift — агенты больше не покидают свою директорию
- **Проблема**: bash-состояние в Claude Code персистентно в рамках сессии. При выполнении `cd /path && cmd` директория менялась для всех последующих вызовов.
- **`sdlc.sh`**: все три точки запуска агентов экспортируют `AGENT_DIR="$agent_dir"` — агент знает домашнюю директорию через переменную окружения.
- **`CLAUDE.md`**: добавлен раздел «Рабочая директория» с правилом подоболочки: `(cd /path && cmd)` вместо `cd /path && cmd`.

---

## [1.3.0] — 2026-05-10

### Added

#### s0-kickoff — Project Kickoff Facilitator (новый агент)
- Новый агент этапа 0: структурированный онбординг для новых и существующих проектов
- Режим **NEW**: 4 блока интервью (Продукт / Бизнес / Техника / Приоритеты), ~19 вопросов
  - Вопросы задаются последовательно, по одному; после каждого блока — резюме и подтверждение
  - Выход: заполненный `idea.md` + `PM-input-interview-YYYY-MM-DD.md`
- Режим **REFRESH**: меню из 5 разделов обновления (Видение/OKR, Беклог, Приоритеты, NFR, Scope Out)
  - Показывает текущий статус проекта из Dashboard.md
  - Целевое интервью только по выбранным разделам
  - Выход: `PM-input-refresh-*.md` и/или `BA-input-refresh-*.md`
- Авто-определение режима (`/start`): new vs refresh по наличию артефактов этапа 1
- Slash-команды: `/start`, `/new`, `/refresh`
- Интеграция в `sdlc.sh`: пункт `0) Kickoff` в главном меню (первый пункт)
- После создания нового проекта (`пункт 3`) — автоматическое предложение запустить `/new`

#### s3-rbac — RBAC Designer (новый агент)
- Новый агент этапа 3: проектирование ролевой модели доступа
- Принципы: Least Privilege, Deny by Default, SoD, Role Hierarchy, Resource Ownership
- Артефакты: `RBAC-model.md` (роли, иерархия), `RBAC-matrix.md` (роль × ресурс × действие), `RBAC-schema.sql` (таблицы + RLS)
- PostgreSQL Row-Level Security политики для owner-only ресурсов
- Выявление и документирование SoD-конфликтов
- Slash-команды: `/rbac-model`, `/rbac-matrix`
- Вставлен в SDLC-цикл между `s3-security` и `s3-dba` (шаг 11)

#### s4-dev — шаблоны реализации RBAC
- Новый раздел в `s4-dev/CLAUDE.md`: RBAC — Реализация (FastAPI + SQLAlchemy)
- Шаблон `require_permission()` dependency для FastAPI (deny by default)
- Шаблон `has_permission()` — SQL-запрос к RBAC-таблицам
- Шаблон owner-only: двойная проверка (application-level + PostgreSQL RLS)
- Шаблон наследования ролей через рекурсивный CTE
- Правило: запрет хардкода ролей в бизнес-логике (`if role == "admin"`)
- Шаблон `tests/test_rbac.py` с 5 обязательными тестами (deny-by-default, grant, hierarchy, owner-only, SoD)
- Gate 4 RBAC checklist (5 пунктов DoD)

#### _standards/data-formats.md (новый стандарт)
- Канонический стандарт форматов данных для всей системы
- §1 PostgreSQL↔ORM↔Python типы: 8 типов + таблица запрещённых форматов
- §2 ENV-переменные: форматы по Python-типу, 7 обязательных полей документирования
- §3 API/JSON контракты: datetime ISO 8601 UTC, UUID v4 строка, стандарт ошибок
- §4 Шаблоны обязательных тестов: `test_env_format.py`, `test_db_format.py`, `test_api_format.py`
- §5 Чеклисты для каждого агента (s2-ba, s3-dba, s4-dev)
- §6 Gate 3/4 условия по форматам

#### Документация
- `GETTING_STARTED.md` — подробное руководство первого запуска (новый файл)
- `CHANGELOG.md` — история изменений (этот файл)
- `README.md` — обновлён раздел "Быстрый старт": kickoff как обязательный шаг, таблица режимов
- `OVERVIEW.md` — добавлен раздел `s0-kickoff`, обновлено меню лаунчера

### Changed

#### Quality Gates (quality.md)
- **Gate 3** — добавлены 5 RBAC-условий:
  - `RBAC-*-model.md` существует: все роли покрыты, иерархия описана
  - `RBAC-*-matrix.md` существует: матрица полная (роль × ресурс × действие)
  - `RBAC-*-schema.sql` существует: таблицы + RLS политики
  - SoD-конфликты выявлены и задокументированы
  - Owner-ресурсы защищены RLS-политиками
- **Gate 3** — добавлены 5 условий по форматам данных
- **Gate 4** — добавлены 7 условий по тестам форматов

#### Definition of Done
- **DoD** расширен с 10 до 11 пунктов
- **DoD-11** (новый): тесты форматов данных написаны и проходят (`test_env_format.py` / `test_db_format.py` / `test_api_format.py` — если применимо)

#### sdlc.sh
- Пункт `0) Kickoff` добавлен в главное меню (перед пунктом 1)
- Функция `menu_kickoff()` с выбором режима (new / refresh / auto)
- `menu_new_project()` предлагает запустить kickoff после создания проекта
- `s3-rbac` добавлен в SDLC-цикл как шаг 11 (между s3-security и s3-dba)
- `s0-kickoff` добавлен в группу инфраструктуры в меню одного агента
- Необязательные шаги цикла — toggle UI для выбора пользователем

#### s4-dev/CLAUDE.md
- Gate 3 entry check: добавлена проверка `RBAC-*-model.md` и `RBAC-*-matrix.md`
- Правило: при реализации авторизации читать RBAC-артефакты и реализовывать права строго по матрице
- Изменения в RBAC требуют обновления RBAC-артефактов через s3-rbac

#### s0-validate/CLAUDE.md
- Проверка RBAC-артефактов для завершённых Stage 3:
  - `RBAC-*-model.md` существует в stage3/outputs/
  - `RBAC-*-matrix.md` существует в stage3/outputs/

#### s2-ba/CLAUDE.md
- Читает `data-formats.md` (добавлен в стандарты)
- Расширена таблица документирования ENV-переменных (7 обязательных полей)
- Добавлены правила для datetime, UUID, NUMERIC, JSONB, Enum в требованиях
- Gate 2 exit checklist расширен 7 format-пунктами

#### s3-dba/CLAUDE.md
- Читает `data-formats.md` (добавлен в стандарты)
- Расширены шаблоны документирования: JSONB, ENUM, CHECK, NUMERIC
- Gate 3 checklist расширен 8 format-пунктами

---

## [1.2.0] — 2026-05-10

### Added
- **Markdown-first документация** — описание того, что вся система построена на `.md` файлах
- **Obsidian integration** — раздел в README с инструкцией по использованию vault в Obsidian
- Таблица функций Obsidian (Graph View, Wiki-links, YAML frontmatter, Tags, Dataview)
- Описание структуры vault в Obsidian
- Workflow: Obsidian + агенты (пошаговый пример)

### Changed
- `README.md` — добавлен раздел "Markdown-first и Obsidian"
- `OVERVIEW.md` — обновлены описания Obsidian-возможностей

---

## [1.1.0] — 2026-05-10

### Added
- **Необязательные шаги в sdlc.sh** — toggle UI для выбора дополнительных шагов цикла
  - 4 предустановленных необязательных шага (s0-validate before/after, s0-secrets, s0-tracker)
  - Нумерованное меню переключения вкл/выкл перед запуском полного цикла
- **`_standards/data-formats.md`** — новый канонический стандарт форматов данных
- **`.gitignore`** — исключены `settings.local.json`, `.env`, `.DS_Store`

### Changed
- Скрипты перемещены из `_bin/` в `_agents/` — `sdlc.sh` и `localrun.sh` теперь в корне `_agents/`
- Обновлены все пути в документации: `_bin/sdlc.sh` → `_agents/sdlc.sh`
- `CLAUDE.md`, `OVERVIEW.md`, `Local_Run/_workflow.md` — обновлены пути запуска

### Removed
- Директория `_bin/` — скрипты перемещены в `_agents/`

---

## [1.0.0] — 2026-05-10

### Added
- Initial commit — Claude SDLC Agents system
- Специализированные агенты: s0-secrets, s0-validate, s0-tracker, s1-pm, s1-pmo, s1-finance, s2-ba, s2-po, s2-qa-req, s3-arch, s3-security, s3-dba, s4-dev, s4-techlead, s4-devops, s5-qa, s5-qa-auto, s5-perf, s6-release, s6-sre, l1-analyze, l2-setup, l3-build, l4-run
- `sdlc.sh` — интерактивный лаунчер с полным SDLC-циклом
- `_standards/quality.md` — DoD (10 пунктов), DoR (8 пунктов), 7 Quality Gates, NFR-дефолты, Auto-Heal паттерны
- `_standards/company.md` — шаблон стандартов компании (стек, роли, методология)
- `README.md` — документация проекта
- `OVERVIEW.md` — полный обзор системы

### Known Pitfalls (зафиксированы в s4-dev/CLAUDE.md)
- pydantic-settings v2: list/set в .env требует JSON-формат `[1,2,3]`
- asyncpg + SQLAlchemy: обязательно `TIMESTAMP(timezone=True)`
- Alembic: `fileConfig(..., disable_existing_loggers=False)` обязателен
- aiogram: `callback.message.bot` может быть `None` — инжектировать через параметр
- Parse mode: HTML вместо Markdown v1

---

[Unreleased]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.002.000...HEAD
[2.002.000]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.001.001...v2.002.000
[2.001.001]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.001.000...v2.001.001
[2.001.000]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.000.004...v2.001.000
[2.000.004]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.000.003...v2.000.004
[2.000.003]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.000.002...v2.000.003
[2.000.002]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.000.001...v2.000.002
[2.000.001]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v2.000.000...v2.000.001
[2.000.000]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.7.1...v2.000.000
[1.7.1]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/fr0sttr3000/Claude-SDLC-agents/compare/v1.0.0...v1.0.0
