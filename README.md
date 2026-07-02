# omp-profiles

Tiny installer for two manually switched Oh My Pi profiles:

- `gpt` — locked to `openai-codex/gpt-5.5`
- `ave` — locked to `avemujicaapi/gpt-5.5`

No automatic fallback is configured. Use Codex until subscription usage runs out, then manually switch to Avemujica.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/notquite28/omp-profiles/main/install.sh | bash
```

## First-time Codex login

After installing, start the Codex profile:

```bash
gpt
```

Then run this inside OMP:

```text
/login openai-codex
```

## Daily use

Use Codex subscription profile:

```bash
gpt
```

Use Avemujica API-key profile:

```bash
ave
```

## What the installer creates

```text
~/.omp/profiles/codex-chatgpt/agent/
~/.omp/profiles/avemujica-chatgpt/agent/
```

It configures these model roles in each profile:

- `default`
- `smol`
- `slow`
- `vision`
- `plan`
- `designer`
- `commit`
- `tiny`
- `task`
- `advisor`

The `task` role is included so OMP subagents use the same locked provider.

## Avemujica setup

The installer looks for an existing `avemujicaapi` provider in:

```text
~/.omp/agent/models.yml
```

If it exists, the installer copies that `models.yml` into the Avemujica profile.

If it does not exist, the installer asks for an Avemujica OpenAI-compatible base URL and writes a minimal `avemujicaapi` provider template.

The Avemujica API key is stored profile-locally in:

```text
~/.omp/profiles/avemujica-chatgpt/agent/.env
```

## Non-interactive install

```bash
AVEMUJICA_API_KEY='your_key_here' \
AVEMUJICA_BASE_URL='https://your-avemujica-endpoint/v1' \
curl -fsSL https://raw.githubusercontent.com/notquite28/omp-profiles/main/install.sh | bash
```

## Overrides

You can override names/models with environment variables:

```bash
CODEX_PROFILE=codex \
AVEMUJICA_PROFILE=ave \
CODEX_ALIAS=gpt \
AVEMUJICA_ALIAS=ave \
CODEX_MODEL=openai-codex/gpt-5.5 \
AVEMUJICA_MODEL=avemujicaapi/gpt-5.5 \
curl -fsSL https://raw.githubusercontent.com/notquite28/omp-profiles/main/install.sh | bash
```

## Verify

```bash
omp --profile codex-chatgpt models find codex
omp --profile avemujica-chatgpt models find avemujica
```
