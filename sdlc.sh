#!/bin/bash
# SDLC Interactive Agent Launcher

export PATH="$HOME/.local/bin:$PATH"

# Пути вычисляются от расположения скрипта — переносимо между окружениями
AGENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$AGENTS")"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sdlc-agents"
CONFIG_FILE="$CONFIG_DIR/config"
ROUTING_FILE="${SDLC_ROUTING_FILE:-$CONFIG_DIR/runtime-routing}"
PROJECTS=""
PROJECTS_MODE=""
SINGLE_PROJECT=""
PROJECTS_DIR_NOTE=""

# Экспортируем пути в окружение — агенты используют их вместо
# захардкоженных абсолютных путей (по образцу AGENT_DIR).
export SDLC_VAULT="$VAULT"
export AGENT_RUNTIME="${AGENT_RUNTIME:-}"
export LOCAL_AGENT_HOST="${LOCAL_AGENT_HOST:-}"
export LOCAL_MODEL_PROVIDER="${LOCAL_MODEL_PROVIDER:-}"
export LOCAL_MODEL="${LOCAL_MODEL:-}"
export LOCAL_MODEL_ENDPOINT="${LOCAL_MODEL_ENDPOINT:-}"
export LOCAL_MODEL_CREDENTIAL_REF="${LOCAL_MODEL_CREDENTIAL_REF:-}"
export SDLC_SUBAGENTS="${SDLC_SUBAGENTS:-}"
export SDLC_SUBAGENT_MAX="${SDLC_SUBAGENT_MAX:-}"
export SDLC_SUBAGENT_PROFILE="${SDLC_SUBAGENT_PROFILE:-}"
export SDLC_SUBAGENT_CREDENTIAL_REF="${SDLC_SUBAGENT_CREDENTIAL_REF:-}"
export SDLC_SUBAGENT_TASKS="${SDLC_SUBAGENT_TASKS:-}"
export SDLC_SUBAGENT_RUNNER="${SDLC_SUBAGENT_RUNNER:-$AGENTS/_runtimes/subagent-run.sh}"
export SDLC_RUNTIME_ROUTING="${SDLC_RUNTIME_ROUTING:-}"
export SDLC_EXECUTION_RUN_ID="${SDLC_EXECUTION_RUN_ID:-}"
export SDLC_EXECUTION_PLAN_SHA256="${SDLC_EXECUTION_PLAN_SHA256:-}"
export SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256="${SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256:-}"
export SDLC_CHANGE_SCOPE_SHA256="${SDLC_CHANGE_SCOPE_SHA256:-}"
AGENT_RUNNER="$AGENTS/_runtimes/agent-run.sh"
MEMORY_BROKER="$AGENTS/_runtimes/memory/memoryctl.sh"
MEMORY_ACL_FILE="$AGENTS/_contract/memory-role-access-v1.tsv"
MEMORY_COMMAND_ACL_FILE="$AGENTS/_contract/memory-command-access-v1.tsv"
COMMAND_CAPABILITIES_FILE="$AGENTS/_contract/command-capabilities-v1.tsv"
CURRENT_ARTIFACT_GROUPS_FILE="$AGENTS/_contract/current-artifact-groups-v1.tsv"
CYCLE1_STEPS_FILE="$AGENTS/_contract/cycle1-steps-v1.tsv"
CURRENT_ARTIFACT_TOOL="$AGENTS/cycle1-dev/s0-validate/current-artifact.sh"
CHANGE_SCOPE_TOOL="$AGENTS/cycle1-dev/s0-validate/change-scope-v1.sh"
source "$AGENTS/_runtimes/runtime-boundary.sh"
BASE_PROFILE=""
LAUNCHER_BASE_PROFILE=""
LAUNCHER_ROUTING_POLICY=""
LAUNCHER_SUBAGENTS=""
LAUNCHER_SUBAGENT_MAX=""
LAUNCHER_SUBAGENT_PROFILE=""
LAUNCHER_SUBAGENT_CREDENTIAL_REF=""
LAUNCHER_SUBAGENT_TASKS=""
PROJECT="${PROJECT:-}"
SDLC_UI_VIEW="${SDLC_UI_VIEW:-}"
CURRENT_RUN_ID="${CURRENT_RUN_ID:-}"
FIRST_RUN_WIZARD=0
PROJECT_CONSOLE_INTRO_PENDING=1
PENDING_FIRST_RUN_AI_SETUP=""
EXECUTION_PREVIEW_BLOCKED=0
RELEASE_NOTES_VERSION=""
RELEASE_NOTES_SOURCE=""
RELEASE_NOTES_MANIFEST_REF=""
RELEASE_NOTES_MANIFEST_SHA=""
RELEASE_NOTES_TARGET_REF=""
ACTIVE_CHANGE_SCOPE_FILE=""
ACTIVE_CHANGE_SCOPE_SHA256=""
CHANGE_SCOPE_METADATA_FILE=""
CHANGE_SCOPE_METADATA_SHA256=""
CHANGE_SCOPE_PATHS_FILE=""
CHANGE_SCOPE_PATHS_SHA256=""
CHANGE_SCOPE_BEFORE_MANIFEST=""
CHANGE_SCOPE_AFTER_MANIFEST=""
CHANGE_SCOPE_INVOCATION_DIR=""
SCOPE_PREP_ID=""
SCOPE_PREP_KIND=""
SCOPE_PREP_REFS=""
SCOPE_PREP_SOURCE=""
SCOPE_PREP_PROFILE_REVISION=""
declare -a EXECUTION_STEP_PROFILES=()
declare -a EXECUTION_STEP_SOURCES=()
declare -a MEMORY_RUNTIME_ARGS=()
declare -A JOURNAL_VALIDATED_FILE_SHA=()

# ─── цвета ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[0;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'


# ─── конфигурация runtime и проектов ─────────────────────────────────────────
read_config_value() {
  local key="$1"
  [[ -f "$CONFIG_FILE" ]] || return 1
  awk -v key="$key" '
    index($0, key "=") == 1 {
      value=$0
      sub(/^[^=]*=/, "", value)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  ' "$CONFIG_FILE"
}

write_config_value() {
  local key="$1" value="$2" tmp
  [[ "$key" =~ ^[A-Z0-9_]+$ ]] || return 1
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *'"'* ]]; then
    echo "Недопустимое значение настройки $key" >&2
    return 1
  fi
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  tmp="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")" || return 1
  if [[ -f "$CONFIG_FILE" ]]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { written=0 }
      index($0, key "=") == 1 { print key "=\"" value "\""; written=1; next }
      { print }
      END { if (written == 0) print key "=\"" value "\"" }
    ' "$CONFIG_FILE" > "$tmp"
  else
    printf '%s="%s"\n' "$key" "$value" > "$tmp"
  fi
  chmod 600 "$tmp"
  mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
}

is_first_run() {
  [[ ! -s "$CONFIG_FILE" ]]
}

render_first_run_intro() {
  printf '%s\n' \
    'Добро пожаловать. Этот launcher помогает выбрать проект и безопасно запустить нужный SDLC-сценарий.' \
    '' \
    'Что сейчас произойдёт:' \
    '  1. Runtime — выберем primary routing и покажем fail-closed статус workers.' \
    '  2. Projects — укажем, где launcher ищет доступные SDLC-проекты.' \
    '  3. View — выберем подробный или краткий вид одного и того же меню.' \
    '' \
    'После настройки откроется выбор проекта, затем Project Console с доступными действиями.' \
    'Настройка ничего не запускает и не изменяет файлы проектов.' \
    ''
}

render_first_run_step_context() {
  case "$1" in
    1)
      printf '%s\n' \
        'Зачем: runtime определяет, какой установленный AI-инструмент будет вызывать agents.' \
        'Что изменится: сохранятся primary routing, worker mode и точные профили без silent fallback.' \
        'Что дальше: launcher зафиксирует безопасный execution profile и перейдёт к Projects.'
      ;;
    2)
      printf '%s\n' \
        'Зачем: Projects ограничивает каталог, в котором launcher показывает и создаёт проекты.' \
        'Что изменится: сохранится путь и режим — коллекция проектов или один конкретный проект.' \
        'Что дальше: файлы проектов не меняются; затем выбирается вид интерфейса.'
      ;;
    3)
      printf '%s\n' \
        'Зачем: подробный вид объясняет действия, краткий оставляет те же команды без длинных описаний.' \
        'Что изменится: сохранится только плотность интерфейса; функции и правила безопасности одинаковы.' \
        'Что дальше: откроется launcher, где сначала нужно выбрать проект и только потом действие.'
      ;;
  esac
  echo
}

render_first_run_step() {
  local step="$1" title="$2"
  [[ "$step" == "1" ]] && render_first_run_intro
  echo -e "${W}ПЕРВЫЙ ЗАПУСК · ШАГ ${step} ИЗ 3${N}"
  echo -e "${W}${title}${N}"
  echo
  render_first_run_step_context "$step"
}

initialize_first_run_execution_policy() {
  case "${SDLC_RUNTIME_ROUTING:-}" in
    "") SDLC_RUNTIME_ROUTING="single" ;;
    single|per-stage|per-agent|ask) ;;
    *) echo -e "${R}Некорректный SDLC_RUNTIME_ROUTING: $SDLC_RUNTIME_ROUTING${N}"; return 1 ;;
  esac

  case "${SDLC_SUBAGENTS:-}" in
    "") SDLC_SUBAGENTS="off" ;;
    off|auto|cross-runtime) ;;
    *) echo -e "${R}SDLC_SUBAGENTS должен быть off, auto или cross-runtime${N}"; return 1 ;;
  esac
  [[ -n "${SDLC_SUBAGENT_MAX:-}" ]] || SDLC_SUBAGENT_MAX=2
  valid_menu_index "$SDLC_SUBAGENT_MAX" 16 || {
      echo -e "${R}SDLC_SUBAGENT_MAX должен быть 1..16${N}"
      return 1
    }

  export SDLC_RUNTIME_ROUTING SDLC_SUBAGENTS SDLC_SUBAGENT_MAX
  write_config_value SDLC_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
  write_config_value SDLC_SUBAGENTS "$SDLC_SUBAGENTS"
  write_config_value SDLC_SUBAGENT_MAX "$SDLC_SUBAGENT_MAX"
}

render_first_run_execution_policy() {
  echo -e "  Профиль исполнения: ${C}${SDLC_RUNTIME_ROUTING}${N}"
  echo -e "  Silent fallback: ${C}выключен${N}"
  echo -e "  Workers: ${C}${SDLC_SUBAGENTS}${N}; bounded read-only handoff, fallback OFF"
  echo -e "  Изменить позже: ${W}Project Console → Configuration${N}"
  echo
}

# ─── interface state and safe project identity ───────────────────────────────
normalize_ui_view() {
  case "${1:-}" in
    detailed|compact) printf '%s\n' "$1" ;;
    *) return 1 ;;
  esac
}

set_ui_view() {
  local view
  view="$(normalize_ui_view "${1:-}")" || return 1
  SDLC_UI_VIEW="$view"
  export SDLC_UI_VIEW
  write_config_value SDLC_UI_VIEW "$view"
}

toggle_ui_view() {
  case "${SDLC_UI_VIEW:-detailed}" in
    detailed) set_ui_view compact ;;
    compact) set_ui_view detailed ;;
    *) set_ui_view detailed ;;
  esac
  printf '%s\n' "$SDLC_UI_VIEW"
}

render_ui_view_choice() {
  printf '%s\n' \
    'Как показывать launcher?' \
    '  1) Подробный вид — действия сразу сопровождаются пояснениями' \
    '  2) Краткий вид — те же действия без длинных описаний' \
    '  ?) Сначала показать оба вида; выбор при этом не сохраняется'
}

ensure_ui_view() {
  local saved choice
  if saved="$(read_config_value SDLC_UI_VIEW 2>/dev/null)" && normalize_ui_view "$saved" >/dev/null; then
    SDLC_UI_VIEW="$saved"
    export SDLC_UI_VIEW
    return 0
  fi
  while true; do
    if [[ "$FIRST_RUN_WIZARD" == "1" ]]; then
      header
      render_first_run_step 3 "Как показывать меню?"
    fi
    render_ui_view_choice
    read -rp 'Выбери [1/2/?/q]: ' choice
    case "$choice" in
      1) set_ui_view detailed; return ;;
      2) set_ui_view compact; return ;;
      \?) printf '\nПодробный — больше контекста. Краткий — тот же порядок, клавиши и безопасность.\n\n' ;;
      q|Q|'') return 1 ;;
      *) echo 'Выбери показанный вариант.' ;;
    esac
  done
}

valid_project_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]]
}

valid_menu_index() {
  local value="${1:-}" maximum="${2:-0}"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] &&
    [[ "$maximum" =~ ^[0-9]+$ ]] &&
    (( 10#$value >= 1 && 10#$value <= 10#$maximum ))
}

project_path() {
  printf '%s/%s\n' "$PROJECTS" "${1:-$PROJECT}"
}

is_recognized_sdlc_project() {
  local dir="$1"
  is_sdlc_project_dir "$dir" && return 0
  [[ -f "$dir/Dashboard.md" &&
     -d "$dir/stage1-planning/inputs" &&
     -d "$dir/stage1-planning/outputs" ]]
}

# ─── Project Console: one action catalog, two renderers ──────────────────────
console_action_map() {
  printf '%s\n' \
    '0|unfinished' '1|kickoff' '2|overview' '3|review' '4|repair' \
    '5|cycle1' '6|cycle23-frozen' '7|agent' '9|ai' \
    'u|utilities' 'p|projects' 'l|local-repositories' \
    'g|launcher-settings' 'v|view' '?|help' 'q|exit'
}

cycle23_support_status() {
  printf '%s\n' 'FROZEN / NOT READY'
}

cycle23_execution_available() {
  return 1
}

cycle23_frozen_notice() {
  echo -e "${Y}Cycle 2/3 — $(cycle23_support_status).${N}"
  echo 'Их historical implementation baseline сохранён, но execution и настройка цели'
  echo 'недоступны в supported launcher до отдельного решения о разморозке.'
}

render_cycle23_frozen_status() {
  printf '%s\n' \
    'CYCLE 2/3 STATUS: FROZEN / NOT READY' \
    'Supported route: только Cycle 1.' \
    'Существующий код Cycle 2/3 сохранён как historical implementation baseline.' \
    'Запуск, goal configuration и AI routing для Cycle 2/3 недоступны.'
}

render_project_selector() {
  local d name
  printf 'SDLC PROJECTS\n\n'
  if [[ "${PROJECTS_MODE:-}" == single && -n "${SINGLE_PROJECT:-}" ]]; then
    printf '  1 %s — %s/%s\n' "$SINGLE_PROJECT" "$PROJECTS" "$SINGLE_PROJECT"
  elif [[ -d "${PROJECTS:-}" ]]; then
    while IFS= read -r -d '' d; do
      name="$(basename "$d")"
      [[ "$name" == _* || "$name" == .* ]] && continue
      is_recognized_sdlc_project "$d" || continue
      printf '  %s — %s\n' "$name" "$d"
    done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
  fi
  printf '%s\n' \
    '' '  n Создать новый SDLC Project' \
    '  l Локальные репозитории' \
    '  g Настройки launcher-а' \
    '  q Завершить launcher'
}

render_launcher_entry_intro() {
  if [[ "${SDLC_UI_VIEW:-detailed}" == "compact" ]]; then
    printf '%s\n' 'LAUNCHER ГОТОВ — выбор проекта ничего не запускает; он только открывает Project Console.'
    return
  fi
  printf '%s\n' \
    'LAUNCHER ГОТОВ' \
    'Настройка завершена. Теперь выберите проект — контекст, с которым будете работать.' \
    'Выбор проекта ничего не запускает и не изменяет его файлы.' \
    'После выбора откроется Project Console: Kickoff, обзор, Review, Repair, Cycle 1 или один Agent.' \
    'Работа начинается только после выбора действия; операции запуска показывают границы и предпросмотр.'
}

render_project_console_intro() {
  if [[ "${SDLC_UI_VIEW:-detailed}" == "compact" ]]; then
    printf '%s\n' 'Действие ещё не запущено — выберите нужную команду Project Console.'
    return
  fi
  printf '%s\n' \
    'КОНТЕКСТ ПРОЕКТА ОТКРЫТ' \
    'Сейчас ничего не запущено: launcher ждёт, что именно вы хотите сделать.' \
    'Обзор и Review работают без изменений; Repair отделён от проверки.' \
    'Для Cycle 1 и Agent сначала показываются границы и предпросмотр запуска.'
}

render_project_console() {
  local view="${SDLC_UI_VIEW:-detailed}" next_view='Краткий вид'
  [[ "$view" == compact ]] && next_view='Подробный вид'
  printf 'PROJECT: %s\nPATH:    %s\nVIEW:    %s\n\n' "$PROJECT" "$(project_path)" "$view"
  if [[ "$view" == compact ]]; then
    printf '%s\n' \
      '0 Незавершённый запуск' '1 Kickoff' '2 Обзор проекта' \
      '3 Review' '4 Repair' '5 Cycle 1' \
      '6 Cycle 2/3 — FROZEN / NOT READY' '7 Один Agent' \
      '9 AI routing/worker status' 'u Утилиты проекта' 'p Другой проект' \
      'l Локальные репозитории' 'g Настройки launcher-а' \
      "v $next_view" '? Пояснить действие' 'q Завершить launcher'
  else
    printf '%s\n' \
      '0 Продолжить незавершённый запуск — открыть его план и доказанную точку восстановления' \
      '1 Пройти или обновить Kickoff — Разработка не стартует сама' \
      '2 Обзор проекта — входы, результаты, циклы и состояние без изменений' \
      '3 Review проекта — только проверить, ничего не исправлять' \
      '4 Repair проекта — сначала показать точные изменения, затем запросить запуск' \
      '5 Запустить Cycle 1 — единственный поддерживаемый SDLC route' \
      '6 Cycle 2/3 — FROZEN / NOT READY; показать статус без запуска' \
      '7 Запустить только один Agent — Cycle 1 или общая утилита' \
      '9 Настроить AI — выбрать primary и проверить статус workers' \
      'u Утилиты проекта — memory, worker handoff, tracker, gates и validation' \
      'p Выбрать другой SDLC Project' \
      'l Локальные репозитории — clone, setup, build и local run' \
      'g Настройки launcher-а — каталоги, интерфейс и общие параметры' \
      "v $next_view" '? Пояснить действие' 'q Завершить launcher'
  fi
}

render_action_help() {
  case "${1:-}" in
    cycle)
      printf '%s\n' \
        'Результат: запуск поддерживаемого Cycle 1.' \
        'Входит: ТОЛЬКО CYCLE 1.' \
        'Не входит: Cycle 2/3 — FROZEN / NOT READY.' \
        'Сейчас: выбор ничего не запускает.' \
        'Далее: Проверка запуска покажет проект, шаги, AI и исключённый scope.' ;;
    *)
      printf '%s\n' \
        'Результат: действие из Project Console.' \
        'Входит: только явно показанный scope.' \
        'Не входит: скрытые действия и silent fallback.' \
        'Сейчас: справка ничего не запускает и не изменяет.' \
        'Далее: вернуться в Console и выбрать действие.' ;;
  esac
}

dispatch_console_action() {
  case "${1:-}" in
    0) menu_unfinished_run ;;
    1) menu_kickoff ;;
    2) menu_project_overview ;;
    3) menu_project_review ;;
    4) menu_project_repair ;;
    5) run_cycle1 selected ;;
    6) render_cycle23_frozen_status ;;
    7) menu_single_agent ;;
    9) menu_ai_assignment ;;
    u) menu_utilities ;;
    p) project_selector ;;
    l) menu_local_repositories ;;
    g) menu_launcher_settings ;;
    v) toggle_ui_view >/dev/null ;;
    \?) render_action_help console ;;
    q|Q) return 2 ;;
    *) return 1 ;;
  esac
}

# ─── frozen execution preview ────────────────────────────────────────────────
preview_route_label() {
  case "${AGENT_RUNTIME:-}" in
    claude) printf 'Claude / external CLI\n' ;;
    codex) printf 'Codex / external CLI\n' ;;
    gemini) printf 'Gemini / external CLI\n' ;;
    local)
      [[ -n "${LOCAL_AGENT_HOST:-}" && -n "${LOCAL_MODEL_PROVIDER:-}" && -n "${LOCAL_MODEL:-}" ]] || return 1
      printf 'Local / %s / %s / %s\n' "$LOCAL_AGENT_HOST" "$LOCAL_MODEL_PROVIDER" "$LOCAL_MODEL"
      ;;
    *) return 1 ;;
  esac
}

render_execution_preview() {
  local type="${1:-ACTION}" scope="${2:-не указан}" excluded="${3:-не указан}"
  local saved_profile entry agent task route source idx=0
  saved_profile="$(current_profile)"
  if [[ "${USE_EXISTING_FROZEN_ROUTES:-0}" != 1 ]]; then
    freeze_execution_routes >/dev/null 2>&1 || true
  fi
  printf '%s\n' 'ПРОВЕРКА ЗАПУСКА'
  printf 'TYPE:     %s\nPROJECT:  %s\nPATH:     %s\nSCOPE:    %s\nEXCLUDED: %s\n' \
    "$type" "$PROJECT" "$(project_path)" "$scope" "$excluded"
  printf 'Fallback OFF\n\n'
  printf 'ORDERED STEPS:\n'
  for entry in "${RUN_CYCLE[@]:-}"; do
    [[ -n "$entry" ]] || continue
    agent="${entry%%:*}"
    task="${entry#*:}"
    if [[ -n "${EXECUTION_STEP_PROFILES[$idx]:-}" ]] &&
       apply_profile "${EXECUTION_STEP_PROFILES[$idx]}" >/dev/null 2>&1; then
      route="$(preview_route_label 2>/dev/null || printf 'BLOCKED: incomplete route')"
      source="${EXECUTION_STEP_SOURCES[$idx]:-unknown}"
    else
      route='BLOCKED: route is not configured'
      source='missing'
      EXECUTION_PREVIEW_BLOCKED=1
    fi
    if [[ "${SDLC_SUBAGENTS:-off}" == "cross-runtime" ]]; then
      local worker_label
      worker_label="$(subagent_profile_label 2>/dev/null || printf 'BLOCKED: incomplete worker')"
      [[ "$worker_label" == BLOCKED:* ]] && EXECUTION_PREVIEW_BLOCKED=1
      printf '  - %s | %s | supervisor=%s | source=%s | worker=%s | tasks=%s | max=%s | verify=supervisor\n' \
        "$agent" "$task" "$route" "$source" "$worker_label" \
        "${SDLC_SUBAGENT_TASKS:-missing}" "${SDLC_SUBAGENT_MAX:-?}"
    else
      printf '  - %s | %s | %s | source=%s | workers=%s\n' \
        "$agent" "$task" "$route" "$source" "${SDLC_SUBAGENTS:-?}"
    fi
    idx=$((idx + 1))
  done
  if [[ -n "${RELEASE_NOTES_VERSION:-}" ]]; then
    printf '\nRELEASE NOTES BOUNDARY:\n'
    printf '  VERSION:  %s\n  SOURCE:   %s\n  INPUT:    %s\n  TARGET:   %s\n' \
      "$RELEASE_NOTES_VERSION" "$RELEASE_NOTES_SOURCE" \
      "$RELEASE_NOTES_MANIFEST_REF" "$RELEASE_NOTES_TARGET_REF"
    printf '  ACTIONS:  Markdown only; no external publication/build/deploy/production/Cycle 2/3\n'
  fi
  apply_profile "$saved_profile" >/dev/null 2>&1 || true
  printf '\nNo action has run yet.\n'
}

confirm_execution_preview() {
  local executor="$1" choice
  printf '%s\n' 'r Запустить точно этот план' 'b Назад без запуска' '? Пояснить безопасность'
  read -r choice
  case "$choice" in
    r|R)
      if [[ "${EXECUTION_PREVIEW_BLOCKED:-0}" -ne 0 ]]; then
        echo 'BLOCKED: execution routes/models are incomplete.'
        return 1
      fi
      "$executor"
      ;;
    \?) render_action_help preview; return 1 ;;
    b|B|q|Q|'') return 1 ;;
    *) return 1 ;;
  esac
}

# ─── launcher-owned Execution Journal (outside agent Project write scope) ─────────
journal_root() {
  local project="${1:-$PROJECT}" project_dir canonical key state_base
  project_dir="$PROJECTS/$project"
  canonical="$(cd "$project_dir" 2>/dev/null && pwd -P)" || return 1
  key="$(printf '%s' "$canonical" | sha256sum | awk '{print substr($1,1,16)}')"
  state_base="${SDLC_JOURNAL_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/sdlc-agents/execution-journal}"
  printf '%s/projects/%s-%s\n' "$state_base" "$project" "$key"
}

journal_run_dir() {
  local project="$1" run_id="$2"
  printf '%s/runs/%s\n' "$(journal_root "$project")" "$run_id"
}

journal_json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}

journal_yaml_quote() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '"%s"' "$value"
}

journal_yaml_unquote() {
  local value="${1:-}"
  if [[ "$value" == \"*\" ]]; then
    value="${value#\"}"
    value="${value%\"}"
    value="${value//\\r/$'\r'}"
    value="${value//\\n/$'\n'}"
    value="${value//\\\"/\"}"
    value="${value//\\\\/\\}"
  fi
  printf '%s' "$value"
}

journal_append_event() {
  local run_id="$1" event="$2" status="$3" step="${4:-0}" step_status="${5:-UNKNOWN}"
  local agent="${6:-}" task="${7:-}" evidence="${8:-}" dir events sequence prev_hash
  local payload event_hash timestamp current_file_sha
  case "$status" in PLANNED|READY|RUNNING|WAITING_USER|BLOCKED|INTERRUPTED|COMPLETED|CANCELLED) ;; *) return 1 ;; esac
  case "$step_status" in PENDING|RUNNING|PROCESS_OK|READ_ONLY_VERIFIED|ARTIFACT_VERIFIED|GATE_PASS|DOD_AUTO_PASS|DOD_PASS|UNVERIFIED|GATE_BLOCKED|DOD_BLOCKED|FAILED|SKIPPED|INTERRUPTED|UNKNOWN) ;; *) return 1 ;; esac
  dir="$(journal_run_dir "$PROJECT" "$run_id")"
  [[ -d "$dir" ]] || return 1
  events="$dir/events.jsonl"
  current_file_sha="$(sha256sum "$events" | awk '{print $1}')"
  if [[ "${JOURNAL_VALIDATED_FILE_SHA[$run_id]:-}" != "$current_file_sha" ]]; then
    journal_validate_run "$PROJECT" "$run_id" || return 1
    JOURNAL_VALIDATED_FILE_SHA["$run_id"]="$current_file_sha"
  fi
  sequence=$(( $(wc -l < "$events") + 1 ))
  if (( sequence == 1 )); then
    prev_hash=GENESIS
  else
    prev_hash="$(tail -1 "$events" | sed -n 's/.*"event_hash":"\([0-9a-f]\{64\}\)"}$/\1/p')"
    [[ "$prev_hash" =~ ^[0-9a-f]{64}$ ]] || return 1
  fi
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  payload="$(printf '{"time":"%s","event":"%s","sequence":%s,"status":"%s","step":%s,"step_status":"%s","agent":"%s","task":"%s","evidence":"%s","prev_hash":"%s"}' \
    "$timestamp" "$(journal_json_escape "$event")" "$sequence" \
    "$(journal_json_escape "$status")" \
    "${step:-0}" "$(journal_json_escape "$step_status")" \
    "$(journal_json_escape "$agent")" "$(journal_json_escape "$task")" \
    "$(journal_json_escape "$evidence")" "$prev_hash")"
  event_hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
  printf '%s\n' "${payload%\}},\"event_hash\":\"$event_hash\"}" >> "$events"
  JOURNAL_VALIDATED_FILE_SHA["$run_id"]="$(sha256sum "$events" | awk '{print $1}')"
}

journal_write_state() {
  local run_id="$1" status="$2" step="${3:-0}" total="${4:-0}"
  local step_status="${5:-UNKNOWN}" current="${6:-}" dir tmp
  case "$status" in PLANNED|READY|RUNNING|WAITING_USER|BLOCKED|INTERRUPTED|COMPLETED|CANCELLED) ;; *) return 1 ;; esac
  case "$step_status" in PENDING|RUNNING|PROCESS_OK|READ_ONLY_VERIFIED|ARTIFACT_VERIFIED|GATE_PASS|DOD_AUTO_PASS|DOD_PASS|UNVERIFIED|GATE_BLOCKED|DOD_BLOCKED|FAILED|SKIPPED|INTERRUPTED|UNKNOWN) ;; *) return 1 ;; esac
  dir="$(journal_run_dir "$PROJECT" "$run_id")"
  [[ -d "$dir" ]] || return 1
  tmp="$(mktemp "$dir/state.md.tmp.XXXXXX")" || return 1
  {
    printf '%s\n' '---'
    printf 'run_id: %s\nproject: %s\nstatus: %s\nstep: %s\ntotal: %s\nstep_status: %s\ncurrent: %s\nupdated_at: %s\n' \
      "$run_id" "$(journal_yaml_quote "$PROJECT")" "$status" "$step" "$total" "$step_status" \
      "$(journal_yaml_quote "$current")" \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' '---' '' '# Execution state'
  } > "$tmp"
  mv "$tmp" "$dir/state.md"
}

journal_ensure_root() {
  local root readme tmp
  root="$(journal_root "$PROJECT")"
  readme="$root/README.md"
  mkdir -p "$root/runs"
  [[ -f "$readme" ]] && return 0
  tmp="$(mktemp "$root/README.md.tmp.XXXXXX")" || return 1
  printf '%s\n' \
    '# Execution Journal' '' \
    'Launcher-owned, runtime-neutral orchestration evidence outside agent Project write scope.' \
    'Each run has an immutable plan, atomic state and append-only events.' \
    'Interrupted/unknown work is never treated as success.' > "$tmp"
  mv "$tmp" "$readme"
}

journal_create_run() {
  local type="$1" scope="$2" excluded="$3" dir entry idx=0 agent task plan_tmp
  local stamp memory_profile memory_profile_sha='none'
  if [[ "${USE_EXISTING_FROZEN_ROUTES:-0}" == 1 ]]; then
    [[ ${#EXECUTION_STEP_PROFILES[@]} -eq ${#RUN_CYCLE[@]} ]] || return 1
  else
    freeze_execution_routes || return 1
  fi
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  CURRENT_RUN_ID="$stamp-${BASHPID:-$$}-$RANDOM"
  dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  memory_profile="$(project_path)/tracking/memory/profile-v1.yaml"
  if [[ -f "$memory_profile" && ! -L "$memory_profile" ]]; then
    memory_profile_sha="$(sha256sum "$memory_profile" | awk '{print $1}')"
  fi
  journal_ensure_root || return 1
  mkdir -p "$dir"
  plan_tmp="$(mktemp "$dir/plan.md.tmp.XXXXXX")" || return 1
  {
    printf '%s\n' '---'
    printf 'run_id: %s\nproject: %s\nproject_path: %s\ntype: %s\nscope: %s\nexcluded: %s\n' \
      "$CURRENT_RUN_ID" "$(journal_yaml_quote "$PROJECT")" "$(journal_yaml_quote "$(project_path)")" \
      "$type" "$(journal_yaml_quote "$scope")" "$(journal_yaml_quote "$excluded")"
    printf 'parent_run_id: %s\n' "${PARENT_RUN_ID:-none}"
    printf 'runtime_routing: %s\nsubagents: %s\nsubagent_max: %s\nsubagent_profile: %s\nsubagent_credential_ref: %s\nsubagent_tasks: %s\ncreated_at: %s\n' \
      "${SDLC_RUNTIME_ROUTING:-}" "${SDLC_SUBAGENTS:-}" "${SDLC_SUBAGENT_MAX:-}" \
      "${SDLC_SUBAGENT_PROFILE:-none}" "${SDLC_SUBAGENT_CREDENTIAL_REF:-none}" "${SDLC_SUBAGENT_TASKS:-none}" \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'memory_profile_sha256: %s\n' "$memory_profile_sha"
    printf 'supported_scope: cycle1\ntdd_cycle1: %s\ncycle23_status: FROZEN / NOT READY\n' \
      "$(read_cycle_tdd_status 1 2>/dev/null || printf 'UNKNOWN')"
    printf 'product_ci_profile_schema: %s\nproduct_ci_profile_revision: %s\n' \
      "$(read_product_ci_profile_field schema_version 2>/dev/null || printf 'UNKNOWN')" \
      "$(read_product_ci_profile_field revision 2>/dev/null || printf 'UNKNOWN')"
    printf '%s\n' '---' '' '# Frozen execution plan' ''
    for entry in "${RUN_CYCLE[@]:-}"; do
      [[ -n "$entry" ]] || continue
      idx=$((idx + 1))
      agent="${entry%%:*}"
      task="${entry#*:}"
      printf '%s. %s\n' "$idx" "$entry"
      printf 'step_%s_agent: %s\nstep_%s_task: %s\nstep_%s_profile: %s\nstep_%s_route_source: %s\n' \
        "$idx" "$agent" "$idx" "$task" "$idx" "${EXECUTION_STEP_PROFILES[$((idx - 1))]}" \
        "$idx" "${EXECUTION_STEP_SOURCES[$((idx - 1))]}"
    done
  } > "$plan_tmp"
  mv "$plan_tmp" "$dir/plan.md"
  sha256sum "$dir/plan.md" | awk '{print $1}' > "$dir/plan.sha256"
  : > "$dir/events.jsonl"
  journal_write_state "$CURRENT_RUN_ID" PLANNED 0 "$idx" PENDING ''
  journal_append_event "$CURRENT_RUN_ID" run_created PLANNED 0 PENDING '' '' 'immutable plan snapshot created'
}

journal_process_start() {
  local pid="$1" stat rest
  [[ -r "/proc/$pid/stat" ]] || return 1
  IFS= read -r stat < "/proc/$pid/stat" || return 1
  rest="${stat##*) }"
  awk '{print $20}' <<< "$rest"
}

journal_acquire_lease() {
  local run_id="$1" dir lease existing_pid existing_start live_start own_start
  dir="$(journal_run_dir "$PROJECT" "$run_id")"
  lease="$dir/lease"
  if [[ -f "$lease" ]]; then
    existing_pid="$(awk -F': ' '$1 == "pid" { print $2; exit }' "$lease")"
    existing_start="$(awk -F': ' '$1 == "pid_start" { print $2; exit }' "$lease")"
    if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
      live_start="$(journal_process_start "$existing_pid" 2>/dev/null || true)"
      [[ -n "$existing_start" && "$existing_start" == "$live_start" ]] && return 1
    fi
  fi
  own_start="$(journal_process_start "$$" 2>/dev/null || true)"
  printf 'project: %s\nrun_id: %s\npid: %s\npid_start: %s\nstarted_at: %s\n' \
    "$(journal_yaml_quote "$PROJECT")" "$run_id" "$$" "$own_start" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$lease"
}

journal_release_lease() {
  local run_id="$1" lease
  lease="$(journal_run_dir "$PROJECT" "$run_id")/lease"
  [[ -f "$lease" ]] || return 0
  : > "$lease"
}

journal_latest_unfinished() {
  local project="${1:-$PROJECT}" root state status newest=''
  root="$(journal_root "$project")/runs"
  [[ -d "$root" ]] || return 1
  while IFS= read -r -d '' state; do
    status="$(awk -F': ' '$1 == "status" { print $2; exit }' "$state")"
    case "$status" in COMPLETED|CANCELLED) continue ;; esac
    newest="$(basename "$(dirname "$state")")"
  done < <(find "$root" -mindepth 2 -maxdepth 2 -name state.md -print0 2>/dev/null | sort -z)
  [[ -n "$newest" ]] || return 1
  printf '%s\n' "$newest"
}

journal_mark_interrupted_runs() {
  local root state status run_id step total current lease lease_pid lease_start live_start
  root="$(journal_root "$PROJECT")/runs"
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' state; do
    status="$(awk -F': ' '$1 == "status" { print $2; exit }' "$state")"
    [[ "$status" == RUNNING ]] || continue
    run_id="$(basename "$(dirname "$state")")"
    lease="$(journal_run_dir "$PROJECT" "$run_id")/lease"
    if [[ -s "$lease" ]]; then
      lease_pid="$(awk -F': ' '$1 == "pid" { print $2; exit }' "$lease")"
      lease_start="$(awk -F': ' '$1 == "pid_start" { print $2; exit }' "$lease")"
      live_start="$(journal_process_start "$lease_pid" 2>/dev/null || true)"
      [[ "$lease_pid" =~ ^[0-9]+$ && -n "$lease_start" && "$lease_start" == "$live_start" ]] && continue
    fi
    step="$(awk -F': ' '$1 == "step" { print $2; exit }' "$state")"
    total="$(awk -F': ' '$1 == "total" { print $2; exit }' "$state")"
    current="$(awk -F': ' '$1 == "current" { sub(/^[^:]*: /, ""); print; exit }' "$state")"
    current="$(journal_yaml_unquote "$current")"
    journal_write_state "$run_id" INTERRUPTED "${step:-0}" "${total:-0}" UNKNOWN "$current"
    journal_append_event "$run_id" stale_run_detected INTERRUPTED "${step:-0}" UNKNOWN '' '' 'previous RUNNING state has no live launcher'
  done < <(find "$root" -mindepth 2 -maxdepth 2 -name state.md -print0 2>/dev/null)
}

journal_validate_run() {
  local project="$1" run_id="$2" dir plan events digest expected actual total line step
  local sequence expected_sequence=1 prev_hash=GENESIS row_prev event_hash payload calculated
  local status step_status
  dir="$(journal_run_dir "$project" "$run_id")"
  plan="$dir/plan.md"; events="$dir/events.jsonl"; digest="$dir/plan.sha256"
  for file in "$plan" "$events" "$digest"; do
    [[ -f "$file" && ! -L "$file" ]] || return 1
  done
  expected="$(awk 'NF {print $1; exit}' "$digest")"
  actual="$(sha256sum "$plan" | awk '{print $1}')"
  [[ "$expected" =~ ^[0-9a-f]{64}$ && "$actual" == "$expected" ]] || return 1
  grep -Fqx "run_id: $run_id" "$plan" || return 1
  grep -Fqx "project: \"${project//\"/\\\"}\"" "$plan" || return 1
  total="$(grep -Ec '^[0-9]+\. ' "$plan" || true)"
  (( total > 0 )) || return 1
  while IFS= read -r line; do
    grep -Eq '^\{"time":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z","event":"[a-z0-9_]+","sequence":[1-9][0-9]*,"status":"[A-Z_]+","step":[0-9]+,"step_status":"[A-Z_]+","agent":"([^"\\]|\\.)*","task":"([^"\\]|\\.)*","evidence":"([^"\\]|\\.)*","prev_hash":"(GENESIS|[0-9a-f]{64})","event_hash":"[0-9a-f]{64}"\}$' <<< "$line" || return 1
    sequence="$(sed -n 's/.*"sequence":\([0-9][0-9]*\),"status".*/\1/p' <<< "$line")"
    [[ "$sequence" == "$expected_sequence" ]] || return 1
    row_prev="$(sed -n 's/.*"prev_hash":"\([A-Z0-9a-f]*\)","event_hash".*/\1/p' <<< "$line")"
    [[ "$row_prev" == "$prev_hash" ]] || return 1
    event_hash="$(sed -n 's/.*"event_hash":"\([0-9a-f]\{64\}\)"}$/\1/p' <<< "$line")"
    [[ "$event_hash" =~ ^[0-9a-f]{64}$ ]] || return 1
    payload="$(sed -E 's/,"event_hash":"[0-9a-f]{64}"}$/}/' <<< "$line")"
    calculated="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
    [[ "$calculated" == "$event_hash" ]] || return 1
    status="$(sed -n 's/.*"status":"\([A-Z_]*\)","step".*/\1/p' <<< "$line")"
    step_status="$(sed -n 's/.*"step_status":"\([A-Z_]*\)","agent".*/\1/p' <<< "$line")"
    case "$status" in PLANNED|READY|RUNNING|WAITING_USER|BLOCKED|INTERRUPTED|COMPLETED|CANCELLED) ;; *) return 1 ;; esac
    case "$step_status" in PENDING|RUNNING|PROCESS_OK|READ_ONLY_VERIFIED|ARTIFACT_VERIFIED|GATE_PASS|DOD_AUTO_PASS|DOD_PASS|UNVERIFIED|GATE_BLOCKED|DOD_BLOCKED|FAILED|SKIPPED|INTERRUPTED|UNKNOWN) ;; *) return 1 ;; esac
    step="$(sed -n 's/.*"step":\([0-9][0-9]*\),"step_status".*/\1/p' <<< "$line")"
    [[ "$step" =~ ^[0-9]+$ ]] || return 1
    (( step >= 0 && step <= total )) || return 1
    prev_hash="$event_hash"
    expected_sequence=$((expected_sequence + 1))
  done < "$events"
}

