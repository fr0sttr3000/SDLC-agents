---
date: 2026-09-01
tags: [release, v2.002.000, connected-memory, multi-runtime, workers]
version: 2.002.000
status: PREPARED_NOT_PUBLISHED
---

# Release Notes — v2.002.000

**Тип:** Cycle 1 feature / connected memory and bounded multi-runtime workers

**Дата подготовки:** 2026-09-01

**Базируется на:** подготовленной platform-линии v2.001.001

**Статус:** PREPARED / NOT PUBLISHED

## Кратко

Релиз добавляет опциональную Project-scoped долговременную память для planning/project vision,
известных дефектов и архитектуры. Primary получает только user-approved immutable snapshot,
отфильтрованный по exact role и command ACL. Запись выполняется как Proposal v1 и применяется
broker-ом только после отдельного Human Approval и provider read-back.

Supervisor + Worker переведён из fail-closed заглушки в ограниченный advisory workflow. Worker
запускается отдельным read-only process по exact digest-bound manifest, не получает ownership
этапа и не может писать artifacts, подписывать gates, делегировать дальше или обращаться к
долговременной памяти.

## Основные изменения

### 1. Connected Memory v1

- Память выключена по умолчанию и включается отдельно для каждого Project.
- Поддерживаются коллекции `planning`, `defects` и `architecture`; role-level и command-level ACL
  пересекаются с Project profile перед каждым чтением или proposal.
- Snapshot создаётся только внутри launcher-owned execution run, связывается SHA-256 и передаётся
  выбранному primary runtime как недоверенный read-only reference.
- Формальные current artifacts, Evidence, approvals и gates всегда приоритетнее memory records.
- `s0-defects` является единственным владельцем записи в defects memory; архитектурные записи
  принадлежат `s3-arch`, planning memory — разрешённым planning-командам.

### 2. Provider-neutral broker

- `files-v1` является полностью локальным baseline.
- Поставляются adapters `qdrant-v1`, `mem0-oss-v1` и `mem0-platform-v1` с bounded network
  requests, canonical record validation, pagination limits и exact read-back.
- Provider credentials разрешаются launcher/broker-ом только из `pass:` reference и не попадают
  в model process, prompt, Project profile или logs.
- Mem0 Platform поддерживает актуальные terminal statuses `SUCCEEDED|COMPLETED`; missing,
  `FAILED` и unknown status блокируют write. Оба Mem0 adapter сохраняют base64 padding record.

### 3. Multi-runtime primary execution

- Claude CLI, Codex CLI, Gemini CLI и зарегистрированные Local agent hosts используют один
  canonical role/command contract.
- `single`, `per-stage`, `per-agent` и `ask` разрешают exact primary profile для каждого шага;
  отсутствующий route блокирует Preview/dispatch без silent fallback.
- Built-in `codex-oss` поддерживает exact Ollama/LM Studio model. Зарегистрированный custom host
  может подключать vLLM, llama.cpp или другой OpenAI-compatible agent host при выполнении
  Universal Runtime Contract.
- `sdlc.sh` остаётся единственной поддерживаемой точкой полного primary execution. `sdlc-task.sh`
  предоставляет vendor-neutral CLI только для explicit memory и worker handoffs из terminal,
  Codex, Claude Code, Gemini CLI или внешней UI-оболочки.

### 4. Bounded advisory workers

- `off` остаётся default; `auto` следует frozen route соответствующего primary step.
- `cross-runtime` использует один отдельный exact Claude, Codex, local `codex-oss` или read-only
  OpenAI Responses API worker profile.
- Worker Request, read scope, authorization и route связываются отдельными SHA-256; пользователь
  видит Preview и отдельно подтверждает `RUN WORKER <id>`.
- Допустимы только `analysis`, `research`, `review` и `test-interpretation`. Worker Result остаётся
  launcher-owned advisory output и не применяется primary автоматически.
- Gemini остаётся primary-only, пока его adapter не доказывает capability-enforced read-only.

