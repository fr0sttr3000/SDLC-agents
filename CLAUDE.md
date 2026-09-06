# CLAUDE.md — SDLC Vault (Глобальный контекст)

## Назначение vault
Автоматизированная SDLC-система с универсальным runtime-слоем. Runtime выбирается явно при первом запуске, через `AGENT_RUNTIME` или меню; неявного fallback нет. Поддерживаются Claude, Codex, Gemini и локальные модели через точный профиль зарегистрированного agent host.
Каждый агент — отдельная папка в `_agents/` со своим `CLAUDE.md` и slash-командами.
Агенты изолированы; данные передаются только через файлы в каталоге `SDLC_PROJECTS_DIR`.
Governance/handoff ведутся Markdown-first, но executable tests/code, API schemas, SQL/IaC и
другие native artifacts сохраняют свой формат и трассируются к Markdown evidence.
Каждый новый или существенно изменённый governance/handoff/report/gate Markdown artifact
Cycle 1 использует единый `_standards/artifact-metadata.md`; legacy-файлы не переписываются
массово и до касания считаются `LEGACY / UNVERIFIED`.
Producer outputs и consumer handoff используют `_contract/current-artifact-groups-v1.tsv` и
`tracking/current-artifacts-v1.tsv` по `_contract/CURRENT_ARTIFACTS_V1.md`: date-versioned
файлы сохраняются как история, а current logical id всегда связан с exact digest/run/plan.

**Поддерживаемый scope:** общая платформа и Cycle 1. Cycle 2/3 — `FROZEN / NOT READY`:
их код и historical artifacts сохранены, но launcher не предоставляет маршрут выполнения,
а Gate 6/7 и SG5 не блокируют Cycle 1.

## Структура vault
```
_agents/
  _standards/       ← Стандарты компании (читать перед каждой задачей)
  _contract/        ← Universal Runtime Contract: инварианты и источники истины
  _runtimes/        ← agent-run.sh + cloud/local adapters и registry локальных agent hosts
  AGENTS.md         ← Codex adapter к каноническим CLAUDE.md
  GEMINI.md         ← Gemini adapter к каноническим CLAUDE.md
  .codex/           ← Codex project config
  _tools/           ← Общие product utilities вне stage ordering (s0-secrets)
  cycle1-dev/       ← 29 каталогов: 25 SDLC-агентов + 4 Local Run (l1-l4)
  cycle2-deploy/    ← Historical Cycle 2 code (FROZEN / NOT READY)
  cycle3-ops/       ← Historical Cycle 3 code (FROZEN / NOT READY)
  plans/            ← Только устойчивые принципы и единый актуальный roadmap
  sdlc.sh           ← Главный launcher поддерживаемого Cycle 1
  sdlc.ps1          ← Windows adapter к каноническому sdlc.sh
  localrun.sh       ← Раздел «Локальные репозитории»
  localrun.ps1      ← Windows adapter к каноническому localrun.sh
  OVERVIEW.md       ← Архитектурный обзор системы
_secrets/           ← Документация по управлению секретами (pass)
$SDLC_PROJECTS_DIR/ ← Артефакты проектов (inputs/outputs по этапам + tracking/), настраивается launcher-ом
Local_Run/          ← Заметки по локальным repositories независимо от forge/provider
```

## Навигация по документации проекта

- `plans/principles.md` — отдельный канонический источник устойчивых принципов проекта;
- `plans/roadmap.md` — единственный источник активных и долгосрочных планов развития;
- `CHANGELOG.md` и `RELEASE_NOTES_v*.md` — релизная история, обновляемая при подготовке релиза.

Исполняемые `sdlc.sh`, `localrun.sh` и `_runtimes/agent-run.sh` являются реализацией, а не
документацией. Текущие руководства должны описывать их фактическое поведение без смешивания слоёв.