journal_resume_point() {
  local project="$1" run_id="$2" events plan total next=1 step event event_type
  local event_agent event_task entry agent task gate
  declare -A proven=() gate_passed=() dod_auto=() dod_full=() completion_passed=()
  journal_validate_run "$project" "$run_id" || return 1
  events="$(journal_run_dir "$project" "$run_id")/events.jsonl"
  plan="$(journal_run_dir "$project" "$run_id")/plan.md"
  total="$(grep -Ec '^[0-9]+\. ' "$plan")"
  while IFS= read -r event; do
    event_type="$(sed -n 's/.*"event":"\([a-z0-9_]*\)","sequence".*/\1/p' <<< "$event")"
    step="$(sed -n 's/.*"step":\([0-9][0-9]*\),"step_status".*/\1/p' <<< "$event")"
    [[ "$step" =~ ^[0-9]+$ ]] || continue
    event_agent="$(sed -n 's/.*"agent":"\([^"]*\)","task".*/\1/p' <<< "$event")"
    event_task="$(sed -n 's/.*"task":"\([^"]*\)","evidence".*/\1/p' <<< "$event")"
    case "$event_type" in
      step_artifact_verified|step_read_only_verified|step_skipped)
        (( step >= 1 && step <= total )) && proven["$step:$event_agent:$event_task"]=1
        ;;
      gate_pass) gate_passed["$step:$event_task"]=1 ;;
      software_dod_auto_pass) dod_auto["$step:$event_agent:$event_task"]=1 ;;
      software_dod_approved) dod_full["$step:$event_agent:$event_task"]=1 ;;
      cycle1_completion_pass) completion_passed["$step:$event_agent:$event_task"]=1 ;;
    esac
  done < "$events"
  while (( next <= total )); do
    entry="$(sed -n "s/^${next}\\. //p" "$plan")"
    agent="${entry%%:*}"
    task="${entry#*:}"
    [[ -n "${proven[$next:$agent:$task]:-}" ]] || break
    gate="$(cycle1_gate_before_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" || -n "${gate_passed[$next:Gate $gate]:-}" ]] || break
    gate="$(cycle1_gate_after_entry "$agent" "$task" 2>/dev/null || true)"
    [[ -z "$gate" || -n "${gate_passed[$next:Gate $gate]:-}" ]] || break
    if cycle1_software_dod_after_entry "$agent" "$task"; then
      [[ -n "${dod_auto[$next:$agent:$task]:-}" &&
         -n "${dod_full[$next:$agent:$task]:-}" ]] || break
    fi
    if cycle1_completion_after_entry "$agent" "$task"; then
      [[ -n "${completion_passed[$next:$agent:$task]:-}" ]] || break
    fi
    next=$((next + 1))
  done
  printf '%s\n' "$next"
}

journal_root_cycle_run() {
  local project="$1" current="$2" dir plan parent type depth=0
  declare -A seen=()
  while :; do
    [[ "$current" =~ ^[A-Za-z0-9._-]+$ && -z "${seen[$current]:-}" ]] || return 1
    seen["$current"]=1
    depth=$((depth + 1))
    (( depth <= 64 )) || return 1
    journal_validate_run "$project" "$current" || return 1
    dir="$(journal_run_dir "$project" "$current")"
    plan="$dir/plan.md"
    parent="$(awk -F': ' '$1 == "parent_run_id" {print $2; exit}' "$plan")"
    type="$(awk -F': ' '$1 == "type" {print $2; exit}' "$plan")"
    if [[ "$parent" == none ]]; then
      [[ "$type" == CYCLE ]] || return 1
      printf '%s\n' "$current"
      return 0
    fi
    [[ "$type" == RESUME && "$parent" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
    current="$parent"
  done
}

# Canonical capability registry for every active command template.
command_capability_record() {
  local agent="$1" task="$2" command
  [[ -f "$COMMAND_CAPABILITIES_FILE" && "$task" == /* ]] || return 1
  command="${task%% *}"
  awk -F '\t' -v agent="$agent" -v command="$command" '
    NR > 1 && $2 == agent && $3 == command { print; found=1; exit }
    END { exit(found ? 0 : 1) }
  ' "$COMMAND_CAPABILITIES_FILE"
}

command_capability_field() {
  local record="$1" field="$2"
  awk -F '\t' -v field="$field" '{ print $field }' <<< "$record"
}

command_capability() {
  local record
  record="$(command_capability_record "$1" "$2")" || return 1
  command_capability_field "$record" 4
}

command_access() {
  local record
  record="$(command_capability_record "$1" "$2")" || return 1
  command_capability_field "$record" 5
}

command_result_verifier() {
  local record
  record="$(command_capability_record "$1" "$2")" || return 1
  command_capability_field "$record" 6
}

command_metadata_stages() {
  local record
  record="$(command_capability_record "$1" "$2")" || return 1
  command_capability_field "$record" 7
}

command_metadata_types() {
  local record
  record="$(command_capability_record "$1" "$2")" || return 1
  command_capability_field "$record" 8
}

command_supported_by_one_agent() {
  local capability
  capability="$(command_capability "$1" "$2")" || return 1
  [[ "$capability" == read-only-no-output || "$capability" == mutating-declared-output ]]
}

change_scope_pointer_field() {
  local file="$1" key="$2"
  awk -F': ' -v key="$key" '$1 == key { print $2; found=1; exit } END { exit(found ? 0 : 1) }' "$file"
}

change_scope_safe_ref() {
  local value="${1:-}" segment
  [[ -n "$value" && "$value" != /* && "$value" != *$'\t'* &&
     "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *//* ]] || return 1
  IFS='/' read -r -a segments <<< "$value"
  for segment in "${segments[@]}"; do
    [[ -n "$segment" && "$segment" != . && "$segment" != .. ]] || return 1
  done
}

resolve_current_change_scope() {
  local project_dir pointer scope_ref paths_ref output
  project_dir="$(project_path)"
  pointer="$project_dir/tracking/current-change-scope-v1.yaml"
  [[ -x "$CHANGE_SCOPE_TOOL" ]] || {
    CHANGE_SCOPE_REASON='Change Scope validator is unavailable'
    return 1
  }
  if ! output="$(bash "$CHANGE_SCOPE_TOOL" current "$project_dir" 2>&1)"; then
    CHANGE_SCOPE_REASON="${output:-current approved Change Scope is missing or invalid}"
    return 1
  fi
  scope_ref="$(change_scope_pointer_field "$pointer" scope_ref 2>/dev/null || true)"
  paths_ref="$(change_scope_pointer_field "$pointer" paths_ref 2>/dev/null || true)"
  CHANGE_SCOPE_METADATA_SHA256="$(change_scope_pointer_field "$pointer" scope_sha256 2>/dev/null || true)"
  CHANGE_SCOPE_PATHS_SHA256="$(change_scope_pointer_field "$pointer" paths_sha256 2>/dev/null || true)"
  change_scope_safe_ref "$scope_ref" && change_scope_safe_ref "$paths_ref" || {
    CHANGE_SCOPE_REASON='current Change Scope pointer contains an unsafe reference'
    return 1
  }
  [[ "$CHANGE_SCOPE_METADATA_SHA256" =~ ^[0-9a-f]{64}$ &&
     "$CHANGE_SCOPE_PATHS_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
    CHANGE_SCOPE_REASON='current Change Scope pointer has no exact digest'
    return 1
  }
  CHANGE_SCOPE_METADATA_FILE="$project_dir/$scope_ref"
  CHANGE_SCOPE_PATHS_FILE="$project_dir/$paths_ref"
  CHANGE_SCOPE_REASON="$output"
}

change_scope_mark_resolution() {
  local record="$1" reason="$2" resolved tmp
  resolved="${record%.yaml}.resolved.yaml"
  [[ ! -e "$resolved" ]] || return 0
  tmp="$(mktemp "${resolved}.tmp.XXXXXX")" || return 1
  printf 'schema_version: 1\nviolation_ref: %s\nresolution: %s\nresolved_at: %s\n' \
    "$(basename "$record")" "$reason" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  mv "$tmp" "$resolved"
}

change_scope_has_unresolved_violation() {
  local violations record resolved recorded_scope before before_sha paths paths_sha agent command current report
  violations="$(journal_root "$PROJECT")/violations"
  [[ -d "$violations" ]] || return 1
  while IFS= read -r -d '' record; do
    resolved="${record%.yaml}.resolved.yaml"
    [[ ! -f "$resolved" ]] || continue
    recorded_scope="$(change_scope_pointer_field "$record" scope_sha256 2>/dev/null || true)"
    if [[ -n "$recorded_scope" && "$recorded_scope" != "$CHANGE_SCOPE_METADATA_SHA256" ]]; then
      change_scope_mark_resolution "$record" FRESH_APPROVED_SCOPE || return 0
      continue
    fi
    before="$(change_scope_pointer_field "$record" before_manifest 2>/dev/null || true)"
    before_sha="$(change_scope_pointer_field "$record" before_manifest_sha256 2>/dev/null || true)"
    paths="${record%.yaml}.paths.tsv"
    paths_sha="$(change_scope_pointer_field "$record" paths_sha256 2>/dev/null || true)"
    agent="$(change_scope_pointer_field "$record" agent 2>/dev/null || true)"
    command="$(change_scope_pointer_field "$record" command 2>/dev/null || true)"
    [[ -f "$before" && ! -L "$before" && -f "$paths" && ! -L "$paths" &&
       "$(sha256sum "$before" | awk '{print $1}')" == "$before_sha" &&
       "$(sha256sum "$paths" | awk '{print $1}')" == "$paths_sha" ]] || return 0
    current="$(mktemp "$(journal_root "$PROJECT")/violation-current.XXXXXX.tsv")" || return 0
    if bash "$CHANGE_SCOPE_TOOL" snapshot "$(project_path)" "$current" >/dev/null 2>&1 &&
       bash "$CHANGE_SCOPE_TOOL" verify-diff "$(project_path)" "$before" "$current" \
         "$paths" "$agent" "$command" >/dev/null 2>&1; then
      change_scope_mark_resolution "$record" OUT_OF_SCOPE_CHANGES_REMOVED || { rm -f "$current"; return 0; }
      rm -f "$current"
      continue
    fi
    rm -f "$current"
    return 0
  done < <(find "$violations" -maxdepth 1 -type f -name 'VIOLATION-*.yaml' \
    ! -name '*.resolved.yaml' -print0 | sort -z)
  return 1
}

prepare_change_scope_step() {
  local agent="$1" task="$2" step="${3:-0}" run_dir command output
  CHANGE_SCOPE_REASON=''
  resolve_current_change_scope || return 1
  if change_scope_has_unresolved_violation; then
    CHANGE_SCOPE_REASON='an unresolved out-of-scope Project change blocks Stage 4 mutation'
    return 1
  fi
  [[ -n "${CURRENT_RUN_ID:-}" ]] || {
    CHANGE_SCOPE_REASON='Execution Journal run is required for scoped-write'
    return 1
  }
  run_dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  command="${task%% *}"
  mkdir -p "$run_dir/change-scope"
  CHANGE_SCOPE_INVOCATION_DIR="$(mktemp -d "$run_dir/change-scope/step-${step}-${agent}-${command#/}.XXXXXX")" || return 1
  ACTIVE_CHANGE_SCOPE_FILE="$CHANGE_SCOPE_INVOCATION_DIR/runtime-access-v1.tsv"
  if ! output="$(bash "$CHANGE_SCOPE_TOOL" runtime-access "$(project_path)" \
      "$CHANGE_SCOPE_METADATA_FILE" "$agent" "$command" "$ACTIVE_CHANGE_SCOPE_FILE" 2>&1)"; then
    CHANGE_SCOPE_REASON="$output"
    return 1
  fi
  ACTIVE_CHANGE_SCOPE_SHA256="$(sha256sum "$ACTIVE_CHANGE_SCOPE_FILE" | awk '{print $1}')"
  CHANGE_SCOPE_BEFORE_MANIFEST="$CHANGE_SCOPE_INVOCATION_DIR/before-tree-v1.tsv"
  CHANGE_SCOPE_AFTER_MANIFEST="$CHANGE_SCOPE_INVOCATION_DIR/after-tree-v1.tsv"
  if ! output="$(bash "$CHANGE_SCOPE_TOOL" snapshot "$(project_path)" "$CHANGE_SCOPE_BEFORE_MANIFEST" 2>&1)"; then
    CHANGE_SCOPE_REASON="$output"
    return 1
  fi
  SDLC_CHANGE_SCOPE_SHA256="$CHANGE_SCOPE_METADATA_SHA256"
  export SDLC_CHANGE_SCOPE_SHA256
  CHANGE_SCOPE_REASON="scope_sha256=$CHANGE_SCOPE_METADATA_SHA256 runtime_sha256=$ACTIVE_CHANGE_SCOPE_SHA256"
  [[ -z "${CURRENT_RUN_ID:-}" ]] ||
    journal_append_event "$CURRENT_RUN_ID" change_scope_ready RUNNING "$step" RUNNING \
      "$agent" "$command" "$CHANGE_SCOPE_REASON"
}

record_change_scope_violation() {
  local agent="$1" command="$2" step="$3" report="$4" root stamp record tmp copied_paths
  root="$(journal_root "$PROJECT")/violations"
  mkdir -p "$root"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)-${CURRENT_RUN_ID:-run}-${step}-${BASHPID:-$$}-$RANDOM"
  record="$root/VIOLATION-$stamp.yaml"
  [[ ! -e "$record" && ! -e "${record%.yaml}.paths.tsv" ]] || return 1
  copied_paths="${record%.yaml}.paths.tsv"
  cp "$CHANGE_SCOPE_PATHS_FILE" "$copied_paths" || return 1
  tmp="$(mktemp "${record}.tmp.XXXXXX")" || return 1
  printf 'schema_version: 1\nstatus: UNRESOLVED\nproject: %s\nrun_id: %s\nstep: %s\nagent: %s\ncommand: %s\nscope_sha256: %s\npaths_sha256: %s\nbefore_manifest: %s\nbefore_manifest_sha256: %s\nafter_manifest: %s\nafter_manifest_sha256: %s\nreport: %s\nobserved_at: %s\n' \
    "$PROJECT" "${CURRENT_RUN_ID:-none}" "$step" "$agent" "$command" \
    "$CHANGE_SCOPE_METADATA_SHA256" "$(sha256sum "$copied_paths" | awk '{print $1}')" \
    "$CHANGE_SCOPE_BEFORE_MANIFEST" "$(sha256sum "$CHANGE_SCOPE_BEFORE_MANIFEST" | awk '{print $1}')" \
    "$CHANGE_SCOPE_AFTER_MANIFEST" "$(sha256sum "$CHANGE_SCOPE_AFTER_MANIFEST" | awk '{print $1}')" \
    "$report" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  mv "$tmp" "$record"
  CHANGE_SCOPE_VIOLATION_RECORD="$record"
}

verify_change_scope_step() {
  local agent="$1" task="$2" step="${3:-0}" command output report
  command="${task%% *}"
  report="$CHANGE_SCOPE_INVOCATION_DIR/diff-verification.out"
  if ! output="$(bash "$CHANGE_SCOPE_TOOL" snapshot "$(project_path)" "$CHANGE_SCOPE_AFTER_MANIFEST" 2>&1)"; then
    CHANGE_SCOPE_REASON="$output"
    return 1
  fi
  if bash "$CHANGE_SCOPE_TOOL" verify-diff "$(project_path)" "$CHANGE_SCOPE_BEFORE_MANIFEST" \
      "$CHANGE_SCOPE_AFTER_MANIFEST" "$CHANGE_SCOPE_PATHS_FILE" "$agent" "$command" > "$report" 2>&1; then
    CHANGE_SCOPE_REASON="$(tr '\n' ';' < "$report" | sed 's/;$//')"
    [[ -z "${CURRENT_RUN_ID:-}" ]] ||
      journal_append_event "$CURRENT_RUN_ID" change_scope_verified RUNNING "$step" ARTIFACT_VERIFIED \
        "$agent" "$command" "$CHANGE_SCOPE_REASON"
    return 0
  fi
  CHANGE_SCOPE_REASON="$(tr '\n' ';' < "$report" | sed 's/;$//')"
  record_change_scope_violation "$agent" "$command" "$step" "$report" || true
  [[ -z "${CURRENT_RUN_ID:-}" ]] ||
    journal_append_event "$CURRENT_RUN_ID" change_scope_violation BLOCKED "$step" UNVERIFIED \
      "$agent" "$command" "$CHANGE_SCOPE_REASON"
  return 1
}

clear_active_change_scope() {
  ACTIVE_CHANGE_SCOPE_FILE=''
  ACTIVE_CHANGE_SCOPE_SHA256=''
  SDLC_CHANGE_SCOPE_SHA256=''
  export SDLC_CHANGE_SCOPE_SHA256
}

change_scope_project_source() {
  local project_dir="$1" revision
  if [[ -e "$project_dir/.git" ]] &&
     revision="$(git -C "$project_dir" rev-parse --verify HEAD 2>/dev/null)" &&
     [[ "$revision" =~ ^[0-9a-f]{40}$|^[0-9a-f]{64}$ ]]; then
    printf '%s\n' "$revision"
    return 0
  fi
  printf '%s\n' pending-tree-digest
}

run_change_scope_preparation_agent() {
  local agent="$1" command="$2" directory="$3" step="$4" run_dir runtime_scope before after allowed
  local runtime_sha previous_access="${ACTIVE_AGENT_ACCESS:-}" rc=0 output
  run_dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/change-scope-preparation/step-$step-$agent"
  mkdir -p "$run_dir"
  runtime_scope="$run_dir/runtime-access-v1.tsv"
  printf 'schema_version\tcapability\tpath\n1\twrite\t%s\n' "$directory" > "$runtime_scope"
  runtime_sha="$(sha256sum "$runtime_scope" | awk '{print $1}')"
  before="$run_dir/before-tree-v1.tsv"
  after="$run_dir/after-tree-v1.tsv"
  allowed="$run_dir/preparation-paths-v1.tsv"
  printf 'schema_version\tintent_id\tagent\tcommand\toperation\tpath\tmodule_id\tmodule_mode\torigin\n1\tINTENT-%s\t%s\t%s\tephemeral\t%s/\tpreparation\tMODIFY\ts3\n' \
    "${SCOPE_PREP_ID#SCOPE-}" "$agent" "$command" "$directory" > "$allowed"
  bash "$CHANGE_SCOPE_TOOL" snapshot "$(project_path)" "$before" >/dev/null || return 1
  ACTIVE_CHANGE_SCOPE_FILE="$runtime_scope"
  ACTIVE_CHANGE_SCOPE_SHA256="$runtime_sha"
  ACTIVE_AGENT_ACCESS=scoped-write
  ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[$((step - 1))]:-}"
  SDLC_CHANGE_SCOPE_SHA256="$(sha256sum "$(project_path)/tracking/change-scopes/$SCOPE_PREP_ID/intent.yaml" | awk '{print $1}')"
  export SDLC_CHANGE_SCOPE_SHA256
  journal_write_state "$CURRENT_RUN_ID" RUNNING "$step" 2 RUNNING "$agent $command"
  journal_append_event "$CURRENT_RUN_ID" step_started RUNNING "$step" RUNNING "$agent" "$command" \
    "isolated Change Scope preparation directory: $directory"
  run_agent "$agent" "$PROJECT" "$command $SCOPE_PREP_ID" || rc=$?
  ACTIVE_EXECUTION_PROFILE=''
  ACTIVE_AGENT_ACCESS="$previous_access"
  clear_active_change_scope
  if ! bash "$CHANGE_SCOPE_TOOL" snapshot "$(project_path)" "$after" >/dev/null; then rc=1; fi
  if [[ $rc -ne 0 ]] || ! output="$(bash "$CHANGE_SCOPE_TOOL" verify-diff "$(project_path)" \
      "$before" "$after" "$allowed" "$agent" "$command" 2>&1)"; then
    journal_append_event "$CURRENT_RUN_ID" change_scope_preparation_blocked BLOCKED "$step" UNVERIFIED \
      "$agent" "$command" "${output:-runtime exit code $rc}"
    return 1
  fi
  case "$agent:$command" in
    l1-analyze:/impact) output="$(bash "$CHANGE_SCOPE_TOOL" validate-l1 "$(project_path)" "$SCOPE_PREP_ID" 2>&1)" || return 1 ;;
    s3-arch:/change-impact) output="$(bash "$CHANGE_SCOPE_TOOL" validate-s3 "$(project_path)" "$SCOPE_PREP_ID" 2>&1)" || return 1 ;;
    *) return 1 ;;
  esac
  journal_append_event "$CURRENT_RUN_ID" change_scope_preparation_verified RUNNING "$step" ARTIFACT_VERIFIED \
    "$agent" "$command" "$output"
}

change_scope_preparation_blocked() {
  local step="$1" reason="$2"
  journal_write_state "$CURRENT_RUN_ID" BLOCKED "$step" 2 UNVERIFIED 'Change Scope preparation'
  journal_append_event "$CURRENT_RUN_ID" run_blocked BLOCKED "$step" UNVERIFIED '' '' "$reason"
  journal_release_lease "$CURRENT_RUN_ID"
  printf '%s\n' "$reason"
  return 1
}

execute_change_scope_preparation() {
  local run_dir baseline_manifest baseline_sha actual_source init_output request
  local approval_id subject scope evidence_producer activate_output actual_profile_revision
  journal_create_run SCOPE "Change Intent $SCOPE_PREP_KIND: $SCOPE_PREP_REFS" \
    'Stage 4 mutation, approval self-service and all paths outside isolated L1/S3 outputs' || return 1
  journal_acquire_lease "$CURRENT_RUN_ID" || return 1
  run_dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  journal_write_state "$CURRENT_RUN_ID" READY 0 2 PENDING ''
  journal_append_event "$CURRENT_RUN_ID" execution_confirmed READY 0 PENDING '' '' \
    'user explicitly confirmed Change Intent preview'
  baseline_manifest="$run_dir/change-scope-baseline-v1.tsv"
  bash "$CHANGE_SCOPE_TOOL" snapshot "$(project_path)" "$baseline_manifest" >/dev/null || {
    change_scope_preparation_blocked 0 'cannot create exact Project baseline'; return 1;
  }
  baseline_sha="$(sha256sum "$baseline_manifest" | awk '{print $1}')"
  actual_source="$(change_scope_project_source "$(project_path)")"
  [[ "$actual_source" != pending-tree-digest ]] || actual_source="sha256:$baseline_sha"
  if [[ -n "$SCOPE_PREP_SOURCE" && "$SCOPE_PREP_SOURCE" != pending-tree-digest &&
        "$actual_source" != "$SCOPE_PREP_SOURCE" ]]; then
    change_scope_preparation_blocked 0 'Project source revision changed after Preview'
    return 1
  fi
  SCOPE_PREP_SOURCE="$actual_source"
  actual_profile_revision="$(read_product_ci_profile_field revision 2>/dev/null || true)"
  if [[ "$actual_profile_revision" != "$SCOPE_PREP_PROFILE_REVISION" ]]; then
    change_scope_preparation_blocked 0 'Product & CI Profile revision changed after Preview'
    return 1
  fi
  if ! init_output="$(bash "$CHANGE_SCOPE_TOOL" init "$(project_path)" "$SCOPE_PREP_ID" \
      "$SCOPE_PREP_KIND" "$SCOPE_PREP_REFS" "$SCOPE_PREP_SOURCE" "$baseline_sha" \
      "$SCOPE_PREP_PROFILE_REVISION" "$CURRENT_RUN_ID" 2>&1)"; then
    change_scope_preparation_blocked 0 "$init_output"
    return 1
  fi
  journal_append_event "$CURRENT_RUN_ID" change_intent_created RUNNING 0 ARTIFACT_VERIFIED \
    launcher /change-scope "$init_output"
  if ! run_change_scope_preparation_agent l1-analyze /impact \
      "tracking/change-scopes/$SCOPE_PREP_ID/l1" 1; then
    change_scope_preparation_blocked 1 'L1 Change Scope preparation failed or changed another path'
    return 1
  fi
  if ! run_change_scope_preparation_agent s3-arch /change-impact \
      "tracking/change-scopes/$SCOPE_PREP_ID/s3" 2; then
    change_scope_preparation_blocked 2 'S3 Change Scope preparation failed or changed another path'
    return 1
  fi
  if ! request="$(bash "$CHANGE_SCOPE_TOOL" request "$(project_path)" "$SCOPE_PREP_ID" 2>&1)"; then
    change_scope_preparation_blocked 2 "$request"
    return 1
  fi
  approval_id="$(awk -F': ' '$1=="approval_id" {print $2; exit}' <<< "$request")"
  subject="$(awk -F': ' '$1=="subject_digest" {print $2; exit}' <<< "$request")"
  scope="$(awk -F': ' '$1=="scope" {sub(/^[^:]*: /, ""); print; exit}' <<< "$request")"
  evidence_producer="$(awk -F': ' '$1=="evidence_producer" {print $2; exit}' <<< "$request")"
  [[ "$approval_id" =~ ^APPROVAL-SCOPE-[A-Z0-9._-]+$ && "$subject" =~ ^[0-9a-f]{64}$ &&
     "$scope" == change-scope:* && "$evidence_producer" == s3-arch ]] || {
    change_scope_preparation_blocked 2 'invalid Change Scope approval request'; return 1;
  }
  printf '%s\n' 'CHANGE SCOPE APPROVAL PREVIEW' "$request"
  journal_write_state "$CURRENT_RUN_ID" WAITING_USER 2 2 UNVERIFIED 'Human Change Scope Approval'
  journal_append_event "$CURRENT_RUN_ID" change_scope_approval_requested WAITING_USER 2 UNVERIFIED \
    launcher /change-scope "subject_digest=$subject scope=$scope"
  if ! bash "$AGENTS/_runtimes/human-approval-record.sh" "$(project_path)" "$approval_id" \
      "$SCOPE_PREP_SOURCE" "$subject" "$scope" "$evidence_producer"; then
    change_scope_preparation_blocked 2 'Human Change Scope Approval was not recorded'
    return 1
  fi
  if ! activate_output="$(bash "$CHANGE_SCOPE_TOOL" activate "$(project_path)" "$SCOPE_PREP_ID" 2>&1)"; then
    change_scope_preparation_blocked 2 "$activate_output"
    return 1
  fi
  journal_append_event "$CURRENT_RUN_ID" change_scope_activated COMPLETED 2 ARTIFACT_VERIFIED \
    launcher /change-scope "$activate_output"
  journal_write_state "$CURRENT_RUN_ID" COMPLETED 2 2 ARTIFACT_VERIFIED ''
  journal_release_lease "$CURRENT_RUN_ID"
  printf '%s\n' "$activate_output"
}

menu_change_scope_preparation() {
  local choice refs stamp
  require_product_ci_profile || return 1
  printf '%s\n' \
    'CHANGE SCOPE PREPARATION' \
    '1 Backlog/FR/task refs (default)' \
    '2 Existing Change Request' \
    'b Назад'
  read -rp 'Источник [1]: ' choice
  case "$choice" in
    ''|1) SCOPE_PREP_KIND=BACKLOG; read -rp 'Exact backlog/FR/task refs через запятую: ' refs ;;
    2) SCOPE_PREP_KIND=CHANGE_REQUEST; read -rp 'Exact existing Change Request ref: ' refs ;;
    b|B) return 0 ;;
    *) return 1 ;;
  esac
  [[ -n "$refs" && "$refs" != *$'\n'* && "$refs" != *$'\r'* ]] || {
    echo -e "${R}BLOCKED: exact Change Intent refs are required.${N}"; return 1;
  }
  SCOPE_PREP_REFS="$refs"
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  SCOPE_PREP_ID="SCOPE-$stamp-$RANDOM"
  SCOPE_PREP_SOURCE="$(change_scope_project_source "$(project_path)")"
  SCOPE_PREP_PROFILE_REVISION="$(read_product_ci_profile_field revision 2>/dev/null || true)"
  [[ "$SCOPE_PREP_PROFILE_REVISION" =~ ^[1-9][0-9]*$ ]] || {
    echo -e "${R}BLOCKED: valid current Product & CI Profile is required.${N}"; return 1;
  }
  local -a RUN_CYCLE=('l1-analyze:/impact' 's3-arch:/change-impact')
  local -a RUN_OPTIONAL=(0 0)
  EXECUTION_TYPE=SCOPE
  EXECUTION_SCOPE="$SCOPE_PREP_KIND $SCOPE_PREP_REFS → L1 /impact → S3 /change-impact → Human Approval"
  EXECUTION_EXCLUDED='Stage 4 mutation; approval by any primary agent; scope self-expansion'
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview execute_change_scope_preparation
}

tracker_special_command() {
  [[ "${1:-}" == s0-tracker ]] || return 1
  case "${2%% *}" in
    /sprint-close|/sprint-init|/task-add|/task-block|/task-done) return 0 ;;
    *) return 1 ;;
  esac
}

tracker_special_expected_verifier() {
  [[ "${1:-}" == s0-tracker ]] || return 1
  case "${2%% *}" in
    /sprint-close) printf '%s\n' tracker-sprint-close-postconditions ;;
    /sprint-init) printf '%s\n' tracker-sprint-init-postconditions ;;
    /task-add|/task-block) printf '%s\n' tracker-task-postconditions ;;
    /task-done) printf '%s\n' tracker-task-done-postconditions ;;
    *) return 1 ;;
  esac
}

tracker_prompt_value() {
  local task="${1:-}" key="${2:-}"
  [[ "$key" =~ ^[a-z-]+$ ]] || return 1
  if [[ " $task " =~ [[:space:]]${key}=([^[:space:]]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# The canonical output registry owns logical ids, compatibility names and current tracking.
# Each output line is one required group; "|" separates allowed alternatives.
cycle1_declared_output_groups() {
  local agent="$1" task="$2" command="${2%% *}" version='' rows pattern
  [[ -f "$CURRENT_ARTIFACT_GROUPS_FILE" ]] || return 1
  rows="$(awk -F'\t' -v agent="$agent" -v command="$command" '
    NR > 1 && $1 == agent && $2 == command { print $7 }
  ' "$CURRENT_ARTIFACT_GROUPS_FILE")"
  [[ -n "$rows" ]] || return 1
  if [[ "$command" == /release-notes ]]; then
    version="${task#/release-notes }"
    [[ "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || return 1
  fi
  while IFS= read -r pattern; do
    printf '%s\n' "${pattern//\{version\}/$version}"
  done <<< "$rows"
}

cycle1_tracks_current_outputs() {
  local agent="$1" command="${2%% *}"
  [[ -f "$CURRENT_ARTIFACT_GROUPS_FILE" ]] || return 1
  awk -F'\t' -v agent="$agent" -v command="$command" '
    NR > 1 && $1 == agent && $2 == command && $6 == "yes" { found=1 }
    END { exit(found ? 0 : 1) }
  ' "$CURRENT_ARTIFACT_GROUPS_FILE"
}

declared_output_files() {
  local agent="$1" task="$2" root="$(project_path)" group pattern
  while IFS= read -r group; do
    IFS='|' read -r -a patterns <<< "$group"
    for pattern in "${patterns[@]}"; do
      find "$root" -type f -path "$root/$pattern" -print0 2>/dev/null
    done
  done < <(cycle1_declared_output_groups "$agent" "$task")
}

declared_output_fingerprint() {
  local agent="$1" task="$2" root="$(project_path)" file
  cycle1_declared_output_groups "$agent" "$task" >/dev/null || return 1
  while IFS= read -r -d '' file; do
    printf '%s\t%s\n' "${file#"$root/"}" "$(cksum < "$file" | awk '{print $1 ":" $2}')"
  done < <(declared_output_files "$agent" "$task" | sort -zu)
}

verify_declared_outputs() {
  local agent="$1" task="$2" before="$3" root="$(project_path)"
  local group pattern found after ref checksum metadata_output metadata_stages metadata_types
  local -a changed_refs=()
  local -A before_checksums=()
  if ! cycle1_declared_output_groups "$agent" "$task" >/dev/null; then
    DECLARED_OUTPUT_REASON="no declared-output mapping for $agent $task"
    return 1
  fi
  while IFS= read -r group; do
    found=0
    IFS='|' read -r -a patterns <<< "$group"
    for pattern in "${patterns[@]}"; do
      if find "$root" -type f -path "$root/$pattern" -print -quit 2>/dev/null | grep -q .; then
        found=1
        break
      fi
    done
    if [[ $found -ne 1 ]]; then
      DECLARED_OUTPUT_REASON="missing declared output group: $group"
      return 1
    fi
  done < <(cycle1_declared_output_groups "$agent" "$task")
  after="$(declared_output_fingerprint "$agent" "$task")" || return 1
  if [[ "$after" == "$before" ]]; then
    DECLARED_OUTPUT_REASON='declared outputs exist but were not changed by this process'
    return 1
  fi
  while IFS=$'\t' read -r ref checksum; do
    [[ -n "$ref" ]] && before_checksums["$ref"]="$checksum"
  done <<< "$before"
  while IFS=$'\t' read -r ref checksum; do
    [[ -n "$ref" ]] || continue
    if [[ "${before_checksums[$ref]:-}" != "$checksum" ]]; then
      changed_refs+=("$ref")
    fi
  done <<< "$after"
  (( ${#changed_refs[@]} > 0 )) || {
    DECLARED_OUTPUT_REASON='declared output snapshot changed without a new/modified path'
    return 1
  }
  metadata_stages="$(command_metadata_stages "$agent" "$task" 2>/dev/null || true)"
  metadata_types="$(command_metadata_types "$agent" "$task" 2>/dev/null || true)"
  local group_changed changed_ref
  while IFS= read -r group; do
    group_changed=0
    IFS='|' read -r -a patterns <<< "$group"
    for pattern in "${patterns[@]}"; do
      for changed_ref in "${changed_refs[@]}"; do
        if [[ "$changed_ref" == $pattern ]]; then
          group_changed=1
          break 2
        fi
      done
    done
    if [[ $group_changed -ne 1 ]]; then
      DECLARED_OUTPUT_REASON="stale declared output group: $group"
      return 1
    fi
  done < <(cycle1_declared_output_groups "$agent" "$task")
  for ref in "${changed_refs[@]}"; do
    [[ "$ref" == *.md ]] || continue
    if [[ -z "$metadata_stages" || "$metadata_stages" == - ||
          -z "$metadata_types" || "$metadata_types" == - ]]; then
      DECLARED_OUTPUT_REASON="$ref has no registry-bound metadata stage/type contract"
      return 1
    fi
    if ! metadata_output="$(bash "$AGENTS/cycle1-dev/s0-validate/artifact-metadata-check.sh" \
      "$root" "$ref" "$agent" "$metadata_stages" "$metadata_types" 2>&1)"; then
      DECLARED_OUTPUT_REASON="$ref metadata invalid: $metadata_output"
      return 1
    fi
  done
  DECLARED_OUTPUT_CHANGED_REFS="$(IFS=,; printf '%s' "${changed_refs[*]}")"
  local current_output='' plan_sha=''
  if cycle1_tracks_current_outputs "$agent" "$task" &&
     [[ -n "${CURRENT_RUN_ID:-}" && -d "$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")" ]]; then
    plan_sha="$(awk 'NF {print $1; exit}' "$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/plan.sha256")"
    if ! current_output="$(bash "$CURRENT_ARTIFACT_TOOL" update "$root" "$agent" "$task" \
      "$CURRENT_RUN_ID" "$plan_sha" "$DECLARED_OUTPUT_CHANGED_REFS" 2>&1)"; then
      DECLARED_OUTPUT_REASON="current artifact update failed: $current_output"
      return 1
    fi
  fi
  DECLARED_OUTPUT_REASON="declared outputs changed and metadata verified: $DECLARED_OUTPUT_CHANGED_REFS"
  [[ -z "$current_output" ]] || DECLARED_OUTPUT_REASON+="; $current_output"
}

cycle1_step_field() {
  local agent="$1" task="${2%% *}" column="$3"
  awk -F'\t' -v agent="$agent" -v task="$task" -v column="$column" '
    NR > 1 && $2 == agent && $3 == task { print $column; found=1; exit }
    END { exit(found ? 0 : 1) }
  ' "$CYCLE1_STEPS_FILE"
}

cycle1_gate_before_entry() {
  local value
  value="$(cycle1_step_field "$1" "$2" 4)" || return 1
  [[ "$value" != none ]] || return 1
  printf '%s\n' "$value"
}

cycle1_gate_after_entry() {
  local value
  value="$(cycle1_step_field "$1" "$2" 5)" || return 1
  [[ "$value" != none ]] || return 1
  printf '%s\n' "$value"
}

cycle1_software_dod_after_entry() {
  [[ "$(cycle1_step_field "$1" "$2" 6 2>/dev/null || true)" == full ]]
}

cycle1_completion_after_entry() {
  [[ "$(cycle1_step_field "$1" "$2" 7 2>/dev/null || true)" == full ]]
}

release_notes_after_entry() {
  [[ "$1:$2" == 's0-tracker:/release-notes 'v* ]]
}

release_manifest_field() {
  local field="$1" manifest="$(project_path)/tracking/completion/CYCLE1-completion-v2.yaml"
  [[ -f "$manifest" ]] || return 1
  awk -F: -v wanted="$field" '$1 == wanted { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }' "$manifest"
}

run_release_notes_validator() {
  bash "$AGENTS/cycle1-dev/s0-validate/release-notes-check.sh" "$(project_path)" "$1"
}

prepare_release_notes_context() {
  local task="$1" version manifest target output
  if [[ ! "$task" =~ ^/release-notes[[:space:]]+(v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))$ ]]; then
    echo -e "${R}BLOCKED: version должна иметь вид vMAJOR.MINOR.PATCH без ведущих нулей.${N}"
    return 1
  fi
  version="${BASH_REMATCH[1]}"
  if ! output="$(run_cycle1_completion_validator 2>&1)"; then
    printf '%s\n' "$output"
    echo -e "${R}BLOCKED: release notes требуют verified Cycle 1 completion.${N}"
    return 1
  fi
  manifest="$(project_path)/tracking/completion/CYCLE1-completion-v2.yaml"
  target="$(project_path)/tracking/releases/REL-$version-release-notes.md"
  RELEASE_NOTES_VERSION="$version"
  RELEASE_NOTES_SOURCE="$(release_manifest_field source_revision)"
  RELEASE_NOTES_MANIFEST_REF='tracking/completion/CYCLE1-completion-v2.yaml'
  RELEASE_NOTES_MANIFEST_SHA="$(sha256sum "$manifest" | awk '{print $1}')"
  RELEASE_NOTES_TARGET_REF="tracking/releases/REL-$version-release-notes.md"
  if [[ -e "$target" ]]; then
    if [[ -f "$target" && ! -L "$target" ]] && run_release_notes_validator "$version" >/dev/null 2>&1; then
      echo "RELEASE NOTES NO-OP: valid artifact already exists for version=$version source=$RELEASE_NOTES_SOURCE path=$RELEASE_NOTES_TARGET_REF"
      return 2
    fi
    echo -e "${R}BLOCKED: existing release-notes target conflicts with verified version/source: $RELEASE_NOTES_TARGET_REF${N}"
    return 1
  fi
  return 0
}

product_ci_profile_file() {
  printf '%s/tracking/product-ci-profile.yaml\n' "$(project_path)"
}

read_product_ci_profile_field() {
  local field="$1" file
  file="$(product_ci_profile_file)"
  [[ -f "$file" ]] || return 1
  awk -F: -v wanted="$field" '
    $1 == wanted {
      value=$0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

require_product_ci_profile() {
  local validator="$AGENTS/cycle1-dev/s0-validate/product-ci-profile-check.sh"
  if ! bash "$validator" "$(project_path)"; then
    echo -e "${R}BLOCKED: до Stage 1 нужен valid Product & CI Profile.${N}"
    echo -e "Запусти ${C}s0-kickoff /product-ci-profile${N} для Project $PROJECT."
    return 1
  fi
}

run_cycle1_gate_validator() {
  bash "$AGENTS/cycle1-dev/s0-validate/dor-check.sh" "$(project_path)" "$1"
}

run_cycle1_software_dod_validator() {
  local source
  source="$(read_cycle_tdd_field 1 source_revision)" || {
    echo -e "${R}DOD BLOCKED: exact TDD source revision отсутствует.${N}"
    return 1
  }
  bash "$AGENTS/cycle1-dev/s0-validate/dod-check.sh" "$(project_path)" K 4 '' "$source"
}

run_cycle1_full_dod_validator() {
  local source output approval_ref root_run root_dir plan_sha request
  local approval_id subject_digest scope evidence_producer
  source="$(read_cycle_tdd_field 1 source_revision)" || {
    echo -e "${R}DOD APPROVAL BLOCKED: exact TDD source revision отсутствует.${N}"
    return 1
  }
  if ! output="$(bash "$AGENTS/cycle1-dev/s0-validate/dod-approval-check.sh" \
    "$(project_path)" "$source" "${CURRENT_RUN_ID:-}" 2>&1)"; then
    if [[ -z "${CURRENT_RUN_ID:-}" ||
      "$output" != *'exact source/run requires one full DoD approval, found 0'* ]]; then
      printf '%s\n' "$output"
      return 1
    fi
    request="$(bash "$AGENTS/cycle1-dev/s0-validate/dod-approval-check.sh" \
      "$(project_path)" "$source" "$CURRENT_RUN_ID" request 2>&1)" || {
      printf '%s\n' "$request"
      return 1
    }
    printf '%s\n' "$request"
    approval_id="$(awk -F': ' '$1 == "approval_id" {print $2; exit}' <<< "$request")"
    subject_digest="$(awk -F': ' '$1 == "subject_digest" {print $2; exit}' <<< "$request")"
    scope="$(awk -F': ' '$1 == "scope" {sub(/^[^:]*:[[:space:]]*/, "", $0); print; exit}' <<< "$request")"
    evidence_producer="$(awk -F': ' '$1 == "evidence_producer" {print $2; exit}' <<< "$request")"
    [[ "$approval_id" =~ ^APPROVAL-DOD-[A-Z0-9._-]+$ &&
      "$subject_digest" =~ ^[0-9a-f]{64}$ && -n "$scope" &&
      "$evidence_producer" == s4-dev ]] || {
      echo -e "${R}DOD APPROVAL BLOCKED: invalid launcher approval request.${N}"
      return 1
    }
    bash "$AGENTS/_runtimes/human-approval-record.sh" "$(project_path)" \
      "$approval_id" "$source" "$subject_digest" "$scope" "$evidence_producer" || return 1
    output="$(bash "$AGENTS/cycle1-dev/s0-validate/dod-approval-check.sh" \
      "$(project_path)" "$source" "$CURRENT_RUN_ID" 2>&1)" || {
      printf '%s\n' "$output"
      return 1
    }
  fi
  printf '%s\n' "$output"
  approval_ref="$(sed -n 's/^DOD APPROVAL VERIFIED: approval=\([^[:space:]]*\).*/\1/p' <<< "$output")"
  [[ -n "$approval_ref" ]] || return 1
  if [[ -n "${CURRENT_RUN_ID:-}" ]]; then
    root_run="$(journal_root_cycle_run "$PROJECT" "$CURRENT_RUN_ID")" || return 1
    root_dir="$(journal_run_dir "$PROJECT" "$root_run")"
    plan_sha="$(awk 'NF {print $1; exit}' "$root_dir/plan.sha256")"
    bash "$AGENTS/cycle1-dev/s0-validate/current-artifact.sh" update \
      "$(project_path)" launcher /full-dod-approval "$CURRENT_RUN_ID" "$plan_sha" "$approval_ref"
  fi
}

run_cycle1_completion_validator() {
  bash "$AGENTS/cycle1-dev/s0-validate/cycle1-completion-check.sh" "$(project_path)"
}

prepare_cycle1_completion_context() {
  local run_id="${1:-$CURRENT_RUN_ID}" root_run root_dir manifest
  root_run="$(journal_root_cycle_run "$PROJECT" "$run_id")" || return 1
  root_dir="$(journal_run_dir "$PROJECT" "$root_run")"
  manifest="$(project_path)/tracking/current-artifacts-v1.tsv"
  [[ -f "$root_dir/plan.sha256" && -f "$manifest" ]] || return 1
  SDLC_EXECUTION_RUN_ID="$run_id"
  SDLC_EXECUTION_PLAN_SHA256="$(awk 'NF {print $1; exit}' "$root_dir/plan.sha256")"
  SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256="$(sha256sum "$manifest" | awk '{print $1}')"
  export SDLC_EXECUTION_RUN_ID SDLC_EXECUTION_PLAN_SHA256 SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256
}

clear_cycle1_completion_context() {
  SDLC_EXECUTION_RUN_ID=''
  SDLC_EXECUTION_PLAN_SHA256=''
  SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256=''
  export SDLC_EXECUTION_RUN_ID SDLC_EXECUTION_PLAN_SHA256 SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256
}

run_cycle1_execution_proof_create() {
  bash "$AGENTS/cycle1-dev/s0-validate/cycle1-execution-proof-check.sh" \
    create "$(project_path)" "$CURRENT_RUN_ID"
}

expand_path() {
  local value="$1"
  [[ "$value" == "~" ]] && value="$HOME"
  [[ "$value" == "~/"* ]] && value="$HOME/${value#~/}"
  echo "$value"
}

normalize_runtime() {
  local runtime="${1:-}"
  [[ -z "$runtime" ]] && return 1
  runtime="${runtime,,}"
  case "$runtime" in
    claude|codex|gemini|local) echo "$runtime" ;;
    *) return 1 ;;
  esac
}

