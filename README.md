# SDLC Agent System

Интерактивная multi-runtime система для разработки и проверки software product в Cycle 1.
Один launcher выбирает Project, точный AI profile, scope и workflow; правила агентов, gates и
artifacts не зависят от Claude, Codex, Gemini или локальной модели.

Этот README — единая пользовательская документация системы. Пользовательские инструкции в
других файлах не дублируются; архитектурные и runtime-контракты перечислены в конце как
технические справочники.

## Fast Start

### `sdlc.sh` — рекомендуемый маршрут

1. Откройте терминал в каталоге `_agents`.
2. Запустите канонический launcher:

   ```bash
   bash sdlc.sh
   ```

3. В первом wizard выберите runtime, вид, каталог Projects, режим Project и AI routing.
4. После сообщения `LAUNCHER ГОТОВ` выберите Project; для нового Project начните с
   `1 Kickoff`.

Runtime можно выбрать заранее:

```bash
AGENT_RUNTIME=claude SDLC_SUBAGENTS=off bash sdlc.sh
AGENT_RUNTIME=codex SDLC_SUBAGENTS=off bash sdlc.sh
AGENT_RUNTIME=gemini SDLC_SUBAGENTS=off bash sdlc.sh
```

Без `AGENT_RUNTIME` первый wizard попросит выбрать runtime явно.
Если runtime binary отсутствует в `PATH`, перед запуском launcher укажите один точный путь через
`CLAUDE_BIN`, `CODEX_BIN` или `GEMINI_BIN`. Значение должно обозначать executable, а не shell-команду.

Выбор папки, Project или пункта меню сам по себе не запускает разработку. Перед изменениями
launcher показывает Preview с `PROJECT`, `PATH`, `SCOPE`, `EXCLUDED`, ordered routes, exact
profile и `Fallback OFF`.

Прямой запуск `_runtimes/agent-run.sh` не поддерживается: это внутренняя реализация launcher-а,
которая сама не создаёт пользовательский Preview и Execution Journal.

### ChatGPT desktop app / Codex

ChatGPT desktop app и Codex — поддерживаемый интерфейс к checkout, но не отдельная точка входа
SDLC. Внутри App также запускайте рекомендуемый `sdlc.sh`:

1. Установите ChatGPT desktop app, войдите в аккаунт и откройте каталог `_agents` как
   folder/project.
2. Выберите Codex и создайте **Local** chat. Managed Worktree может не включить внешние,
   untracked или ignored файлы.
3. Откройте integrated terminal кнопкой справа сверху или сочетанием
   <kbd>Ctrl</kbd>+<kbd>&#96;</kbd> и запустите:

   ```bash
   AGENT_RUNTIME=codex SDLC_SUBAGENTS=off bash sdlc.sh
   ```

Launcher/argv/sandbox routing проверены synthetic compatibility smoke. Полный live Project E2E
через реальный nested Codex ещё не подтверждён; до отдельного подтверждения используйте этот
маршрут на непроизводственной копии Project. Внешний chat не заменяет launcher и не должен
имитировать его SDLC-шаги.

Официальные руководства OpenAI:

- [ChatGPT desktop app](https://learn.chatgpt.com/docs/app)
- [Integrated terminal](https://learn.chatgpt.com/docs/integrated-terminal)
- [Local, Worktree и Cloud](https://learn.chatgpt.com/docs/environments/modes)
- [Managed Worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees)
- [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Windows app](https://learn.chatgpt.com/docs/windows/windows-app)

### Windows — experimental

Windows PowerShell route имеет статус **EXPERIMENTAL / NOT TESTED ON WINDOWS** для полного
interactive run и не входит в подтверждённый supported scope; используйте на свой страх и риск.
Repository Windows workflow определяет real `windows-latest` matrix: PowerShell parser с
invalid mutation, Git Bash auto-detection и explicit `SDLC_BASH`, пути с пробелами/не-ASCII,
UNC rejection, argv и exit-code propagation. До успешного запуска этого workflow на exact
revision это лишь план проверки и не повышает статус выше experimental:

```powershell
./sdlc.ps1
./localrun.ps1
```

Wrappers используют Git for Windows Bash либо путь из `SDLC_BASH` и запускают те же
канонические `.sh`. Для Codex App предпочтителен WSL2/Linux checkout. Windows-native agent и
integrated terminal настраиваются отдельно; после смены режима откройте новый terminal/chat или
перезапустите приложение. Не смешивайте Windows- и WSL-пути в одной команде.

## Product status

| Scope | Статус | Пользовательский результат |
|---|---|---|
| Cycle 1 — Development & Verification | **ACTIVE / SUPPORTED** | требования, design, code, tests, SG1–SG4, Go/No-Go |
| Cycle 2 — Deploy | **FROZEN / NOT READY** | historical code сохранён, execution route отсутствует |
| Cycle 3 — Operations | **FROZEN / NOT READY** | historical code сохранён, execution route отсутствует |

Подготовленный platform release: [v2.002.000](RELEASE_NOTES_v2.002.000.md).
Он имеет статус `PREPARED / NOT PUBLISHED` до отдельного commit/tag/publication action.

Cycle 1 содержит 28 обязательных шагов. Launcher показывает immutable ordered plan до запуска и
не считает пропуск обязательного шага успешным. Cycle 2/3 сохранены как historical code, но их
старые agents, goals и artifacts не подтверждают readiness.

## Первый запуск

Первый wizard только сохраняет настройки и открывает Project Console. Он не изменяет Project и
не начинает Cycle.

### 1. Выберите вид

- **Подробный** объясняет результат, scope и следующий шаг; рекомендуется новичку.
- **Краткий** показывает те же действия и клавиши с меньшим количеством текста.

Вид можно переключить клавишей `v`; набор функций не меняется.

### 2. Укажите Projects

Выберите один из режимов:

- **Collection** — каталог, внутри которого находятся несколько SDLC Projects;
- **Single** — один конкретный Project.

Launcher показывает абсолютный путь выбранного Project. Имя Project должно быть безопасным
именем каталога без `/` и `..`.

### 3. Настройте primary AI

Primary выполняет шаг, пишет artifacts и отвечает за результат. Доступны Claude, Codex, Gemini
и зарегистрированный Local agent host.

Routing определяет, какой primary используется для шагов:

| Policy | Значение |
|---|---|
| `single` | один exact profile для всех шагов |
| `per-stage` | profiles по Cycle/Stage groups |
| `per-agent` | базовый profile и exact overrides ролей |
| `ask` | назначения всех шагов собираются до Preview |

Workers опциональны: `SDLC_SUBAGENTS=off` остаётся default, `auto` использует тот же exact
поддержанный route, `cross-runtime` — отдельный exact worker profile. Worker получает только
digest-bound read manifest в новом read-only process; Project/memory writes, gates, approvals,
nested delegation и silent fallback запрещены. Gemini CLI поддерживается как primary, но пока
не как worker: его adapter не доказывает read-only capability.

`auto` следует exact primary profile конкретного шага.
`cross-runtime` фиксирует один frozen worker profile на execution plan; отдельная
per-stage/per-agent worker-profile matrix в MVP
отсутствует. Workers не получают connected-memory snapshots или provider access: память доступна
только primary через launcher-owned ACL-filtered snapshot.

При `auto|cross-runtime` primary может записать только Worker Request v1 в process-local
handoff. После шага откройте `Utilities → Worker request`, задайте 1..64 exact Project-relative
read paths и подтвердите `RUN WORKER <id>`. Launcher привязывает request/read-scope/route
digests, запускает новый read-only process и сохраняет advisory Worker Result вне Project.
Результат не передаётся через vendor conversation и не применяется автоматически primary.

Codex и встроенный `codex-oss` работают только в task mode через зарегистрированные команды.
Каждый такой шаг запускает новый `codex exec --ignore-user-config --ephemeral`; вложенный
интерактивный Codex блокируется до старта, потому что этот режим не умеет отключать ambient
user configuration. Интерактивность внешнего ChatGPT/Codex chat остаётся только оболочкой для
launcher и не передаётся продуктовому агенту.

Для локальной модели укажите точные host, provider и model id:

```bash
AGENT_RUNTIME=local \
LOCAL_AGENT_HOST=codex-oss \
LOCAL_MODEL_PROVIDER=ollama \
LOCAL_MODEL=qwen2.5-coder:14b \
SDLC_SUBAGENTS=off \
bash sdlc.sh
```

Встроенный `codex-oss` поддерживает Ollama и LM Studio. Silent fallback и default model
отсутствуют: недоступный exact profile блокирует запуск.

### Подключаемая долговременная память

Память выключена по умолчанию и настраивается на Project через
`Project Console → Utilities → Memory` либо общий CLI `sdlc-task.sh`. Полностью локальный
baseline — Files; также поставляются fail-closed protocol adapters для Qdrant, Mem0 OSS и
Mem0 Platform. Совместимость конкретного external deployment подтверждается `doctor` и live
read-back; Mem0 OSS дополнительно обязан доказанно исполнять `infer=false`. Agents получают
только user-approved immutable snapshot;
запись идёт через Proposal v1, отдельный Human Approval и provider read-back. Provider не
зависит от выбранных Claude/Codex/Gemini/local routes.

Краткая настройка, примеры для обычного script, Codex, Claude Code, Gemini и ChatGPT/Codex App:
[`_contract/MEMORY_USER_GUIDE.md`](_contract/MEMORY_USER_GUIDE.md).
Актуальный verdict и условия live-поддержки: [`_contract/MEMORY_MVP_AUDIT.md`](_contract/MEMORY_MVP_AUDIT.md).

## Project Console

Подробный и краткий виды содержат одинаковые действия:

| Клавиша | Действие | Что происходит |
|---|---|---|
| `0` | Незавершённый запуск | показать evidence и безопасную точку child retry |
| `1` | Kickoff | создать или обновить входные данные; Cycle не стартует автоматически |
| `2` | Обзор | прочитать текущее состояние |
| `3` | Review | выполнить read-only review Project, Cycle, Stage или Agent |
| `4` | Repair | исправить подтверждённый scope после Preview |
| `5` | Cycle 1 | запустить единственный supported SDLC route |
| `6` | Cycle 2/3 status | показать `FROZEN / NOT READY`; execution недоступен |
| `7` | Один Agent | запустить одну роль и одну команду |
| `9` | AI routing/workers | настроить primary profiles и увидеть статус workers |
| `u` | Утилиты | secret mappings, tracker, quality gates, validation, Change Scope |
| `l` | Локальные репозитории | clone/pull, analyze, setup, build, local smoke |
| `g` | Launcher settings | изменить каталоги, UI, runtime и routing |
| `v` | Вид | переключить compact/detailed без смены функций |

В `u → Tracker` доступны read-only status/backlog и изменяющие `task-add`, `task-block`,
`task-done`, `sprint-init`, `sprint-close`. Для изменяющей команды launcher сначала
собирает exact task/sprint параметры, показывает Preview и после runtime exit проверяет
синхронизацию task state, DoD/governance ledgers или итоговый sprint state. Один exit code `0`
не завершает Tracker operation.

В `u → Change Scope` launcher сначала фиксирует Change Intent. По умолчанию это exact
backlog/FR/task refs; альтернативно можно выбрать существующий Change Request. Затем в двух
новых изолированных процессах всегда выполняются `l1-analyze /impact` и
`s3-arch /change-impact`. Launcher проверяет их file handoff, добавляет только зарегистрированные
Stage 4 governance outputs, показывает exact subject/path scope и вызывает отдельный Human
Approval. L1, S3 и Stage 4 не могут подтвердить или расширить собственный scope.

## Рекомендуемый путь нового Project

1. Откройте `1 Kickoff` и заполните idea и ограничения Cycle 1.
2. Запустите `s0-kickoff /product-ci-profile`, чтобы собрать versioned product/build/test/CI
   facts без secret values.
3. Запустите `s0-validate /profile-check` и получите `PROFILE VALID`.
4. При необходимости выполните `3 Review` для read-only проверки входов.
5. Откройте `9 AI routing/workers` и проверьте назначения primary.
6. До первого изменяющего шага Stage 4 откройте `u → Change Scope`, проверьте предложенные
   module modes/paths и отдельно подтвердите Human Approval.
7. Выберите `5 Cycle 1`, изучите Preview и только затем подтвердите запуск.

`PROFILE BLOCKED` означает, что обязательный fact отсутствует, inferred, stale или нарушает
supported boundary. Исправьте названный факт; не подставляйте silent default.

## Preview перед выполнением

Перед Cycle, Repair или utility проверьте:

- правильный Project и абсолютный `PATH`;
- `SCOPE` — что войдёт в действие;
- `EXCLUDED` — что гарантированно не войдёт;
- ordered steps/routes;
- exact primary profile и Local model;
- `Fallback OFF`.

Подтверждение запускает только показанный план; возврат отменяет действие. Review выполняется
read-only. Repair и Cycle получают право записи только после Preview.

## Частые сценарии

### Проверить или исправить существующий Project

Сначала `3 Review` с точным Project/Cycle/Stage/Agent scope. Если найдены подтверждённые
проблемы, выберите `4 Repair` с тем же scope. Repair требует актуальный Review и после изменений
автоматически повторяет read-only проверку; завершение возможно только при machine `CLEAN`.

### Запустить Cycle 1

Project Console → `5 Cycle 1`. Перед Stage 1 обязателен валидный Product & CI Profile. После S1
quality-gates связывают применимые characteristics с owners, evidence contracts и Gates.

Начиная со Stage 4 каждая изменяющая команда требует current approved Change Scope. Runtime
читает Project целиком, но пишет только в вычисленные paths текущего owner. Launcher делает
полный before/after manifest и проверяет create/delete/modify/mode/type/symlink changes; declared
report без прошедшего full diff не получает `ARTIFACT_VERIFIED`. Нарушение не откатывается
автоматически и блокирует следующую mutation до восстановления Project или свежего approved
scope.

Cycle завершается только после Gate 1–5, автоматического и независимого полного DoD, exact
current artifacts и связанной root/Retry evidence chain. `CYCLE 1 COMPLETION VERIFIED` означает
готовый Cycle 1 handoff, но не разрешение на release или deploy.

### Продолжить прерванный запуск

Project Console → `0`. Launcher показывает immutable plan, state и evidence. Retry создаёт
linked child run с первого неподтверждённого шага и exact remaining suffix. Vendor chat не
возобновляется, а `RUNNING`, `UNKNOWN` и отсутствующий Gate/DoD не считаются success.

### Запустить одну роль

Project Console → `7 Один Agent`, затем выберите роль и зарегистрированную команду. Специальные
flows — secrets, kickoff, Repair и Local Repositories — доступны только в своих разделах. Для
Codex и `codex-oss` нужно выбрать команду: пустой интерактивный запуск и клавиша `i` недоступны.

### Локальные репозитории

Project Console → `l Локальные репозитории`. Это отдельный developer flow, не четвёртый Cycle:

1. Analyze.
2. Install & configure.
3. Build.
4. Start & smoke.

Полный pipeline успешен только после всех четырёх шагов. Skip или failure останавливает
последовательность как incomplete. Каждая стадия обновляет собственную техническую заметку.
Source не привязан к forge/provider: принимаются полные HTTPS/SSH/file URL, SCP-style Git URL
или существующий локальный path. Exact repository root и origin проверяются fail-closed;
неоднозначный source/root не запускается. Имена каталогов могут содержать внутренние пробелы,
поскольку launcher передаёт exact quoted path.

Smoke выбирается по типу продукта: web/service проверяет bounded process и health/request,
library/package — tests плюс import/package, CLI — exit code и stdout/stderr, worker/job —
один bounded job/queue result. Отсутствующий тип, native command или проверяемый oracle
завершает шаг как `BLOCKED`, а не как условный успех.

### Создать release notes

После `CYCLE 1 COMPLETION VERIFIED` откройте Project Console → Utilities → Release notes, введите
`vX.Y.Z`, проверьте Preview и подтвердите `s0-tracker /release-notes vX.Y.Z`.

Команда создаёт только `tracking/releases/REL-vX.Y.Z-release-notes.md`. Она не меняет completion
manifest и не выполняет внешнюю публикацию, build, deploy или Cycle 2/3.

## Пользовательские границы безопасности

- Каждая роль запускается в отдельной runtime-сессии и не вызывает другие роли напрямую.
  История chat и скрытая память между ролями не передаются: следующий шаг получает только
  проверенные Project artifacts через current manifest. Последовательность ролей и handoff
  координирует launcher.
- Секреты не вводятся в chat, prompt, argv, Markdown, код или логи. Используйте только ссылку на
  запись в `pass`; само значение вводится непосредственно в интерактивный prompt `pass`.
- Launcher передаёт runtime только выбранный Project scope и разрешённые дополнительные пути.
  Если runtime-защита недоступна, dispatch завершается fail-closed.
- Primary agents не изменяют repository history, remotes или branches и не создают commits,
  pushes, pull requests или tags. Поддерживаемый pull выполняется только операторским workflow
  после Preview; VCS control-plane не передаётся продуктовому agent runtime.
- Не используйте `danger-full-access` как обход ошибки sandbox. Исправьте поддерживаемую
  Linux/WSL2 sandbox configuration либо запустите launcher из отдельного terminal в том же
  checkout.
- Cycle 2/3, deployment и operations execution недоступны в supported launcher.
- Release notes — документ; они не являются release/deploy authorization.

## Диагностика

- `codex: command not found`: установите или авторизуйте Codex CLI именно в среде integrated
  terminal; runtime fallback запрещён.
- Ошибка sandbox/user namespaces (`bubblewrap`): используйте поддерживаемый Linux/WSL2 setup;
  не включайте `danger-full-access`.
- Путь содержит пробелы: выбирайте каталог через wizard или передавайте его в кавычках:

  ```bash
  SDLC_PROJECTS_DIR="/path/with spaces/Projects" \
  AGENT_RUNTIME=codex SDLC_SUBAGENTS=off bash sdlc.sh
  ```

- Runtime binary или Local model недоступен: исправьте exact profile/model id; другой profile
  автоматически не выбирается.
- Worker `BLOCKED`: проверьте exact route, request/read-scope/authorization digests и поддержку
  bounded read-only выбранным adapter; fallback на primary или другую модель не выполняется.
- Memory `BLOCKED`: запустите `bash sdlc-task.sh memory profile-check ...` и `doctor ...`;
  проверьте role ACL, source digest и `pass:` reference, не вставляя secret value в Project.
- Prompt отклонён как secret-like: удалите значение и передайте только ссылку на `pass`.
- Gate/DoR/DoD `BLOCKED`: откройте названный evidence id и исправьте причину; не ослабляйте
  threshold или test.
- Cycle 2/3 недоступен: это ожидаемый статус `FROZEN / NOT READY`, а не ошибка launcher.

## Интеграция с Obsidian

### Markdown-first и native artifacts

Папка `Claude/` открывается как Obsidian Vault. Пользовательские Project artifacts, standards и
plans остаются обычными переносимыми файлами. Markdown используется для решений, handoff,
gates, reviews и человекочитаемого evidence, но система не является Markdown-only: исполняемые и schema-артефакты сохраняют нативный формат — code,
tests, OpenAPI, SQL/DBML, YAML/IaC, scanner configs и logs.

## Технические справочники

Следующие документы описывают реализацию и governance, а не отдельные пользовательские маршруты:

- [Архитектура и workflow](OVERVIEW.md)
- [Принципы](plans/principles.md)
- [Roadmap](plans/roadmap.md)
- [Runtime contracts](_contract/README.md)
- [Codex runtime adapter](_runtimes/adapters/codex.md)
- [История изменений](CHANGELOG.md)

Активные планы находятся только в roadmap. Канонические обязательные правила находятся в
`_standards/` и `_contract/`; README объясняет пользователю, как безопасно применять систему.