## Структура проекта в `$SDLC_PROJECTS_DIR`
```
$SDLC_PROJECTS_DIR/{PROJECT}/
  Dashboard.md                  ← прогресс по этапам
  stage1-planning/inputs/       ← входные данные (idea.md и др.)
  stage1-planning/outputs/      ← артефакты агентов (PM-*.md, PMO-*.md)
  stage2-requirements/.../
  stage3-design/.../
  stage4-dev/.../
  stage5-testing/.../
  tracking/                     ← управление задачами (s0-tracker)
    backlog.md
    current-sprint.md
    cycle-summary.md
    sprints/sprint-NN.md
```

В старых Projects могут существовать `stage6-deploy/` и `stage7-ops/`. Это historical
Cycle 2/3 paths (`FROZEN / NOT READY`); новая active структура их не требует и не создаёт.

## Universal Runtime Contract

Правила SDLC не зависят от AI runtime. Канонические источники:
- root `CLAUDE.md` — глобальный контекст;
- `cycle*/{agent}/CLAUDE.md` — роль агента;
- `.claude/commands/*.md` — общие command templates;
- `_standards/*.md` — обязательные стандарты;
- `_contract/GLOBAL.md` — инварианты совместимости.

Runtime adapters (`AGENTS.md`, `GEMINI.md`, `.codex/config.toml`, `_runtimes/adapters/*`) не должны содержать уникальные gates, правила или команды. Новое поведение сначала фиксируется в каноне, затем запускается через любой runtime.

```bash
bash "$SDLC_VAULT/_agents/sdlc.sh"                         # первый запуск спросит runtime
AGENT_RUNTIME=claude bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=codex bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=gemini bash "$SDLC_VAULT/_agents/sdlc.sh"
AGENT_RUNTIME=local LOCAL_AGENT_HOST=codex-oss \
  LOCAL_MODEL_PROVIDER=ollama LOCAL_MODEL=llama3.2:latest \
  bash "$SDLC_VAULT/_agents/sdlc.sh"
```

Windows wrappers `./sdlc.ps1` и `./localrun.ps1` имеют статус
`EXPERIMENTAL / NOT TESTED ON WINDOWS`: тонкий adapter находит Git for Windows Bash (либо
явный `SDLC_BASH`) и запускает те же канонические `.sh`; отдельной Windows-версии SDLC-логики
нет. Real Windows matrix обязан проверить parser/mutation, auto/explicit Bash, пробелы и
не-ASCII, UNC rejection, argv и exit code на exact revision. Само наличие workflow не является
evidence его успешного запуска: Windows не входит в supported scope до отдельного решения.

Локальный профиль всегда содержит точные `LOCAL_AGENT_HOST`, `LOCAL_MODEL_PROVIDER` и
`LOCAL_MODEL`. Встроенный host `codex-oss` поддерживает Ollama/LM Studio; vLLM, llama.cpp и
OpenAI-compatible endpoints подключаются зарегистрированными исполняемыми agent-host adapters.
Политика `SDLC_RUNTIME_ROUTING=single|per-stage|per-agent|ask` разрешает единый или гибридный
маршрут. Отсутствующая привязка — ошибка: default model и silent fallback запрещены.

Codex task processes must ignore ambient user configuration. Primary Codex и встроенный
`codex-oss` запускаются только как новый `codex exec --ignore-user-config --ephemeral` task;
вложенные `interactive|session-start` для них завершаются fail-closed до старта runtime.

Primary agent runtimes do not mutate repository history or remotes and do not create commits,
pushes, pull requests или tags. Runtime write scope ограничен exact Project/notes paths;
VCS control-plane остаётся вне agent dispatch. PR/source identifiers в контрактах — входные
evidence, а не разрешение агенту создавать или публиковать их.