init_runtime() {
  local requested="${1:-${AGENT_RUNTIME:-}}"
  local normalized
  if ! normalized="$(normalize_runtime "$requested")"; then
    [[ -n "$requested" ]] && echo -e "${R}Неизвестный runtime: ${requested}${N}"
    [[ -n "$requested" ]] && echo -e "Ожидается: ${C}claude${N}, ${C}codex${N}, ${C}gemini${N} или ${C}local${N}"
    return 1
  fi
  AGENT_RUNTIME="$normalized"
  export AGENT_RUNTIME
}

runtime_label() {
  case "$AGENT_RUNTIME" in
    claude) echo "Claude" ;;
    codex) echo "Codex" ;;
    gemini) echo "Gemini" ;;
    local) echo "Local model" ;;
    "") echo "не выбран" ;;
    *) echo "$AGENT_RUNTIME" ;;
  esac
}

runtime_supports_interactive() {
  case "$AGENT_RUNTIME:${LOCAL_AGENT_HOST:-}" in
    codex:*|local:codex-oss) return 1 ;;
    *) return 0 ;;
  esac
}

report_interactive_codex_block() {
  echo -e "${R}BLOCKED: interactive Codex cannot disable ambient user configuration; use a registered command in task mode.${N}"
}

runtime_bin() {
  case "$AGENT_RUNTIME" in
    claude) echo "${CLAUDE_BIN:-claude}" ;;
    codex) echo "${CODEX_BIN:-codex}" ;;
    gemini) echo "${GEMINI_BIN:-gemini}" ;;
    local)
      if [[ -n "${LOCAL_AGENT_HOST:-}" ]]; then
        echo "$AGENTS/_runtimes/local-hosts/$LOCAL_AGENT_HOST"
      else
        echo "не выбран"
      fi
      ;;
    *) echo "" ;;
  esac
}

ensure_runtime_available() {
  local bin
  if [[ -z "${AGENT_RUNTIME:-}" ]]; then
    echo -e "${R}Runtime не выбран.${N}"
    return 1
  fi
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    if [[ -z "${LOCAL_AGENT_HOST:-}" || -z "${LOCAL_MODEL_PROVIDER:-}" || -z "${LOCAL_MODEL:-}" ]]; then
      echo -e "${R}Local runtime требует явные agent host, provider и model id.${N}"
      return 1
    fi
    if [[ ! "$LOCAL_AGENT_HOST" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo -e "${R}Недопустимый id local agent host: $LOCAL_AGENT_HOST${N}"
      return 1
    fi
    bin="${LOCAL_HOST_REGISTRY:-$AGENTS/_runtimes/local-hosts}/$LOCAL_AGENT_HOST"
    if [[ ! -f "$bin" || ! -x "$bin" ]]; then
      echo -e "${R}Local agent host '$LOCAL_AGENT_HOST' не зарегистрирован или не исполняемый: $bin${N}"
      return 1
    fi
    if [[ "$LOCAL_AGENT_HOST" == "codex-oss" ]] && ! command -v "${LOCAL_CODEX_BIN:-codex}" >/dev/null 2>&1; then
      echo -e "${R}codex-oss требует Codex CLI (${LOCAL_CODEX_BIN:-codex}).${N}"
      return 1
    fi
    return 0
  fi
  bin="$(runtime_bin)"
  if [[ -z "$bin" ]] || ! command -v "$bin" >/dev/null 2>&1; then
    echo -e "${R}Runtime '${AGENT_RUNTIME}' выбран, но команда '${bin}' не найдена в PATH.${N}"
    echo -e "Установи CLI, выбери другой runtime в настройках или задай ${W}${AGENT_RUNTIME^^}_BIN${N}."
    return 1
  fi
}

load_runtime() {
  local configured=""
  if [[ -n "${AGENT_RUNTIME:-}" ]]; then
    configured="$AGENT_RUNTIME"
  else
    configured="$(read_config_value AGENT_RUNTIME || true)"
  fi
  [[ -n "$configured" ]] && init_runtime "$configured" || return 1

  [[ -n "${LOCAL_AGENT_HOST:-}" ]] || LOCAL_AGENT_HOST="$(read_config_value LOCAL_AGENT_HOST || true)"
  [[ -n "${LOCAL_MODEL_PROVIDER:-}" ]] || LOCAL_MODEL_PROVIDER="$(read_config_value LOCAL_MODEL_PROVIDER || true)"
  [[ -n "${LOCAL_MODEL:-}" ]] || LOCAL_MODEL="$(read_config_value LOCAL_MODEL || true)"
  [[ -n "${LOCAL_MODEL_ENDPOINT:-}" ]] || LOCAL_MODEL_ENDPOINT="$(read_config_value LOCAL_MODEL_ENDPOINT || true)"
  [[ -n "${LOCAL_MODEL_CREDENTIAL_REF:-}" ]] || LOCAL_MODEL_CREDENTIAL_REF="$(read_config_value LOCAL_MODEL_CREDENTIAL_REF || true)"
  [[ -n "${SDLC_SUBAGENTS:-}" ]] || SDLC_SUBAGENTS="$(read_config_value SDLC_SUBAGENTS || true)"
  [[ -n "${SDLC_SUBAGENT_MAX:-}" ]] || SDLC_SUBAGENT_MAX="$(read_config_value SDLC_SUBAGENT_MAX || true)"
  [[ -n "${SDLC_SUBAGENT_PROFILE:-}" ]] || SDLC_SUBAGENT_PROFILE="$(read_config_value SDLC_SUBAGENT_PROFILE || true)"
  [[ -n "${SDLC_SUBAGENT_CREDENTIAL_REF:-}" ]] || SDLC_SUBAGENT_CREDENTIAL_REF="$(read_config_value SDLC_SUBAGENT_CREDENTIAL_REF || true)"
  [[ -n "${SDLC_SUBAGENT_TASKS:-}" ]] || SDLC_SUBAGENT_TASKS="$(read_config_value SDLC_SUBAGENT_TASKS || true)"
  [[ -n "${SDLC_RUNTIME_ROUTING:-}" ]] || SDLC_RUNTIME_ROUTING="$(read_config_value SDLC_RUNTIME_ROUTING || true)"
  export LOCAL_AGENT_HOST LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_MODEL_ENDPOINT LOCAL_MODEL_CREDENTIAL_REF
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_CREDENTIAL_REF SDLC_SUBAGENT_TASKS SDLC_RUNTIME_ROUTING
}

configure_local_profile() {
  local persist="${1:-yes}" host provider model endpoint credential_ref=''
  echo
  echo -e "${W}Local agent host${N} — зарегистрированный адаптер из _runtimes/local-hosts/"
  echo -e "  Встроенные: ${C}codex-oss${N} (Ollama/LM Studio), ${C}openai-api${N} (read-only advisory Responses API)"
  read -rp "Agent host id: " host
  [[ "$host" =~ ^[A-Za-z0-9._-]+$ ]] || { echo -e "${R}Некорректный host id${N}"; return 1; }

  if [[ "$host" == "codex-oss" ]]; then
    read -rp "Provider [ollama/lmstudio]: " provider
    [[ "$provider" == "ollama" || "$provider" == "lmstudio" ]] || {
      echo -e "${R}codex-oss поддерживает provider ollama или lmstudio${N}"
      return 1
    }
    endpoint=""
  elif [[ "$host" == openai-api ]]; then
    provider=openai
    read -rp 'Endpoint [https://api.openai.com/v1]: ' endpoint
    [[ -n "$endpoint" ]] || endpoint='https://api.openai.com/v1'
    read -rp 'Credential ref (pass:entry): ' credential_ref
    [[ "$credential_ref" == pass:* ]] || { echo -e "${R}openai-api требует pass:entry${N}"; return 1; }
  else
    read -rp "Provider id (например openai-compatible/vllm/llama.cpp): " provider
    read -rp "Endpoint URL (без токена): " endpoint
    [[ -n "$endpoint" ]] || { echo -e "${R}Endpoint для custom host обязателен${N}"; return 1; }
  fi
  read -rp "Точный model id: " model
  for value in "$provider" "$model" "$endpoint"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'|'* && "$value" != *'"'* ]] || {
      echo -e "${R}Недопустимые символы в local profile${N}"
      return 1
    }
  done
  [[ -n "$provider" && -n "$model" ]] || { echo -e "${R}Provider и точный model id обязательны${N}"; return 1; }

  LOCAL_AGENT_HOST="$host"
  LOCAL_MODEL_PROVIDER="$provider"
  LOCAL_MODEL="$model"
  LOCAL_MODEL_ENDPOINT="$endpoint"
  LOCAL_MODEL_CREDENTIAL_REF="$credential_ref"
  export LOCAL_AGENT_HOST LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_MODEL_ENDPOINT LOCAL_MODEL_CREDENTIAL_REF
  if [[ "$persist" == "yes" ]]; then
    write_config_value LOCAL_AGENT_HOST "$LOCAL_AGENT_HOST"
    write_config_value LOCAL_MODEL_PROVIDER "$LOCAL_MODEL_PROVIDER"
    write_config_value LOCAL_MODEL "$LOCAL_MODEL"
    write_config_value LOCAL_MODEL_ENDPOINT "$LOCAL_MODEL_ENDPOINT"
    write_config_value LOCAL_MODEL_CREDENTIAL_REF "$LOCAL_MODEL_CREDENTIAL_REF"
  fi
}

select_runtime() {
  local allow_back="${1:-yes}"
  local choice prompt_suffix
  while true; do
    header
    if [[ "$FIRST_RUN_WIZARD" == "1" ]]; then
      render_first_run_step 1 "Как запускать AI agents?"
    else
      echo -e "${W}── Runtime AI-вендора ───────────────────────────────${N}"
      echo
    fi
    echo -e "Текущий runtime: ${C}$(runtime_label)${N}${AGENT_RUNTIME:+ ($AGENT_RUNTIME)}"
    echo
    echo -e "  ${Y}1)${N} Claude"
    echo -e "     Claude Code CLI выполняет выбранные agents"
    echo -e "  ${Y}2)${N} Codex"
    echo -e "     Codex CLI выполняет выбранные agents"
    echo -e "  ${Y}3)${N} Gemini"
    echo -e "     Gemini CLI выполняет выбранные agents"
    echo -e "  ${Y}4)${N} Local model (registered agent host)"
    echo -e "     Явные host, provider и точный model id; silent fallback запрещён"
    if [[ "$allow_back" == "yes" ]]; then
      echo -e "  ${Y}b)${N} Назад"
      prompt_suffix="1-4/b"
    else
      prompt_suffix="1-4"
    fi
    echo
    read -rp "$(echo -e "${W}Выбери runtime [${prompt_suffix}]:${N} ")" choice
    case "$choice" in
      1) AGENT_RUNTIME="claude" ;;
      2) AGENT_RUNTIME="codex" ;;
      3) AGENT_RUNTIME="gemini" ;;
      4)
        AGENT_RUNTIME="local"
        configure_local_profile || continue
        ;;
      b|B)
        if [[ "$allow_back" == "yes" ]]; then
          return 1
        fi
        echo -e "${R}Неверный выбор${N}"
        sleep 0.5
        continue
        ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; continue ;;
    esac
    export AGENT_RUNTIME
    write_config_value AGENT_RUNTIME "$AGENT_RUNTIME"
    BASE_PROFILE="$AGENT_RUNTIME|$LOCAL_MODEL_PROVIDER|$LOCAL_MODEL|$LOCAL_AGENT_HOST|$LOCAL_MODEL_ENDPOINT"
    echo
    echo -e "${G}✓ Runtime: ${W}$(runtime_label)${N}"
    ensure_runtime_available || true
    echo
    if [[ "$FIRST_RUN_WIZARD" != "1" ]]; then
      read -rp "$(echo -e "${W}Нажми Enter для продолжения...${N} ")" _
    fi
    return 0
  done
}

ensure_runtime() {
  load_runtime && return 0
  select_runtime no
}

ensure_first_run_runtime() {
  if load_runtime; then
    header
    render_first_run_step 1 "Как запускать AI agents?"
    echo -e "${G}✓ Runtime задан явно: ${W}$(runtime_label)${N}"
    echo
    read -rp "$(echo -e "${W}Нажми Enter, чтобы перейти к Projects...${N} ")" _
    return 0
  fi
  select_runtime no
}

is_sdlc_project_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -d "$dir/stage1-planning" ]] || return 1
  [[ -d "$dir/stage2-requirements" ]] || return 1
  [[ -d "$dir/stage3-design" ]] || return 1
  [[ -d "$dir/stage4-dev" ]] || return 1
  [[ -d "$dir/stage5-testing" ]] || return 1
}

set_project_collection_dir() {
  local dir
  PROJECTS_DIR_NOTE=""
  dir="$(expand_path "$1")"
  [[ -z "$dir" ]] && return 1
  mkdir -p "$dir" || return 1
  PROJECTS="$(cd "$dir" && pwd -P)"
  PROJECTS_MODE="collection"
  SINGLE_PROJECT=""
  export SDLC_PROJECTS_DIR="$PROJECTS"
  unset SDLC_SINGLE_PROJECT
}

set_single_project_dir() {
  local dir project_dir
  PROJECTS_DIR_NOTE=""
  dir="$(expand_path "$1")"
  [[ -z "$dir" ]] && return 1
  if ! is_sdlc_project_dir "$dir"; then
    echo -e "${R}Это не похоже на папку SDLC-проекта: $dir${N}"
    echo -e "Ожидаются stage1-planning ... stage5-testing внутри выбранной папки."
    return 1
  fi
  project_dir="$(cd "$dir" && pwd -P)"
  PROJECTS="$(dirname "$project_dir")"
  SINGLE_PROJECT="$(basename "$project_dir")"
  PROJECTS_MODE="single"
  PROJECTS_DIR_NOTE="Режим: один проект — ${SINGLE_PROJECT}"
  export SDLC_PROJECTS_DIR="$PROJECTS"
  export SDLC_SINGLE_PROJECT="$SINGLE_PROJECT"
}

load_projects_dir() {
  local configured="" mode="" single=""
  if [[ -n "${SDLC_PROJECTS_DIR:-}" ]]; then
    configured="$SDLC_PROJECTS_DIR"
    mode="${SDLC_PROJECTS_MODE:-}"
    single="${SDLC_SINGLE_PROJECT:-}"
  else
    configured="$(read_config_value SDLC_PROJECTS_DIR || true)"
    mode="$(read_config_value SDLC_PROJECTS_MODE || true)"
    single="$(read_config_value SDLC_SINGLE_PROJECT || true)"
  fi
  [[ -z "$configured" ]] && return 1
  case "$mode" in
    single)
      if [[ -n "$single" ]]; then
        set_single_project_dir "$configured/$single"
      else
        set_single_project_dir "$configured"
      fi
      ;;
    collection)
      set_project_collection_dir "$configured"
      ;;
    *)
      if is_sdlc_project_dir "$configured"; then
        set_single_project_dir "$configured"
      else
        set_project_collection_dir "$configured"
      fi
      ;;
  esac
}

configure_projects_dir() {
  local mode input
  while true; do
    header
    if [[ "$FIRST_RUN_WIZARD" == "1" ]]; then
      render_first_run_step 2 "С какими проектами работать?"
    else
      echo -e "${W}── Настройка каталога SDLC-проектов ────────────────${N}"
      echo
    fi
    echo -e "Launcher не выбирает каталог автоматически."
    echo -e "Можно указать каталог с несколькими SDLC-проектами или папку одного проекта."
    [[ -n "${SDLC_PROJECTS_DIR:-}" ]] && echo -e "Текущее значение env: ${C}${SDLC_PROJECTS_DIR}${N}"
    echo
    echo -e "  ${Y}1)${N} Каталог с несколькими проектами"
    echo -e "     Сначала выбирается проект из найденных подпапок; удобно для общей рабочей области."
    echo -e "  ${Y}2)${N} Папка одного проекта"
    echo -e "     Launcher закрепляется за одним проектом; переключение между проектами не требуется."
    echo -e "  ${Y}b)${N} Отмена"
    echo
    read -rp "$(echo -e "${W}Выбери [1-2/b]:${N} ")" mode
    case "$mode" in
      b|B) return 1 ;;
      1|2) ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; continue ;;
    esac

    echo
    if [[ "$mode" == "1" ]]; then
      echo -e "${C}Введи полный путь к каталогу, внутри которого лежат папки проектов.${N}"
    else
      echo -e "${C}Введи полный путь к папке конкретного SDLC-проекта.${N}"
    fi
    read -rp "$(echo -e "${W}Путь (b — отмена):${N} ")" input
    [[ "$input" == "b" || "$input" == "B" ]] && continue
    if [[ -z "$input" ]]; then
      echo -e "${R}Путь обязателен. Launcher не подставляет каталог по умолчанию.${N}"
      sleep 0.8
      continue
    fi

    if [[ "$mode" == "1" ]]; then
      set_project_collection_dir "$input" || { echo -e "${R}Не удалось настроить каталог: $input${N}"; sleep 1; continue; }
    else
      set_single_project_dir "$input" || { sleep 1; continue; }
    fi

    write_config_value SDLC_PROJECTS_DIR "$PROJECTS"
    write_config_value SDLC_PROJECTS_MODE "$PROJECTS_MODE"
    write_config_value SDLC_SINGLE_PROJECT "$SINGLE_PROJECT"
    echo
    [[ -n "${PROJECTS_DIR_NOTE:-}" ]] && echo -e "${Y}${PROJECTS_DIR_NOTE}${N}"
    echo -e "${G}✓ Каталог проектов: ${W}$PROJECTS${N}"
    [[ "$PROJECTS_MODE" == "single" ]] && echo -e "  Активный проект: ${W}$SINGLE_PROJECT${N}"
    echo -e "  Изменить позже: настройки launcher или env ${W}SDLC_PROJECTS_DIR${N}"
    echo
    if [[ "$FIRST_RUN_WIZARD" != "1" ]]; then
      read -rp "$(echo -e "${W}Нажми Enter для продолжения...${N} ")" _
    fi
    return 0
  done
}

ensure_projects_dir() {
  load_projects_dir
  [[ -n "$PROJECTS" ]] && return 0
  configure_projects_dir
}

ensure_first_run_projects_dir() {
  load_projects_dir
  if [[ -n "$PROJECTS" ]]; then
    header
    render_first_run_step 2 "С какими проектами работать?"
    echo -e "${G}✓ Projects заданы явно: ${W}$PROJECTS${N}"
    echo -e "  Режим: ${C}${PROJECTS_MODE}${N}"
    echo
    read -rp "$(echo -e "${W}Нажми Enter, чтобы перейти к выбору View...${N} ")" _
    return 0
  fi
  configure_projects_dir
}

choose_runtime() {
  select_runtime yes
}

current_profile() {
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    printf '%s|%s|%s|%s|%s\n' "$AGENT_RUNTIME" "$LOCAL_MODEL_PROVIDER" \
      "$LOCAL_MODEL" "$LOCAL_AGENT_HOST" "$LOCAL_MODEL_ENDPOINT"
  else
    printf '%s||||\n' "$AGENT_RUNTIME"
  fi
}

apply_profile() {
  local profile="$1" runtime provider model host endpoint extra
  IFS='|' read -r runtime provider model host endpoint extra <<< "$profile"
  [[ -z "$extra" ]] || { echo -e "${R}Некорректный runtime profile${N}"; return 1; }
  init_runtime "$runtime" || return 1
  if [[ "$runtime" == "local" ]]; then
    [[ -n "$provider" && -n "$model" && -n "$host" ]] || {
      echo -e "${R}Local route обязан содержать provider, exact model id и agent host.${N}"
      return 1
    }
    LOCAL_MODEL_PROVIDER="$provider"
    LOCAL_MODEL="$model"
    LOCAL_AGENT_HOST="$host"
    LOCAL_MODEL_ENDPOINT="$endpoint"
  else
    LOCAL_MODEL_PROVIDER=""
    LOCAL_MODEL=""
    LOCAL_AGENT_HOST=""
    LOCAL_MODEL_ENDPOINT=""
    LOCAL_MODEL_CREDENTIAL_REF=""
  fi
  export AGENT_RUNTIME LOCAL_MODEL_PROVIDER LOCAL_MODEL LOCAL_AGENT_HOST LOCAL_MODEL_ENDPOINT LOCAL_MODEL_CREDENTIAL_REF
  ensure_runtime_available
}

select_step_profile() {
  local choice
  echo
  echo -e "${W}Профиль runtime для шага${N}"
  echo -e "  ${Y}1)${N} Claude"
  echo -e "  ${Y}2)${N} Codex"
  echo -e "  ${Y}3)${N} Gemini"
  echo -e "  ${Y}4)${N} Local model"
  read -rp "Выбери [1-4]: " choice
  case "$choice" in
    1) AGENT_RUNTIME="claude" ;;
    2) AGENT_RUNTIME="codex" ;;
    3) AGENT_RUNTIME="gemini" ;;
    4)
      AGENT_RUNTIME="local"
      configure_local_profile no || return 1
      ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  export AGENT_RUNTIME
  SELECTED_PROFILE="$(current_profile)"
  apply_profile "$SELECTED_PROFILE"
}

select_routing_policy() {
  local allow_back="${1:-yes}" choice prompt_range
  while true; do
    header
    echo -e "${W}── Маршрутизация runtime ─────────────────────────────${N}"
    echo
    echo -e "  ${Y}1)${N} single — один явно выбранный профиль"
    echo -e "  ${Y}2)${N} per-stage — профиль для каждого этапа"
    echo -e "  ${Y}3)${N} per-agent — профиль для каждого агента"
    echo -e "  ${Y}4)${N} ask — спрашивать перед каждым шагом"
    [[ "$allow_back" == "yes" ]] && echo -e "  ${Y}b)${N} Назад"
    echo
    [[ "$allow_back" == "yes" ]] && prompt_range="1-4/b" || prompt_range="1-4"
    read -rp "Выбери [$prompt_range]: " choice
    case "$choice" in
      1) SDLC_RUNTIME_ROUTING="single" ;;
      2) SDLC_RUNTIME_ROUTING="per-stage" ;;
      3) SDLC_RUNTIME_ROUTING="per-agent" ;;
      4) SDLC_RUNTIME_ROUTING="ask" ;;
      b|B) [[ "$allow_back" == "yes" ]] && return 1 ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; continue ;;
    esac
    export SDLC_RUNTIME_ROUTING
    write_config_value SDLC_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
    return 0
  done
}

ensure_routing_policy() {
  case "${SDLC_RUNTIME_ROUTING:-}" in
    single|per-stage|per-agent|ask) return 0 ;;
    "") select_routing_policy no ;;
    *) echo -e "${R}Некорректный SDLC_RUNTIME_ROUTING: $SDLC_RUNTIME_ROUTING${N}"; return 1 ;;
  esac
}

configure_subagent_settings() {
  local context="${1:-standalone}" choice max
  echo
  render_subagent_mode_choice "$context"
  if [[ "$context" == first-run ]]; then
    choice=1
  else
    read -rp 'Worker policy [1-3]: ' choice
  fi
  case "$choice" in
    1) SDLC_SUBAGENTS=off; SDLC_SUBAGENT_PROFILE=''; SDLC_SUBAGENT_CREDENTIAL_REF=''; SDLC_SUBAGENT_TASKS='' ;;
    2) SDLC_SUBAGENTS=auto; SDLC_SUBAGENT_PROFILE=''; SDLC_SUBAGENT_CREDENTIAL_REF=''; SDLC_SUBAGENT_TASKS='analysis,research,review,test-interpretation' ;;
    3)
      SDLC_SUBAGENTS=cross-runtime
      configure_cross_runtime_subagents || return 1
      ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  SDLC_SUBAGENT_MAX=2
  if [[ "$SDLC_SUBAGENTS" != off ]]; then
    read -rp 'Максимум workers на primary run [2]: ' max
    [[ -z "$max" ]] || SDLC_SUBAGENT_MAX="$max"
  fi
  ensure_subagent_settings || return 1
  export SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_CREDENTIAL_REF SDLC_SUBAGENT_TASKS
  write_config_value SDLC_SUBAGENTS "$SDLC_SUBAGENTS"
  write_config_value SDLC_SUBAGENT_MAX "$SDLC_SUBAGENT_MAX"
  write_config_value SDLC_SUBAGENT_PROFILE "$SDLC_SUBAGENT_PROFILE"
  write_config_value SDLC_SUBAGENT_CREDENTIAL_REF "$SDLC_SUBAGENT_CREDENTIAL_REF"
  write_config_value SDLC_SUBAGENT_TASKS "$SDLC_SUBAGENT_TASKS"
}

render_subagent_mode_choice() {
  local context="${1:-standalone}"
  if [[ "$context" == "first-run" ]]; then
    echo -e "${W}Шаг 2 из 2 — статус AI-помощников${N}"
  else
    echo -e "${W}Статус AI-помощников${N}"
  fi
  echo -e "${W}Worker execution policy${N}"
  echo
  echo "Worker — отдельный read-only task process с точным digest-bound read manifest."
  echo "Обмен идёт только через launcher-owned Worker Request/Result files; fallback выключен."
  echo
  echo -e "  ${Y}1)${N} off — без workers (по умолчанию)"
  echo -e "  ${Y}2)${N} auto — тот же точный route, если adapter поддерживает bounded read-only"
  echo -e "  ${Y}3)${N} cross-runtime — отдельный явный worker runtime/provider/model"
}

render_first_run_ai_routing_choice() {
  printf '%s\n' \
    'Шаг 1 из 2 — Основные исполнители' \
    'Какая AI-модель будет выполнять основные этапы проекта?' \
    '' \
    'Основной исполнитель запускает назначенного SDLC Agent, создаёт итоговые файлы проекта и отвечает за результат этапа.' \
    'Выбор определяет, какая AI-модель получит каждую роль, но не меняет состав или порядок SDLC-этапов.' \
    'Сейчас ничего не запускается: назначения будут показаны в Preview перед реальным стартом.' \
    '' \
    '  1) Одна AI-модель для всего проекта' \
    '     Например, Codex выполняет все основные этапы.' \
    '' \
    '  2) Своя AI-модель для каждого цикла' \
    '     Отдельно для разработки, деплоя и эксплуатации.' \
    '' \
    '  3) Настроить исключения для отдельных ролей' \
    '     Сначала выбираются модели по циклам, затем можно назначить другую модель, например, только для Developer или Reviewer.' \
    '' \
    '  4) Спрашивать при подготовке каждого запуска' \
    '     Launcher соберёт назначения для всех нужных шагов до Preview. Это даёт больше контроля, но требует больше ответов.' \
    '' \
    'Следующий шаг: launcher оставит workers выключенными по умолчанию; их можно включить позже в настройках.'
}

configure_first_run_ai_mode() {
  local choice
  echo
  render_first_run_ai_routing_choice
  read -rp 'Выбери способ [1-4]: ' choice
  case "$choice" in
    1) SDLC_RUNTIME_ROUTING='single'; PENDING_FIRST_RUN_AI_SETUP='' ;;
    2) SDLC_RUNTIME_ROUTING='per-agent'; PENDING_FIRST_RUN_AI_SETUP='cycle' ;;
    3) SDLC_RUNTIME_ROUTING='per-agent'; PENDING_FIRST_RUN_AI_SETUP='matrix' ;;
    4) SDLC_RUNTIME_ROUTING='ask'; PENDING_FIRST_RUN_AI_SETUP='' ;;
    *) echo -e "${R}Неверный выбор${N}"; return 1 ;;
  esac
  export SDLC_RUNTIME_ROUTING
  write_config_value SDLC_RUNTIME_ROUTING "$SDLC_RUNTIME_ROUTING"
  configure_subagent_settings first-run
}

ensure_subagent_settings() {
  case "${SDLC_SUBAGENTS:-}" in
    off|"")
      SDLC_SUBAGENTS=off
      SDLC_SUBAGENT_PROFILE=''
      SDLC_SUBAGENT_CREDENTIAL_REF=''
      SDLC_SUBAGENT_TASKS=''
      ;;
    auto)
      SDLC_SUBAGENT_PROFILE=''
      SDLC_SUBAGENT_CREDENTIAL_REF=''
      ;;
    cross-runtime)
      validate_subagent_profile "${SDLC_SUBAGENT_PROFILE:-}" || return 1
      case "$SDLC_SUBAGENT_PROFILE" in
        local\|*\|openai-api\|*)
          [[ "${SDLC_SUBAGENT_CREDENTIAL_REF:-}" == pass:* &&
             "$SDLC_SUBAGENT_CREDENTIAL_REF" != *$'\n'* &&
             "$SDLC_SUBAGENT_CREDENTIAL_REF" != *$'\r'* &&
             "$SDLC_SUBAGENT_CREDENTIAL_REF" != *'"'* ]] || return 1
          ;;
        *) [[ -z "${SDLC_SUBAGENT_CREDENTIAL_REF:-}" ]] || return 1 ;;
      esac
      ;;
    *) echo -e "${R}SDLC_SUBAGENTS должен быть off, auto или cross-runtime${N}"; return 1 ;;
  esac
  valid_menu_index "${SDLC_SUBAGENT_MAX:-}" 16 || {
      echo -e "${R}SDLC_SUBAGENT_MAX должен быть 1..16${N}"
      return 1
    }
}

