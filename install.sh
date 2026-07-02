#!/usr/bin/env bash
set -euo pipefail

# Installs two locked OMP profiles:
#   omp-codex -> openai-codex/gpt-5.5 only
#   omp-ave   -> avemujicaapi/gpt-5.5 only
#
# Usage:
#   curl -fsSL <raw-url>/install.sh | bash
#
# Optional env overrides:
#   CODEX_PROFILE=codex-chatgpt
#   AVEMUJICA_PROFILE=avemujica-chatgpt
#   CODEX_ALIAS=omp-codex
#   AVEMUJICA_ALIAS=omp-ave
#   CODEX_MODEL=openai-codex/gpt-5.5
#   AVEMUJICA_MODEL=avemujicaapi/gpt-5.5
#   AVEMUJICA_API_KEY=...
#   AVEMUJICA_BASE_URL=https://.../v1

CODEX_PROFILE="${CODEX_PROFILE:-codex-chatgpt}"
AVEMUJICA_PROFILE="${AVEMUJICA_PROFILE:-avemujica-chatgpt}"
CODEX_ALIAS="${CODEX_ALIAS:-omp-codex}"
AVEMUJICA_ALIAS="${AVEMUJICA_ALIAS:-omp-ave}"
CODEX_MODEL="${CODEX_MODEL:-openai-codex/gpt-5.5}"
AVEMUJICA_MODEL="${AVEMUJICA_MODEL:-avemujicaapi/gpt-5.5}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

profile_agent_dir() {
  local profile="$1"
  local dir
  if dir="$(omp --profile "$profile" config path 2>/dev/null)" && [ -n "$dir" ]; then
    printf '%s\n' "$dir"
  else
    printf '%s/.omp/profiles/%s/agent\n' "$HOME" "$profile"
  fi
}

set_config() {
  local profile="$1"
  local key="$2"
  local value="$3"
  printf 'Setting %s for profile %s\n' "$key" "$profile"
  omp --profile "$profile" config set "$key" "$value" >/dev/null
}

make_alias() {
  local profile="$1"
  local alias_name="$2"
  printf 'Creating alias %s for profile %s\n' "$alias_name" "$profile"
  if ! omp --profile "$profile" --alias "$alias_name"; then
    printf 'Warning: OMP could not create alias %s automatically. You can still use: omp --profile %s\n' "$alias_name" "$profile" >&2
  fi
}

append_env_if_missing() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  mkdir -p "$(dirname "$env_file")"
  touch "$env_file"
  chmod 600 "$env_file" 2>/dev/null || true

  if grep -q "^${key}=" "$env_file"; then
    printf '%s already exists in %s; leaving it unchanged.\n' "$key" "$env_file"
    return 0
  fi

  printf '\n%s=%s\n' "$key" "$value" >>"$env_file"
  chmod 600 "$env_file" 2>/dev/null || true
}

contains_avemujica_provider() {
  local file="$1"
  [ -f "$file" ] && grep -q '^  avemujicaapi:' "$file"
}

write_avemujica_template() {
  local file="$1"
  local base_url="$2"
  mkdir -p "$(dirname "$file")"
  cat >"$file" <<YAML
providers:
  avemujicaapi:
    baseUrl: ${base_url}
    apiKey: AVEMUJICA_API_KEY
    api: openai-completions
    authHeader: true
    models:
      - id: gpt-5.5
        name: Avemujica GPT-5.5
        reasoning: true
        input: [text, image]
        contextWindow: 400000
        maxTokens: 128000
      - id: gpt-5.4-mini
        name: Avemujica GPT-5.4 Mini
        reasoning: true
        input: [text, image]
        contextWindow: 400000
        maxTokens: 128000
YAML
}

configure_codex_profile() {
  local roles
  roles="$(cat <<JSON
{
  "default": "${CODEX_MODEL}:high",
  "smol": "${CODEX_MODEL}:low",
  "slow": "${CODEX_MODEL}:xhigh",
  "vision": "${CODEX_MODEL}:high",
  "plan": "${CODEX_MODEL}:high",
  "designer": "${CODEX_MODEL}:high",
  "commit": "${CODEX_MODEL}:low",
  "tiny": "${CODEX_MODEL}:low",
  "task": "${CODEX_MODEL}:high",
  "advisor": "${CODEX_MODEL}:medium"
}
JSON
)"

  set_config "$CODEX_PROFILE" enabledModels '["openai-codex/*"]'
  set_config "$CODEX_PROFILE" retry.modelFallback false
  set_config "$CODEX_PROFILE" modelRoles "$roles"
}