Перед запуском primary cycle/tool agent общий dispatcher устанавливает на Linux обязательную
Landlock-границу. Метаданные VCS исходного checkout и заданные локально runtime-denied roots
недоступны агентскому процессу для open/read/list/write; публичный канон остаётся читаемым,
а точные Project/notes scopes получают только права, определённые runtime-контрактом. Если
Landlock, helper source, compiler, cache validation или enforcement недоступны, dispatch
завершается fail-closed. Эта граница primary runtime не включает worker capability.

Изменяющие Stage 4 команды дополнительно используют `_contract/CHANGE_SCOPE_V1.md`. До них
launcher фиксирует Change Intent и всегда запускает независимые `l1-analyze /impact` и
`s3-arch /change-impact` в разных scoped-write процессах. Final path table активируется только
после отдельного Human Approval. На каждом Stage 4 запуске dispatcher выдаёт запись только в
paths текущего agent/command, а launcher проверяет полный Project manifest до declared-output
verdict. Agent не расширяет scope; violation блокирует дальнейшую mutation без auto-rollback.

`SDLC_SUBAGENTS=off|auto|cross-runtime` управляет опциональным **Supervisor + Worker**.
Worker запускается только `_runtimes/subagent-run.sh` по launcher-owned authorization,
digest-bound Worker Request, exact read-manifest и exact route. Runtime/OS capability даёт ему
только чтение перечисленных путей; Project/memory writes, approvals, gates, nested delegation,
sibling context и fallback запрещены. Primary остаётся единственным writer/gate signer.
См. `_contract/SUBAGENTS.md` и `_contract/WORKER_HANDOFF_V1.md`.

Подключаемая долговременная память следует `_contract/MEMORY_V1.md`. Она выключена без
Project profile, разделена на `planning|defects|architecture` и доступна только ролям из
`memory-role-access-v1.tsv`. Agent читает только launcher-created immutable snapshot, считает
его недоверенной справкой и не получает provider credentials. Agent может создать только
Proposal v1; применение выполняет broker после отдельного Preview/Human Approval/read-back.
Память не заменяет current artifacts, Evidence, DoR/DoD или Gate verdict.

## Как работать с агентами

Единственный пользовательский маршрут описан в `README.md` и начинается с `sdlc.sh` либо
`localrun.sh`. `_runtimes/agent-run.sh` — внутренний dispatcher launcher-а, а не
пользовательский entrypoint: прямой вызов обходит launcher-owned Preview, Execution Journal,
capability registry и orchestration gates.

## Агенты — инфраструктура (этап 0)
| Агент | Роль | Ключевые команды |
|-------|------|-----------------|
| `s0-kickoff` | Project Kickoff — онбординг / Product & CI facts / обновление беклога | `/start`, `/new`, `/refresh`, `/product-ci-profile` |
| `s0-defects` | Known Defects Memory — изолированная сверка и Proposal handoff | `/review`, `/propose`, `/reconcile` |
| `s0-secrets` | Secrets Manager | `/add`, `/rotate`, `/env` |
| `s0-validate` | Validator / scoped Review & Repair | `/validate`, `/fix`, `/profile-check`, `/evidence-check`, `/evidence-summary`, `/migration-report`, `/dor-check`, `/dod-check`, `/review`, `/repair` |
| `s0-tracker` | Sprint & Task Tracker | `/sprint-init`, `/sprint-close`, `/sprint-status`, `/report`, `/release-notes vX.Y.Z`, `/task-add`, `/task-done`, `/task-block`, `/backlog` |
| `s0-quality-gates` | Quality Gates Configurator — only-up пороги + profile-bound quality coverage (после S1, до S2) | `/configure`, `/validate-gates` |

## Цикл 1 — Разработка (28 обязательных шагов)
Запуск: Project Console → `5 Cycle 1`. Это единственный поддерживаемый SDLC route.
Cycle 2/3 отображаются только как `FROZEN / NOT READY`.