normalize_subagent_tasks() {
  local raw="${1:-}" item
  local analysis=0 research=0 review=0 test_interpretation=0
  local -a items=() result=()
  [[ -n "$raw" ]] || return 1
  IFS=',' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    case "$item" in
      analysis) analysis=1 ;;
      research) research=1 ;;
      review) review=1 ;;
      test-interpretation) test_interpretation=1 ;;
      *) return 1 ;;
    esac
  done
  (( analysis )) && result+=(analysis)
  (( research )) && result+=(research)
  (( review )) && result+=(review)
  (( test_interpretation )) && result+=(test-interpretation)
  local joined
  joined="$(IFS=,; echo "${result[*]}")"
  [[ -n "$joined" ]] || return 1
  printf '%s\n' "$joined"
}

validate_subagent_profile() {
  local profile="${1:-}" runtime provider model host endpoint extra value
  IFS='|' read -r runtime provider model host endpoint extra <<< "$profile"
  [[ -z "$extra" ]] || return 1
  case "$runtime" in
    claude|codex)
      [[ -z "$provider$model$host$endpoint" ]] || return 1
      ;;
    local)
      [[ -n "$provider" && -n "$model" && -n "$host" ]] || return 1
      [[ "$host" == codex-oss || "$host" == openai-api ]] || return 1
      ;;
    *) return 1 ;;
  esac
  for value in "$runtime" "$provider" "$model" "$host" "$endpoint"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'"'* ]] || return 1
  done
}

subagent_profile_label() {
  local profile="${1:-${SDLC_SUBAGENT_PROFILE:-}}" runtime provider model host endpoint
  validate_subagent_profile "$profile" || return 1
  IFS='|' read -r runtime provider model host endpoint <<< "$profile"
  case "$runtime" in
    claude) printf 'Claude / external CLI\n' ;;
    codex) printf 'Codex / external CLI\n' ;;
    local) printf 'Local / %s / %s / %s\n' "$host" "$provider" "$model" ;;
  esac
}

render_subagent_execution_summary() {
  printf '  Primary: %s\n' "$(preview_route_label 2>/dev/null || printf 'BLOCKED: incomplete primary')"
  printf '  Workers: %s (max=%s)\n' "${SDLC_SUBAGENTS:-off}" "${SDLC_SUBAGENT_MAX:-2}"
  [[ "${SDLC_SUBAGENTS:-off}" != cross-runtime ]] ||
    printf '  Worker route: %s; tasks=%s\n' "$(subagent_profile_label 2>/dev/null || printf 'BLOCKED: incomplete')" "${SDLC_SUBAGENT_TASKS:-missing}"
  printf '%s\n' '  Handoff: digest-bound files only; Project/memory writes and nested delegation denied' '  Fallback: OFF'
}

configure_cross_runtime_subagents() {
  local saved_profile saved_credential_ref raw normalized
  saved_profile="$(current_profile)"
  saved_credential_ref="${LOCAL_MODEL_CREDENTIAL_REF:-}"
  echo -e "${W}Выбери точный worker runtime/profile.${N} Gemini worker пока недоступен: его CLI adapter не доказывает read-only capability."
  select_step_profile || { LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"; export LOCAL_MODEL_CREDENTIAL_REF; apply_profile "$saved_profile" >/dev/null 2>&1 || true; return 1; }
  case "$AGENT_RUNTIME:${LOCAL_AGENT_HOST:-}" in
    claude:|codex:|local:codex-oss|local:openai-api) ;;
    *) echo -e "${R}Выбранный worker profile не поддерживает bounded read-only.${N}"; LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"; export LOCAL_MODEL_CREDENTIAL_REF; apply_profile "$saved_profile"; return 1 ;;
  esac
  SDLC_SUBAGENT_PROFILE="$(current_profile)"
  SDLC_SUBAGENT_CREDENTIAL_REF="${LOCAL_MODEL_CREDENTIAL_REF:-}"
  read -rp 'Разрешённые advisory kinds (analysis,research,review,test-interpretation): ' raw
  normalized="$(normalize_subagent_tasks "$raw")" || {
    echo -e "${R}Некорректный список worker kinds${N}"
    LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"
    export LOCAL_MODEL_CREDENTIAL_REF
    apply_profile "$saved_profile"
    return 1
  }
  SDLC_SUBAGENT_TASKS="$normalized"
  LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"
  export LOCAL_MODEL_CREDENTIAL_REF SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_CREDENTIAL_REF SDLC_SUBAGENT_TASKS
  apply_profile "$saved_profile"
}

write_routing_entry() {
  local key="$1" profile="$2" tmp
  [[ "$key" =~ ^(stage:s[0-9]|agent:[A-Za-z0-9._-]+)$ ]] || {
    echo -e "${R}Route key должен быть stage:sN или agent:agent-id${N}"
    return 1
  }
  [[ "$profile" != *$'\n'* && "$profile" != *$'\r'* ]] || return 1
  mkdir -p "$CONFIG_DIR"
  mkdir -p "$(dirname "$ROUTING_FILE")"
  chmod 700 "$CONFIG_DIR"
  tmp="$(mktemp "${ROUTING_FILE}.tmp.XXXXXX")" || return 1
  if [[ -f "$ROUTING_FILE" ]]; then
    awk -F= -v key="$key" -v value="$profile" '
      BEGIN { written=0 }
      $1 == key { print key "=" value; written=1; next }
      { print }
      END { if (!written) print key "=" value }
    ' "$ROUTING_FILE" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$profile" > "$tmp"
  fi
  chmod 600 "$tmp"
  mv "$tmp" "$ROUTING_FILE"
  chmod 600 "$ROUTING_FILE"
}

configure_runtime_route() {
  local key
  echo
  read -rp "Route key (stage:s2 или agent:s4-dev): " key
  select_step_profile || return 1
  write_routing_entry "$key" "$SELECTED_PROFILE" || return 1
  echo -e "${G}✓ $key → $SELECTED_PROFILE${N}"
  apply_profile "$BASE_PROFILE" || return 1
}

lookup_route() {
  local key="$1"
  [[ -f "$ROUTING_FILE" ]] || return 1
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ROUTING_FILE"
}

stage_for_agent() {
  local agent="$1"
  case "$agent" in
    s[0-9]-*) echo "${agent%%-*}" ;;
    l[0-9]-*) echo "localrun" ;;
    *) echo "tools" ;;
  esac
}

resolve_step_runtime() {
  local agent="$1" key profile
  case "$SDLC_RUNTIME_ROUTING" in
    single)
      apply_profile "$BASE_PROFILE"
      ;;
    per-stage)
      key="stage:$(stage_for_agent "$agent")"
      profile="$(lookup_route "$key" || true)"
      [[ -n "$profile" ]] || {
        echo -e "${R}Нет явного runtime route для $key. Silent fallback запрещён.${N}"
        return 1
      }
      apply_profile "$profile"
      ;;
    per-agent)
      key="agent:$agent"
      profile="$(lookup_route "$key" || true)"
      [[ -n "$profile" ]] || {
        echo -e "${R}Нет явного runtime route для $key. Silent fallback запрещён.${N}"
        return 1
      }
      apply_profile "$profile"
      ;;
    ask)
      select_step_profile
      ;;
    *)
      echo -e "${R}Неизвестная routing policy: $SDLC_RUNTIME_ROUTING${N}"
      return 1
      ;;
  esac
}

project_ai_config_path() {
  local project="${1:-$PROJECT}"
  printf '%s/%s/tracking/ai-routing.conf\n' "$PROJECTS" "$project"
}

save_project_ai_config() {
  local profile="$1" policy="$2" path dir tmp tasks
  case "$policy" in single|per-stage|per-agent|ask) ;; *) return 1 ;; esac
  [[ "$profile" != *$'\n'* && "$profile" != *$'\r'* && "$profile" != *'"'* ]] || return 1
  ensure_subagent_settings || return 1
  if [[ "${SDLC_SUBAGENTS:-off}" == cross-runtime ]]; then
    validate_subagent_profile "${SDLC_SUBAGENT_PROFILE:-}" || return 1
    tasks="$(normalize_subagent_tasks "${SDLC_SUBAGENT_TASKS:-}")" || return 1
    SDLC_SUBAGENT_TASKS="$tasks"
  fi
  path="$(project_ai_config_path)"
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  tmp="$(mktemp "$path.tmp.XXXXXX")" || return 1
  printf 'BASE_PROFILE="%s"\nSDLC_RUNTIME_ROUTING="%s"\nSDLC_SUBAGENTS="%s"\nSDLC_SUBAGENT_MAX="%s"\nSDLC_SUBAGENT_PROFILE="%s"\nSDLC_SUBAGENT_CREDENTIAL_REF="%s"\nSDLC_SUBAGENT_TASKS="%s"\n' \
    "$profile" "$policy" "${SDLC_SUBAGENTS:-off}" "${SDLC_SUBAGENT_MAX:-2}" \
    "${SDLC_SUBAGENT_PROFILE:-}" "${SDLC_SUBAGENT_CREDENTIAL_REF:-}" "${SDLC_SUBAGENT_TASKS:-}" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$path"
}

activate_project_ai_config() {
  local path profile policy subagents subagent_max subagent_profile subagent_credential_ref subagent_tasks value
  ROUTING_FILE="$(project_path)/tracking/runtime-routing"
  profile="${LAUNCHER_BASE_PROFILE:-$BASE_PROFILE}"
  policy="${LAUNCHER_ROUTING_POLICY:-${SDLC_RUNTIME_ROUTING:-single}}"
  subagents="${LAUNCHER_SUBAGENTS:-${SDLC_SUBAGENTS:-off}}"
  subagent_max="${LAUNCHER_SUBAGENT_MAX:-${SDLC_SUBAGENT_MAX:-2}}"
  subagent_profile="${LAUNCHER_SUBAGENT_PROFILE:-${SDLC_SUBAGENT_PROFILE:-}}"
  subagent_credential_ref="${LAUNCHER_SUBAGENT_CREDENTIAL_REF:-${SDLC_SUBAGENT_CREDENTIAL_REF:-}}"
  subagent_tasks="${LAUNCHER_SUBAGENT_TASKS:-${SDLC_SUBAGENT_TASKS:-}}"
  path="$(project_ai_config_path)"
  if [[ -f "$path" ]]; then
    profile="$(awk -F= '$1 == "BASE_PROFILE" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    policy="$(awk -F= '$1 == "SDLC_RUNTIME_ROUTING" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    value="$(awk -F= '$1 == "SDLC_SUBAGENTS" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    [[ -z "$value" ]] || subagents="$value"
    value="$(awk -F= '$1 == "SDLC_SUBAGENT_MAX" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    [[ -z "$value" ]] || subagent_max="$value"
    if grep -q '^SDLC_SUBAGENT_PROFILE=' "$path"; then
      subagent_profile="$(awk -F= '$1 == "SDLC_SUBAGENT_PROFILE" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    fi
    if grep -q '^SDLC_SUBAGENT_CREDENTIAL_REF=' "$path"; then
      subagent_credential_ref="$(awk -F= '$1 == "SDLC_SUBAGENT_CREDENTIAL_REF" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    fi
    if grep -q '^SDLC_SUBAGENT_TASKS=' "$path"; then
      subagent_tasks="$(awk -F= '$1 == "SDLC_SUBAGENT_TASKS" { sub(/^[^=]*="/, ""); sub(/"$/, ""); print; exit }' "$path")"
    fi
  fi
  [[ -n "$profile" ]] || return 1
  case "$policy" in single|per-stage|per-agent|ask) ;; *) return 1 ;; esac
  BASE_PROFILE="$profile"
  SDLC_RUNTIME_ROUTING="$policy"
  SDLC_SUBAGENTS="$subagents"
  SDLC_SUBAGENT_MAX="$subagent_max"
  SDLC_SUBAGENT_PROFILE="$subagent_profile"
  SDLC_SUBAGENT_CREDENTIAL_REF="$subagent_credential_ref"
  SDLC_SUBAGENT_TASKS="$subagent_tasks"
  ensure_subagent_settings || return 1
  export SDLC_RUNTIME_ROUTING SDLC_SUBAGENTS SDLC_SUBAGENT_MAX SDLC_SUBAGENT_PROFILE SDLC_SUBAGENT_CREDENTIAL_REF SDLC_SUBAGENT_TASKS
  apply_profile "$BASE_PROFILE"
}

execution_route_source() {
  local agent="$1"
  case "$SDLC_RUNTIME_ROUTING" in
    single) printf 'single profile\n' ;;
    per-stage) printf 'stage:%s\n' "$(stage_for_agent "$agent")" ;;
    per-agent) printf 'agent:%s\n' "$agent" ;;
    ask) printf 'explicit ASK answer\n' ;;
    *) return 1 ;;
  esac
}

freeze_execution_routes() {
  local saved_profile entry agent
  saved_profile="$(current_profile)"
  EXECUTION_STEP_PROFILES=()
  EXECUTION_STEP_SOURCES=()
  EXECUTION_PREVIEW_BLOCKED=0
  for entry in "${RUN_CYCLE[@]:-}"; do
    [[ -n "$entry" ]] || continue
    agent="${entry%%:*}"
    if ! resolve_step_runtime "$agent"; then
      EXECUTION_PREVIEW_BLOCKED=1
      apply_profile "$saved_profile" >/dev/null 2>&1 || true
      return 1
    fi
    EXECUTION_STEP_PROFILES+=("$(current_profile)")
    EXECUTION_STEP_SOURCES+=("$(execution_route_source "$agent")")
  done
  apply_profile "$saved_profile" >/dev/null 2>&1 || true
}

# ─── агенты: папка → описание ─────────────────────────────────────────────────
declare -A AGENT_DESC=(
  [l1-analyze]="Local Analyzer — изучить структуру проекта с GitHub"
  [l2-setup]="Local Setup — установить зависимости и настроить .env"
  [l3-build]="Local Builder — собрать проект"
  [l4-run]="Local Runner — запустить и проверить проект"
  [s0-kickoff]="Project Kickoff — интервью для нового проекта / обновление беклога"
  [s0-defects]="Known Defects Memory — read/proposal handoff известных ошибок"
  [s0-secrets]="Secrets Manager — pass: добавить, ротировать, env"
  [s0-validate]="Structure Validator — проверить и починить структуру проекта"
  [s0-tracker]="Sprint & Task Tracker — спринты, задачи, план vs факт"
  [s0-quality-gates]="Quality Gates Configurator — проектные пороги качества из risk-профиля"
  [s1-pm]="Product Manager — Feasibility, Vision, OKR"
  [s1-pmo]="Project Manager — Charter, Risk Register, RACI"
  [s1-finance]="Finance Analyst — ROI, NPV, Business Case"
  [s2-ba]="Business Analyst — BRD, NFR, RTM"
  [s2-po]="Product Owner — User Stories, Backlog"
  [s2-qa-req]="QA Analyst — Testability Review"
  [s2-test-strategy]="QA Strategist — risk-based test-first стратегия"
  [s2-security]="Security Requirements Engineer — abuse cases, классификация данных, ASVS (SG1, shift-left)"
  [s3-arch]="Solution Architect — HLD, ADR, API Spec"
  [s3-security]="Security Engineer — Threat Model"
  [s3-rbac]="Authorization Designer — stack-neutral роли, права и enforcement model"
  [s3-dba]="DBA — DB Schema, Migrations"
  [s4-dev]="Backend Developer — Код, PR Summary"
  [s4-qa-auto]="SDET TDD — тесты до кода, Red/PASS и repair verdict"
  [s4-techlead]="Tech Lead — Code Review, Tech Debt"
  [s4-devops]="DevOps Engineer — CI/CD, Runbook"
  [s5-qa]="QA Engineer — Test Plan, Go/No-Go"
  [s5-qa-auto]="QA Automation — E2E/API тесты"
  [s5-perf]="Performance Engineer — Load Tests"
  [s5-security]="Security Test Engineer — DAST, pentest, security-тесты (SG4, tier-aware)"
  [s6-release]="Release Manager — Checklist, Release Notes"
  [s6-sre]="SRE — Post-Deploy, Post-Mortem"
)

# ─── необязательные шаги (можно добавить в Цикл 1) ───────────────────────────
# Формат: "агент|задача|позиция|описание"
# позиция: before — до основного цикла, after — после основного цикла
declare -a OPTIONAL_AGENTS_DEF=(
  "s0-validate|/validate|before|Проверить структуру проекта до старта"
  "s0-validate|/validate|after|Проверить артефакты после завершения цикла"
)

# глобальные массивы — заполняются configure_optional_steps
OPTIONAL_BEFORE=()
OPTIONAL_AFTER=()

# ─── Цикл 1 — Разработка (агент:задача) ───────────────────────────────────────
# Единственный порядок берётся из machine registry; второй hard-coded DAG запрещён.
declare -a CYCLE1_AGENTS=()
if [[ -f "$CYCLE1_STEPS_FILE" ]]; then
  mapfile -t CYCLE1_AGENTS < <(awk -F'\t' 'NR > 1 { print $2 ":" $3 }' "$CYCLE1_STEPS_FILE")
fi

# ─── Цикл 2 — Деплой ──────────────────────────────────────────────────────────
declare -a CYCLE2_AGENTS=(
  "s4-devops:/deploy-intake"
  "s4-devops:/write-deploy-tests"
  "s4-devops:/pipeline"
  "s4-devops:/runbook"
  "s4-devops:/prepare-delivery"
  "s4-devops:/run-deploy-tests"
  "s6-release:/release-notes"
  "s6-release:/release-checklist"
)

# ─── Цикл 3 — Эксплуатация ────────────────────────────────────────────────────
declare -a CYCLE3_AGENTS=(
  "s6-sre:/ops-intake"
  "s6-sre:/write-ops-tests"
  "s6-sre:/configure-ops"
  "s6-sre:/run-ops-tests"
  "s6-sre:/post-deploy"
  "s6-sre:/gate7"
)

# Единый per-project профиль цели Cycle 2/3. Секреты в нём запрещены.
declare -A GOAL_VALUES=()
declare -a CYCLE2_GOAL_KEYS=(
  cycle2_enabled cycle2_goal cycle2_target cycle2_environments
  cycle2_deliverables cycle2_registry_supply_chain cycle2_runtime_packaging
  cycle2_orchestrator cycle2_iac cycle2_cicd cycle2_gitops cycle2_network
  cycle2_data cycle2_capacity_ha cycle2_rollout cycle2_executor
  cycle2_authorization cycle2_validation cycle2_constraints
)
declare -a CYCLE3_GOAL_KEYS=(
  cycle3_enabled cycle3_goal cycle3_operating_environment cycle3_deliverables
  cycle3_monitoring_stack cycle3_slo_error_budget cycle3_logs_traces_retention
  cycle3_alerting_incident cycle3_dedup_capabilities cycle3_playbook_executor
  cycle3_auto_heal_authorization cycle3_backup_dr cycle3_capacity_cost
  cycle3_maintenance cycle3_validation cycle3_reporting cycle3_constraints
)
declare -a CYCLE2_DELIVERABLES=(
  images runtime-bundle orchestrator iac cicd gitops operations-pack execute-deploy custom
)
declare -a CYCLE3_DELIVERABLES=(
  monitoring dashboards alerts runbooks auto-heal backup-dr capacity incident reporting execute-ops custom
)
declare -A DELIVERABLE_LABELS=(
  [images]="Образы + provenance/SBOM/signing"
  [runtime-bundle]="Runtime bundle / package"
  [orchestrator]="Конфигурация оркестратора"
  [iac]="Infrastructure as Code"
  [cicd]="CI/CD pipeline"
  [gitops]="GitOps manifests/config"
  [operations-pack]="Runbook + rollback + handoff"
  [execute-deploy]="Выполнить разрешённый deploy"
  [monitoring]="Monitoring configuration"
  [dashboards]="Dashboards"
  [alerts]="Alerts + routing + dedup"
  [runbooks]="Incident runbooks"
  [auto-heal]="Auto-heal configuration"
  [backup-dr]="Backup / restore / DR"
  [capacity]="Capacity + cost controls"
  [incident]="Incident-management integration"
  [reporting]="Operations reporting"
  [execute-ops]="Выполнять разрешённые ops actions"
  [custom]="Другой явно описанный результат"
)
declare -a ALL_GOAL_KEYS=(
  schema_version revision updated_at updated_by confirmed
  goal_mode revision_reason
  "${CYCLE2_GOAL_KEYS[@]}"
  "${CYCLE3_GOAL_KEYS[@]}"
)
declare -A GOAL_LABELS=(
  [goal_mode]="Режим цели (cycle1-only / through-cycle2 / through-cycle3 / custom)"
  [revision_reason]="Причина создания или изменения профиля"
  [cycle2_enabled]="Выполнять Cycle 2 (yes/no)"
  [cycle2_goal]="Цель поставки"
  [cycle2_target]="Целевая инфраструктура или платформа"
  [cycle2_environments]="Окружения (например dev,stage,prod)"
  [cycle2_deliverables]="Артефакты Cycle 2"
  [cycle2_registry_supply_chain]="Registry, подпись, SBOM и supply chain"
  [cycle2_runtime_packaging]="Runtime и упаковка"
  [cycle2_orchestrator]="Оркестратор"
  [cycle2_iac]="Infrastructure as Code"
  [cycle2_cicd]="CI/CD"
  [cycle2_gitops]="GitOps"
  [cycle2_network]="Сеть, ingress, DNS, TLS"
  [cycle2_data]="Данные, миграции и хранилища"
  [cycle2_capacity_ha]="Capacity и High Availability"
  [cycle2_rollout]="Стратегия rollout/rollback"
  [cycle2_executor]="Кто выполняет deploy"
  [cycle2_authorization]="Границы разрешённых изменений"
  [cycle2_validation]="Как проверяется поставка"
  [cycle2_constraints]="Ограничения Cycle 2"
  [cycle3_enabled]="Выполнять Cycle 3 (yes/no)"
  [cycle3_goal]="Цель эксплуатации"
  [cycle3_operating_environment]="Эксплуатационная среда"
  [cycle3_deliverables]="Артефакты Cycle 3"
  [cycle3_monitoring_stack]="Стек мониторинга"
  [cycle3_slo_error_budget]="SLO и error budget"
  [cycle3_logs_traces_retention]="Логи, трассировки и retention"
  [cycle3_alerting_incident]="Алертинг и incident management"
  [cycle3_dedup_capabilities]="Дедупликация и корреляция событий"
  [cycle3_playbook_executor]="Кто выполняет playbook"
  [cycle3_auto_heal_authorization]="Разрешения auto-heal"
  [cycle3_backup_dr]="Backup и Disaster Recovery"
  [cycle3_capacity_cost]="Capacity и стоимость"
  [cycle3_maintenance]="Окна и правила обслуживания"
  [cycle3_validation]="Как проверяется эксплуатация"
  [cycle3_reporting]="Отчётность"
  [cycle3_constraints]="Ограничения Cycle 3"
)

header() {
  clear
  echo -e "${B}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${B}║${W}        SDLC Agent Launcher — AI Runtime           ${B}║${N}"
  echo -e "${B}╚══════════════════════════════════════════════════════╝${N}"
  echo -e "  Runtime: ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    echo -e "  Local:   ${C}${LOCAL_AGENT_HOST:-?} / ${LOCAL_MODEL_PROVIDER:-?} / ${LOCAL_MODEL:-?}${N}"
  fi
  echo -e "  Routing: ${C}${SDLC_RUNTIME_ROUTING:-не выбран}${N}"
  echo -e "  Workers: ${C}${SDLC_SUBAGENTS:-off}/${SDLC_SUBAGENT_MAX:-2}${N} — exact read/route handoff"
  if [[ "${SDLC_SUBAGENTS:-}" == "cross-runtime" ]]; then
    echo -e "  Worker:  ${C}$(subagent_profile_label 2>/dev/null || printf 'не настроен')${N}"
    echo -e "  Verify:  ${C}supervisor; fallback OFF${N}"
  fi
  if [[ -n "${PROJECTS:-}" ]]; then
    if [[ "$PROJECTS_MODE" == "single" ]]; then
      echo -e "  Projects: ${C}$PROJECTS/$SINGLE_PROJECT${N} ${Y}(один проект)${N}"
    else
      echo -e "  Projects: ${C}$PROJECTS${N}"
    fi
  else
    echo -e "  Projects: ${Y}не настроены${N}"
  fi
  [[ -n "${PROJECT:-}" ]] &&
    echo -e "  Active:   ${C}$PROJECT${N} ($(project_path))"
  echo
}

# ─── выбор проекта ────────────────────────────────────────────────────────────
pick_project() {
  mkdir -p "$PROJECTS"
  echo -e "${C}Проекты:${N}"
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    echo -e "  ${Y}1)${N} $SINGLE_PROJECT"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери проект [1/b]:${N} ")" choice
    [[ "$choice" == "b" || "$choice" == "B" ]] && return 1
    if [[ "$choice" == "1" ]]; then
      PROJECT="$SINGLE_PROJECT"
      return 0
    fi
    echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
  fi

  local i=1
  local -a proj_list=()
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* || "$name" == .* ]] && continue
    is_sdlc_project_dir "$d" || continue
    proj_list+=("$name")
    echo -e "  ${Y}$i)${N} $name"
    ((i++))
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

  [[ ${#proj_list[@]} -eq 0 ]] && echo -e "  ${Y}Проектов пока нет в выбранном каталоге${N}"
  echo -e "  ${Y}n)${N} Создать новый проект"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери проект [1-${#proj_list[@]}/n/b]:${N} ")" choice

  if [[ "$choice" == "b" || "$choice" == "B" ]]; then
    return 1
  elif [[ "$choice" == "n" ]]; then
    read -rp "$(echo -e "${W}Название нового проекта (Enter — отмена):${N} ")" PROJECT
    [[ -z "$PROJECT" ]] && return 1
    create_project "$PROJECT"
  else
    if ! valid_menu_index "$choice" "${#proj_list[@]}"; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
    fi
    PROJECT="${proj_list[$((choice-1))]}"
    if [[ -z "$PROJECT" ]]; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return 1
    fi
  fi
}

# ─── создать структуру проекта ────────────────────────────────────────────────
create_project() {
  local name="$1"
  if ! valid_project_name "$name"; then
    echo -e "${R}Недопустимое имя проекта. Используй буквы, цифры, '_' или '-', без путей и пробелов.${N}"
    return 1
  fi
  mkdir -p "$PROJECTS"
  local dir="$PROJECTS/$name"

  if [[ -d "$dir" ]]; then
    echo -e "${Y}Проект '$name' уже существует${N}"; return
  fi

  for stage in stage1-planning stage2-requirements stage3-design \
               stage4-dev stage5-testing; do
    mkdir -p "$dir/$stage/inputs" "$dir/$stage/outputs"
  done

  cat > "$dir/stage1-planning/inputs/idea.md" << 'IDEA'
---
tags: [input, stage1, idea]
---

# Описание идеи / запроса

## Бизнес-идея
[Опиши продукт или фичу]

## Целевая аудитория
[Кто будет пользоваться]

## Проблема которую решаем
[Какой pain point]

## Финансовые ожидания
[Бюджет, ожидаемый ROI]

## Ограничения
[Сроки, технические, организационные]

## Известные конкуренты
[Список]
IDEA

  local today
  today=$(date +%Y-%m-%d)
  cat > "$dir/Dashboard.md" << DASH
---
date: $today
tags: [project, dashboard]
status: active
---

# SDLC Dashboard — $name

| Этап | Статус | Последнее обновление |
|------|--------|---------------------|
| 1 — Планирование    | ⏳ Pending | — |
| 2 — Требования      | ⏳ Pending | — |
| 3 — Дизайн          | ⏳ Pending | — |
| 4 — Разработка      | ⏳ Pending | — |
| 5 — Тестирование    | ⏳ Pending | — |

Cycle 2/3: FROZEN / NOT READY
DASH

  echo -e "${G}✓ Проект '$name' создан${N}"
  echo -e "  Заполни: ${C}$dir/stage1-planning/inputs/idea.md${N}"
  echo
}

# ─── запуск агента ────────────────────────────────────────────────────────────
# Режимы:
#   task (default) — runtime "задача проект"  →  агент выполняет и завершает
#   interactive    — runtime                  →  открывается диалог, если runtime поддерживает
#
# Возврат: 0 — OK, 1 — ошибка, 2 — выход из цикла, 3 — шаг пропущен
find_agent_dir() {
  local agent="$1"
  local dir
  for subdir in cycle1-dev cycle2-deploy cycle3-ops _tools; do
    dir="$AGENTS/$subdir/$agent"
    [[ -d "$dir" ]] && echo "$dir" && return
  done
  echo ""
}

memory_collections_for_agent() {
  local agent="$1" command="$2" project_dir="$3" enabled configured collection joined=''
  local -a allowed=()
  [[ -x "$MEMORY_BROKER" && -f "$MEMORY_ACL_FILE" && -f "$MEMORY_COMMAND_ACL_FILE" ]] || return 0
  [[ -f "$project_dir/tracking/memory/profile-v1.yaml" ]] || return 0
  enabled="$(awk -F': ' '$1 == "enabled" {print $2; exit}' "$project_dir/tracking/memory/profile-v1.yaml")"
  [[ "$enabled" == true ]] || return 0
  configured="$(awk -F': ' '$1 == "collections" {print $2; exit}' "$project_dir/tracking/memory/profile-v1.yaml")"
  mapfile -t allowed < <(awk -F'\t' -v agent="$agent" 'NR > 1 && $2 == agent && $4 == "allow" {print $3}' "$MEMORY_ACL_FILE")
  for collection in planning defects architecture; do
    [[ ",$configured," == *",$collection,"* ]] || continue
    printf '%s\n' "${allowed[@]}" | grep -Fxq "$collection" || continue
    [[ "$(awk -F'\t' -v a="$agent" -v m="$command" -v c="$collection" 'NR > 1 && $2 == a && $3 == m && $4 == c && $5 == "allow" {print "allow"; exit}' "$MEMORY_COMMAND_ACL_FILE")" == allow ]] || continue
    joined="${joined}${joined:+,}$collection"
  done
  printf '%s\n' "$joined"
}

prepare_memory_snapshot() {
  local agent="$1" task="$2" project_dir="$3" collections run_dir output digest approval_id expected_profile_sha current_profile_sha memory_command
  MEMORY_RUNTIME_ARGS=()
  [[ -n "${CURRENT_RUN_ID:-}" ]] || {
    [[ ! -f "$project_dir/tracking/memory/profile-v1.yaml" ]] && return 0
    echo -e "${R}MEMORY BLOCKED: launcher-owned execution run is required.${N}"; return 1
  }
  run_dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  [[ -d "$run_dir" && ! -L "$run_dir" ]] || return 1
  expected_profile_sha="$(awk -F': ' '$1 == "memory_profile_sha256" {print $2; exit}' "$run_dir/plan.md")"
  if [[ -f "$project_dir/tracking/memory/profile-v1.yaml" && ! -L "$project_dir/tracking/memory/profile-v1.yaml" ]]; then
    current_profile_sha="$(sha256sum "$project_dir/tracking/memory/profile-v1.yaml" | awk '{print $1}')"
  else
    current_profile_sha=none
  fi
  [[ "$expected_profile_sha" == "$current_profile_sha" ]] || {
    echo -e "${R}MEMORY BLOCKED: Project memory profile changed after execution Preview.${N}"
    return 1
  }
  [[ "$current_profile_sha" != none ]] || return 0
  memory_command="${task%%$'\n'*}"
  memory_command="${memory_command%% *}"
  collections="$(memory_collections_for_agent "$agent" "$memory_command" "$project_dir")"
  [[ -n "$collections" ]] || return 0
  mkdir -p "$run_dir/memory"
  output="$run_dir/memory/step-${EXECUTION_LAST_STEP:-0}-${agent}-snapshot.md"
  approval_id="APPROVAL-MEMORY-READ-${CURRENT_RUN_ID}-${EXECUTION_LAST_STEP:-0}"
  SDLC_EXECUTION_RUN_DIR="$run_dir" "$MEMORY_BROKER" snapshot \
    --project "$project_dir" --agent "$agent" --command "$memory_command" \
    --collections "$collections" --output "$output" --approval-id "$approval_id" || return 1
  digest="$(sha256sum "$output" | awk '{print $1}')"
  MEMORY_RUNTIME_ARGS=(--memory-snapshot "$output" --memory-snapshot-sha256 "$digest")
  export SDLC_EXECUTION_RUN_DIR="$run_dir"
  [[ -z "${CURRENT_RUN_ID:-}" ]] ||
    journal_append_event "$CURRENT_RUN_ID" memory_snapshot_ready RUNNING \
      "${EXECUTION_LAST_STEP:-0}" PENDING "$agent" "$task" \
      "collections=$collections snapshot_sha256=$digest"
}

run_agent() {
  local agent="$1"
  local project="$2"
  local task="$3"
  local access="${ACTIVE_AGENT_ACCESS:-write}"
  local agent_dir project_dir="$PROJECTS/$project"
  local -a runtime_scope_args=()
  local -a worker_request_args=()
  local worker_request_file=''
  case "$agent" in
    s4-devops|s6-release|s6-sre)
      cycle23_frozen_notice
      return 1
      ;;
  esac
  agent_dir=$(find_agent_dir "$agent")

  if [[ ! -d "$agent_dir" ]]; then
    echo -e "${R}Агент '$agent' не найден${N}"; return 1
  fi
  if [[ ! -d "$project_dir" ]]; then
    echo -e "${R}Каталог проекта не найден: $project_dir${N}"; return 1
  fi

  if [[ ! -x "$AGENT_RUNNER" ]]; then
    echo -e "${R}Runtime dispatcher не найден или не исполняемый: $AGENT_RUNNER${N}"; return 1
  fi

  if [[ "$access" == scoped-write ]]; then
    [[ -f "${ACTIVE_CHANGE_SCOPE_FILE:-}" &&
       "${ACTIVE_CHANGE_SCOPE_SHA256:-}" =~ ^[0-9a-f]{64}$ ]] || {
      echo -e "${R}BLOCKED: scoped-write runtime scope не подготовлен launcher-ом.${N}"
      return 1
    }
    runtime_scope_args=(--scope-file "$ACTIVE_CHANGE_SCOPE_FILE" \
      --scope-sha256 "$ACTIVE_CHANGE_SCOPE_SHA256")
  fi

  if [[ -n "${ACTIVE_EXECUTION_PROFILE:-}" ]]; then
    apply_profile "$ACTIVE_EXECUTION_PROFILE" || return 1
  else
    resolve_step_runtime "$agent" || return 1
  fi

  if [[ "${SDLC_SUBAGENTS:-off}" != off && -n "${CURRENT_RUN_ID:-}" ]]; then
    local worker_dir
    worker_dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/workers"
    mkdir -p "$worker_dir"
    worker_request_file="$worker_dir/request-step-${EXECUTION_LAST_STEP:-0}.yaml"
    worker_request_args=(--worker-request-out "$worker_request_file")
    export SDLC_EXECUTION_RUN_DIR="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  fi

  # Собираем vendor-neutral prompt для выбранного runtime.
  local prompt=""
  if [[ "$task" == /* ]]; then
    local slash_task="${task#/}"
    local cmd_name="${slash_task%% *}"
    local cmd_args="${slash_task#"$cmd_name"}"
    cmd_args="${cmd_args# }"
    [[ -z "$cmd_args" ]] && cmd_args="$project"
    local cmd_file="$agent_dir/.claude/commands/${cmd_name}.md"
    if [[ -f "$cmd_file" ]]; then
      local template
      template=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$cmd_file")
      [[ -z "$template" ]] && template=$(grep -v '^---' "$cmd_file" | grep -v '^description:')
      prompt="Проект: $project."$'\n\n'"${template//\$ARGUMENTS/$cmd_args}"
    else
      prompt="$task"
    fi
  elif [[ -n "$task" ]]; then
    prompt="Проект: $project."$'\n\n'"$task"
  fi

  runtime_validate_prompt "$prompt" || return 1

  echo
  echo -e "${B}┌─ Агент ────────────────────────────────────────────┐${N}"
  echo -e "${B}│${N} ${W}$agent${N} — ${AGENT_DESC[$agent]}"
  echo -e "${B}│${N} Runtime: ${W}$(runtime_label)${N} (${AGENT_RUNTIME})"
  if [[ "$AGENT_RUNTIME" == "local" ]]; then
    echo -e "${B}│${N} Local: ${W}$LOCAL_AGENT_HOST / $LOCAL_MODEL_PROVIDER / $LOCAL_MODEL${N}"
  fi
  echo -e "${B}│${N} Routing: ${W}$SDLC_RUNTIME_ROUTING${N}; subagents: ${W}$SDLC_SUBAGENTS/$SDLC_SUBAGENT_MAX${N}"
  echo -e "${B}│${N} Access:  ${W}$access${N}"
  echo -e "${B}│${N} Проект: ${W}$project${N}"
  [[ -n "$prompt" ]] && echo -e "${B}│${N} Prompt: ${C}$prompt${N}"
  echo -e "${B}└────────────────────────────────────────────────────┘${N}"
  echo
  if [[ -n "$prompt" ]]; then
    echo -e "  ${Y}Enter${N} — запустить задачу (выбранный runtime завершится автоматически)"
  elif ! runtime_supports_interactive; then
    echo -e "  ${C}task-only${N} — сначала выберите зарегистрированную команду"
  else
    echo -e "  ${Y}Enter${N} — открыть интерактивный режим выбранного runtime"
  fi
  if [[ "$access" == write ]] && runtime_supports_interactive; then
    echo -e "  ${Y}i${N}     — открыть интерактивный диалог с агентом"
  elif [[ "$access" == write ]]; then
    echo -e "  ${C}Codex task-only${N} — интерактивный режим недоступен"
  elif [[ "$access" == scoped-write ]]; then
    echo -e "  ${C}scoped-write${N} — запись только в одобренные пути; интерактивный режим запрещён"
  else
    echo -e "  ${C}read-only${N} — запись и интерактивный режим запрещены launcher-ом"
  fi
  echo -e "  ${Y}s${N}     — пропустить этот шаг"
  echo -e "  ${Y}q${N}     — выйти из цикла"
  echo
  read -rp "$(echo -e "${W}Действие:${N} ")" confirm

  case "$confirm" in
    q|Q)
      return 2
      ;;
    s|S)
      echo -e "${Y}⏭  Пропущен${N}"
      return 3
      ;;
    i|I)
      if [[ "$access" != write ]]; then
        echo -e "${R}Интерактивный режим недоступен для constrained-write/read-only действия.${N}"
        return 1
      fi
      if ! runtime_supports_interactive; then
        report_interactive_codex_block
        return 1
      fi
      echo
      echo -e "${C}Интерактивный режим — ${W}$agent${N} — ${AGENT_DESC[$agent]}"
      [[ -n "$prompt" ]] && echo -e "${Y}Задача этого шага:${N} $prompt"
      echo -e "${Y}Для выхода используй команду выхода выбранного runtime.${N}"
      echo
      prepare_memory_snapshot "$agent" "$task" "$project_dir" || return 1
      "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" \
        --project-dir "$project_dir" --mode interactive "${MEMORY_RUNTIME_ARGS[@]}" \
        "${worker_request_args[@]}" --prompt "${prompt:-начни сессию}"
      local rc=$?
      echo
      if [[ $rc -eq 0 ]]; then
        echo -e "${G}✓ Сессия завершена${N}"
      else
        echo -e "${R}✗ Runtime завершился с кодом $rc${N}"
      fi
      return "$rc"
      ;;
    *)
      echo
      local rc=0
      prepare_memory_snapshot "$agent" "$task" "$project_dir" || return 1
      if [[ -n "$prompt" ]]; then
        echo -e "${C}Запускаю ($(runtime_label)): ${W}$prompt${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" \
          --project-dir "$project_dir" --mode task --access "$access" \
          "${runtime_scope_args[@]}" "${MEMORY_RUNTIME_ARGS[@]}" \
          "${worker_request_args[@]}" --prompt "$prompt" || rc=$?
      else
        if ! runtime_supports_interactive; then
          report_interactive_codex_block
          return 1
        fi
        echo -e "${C}Открываю интерактивный режим выбранного runtime...${N}"
        echo
        "$AGENT_RUNNER" --runtime "$AGENT_RUNTIME" --agent-dir "$agent_dir" \
          --project-dir "$project_dir" --mode interactive "${MEMORY_RUNTIME_ARGS[@]}" \
          "${worker_request_args[@]}" --prompt "начни сессию" || rc=$?
      fi
      echo
      if [[ $rc -eq 0 ]]; then
        echo -e "${G}✓ Агент завершил работу${N}"
        if [[ -n "$worker_request_file" && -f "$worker_request_file" ]]; then
          echo -e "${Y}Worker Request готов, но ещё не авторизован: ${C}$worker_request_file${N}"
          echo -e "Launcher/user должен отдельно зафиксировать exact read manifest и route; прямой обмен запрещён."
          journal_append_event "$CURRENT_RUN_ID" worker_request_ready WAITING_USER \
            "${EXECUTION_LAST_STEP:-0}" PENDING "$agent" "$task" \
            "request_sha256=$(sha256sum "$worker_request_file" | awk '{print $1}')"
        fi
      else
        echo -e "${R}✗ Runtime завершился с кодом $rc${N}"
      fi
      return "$rc"
      ;;
  esac
}

# ─── один агент ───────────────────────────────────────────────────────────────
menu_single_agent() {
  header
  echo -e "${W}── Запуск одного агента ──────────────────────────────${N}"
  echo

  local -a stages=(
    "Цикл 1 · S0 — Discovery & Tracking"
    "Цикл 1 · S1 — Планирование"
    "Цикл 1 · S2 — Требования"
    "Цикл 1 · S3 — Дизайн"
    "Цикл 1 · S4 — Разработка"
    "Цикл 1 · S5 — Тестирование"
    "Tools — общие утилиты (все циклы)"
  )
  local -a groups=(
    "s0-kickoff s0-defects s0-tracker s0-validate s0-quality-gates"
    "s1-pm s1-pmo s1-finance"
    "s2-ba s2-po s2-qa-req s2-test-strategy s2-security"
    "s3-arch s3-security s3-rbac s3-dba"
    "s4-qa-auto s4-dev s4-techlead"
    "s5-qa s5-qa-auto s5-perf s5-security"
    "s0-secrets"
  )

  local i=1
  local -a agent_list=()
  for s in "${!stages[@]}"; do
    echo -e "${B}${stages[$s]}${N}"
    for ag in ${groups[$s]}; do
      echo -e "  ${Y}$i)${N} ${W}$ag${N} — ${AGENT_DESC[$ag]}"
      agent_list+=("$ag")
      ((i++))
    done
    echo
  done

  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери агента [1-${#agent_list[@]}/b]:${N} ")" choice
  [[ "$choice" == "b" || "$choice" == "B" ]] && return
  if ! valid_menu_index "$choice" "${#agent_list[@]}"; then
    echo -e "${R}Неверный выбор${N}"; sleep 1; return
  fi
  local agent="${agent_list[$((choice-1))]}"
  if [[ -z "$agent" ]]; then echo -e "${R}Неверный выбор${N}"; sleep 1; return; fi

  [[ -n "${PROJECT:-}" ]] || { pick_project || return; }

  # command templates агента
  local cmd_dir
  cmd_dir="$(find_agent_dir "$agent")/.claude/commands"
  local task
  if [[ -d "$cmd_dir" ]] && compgen -G "$cmd_dir/*.md" > /dev/null 2>&1; then
    echo
    echo -e "${C}Команды агента:${N}"
    local j=1 special_count=0
    local -a cmds=()
    for f in "$cmd_dir"/*.md; do
      local cname desc
      cname="/"$(basename "$f" .md)
      if ! command_supported_by_one_agent "$agent" "$cname"; then
        ((special_count++))
        continue
      fi
      desc=$(grep '^description:' "$f" 2>/dev/null | sed 's/description: *//')
      echo -e "  ${Y}$j)${N} ${W}$cname${N} — $desc"
      cmds+=("$cname")
      ((j++))
    done
    (( special_count == 0 )) ||
      echo -e "  ${C}$special_count special command(s) доступны только через их launcher workflow.${N}"
    echo -e "  ${Y}b)${N} Назад"
    echo
    if (( ${#cmds[@]} == 0 )); then
      echo -e "${Y}У этого Agent нет команд для generic One Agent route.${N}"
      return
    fi
    read -rp "$(echo -e "${W}Выбери [1-${#cmds[@]}/b]:${N} ")" cmd_choice

    [[ "$cmd_choice" == "b" || "$cmd_choice" == "B" ]] && return
    if ! valid_menu_index "$cmd_choice" "${#cmds[@]}"; then
      echo -e "${R}Неверный выбор${N}"; sleep 1; return
    fi
    task="${cmds[$((cmd_choice-1))]}"
  else
    echo -e "${Y}У этого Agent нет зарегистрированных active commands.${N}"
    return
  fi

  run_agent_with_preview "$agent" "$PROJECT" "$task"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── настройка необязательных шагов ──────────────────────────────────────────
configure_optional_steps() {
  OPTIONAL_BEFORE=()
  OPTIONAL_AFTER=()

  local -a opt_agents=() opt_tasks=() opt_pos=() opt_labels=() opt_enabled=()

  for def in "${OPTIONAL_AGENTS_DEF[@]}"; do
    IFS='|' read -r ag task pos lbl <<< "$def"
    opt_agents+=("$ag")
    opt_tasks+=("$task")
    opt_pos+=("$pos")
    opt_labels+=("$lbl")
    opt_enabled+=(0)
  done

  local n=${#opt_agents[@]}

  while true; do
    echo
    echo -e "${B}┌─ Дополнительные шаги (необязательные) ────────────┐${N}"
    echo -e "${B}│${N} Нажми номер чтобы включить/выключить шаг"
    echo -e "${B}│${N} Enter — продолжить с текущим выбором"
    echo -e "${B}└────────────────────────────────────────────────────┘${N}"
    echo

    for ((i=0; i<n; i++)); do
      local pos_label=""
      [[ "${opt_pos[$i]}" == "before" ]] && pos_label="${C}[до цикла]${N}" || pos_label="${Y}[после цикла]${N}"
      if [[ "${opt_enabled[$i]}" -eq 1 ]]; then
        echo -e "  ${G}$((i+1)))${N} ${G}[ВКЛ]${N} ${W}${opt_agents[$i]}${N} — ${opt_labels[$i]}  $pos_label"
      else
        echo -e "  ${Y}$((i+1)))${N} ${W}[   ]${N} ${W}${opt_agents[$i]}${N} — ${opt_labels[$i]}  $pos_label"
      fi
    done

    echo
    read -rp "$(echo -e "${W}Переключить [1-${n}] или Enter для продолжения:${N} ")" toggle

    [[ -z "$toggle" ]] && break

    if valid_menu_index "$toggle" "$n"; then
      local idx=$((toggle-1))
      opt_enabled[$idx]=$(( 1 - opt_enabled[$idx] ))
    fi
  done

  for ((i=0; i<n; i++)); do
    if [[ "${opt_enabled[$i]}" -eq 1 ]]; then
      local entry="${opt_agents[$i]}:${opt_tasks[$i]}"
      if [[ "${opt_pos[$i]}" == "after" ]]; then
        OPTIONAL_AFTER+=("$entry")
      else
        OPTIONAL_BEFORE+=("$entry")
      fi
    fi
  done
}

goal_profile_path() {
  printf '%s/%s/tracking/SDLC-goals.md\n' "$PROJECTS" "$PROJECT"
}

goal_profile_history_path() {
  printf '%s/%s/tracking/SDLC-goals-history.md\n' "$PROJECTS" "$PROJECT"
}

goal_key_known() {
  local wanted="$1" key
  for key in "${ALL_GOAL_KEYS[@]}"; do
    [[ "$key" == "$wanted" ]] && return 0
  done
  return 1
}

load_goal_profile() {
  local file line key value
  file="$(goal_profile_path)"
  [[ -f "$file" ]] || return 1
  GOAL_VALUES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *:* ]] || continue
    key="${line%%:*}"
    goal_key_known "$key" || continue
    value="${line#*:}"
    value="${value# }"
    GOAL_VALUES["$key"]="$value"
  done < "$file"
}

goal_csv_allowed() {
  local value="$1" allowed="$2" item
  local -a items=()
  [[ -n "$value" ]] || return 1
  IFS=',' read -r -a items <<< "$value"
  for item in "${items[@]}"; do
    [[ ",$allowed," == *",$item,"* ]] || return 1
  done
}

goal_profile_complete_for_cycle() {
  local cycle="$1" key enabled deliverables allowed
  local -a keys=()
  case "$cycle" in
    2)
      keys=("${CYCLE2_GOAL_KEYS[@]}")
      enabled="${GOAL_VALUES[cycle2_enabled]:-}"
      deliverables="${GOAL_VALUES[cycle2_deliverables]:-}"
      allowed="images,runtime-bundle,orchestrator,iac,cicd,gitops,operations-pack,execute-deploy,custom"
      ;;
    3)
      keys=("${CYCLE3_GOAL_KEYS[@]}")
      enabled="${GOAL_VALUES[cycle3_enabled]:-}"
      deliverables="${GOAL_VALUES[cycle3_deliverables]:-}"
      allowed="monitoring,dashboards,alerts,runbooks,auto-heal,backup-dr,capacity,incident,reporting,execute-ops,custom"
      ;;
    *) return 1 ;;
  esac
  goal_profile_mode_consistent || return 1
  [[ -n "${GOAL_VALUES[revision_reason]:-}" ]] || return 1
  [[ "$enabled" =~ ^(yes|no)$ ]] || return 1
  [[ "$enabled" == "no" ]] && return 0
  for key in "${keys[@]}"; do
    [[ -n "${GOAL_VALUES[$key]:-}" ]] || return 1
  done
  goal_csv_allowed "$deliverables" "$allowed"
}

goal_profile_mode_consistent() {
  local mode="${GOAL_VALUES[goal_mode]:-}"
  local c2="${GOAL_VALUES[cycle2_enabled]:-}" c3="${GOAL_VALUES[cycle3_enabled]:-}"
  [[ "$c2" =~ ^(yes|no)$ && "$c3" =~ ^(yes|no)$ ]] || return 1
  case "$mode" in
    cycle1-only) [[ "$c2" == "no" && "$c3" == "no" ]] ;;
    through-cycle2) [[ "$c2" == "yes" && "$c3" == "no" ]] ;;
    through-cycle3) [[ "$c2" == "yes" && "$c3" == "yes" ]] ;;
    custom) return 0 ;;
    *) return 1 ;;
  esac
}

goal_route_label() {
  case "${1:-${GOAL_VALUES[goal_mode]:-}}" in
    cycle1-only) printf 'Только Cycle 1 — разработка; Cycle 2 и 3 не запускаются' ;;
    through-cycle2) printf 'Cycle 1 → Cycle 2 — разработка и подготовка поставки' ;;
    through-cycle3) printf 'Cycle 1 → Cycle 2 → Cycle 3 — полный маршрут цели' ;;
    custom)
      printf 'Своя комбинация — Cycle 2: %s, Cycle 3: %s' "${GOAL_VALUES[cycle2_enabled]:-?}" "${GOAL_VALUES[cycle3_enabled]:-?}"
      ;;
    *) printf 'Маршрут ещё не выбран' ;;
  esac
}

