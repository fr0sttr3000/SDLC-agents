---
date: 2026-08-22
tags: [plans, principles]
---

# Принципы проекта — SDLC Agent System

Этот файл — канонический источник устойчивых продуктовых принципов: он определяет, **что**
система гарантирует и **почему**. Исполняемые требования, schemas и алгоритмы определяются
связанными standards/contracts; текущий статус и приоритеты — в [[roadmap]].

Если краткое описание принципа повторяется в пользовательской или архитектурной документации,
формулировка здесь остаётся основной, а подробности не копируются и читаются по ссылке.

## Область действия

Принципы применяются к текущему поддерживаемому продуктовому scope. Его границы, замороженные
направления и условия расширения определяются только в [[roadmap]].

## Архитектурные принципы

### Изолированные роли и файловый handoff

Каждая роль действует в явно заданных границах и передаёт результат через проверяемые файловые
артефакты, а не через скрытую память или историю диалога. Подключаемая память входит в процесс
только как immutable digest-bound snapshot, а запись — как Proposal/Approval/Receipt files.
Это делает handoff воспроизводимым и аудируемым.

Подробнее: [[_contract/GLOBAL#Runtime Invariants]],
[[_contract/CURRENT_ARTIFACTS_V1#Project current manifest]], [[_contract/MEMORY_V1]].

### Границы изменения предшествуют реализации

Перед native mutation система фиксирует Change Intent, карту проекта, техническое и
архитектурное влияние, exact owners/paths и отдельное человеческое подтверждение. Runtime
allowlist уменьшает доступную запись, а полный diff доказывает фактический результат; ни один
агент не расширяет собственную границу.

Подробнее: [[_contract/CHANGE_SCOPE_V1]], [[_contract/RUNTIME_ACCESS_V1]].

### Runtime-neutral SDLC

SDLC-правила не зависят от AI vendor или runtime. Runtime adapters реализуют общий контракт и
не создают отдельные gates, роли или форматы артефактов.

Подробнее: [[_contract/GLOBAL#Compatibility Rule]], [[_contract/README#Canonical Sources]].

### Явное и fail-closed исполнение

Runtime, модель, capability и scope выбираются явно. Если требуемая граница или точная
конфигурация не доказана, выполнение блокируется вместо неявного fallback.

Подробнее: [[_contract/GLOBAL#Runtime Invariants]],
[[_standards/security#Runtime-граница файловой системы]].

### Ответственный primary и ограниченные помощники

Primary остаётся ответственным за запись результата и gate verdict. Любой помощник имеет только
явно разрешённую advisory capability и не расширяет собственные права.

Подробнее: [[_contract/SUBAGENTS#Обязательная граница]], [[_contract/WORKER_HANDOFF_V1]].

## Принципы платформы

### Markdown-first governance

Решения, handoff, gates и человекочитаемое evidence должны быть обозримыми в Markdown. Код,
тесты, schemas, SQL, IaC и другие исполняемые материалы сохраняют нативный формат и связываются
с governance-артефактами через проверяемую идентичность.

Подробнее: [[README#Markdown-first и native artifacts]],
[[_standards/artifact-metadata#Required frontmatter]].

### Obsidian — интерфейс, а не скрытый контракт

Система использует Obsidian для навигации и чтения, но продуктовые данные остаются переносимыми
файлами. Работоспособность не должна зависеть от непубличного состояния интерфейса.

Подробнее: [[README#Интеграция с Obsidian]].

### Единая оркестрация

Пользователь входит в поддерживаемые workflows через launcher, который показывает выбранный
Project, scope и план до выполнения. Отдельные инструменты не должны незаметно обходить эту
оркестрацию.

Подробнее: [[OVERVIEW#Слои системы]], [[README#Fast Start]].

### Local Run отделён от SDLC

Подготовка и локальный запуск существующего repository — отдельная оснастка разработчика, а не
дополнительный SDLC stage. Такое разделение не смешивает анализ чужого кода с продуктовыми gates.

Подробнее: [[README#Локальные репозитории]].

### Секреты не являются проектными данными

Секретные значения не записываются в код, документацию, артефакты или логи и передаются только
через утверждённый secret-store boundary.

Подробнее: [[_standards/security#Хранение секретов]].

## Принципы разработки

### Specification-driven development

Проверяемая спецификация предшествует реализации и связывает требования, архитектурные решения,
тесты и точную ревизию результата.

Подробнее: [[_contract/TRACEABILITY_V1]], [[_contract/ARCHITECTURE_DECISION_TRACE_V1]].

### Test-driven development

Для применимой работы сначала определяется проверяемое ожидание и наблюдается корректный Red,
затем создаётся минимальный Green, выполняется полный затронутый набор и устраняются причины FAIL.

Подробнее: [[_standards/tdd#1. Неизменяемый порядок]].

### KISS — минимальная достаточная реализация

Агент, который непосредственно изменяет implementation code или repository-local
конфигурацию и не владеет planning/design, quality, security или reliability verdict, выбирает
самое простое решение, полностью удовлетворяющее approved scope, требованиям, HLD/ADR, NFR,
security/reliability/data contracts и тестам. По умолчанию он использует существующие
conventions и public interfaces, делает минимальный связный diff и не добавляет speculative
layers, dependencies, frameworks, extension points или обобщения «про запас».

KISS не разрешает удалять или обходить validation, error handling, authorization,
observability, compatibility, recovery controls и тесты. Intentional complexity, защищённая
current HLD/ADR и Change Scope, сохраняется. Если упрощение требует изменить архитектуру,
требования или approved paths, агент возвращает `BLOCKED` для нового handoff, а не расширяет
решение самостоятельно.

В active Cycle 1 принцип обязателен для `s4-dev`; в Local Repositories — для `l2-setup`,
`l3-build` и `l4-run`, только когда они действительно меняют repository. Он не является
указанием упрощать независимые проверки и evidence, принадлежащие planning/architecture,
QA/quality, security, reliability/SRE или validator roles.

Подробнее: [[_contract/CHANGE_SCOPE_V1]], [[_standards/tdd]],
[[_standards/quality#2. Definition of Done (DoD) — выход из задачи]].

### Shift Left

Качество, безопасность и тестируемость уточняются с требований и дизайна, а не добавляются после
реализации.

Подробнее: [[_standards/security#3. Active Security Gates SG1–SG4 и historical SG5]],
[[_standards/quality#4. Quality Gates — переходы между этапами]].

### Решения через evidence и trade-offs

Архитектурный выбор связывается с наблюдаемой характеристикой качества, tactic, pattern и ADR;
альтернативы и trade-offs фиксируются явно.

Подробнее: [[_contract/ARCHITECTURE_DECISION_TRACE_V1]],
[[_standards/quality#5. Обязательные паттерны надёжности]].

## Принципы качества

### Только усиление требований

Общие quality/security требования являются минимальной границей. Проект может доказуемо
усиливать её, но не ослаблять локальной настройкой.

Подробнее: [[_standards/quality#4. Quality Gates — переходы между этапами]],
[[_contract/QUALITY_POLICY_V1]].

### Явная применимость без молчаливых исключений

DoR, DoD и gates применяются по проверяемому scope. Неприменимость требует структурированного
обоснования; отсутствие evidence не превращается в PASS.

Подробнее: [[_standards/quality#1. Definition of Ready (DoR) — вход в этап]],
[[_standards/quality#2. Definition of Done (DoD) — выход из задачи]],
[[_contract/APPLICABILITY_V1]].

### Machine evidence before declarations

Автоматический verdict опирается на проверяемое evidence точного subject. Отчёт объясняет
результат, но не заменяет исходные данные и verifier.

Подробнее: [[_contract/EVIDENCE_V1#Verdict and verification state]].

### Current set отделён от истории

Текущий verdict использует однозначно выбранный набор артефактов. Предыдущие версии сохраняются
как история и не подмешиваются в актуальный результат.

Подробнее: [[_contract/CURRENT_ARTIFACTS_V1]].

### Completion доказывает исполнение

Наличие ожидаемых файлов недостаточно: завершение требует связанного доказательства фактически
исполненного плана, проверок и утверждённых verdicts.

Подробнее: [[_contract/CYCLE1_COMPLETION_V2]], [[_contract/EXECUTION_JOURNAL]].

## Принцип документационного управления

Устойчивые принципы хранятся здесь, планы — в [[roadmap]], подробные обязательные правила — в
`_standards/` и `_contract/`, пользовательские инструкции — только в `README.md`, история
поставок — в `CHANGELOG.md` и release notes. Один тип информации
не должен превращаться в параллельный источник истины для другого.