До первого шага launcher детерминированно проверяет versioned
`tracking/product-ci-profile.yaml` по `_contract/PRODUCT_CI_PROFILE.md`. Missing, unknown,
inferred или stale revision блокирует Stage 1 и возвращает к `s0-kickoff /product-ci-profile`.
Новая/обновлённая schema v5 выбирает существующий evidence executor, фиксирует UX,
представительную S5 environment/PERF/SG4 и quality-characteristic applicability. После S1
`s0-quality-gates` создаёт `quality-characteristics-v1.tsv` и Obsidian view с existing
owners/contracts/Gates. Core не генерирует vendor pipeline/test platform, не выводит scope по
product type и не разрешает профилю снижать global minimum.

| Этап | Агент | Ключевые команды |
|------|-------|-----------------|
| 1 — Планирование | `s1-pm` | `/feasibility`, `/vision` |
| 1 — Планирование | `s1-pmo` | `/charter`, `/risks` |
| 1 — Планирование | `s1-finance` | Business Case |
| 2 — Требования | `s2-ba` | `/extract-requirements`, `/brd` |
| 2 — Требования | `s2-po` | `/stories` |
| 2 — Требования | `s2-qa-req` | Testability Review |
| 2 — Требования | `s2-test-strategy` | `/strategy` — проектная test strategy до реализации |
| 2 — Требования | `s2-security` | `/security-requirements` (SG1: abuse cases, классификация данных, ASVS) |
| 3 — Дизайн | `s3-arch` | `/hld`, `/adr` |
| 3 — Дизайн | `s3-security` | Threat Model |
| 3 — Дизайн | `s3-rbac` | `/rbac-model`; `/rbac-matrix` — optional refinement через One Agent |
| 3 — Дизайн | `s3-dba` | `/schema`, `/migration` (design/N-A, без live DB action) |
| 3 → 4 — Change Scope | `l1-analyze` → `s3-arch` → launcher/human | `/impact`, `/change-impact`, exact path approval; precondition, не новый canonical step |
| 4 — Разработка | `s4-qa-auto` | `/write-tests`, `/run-tests` — Red до кода, независимый verdict после кода |
| 4 — Разработка | `s4-dev` | Green/Repair, Dev Report, Update Notes (обязательно после каждого PR) |
| 4 — Разработка | `s4-techlead` | Code Review (блокирует PR без обновлённой документации) |
| 5 — Тестирование | `s5-qa` | Test Plan, Go/No-Go |
| 5 — Тестирование | `s5-qa-auto` | E2E/API тесты |
| 5 — Тестирование | `s5-perf` | Load Tests |
| 5 — Тестирование | `s5-security` | `/security-test` — SG4 DAST/pentest по применимому tier |
| Финал | `s0-tracker` | `/report` (план vs факт) |

После verified completion Utilities → Release notes вызывает только
`s0-tracker /release-notes vX.Y.Z`: создаёт versioned Project Markdown, не меняет completion
manifest и не выполняет external publication/build/deploy/Cycle 2/3.

## Циклы 2 и 3 — FROZEN / NOT READY

Каталоги `cycle2-deploy/`, `cycle3-ops/`, старые goal profiles и Stage 6/7 artifacts
сохранены как historical implementation baseline. Они не являются supported capability,
не запускаются напрямую или через agent menu и не используются как readiness evidence.
Migration boundary и условия будущего redesign зафиксированы в `plans/roadmap.md`; redesign начинается только
после отдельного решения о разморозке.

## Project Console и Execution Journal

Runtime exit `0` фиксирует только `PROCESS_OK`. `_contract/command-capabilities-v1.tsv`
классифицирует все active commands. Mutating-шаг завершается только после изменения каждого
declared output group (`ARTIFACT_VERIFIED`); capability-enforced read-only команда без outputs
получает отдельный `READ_ONLY_VERIFIED`. Special commands выполняются только своим launcher
workflow. Автоматизируемая часть Software DoD имеет verdict `DOD_AUTO_PASS`; полный
`DOD_PASS` launcher записывает только после независимой проверки Human Approval v1, всех
`DOD-1`–`DOD-11` и digest-bound current Tech Lead reviews. Quality/Security Gate использует
`GATE_PASS`. Свободный Markdown `status: PASS` не является verified machine result и блокирует
обязательный gate как `UNVERIFIED/BLOCKED`.