normalize_goal_mode_from_flags() {
  local c2="${GOAL_VALUES[cycle2_enabled]:-no}" c3="${GOAL_VALUES[cycle3_enabled]:-no}"
  if [[ "$c2" == "no" && "$c3" == "no" ]]; then
    GOAL_VALUES[goal_mode]="cycle1-only"
  elif [[ "$c2" == "yes" && "$c3" == "no" ]]; then
    GOAL_VALUES[goal_mode]="through-cycle2"
  elif [[ "$c2" == "yes" && "$c3" == "yes" ]]; then
    GOAL_VALUES[goal_mode]="through-cycle3"
  else
    GOAL_VALUES[goal_mode]="custom"
  fi
}

set_goal_route_from_choice() {
  local choice="$1" custom_c2="${2:-}" custom_c3="${3:-}"
  case "$choice" in
    1)
      GOAL_VALUES[goal_mode]="cycle1-only"
      GOAL_VALUES[cycle2_enabled]="no"
      GOAL_VALUES[cycle3_enabled]="no"
      ;;
    2)
      GOAL_VALUES[goal_mode]="through-cycle2"
      GOAL_VALUES[cycle2_enabled]="yes"
      GOAL_VALUES[cycle3_enabled]="no"
      ;;
    3)
      GOAL_VALUES[goal_mode]="through-cycle3"
      GOAL_VALUES[cycle2_enabled]="yes"
      GOAL_VALUES[cycle3_enabled]="yes"
      ;;
    4)
      [[ "$custom_c2" =~ ^(yes|no)$ && "$custom_c3" =~ ^(yes|no)$ ]] || return 1
      GOAL_VALUES[cycle2_enabled]="$custom_c2"
      GOAL_VALUES[cycle3_enabled]="$custom_c3"
      GOAL_VALUES[goal_mode]="custom"
      ;;
    *) return 1 ;;
  esac
}

set_goal_cycle_enabled() {
  local cycle="$1" value="$2"
  [[ "$cycle" =~ ^(2|3)$ && "$value" =~ ^(yes|no)$ ]] || return 1
  GOAL_VALUES["cycle${cycle}_enabled"]="$value"
  [[ -n "${GOAL_VALUES[cycle2_enabled]:-}" ]] || GOAL_VALUES[cycle2_enabled]="no"
  [[ -n "${GOAL_VALUES[cycle3_enabled]:-}" ]] || GOAL_VALUES[cycle3_enabled]="no"
  normalize_goal_mode_from_flags
}

save_goal_profile() {
  local file history tmp history_tmp key previous_revision next_revision now actor
  file="$(goal_profile_path)"
  history="$(goal_profile_history_path)"
  goal_profile_mode_consistent || {
    echo -e "${R}Профиль цели противоречив: goal_mode не совпадает с cycle2/3_enabled.${N}"
    return 1
  }
  previous_revision="${GOAL_VALUES[revision]:-0}"
  if [[ "$previous_revision" =~ ^[0-9]+$ ]]; then
    previous_revision=$((10#$previous_revision))
  else
    previous_revision=0
  fi
  next_revision=$((previous_revision + 1))
  now="${SDLC_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  actor="${SDLC_PROFILE_ACTOR:-${USER:-launcher}}"
  GOAL_VALUES[schema_version]="sdlc-goals/v1"
  GOAL_VALUES[revision]="$next_revision"
  GOAL_VALUES[updated_at]="$now"
  GOAL_VALUES[updated_by]="$actor"
  GOAL_VALUES[confirmed]="yes"
  mkdir -p "$(dirname "$file")" || return 1
  tmp="$(mktemp "${file}.tmp.XXXXXX")" || return 1
  history_tmp="$(mktemp "${history}.tmp.XXXXXX")" || { rm -f "$tmp"; return 1; }
  if [[ -f "$history" ]]; then
    cp "$history" "$history_tmp" || { rm -f "$tmp" "$history_tmp"; return 1; }
  fi
  {
    echo "# SDLC Goal Profile"
    echo
    echo "> Единый контракт цели для Cycle 1 → 2 → 3. Секреты здесь запрещены."
    echo "> Значения unknown и not-applicable допустимы только как явный ответ пользователя."
    echo
    echo '## Machine-readable contract'
    echo
    for key in "${ALL_GOAL_KEYS[@]}"; do
      printf '%s: %s\n' "$key" "${GOAL_VALUES[$key]:-}"
    done
    echo
    echo '## Допустимые deliverables'
    echo
    echo '- Cycle 2: images, runtime-bundle, orchestrator, iac, cicd, gitops, operations-pack, execute-deploy, custom'
    echo '- Cycle 3: monitoring, dashboards, alerts, runbooks, auto-heal, backup-dr, capacity, incident, reporting, execute-ops, custom'
    echo
    echo 'Профиль можно частично обновить из запускающего скрипта без повторного Cycle 1.'
  } > "$tmp"
  {
    [[ -s "$history_tmp" ]] || { echo "# SDLC Goal Profile History"; echo; }
    echo "## Revision $next_revision — $now"
    echo
    for key in "${ALL_GOAL_KEYS[@]}"; do
      printf '%s: %s\n' "$key" "${GOAL_VALUES[$key]:-}"
    done
    echo
  } >> "$history_tmp"
  mv "$tmp" "$file" || { rm -f "$history_tmp"; return 1; }
  mv "$history_tmp" "$history"
}

goal_value_valid() {
  local key="$1" value="$2"
  [[ -n "$value" ]] || return 1
  case "$key" in
    goal_mode) [[ "$value" =~ ^(cycle1-only|through-cycle2|through-cycle3|custom)$ ]] ;;
    cycle2_enabled|cycle3_enabled) [[ "$value" =~ ^(yes|no)$ ]] ;;
    cycle2_deliverables)
      goal_csv_allowed "$value" "images,runtime-bundle,orchestrator,iac,cicd,gitops,operations-pack,execute-deploy,custom"
      ;;
    cycle3_deliverables)
      goal_csv_allowed "$value" "monitoring,dashboards,alerts,runbooks,auto-heal,backup-dr,capacity,incident,reporting,execute-ops,custom"
      ;;
    *) return 0 ;;
  esac
}

prompt_goal_value() {
  local key="$1" current="${GOAL_VALUES[$1]:-}" value hint=""
  case "$key" in
    cycle2_deliverables)
      hint="images,runtime-bundle,orchestrator,iac,cicd,gitops,operations-pack,execute-deploy,custom"
      ;;
    cycle3_deliverables)
      hint="monitoring,dashboards,alerts,runbooks,auto-heal,backup-dr,capacity,incident,reporting,execute-ops,custom"
      ;;
  esac
  while true; do
    echo
    echo -e "  ${W}${GOAL_LABELS[$key]:-$key}${N}"
    [[ -n "$hint" ]] && echo -e "  ${C}Допустимо CSV: $hint${N}"
    [[ -n "$current" ]] && echo -e "  Сейчас: ${C}$current${N} (Enter — оставить)"
    read -rp "> " value
    [[ -z "$value" && -n "$current" ]] && value="$current"
    if goal_value_valid "$key" "$value"; then
      GOAL_VALUES["$key"]="$value"
      return 0
    fi
    echo -e "${R}Нужно явное допустимое значение. Для неизвестного ответа используй unknown; для неприменимого — not-applicable.${N}"
  done
}

read_explicit_yes_no() {
  local question="$1" choice
  while true; do
    echo -e "  ${W}$question${N}"
    echo -e "    ${Y}1)${N} Да, включить"
    echo -e "    ${Y}2)${N} Нет, не включать"
    read -rp "> " choice
    case "$choice" in
      1) YES_NO_RESULT="yes"; return 0 ;;
      2) YES_NO_RESULT="no"; return 0 ;;
      *) echo -e "${R}Выбери 1 или 2.${N}" ;;
    esac
  done
}

prompt_goal_route_selection() {
  local allow_keep="${1:-yes}" choice c2 c3 prompt_options="[1-4]" show_keep=0
  while true; do
    echo
    echo -e "${W}Что должно быть выполнено для этой цели?${N}"
    echo -e "  ${Y}1)${N} ${G}Только Cycle 1${N} — разработка; deploy и ops не запускаются"
    echo -e "  ${Y}2)${N} Cycle 1 → Cycle 2 — разработка и подготовка поставки"
    echo -e "  ${Y}3)${N} Cycle 1 → Cycle 2 → Cycle 3 — полный маршрут"
    echo -e "  ${Y}4)${N} Своя комбинация Cycle 2/3"
    show_keep=0
    if [[ "$allow_keep" == "yes" ]] && goal_profile_mode_consistent; then
      show_keep=1
      prompt_options="[1-4/k]"
      echo -e "  ${Y}k)${N} Оставить текущий маршрут: ${C}$(goal_route_label)${N}"
    else
      prompt_options="[1-4]"
    fi
    read -rp "$(echo -e "${W}Выбери маршрут $prompt_options:${N} ")" choice
    case "$choice" in
      1|2|3) set_goal_route_from_choice "$choice"; return 0 ;;
      4)
        read_explicit_yes_no "Включить Cycle 2 — подготовку поставки?" || return 1
        c2="$YES_NO_RESULT"
        read_explicit_yes_no "Включить Cycle 3 — эксплуатационный контур?" || return 1
        c3="$YES_NO_RESULT"
        set_goal_route_from_choice 4 "$c2" "$c3"
        return 0
        ;;
      k|K)
        if [[ $show_keep -eq 1 ]]; then
          return 0
        fi
        echo -e "${R}Текущего согласованного маршрута нет.${N}"
        ;;
      *) echo -e "${R}Выбери один из показанных вариантов.${N}" ;;
    esac
  done
}

goal_csv_contains() {
  [[ ",$1," == *",$2,"* ]]
}

prompt_goal_deliverables() {
  local cycle="$1" key current raw token item selected_csv="" seen=","
  local -a options=() tokens=()
  case "$cycle" in
    2) key="cycle2_deliverables"; options=("${CYCLE2_DELIVERABLES[@]}") ;;
    3) key="cycle3_deliverables"; options=("${CYCLE3_DELIVERABLES[@]}") ;;
    *) return 1 ;;
  esac
  current="${GOAL_VALUES[$key]:-}"
  while true; do
    echo
    echo -e "${W}Выбери deliverables для Cycle $cycle:${N}"
    local i=1 mark
    for item in "${options[@]}"; do
      mark=" "
      goal_csv_contains "$current" "$item" && mark="✓"
      echo -e "  ${Y}$i)${N} [${mark}] ${DELIVERABLE_LABELS[$item]} ${C}($item)${N}"
      ((i++))
    done
    echo -e "  Введи номера через запятую, например ${C}1,5,7${N}."
    [[ -n "$current" ]] && echo -e "  ${Y}k)${N} Оставить текущий выбор: ${C}$current${N}"
    echo -e "  ${Y}b)${N} Отменить корректировку"
    read -rp "> " raw
    if [[ "$raw" =~ ^[kK]$ && -n "$current" ]]; then
      return 0
    fi
    [[ "$raw" =~ ^[bB]$ ]] && return 2
    raw="${raw//[[:space:]]/}"
    IFS=',' read -r -a tokens <<< "$raw"
    selected_csv=""
    seen=","
    local valid=1
    for token in "${tokens[@]}"; do
      if ! valid_menu_index "$token" "${#options[@]}"; then
        valid=0
        break
      fi
      item="${options[$((token-1))]}"
      [[ "$seen" == *",$item,"* ]] && continue
      seen+="$item,"
      [[ -n "$selected_csv" ]] && selected_csv+=","
      selected_csv+="$item"
    done
    if [[ $valid -eq 1 && -n "$selected_csv" ]]; then
      GOAL_VALUES["$key"]="$selected_csv"
      return 0
    fi
    echo -e "${R}Выбери хотя бы один существующий номер из списка.${N}"
  done
}

prompt_goal_cycle() {
  local cycle="$1" edit_mode="${2:-full}" key choice current
  local -a keys=()
  case "$cycle" in
    2) keys=("${CYCLE2_GOAL_KEYS[@]}") ;;
    3) keys=("${CYCLE3_GOAL_KEYS[@]}") ;;
    *) return 1 ;;
  esac
  if [[ "$edit_mode" == "partial" ]]; then
    current="${GOAL_VALUES[${keys[0]}]:-no}"
    while true; do
      echo
      echo -e "${W}Cycle $cycle сейчас: ${C}$([[ "$current" == "yes" ]] && echo 'ВКЛЮЧЁН' || echo 'ВЫКЛЮЧЕН')${N}"
      if [[ "$current" == "yes" ]]; then
        echo -e "  ${Y}1)${N} Оставить включённым и изменить настройки"
        echo -e "  ${Y}2)${N} Выключить Cycle $cycle"
      else
        echo -e "  ${Y}1)${N} Включить Cycle $cycle и настроить"
      fi
      echo -e "  ${Y}b)${N} Отменить корректировку"
      read -rp "> " choice
      case "$choice" in
        1) set_goal_cycle_enabled "$cycle" yes; break ;;
        2)
          if [[ "$current" == "yes" ]]; then
            set_goal_cycle_enabled "$cycle" no
            return 0
          fi
          ;;
        b|B) return 2 ;;
        *) echo -e "${R}Выбери показанный вариант.${N}" ;;
      esac
    done
  fi
  [[ "${GOAL_VALUES[${keys[0]}]:-}" == "no" ]] && return 0
  echo
  echo -e "${B}── Настройка включённого Cycle $cycle ──${N}"
  for key in "${keys[@]:1}"; do
    if [[ "$key" == "cycle${cycle}_deliverables" ]]; then
      prompt_goal_deliverables "$cycle" || return $?
    else
      prompt_goal_value "$key"
    fi
  done
}

configure_goal_profile() {
  cycle23_frozen_notice
  return 1
  # Historical implementation below is intentionally retained for a future redesign.
  local scope="${1:-full}" key confirm
  if ! load_goal_profile; then
    GOAL_VALUES=()
    if [[ "$scope" != "full" ]]; then
      echo -e "${Y}Первое создание требует полного профиля; переключаю на полный wizard.${N}"
      scope="full"
    fi
  fi
  header
  echo -e "${W}── Профиль цели проекта: $PROJECT ───────────────────${N}"
  echo -e "${Y}Секреты не вводить:${N} только названия, identity/path и границы разрешений."

  if [[ "$scope" == "full" || -z "${GOAL_VALUES[goal_mode]:-}" ]]; then
    prompt_goal_route_selection yes || return 1
  fi

  case "$scope" in
    full)
      prompt_goal_cycle 2 full || return 1
      prompt_goal_cycle 3 full || return 1
      ;;
    2) prompt_goal_cycle 2 partial || return 1 ;;
    3) prompt_goal_cycle 3 partial || return 1 ;;
    *) return 1 ;;
  esac
  prompt_goal_value revision_reason

  if { [[ "$scope" == "full" || "$scope" == "2" ]] && ! goal_profile_complete_for_cycle 2; } ||
     { [[ "$scope" == "full" || "$scope" == "3" ]] && ! goal_profile_complete_for_cycle 3; }; then
    echo -e "${R}Профиль неполон или содержит недопустимые deliverables; файл не изменён.${N}"
    return 1
  fi
  echo
  echo -e "${W}Проверь перед сохранением:${N}"
  echo -e "  mode=${C}${GOAL_VALUES[goal_mode]}${N}; Cycle2=${C}${GOAL_VALUES[cycle2_enabled]}${N}; Cycle3=${C}${GOAL_VALUES[cycle3_enabled]}${N}"
  [[ "${GOAL_VALUES[cycle2_enabled]}" == "yes" ]] &&
    echo -e "  Cycle2 deliverables: ${C}${GOAL_VALUES[cycle2_deliverables]}${N}"
  [[ "${GOAL_VALUES[cycle3_enabled]}" == "yes" ]] &&
    echo -e "  Cycle3 deliverables: ${C}${GOAL_VALUES[cycle3_deliverables]}${N}"
  echo -e "  revision reason: ${C}${GOAL_VALUES[revision_reason]}${N}"
  read -rp "$(echo -e "${W}Сохранить новую revision? [y/N]:${N} ")" confirm
  [[ "$confirm" =~ ^[yYдД]$ ]] || { echo -e "${Y}Изменения не сохранены.${N}"; return 1; }
  save_goal_profile || return 1
  case "$scope" in
    full)
      set_cycle_tdd_status_blocked 2 2>/dev/null || true
      set_cycle_tdd_status_blocked 3 2>/dev/null || true
      ;;
    2) set_cycle_tdd_status_blocked 2 2>/dev/null || true ;;
    3) set_cycle_tdd_status_blocked 3 2>/dev/null || true ;;
  esac
  echo -e "${G}✓ Профиль цели сохранён: $(goal_profile_path)${N}"
}

show_goal_profile() {
  local file
  file="$(goal_profile_path)"
  if [[ -f "$file" ]]; then
    echo -e "${C}$file${N}"
    echo
    awk '{ print "  " $0 }' "$file"
  else
    echo -e "${Y}Профиль цели ещё не создан.${N}"
  fi
}

show_goal_profile_history() {
  local file
  file="$(goal_profile_history_path)"
  if [[ -f "$file" ]]; then
    echo -e "${C}$file${N}"
    echo
    awk '{ print "  " $0 }' "$file"
  else
    echo -e "${Y}История revision ещё не создана.${N}"
  fi
}

ensure_goal_profile_for_cycle() {
  local cycle="$1"
  if load_goal_profile && goal_profile_complete_for_cycle "$cycle"; then
    return 0
  fi
  echo -e "${Y}Для Cycle $cycle нужен заполненный профиль цели.${N}"
  configure_goal_profile "$cycle"
}

offer_goal_profile_at_cycle1_entry() {
  return 0
}

menu_goal_profile() {
  render_cycle23_frozen_status
  return 1
}

cycle_tdd_status_file() {
  case "$1" in
    1) printf '%s/%s/stage4-dev/outputs/QA-TDD-status.md\n' "$PROJECTS" "$PROJECT" ;;
    2) printf '%s/%s/stage6-deploy/outputs/DEPLOY-TDD-status.md\n' "$PROJECTS" "$PROJECT" ;;
    3) printf '%s/%s/stage7-ops/outputs/OPS-TDD-status.md\n' "$PROJECTS" "$PROJECT" ;;
    *) return 1 ;;
  esac
}

read_cycle_tdd_field() {
  local cycle="$1" field="$2" file
  file="$(cycle_tdd_status_file "$cycle")" || return 1
  [[ -f "$file" ]] || return 1
  awk -F: -v wanted="$field" '
    {
      key=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
    }
    key == wanted {
      value=$0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

read_cycle_tdd_status() {
  local status
  status="$(read_cycle_tdd_field "$1" status)" || return 1
  printf '%s\n' "${status^^}"
}

validate_cycle1_tdd_status() {
  local expected="$1"
  bash "$AGENTS/cycle1-dev/s0-validate/tdd-status-check.sh" "$(project_path)" "$expected"
}

cycle1_pr_evidence_check() {
  bash "$AGENTS/cycle1-dev/s0-validate/pr-evidence-check.sh" "$1" "$2"
}

cycle1_evidence_summary() {
  bash "$AGENTS/cycle1-dev/s0-validate/evidence-v1-summary.sh" "$1" "$2"
}

prepare_cycle1_techlead_evidence() {
  local root source safe_source output tmp evidence_output
  root="$(project_path)"
  validate_cycle1_tdd_status PASS >/dev/null || return 1
  source="$(read_cycle_tdd_field 1 source_revision)" || return 1
  evidence_output="$(cycle1_pr_evidence_check "$root" "$source" 2>&1)" || {
    printf '%s\n' "$evidence_output" >&2
    return 1
  }
  safe_source="${source//:/-}"
  output="$root/stage4-dev/outputs/EVIDENCE-$safe_source.md"
  mkdir -p "$(dirname "$output")"
  tmp="$(mktemp "${output}.tmp.XXXXXX")" || return 1
  if cycle1_evidence_summary "$root" "$source" > "$tmp"; then
    mv "$tmp" "$output"
  else
    rm -f "$tmp"
    return 1
  fi
  printf '%s\n' "$evidence_output"
  echo "EVIDENCE SUMMARY VERIFIED: source=$source path=${output#"$root/"}"
}

cycle_tdd_revision_matches() {
  local cycle="$1" status_revision
  if [[ "$cycle" == "1" ]]; then
    status_revision="$(read_cycle_tdd_field "$cycle" source_revision || true)"
    [[ "$status_revision" =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64}|sha256:[0-9a-fA-F]{64})$ ]]
    return
  fi
  status_revision="$(read_cycle_tdd_field "$cycle" goal_profile_revision || true)"
  load_goal_profile || return 1
  [[ -n "$status_revision" && "$status_revision" == "${GOAL_VALUES[revision]:-}" ]]
}

set_cycle_tdd_status_blocked() {
  local file tmp
  file="$(cycle_tdd_status_file "$1")" || return 1
  [[ -f "$file" ]] || return 1
  tmp="$(mktemp "${file}.tmp.XXXXXX")" || return 1
  awk '
    BEGIN { written=0 }
    /^[[:space:]]*status:[[:space:]]*/ && !written {
      print "status: BLOCKED"
      written=1
      next
    }
    { print }
    END { if (!written) print "status: BLOCKED" }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

require_cycle_tdd_red() {
  local cycle="$1" status
  status="$(read_cycle_tdd_status "$cycle" || true)"
  if [[ "$status" != "RED" ]]; then
    echo -e "${R}TDD BLOCKER Cycle $cycle: перед реализацией нужен status: RED; получено '${status:-нет файла}'.${N}"
    return 1
  fi
  if ! cycle_tdd_revision_matches "$cycle"; then
    if [[ "$cycle" == 1 ]]; then
      echo -e "${R}TDD BLOCKER Cycle 1: source_revision отсутствует или не является exact SHA/digest.${N}"
    else
      echo -e "${R}TDD BLOCKER Cycle $cycle: goal_profile_revision устарела или отсутствует.${N}"
    fi
    return 1
  fi
  if [[ "$cycle" == 1 ]] && ! validate_cycle1_tdd_status RED; then
    echo -e "${R}TDD BLOCKER Cycle 1: QA-TDD-status/Red evidence не прошёл schema validation.${N}"
    return 1
  fi
}

run_cycle_tdd_repair_loop() {
  local cycle="$1" status max_iterations="${TDD_MAX_REPAIR_ITERATIONS:-3}" iteration=0 rc
  local -a repair_steps=()
  case "$cycle" in
    1) repair_steps=("s4-dev:/dev-report" "s4-qa-auto:/run-tests") ;;
    2) repair_steps=("s4-devops:/pipeline" "s4-devops:/runbook" "s4-devops:/prepare-delivery" "s4-devops:/run-deploy-tests") ;;
    3) repair_steps=("s6-sre:/configure-ops" "s6-sre:/run-ops-tests") ;;
    *) return 1 ;;
  esac
  valid_menu_index "$max_iterations" 10 || {
    echo -e "${R}TDD_MAX_REPAIR_ITERATIONS должен быть 1..10${N}"
    return 1
  }

  status="$(read_cycle_tdd_status "$cycle" || true)"
  if ! cycle_tdd_revision_matches "$cycle"; then
    set_cycle_tdd_status_blocked "$cycle" || true
    if [[ "$cycle" == 1 ]]; then
      echo -e "${R}TDD BLOCKED Cycle 1: evidence не связано с exact source revision.${N}"
    else
      echo -e "${R}TDD BLOCKED Cycle $cycle: evidence относится к другой revision профиля цели.${N}"
    fi
    return 1
  fi
  while [[ "$status" == "FAIL" && $iteration -lt $max_iterations ]]; do
    if [[ "$cycle" == 1 ]] && ! validate_cycle1_tdd_status FAIL; then
      set_cycle_tdd_status_blocked "$cycle" || true
      echo -e "${R}TDD BLOCKED: FAIL не подтверждает полный affected regression set.${N}"
      return 1
    fi
    ((iteration++))
    echo -e "${Y}TDD repair Cycle $cycle — $iteration/$max_iterations: тесты FAIL.${N}"
    local entry agent task
    for entry in "${repair_steps[@]}"; do
      agent="${entry%%:*}"
      task="${entry#*:}"
      local repair_before='UNMAPPED' repair_access previous_access="${ACTIVE_AGENT_ACCESS:-}"
      if [[ "$cycle" == 1 ]]; then
        repair_before="$(declared_output_fingerprint "$agent" "$task" 2>/dev/null || printf 'UNMAPPED')"
        repair_access="$(command_access "$agent" "$task" 2>/dev/null || true)"
        [[ "$repair_access" == scoped-write ]] || {
          echo -e "${R}TDD BLOCKED: Stage 4 repair command has no scoped-write capability.${N}"
          return 1
        }
        if ! prepare_change_scope_step "$agent" "$task" "${EXECUTION_LAST_STEP:-0}"; then
          echo -e "${R}TDD BLOCKED: ${CHANGE_SCOPE_REASON:-approved Change Scope is required}.${N}"
          clear_active_change_scope
          return 1
        fi
        ACTIVE_AGENT_ACCESS="$repair_access"
      fi
      run_agent "$agent" "$PROJECT" "$task"
      rc=$?
      ACTIVE_AGENT_ACCESS="$previous_access"
      if [[ "$cycle" == 1 ]] &&
         ! verify_change_scope_step "$agent" "$task" "${EXECUTION_LAST_STEP:-0}"; then
        clear_active_change_scope
        set_cycle_tdd_status_blocked "$cycle" || true
        echo -e "${R}TDD BLOCKED: repair изменил Project вне одобренного Change Scope.${N}"
        return 1
      fi
      clear_active_change_scope
      [[ $rc -eq 0 ]] || { set_cycle_tdd_status_blocked "$cycle" || true; return 1; }
      if [[ "$cycle" == 1 ]]; then
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" repair_process_ok RUNNING "${EXECUTION_LAST_STEP:-0}" PROCESS_OK "$agent" "$task" 'runtime exit code 0'
        if ! verify_declared_outputs "$agent" "$task" "$repair_before"; then
          set_cycle_tdd_status_blocked "$cycle" || true
          [[ -z "${CURRENT_RUN_ID:-}" ]] ||
            journal_append_event "$CURRENT_RUN_ID" repair_artifact_unverified BLOCKED "${EXECUTION_LAST_STEP:-0}" UNVERIFIED "$agent" "$task" "$DECLARED_OUTPUT_REASON"
          echo -e "${R}TDD BLOCKED: repair process не изменил declared outputs: $DECLARED_OUTPUT_REASON.${N}"
          return 1
        fi
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" repair_artifact_verified RUNNING "${EXECUTION_LAST_STEP:-0}" ARTIFACT_VERIFIED "$agent" "$task" "$DECLARED_OUTPUT_REASON"
      fi
    done
    status="$(read_cycle_tdd_status "$cycle" || true)"
  done

  case "$status" in
    PASS)
      if ! cycle_tdd_revision_matches "$cycle"; then
        set_cycle_tdd_status_blocked "$cycle" || true
        echo -e "${R}TDD BLOCKED Cycle $cycle: PASS не связан с допустимой exact revision.${N}"
        return 1
      fi
      if [[ "$cycle" == 1 ]] && ! validate_cycle1_tdd_status PASS; then
        set_cycle_tdd_status_blocked "$cycle" || true
        echo -e "${R}TDD BLOCKED Cycle 1: selective/partial PASS не принимается.${N}"
        return 1
      fi
      echo -e "${G}✓ TDD PASS после $iteration repair iteration(s).${N}"
      return 0
      ;;
    FAIL)
      set_cycle_tdd_status_blocked "$cycle" || true
      echo -e "${R}TDD BLOCKED: исчерпан лимит $max_iterations, silent pass запрещён.${N}"
      return 1
      ;;
    BLOCKED)
      echo -e "${R}TDD BLOCKED агентом тестирования.${N}"
      return 1
      ;;
    *)
      set_cycle_tdd_status_blocked "$cycle" || true
      echo -e "${R}TDD BLOCKED: ожидался PASS/FAIL/BLOCKED, получено '${status:-нет файла}'.${N}"
      return 1
      ;;
  esac
}

