# Subagent Contract

Supervisor + Worker — опциональный режим исполнения. Он не создаёт второй SDLC, не меняет
artifact/gate/security contracts и никогда не передаёт worker-у ownership этапа.

## Исполняемый статус

- `off` — default, workers не запускаются;
- `auto` — тот же exact route, если adapter поддерживает capability-enforced read-only;
- `cross-runtime` — отдельный exact worker runtime/host/provider/model/endpoint.

`auto` берёт frozen exact route primary step. `cross-runtime` фиксирует один exact worker profile
на execution plan; отдельная per-stage/per-agent worker-profile matrix в MVP не поддерживается.

Поддержанный bounded worker route: Claude CLI, Codex CLI и local `codex-oss`; OpenAI Responses
API доступен как отдельный read-only advisory host с явно разрешённым text bundle. Gemini CLI
остаётся primary-only, пока его adapter не доказывает read-only capability. Silent fallback
между routes/models запрещён.

Исполняемый формат, authorization и result описаны в `_contract/WORKER_HANDOFF_V1.md`.

## Обязательная граница

1. Primary формирует только Worker Request v1 для одной bounded advisory задачи.
2. Launcher фиксирует exact read-manifest и route, вычисляет их SHA-256 и создаёт authorization.
3. `_runtimes/subagent-run.sh` принимает только launcher-owned files конкретного execution run.
4. Новый sanitized task process получает public canon и только exact read paths. Весь Project,
   ambient HOME, sibling Projects, VCS metadata, secrets и runtime-denied roots не монтируются.
5. Worker не пишет в Project/notes/memory, не создаёт approvals, не подписывает gates, не
   делегирует дальше и не выполняет external operational actions.
   Connected-memory snapshot и memory-provider access worker-у не передаются.
6. Dispatcher кодирует stdout в Worker Result v1. Другие workers и primary его не читают;
   MVP показывает advisory result пользователю. Принятое заключение возвращается только через
   обычный Project artifact и новый изолированный run.
7. Любая ошибка, mismatch или недоступный exact route означает `BLOCKED`; fallback отсутствует.

Prompt, allowlist задач и последующая проверка supervisor-ом дополняют, но не заменяют
runtime/OS capability boundary.

## Допустимые задачи

Только bounded `analysis|research|review|test-interpretation` внутри active Cycle 1. Deploy,
rollback, production drill, auto-heal, редактирование artifacts, memory-provider access,
подписание gates и любые frozen Cycle 2/3 actions запрещены.