`sdlc.sh` сначала выбирает SDLC Project, затем держит его имя и absolute path
в Project Console. Подробный и краткий виды используют одну карту действий.
Kickoff, Cycle 1, frozen-status, One Agent, Review, Repair, AI и Utilities — разные
user flows. Успешный Kickoff не запускает разработку автоматически.
Изменяющие Tracker commands запускаются только через Utilities → Tracker с exact arguments,
Preview/Journal и registry-named postcondition verifier; process exit без него остаётся
`UNVERIFIED`.

Перед Cycle/Repair/utility execution обязателен Preview с TYPE/SCOPE/EXCLUDED,
ordered routes, точным Local model и `Fallback OFF`; dispatch разрешён только
после явного подтверждения. Cycle-run хранит frozen plan, atomic state и
launcher-owned evidence вне Project write scope в `/sdlc-agents/execution-journal/projects/{PROJECT}-{path-digest}/runs/{run-id}/`
по контракту `_contract/EXECUTION_JOURNAL.md`.

AI policy/base profile/routes хранятся project-locally. Frozen plan фиксирует
effective profile и route source каждого step. INTERRUPTED run сначала открывает
evidence; retry создаёт linked child run с exact remaining frozen suffix и не вызывает
vendor session resume. Resume не пропускает шаг без его Gate/DoD/completion hooks. Verified
completion связывает root CYCLE и все RESUME children в launcher-owned digest chain; current
artifacts из постороннего run блокируются.

`localrun.sh` показывается пользователю как «Локальные репозитории», имеет
собственный AI/routing-профиль и не наследует effective route последнего SDLC Agent.
Full pipeline и batch update технических заметок показывают exact Preview; первый
skip/failure завершает последовательность как incomplete, а не success.

## Система качества и надёжности

**Канонические стандарты (читать перед каждой задачей):**
- `$SDLC_VAULT/_agents/_standards/tdd.md` — Specify → Red → Green → Run → Repair → Refactor, test-first применимость и BLOCKED repair loop
- `$SDLC_VAULT/_agents/_standards/quality.md` — DoD, DoR, Gates, NFR, test pyramid (§3.1), ISO 25010 (§4.1), Auto-Heal, Known Issues (§6.1), метрики (§7)
- `$SDLC_VAULT/_agents/_standards/security.md` — active Security-трек SG1–SG4; SG5 historical/frozen
- `$SDLC_VAULT/_agents/_standards/data-formats.md` — форматы DB/ENV/API, обязательные тесты форматов

### Quality Gates — принудительные переходы между этапами
Переход заблокирован, пока Gate не закрыт. Агент следующего этапа проверяет Gate ПЕРВЫМ делом.
Параллельно действует **active Security-трек SG1–SG4** (security.md §3): этап пройден только когда
зелёный И Quality Gate, И соответствующий Security Gate.

| Переход | Gate (+ Security Gate) | Кто проверяет |
|---------|------|--------------|
| S1 → S2 | Feasibility + Charter + Риски | **s2-ba** |
| S2 → S3 | BRD/NFR + QA/test strategy + Must-FR UAT + UX/A11Y applicability + Quality Characteristics v1 + **SG1** | **s3-arch** |
| S3 → S4 | HLD quality scope + применимые API/Auth/Data artifacts или N/A evidence + **SG2** | **s4-dev** |
| S4 → S5 | Exact-source Evidence v1 + compatibility + only-up + executor controls + five-dimension maintainability + **SG3** | **s5-qa** |
| S5 → Cycle 1 validated | Exact-source S5 Validation v1: full affected regression + UAT approval + PERF + **SG4** + single defects + Go/No-Go | **s5-qa** |