# Backward-compatible Cycle 1 API used by existing contracts.
read_tdd_status() { read_cycle_tdd_status 1; }
set_tdd_status_blocked() { set_cycle_tdd_status_blocked 1; }
require_tdd_red() { require_cycle_tdd_red 1; }
run_tdd_repair_loop() { run_cycle_tdd_repair_loop 1; }

# ─── исполнение списка шагов цикла ────────────────────────────────────────────
# Аргументы: $1 — заголовок; $2 — номер цикла; RUN_CYCLE/RUN_OPTIONAL заполнены
execute_cycle() {
  local cycle_title="$1"
  local cycle_id="${2:-1}"
  local total=${#RUN_CYCLE[@]}

  local step=0 skipped=0 done_count=0 aborted=0
  local -a step_log=()
  EXECUTION_LAST_STEP=0
  EXECUTION_LAST_STEP_STATUS=PENDING
  EXECUTION_LAST_ACTION=''
  EXECUTION_LAST_AGENT=''
  EXECUTION_LAST_TASK=''
  EXECUTION_LAST_REASON=''

  for ((idx=0; idx<${#RUN_CYCLE[@]}; idx++)); do
    ((step++))
    local entry="${RUN_CYCLE[$idx]}"
    local is_optional="${RUN_OPTIONAL[$idx]}"
    local agent="${entry%%:*}"
    local task="${entry#*:}"
    local label="${agent} — ${AGENT_DESC[$agent]}"
    local opt_tag=""
    [[ "$is_optional" -eq 1 ]] && opt_tag=" ${C}[доп]${N}"
    EXECUTION_LAST_STEP="$step"
    EXECUTION_LAST_STEP_STATUS=RUNNING
    EXECUTION_LAST_ACTION="$agent $task"
    EXECUTION_LAST_AGENT="$agent"
    EXECUTION_LAST_TASK="$task"
    EXECUTION_LAST_REASON='dispatch requested'

    local capability access previous_access="${ACTIVE_AGENT_ACCESS:-}"
    capability="$(command_capability "$agent" "$task" 2>/dev/null || true)"
    access="$(command_access "$agent" "$task" 2>/dev/null || true)"
    if [[ -z "$capability" || -z "$access" || "$capability" == orchestrated-special ]]; then
      EXECUTION_LAST_STEP_STATUS=UNVERIFIED
      EXECUTION_LAST_REASON="unsupported command capability: ${capability:-unregistered}"
      step_log+=("  ${R}✗${N}  $label${opt_tag} — capability contract отсутствует")
      ((aborted++))
      break
    fi

    local boundary_gate=''
    if [[ "$cycle_id" == 1 ]]; then
      boundary_gate="$(cycle1_gate_before_entry "$agent" "$task" 2>/dev/null || true)"
    fi
    if [[ -n "$boundary_gate" ]]; then
      echo
      echo -e "${B}── Gate $boundary_gate перед $agent $task ──${N}"
      local gate_output gate_evidence
      if gate_output="$(run_cycle1_gate_validator "$boundary_gate" 2>&1)"; then
        printf '%s\n' "$gate_output"
        gate_evidence="$(grep -E '^[[:space:]]*(PR EVIDENCE|SG3|EXECUTOR CONTROLS|QUALITY POLICY) VERIFIED:' <<< "$gate_output" | sed 's/^[[:space:]]*//' | tr '\n' ';' | sed 's/;$//' || true)"
        [[ -n "$gate_evidence" ]] || gate_evidence='deterministic validator exit code 0'
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" gate_pass RUNNING "$step" GATE_PASS '' "Gate $boundary_gate" "$gate_evidence"
      else
        printf '%s\n' "$gate_output"
        EXECUTION_LAST_STEP_STATUS=GATE_BLOCKED
        EXECUTION_LAST_REASON="Gate $boundary_gate FAIL/BLOCKED/UNVERIFIED"
        EXECUTION_LAST_ACTION="Gate $boundary_gate before $agent $task"
        step_log+=("  ${R}✗${N}  Gate $boundary_gate — следующий Stage заблокирован")
        ((aborted++))
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" gate_blocked BLOCKED "$step" GATE_BLOCKED '' "Gate $boundary_gate" "$EXECUTION_LAST_REASON"
        break
      fi
    fi

    echo
    echo -e "${B}━━━ $cycle_title — Шаг $step / $total ━━━━━━━━━━━━━━━━━━${N}${opt_tag}"
    if [[ -n "${CURRENT_RUN_ID:-}" && -d "$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")" ]]; then
      journal_write_state "$CURRENT_RUN_ID" RUNNING "$step" "$total" RUNNING "$agent $task"
      journal_append_event "$CURRENT_RUN_ID" step_started RUNNING "$step" RUNNING "$agent" "$task" 'dispatch requested'
    fi

    if [[ "$entry" == "s4-dev:/dev-report" ]] && ! require_cycle_tdd_red 1; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='TDD RED отсутствует'
      step_log+=("  ${R}✗${N}  $label — TDD RED отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" == "s4-techlead:/review" ]]; then
      local techlead_evidence_output
      if techlead_evidence_output="$(prepare_cycle1_techlead_evidence 2>&1)"; then
        printf '%s\n' "$techlead_evidence_output"
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" techlead_evidence_ready RUNNING "$step" ARTIFACT_VERIFIED "$agent" "$task" "$techlead_evidence_output"
      else
        printf '%s\n' "$techlead_evidence_output"
        EXECUTION_LAST_STEP_STATUS=GATE_BLOCKED
        EXECUTION_LAST_REASON='Tech Lead input evidence FAIL/BLOCKED/UNVERIFIED'
        step_log+=("  ${R}✗${N}  $label — verified evidence summary отсутствует")
        ((aborted++))
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" techlead_evidence_blocked BLOCKED "$step" UNVERIFIED "$agent" "$task" "$EXECUTION_LAST_REASON"
        break
      fi
    fi
    if [[ "$entry" == "s4-devops:/pipeline" ]] && ! require_cycle_tdd_red 2; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='DEPLOY TDD RED отсутствует'
      step_log+=("  ${R}✗${N}  $label — DEPLOY TDD RED отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" == "s6-sre:/configure-ops" ]] && ! require_cycle_tdd_red 3; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='OPS TDD RED отсутствует'
      step_log+=("  ${R}✗${N}  $label — OPS TDD RED отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" =~ ^s6-release: ]] &&
       { [[ "$(read_cycle_tdd_status 2 || true)" != "PASS" ]] ||
         ! cycle_tdd_revision_matches 2; }; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='DEPLOY TDD PASS отсутствует'
      step_log+=("  ${R}✗${N}  $label — DEPLOY TDD PASS отсутствует")
      ((aborted++))
      break
    fi
    if [[ "$entry" =~ ^s6-sre:/(post-deploy|gate7)$ ]] &&
       { [[ "$(read_cycle_tdd_status 3 || true)" != "PASS" ]] ||
         ! cycle_tdd_revision_matches 3; }; then
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON='OPS TDD PASS отсутствует'
      step_log+=("  ${R}✗${N}  $label — OPS TDD PASS отсутствует")
      ((aborted++))
      break
    fi

    local declared_before='UNMAPPED'
    if [[ "$capability" == mutating-declared-output ]]; then
      declared_before="$(declared_output_fingerprint "$agent" "$task" 2>/dev/null || printf 'UNMAPPED')"
    fi
    if [[ "$access" == scoped-write ]] && ! prepare_change_scope_step "$agent" "$task" "$step"; then
      EXECUTION_LAST_STEP_STATUS=UNVERIFIED
      EXECUTION_LAST_REASON="${CHANGE_SCOPE_REASON:-approved Change Scope is required}"
      step_log+=("  ${R}✗${N}  $label${opt_tag} — Change Scope blocked")
      ((aborted++))
      [[ -z "${CURRENT_RUN_ID:-}" ]] ||
        journal_append_event "$CURRENT_RUN_ID" change_scope_blocked WAITING_USER "$step" UNVERIFIED \
          "$agent" "$task" "$EXECUTION_LAST_REASON"
      clear_active_change_scope
      break
    fi
    if [[ "$cycle_id" == 1 ]] && cycle1_completion_after_entry "$agent" "$task"; then
      if ! prepare_cycle1_completion_context "$CURRENT_RUN_ID"; then
        EXECUTION_LAST_STEP_STATUS=UNVERIFIED
        EXECUTION_LAST_REASON='completion runtime context unavailable'
        step_log+=("  ${R}✗${N}  $label — current manifest/plan context отсутствует")
        ((aborted++))
        clear_active_change_scope
        break
      fi
    fi
    ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[$idx]:-}"
    ACTIVE_AGENT_ACCESS="$access"
    run_agent "$agent" "$PROJECT" "$task"
    local rc=$?
    ACTIVE_EXECUTION_PROFILE=""
    ACTIVE_AGENT_ACCESS="$previous_access"
    clear_cycle1_completion_context

    local scope_verification_failed=0
    if [[ "$access" == scoped-write ]] && ! verify_change_scope_step "$agent" "$task" "$step"; then
      scope_verification_failed=1
    fi
    clear_active_change_scope

    if [[ $scope_verification_failed -eq 0 && $rc -eq 0 && "$entry" == "s4-qa-auto:/run-tests" ]]; then
      run_cycle_tdd_repair_loop 1
      rc=$?
    elif [[ $rc -eq 0 && "$entry" == "s4-devops:/run-deploy-tests" ]]; then
      run_cycle_tdd_repair_loop 2
      rc=$?
    elif [[ $rc -eq 0 && "$entry" == "s6-sre:/run-ops-tests" ]]; then
      run_cycle_tdd_repair_loop 3
      rc=$?
    fi

    if [[ $scope_verification_failed -ne 0 ]]; then
      EXECUTION_LAST_STEP_STATUS=UNVERIFIED
      EXECUTION_LAST_REASON="${CHANGE_SCOPE_REASON:-full Project diff violates approved Change Scope}"
      step_log+=("  ${R}✗${N}  $label${opt_tag} — Change Scope violation")
      ((aborted++))
      echo -e "${R}Цикл заблокирован: обнаружено изменение вне одобренного Change Scope.${N}"
      break
    elif [[ $rc -eq 2 ]]; then
      EXECUTION_LAST_STEP_STATUS=UNKNOWN
      EXECUTION_LAST_REASON='пользователь прервал цикл'
      step_log+=("  ${Y}⏹${N}  $label${opt_tag}")
      ((aborted++))
      echo -e "${Y}Цикл прерван на шаге $step${N}"
      break
    elif [[ $rc -eq 3 && "$is_optional" -eq 0 ]]; then
      EXECUTION_LAST_STEP_STATUS=SKIPPED
      EXECUTION_LAST_REASON='обязательный шаг пропущен'
      step_log+=("  ${R}✗${N}  $label — обязательный шаг нельзя пропустить")
      ((aborted++))
      echo -e "${R}Цикл заблокирован: обязательный шаг $step нельзя пропустить.${N}"
      break
    elif [[ $rc -eq 3 ]]; then
      EXECUTION_LAST_STEP_STATUS=SKIPPED
      EXECUTION_LAST_REASON='необязательный шаг пропущен'
      step_log+=("  ${Y}⏭${N}  $label${opt_tag}")
      ((skipped++))
      [[ -z "${CURRENT_RUN_ID:-}" ]] ||
        journal_append_event "$CURRENT_RUN_ID" step_skipped RUNNING "$step" SKIPPED "$agent" "$task" 'optional step skipped'
    elif [[ $rc -eq 0 ]]; then
      [[ -z "${CURRENT_RUN_ID:-}" ]] ||
        journal_append_event "$CURRENT_RUN_ID" step_process_ok RUNNING "$step" PROCESS_OK "$agent" "$task" 'runtime exit code 0'
      if [[ "$capability" == read-only-no-output ]]; then
        EXECUTION_LAST_STEP_STATUS=READ_ONLY_VERIFIED
        EXECUTION_LAST_REASON='capability-enforced read-only command completed'
        step_log+=("  ${G}✓${N}  $label${opt_tag} — read-only verified")
        ((done_count++))
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" step_read_only_verified RUNNING "$step" READ_ONLY_VERIFIED \
            "$agent" "$task" "$EXECUTION_LAST_REASON"
        continue
      fi
      if verify_declared_outputs "$agent" "$task" "$declared_before"; then
        EXECUTION_LAST_STEP_STATUS=ARTIFACT_VERIFIED
        EXECUTION_LAST_REASON="$DECLARED_OUTPUT_REASON"
        step_log+=("  ${G}✓${N}  $label${opt_tag} — artifact verified")
        ((done_count++))
        [[ -z "${CURRENT_RUN_ID:-}" ]] ||
          journal_append_event "$CURRENT_RUN_ID" step_artifact_verified RUNNING "$step" ARTIFACT_VERIFIED "$agent" "$task" "$DECLARED_OUTPUT_REASON"

        if [[ "$cycle_id" == 1 ]] && cycle1_software_dod_after_entry "$agent" "$task"; then
          if run_cycle1_software_dod_validator; then
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" software_dod_auto_pass RUNNING "$step" DOD_AUTO_PASS "$agent" "$task" 'deterministic automated DoD subset exit code 0'
          else
            EXECUTION_LAST_STEP_STATUS=DOD_BLOCKED
            EXECUTION_LAST_REASON='software DoD FAIL/BLOCKED/UNVERIFIED'
            step_log+=("  ${R}✗${N}  Software DoD — implementation unit заблокирован")
            ((aborted++))
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" software_dod_blocked BLOCKED "$step" DOD_BLOCKED "$agent" "$task" "$EXECUTION_LAST_REASON"
            break
          fi
          if run_cycle1_full_dod_validator; then
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" software_dod_approved RUNNING "$step" DOD_PASS \
                "$agent" "$task" 'independent Human Approval v1 covers DOD-1..DOD-11 and current review digests'
          else
            EXECUTION_LAST_STEP_STATUS=DOD_BLOCKED
            EXECUTION_LAST_REASON='full Software DoD approval FAIL/BLOCKED/UNVERIFIED'
            step_log+=("  ${R}✗${N}  Full Software DoD — independent approval отсутствует")
            ((aborted++))
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" software_dod_blocked BLOCKED "$step" DOD_BLOCKED "$agent" "$task" "$EXECUTION_LAST_REASON"
            break
          fi
        fi

        if [[ "$cycle_id" == 1 ]]; then
          boundary_gate="$(cycle1_gate_after_entry "$agent" "$task" 2>/dev/null || true)"
        else
          boundary_gate=''
        fi
        if [[ -n "$boundary_gate" ]]; then
          local gate_output gate_evidence
          if gate_output="$(run_cycle1_gate_validator "$boundary_gate" 2>&1)"; then
            printf '%s\n' "$gate_output"
            gate_evidence="$(grep -E '^[[:space:]]*(PR EVIDENCE|SG3|EXECUTOR CONTROLS|QUALITY POLICY) VERIFIED:' <<< "$gate_output" | sed 's/^[[:space:]]*//' | tr '\n' ';' | sed 's/;$//' || true)"
            [[ -n "$gate_evidence" ]] || gate_evidence='deterministic validator exit code 0'
            journal_append_event "$CURRENT_RUN_ID" gate_pass RUNNING "$step" GATE_PASS '' "Gate $boundary_gate" "$gate_evidence"
          else
            printf '%s\n' "$gate_output"
            EXECUTION_LAST_STEP_STATUS=GATE_BLOCKED
            EXECUTION_LAST_REASON="Gate $boundary_gate FAIL/BLOCKED/UNVERIFIED"
            step_log+=("  ${R}✗${N}  Gate $boundary_gate — Cycle 1 validation заблокирована")
            ((aborted++))
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" gate_blocked BLOCKED "$step" GATE_BLOCKED '' "Gate $boundary_gate" "$EXECUTION_LAST_REASON"
            break
          fi
        fi

        if [[ "$cycle_id" == 1 ]] && cycle1_completion_after_entry "$agent" "$task"; then
          local completion_output
          if ! completion_output="$(run_cycle1_execution_proof_create 2>&1)"; then
            printf '%s\n' "$completion_output"
            EXECUTION_LAST_STEP_STATUS=UNVERIFIED
            EXECUTION_LAST_REASON='full Cycle 1 execution proof FAIL/BLOCKED/UNVERIFIED'
            step_log+=("  ${R}✗${N}  Cycle 1 completion — execution proof заблокирован")
            ((aborted++))
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" cycle1_completion_blocked BLOCKED "$step" UNVERIFIED "$agent" "$task" "$EXECUTION_LAST_REASON"
            break
          elif completion_output="$(run_cycle1_completion_validator 2>&1)"; then
            printf '%s\n' "$completion_output"
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" cycle1_completion_pass RUNNING "$step" ARTIFACT_VERIFIED "$agent" "$task" "$completion_output"
          else
            printf '%s\n' "$completion_output"
            EXECUTION_LAST_STEP_STATUS=UNVERIFIED
            EXECUTION_LAST_REASON='Cycle 1 completion FAIL/BLOCKED/UNVERIFIED'
            step_log+=("  ${R}✗${N}  Cycle 1 completion — manifest/evidence bundle заблокированы")
            ((aborted++))
            [[ -z "${CURRENT_RUN_ID:-}" ]] ||
              journal_append_event "$CURRENT_RUN_ID" cycle1_completion_blocked BLOCKED "$step" UNVERIFIED "$agent" "$task" "$EXECUTION_LAST_REASON"
            break
          fi
        fi
      else
        EXECUTION_LAST_STEP_STATUS=UNVERIFIED
        EXECUTION_LAST_REASON="$DECLARED_OUTPUT_REASON"
        step_log+=("  ${R}✗${N}  $label${opt_tag} — artifact unverified")
        ((aborted++))
        if [[ -n "${CURRENT_RUN_ID:-}" ]]; then
          journal_append_event "$CURRENT_RUN_ID" step_artifact_unverified BLOCKED "$step" UNVERIFIED "$agent" "$task" "$DECLARED_OUTPUT_REASON"
        fi
        echo -e "${R}Цикл заблокирован на шаге $step: ${DECLARED_OUTPUT_REASON}.${N}"
        break
      fi
    else
      EXECUTION_LAST_STEP_STATUS=FAILED
      EXECUTION_LAST_REASON="runtime exit code $rc"
      step_log+=("  ${R}✗${N}  $label${opt_tag}")
      ((aborted++))
      if [[ -n "${CURRENT_RUN_ID:-}" ]]; then
        journal_append_event "$CURRENT_RUN_ID" step_failed BLOCKED "$step" FAILED "$agent" "$task" "runtime exit code $rc"
      fi
      echo -e "${R}Цикл заблокирован на шаге $step (код $rc)${N}"
      break
    fi
  done

  echo
  echo -e "${G}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${G}║${W}  Итог: $cycle_title — Проект: $PROJECT${N}"
  echo -e "${G}╠══════════════════════════════════════════════════════╣${N}"
  for line in "${step_log[@]}"; do
    echo -e "${G}║${N}${line}"
  done
  echo -e "${G}╠══════════════════════════════════════════════════════╣${N}"
  echo -e "${G}║${N}  ${G}✓${N} Выполнено: ${G}$done_count${N}   ${Y}⏭${N} Пропущено: ${Y}$skipped${N}   Всего: $step / $total"
  echo -e "${G}╚══════════════════════════════════════════════════════╝${N}"
  echo
  [[ $aborted -eq 0 ]]
}

execute_previewed_cycle() {
  local rc=0 total="${#RUN_CYCLE[@]}" plan_sha current_output
  journal_create_run "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED" || return 1
  journal_acquire_lease "$CURRENT_RUN_ID" || {
    echo -e "${R}Run уже выполняется другим launcher process.${N}"
    return 1
  }
  if [[ "$EXECUTION_TYPE" == CYCLE && "${EXECUTION_CYCLE_ID:-0}" -eq 1 &&
        -z "${PARENT_RUN_ID:-}" ]]; then
    plan_sha="$(awk 'NF {print $1; exit}' "$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")/plan.sha256")"
    if current_output="$(bash "$CURRENT_ARTIFACT_TOOL" begin-run "$(project_path)" \
      "$CURRENT_RUN_ID" "$plan_sha" 2>&1)"; then
      journal_append_event "$CURRENT_RUN_ID" current_artifact_run_started READY 0 PENDING \
        '' '' "$current_output"
    else
      printf '%s\n' "$current_output"
      journal_write_state "$CURRENT_RUN_ID" BLOCKED 0 "$total" UNVERIFIED \
        'current artifact generation'
      journal_append_event "$CURRENT_RUN_ID" current_artifact_run_blocked BLOCKED 0 UNVERIFIED \
        '' '' "$current_output"
      journal_release_lease "$CURRENT_RUN_ID"
      return 1
    fi
  fi
  if [[ -n "${PARENT_RUN_ID:-}" ]]; then
    journal_append_event "$PARENT_RUN_ID" retry_child_created INTERRUPTED 0 UNKNOWN '' '' "child run $CURRENT_RUN_ID"
  fi
  journal_write_state "$CURRENT_RUN_ID" READY 0 "$total" PENDING ''
  journal_append_event "$CURRENT_RUN_ID" execution_confirmed READY 0 PENDING '' '' 'user explicitly confirmed preview'
  journal_write_state "$CURRENT_RUN_ID" RUNNING 0 "$total" PENDING ''
  execute_cycle "$EXECUTION_TITLE" "$EXECUTION_CYCLE_ID" || rc=$?
  if [[ $rc -eq 0 ]]; then
    journal_write_state "$CURRENT_RUN_ID" COMPLETED "$total" "$total" \
      "${EXECUTION_LAST_STEP_STATUS:-ARTIFACT_VERIFIED}" ''
    journal_append_event "$CURRENT_RUN_ID" run_completed COMPLETED "$total" \
      "${EXECUTION_LAST_STEP_STATUS:-ARTIFACT_VERIFIED}" '' '' \
      'all planned steps satisfied their registered result verifiers'
  else
    journal_write_state "$CURRENT_RUN_ID" BLOCKED "${EXECUTION_LAST_STEP:-0}" "$total" \
      "${EXECUTION_LAST_STEP_STATUS:-UNKNOWN}" "${EXECUTION_LAST_ACTION:-}"
    journal_append_event "$CURRENT_RUN_ID" run_blocked BLOCKED \
      "${EXECUTION_LAST_STEP:-0}" "${EXECUTION_LAST_STEP_STATUS:-UNKNOWN}" \
      "${EXECUTION_LAST_AGENT:-}" "${EXECUTION_LAST_TASK:-}" \
      "${EXECUTION_LAST_REASON:-cycle exit code $rc}"
  fi
  journal_release_lease "$CURRENT_RUN_ID"
  return "$rc"
}

preview_and_execute_cycle() {
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview execute_previewed_cycle
}

# ─── Цикл 1 — Разработка ──────────────────────────────────────────────────────
# Аргумент $1: "standalone" (по умолчанию) — спросить проект; "chained" — PROJECT уже выбран
run_cycle1() {
  local mode="${1:-standalone}"
  header
  echo -e "${W}── Цикл 1 — Разработка ───────────────────────────────${N}"
  echo
  [[ "$mode" == "standalone" ]] && { pick_project || return; }
  [[ "$mode" != "chained" ]] && { offer_goal_profile_at_cycle1_entry || return; }
  require_product_ci_profile || return 1

  # выбор необязательных шагов
  configure_optional_steps

  # строим динамический массив: before + обязательные + after
  local -a RUN_CYCLE=()
  local -a RUN_OPTIONAL=()  # флаги: 1 = необязательный шаг

  for entry in "${OPTIONAL_BEFORE[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(1)
  done
  for entry in "${CYCLE1_AGENTS[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(0)
  done
  for entry in "${OPTIONAL_AFTER[@]}"; do
    RUN_CYCLE+=("$entry")
    RUN_OPTIONAL+=(1)
  done

  local mandatory_count=${#CYCLE1_AGENTS[@]}
  local optional_count=$(( ${#OPTIONAL_BEFORE[@]} + ${#OPTIONAL_AFTER[@]} ))
  local total=${#RUN_CYCLE[@]}

  echo
  echo -e "${C}Проект: ${W}$PROJECT${N}"
  echo -e "  Обязательных шагов: ${W}$mandatory_count${N}"
  if [[ $optional_count -gt 0 ]]; then
    echo -e "  Дополнительных шагов: ${G}$optional_count${N}"
    [[ ${#OPTIONAL_BEFORE[@]} -gt 0 ]] && echo -e "    До цикла:    ${G}${#OPTIONAL_BEFORE[@]}${N}"
    [[ ${#OPTIONAL_AFTER[@]}  -gt 0 ]] && echo -e "    После цикла: ${G}${#OPTIONAL_AFTER[@]}${N}"
  fi
  echo -e "  Итого шагов: ${W}$total${N}"
  echo
  echo -e "После общей проверки запуска на каждом шаге:"
  echo -e "  ${Y}Enter${N} — запустить задачу автоматически"
  echo -e "  ${Y}i${N}     — открыть интерактивный диалог с агентом"
  echo -e "  ${Y}s${N}     — пропустить шаг"
  echo -e "  ${Y}q${N}     — прервать цикл"
  echo
  EXECUTION_TYPE=CYCLE
  EXECUTION_SCOPE='ТОЛЬКО Cycle 1'
  EXECUTION_EXCLUDED='Cycle 2/3 — FROZEN / NOT READY'
  EXECUTION_TITLE='Цикл 1 — Разработка'
  EXECUTION_CYCLE_ID=1
  local rc=0
  preview_and_execute_cycle || rc=$?
  [[ "$mode" == "standalone" ]] && read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
  return "$rc"
}

# ─── Цикл 2 — Деплой ──────────────────────────────────────────────────────────
run_cycle2() {
  cycle23_frozen_notice
  return 1
}

# ─── Цикл 3 — Эксплуатация ────────────────────────────────────────────────────
run_cycle3() {
  cycle23_frozen_notice
  return 1
}

# ─── Режим цели (Cycle 1 → выбранные Cycle 2/3) ────────────────────────────────
run_goal_mode() {
  local mode="${1:-standalone}"
  echo 'Legacy goal mode is limited to supported Cycle 1; Cycle 2/3 are FROZEN / NOT READY.'
  run_cycle1 "$mode"
}

# ─── подменю выбора цикла ─────────────────────────────────────────────────────
menu_cycle_select() {
  header
  echo -e "${W}── Что хотите сделать? ───────────────────────────────${N}"
  echo
  echo -e "  ${Y}1)${N} ${G}🔧 Только Cycle 1${N} — разработка без запуска deploy/ops"
  echo -e "  ${Y}2)${N} Cycle 2/3 — ${Y}FROZEN / NOT READY${N} (только показать статус)"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери [1-2/b]:${N} ")" choice
  case "$choice" in
    1) run_cycle1 selected ;;
    2) render_cycle23_frozen_status ;;
    b|B) return ;;
    *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
  esac
}

# ─── создание проекта ─────────────────────────────────────────────────────────
menu_new_project() {
  header
  echo -e "${W}── Новый проект ──────────────────────────────────────${N}"
  echo
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    echo -e "${Y}Сейчас выбран режим одного проекта: ${W}$SINGLE_PROJECT${N}"
    echo -e "Чтобы создавать новые проекты, переключи настройки на каталог с несколькими проектами."
    echo
    read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
    return
  fi
  read -rp "$(echo -e "${W}Название проекта (Enter — назад):${N} ")" name
  if [[ -z "$name" ]]; then return; fi
  create_project "$name"
  echo
  echo -e "${C}Проект создан. Запустить интервью для заполнения входных данных? (s0-kickoff /new)${N}"
  read -rp "$(echo -e "${W}[Enter = да / n = пропустить]:${N} ")" run_kickoff
  if [[ "$run_kickoff" != "n" && "$run_kickoff" != "N" ]]; then
    run_agent "s0-kickoff" "$name" "/new $name"
  fi
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_kickoff() {
  header
  echo -e "${W}── Kickoff — Онбординг / Обновление проекта ─────────${N}"
  echo
  echo -e "  ${Y}1)${N} ${G}Новый проект${N} — провести интервью с нуля   ${C}(/new)${N}"
  echo -e "  ${Y}2)${N} ${C}Обновить существующий${N} — беклог, видение   ${C}(/refresh)${N}"
  echo -e "  ${Y}3)${N} Авто-определение режима                     ${C}(/start)${N}"
  echo -e "  ${Y}4)${N} Change Request / анализ влияния            ${C}(/cr)${N}"
  echo -e "  ${Y}b)${N} Назад"
  echo
  read -rp "$(echo -e "${W}Выбери [1-4/b]:${N} ")" choice
  [[ "$choice" == "b" || "$choice" == "B" ]] && return

  [[ -n "${PROJECT:-}" ]] || { pick_project || return; }

  local rc=0
  case "$choice" in
    1) run_agent "s0-kickoff" "$PROJECT" "/new $PROJECT" || rc=$? ;;
    2) run_agent "s0-kickoff" "$PROJECT" "/refresh $PROJECT" || rc=$? ;;
    3) run_agent "s0-kickoff" "$PROJECT" "/start $PROJECT" || rc=$? ;;
    4) run_agent "s0-kickoff" "$PROJECT" "/cr $PROJECT" || rc=$? ;;
    *) echo -e "${R}Неверный выбор${N}"; sleep 0.5; return ;;
  esac
  [[ $rc -eq 0 ]] && post_kickoff_menu
  return "$rc"
}

post_kickoff_menu() {
  local choice
  printf '%s\n' \
    '' 'KICKOFF ЗАВЕРШЁН. Что дальше?' \
    '  1) Подготовить запуск только Cycle 1' \
    '  2) Проверить входные данные проекта' \
    '  3) Вернуться в Project Console' \
    '  Cycle 2/3: FROZEN / NOT READY'
  read -r choice
  case "$choice" in
    1) run_cycle1 selected ;;
    2) menu_project_inputs_review ;;
    3|b|B|'') return 0 ;;
    *) return 1 ;;
  esac
}

