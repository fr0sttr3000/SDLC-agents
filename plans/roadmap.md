---
date: 2026-08-23
tags: [plans, roadmap, current]
status: ACTIVE
---

# Roadmap — SDLC Agent System

Roadmap упорядочивает будущие продуктовые результаты. Он не повторяет устойчивые
[[principles|принципы]], действующие contracts или список уже реализованных файлов.

Горизонты `Now`, `Next` и `Later` задают последовательность, а не обещанные календарные даты.
Дата или release target добавляются только после отдельного обязательства.

## Delivered baseline

Текущий поддерживаемый scope и пользовательское обещание описаны в [[README#Product status]].
Поставленные изменения и версии перечислены в [[CHANGELOG]]. Они не дублируются в roadmap и не
считаются будущими инициативами.

## Now

| Инициатива | Ожидаемый результат | Зависимости | Критерий выхода |
|---|---|---|---|
| Live Codex App E2E | Канонический launcher проходит representative Cycle 1 flow через Local chat и integrated terminal без обхода dispatcher или scope boundary | Авторизованные App и Codex CLI в одной среде; непроизводственный Project; поддерживаемая Linux/WSL2 boundary | Явно разрешённый live run завершён с проверяемым launcher/Project evidence; synthetic argv smoke сам по себе недостаточен |

## Next

| Инициатива | Ожидаемый результат | Зависимости | Критерий выхода |
|---|---|---|---|
| Live external memory integration matrix | Подтвердить реальные Qdrant OSS/Cloud, Mem0 OSS и Mem0 Platform deployments без ослабления provider-neutral broker | Отдельные непроизводственные instances/credentials и явное разрешение на network tests | Для каждого advertised external adapter есть live add/read-back/snapshot/denial evidence; неподтверждённые версии блокируются fail-closed |

## Later / Decision gates

Эти пункты не являются обещанием реализации. Каждый сначала требует отдельного продуктового
решения; до него текущая граница поддержки не меняется.
Cycle 2/3 сохраняют статус `FROZEN / NOT READY` до отдельного решения для каждого цикла.

| Решение | Ожидаемый результат | Зависимости | Критерий выхода |
|---|---|---|---|
| Windows support | Выбрать: подтверждённая Windows support или явно сохранённый experimental status | Реальная Windows-среда, platform test matrix и доказанная runtime boundary | Live Windows evidence и обновлённое support promise либо зафиксированное решение не расширять scope |
| Cycle 2 — Deploy | Отдельно решить, нужен ли redesign и поддерживаемый delivery workflow | Product delivery contract, owners, gates, evidence и release boundary | Утверждённый и проверяемый public contract либо явное решение оставить Cycle 2 замороженным |
| Cycle 3 — Operations | Отдельно решить, нужен ли operations workflow и где проходит его ответственность | Operations contract, owners, security/reliability gates и handoff boundary | Утверждённый и проверяемый public contract либо явное решение оставить Cycle 3 замороженным |

## Правила ведения

- Инициатива описывает пользовательский результат, а не перечень изменяемых файлов.
- Поставленный результат удаляется из активных горизонтов и отражается в `CHANGELOG.md`/release
  notes; в `Delivered baseline` остаётся только ссылка.
- Переход между горизонтами требует закрытых зависимостей; переход в delivered требует evidence
  из столбца «Критерий выхода».
- Roadmap не копирует requirements из `_standards/` и `_contract/` и не переопределяет
  [[principles]].