Gate 6/7 и SG5 — `FROZEN / NOT SUPPORTED`; они не входят в active переходы.

### Неотменяемые правила (нарушение = BLOCKER)
- Definition of Done (DoD) обязателен для каждой задачи — все 11 пунктов (включая DoD-11: тесты форматов)
- Definition of Ready (DoR) обязателен перед стартом каждого active этапа — все применимые пункты
- Secrets никогда не в коде, логах, .md-файлах
- Critical/High уязвимости (CVSS ≥ 7.0) блокируют релиз (severity по CVSS — security.md §1)
- Некритичный дефект S3/S4 или security Low/Medium с user-facing impact — только через полный
  Known Issue + Tech Debt/Patch SLA + отдельный Human Approval v1; security Medium также требует
  Risk Exception v3; operational runbook deferred
- UAT только в реальной системе, не в эмуляторе
- Reliability/security/observability решения Cycle 1 выводятся из точных NFR и topology;
  deployment/operations execution не подставляется и не обещается

## Правила именования файлов
Точные producer patterns, cardinality и stable logical ids определены только в
`_contract/current-artifact-groups-v1.tsv`; роли и commands не вводят параллельные имена.
Date-versioned файлы не перезаписываются и не удаляются. Launcher после проверки output groups
атомарно обновляет `tracking/current-artifacts-v1.tsv`; при смене Product Profile revision
current rows пересобираются, а история остаётся на месте. Historical Stage 6/7 naming не
является разрешённым Cycle 1 output.

## Передача данных между агентами
Агент получает exact Project root через окружение, а Project artifacts предыдущего этапа
разрешает по logical id через `current-artifact.sh resolve-compatible[-one]`. Если manifest
существует, missing/stale/tampered row блокирует чтение без glob fallback. Legacy lookup
допустим только при полном отсутствии manifest и всегда помечается `LEGACY / UNVERIFIED`.
НЕ ПЕРЕДАВАЙ историю диалога. Только финальные файлы из outputs/.

```bash
# Пример: получить current feasibility-study без угадывания даты в имени
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/current-artifact.sh" \
  resolve-compatible-one "$SDLC_PROJECTS_DIR/my-project" feasibility-study
```

## Пути проекта (env-переменные, КРИТИЧНО)

Абсолютные пути НЕ захардкожены — они приходят из окружения (лаунчер их экспортирует). Используй переменные, а не литералы вроде `/home/<user>/...`:

| Переменная | Что содержит | Пример пути |
|-----------|--------------|-------------|
| `AGENT_DIR` | папка текущего агента | `$AGENT_DIR/.claude/commands/` |
| `SDLC_VAULT` | корень установки/vault со стандартами и `_agents` | `$SDLC_VAULT/_agents/_standards/quality.md` |
| `SDLC_PROJECTS_DIR` | каталог-родитель SDLC-проектов | `$SDLC_PROJECTS_DIR/{PROJECT}/...` |
| `SDLC_PROJECTS_MODE` | режим выбора проектов: `collection` или `single` | `single` |
| `SDLC_SINGLE_PROJECT` | имя активного проекта в режиме `single` | `ExampleProject` |
| `LOCALRUN_PROJECTS` | локальные repositories (L-агенты) | `$LOCALRUN_PROJECTS/{PROJECT}/` |

В режиме одного проекта launcher показывает путь к конкретному проекту, но `SDLC_PROJECTS_DIR` остаётся родительским каталогом для совместимости с контрактом `$SDLC_PROJECTS_DIR/{PROJECT}`.

Получить значение в bash: `echo "$SDLC_PROJECTS_DIR"`. Стандарты читаются как `$SDLC_VAULT/_agents/_standards/quality.md`.

**Фолбэк:** если переменная пуста (агент запущен напрямую, минуя лаунчер) — спроси путь у пользователя, не угадывай и не подставляй чужой абсолютный путь.