# ─── валидация структуры ──────────────────────────────────────────────────────
execute_structure_dispatch() {
  local action="$1" name output rc=0
  shift
  [[ "$action" == validate || "$action" == fix ]] || return 1
  (( $# > 0 )) || return 1
  for name in "$@"; do
    valid_project_name "$name" || { echo -e "${R}BLOCKED: invalid Project name: $name${N}"; rc=1; continue; }
    if [[ ! -d "$PROJECTS/$name" || -L "$PROJECTS/$name" ]]; then
      echo -e "${R}BLOCKED: unsafe or missing Project directory: $name${N}"
      rc=1
      continue
    fi
    echo -e "${B}── $action: $name ──${N}"
    if [[ "$action" == validate ]]; then
      bash "$AGENTS/cycle1-dev/s0-validate/structure-check.sh" "$PROJECTS/$name" check || rc=1
    else
      if ! bash "$AGENTS/cycle1-dev/s0-validate/structure-check.sh" "$PROJECTS/$name" fix; then
        rc=1
      elif ! bash "$AGENTS/cycle1-dev/s0-validate/structure-check.sh" "$PROJECTS/$name" check; then
        echo -e "${R}BLOCKED: post-fix structure verification failed for $name.${N}"
        rc=1
      fi
    fi
  done
  return "$rc"
}

preview_structure_dispatch() {
  local action="$1" access name confirm
  shift
  [[ "$action" == validate ]] && access=read-only || access=write-missing-only
  echo -e "${W}Structure action preview${N}"
  echo -e "  Action: ${C}$action${N}"
  echo -e "  Access: ${C}$access${N}"
  echo -e "  Targets (${#}):"
  for name in "$@"; do echo "    - $name"; done
  echo '  Excluded: every other directory and all existing file contents'
  read -rp 'Выполнить exact plan? [y/N]: ' confirm
  [[ "$confirm" =~ ^[yY]$ ]] || return 1
  execute_structure_dispatch "$action" "$@"
}

menu_validate_project() {
  header
  echo -e "${W}── Валидация и починка структуры проекта ────────────${N}"
  echo
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    echo -e "  ${Y}1)${N} Проверить проект ${W}$SINGLE_PROJECT${N}       ${C}(/validate)${N}"
    echo -e "  ${Y}3)${N} Починить проект ${W}$SINGLE_PROJECT${N}        ${C}(/fix)${N}"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1/3/b]:${N} ")" choice
  else
    echo -e "  ${Y}1)${N} Проверить один проект       ${C}(/validate)${N}"
    echo -e "  ${Y}2)${N} Проверить все проекты       ${C}(/validate all)${N}"
    echo -e "  ${Y}3)${N} Починить один проект        ${C}(/fix)${N}"
    echo -e "  ${Y}4)${N} Починить все проекты        ${C}(/fix all)${N}"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-4/b]:${N} ")" choice
  fi

  case "$choice" in
    b|B) return ;;
    1|3)
      if [[ "$PROJECTS_MODE" == "single" ]]; then
        PROJECT="$SINGLE_PROJECT"
      else
        pick_project || return
      fi
      local action; [[ "$choice" == "1" ]] && action=validate || action=fix
      preview_structure_dispatch "$action" "$PROJECT"
      ;;
    2|4)
      [[ "$PROJECTS_MODE" == "single" ]] && { echo -e "${R}Неверный выбор${N}"; sleep 0.5; return; }
      local action name d
      local -a collection_projects=()
      [[ "$choice" == "2" ]] && action=validate || action=fix
      while IFS= read -r -d '' d; do
        name="$(basename "$d")"
        [[ "$name" == _* || "$name" == .* ]] && continue
        valid_project_name "$name" || continue
        is_recognized_sdlc_project "$d" || continue
        collection_projects+=("$name")
      done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
      if (( ${#collection_projects[@]} == 0 )); then
        echo -e "${Y}Нет распознанных SDLC Projects для $action.${N}"
        return
      fi
      preview_structure_dispatch "$action" "${collection_projects[@]}"
      ;;
    *)
      echo -e "${R}Неверный выбор${N}"; sleep 0.5; return
      ;;
  esac
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── список проектов ──────────────────────────────────────────────────────────
print_project_progress() {
  local d="$1" name="$2" stages_done=0 s bar=""
  for s in stage1-planning stage2-requirements stage3-design stage4-dev \
            stage5-testing; do
    [[ -n "$(ls -A "$d/$s/outputs" 2>/dev/null)" ]] && ((stages_done++))
  done
  for ((k=0; k<stages_done; k++)); do bar+="█"; done
  for ((k=stages_done; k<5; k++)); do bar+="░"; done
  echo -e "  ${W}$name${N}  ${C}$bar${N} $stages_done/5  ${Y}Cycle 2/3 FROZEN${N}"
}

menu_list_projects() {
  header
  echo -e "${W}── Проекты ───────────────────────────────────────────${N}"
  echo
  if [[ "$PROJECTS_MODE" == "single" ]]; then
    print_project_progress "$PROJECTS/$SINGLE_PROJECT" "$SINGLE_PROJECT"
    echo
    read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
    return
  fi

  local found=0
  while IFS= read -r -d '' d; do
    local name
    name=$(basename "$d")
    [[ "$name" == _* || "$name" == .* ]] && continue
    is_sdlc_project_dir "$d" || continue
    print_project_progress "$d" "$name"
    found=1
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
  [[ $found -eq 0 ]] && echo -e "  ${Y}Проектов пока нет${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

# ─── project-scoped Console actions ──────────────────────────────────────────
cycle1_one_agent_preflight() {
  local agent="$1" task="$2" gate output
  gate="$(cycle1_gate_before_entry "$agent" "$task" 2>/dev/null || true)"
  if [[ -n "$gate" ]]; then
    if output="$(run_cycle1_gate_validator "$gate" 2>&1)"; then
      printf '%s\n' "$output"
      journal_append_event "$CURRENT_RUN_ID" gate_pass RUNNING 1 GATE_PASS '' "Gate $gate" "$output"
    else
      printf '%s\n' "$output"
      journal_append_event "$CURRENT_RUN_ID" gate_blocked BLOCKED 1 GATE_BLOCKED '' "Gate $gate" 'One Agent preflight blocked'
      return 1
    fi
  fi
  if [[ "$agent:$task" == 's4-dev:/dev-report' ]] && ! require_cycle_tdd_red 1; then
    return 1
  fi
  if [[ "$agent:$task" == 's4-techlead:/review' ]]; then
    prepare_cycle1_techlead_evidence
  fi
}

cycle1_one_agent_postflight() {
  local agent="$1" task="$2" gate output
  if cycle1_software_dod_after_entry "$agent" "$task"; then
    run_cycle1_software_dod_validator || return 1
    journal_append_event "$CURRENT_RUN_ID" software_dod_auto_pass RUNNING 1 DOD_AUTO_PASS \
      "$agent" "$task" 'deterministic automated DoD subset exit code 0'
    run_cycle1_full_dod_validator || {
      journal_append_event "$CURRENT_RUN_ID" software_dod_blocked BLOCKED 1 DOD_BLOCKED \
        "$agent" "$task" 'full Software DoD approval FAIL/BLOCKED/UNVERIFIED'
      return 1
    }
    journal_append_event "$CURRENT_RUN_ID" software_dod_approved RUNNING 1 DOD_PASS \
      "$agent" "$task" 'independent Human Approval v1 covers DOD-1..DOD-11 and current review digests'
  fi
  gate="$(cycle1_gate_after_entry "$agent" "$task" 2>/dev/null || true)"
  if [[ -n "$gate" ]]; then
    if output="$(run_cycle1_gate_validator "$gate" 2>&1)"; then
      printf '%s\n' "$output"
      journal_append_event "$CURRENT_RUN_ID" gate_pass RUNNING 1 GATE_PASS '' "Gate $gate" "$output"
    else
      printf '%s\n' "$output"
      journal_append_event "$CURRENT_RUN_ID" gate_blocked BLOCKED 1 GATE_BLOCKED '' "Gate $gate" 'One Agent postflight blocked'
      return 1
    fi
  fi
}

execute_previewed_agent() {
  local rc=0 declared_before='UNMAPPED' release_manifest_before='' release_version=''
  local release_output current_manifest_sha tracker_before='' previous_access="${ACTIVE_AGENT_ACCESS:-}"
  local scope_verification_failed=0
  if release_notes_after_entry "$SINGLE_AGENT" "$SINGLE_TASK"; then
    release_version="${SINGLE_TASK#/release-notes }"
    release_manifest_before="$RELEASE_NOTES_MANIFEST_SHA"
  fi
  journal_create_run AGENT "$SINGLE_AGENT $SINGLE_TASK" 'другие primary Agents и Cycles' || return 1
  journal_acquire_lease "$CURRENT_RUN_ID" || return 1
  journal_write_state "$CURRENT_RUN_ID" RUNNING 1 1 RUNNING "$SINGLE_AGENT $SINGLE_TASK"
  if ! cycle1_one_agent_preflight "$SINGLE_AGENT" "$SINGLE_TASK"; then
    journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 GATE_BLOCKED "$SINGLE_AGENT $SINGLE_TASK"
    journal_release_lease "$CURRENT_RUN_ID"
    return 1
  fi
  if [[ "$SINGLE_ACCESS" == scoped-write ]] &&
     ! prepare_change_scope_step "$SINGLE_AGENT" "$SINGLE_TASK" 1; then
    journal_append_event "$CURRENT_RUN_ID" change_scope_blocked WAITING_USER 1 UNVERIFIED \
      "$SINGLE_AGENT" "$SINGLE_TASK" "${CHANGE_SCOPE_REASON:-approved Change Scope is required}"
    journal_write_state "$CURRENT_RUN_ID" WAITING_USER 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
    journal_release_lease "$CURRENT_RUN_ID"
    clear_active_change_scope
    return 1
  fi
  if [[ "$SINGLE_CAPABILITY" == mutating-declared-output ]] ||
     release_notes_after_entry "$SINGLE_AGENT" "$SINGLE_TASK"; then
    declared_before="$(declared_output_fingerprint "$SINGLE_AGENT" "$SINGLE_TASK" 2>/dev/null || printf 'UNMAPPED')"
  fi
  if tracker_special_command "$SINGLE_AGENT" "$SINGLE_TASK"; then
    tracker_before="$(project_snapshot_sha256)"
  fi
  if cycle1_completion_after_entry "$SINGLE_AGENT" "$SINGLE_TASK" &&
     ! prepare_cycle1_completion_context "$CURRENT_RUN_ID"; then
    journal_append_event "$CURRENT_RUN_ID" cycle1_completion_blocked BLOCKED 1 UNVERIFIED \
      "$SINGLE_AGENT" "$SINGLE_TASK" 'completion runtime context unavailable'
    journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
    journal_release_lease "$CURRENT_RUN_ID"
    clear_active_change_scope
    return 1
  fi
  ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[0]:-}"
  ACTIVE_AGENT_ACCESS="$SINGLE_ACCESS"
  run_agent "$SINGLE_AGENT" "$SINGLE_PROJECT_NAME" "$SINGLE_TASK" || rc=$?
  ACTIVE_EXECUTION_PROFILE=""
  ACTIVE_AGENT_ACCESS="$previous_access"
  clear_cycle1_completion_context
  if [[ "$SINGLE_ACCESS" == scoped-write ]] &&
     ! verify_change_scope_step "$SINGLE_AGENT" "$SINGLE_TASK" 1; then
    scope_verification_failed=1
  fi
  clear_active_change_scope
  if [[ $scope_verification_failed -eq 0 && $rc -eq 0 &&
        "$SINGLE_AGENT:$SINGLE_TASK" == "s4-qa-auto:/run-tests" ]]; then
    run_cycle_tdd_repair_loop 1 || rc=$?
  fi
  if [[ $scope_verification_failed -ne 0 ]]; then
    rc=1
    journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
  elif [[ $rc -eq 0 ]]; then
    journal_append_event "$CURRENT_RUN_ID" step_process_ok RUNNING 1 PROCESS_OK "$SINGLE_AGENT" "$SINGLE_TASK" 'runtime exit code 0'
    if [[ "$SINGLE_CAPABILITY" == read-only-no-output ]]; then
      journal_append_event "$CURRENT_RUN_ID" step_read_only_verified COMPLETED 1 READ_ONLY_VERIFIED \
        "$SINGLE_AGENT" "$SINGLE_TASK" 'capability-enforced read-only command completed'
      journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 READ_ONLY_VERIFIED ''
    elif tracker_special_command "$SINGLE_AGENT" "$SINGLE_TASK"; then
      if verify_tracker_special_command "$SINGLE_TASK" "$tracker_before"; then
        journal_append_event "$CURRENT_RUN_ID" tracker_artifact_verified COMPLETED 1 ARTIFACT_VERIFIED \
          "$SINGLE_AGENT" "${SINGLE_TASK%%$'\n'*}" "$TRACKER_VERIFICATION_REASON"
        journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 ARTIFACT_VERIFIED ''
      else
        rc=1
        journal_append_event "$CURRENT_RUN_ID" tracker_artifact_unverified BLOCKED 1 UNVERIFIED \
          "$SINGLE_AGENT" "${SINGLE_TASK%%$'\n'*}" "${TRACKER_VERIFICATION_REASON:-tracker postcondition failed}"
        journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT ${SINGLE_TASK%% *}"
      fi
    elif verify_declared_outputs "$SINGLE_AGENT" "$SINGLE_TASK" "$declared_before"; then
      journal_append_event "$CURRENT_RUN_ID" step_artifact_verified RUNNING 1 ARTIFACT_VERIFIED \
        "$SINGLE_AGENT" "$SINGLE_TASK" "$DECLARED_OUTPUT_REASON"
      if ! cycle1_one_agent_postflight "$SINGLE_AGENT" "$SINGLE_TASK"; then
        rc=1
        journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 GATE_BLOCKED "$SINGLE_AGENT $SINGLE_TASK"
      fi
      if [[ $rc -eq 0 ]] && release_notes_after_entry "$SINGLE_AGENT" "$SINGLE_TASK"; then
        current_manifest_sha="$(sha256sum "$(project_path)/tracking/completion/CYCLE1-completion-v2.yaml" | awk '{print $1}')"
        if [[ -z "$release_manifest_before" || "$current_manifest_sha" != "$release_manifest_before" ]]; then
          rc=1
          journal_append_event "$CURRENT_RUN_ID" release_notes_blocked BLOCKED 1 UNVERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" 'completion manifest changed during release-notes generation'
          journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
        elif release_output="$(run_release_notes_validator "$release_version" 2>&1)"; then
          printf '%s\n' "$release_output"
          journal_append_event "$CURRENT_RUN_ID" release_notes_verified COMPLETED 1 ARTIFACT_VERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" "$release_output"
          journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 ARTIFACT_VERIFIED ''
        else
          printf '%s\n' "$release_output"
          rc=1
          journal_append_event "$CURRENT_RUN_ID" release_notes_blocked BLOCKED 1 UNVERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" 'Release Notes v1 FAIL/BLOCKED/UNVERIFIED'
          journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
        fi
      elif [[ $rc -eq 0 ]] && cycle1_completion_after_entry "$SINGLE_AGENT" "$SINGLE_TASK"; then
        local completion_output
        if ! completion_output="$(run_cycle1_execution_proof_create 2>&1)"; then
          printf '%s\n' "$completion_output"
          rc=1
          journal_append_event "$CURRENT_RUN_ID" cycle1_completion_blocked BLOCKED 1 UNVERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" 'full Cycle 1 execution proof FAIL/BLOCKED/UNVERIFIED'
          journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
        elif completion_output="$(run_cycle1_completion_validator 2>&1)"; then
          printf '%s\n' "$completion_output"
          journal_append_event "$CURRENT_RUN_ID" cycle1_completion_pass COMPLETED 1 ARTIFACT_VERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" "$completion_output"
          journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 ARTIFACT_VERIFIED ''
        else
          printf '%s\n' "$completion_output"
          rc=1
          journal_append_event "$CURRENT_RUN_ID" cycle1_completion_blocked BLOCKED 1 UNVERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" 'Cycle 1 completion FAIL/BLOCKED/UNVERIFIED'
          journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
        fi
      elif [[ $rc -eq 0 ]]; then
        journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 ARTIFACT_VERIFIED ''
      fi
    else
      rc=1
      journal_append_event "$CURRENT_RUN_ID" step_artifact_unverified BLOCKED 1 UNVERIFIED "$SINGLE_AGENT" "$SINGLE_TASK" "$DECLARED_OUTPUT_REASON"
      journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "$SINGLE_AGENT $SINGLE_TASK"
    fi
  else
    journal_append_event "$CURRENT_RUN_ID" step_failed BLOCKED 1 FAILED "$SINGLE_AGENT" "$SINGLE_TASK" "runtime exit code $rc"
    journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 FAILED "$SINGLE_AGENT $SINGLE_TASK"
  fi
  journal_release_lease "$CURRENT_RUN_ID"
  return "$rc"
}

run_agent_with_preview() {
  SINGLE_AGENT="$1"
  SINGLE_PROJECT_NAME="$2"
  SINGLE_TASK="$3"
  RELEASE_NOTES_VERSION=''
  RELEASE_NOTES_SOURCE=''
  RELEASE_NOTES_MANIFEST_REF=''
  RELEASE_NOTES_MANIFEST_SHA=''
  RELEASE_NOTES_TARGET_REF=''
  runtime_validate_prompt "$SINGLE_TASK" || return 1
  SINGLE_CAPABILITY="$(command_capability "$SINGLE_AGENT" "$SINGLE_TASK" 2>/dev/null || true)"
  SINGLE_ACCESS="$(command_access "$SINGLE_AGENT" "$SINGLE_TASK" 2>/dev/null || true)"
  if [[ -z "$SINGLE_CAPABILITY" || -z "$SINGLE_ACCESS" ]]; then
    echo -e "${R}BLOCKED: command отсутствует в capability registry.${N}"
    return 1
  fi
  if [[ "$SINGLE_CAPABILITY" == orchestrated-special ]] &&
     ! release_notes_after_entry "$SINGLE_AGENT" "$SINGLE_TASK" &&
     ! tracker_special_command "$SINGLE_AGENT" "$SINGLE_TASK"; then
    echo -e "${R}BLOCKED: $SINGLE_AGENT ${SINGLE_TASK%% *} требует отдельный launcher workflow.${N}"
    return 1
  fi
  if release_notes_after_entry "$SINGLE_AGENT" "$SINGLE_TASK"; then
    prepare_release_notes_context "$SINGLE_TASK"
    local context_rc=$?
    [[ $context_rc -eq 2 ]] && return 0
    [[ $context_rc -eq 0 ]] || return "$context_rc"
  fi
  local -a RUN_CYCLE=("$SINGLE_AGENT:$SINGLE_TASK")
  local -a RUN_OPTIONAL=(0)
  render_execution_preview AGENT "$SINGLE_AGENT ${SINGLE_TASK:-interactive}" 'другие primary Agents и Cycles'
  confirm_execution_preview execute_previewed_agent
}

render_project_review_menu() {
  printf '%s\n' \
    'ПРОВЕРИТЬ PROJECT · READ-ONLY' \
    '  1 Весь Project' \
    '  2 Один Cycle' \
    '  3 Один Stage' \
    '  4 Один Agent и его artifacts' \
    '  5 AI routes и exact models' \
    '  6 Структуру нескольких Projects' \
    'Никакие файлы не будут изменены и workflow не будет запущен.'
}

render_project_repair_menu() {
  printf '%s\n' \
    'ИСПРАВИТЬ PROJECT · ТОЛЬКО ПОСЛЕ PREVIEW' \
    '  1 Весь Project' \
    '  2 Один Cycle' \
    '  3 Один Stage' \
    '  4 Один Agent и его artifacts' \
    '  5 Только структуру Project' \
    'Сначала будут показаны точный scope, исключения, AI и команда. Без подтверждения записи не будет.'
}

prepare_scoped_project_action() {
  local action="${1:-}" scope="${2:-}" value
  case "$action" in review|repair) ;; *) return 1 ;; esac
  case "$scope" in
    project)
      EXECUTION_SCOPE='весь выбранный Project'
      EXECUTION_EXCLUDED='другие Projects'
      ;;
    cycle:1)
      value="${scope#cycle:}"
      EXECUTION_SCOPE="только Cycle $value выбранного Project"
      EXECUTION_EXCLUDED='остальные Cycles и другие Projects'
      ;;
    stage:[0-5])
      value="${scope#stage:}"
      EXECUTION_SCOPE="только Stage $value выбранного Project"
      EXECUTION_EXCLUDED='остальные Stages и другие Projects'
      ;;
    agent:*)
      value="${scope#agent:}"
      [[ -n "$value" && -d "$(find_agent_dir "$value")" ]] || return 1
      case "$value" in s4-devops|s6-release|s6-sre) return 1 ;; esac
      EXECUTION_SCOPE="только Agent $value и связанные с ним artifacts"
      EXECUTION_EXCLUDED='другие Agents, Cycles и Projects'
      ;;
    structure)
      [[ "$action" == repair ]] || return 1
      EXECUTION_SCOPE='только структура каталогов выбранного Project'
      EXECUTION_EXCLUDED='содержимое существующих artifacts и другие Projects'
      ;;
    *) return 1 ;;
  esac
  SCOPED_ACTION="$action"
  SCOPED_ACTION_SCOPE="$scope"
  if [[ "$action" == review ]]; then
    SCOPED_ACTION_ACCESS=read-only
    EXECUTION_TYPE=REVIEW
  else
    SCOPED_ACTION_ACCESS=write
    EXECUTION_TYPE=REPAIR
  fi
  RUN_CYCLE=("s0-validate:/$action scope=$scope")
  RUN_OPTIONAL=(0)
}

project_snapshot_sha256() {
  local root="$(project_path)" file
  {
    while IFS= read -r -d '' file; do
      [[ ! -L "$file" ]] || continue
      printf '%s\t%s\n' "${file#"$root/"}" "$(sha256sum "$file" | awk '{print $1}')"
    done < <(find "$root" -type f -print0 2>/dev/null | sort -z)
  } | sha256sum | awk '{print $1}'
}

tracker_next_task_id() {
  local backlog="$(project_path)/tracking/backlog.md" next
  if [[ ! -e "$backlog" && ! -L "$backlog" ]]; then
    printf '%s\n' T-001
    return 0
  fi
  [[ -f "$backlog" && ! -L "$backlog" ]] || return 1
  next="$(awk -F'|' '
    function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
    /^\|/ {
      id=trim($2)
      if (id ~ /^T-[0-9]+$/) {
        number=id; sub(/^T-/, "", number)
        if ((number + 0) > maximum) maximum=number + 0
      }
    }
    END {print maximum + 1}
  ' "$backlog")" || return 1
  [[ "$next" =~ ^[1-9][0-9]*$ ]] || return 1
  printf 'T-%03d\n' "$next"
}

tracker_current_sprint_number() {
  local current="$(project_path)/tracking/current-sprint.md" number
  [[ -f "$current" && ! -L "$current" ]] || return 1
  number="$(awk -F: '$1 == "sprint" {value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); print value; exit}' "$current")"
  [[ "$number" =~ ^[1-9][0-9]*$ ]] || return 1
  printf '%s\n' "$number"
}

tracker_task_status_in_file() {
  local file="$1" task_id="$2"
  awk -F'|' -v wanted="$task_id" '
    function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
    /^\|/ {
      if (!status_col) {
        for (i=1; i<=NF; i++) if (trim($i) == "Статус" || trim($i) == "Status") status_col=i
      }
      if (trim($2) == wanted && status_col) {print trim($status_col); found++}
    }
    END {if (found != 1) exit 1}
  ' "$file"
}

tracker_task_occurrences_have_status() {
  local task_id="$1" expected="$2" minimum="$3" maximum="$4"
  local root="$(project_path)" file status rows sprint_number count=0
  local -a files=("$root/tracking/backlog.md" "$root/tracking/current-sprint.md")
  TRACKER_TASK_MATCHED_FILES=()
  if sprint_number="$(tracker_current_sprint_number 2>/dev/null)"; then
    files+=("$root/tracking/sprints/sprint-$(printf '%02d' "$sprint_number").md")
  fi
  for file in "${files[@]}"; do
    if [[ -L "$file" ]]; then
      return 1
    fi
    [[ -f "$file" ]] || continue
    rows="$(awk -F'|' -v wanted="$task_id" '
      function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
      /^\|/ && trim($2) == wanted {n++}
      END {print n+0}
    ' "$file")"
    (( rows == 0 )) && continue
    (( rows == 1 )) || return 1
    status="$(tracker_task_status_in_file "$file" "$task_id")" || return 1
    [[ "$status" == "$expected" ]] || return 1
    TRACKER_TASK_MATCHED_FILES+=("$file")
    count=$((count + 1))
  done
  (( count >= minimum && count <= maximum ))
}

verify_tracker_special_command() {
  local task="$1" before="$2" command="${1%% *}" root="$(project_path)"
  local after task_id sprint end sprint_file current reason backlog status count file expected_verifier
  TRACKER_VERIFICATION_REASON=''
  expected_verifier="$(tracker_special_expected_verifier s0-tracker "$task" 2>/dev/null || true)"
  if [[ -z "$expected_verifier" ||
        "$(command_result_verifier s0-tracker "$task" 2>/dev/null || true)" != "$expected_verifier" ]]; then
    TRACKER_VERIFICATION_REASON='tracker result verifier does not match capability registry'
    return 1
  fi
  after="$(project_snapshot_sha256)"
  if [[ -z "$before" || "$after" == "$before" ]]; then
    TRACKER_VERIFICATION_REASON='Project tracking state did not change'
    return 1
  fi
  case "$command" in
    /task-add)
      task_id="$(tracker_prompt_value "$task" expected-task 2>/dev/null || true)"
      backlog="$root/tracking/backlog.md"
      [[ "$task_id" =~ ^T-[0-9]+$ && -f "$backlog" && ! -L "$backlog" ]] || {
        TRACKER_VERIFICATION_REASON='expected task id or regular backlog is missing'; return 1;
      }
      status="$(tracker_task_status_in_file "$backlog" "$task_id" 2>/dev/null || true)"
      [[ "$status" == TODO ]] || {
        TRACKER_VERIFICATION_REASON="$task_id is not exactly one TODO backlog row"; return 1;
      }
      count="$(find "$root/tracking" -type f \
        \( -name 'backlog.md' -o -name 'current-sprint.md' -o -name 'sprint-*.md' \) \
        -exec awk -F'|' -v wanted="$task_id" '
          function trim(v) {gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v}
          /^\|/ && trim($2) == wanted {n++} END {print n+0}
        ' {} + 2>/dev/null | awk '{n += $1} END {print n+0}')"
      [[ "$count" == 1 ]] || {
        TRACKER_VERIFICATION_REASON="$task_id must exist only in backlog before sprint planning"; return 1;
      }
      TRACKER_VERIFICATION_REASON="tracker task-add verified: task=$task_id status=TODO scope=backlog"
      ;;
    /task-block)
      task_id="$(tracker_prompt_value "$task" task 2>/dev/null || true)"
      reason="${task#*$'\n'Blocker reason: }"
      reason="${reason%%$'\n'*}"
      [[ "$task_id" =~ ^T-[0-9]+$ && -n "$reason" && "$reason" != "$task" ]] || {
        TRACKER_VERIFICATION_REASON='exact task id and blocker reason are required'; return 1;
      }
      tracker_task_occurrences_have_status "$task_id" BLOCKED 1 3 || {
        TRACKER_VERIFICATION_REASON="$task_id is not BLOCKED in every canonical occurrence"; return 1;
      }
      status=0
      for file in "${TRACKER_TASK_MATCHED_FILES[@]}"; do
        if grep -Fq -- "$reason" "$file"; then
          status=1
        fi
      done
      [[ "$status" == 1 ]] || {
        TRACKER_VERIFICATION_REASON="$task_id blocker reason was not persisted"; return 1;
      }
      TRACKER_VERIFICATION_REASON="tracker task-block verified: task=$task_id status=BLOCKED"
      ;;
    /task-done)
      task_id="$(tracker_prompt_value "$task" task 2>/dev/null || true)"
      [[ "$task_id" =~ ^T-[0-9]+$ ]] || {
        TRACKER_VERIFICATION_REASON='exact task id is required'; return 1;
      }
      bash "$AGENTS/cycle1-dev/s0-validate/task-dod-check.sh" "$root" "$task_id" >/dev/null || {
        TRACKER_VERIFICATION_REASON="$task_id DoD is not VERIFIED"; return 1;
      }
      tracker_task_occurrences_have_status "$task_id" DONE 3 3 || {
        TRACKER_VERIFICATION_REASON="$task_id DONE status is not synchronized"; return 1;
      }
      TRACKER_VERIFICATION_REASON="tracker task-done verified: task=$task_id status=DONE files=3"
      ;;
    /sprint-init)
      sprint="$(tracker_prompt_value "$task" sprint 2>/dev/null || true)"
      end="$(tracker_prompt_value "$task" end 2>/dev/null || true)"
      [[ "$sprint" =~ ^[1-9][0-9]*$ && "$end" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
        TRACKER_VERIFICATION_REASON='exact sprint number and end date are required'; return 1;
      }
      sprint_file="$root/tracking/sprints/sprint-$(printf '%02d' "$sprint").md"
      current="$root/tracking/current-sprint.md"
      for file in "$sprint_file" "$current" "$root/tracking/backlog.md" \
        "$root/tracking/dor-violations.md" "$root/tracking/tech-debt.md" \
        "$root/tracking/known-issues.md" "$root/tracking/task-dod-v1.tsv"; do
        [[ -f "$file" && ! -L "$file" ]] || {
          TRACKER_VERIFICATION_REASON="missing/non-regular tracker artifact: ${file#$root/}"; return 1;
        }
      done
      grep -Eq "^sprint:[[:space:]]*$sprint[[:space:]]*$" "$sprint_file" &&
        grep -Eq '^status:[[:space:]]*ACTIVE[[:space:]]*$' "$sprint_file" &&
        grep -Eq "^sprint:[[:space:]]*$sprint[[:space:]]*$" "$current" &&
        grep -Eq '^status:[[:space:]]*ACTIVE[[:space:]]*$' "$current" || {
          TRACKER_VERIFICATION_REASON="sprint $sprint is not the exact ACTIVE sprint"; return 1;
        }
      bash "$AGENTS/cycle1-dev/s0-validate/tech-debt-check.sh" "$root" sprint-init "$sprint" >/dev/null || {
        TRACKER_VERIFICATION_REASON="sprint $sprint Tech Debt materialization is not verified"; return 1;
      }
      TRACKER_VERIFICATION_REASON="tracker sprint-init verified: sprint=$sprint end=$end status=ACTIVE"
      ;;
    /sprint-close)
      sprint="$(tracker_prompt_value "$task" sprint 2>/dev/null || true)"
      [[ "$sprint" =~ ^[1-9][0-9]*$ ]] || {
        TRACKER_VERIFICATION_REASON='exact sprint number is required'; return 1;
      }
      sprint_file="$root/tracking/sprints/sprint-$(printf '%02d' "$sprint").md"
      current="$root/tracking/current-sprint.md"
      [[ -f "$sprint_file" && ! -L "$sprint_file" && -f "$current" && ! -L "$current" ]] || {
        TRACKER_VERIFICATION_REASON='sprint/current artifact missing or non-regular'; return 1;
      }
      grep -Eq '^status:[[:space:]]*CLOSED[[:space:]]*$' "$sprint_file" || {
        TRACKER_VERIFICATION_REASON="sprint $sprint is not CLOSED"; return 1;
      }
      ! grep -Eq '^status:[[:space:]]*ACTIVE[[:space:]]*$' "$current" || {
        TRACKER_VERIFICATION_REASON='current-sprint still declares an ACTIVE sprint'; return 1;
      }
      bash "$AGENTS/cycle1-dev/s0-validate/tracker-sprint-close-check.sh" "$root" "$sprint" >/dev/null || {
        TRACKER_VERIFICATION_REASON="sprint $sprint close invariants are not verified"; return 1;
      }
      TRACKER_VERIFICATION_REASON="tracker sprint-close verified: sprint=$sprint status=CLOSED"
      ;;
    *) TRACKER_VERIFICATION_REASON='unsupported tracker command'; return 1 ;;
  esac
}

write_review_findings() {
  local output="$1" target="$2" run_id="$3" scope="$4" snapshot="$5"
  local line marker id severity ref contract repair_scope summary extra count=0 clean=0 findings=0
  local rows tmp digest_file
  rows="$(mktemp "${target}.rows.XXXXXX")" || return 1
  while IFS= read -r line; do
    [[ "$line" == REVIEW_FINDING$'\t'* ]] || continue
    IFS=$'\t' read -r marker id severity ref contract repair_scope summary extra <<< "$line"
    [[ "$marker" == REVIEW_FINDING && -z "${extra:-}" && -n "${summary:-}" ]] || { rm -f "$rows"; return 1; }
    [[ "$id" == CLEAN || "$id" =~ ^FND-[A-Z0-9._-]+$ ]] || { rm -f "$rows"; return 1; }
    [[ "$severity" =~ ^(INFO|LOW|MEDIUM|HIGH|CRITICAL)$ ]] || { rm -f "$rows"; return 1; }
    [[ "$ref" == none || "$ref" =~ ^[A-Za-z0-9._/-]+$ ]] || { rm -f "$rows"; return 1; }
    [[ "$contract" == none || "$contract" =~ ^[A-Za-z0-9._/-]+$ ]] || { rm -f "$rows"; return 1; }
    [[ "$repair_scope" =~ ^(structure|project|cycle:1|stage:[0-5]|agent:[A-Za-z0-9._-]+)$ ]] || { rm -f "$rows"; return 1; }
    if grep -Eiq '(AKIA[0-9A-Z]{8,}|gh[pousr]_[A-Za-z0-9]+|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{8,}|password=|token=|secret=|/home/[^/]+/)' <<< "$line"; then
      rm -f "$rows"; return 1
    fi
    if [[ "$id" == CLEAN ]]; then
      [[ "$severity:$ref:$contract:$repair_scope" == "INFO:none:none:$scope" ]] || { rm -f "$rows"; return 1; }
      clean=$((clean + 1))
    else
      findings=$((findings + 1))
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$severity" "$ref" "$contract" "$repair_scope" "$summary" >> "$rows"
    count=$((count + 1))
  done <<< "$output"
  (( count > 0 )) || { rm -f "$rows"; return 1; }
  (( (clean == 1 && findings == 0) || (clean == 0 && findings > 0) )) || { rm -f "$rows"; return 1; }
  tmp="$(mktemp "${target}.tmp.XXXXXX")" || { rm -f "$rows"; return 1; }
  {
    printf 'schema_version: 1\nrun_id: %s\nproject: %s\nscope: %s\nproject_snapshot_sha256: %s\nverdict: %s\nfinding_count: %s\n' \
      "$run_id" "$PROJECT" "$scope" "$snapshot" "$([[ $findings -gt 0 ]] && printf FINDINGS || printf CLEAN)" "$findings"
    printf 'finding_id\tseverity\ttarget_ref\tcontract_id\trepair_scope\tsummary\n'
    cat "$rows"
  } > "$tmp"
  rm -f "$rows"
  mv "$tmp" "$target"
  chmod 0444 "$target"
  digest_file="${target%.tsv}.sha256"
  sha256sum "$target" | awk '{print $1}' > "$digest_file"
  chmod 0444 "$digest_file"
}

review_findings_valid() {
  local file="$1" scope="$2" digest_file expected actual
  digest_file="${file%.tsv}.sha256"
  [[ -f "$file" && ! -L "$file" && -f "$digest_file" && ! -L "$digest_file" ]] || return 1
  expected="$(awk 'NF {print $1; exit}' "$digest_file")"
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$expected" =~ ^[0-9a-f]{64}$ && "$actual" == "$expected" ]] || return 1
  grep -Fqx 'schema_version: 1' "$file" || return 1
  grep -Fqx "project: $PROJECT" "$file" || return 1
  grep -Fqx "scope: $scope" "$file" || return 1
  grep -Eq '^verdict: (CLEAN|FINDINGS)$' "$file" || return 1
  grep -Eq '^finding_count: [0-9]+$' "$file" || return 1
  [[ "$(sed -n '8p' "$file")" == $'finding_id\tseverity\ttarget_ref\tcontract_id\trepair_scope\tsummary' ]]
}

latest_review_findings() {
  local scope="$1" root dir file
  root="$(journal_root "$PROJECT")/runs"
  while IFS= read -r dir; do
    file="$dir/review-findings.tsv"
    if review_findings_valid "$file" "$scope"; then
      printf '%s\n' "$file"
      return 0
    fi
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -r)
  return 1
}

run_scoped_review() {
  local previous_access="${ACTIVE_AGENT_ACCESS:-}" rc=0 output before after dir findings
  journal_create_run REVIEW "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED" || return 1
  journal_acquire_lease "$CURRENT_RUN_ID" || return 1
  journal_write_state "$CURRENT_RUN_ID" RUNNING 1 1 RUNNING "s0-validate /review scope=$SCOPED_ACTION_SCOPE"
  before="$(project_snapshot_sha256)"
  ACTIVE_AGENT_ACCESS=read-only
  ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[0]:-}"
  if [[ -z "$ACTIVE_EXECUTION_PROFILE" ]]; then rc=1
  else output="$(run_agent s0-validate "$PROJECT" "/review scope=$SCOPED_ACTION_SCOPE" 2>&1)" || rc=$?
  fi
  ACTIVE_EXECUTION_PROFILE=''
  ACTIVE_AGENT_ACCESS="$previous_access"
  printf '%s\n' "${output:-}"
  after="$(project_snapshot_sha256)"
  dir="$(journal_run_dir "$PROJECT" "$CURRENT_RUN_ID")"
  findings="$dir/review-findings.tsv"
  if [[ $rc -eq 0 && "$before" == "$after" ]] &&
     write_review_findings "$output" "$findings" "$CURRENT_RUN_ID" "$SCOPED_ACTION_SCOPE" "$before"; then
    local digest verdict count
    digest="$(awk 'NF {print $1; exit}' "${findings%.tsv}.sha256")"
    verdict="$(awk -F': ' '$1=="verdict" {print $2; exit}' "$findings")"
    count="$(awk -F': ' '$1=="finding_count" {print $2; exit}' "$findings")"
    journal_append_event "$CURRENT_RUN_ID" review_findings_verified COMPLETED 1 READ_ONLY_VERIFIED \
      s0-validate "/review scope=$SCOPED_ACTION_SCOPE" "verdict=$verdict findings=$count sha256=$digest"
    journal_write_state "$CURRENT_RUN_ID" COMPLETED 1 1 READ_ONLY_VERIFIED ''
    LATEST_REVIEW_RUN_ID="$CURRENT_RUN_ID"
  else
    rc=1
    journal_append_event "$CURRENT_RUN_ID" review_findings_unverified BLOCKED 1 UNVERIFIED \
      s0-validate "/review scope=$SCOPED_ACTION_SCOPE" 'invalid findings envelope or Project changed during read-only review'
    journal_write_state "$CURRENT_RUN_ID" BLOCKED 1 1 UNVERIFIED "s0-validate /review scope=$SCOPED_ACTION_SCOPE"
  fi
  journal_release_lease "$CURRENT_RUN_ID"
  return "$rc"
}

run_scoped_repair() {
  local previous_access="${ACTIVE_AGENT_ACCESS:-}" review_file review_dir review_run review_snapshot
  local review_digest before after verify_after rc=0 output verify_output repair_run repair_dir verification verdict findings_payload
  review_file="$(latest_review_findings "$SCOPED_ACTION_SCOPE")" || {
    echo -e "${R}BLOCKED: сначала нужен verified Review того же exact scope.${N}"; return 1;
  }
  review_dir="$(dirname "$review_file")"; review_run="$(basename "$review_dir")"
  verdict="$(awk -F': ' '$1=="verdict" {print $2; exit}' "$review_file")"
  [[ "$verdict" == FINDINGS ]] || { echo -e "${Y}Repair не нужен: latest verified Review имеет CLEAN verdict.${N}"; return 1; }
  review_snapshot="$(awk -F': ' '$1=="project_snapshot_sha256" {print $2; exit}' "$review_file")"
  [[ "$(project_snapshot_sha256)" == "$review_snapshot" ]] || {
    echo -e "${R}BLOCKED: Project изменился после Review; сначала повтори Review.${N}"; return 1;
  }
  review_digest="$(awk 'NF {print $1; exit}' "${review_file%.tsv}.sha256")"
  findings_payload="$(sed -n '8,$p' "$review_file")"
  PARENT_RUN_ID="$review_run"
  journal_create_run REPAIR "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED" || { PARENT_RUN_ID=''; return 1; }
  repair_run="$CURRENT_RUN_ID"; repair_dir="$(journal_run_dir "$PROJECT" "$repair_run")"
  journal_append_event "$review_run" repair_child_created COMPLETED 1 READ_ONLY_VERIFIED \
    s0-validate "/repair scope=$SCOPED_ACTION_SCOPE" "child=$repair_run findings_sha256=$review_digest"
  journal_acquire_lease "$repair_run" || { PARENT_RUN_ID=''; return 1; }
  journal_write_state "$repair_run" RUNNING 1 1 RUNNING "s0-validate /repair scope=$SCOPED_ACTION_SCOPE"
  before="$(project_snapshot_sha256)"
  ACTIVE_AGENT_ACCESS=write
  ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[0]:-}"
  if [[ -z "$ACTIVE_EXECUTION_PROFILE" ]]; then rc=1
  else
    output="$(run_agent s0-validate "$PROJECT" "/repair scope=$SCOPED_ACTION_SCOPE parent_review=$review_run findings_sha256=$review_digest"$'\n\n'"VERIFIED REVIEW FINDINGS TSV:"$'\n'"$findings_payload" 2>&1)" || rc=$?
  fi
  ACTIVE_EXECUTION_PROFILE=''
  ACTIVE_AGENT_ACCESS="$previous_access"
  printf '%s\n' "${output:-}"
  after="$(project_snapshot_sha256)"
  if [[ $rc -eq 0 && "$after" != "$before" ]]; then
    ACTIVE_AGENT_ACCESS=read-only
    ACTIVE_EXECUTION_PROFILE="${EXECUTION_STEP_PROFILES[0]:-}"
    verify_output="$(run_agent s0-validate "$PROJECT" "/review scope=$SCOPED_ACTION_SCOPE verification_of=$repair_run" 2>&1)" || rc=$?
    ACTIVE_EXECUTION_PROFILE=''
    ACTIVE_AGENT_ACCESS="$previous_access"
    printf '%s\n' "${verify_output:-}"
    verify_after="$(project_snapshot_sha256)"
    [[ "$verify_after" == "$after" ]] || rc=1
  else
    rc=1
  fi
  verification="$repair_dir/repair-verification-findings.tsv"
  if [[ $rc -eq 0 ]] && write_review_findings "$verify_output" "$verification" "$repair_run" \
      "$SCOPED_ACTION_SCOPE" "$after" && grep -Fqx 'verdict: CLEAN' "$verification"; then
    journal_append_event "$repair_run" repair_verified COMPLETED 1 ARTIFACT_VERIFIED \
      s0-validate "/repair scope=$SCOPED_ACTION_SCOPE" "parent=$review_run findings_sha256=$review_digest re_review=CLEAN"
    journal_write_state "$repair_run" COMPLETED 1 1 ARTIFACT_VERIFIED ''
  else
    rc=1
    journal_append_event "$repair_run" repair_unverified BLOCKED 1 UNVERIFIED \
      s0-validate "/repair scope=$SCOPED_ACTION_SCOPE" 'no changed Project snapshot or re-review is not CLEAN'
    journal_write_state "$repair_run" BLOCKED 1 1 UNVERIFIED "s0-validate /repair scope=$SCOPED_ACTION_SCOPE"
  fi
  journal_release_lease "$repair_run"
  PARENT_RUN_ID=''
  return "$rc"
}

run_scoped_project_action() {
  case "$SCOPED_ACTION" in
    review) run_scoped_review ;;
    repair) run_scoped_repair ;;
    *) return 1 ;;
  esac
}

