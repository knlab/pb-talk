# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- `.env` is now parsed line by line instead of being sourced as shell code. Previously, starting `pbtalk` in a directory containing a crafted `.env` (e.g. a cloned bot repository) executed whatever it contained. Supported syntax: `KEY=VALUE`, optional `export` prefix, `#` comments (full-line and after an unquoted value), single or double quotes around a value. No shell expansion is performed.
- Bot replies, server error messages, non-JSON server bodies and every string in `pbtrace` output are stripped of terminal control characters (C0, C1, DEL; TAB and LF are kept). A bot template or an `sraix` upstream can no longer inject escape sequences (terminal title, OSC 52 clipboard, screen clearing) into the terminal. `Server:` error lines are printed with `printf` rather than `echo`, which under zsh also interpreted backslash escapes.

### Changed
- `.env` values are no longer exported to child processes (`curl`, `jq`, `pbtrace`, the segmentation hook). Keys other than the documented `PB_*` ones are ignored with a warning instead of being set.
- `curl` is invoked with `--globoff`, so `[` `]` `{` `}` in `PB_APP_ID` / `PB_BOTNAME` are no longer expanded into multiple requests.

### Fixed
- Under zsh, every talk request failed with `read-only variable: status` because `send_talk` declared a local named `status`, which zsh reserves. Renamed.

### Added
- Unit tests now exercise the talk path through a fake `curl` on `PATH`, so request shape, `.env` parsing and output sanitization are covered without credentials or network access.
- `tests/unit/helpers.bash` with `assert_contains` / `assert_not_contains` / `assert_starts_with`. All unit-test assertions now use them: under bash 3.2 (macOS default) a failing `[[ ... ]]` does not abort a `set -e` test, so the previous `[[ "$output" =~ ... ]]` assertions were only effective when they happened to be the last line of a test.

## [0.9.0] — 2026-05-05

Initial public beta release. The CLI surface and configuration variables are expected to be stable through the 0.9.x line. The 1.0.0 promotion will follow once external feedback has been incorporated.


### Added
- `bin/pbtalk`: shell-based REPL for the Pandorabots public API.
  - Talk loop with session continuity via the server-issued `sessionid`.
  - Per-turn flags: `--trace`, `--reset`, `--reload`, `--reset --trace` (and reversed `--trace --reset`).
  - `--atalk` mode for botkey-authenticated anonymous talk via `POST /atalk`. Auto-captures the server-issued `client_name` on the first reply and re-sends it on subsequent turns. Prompt marker `:at` while in atalk mode.
  - Client-side `topic` set with the `topic` REPL command, automatically attached as the `topic` parameter on every following talk request.
  - Local input history: `history`, `historyc`, `historyf` (appends to `history.txt`).
  - Optional word-segmentation hook (`seg` / `noseg`) that pipes input through `$PB_SEG_CMD` (default `pbseg`) before sending. Off by default. If the configured command is missing from `PATH`, the toggle is refused with a warning and segmentation stays off.
  - Bot replies are prefixed with `$PB_BOTNAME>` so transcripts read as a clear `Human> input` / `<bot>> response` dialogue.
  - When stdin is not a TTY (scripted/piped runs), pbtalk echoes the typed input back so log transcripts remain self-readable. Interactive (TTY) usage is unaffected.
  - Configuration via `.env` (or `$PB_TALK_ENV_FILE`): `PB_APP_ID`, `PB_USER_KEY`, `PB_BOTNAME` required; `PB_HOST`, `PB_BOT_KEY`, `PB_CLIENT_NAME`, `PB_SEG_CMD` optional.
  - Credentials (`user_key`, `botkey`) sent in the request body, never in the URL query string, so error messages that echo a URL never leak them.
- `bin/pbtrace`: companion formatter for `trace=true` responses.
  - Renders the actual Pandorabots trace schema: 7 step types (`begin`, `match`, `srai-begin`, `srai-end`, `sraix-begin`, `sraix-end`, `end`) with their real fields (`input` array, `matched`, `template`, `filename`, `status`, `result`, `bot`, `level`).
  - Hierarchical, color-coded output. `<template>...</template>` wrapper tags are stripped for readability. Empty/whitespace-only entries in `result` arrays are filtered. Nested srai/sraix steps are indented and tagged with `level=N`.
  - Color toggle: `--color` forces ANSI on, `--no-color` forces it off, `NO_COLOR` env var disables colors, and stdout-not-a-TTY auto-disables.
  - Standalone use (`pbtrace < trace.json`) produces the same output as the piped form.
  - Compatible with jq 1.4+ (avoids `--argjson`, `sub`, `gsub`).
- `examples/env.example`: configuration template.
- `examples/sample.aiml`: minimal AIML 2.0 file with a single `HELLO` category so first-time users can upload a working bot. The Pandorabots-shipped wildcard category provides the fallback for non-matching input.
- `tests/unit/`: 20 bats-core unit tests covering CLI flags, env validation, schema-aware trace rendering, srai/sraix indentation, sraix `bot` field, whitespace filtering, color toggle.
- `tests/integration/`: bats-core integration tests against the real Pandorabots API, skipped automatically when credentials are not provided.
- GitHub Actions CI: shellcheck, `bash -n` / `zsh -n` parse checks on macOS and Ubuntu, bats unit tests on bash and zsh, language/term policy checks (no Japanese characters outside `README.ja.md`, no forbidden internal-tool names).
- `README.md` (English) and `README.ja.md` (Japanese supplement covering the segmentation hook with MeCab and SudachiPy examples).
- `CONTRIBUTING.md` and GitHub issue/PR templates.