configure_avemujica_profile() {
  local roles
  roles="$(cat <<JSON
{
  "default": "${AVEMUJICA_MODEL}:high",
  "smol": "${AVEMUJICA_MODEL}:low",
  "slow": "${AVEMUJICA_MODEL}:xhigh",
  "vision": "${AVEMUJICA_MODEL}:high",
  "plan": "${AVEMUJICA_MODEL}:high",
  "designer": "${AVEMUJICA_MODEL}:high",
  "commit": "${AVEMUJICA_MODEL}:low",
  "tiny": "${AVEMUJICA_MODEL}:low",
  "task": "${AVEMUJICA_MODEL}:high",
  "advisor": "${AVEMUJICA_MODEL}:medium"
}
JSON
)"

  set_config "$AVEMUJICA_PROFILE" enabledModels '["avemujicaapi/*"]'
  set_config "$AVEMUJICA_PROFILE" retry.modelFallback false
  set_config "$AVEMUJICA_PROFILE" modelRoles "$roles"
}

setup_avemujica_models() {
  local ave_dir="$1"
  local target_models="$ave_dir/models.yml"
  local default_models="$HOME/.omp/agent/models.yml"

  if contains_avemujica_provider "$target_models"; then
    printf 'Avemujica provider already exists in %s\n' "$target_models"
    return 0
  fi

  if contains_avemujica_provider "$default_models"; then
    printf 'Copying existing default models.yml into Avemujica profile.\n'
    cp "$default_models" "$target_models"
    return 0
  fi

  local base_url="${AVEMUJICA_BASE_URL:-}"
  if [ -z "$base_url" ]; then
    printf 'No avemujicaapi provider found in %s.\n' "$default_models"
    printf 'Enter Avemujica OpenAI-compatible base URL, or leave blank to skip models.yml creation: '
    IFS= read -r base_url
  fi

  if [ -n "$base_url" ]; then
    printf 'Writing Avemujica provider template to %s\n' "$target_models"
    write_avemujica_template "$target_models" "$base_url"
  else
    printf 'Skipped Avemujica models.yml creation. Add provider avemujicaapi manually to: %s\n' "$target_models" >&2
  fi
}

setup_avemujica_key() {
  local ave_dir="$1"
  local env_file="$ave_dir/.env"
  local key_value="${AVEMUJICA_API_KEY:-}"

  if grep -q '^AVEMUJICA_API_KEY=' "$env_file" 2>/dev/null; then
    printf 'AVEMUJICA_API_KEY already exists in %s; leaving it unchanged.\n' "$env_file"
    return 0
  fi

  if [ -z "$key_value" ]; then
    printf 'Enter Avemujica API key for profile-local .env, or leave blank to skip: '
    IFS= read -r -s key_value
    printf '\n'
  fi

  if [ -n "$key_value" ]; then
    append_env_if_missing "$env_file" AVEMUJICA_API_KEY "$key_value"
    printf 'Stored Avemujica key in %s\n' "$env_file"
  else
    printf 'Skipped Avemujica API key. Add it later to %s as AVEMUJICA_API_KEY=...\n' "$env_file" >&2
  fi
}

main() {
  require_cmd omp

  make_alias "$CODEX_PROFILE" "$CODEX_ALIAS"
  make_alias "$AVEMUJICA_PROFILE" "$AVEMUJICA_ALIAS"

  local codex_dir
  local ave_dir
  codex_dir="$(profile_agent_dir "$CODEX_PROFILE")"
  ave_dir="$(profile_agent_dir "$AVEMUJICA_PROFILE")"
  mkdir -p "$codex_dir" "$ave_dir"

  configure_codex_profile
  setup_avemujica_models "$ave_dir"
  setup_avemujica_key "$ave_dir"
  configure_avemujica_profile

  printf '\nDone.\n'
  printf '\nUse Codex subscription profile:\n  %s\n' "$CODEX_ALIAS"
  printf '\nFirst time only, login inside Codex profile with:\n  /login openai-codex\n'
  printf '\nUse Avemujica API-key profile:\n  %s\n' "$AVEMUJICA_ALIAS"
  printf '\nVerify:\n'
  printf '  omp --profile %s models find codex\n' "$CODEX_PROFILE"
  printf '  omp --profile %s models find avemujica\n' "$AVEMUJICA_PROFILE"
}

main "$@"