select_scoped_project_action() {
  local action="$1" choice="$2" value scope
  case "$choice" in
    1) scope=project ;;
    2)
      read -rp 'Cycle [только 1; Cycle 2/3 frozen]: ' value
      scope="cycle:$value"
      ;;
    3)
      read -rp 'Stage [0-5]: ' value
      scope="stage:$value"
      ;;
    4)
      read -rp 'Точный Agent id (например s4-dev): ' value
      scope="agent:$value"
      ;;
    5) [[ "$action" == repair ]] || return 1; scope=structure ;;
    *) return 1 ;;
  esac
  prepare_scoped_project_action "$action" "$scope"
}

menu_project_inputs_review() {
  header
  echo -e "${W}── Входные данные проекта (только чтение) ─────────────${N}"
  echo -e "  Project: ${C}$PROJECT${N}"
  echo -e "  Path:    ${C}$(project_path)${N}"
  echo
  find "$(project_path)" -path '*/inputs/*' -type f -print 2>/dev/null | sort | sed 's/^/  /'
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_project_overview() {
  header
  echo -e "${W}── Обзор проекта (без изменений) ────────────────────${N}"
  print_project_progress "$(project_path)" "$PROJECT"
  local unfinished
  unfinished="$(journal_latest_unfinished "$PROJECT" 2>/dev/null || true)"
  echo -e "  Незавершённый run: ${C}${unfinished:-нет}${N}"
  echo -e "  Supported scope:   ${C}Cycle 1 / Stage 0-5${N}"
  echo -e "  Cycle 2/3:         ${Y}FROZEN / NOT READY${N}"
  echo
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_project_review() {
  header
  render_project_review_menu
  echo
  read -rp 'Выбери [1-6/b]: ' review_choice
  [[ "$review_choice" =~ ^[bB]$ ]] && return
  case "$review_choice" in
    5)
      echo -e "  Policy:  ${C}$SDLC_RUNTIME_ROUTING${N}"
      echo -e "  Base:    ${C}$BASE_PROFILE${N}"
      echo -e "  Routes:  ${C}$ROUTING_FILE${N}"
      [[ -f "$ROUTING_FILE" ]] && sed 's/^/  /' "$ROUTING_FILE"
      read -rp 'Нажми Enter...' _
      return
      ;;
    6)
      menu_list_projects
      return
      ;;
  esac
  if ! select_scoped_project_action review "$review_choice"; then
    echo -e "${R}Некорректный scope Review.${N}"
    return 1
  fi
  echo
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview run_scoped_project_action || true
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

menu_project_repair() {
  header
  render_project_repair_menu
  echo
  local repair_choice
  read -rp 'Выбери [1-5/b]: ' repair_choice
  [[ "$repair_choice" =~ ^[bB]$ ]] && return
  if ! select_scoped_project_action repair "$repair_choice"; then
    echo -e "${R}Некорректный scope Repair.${N}"
    return 1
  fi
  echo
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview run_scoped_project_action || true
  read -rp "$(echo -e "${W}Нажми Enter для возврата...${N} ")" _
}

configure_cycle_runtime_matrix() {
  local entry supervisor_profile
  supervisor_profile="$(current_profile)"
  SDLC_RUNTIME_ROUTING=per-agent
  export SDLC_RUNTIME_ROUTING
  echo
  echo -e "${W}Primary profile для поддерживаемого Cycle 1:${N}"
  select_step_profile || { apply_profile "$supervisor_profile" >/dev/null 2>&1 || true; return 1; }
  for entry in "${CYCLE1_AGENTS[@]}"; do
    write_routing_entry "agent:${entry%%:*}" "$SELECTED_PROFILE"
  done
  apply_profile "$supervisor_profile"
}

configure_agent_runtime_override() {
  local agent supervisor_profile
  supervisor_profile="$(current_profile)"
  read -rp 'Agent id для override (например s4-dev): ' agent
  [[ "$agent" =~ ^[A-Za-z0-9._-]+$ && -d "$(find_agent_dir "$agent")" ]] || {
    echo -e "${R}Неизвестный Agent id: $agent${N}"
    return 1
  }
  case "$agent" in
    s4-devops|s6-release|s6-sre) cycle23_frozen_notice; return 1 ;;
  esac
  select_step_profile || { apply_profile "$supervisor_profile" >/dev/null 2>&1 || true; return 1; }
  write_routing_entry "agent:$agent" "$SELECTED_PROFILE"
  apply_profile "$supervisor_profile"
}

configure_exact_agent_matrix() {
  local choice
  echo -e "${C}Сначала каждый Agent Cycle 1 получает явный профиль; затем можно добавить overrides.${N}"
  configure_cycle_runtime_matrix || return 1
  while true; do
    read -rp 'Добавить override для отдельного Agent? [y/N]: ' choice
    case "$choice" in
      y|Y) configure_agent_runtime_override || return 1 ;;
      n|N|'') return 0 ;;
      *) echo -e "${R}Ответь y или n${N}" ;;
    esac
  done
}

complete_pending_first_run_ai_setup() {
  case "${PENDING_FIRST_RUN_AI_SETUP:-}" in
    '') return 0 ;;
    cycle)
      echo -e "${W}Завершаем project-specific routing по Cycle для $PROJECT.${N}"
      configure_cycle_runtime_matrix || return 1
      ;;
    matrix)
      echo -e "${W}Завершаем точную project-specific Stage/Agent matrix для $PROJECT.${N}"
      configure_exact_agent_matrix || return 1
      ;;
    *) return 1 ;;
  esac
  save_project_ai_config "$BASE_PROFILE" "$SDLC_RUNTIME_ROUTING" || return 1
  PENDING_FIRST_RUN_AI_SETUP=''
}

menu_ai_assignment() {
  header
  echo -e "${W}── Primary routing и worker status ────────────────${N}"
  echo "Здесь можно изменить AI-настройку выбранного проекта. Она определяет"
  echo "исполнителя каждого основного этапа; workers остаются опциональными и bounded read-only,"
  echo "но не меняет порядок SDLC и сама ничего не запускает."
  echo "Перед реальным запуском итоговые назначения будут показаны в Preview."
  echo "Для Local обязательны host, provider и точный model id; fallback выключен."
  echo
  echo -e "${W}Основные исполнители:${N}"
  echo -e "  ${Y}1)${N} Одна AI-модель для всего проекта"
  echo -e "  ${Y}2)${N} Своя AI-модель для каждого Agent Cycle 1"
  echo -e "  ${Y}3)${N} Исключения для отдельных ролей"
  echo -e "  ${Y}4)${N} Спрашивать при подготовке каждого запуска"
  echo -e "${W}Workers:${N} ${SDLC_SUBAGENTS:-off}/${SDLC_SUBAGENT_MAX:-2}; exact handoff, fallback OFF"
  echo -e "  ${Y}5)${N} Настроить worker policy/profile"
  echo -e "  ${Y}6)${N} Показать текущие primary назначения и worker status"
  echo -e "  ${Y}b)${N} Назад"
  read -rp "$(echo -e "${W}Выбери:${N} ")" choice
  case "$choice" in
    1)
      choose_runtime || return
      BASE_PROFILE="$(current_profile)"
      SDLC_RUNTIME_ROUTING=single
      save_project_ai_config "$BASE_PROFILE" single
      ;;
    2)
      configure_cycle_runtime_matrix && save_project_ai_config "$BASE_PROFILE" per-agent
      ;;
    3)
      configure_exact_agent_matrix && save_project_ai_config "$BASE_PROFILE" per-agent
      ;;
    4)
      SDLC_RUNTIME_ROUTING=ask
      save_project_ai_config "$BASE_PROFILE" ask
      ;;
    5)
      configure_cross_runtime_subagents && save_project_ai_config "$BASE_PROFILE" "$SDLC_RUNTIME_ROUTING"
      ;;
    6) show_runtime_routing; render_subagent_execution_summary; read -rp 'Нажми Enter...' _ ;;
    b|B|'') return ;;
  esac
}

menu_tracker() {
  local choice task_id reason title type owner points depends description goal start end tasks sprint expected
  header
  echo -e "${W}── Tracker выбранного проекта ───────────────────────${N}"
  printf '%s\n' \
    '  1) Sprint status (read-only)' \
    '  2) Backlog (read-only)' \
    '  3) Add task' \
    '  4) Block task' \
    '  5) Complete task (verified DoD required)' \
    '  6) Initialize sprint' \
    '  7) Close current sprint' \
    '  8) Cycle report' \
    '  b) Назад'
  read -rp 'Выбери [1-8/b]: ' choice
  case "$choice" in
    1) run_agent_with_preview s0-tracker "$PROJECT" /sprint-status ;;
    2) run_agent_with_preview s0-tracker "$PROJECT" /backlog ;;
    3)
      expected="$(tracker_next_task_id)" || return 1
      read -rp 'Название задачи: ' title
      read -rp 'Тип (feature|bug|chore|SDLC-artifact|research): ' type
      read -rp 'Agent/исполнитель (или team): ' owner
      read -rp 'Story Points (1|2|3|5|8|13): ' points
      read -rp 'Зависит от (task ID или none): ' depends
      read -rp 'Описание (одна строка, optional): ' description
      [[ -n "$title" && "$type" =~ ^(feature|bug|chore|SDLC-artifact|research)$ &&
         -n "$owner" && "$points" =~ ^(1|2|3|5|8|13)$ &&
         ( "$depends" == none || "$depends" =~ ^T-[0-9]+$ ) ]] || {
        echo -e "${R}BLOCKED: task fields are incomplete or invalid.${N}"; return 1;
      }
      run_agent_with_preview s0-tracker "$PROJECT" "/task-add expected-task=$expected"$'\n'\
"Title: $title"$'\n'"Type: $type"$'\n'"Owner: $owner"$'\n'"SP: $points"$'\n'\
"Depends on: $depends"$'\n'"Description: ${description:-none}"
      ;;
    4)
      read -rp 'Exact task ID (T-NNN): ' task_id
      read -rp 'Конкретная причина blocker: ' reason
      [[ "$task_id" =~ ^T-[0-9]+$ && -n "$reason" ]] || {
        echo -e "${R}BLOCKED: exact task ID and blocker reason are required.${N}"; return 1;
      }
      run_agent_with_preview s0-tracker "$PROJECT" "/task-block task=$task_id"$'\n'"Blocker reason: $reason"
      ;;
    5)
      read -rp 'Exact task ID (T-NNN): ' task_id
      [[ "$task_id" =~ ^T-[0-9]+$ ]] || {
        echo -e "${R}BLOCKED: invalid task ID.${N}"; return 1;
      }
      run_agent_with_preview s0-tracker "$PROJECT" "/task-done task=$task_id"
      ;;
    6)
      sprint="$(find "$(project_path)/tracking/sprints" -maxdepth 1 -type f -name 'sprint-*.md' 2>/dev/null |
        sed -n 's#^.*/sprint-\([0-9][0-9]*\)\.md$#\1#p' | sort -n | tail -n 1)"
      sprint=$((10#${sprint:-0} + 1))
      read -rp 'Цель спринта (одна строка): ' goal
      read -rp 'Дата начала (YYYY-MM-DD): ' start
      read -rp 'Дата окончания (YYYY-MM-DD): ' end
      read -rp 'Task IDs через запятую: ' tasks
      [[ -n "$goal" && "$start" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ &&
         "$end" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && -n "$tasks" ]] || {
        echo -e "${R}BLOCKED: sprint goal, exact dates and task IDs are required.${N}"; return 1;
      }
      run_agent_with_preview s0-tracker "$PROJECT" "/sprint-init sprint=$sprint start=$start end=$end"$'\n'\
"Sprint goal: $goal"$'\n'"Selected tasks: $tasks"$'\n'"Required sprint status: ACTIVE"
      ;;
    7)
      sprint="$(tracker_current_sprint_number)" || {
        echo -e "${R}BLOCKED: active sprint number is unavailable.${N}"; return 1;
      }
      run_agent_with_preview s0-tracker "$PROJECT" "/sprint-close sprint=$sprint"
      ;;
    8) run_agent_with_preview s0-tracker "$PROJECT" /report ;;
    b|B|'') return ;;
    *) return 1 ;;
  esac
}

menu_memory() {
  local choice project_dir provider endpoint credential namespace read_approval collections retention
  local proposal agent command approval
  project_dir="$(project_path)"
  header
  echo -e "${W}── Подключаемая память выбранного проекта ───────────${N}"
  printf '%s\n' \
    '  1) Status / profile validation' \
    '  2) Configure provider (explicit persistent Project grant)' \
    '  3) Provider doctor' \
    '  4) Validate proposal (no write)' \
    '  5) Apply proposal (Preview + Human Approval + read-back)' \
    '  6) Disable memory profile (provider data is retained)' \
    '  b) Назад'
  read -rp 'Выбери [1-6/b]: ' choice
  case "$choice" in
    1) "$MEMORY_BROKER" status --project "$project_dir" ;;
    2)
      read -rp 'Provider [files-v1|qdrant-v1|mem0-oss-v1|mem0-platform-v1]: ' provider
      read -rp 'Endpoint (existing directory or URL): ' endpoint
      read -rp 'Credential ref [none|pass:entry]: ' credential
      read -rp 'Project namespace: ' namespace
      read -rp 'Read approval [always|profile]: ' read_approval
      read -rp 'Collections [planning,defects,architecture]: ' collections
      read -rp 'Retention days [3650]: ' retention
      [[ -n "$credential" ]] || credential=none
      [[ -n "$read_approval" ]] || read_approval=always
      [[ -n "$retention" ]] || retention=3650
      echo -e "${Y}Эта команда создаст/заменит только tracking/memory/profile-v1.yaml.${N}"
      read -rp 'Type ENABLE MEMORY: ' approval
      [[ "$approval" == 'ENABLE MEMORY' ]] || { echo -e "${R}Отменено${N}"; return 1; }
      "$MEMORY_BROKER" configure --project "$project_dir" --provider "$provider" \
        --endpoint "$endpoint" --credential-ref "$credential" --namespace "$namespace" \
        --read-approval "$read_approval" --collections "$collections" --retention-days "$retention"
      ;;
    3) "$MEMORY_BROKER" doctor --project "$project_dir" ;;
    4|5)
      read -rp 'Agent id: ' agent
      read -rp 'Command id: ' command
      read -rp 'Proposal TSV path: ' proposal
      if [[ "$choice" == 4 ]]; then
        "$MEMORY_BROKER" proposal-check --project "$project_dir" --agent "$agent" \
          --command "$command" --proposal "$proposal"
      else
        read -rp 'Approval id (APPROVAL-MEMORY-*): ' approval
        "$MEMORY_BROKER" apply --project "$project_dir" --agent "$agent" \
          --command "$command" --proposal "$proposal" --approval-id "$approval"
      fi
      ;;
    6)
      read -rp 'Type DISABLE MEMORY: ' approval
      [[ "$approval" == 'DISABLE MEMORY' ]] || { echo -e "${R}Отменено${N}"; return 1; }
      "$MEMORY_BROKER" disable --project "$project_dir"
      ;;
    b|B|'') return ;;
    *) return 1 ;;
  esac
  read -rp 'Нажми Enter...' _
}

worker_scope_safe_relative() {
  local value="${1:-}" part
  local -a parts=()
  [[ -n "$value" && "$value" != /* && "$value" != *$'\t'* && "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *'//' ]] || return 1
  IFS='/' read -r -a parts <<<"$value"
  for part in "${parts[@]}"; do [[ -n "$part" && "$part" != . && "$part" != .. ]] || return 1; done
}

menu_worker_request() {
  local root request='' candidate run_dir workers_dir step request_id worker_agent kind task_b64 raw confirm
  local saved_profile saved_credential_ref route_profile route_material route_sha request_sha scope_sha auth_sha result scope authorization
  local ref canonical decoded plan_sha frozen_policy frozen_profile frozen_credential_ref frozen_tasks frozen_max completed_count
  local -a refs=()
  [[ "${SDLC_SUBAGENTS:-off}" != off ]] || {
    echo -e "${Y}Workers выключены. Сначала выберите auto или cross-runtime в AI settings.${N}"
    return 1
  }
  root="$(journal_root "$PROJECT")/runs"
  while IFS= read -r candidate; do
    step="$(basename "$candidate")"; step="${step#request-step-}"; step="${step%.yaml}"
    [[ "$step" =~ ^[0-9]+$ ]] || continue
    [[ ! -e "$(dirname "$candidate")/result-step-$step.yaml" ]] || continue
    request="$candidate"
    break
  done < <(find "$root" -type f -path '*/workers/request-step-*.yaml' -print 2>/dev/null | sort -r)
  [[ -n "$request" && -f "$request" && ! -L "$request" ]] || {
    echo -e "${Y}Нет pending Worker Request для этого Project.${N}"; return 1;
  }
  workers_dir="$(dirname "$request")"
  run_dir="$(dirname "$workers_dir")"
  step="$(basename "$request")"; step="${step#request-step-}"; step="${step%.yaml}"
  [[ "$step" =~ ^[0-9]+$ ]] || return 1
  [[ -f "$run_dir/plan.md" && ! -L "$run_dir/plan.md" && -f "$run_dir/plan.sha256" && ! -L "$run_dir/plan.sha256" ]] || return 1
  plan_sha="$(sed -n '1p' "$run_dir/plan.sha256")"
  [[ "$plan_sha" =~ ^[0-9a-f]{64}$ && "$(sha256sum "$run_dir/plan.md" | awk '{print $1}')" == "$plan_sha" ]] || {
    echo -e "${R}Frozen execution plan digest mismatch.${N}"; return 1;
  }
  frozen_policy="$(awk -F': ' '$1 == "subagents" {print $2; exit}' "$run_dir/plan.md")"
  frozen_profile="$(awk -F': ' '$1 == "subagent_profile" {print $2; exit}' "$run_dir/plan.md")"
  frozen_credential_ref="$(awk -F': ' '$1 == "subagent_credential_ref" {print $2; exit}' "$run_dir/plan.md")"
  frozen_tasks="$(awk -F': ' '$1 == "subagent_tasks" {print $2; exit}' "$run_dir/plan.md")"
  frozen_max="$(awk -F': ' '$1 == "subagent_max" {print $2; exit}' "$run_dir/plan.md")"
  [[ "$frozen_policy" == auto || "$frozen_policy" == cross-runtime ]] || return 1
  valid_menu_index "$frozen_max" 16 || return 1
  completed_count="$(find "$workers_dir" -maxdepth 1 -type f -name 'result-step-*.yaml' | wc -l)"
  (( completed_count < frozen_max )) || { echo -e "${Y}Frozen worker limit reached.${N}"; return 1; }
  request_id="$(awk -F': ' '$1 == "request_id" {print $2; exit}' "$request")"
  worker_agent="$(awk -F': ' '$1 == "worker_agent" {print $2; exit}' "$request")"
  kind="$(awk -F': ' '$1 == "kind" {print $2; exit}' "$request")"
  task_b64="$(awk -F': ' '$1 == "task_b64" {print $2; exit}' "$request")"
  [[ "$request_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ && -d "$AGENTS/cycle1-dev/$worker_agent" && -f "$AGENTS/cycle1-dev/$worker_agent/CLAUDE.md" ]] || return 1
  decoded="$(printf '%s' "$task_b64" | base64 -d 2>/dev/null)" || return 1
  [[ -n "$decoded" && "$decoded" != *$'\n'* ]] || return 1
  [[ ",$frozen_tasks," == *",$kind,"* ]] || { echo -e "${R}Worker kind is outside the frozen allowlist.${N}"; return 1; }
  read -rp 'Project-relative read paths, comma-separated (1..64): ' raw
  IFS=',' read -r -a refs <<<"$raw"
  (( ${#refs[@]} >= 1 && ${#refs[@]} <= 64 )) || return 1
  for ref in "${refs[@]}"; do
    worker_scope_safe_relative "$ref" || { echo -e "${R}Invalid read path: $ref${N}"; return 1; }
    [[ -e "$(project_path)/$ref" && ! -L "$(project_path)/$ref" ]] || return 1
    canonical="$(realpath -e -- "$(project_path)/$ref")" || return 1
    [[ "$canonical" == "$(project_path)/"* ]] || return 1
  done
  saved_profile="$(current_profile)"
  saved_credential_ref="${LOCAL_MODEL_CREDENTIAL_REF:-}"
  if [[ "$frozen_policy" == cross-runtime ]]; then
    route_profile="$frozen_profile"
    [[ "$frozen_credential_ref" == none ]] && frozen_credential_ref=''
    LOCAL_MODEL_CREDENTIAL_REF="$frozen_credential_ref"
  else
    route_profile="$(awk -F': ' -v key="step_${step}_profile" '$1 == key {print $2; exit}' "$run_dir/plan.md")"
    LOCAL_MODEL_CREDENTIAL_REF=''
  fi
  export LOCAL_MODEL_CREDENTIAL_REF
  apply_profile "$route_profile" || { LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"; export LOCAL_MODEL_CREDENTIAL_REF; apply_profile "$saved_profile" >/dev/null 2>&1 || true; return 1; }
  route_material="$AGENT_RUNTIME|${LOCAL_AGENT_HOST:-}|${LOCAL_MODEL_PROVIDER:-}|${LOCAL_MODEL:-}|${LOCAL_MODEL_ENDPOINT:-}|${LOCAL_MODEL_CREDENTIAL_REF:-}"
  route_sha="$(printf '%s' "$route_material" | sha256sum | awk '{print $1}')"
  printf '%s\n' 'WORKER PREVIEW' \
    "Project: $(project_path)" "Request: $request_id" "Worker: $worker_agent" \
    "Route: $route_material" "Kind: $kind" "Task: $decoded" 'Read paths:'
  printf '  - %s\n' "${refs[@]}"
  printf '%s\n' 'Writes: denied' 'Memory/provider: denied' 'Nested delegation: denied' 'Fallback: OFF'
  read -rp "Type RUN WORKER $request_id: " confirm
  [[ "$confirm" == "RUN WORKER $request_id" ]] || { LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"; export LOCAL_MODEL_CREDENTIAL_REF; apply_profile "$saved_profile"; return 1; }
  scope="$workers_dir/read-scope-step-$step.tsv"
  authorization="$workers_dir/authorization-step-$step.tsv"
  result="$workers_dir/result-step-$step.yaml"
  [[ ! -e "$scope" && ! -L "$scope" && ! -e "$authorization" && ! -L "$authorization" && ! -e "$result" && ! -L "$result" ]] || {
    echo -e "${R}Worker handoff already exists; retry requires a new execution run.${N}"; LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"; export LOCAL_MODEL_CREDENTIAL_REF; apply_profile "$saved_profile"; return 1;
  }
  printf '%s\n' $'schema_version\tpath' >"$scope"
  for ref in "${refs[@]}"; do printf '1\t%s\n' "$ref" >>"$scope"; done
  chmod 600 "$scope"
  request_sha="$(sha256sum "$request" | awk '{print $1}')"
  scope_sha="$(sha256sum "$scope" | awk '{print $1}')"
  printf '%s\n' $'schema_version\trequest_sha256\tread_scope_sha256\troute_sha256' >"$authorization"
  printf '1\t%s\t%s\t%s\n' "$request_sha" "$scope_sha" "$route_sha" >>"$authorization"
  chmod 600 "$authorization"
  auth_sha="$(sha256sum "$authorization" | awk '{print $1}')"
  if ! SDLC_SUBAGENTS="$frozen_policy" SDLC_SUBAGENT_MAX="$frozen_max" SDLC_SUBAGENT_TASKS="$frozen_tasks" \
    SDLC_EXECUTION_RUN_DIR="$run_dir" "$SDLC_SUBAGENT_RUNNER" --runtime "$AGENT_RUNTIME" \
    --agent-dir "$AGENTS/cycle1-dev/$worker_agent" --project-dir "$(project_path)" \
    --request-file "$request" --request-sha256 "$request_sha" \
    --read-scope-file "$scope" --read-scope-sha256 "$scope_sha" \
    --authorization-file "$authorization" --authorization-sha256 "$auth_sha" \
    --result-file "$result"; then
    LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"
    export LOCAL_MODEL_CREDENTIAL_REF
    apply_profile "$saved_profile" >/dev/null 2>&1 || true
    return 1
  fi
  LOCAL_MODEL_CREDENTIAL_REF="$saved_credential_ref"
  export LOCAL_MODEL_CREDENTIAL_REF
  apply_profile "$saved_profile" || return 1
  echo -e "${G}Worker Result (advisory, не Project artifact):${N} $result"
  awk -F': ' '$1 == "output_b64" {print $2; exit}' "$result" | base64 -d
  echo
}

menu_utilities() {
  header
  echo -e "${W}── Утилиты выбранного проекта ───────────────────────${N}"
  echo -e "  ${Y}1)${N} Secret mappings  ${C}(s0-secrets /env)${N}"
  echo -e "  ${Y}2)${N} Tracker          ${C}(s0-tracker)${N}"
  echo -e "  ${Y}3)${N} Quality gates    ${C}(s0-quality-gates)${N}"
  echo -e "  ${Y}4)${N} Structure check ${C}(s0-validate)${N}"
  echo -e "  ${Y}5)${N} Release notes   ${C}(s0-tracker /release-notes vX.Y.Z)${N}"
  echo -e "  ${Y}6)${N} Change Scope    ${C}(L1 impact → S3 architecture → Human Approval)${N}"
  echo -e "  ${Y}7)${N} Memory          ${C}(Files / Qdrant / Mem0; approval-gated)${N}"
  echo -e "  ${Y}8)${N} Worker request  ${C}(authorize exact read/route and run advisory worker)${N}"
  echo -e "  ${Y}b)${N} Назад"
  read -rp "$(echo -e "${W}Выбери:${N} ")" choice
  local agent task
  case "$choice" in
    1) agent=s0-secrets; task=/env ;;
    2) menu_tracker; return ;;
    3) agent=s0-quality-gates; task=/validate-gates ;;
    4) agent=s0-validate; task=/validate ;;
    5)
      local version
      read -rp "Версия vMAJOR.MINOR.PATCH: " version
      [[ -n "$version" ]] || return 1
      run_agent_with_preview s0-tracker "$PROJECT" "/release-notes $version"
      return
      ;;
    6) menu_change_scope_preparation; return ;;
    7) menu_memory; return ;;
    8) menu_worker_request; return ;;
    b|B|"") return ;;
    *) return 1 ;;
  esac
  run_agent_with_preview "$agent" "$PROJECT" "$task"
}

menu_unfinished_run() {
  local run_id choice
  run_id="$(journal_latest_unfinished "$PROJECT" 2>/dev/null || true)"
  if [[ -z "$run_id" ]]; then
    echo -e "${Y}У проекта нет незавершённых запусков.${N}"
  else
    echo -e "${W}Последний незавершённый run:${N} ${C}$run_id${N}"
    sed -n '1,30p' "$(journal_run_dir "$PROJECT" "$run_id")/state.md"
    echo -e "${Y}Возобновление выполняется по frozen plan и доказанному следующему шагу, не через vendor resume.${N}"
    echo -e "  ${Y}1)${N} Показать evidence"
    echo -e "  ${Y}2)${N} Retry с доказанного следующего шага через новый child run"
    echo -e "  ${Y}3)${N} Открыть Repair"
    echo -e "  ${Y}4)${N} Отменить run"
    echo -e "  ${Y}b)${N} Назад"
    read -rp 'Выбери: ' choice
    case "$choice" in
      1) sed -n '1,160p' "$(journal_run_dir "$PROJECT" "$run_id")/events.jsonl"; read -rp 'Нажми Enter...' _ ;;
      2) retry_journal_run "$run_id" ;;
      3) menu_project_repair ;;
      4)
        journal_write_state "$run_id" CANCELLED 0 0 UNKNOWN ''
        journal_append_event "$run_id" run_cancelled CANCELLED 0 UNKNOWN '' '' 'cancelled explicitly by user'
        ;;
      b|B|'') return ;;
    esac
    return
  fi
  read -rp 'Нажми Enter...' _
}

retry_journal_run() {
  local parent_run="$1" dir next total line n profile source plan_type
  local -a all_entries=() all_profiles=() all_sources=()
  dir="$(journal_run_dir "$PROJECT" "$parent_run")"
  plan_type="$(awk -F': ' '$1 == "type" {print $2; exit}' "$dir/plan.md" 2>/dev/null || true)"
  if [[ "$plan_type" == SCOPE ]]; then
    echo -e "${Y}Change Scope preparation нельзя продолжить как обычный child retry.${N}"
    echo -e "${Y}Создай новый scope через Utilities → Change Scope: граница и подтверждение должны быть собраны заново.${N}"
    return 1
  fi
  next="$(journal_resume_point "$PROJECT" "$parent_run")" || return 1
  while IFS= read -r line; do
    [[ "$line" =~ ^([0-9]+)\.\ (.+)$ ]] || continue
    n="${BASH_REMATCH[1]}"
    all_entries+=("${BASH_REMATCH[2]}")
    profile="$(awk -F': ' -v key="step_${n}_profile" '$1 == key { sub(/^[^:]*: /, ""); print; exit }' "$dir/plan.md")"
    source="$(awk -F': ' -v key="step_${n}_route_source" '$1 == key { sub(/^[^:]*: /, ""); print; exit }' "$dir/plan.md")"
    all_profiles+=("$profile")
    all_sources+=("$source")
  done < "$dir/plan.md"
  total="${#all_entries[@]}"
  (( next <= total )) || {
    echo -e "${Y}Все шаги уже имеют success evidence; сначала выполни Review.${N}"
    return 1
  }
  local -a RUN_CYCLE=("${all_entries[@]:$((next - 1))}")
  local -a RUN_OPTIONAL=()
  EXECUTION_STEP_PROFILES=("${all_profiles[@]:$((next - 1))}")
  EXECUTION_STEP_SOURCES=("${all_sources[@]:$((next - 1))}")
  local entry
  for entry in "${RUN_CYCLE[@]}"; do RUN_OPTIONAL+=(0); done
  EXECUTION_TYPE=RESUME
  EXECUTION_SCOPE="child retry of $parent_run from original step $next/$total"
  EXECUTION_EXCLUDED="proven steps 1-$((next - 1)); all scopes outside parent plan"
  EXECUTION_TITLE="Retry $parent_run"
  EXECUTION_CYCLE_ID=1
  PARENT_RUN_ID="$parent_run"
  USE_EXISTING_FROZEN_ROUTES=1
  render_execution_preview "$EXECUTION_TYPE" "$EXECUTION_SCOPE" "$EXECUTION_EXCLUDED"
  confirm_execution_preview execute_previewed_cycle
  local rc=$?
  USE_EXISTING_FROZEN_ROUTES=0
  PARENT_RUN_ID=""
  return "$rc"
}

menu_local_repositories() {
  local rc=0
  SDLC_LAUNCHER_PARENT=1 SDLC_PARENT_PROJECT="$PROJECT" SDLC_UI_VIEW="$SDLC_UI_VIEW" \
    bash "$AGENTS/localrun.sh" || rc=$?
  [[ $rc -eq 86 ]] && return 2
  return "$rc"
}

menu_launcher_settings() {
  menu_settings
}

project_selector() {
  local choice i d name had_ai_config
  local -a projects=()
  while true; do
    header
    echo -e "${W}── Выбор SDLC Project ────────────────────────────────${N}"
    echo
    render_launcher_entry_intro
    projects=()
    if [[ "$PROJECTS_MODE" == single ]]; then
      projects+=("$SINGLE_PROJECT")
    else
      while IFS= read -r -d '' d; do
        name="$(basename "$d")"
        [[ "$name" == _* || "$name" == .* ]] && continue
        is_recognized_sdlc_project "$d" || continue
        projects+=("$name")
      done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
    fi
    echo
    for i in "${!projects[@]}"; do
      printf '  %s) %s\n     %s/%s\n' "$((i + 1))" "${projects[$i]}" "$PROJECTS" "${projects[$i]}"
    done
    printf '%s\n' '  n) Создать новый SDLC Project' '  l) Локальные репозитории' \
      '  g) Настройки launcher-а' '  q) Завершить launcher'
    read -rp 'Выбери номер, n/l/g/q: ' choice
    case "$choice" in
      n|N) menu_new_project ;;
      l|L) menu_local_repositories ;;
      g|G) menu_launcher_settings ;;
      q|Q) return 2 ;;
      *)
        if valid_menu_index "$choice" "${#projects[@]}"; then
          PROJECT="${projects[$((choice - 1))]}"
          had_ai_config=0
          [[ -f "$(project_ai_config_path)" ]] && had_ai_config=1
          activate_project_ai_config || {
            echo -e "${R}AI configuration проекта повреждена или неполна.${N}"
            return 1
          }
          if [[ -n "${PENDING_FIRST_RUN_AI_SETUP:-}" ]]; then
            if [[ "$had_ai_config" == "1" ]]; then
              echo -e "${Y}У проекта уже есть AI routing; first-run intent не перезаписывает его.${N}"
              PENDING_FIRST_RUN_AI_SETUP=''
            else
              complete_pending_first_run_ai_setup || return 1
            fi
          elif [[ "$had_ai_config" == "0" ]]; then
            save_project_ai_config "$BASE_PROFILE" "$SDLC_RUNTIME_ROUTING" || return 1
          fi
          journal_mark_interrupted_runs
          PROJECT_CONSOLE_INTRO_PENDING=1
          return 0
        fi
        ;;
    esac
  done
}

project_console() {
  local choice rc
  while true; do
    header
    if [[ "$PROJECT_CONSOLE_INTRO_PENDING" == "1" ]]; then
      render_project_console_intro
      echo
      PROJECT_CONSOLE_INTRO_PENDING=0
    fi
    render_project_console
    echo
    read -rp 'Выбери действие: ' choice
    if [[ "$choice" == p || "$choice" == P ]]; then
      project_selector || return $?
      continue
    fi
    dispatch_console_action "$choice"
    rc=$?
    [[ $rc -eq 2 ]] && return 2
  done
}


# ─── настройки ────────────────────────────────────────────────────────────────
menu_settings() {
  apply_profile "$BASE_PROFILE" || true
  while true; do
    header
    echo -e "${W}── Настройки ────────────────────────────────────────${N}"
    echo
    echo -e "  Runtime:  ${C}$(runtime_label)${N} (${AGENT_RUNTIME})"
    echo -e "  CLI:      ${C}$(runtime_bin)${N}"
    [[ "$AGENT_RUNTIME" == "local" ]] &&
      echo -e "  Local:    ${C}$LOCAL_AGENT_HOST / $LOCAL_MODEL_PROVIDER / $LOCAL_MODEL${N}"
    echo -e "  Routing:  ${C}$SDLC_RUNTIME_ROUTING${N}"
    echo -e "  Workers:  ${C}${SDLC_SUBAGENTS:-off}/${SDLC_SUBAGENT_MAX:-2}${N} — exact read/route handoff"
    if [[ "$SDLC_SUBAGENTS" == "cross-runtime" ]]; then
      echo -e "  Worker:   ${C}$(subagent_profile_label)${N}"
      echo -e "  Tasks:    ${C}$SDLC_SUBAGENT_TASKS${N}"
    fi
    if [[ "$PROJECTS_MODE" == "single" ]]; then
      echo -e "  Projects: ${C}$PROJECTS/$SINGLE_PROJECT${N} (один проект)"
    else
      echo -e "  Projects: ${C}${PROJECTS:-не настроены}${N}"
    fi
    echo
    echo -e "  ${Y}1)${N} Выбрать основной AI runtime/profile"
    echo -e "  ${Y}2)${N} Настроить local profile (host/provider/exact model)"
    echo -e "  ${Y}3)${N} Выбрать routing policy"
    echo -e "  ${Y}4)${N} Добавить/изменить per-stage или per-agent route"
    echo -e "  ${Y}5)${N} Показать статус workers"
    echo -e "  ${Y}6)${N} Изменить каталог SDLC-проектов"
    echo -e "  ${Y}7)${N} Проверить основной runtime/profile"
    echo -e "  ${Y}8)${N} Переключить подробный/краткий вид"
    echo -e "  ${Y}b)${N} Назад"
    echo
    read -rp "$(echo -e "${W}Выбери [1-8/b]:${N} ")" choice
    case "$choice" in
      1) choose_runtime ;;
      2)
        configure_local_profile && {
          AGENT_RUNTIME="local"
          export AGENT_RUNTIME
          write_config_value AGENT_RUNTIME local
          BASE_PROFILE="$(current_profile)"
        }
        ;;
      3) select_routing_policy yes || true ;;
      4) configure_runtime_route ;;
      5) configure_subagent_settings ;;
      6) configure_projects_dir ;;
      7)
        apply_profile "$BASE_PROFILE"
        read -rp "$(echo -e "${W}Нажми Enter...${N} ")" _
        ;;
      8) toggle_ui_view >/dev/null ;;
      b|B) return ;;
      *) echo -e "${R}Неверный выбор${N}"; sleep 0.5 ;;
    esac
  done
}

# ─── главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  while true; do
    if [[ -z "${PROJECT:-}" ]]; then
      project_selector || return 0
    fi
    project_console
    [[ $? -eq 2 ]] && return 0
  done
}

main() {
  if is_first_run; then
    FIRST_RUN_WIZARD=1
    ensure_first_run_runtime || exit 1
    BASE_PROFILE="$(current_profile)"
    initialize_first_run_execution_policy || exit 1
    configure_first_run_ai_mode || exit 1
    render_first_run_execution_policy
    ensure_first_run_projects_dir || exit 1
    ensure_ui_view || exit 1
    FIRST_RUN_WIZARD=0
  else
    ensure_runtime || exit 1
    BASE_PROFILE="$(current_profile)"
    ensure_routing_policy || exit 1
    ensure_subagent_settings || exit 1
    ensure_projects_dir || exit 1
    ensure_ui_view || exit 1
  fi
  LAUNCHER_BASE_PROFILE="$BASE_PROFILE"
  LAUNCHER_ROUTING_POLICY="$SDLC_RUNTIME_ROUTING"
  LAUNCHER_SUBAGENTS="$SDLC_SUBAGENTS"
  LAUNCHER_SUBAGENT_MAX="$SDLC_SUBAGENT_MAX"
  LAUNCHER_SUBAGENT_PROFILE="$SDLC_SUBAGENT_PROFILE"
  LAUNCHER_SUBAGENT_CREDENTIAL_REF="$SDLC_SUBAGENT_CREDENTIAL_REF"
  LAUNCHER_SUBAGENT_TASKS="$SDLC_SUBAGENT_TASKS"
  main_menu
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