## Рабочая директория (КРИТИЧНО)

**Правило bash-команд**: если нужно временно сменить директорию — используй **подоболочку**:

```bash
# ✅ Правильно — cwd возвращается после команды
(cd /some/project && git log)

# ❌ Неправильно — cwd меняется для ВСЕХ последующих bash-вызовов в сессии
cd /some/project && git log
```

**Для всех файловых операций** используй только абсолютные пути (через env-переменные выше). Никогда не полагайся на текущую директорию для записи или чтения файлов.

**Верификация директории перед записью (КРИТИЧНО):** перед первой записью в директорию проекта — прочитай хотя бы один существующий файл оттуда, чтобы убедиться, что путь правильный. НЕ полагайся на память о расположении проекта из прошлых сессий — директория могла измениться. Если целевая папка пуста или не читается — уточни путь у пользователя, не угадывай.

## Поведенческие правила агентов
Обязательны для всех агентов Цикла 1.

- **Интерактивный старт — общий.** На явное сообщение `начни сессию` представь роль и этап,
  кратко перечисли зарегистрированные для этой роли задачи/команды и предложи следующее
  допустимое действие. Используй Project, уже выбранный launcher-ом; не спрашивай его повторно.
  Если агент запущен без exact Project, запроси его у пользователя и не угадывай. Ролевые
  `CLAUDE.md` описывают только отличия роли и не копируют этот общий сценарий.
- **Только файловый worker handoff.** При `SDLC_SUBAGENTS=off` не вызывай workers. При
  `auto|cross-runtime` primary может подготовить только Worker Request v1 для bounded advisory
  задачи; он не запускает vendor-native subagent и не расширяет launcher-owned read scope или
  route. Результат читается только из Worker Result v1 в новом изолированном launch. Primary
  остаётся единственным writer и gate signer.
- **«Все» = полный вывод.** Если пользователь просит «все» (задачи, список и т.п.) — выводить целиком, без сокращений «ради краткости». Явное «все/полный» перевешивает дефолт на лаконичность.
- **Runtime Constraints — учитывать.** Не предлагать действий, противоречащих
  подтверждённым ограничениям запуска и проверки продукта. Читать `Runtime Constraints`
  из `idea.md` и сохранять trace по `_contract/RUNTIME_CONSTRAINTS_V1.md`. Legacy-поле
  `Deployment Constraint` допустимо только как вход kickoff-миграции и должно быть
  нормализовано в `Runtime Constraints` до Stage 2. Если присутствуют оба поля, ни одно
  не имеет молчаливого приоритета: конфликт явно разрешает пользователь, legacy удаляется.
  Runtime Constraint не даёт разрешения на deploy/operations или frozen Cycle 2/3.
- **KISS — только для implementation writers.** `s4-dev`, а также `l2-setup`, `l3-build` и
  `l4-run` при фактическом изменении repository выбирают минимальную достаточную реализацию:
  existing conventions/public interfaces, smallest coherent diff, без speculative layers,
  dependencies, frameworks, extension points и обобщений «про запас». Решение всё равно
  обязано выполнять approved scope, requirements, HLD/ADR, NFR, security, reliability,
  compatibility/data contracts и тесты. KISS не разрешает убирать validation, error handling,
  authorization, observability, recovery controls или intentional complexity. Изменение
  архитектуры/approved paths требует нового handoff и возвращает `BLOCKED`. Planning/design,
  QA/quality, security, reliability/SRE и validator roles не упрощают принадлежащие им
  проверки/evidence по этому принципу. Каноническая формулировка — в
  `plans/principles.md#KISS — минимальная достаточная реализация`.

## Отвечай на русском

## Хранение секретов

Каноническая product policy находится в
`$SDLC_VAULT/_agents/_standards/security.md#Хранение-секретов`. Роли и команды не копируют и
не переопределяют её.
