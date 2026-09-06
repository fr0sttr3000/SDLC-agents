# Подключаемая долговременная память — краткая инструкция

Память опциональна и настраивается отдельно для каждого Project. Без
`tracking/memory/profile-v1.yaml` она выключена. Runtime агента (Claude, Codex, Gemini или
local), primary routing и memory provider независимы: launcher всегда обращается к provider
через `_runtimes/memory/memoryctl.sh`, а model получает только immutable Markdown snapshot.

## Поддержанные providers

| Provider id | Дистрибутив | Endpoint | Credential |
|---|---|---|---|
| `files-v1` | локальный файловый store | каталог вне Project и agent system | `none` |
| `qdrant-v1` | Qdrant OSS/Cloud с vectorless scroll API | HTTPS или loopback HTTP | `none` или `pass:entry` |
| `mem0-oss-v1` | Mem0 OSS с рабочим `infer=false` и полным count | HTTPS или loopback HTTP | `none` или `pass:entry` |
| `mem0-platform-v1` | Mem0 Platform API v3 add/get-all/event | обычно `https://api.mem0.ai` | `pass:entry` |

Автоматического fallback нет. Qdrant collection должна быть заранее создана с именем Project
namespace, которое `configure` выводит после добавления Project hash suffix, и поддерживать
vectorless points (`vectors: {}`). Mem0 adapters запрашивают `infer=false` и сохраняют exact
canonical record в metadata. Для Mem0 OSS это условная совместимость: пользователь должен
отдельно подтвердить, что выбранная версия действительно исполняет `infer=false`; `doctor`
проверяет endpoint/shape, но не способен доказать отсутствие server-side LLM extraction. Если
это доказать нельзя, используйте `files-v1` или `qdrant-v1`. Неполный read-back и
неканонические memories broker блокирует.

## 1. Настройка через launcher

Откройте `Project Console → Utilities → Memory → Configure provider`. Launcher показывает
точный Project profile и требует `ENABLE MEMORY`. `read_approval=always` спрашивает разрешение
на каждый snapshot; `profile` — явное постоянное разрешение этого Project profile. Каждая
запись всё равно имеет отдельный `APPROVAL-MEMORY-*`.

## 2. Настройка через общий скрипт

Все пути передавайте абсолютными и в кавычках.

```bash
bash sdlc-task.sh memory configure \
  --project "/abs/path/Project" \
  --provider files-v1 \
  --endpoint "/abs/path/memory-store" \
  --credential-ref none \
  --namespace my-project \
  --read-approval always \
  --collections planning,defects,architecture \
  --retention-days 3650

bash sdlc-task.sh memory profile-check --project "/abs/path/Project"
bash sdlc-task.sh memory doctor --project "/abs/path/Project"
```

Для remote provider сначала сохраните токен в `pass`, затем укажите только ссылку:

```bash
pass insert services/project-memory

bash sdlc-task.sh memory configure \
  --project "/abs/path/Project" \
  --provider mem0-platform-v1 \
  --endpoint "https://api.mem0.ai" \
  --credential-ref "pass:services/project-memory" \
  --namespace my-project \
  --read-approval always \
  --collections planning,defects,architecture \
  --retention-days 3650
```

Не помещайте token, password или API key в Project profile, prompt или proposal.

## 3. Чтение агентом

При обычном запуске `bash sdlc.sh` launcher:

1. пересекает collections Project profile с role и exact-command ACL tables;
2. запрашивает разрешение, если policy — `always`;
3. получает и перепроверяет provider records;
4. создаёт snapshot внутри launcher-owned execution run;
5. передаёт runtime только точный snapshot path + SHA-256.

Agent не видит provider endpoint/credential и не может изменить snapshot. Planning roles
получают только `planning`, `s0-defects` — `defects`, архитектурные роли — `architecture`.
Это относится только к primary runtime. Workers не получают connected-memory snapshot или
provider access; их контекст ограничен отдельным user-authorized Project-relative read manifest.

## 4. Запись

Agent создаёт только Proposal v1 TSV внутри canonical Project. Пользователь сначала валидирует его, затем отдельно
подтверждает применение:

```bash
bash sdlc-task.sh memory proposal-check \
  --project "/abs/path/Project" --agent s3-arch --command /adr \
  --proposal "/abs/path/Project/tracking/memory/proposals/architecture.tsv"

bash sdlc-task.sh memory apply \
  --project "/abs/path/Project" --agent s3-arch --command /adr \
  --proposal "/abs/path/Project/tracking/memory/proposals/architecture.tsv" \
  --approval-id APPROVAL-MEMORY-ARCH-001
```

Broker проверяет ACL, source SHA-256, размеры, secret-like patterns, append-only lifecycle,
Human Approval и provider read-back. Только успешный receipt означает, что запись применена.

## Codex, Claude Code, Gemini и ChatGPT/Codex App

Используйте один и тот же `sdlc-task.sh`; vendor-specific memory plugins не нужны:

```text
Codex:       выполни bash sdlc-task.sh memory status --project "/abs/path/Project"
Claude Code: выполни bash sdlc-task.sh memory status --project "/abs/path/Project"
Gemini CLI:  выполни bash sdlc-task.sh memory status --project "/abs/path/Project"
```

ChatGPT/Codex App является внешней UI-оболочкой: откройте этот checkout в Codex/terminal и
вызовите тот же CLI. Обычный ChatGPT web без доступа к локальному checkout не может безопасно
подключить локальную Project memory. Для OpenAI API advisory workers доступен registered local
host `openai-api`; exact model/endpoint задаются profile, token — только `pass:` reference.

## Отключение и диагностика

- `bash sdlc-task.sh memory disable --project "/abs/path/Project"` выключает profile, не удаляя
  provider data;
- отсутствующий/повреждённый profile, provider error, stale digest или ACL mismatch блокирует
  только memory-dependent launch/write и не переключает provider;
- проверка: `bash sdlc-task.sh memory status ...` и `... memory doctor ...`;
- formal Project artifacts, Evidence, approvals и gates всегда имеют приоритет над памятью.

Полный нормативный контракт: `_contract/MEMORY_V1.md`.