### 5. Runtime и документационное hardening

- OpenAI advisory host ограничивает connect time, total request time и максимальный размер
  ответа.
- README, OVERVIEW, memory guide, worker contract и CHANGELOG синхронизированы с фактическими
  primary/worker/memory границами.
- Операторский pull workflow описан без передачи VCS control-plane агентам.

## Критические границы поведения

- Primary memory is runtime-independent: provider выбирается Project profile, а не AI route.
- Workers do not receive connected-memory snapshots или прямой memory-provider access.
- Per-stage worker-profile routing is not included: `auto` следует primary step, а
  `cross-runtime` фиксирует один worker profile на execution plan.
- Vendor CLI или внешний chat не заменяет launcher. Прямой обход `sdlc.sh` не получает execution
  Preview, Journal, capability boundary или автоматический memory snapshot.
- Agent не изменяет memory provider напрямую: он может создать только Proposal v1 внутри
  разрешённого Project scope.
- Ошибка runtime, provider, ACL, digest, approval или read-back даёт `BLOCKED`; fallback на другой
  model/provider отсутствует.

## Требуемые действия при обновлении

1. Продолжайте запускать полный workflow через `bash sdlc.sh`; Codex/Claude/Gemini shell должен
   вызывать тот же launcher.
2. Если память не нужна, ничего не настраивайте: существующие Projects сохраняют прежнее
   поведение.
3. Для памяти выберите provider в `Utilities → Memory`, выполните `profile-check` и `doctor`,
   затем настройте read approval и только необходимые collections.
4. Для remote provider храните credential только в `pass` и передавайте `pass:entry`.
5. Для mixed primary routing заполните каждый required stage/agent route до Preview.
6. Workers включайте отдельно. Проверяйте request, exact read paths и route перед подтверждением;
   не используйте worker result как gate evidence или автоматическую mutation-инструкцию.

## Миграции и совместимость

- Обязательной data migration нет. Memory profile и records добавляются только после явного
  включения пользователем.
- Existing Projects без memory profile продолжают работать с memory disabled.
- Каноническая 28-step Cycle 1 sequence не изменена; Cycle 2/3 остаются `FROZEN / NOT READY`.
- Claude, Codex, Gemini и зарегистрированные Local hosts поддерживаются как primary. OpenAI
  Responses API host является только read-only advisory worker.
- Qdrant и Mem0 adapters требуют live проверки конкретного deployment до включения его в
  подтверждённую compatibility matrix.
- Linux/WSL2 остаётся поддерживаемой execution boundary; Windows adapter остаётся experimental.

## Проверка

- Полный доступный локальный набор завершился с 55 PASS и без product failures.
- Восемь OS-bound positive scenarios не запускались, поскольку требуют exact synthetic Project
  вне source system; требуемая boundary не ослаблялась.
- 125 public bash/sh files прошли `bash -n`; Landlock C component прошёл syntax validation.
- Documentation inventory, internal links, principles, capability registries, memory ACL,
  provider adapters и OpenAI host regressions прошли.
- Mem0 status/base64 и OpenAI request bounds имеют отдельные Red→Green regressions.

## Известные ограничения

- Live Qdrant OSS/Cloud, Mem0 OSS distribution и Mem0 Platform deployments ещё не образуют
  закрытую external integration matrix.
- Representative live Codex App Cycle 1 E2E не выполнен.
- Real Windows execution не выполнен; Windows остаётся `EXPERIMENTAL / NOT TESTED ON WINDOWS`.
- Полный current system-contract run с Project вне source system требует отдельного exact scope.
- Workers не читают connected memory, не пишут Project и не передают result автоматически.
- Отдельные worker profiles по stage/agent не поддерживаются; `cross-runtime` использует один
  frozen profile на execution plan.

## Явные исключения

- Документ не выполняет commit, push, PR, tag или GitHub Release.
- Build, deploy, production и Cycle 2/3 execution не выполнялись.
- Статус `PREPARED / NOT PUBLISHED` не является разрешением на публикацию.
