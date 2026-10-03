# pb-talk

A shell-based REPL for the [Pandorabots](https://www.pandorabots.com/docs/api-endpoints/) public API. Originally written for in-house use; now released as personal OSS.

> Looking for the Japanese supplement? See [README.ja.md](README.ja.md).

## Features

- Interactive talk loop against `POST /talk/{app_id}/{botname}` with session continuity.
- One-shot debugging flags: `--trace`, `--reset`, `--reload`, `--reset --trace`.
- `--atalk` mode for botkey-authenticated anonymous talk via `POST /atalk`.
- Per-session client-side `topic`, automatically attached to subsequent requests.
- Local input history (`history`, `historyc`, `historyf`).
- Companion `pbtrace` formatter that pretty-prints `trace=true` responses with ANSI color (auto-disables when `NO_COLOR` is set or stdout is not a TTY).
- Optional word-segmentation hook for languages that need it; off by default.

## Requirements

- `bash` 4+ (or `zsh` 5+ for invocation).
- `curl`
- `jq`
- macOS or Linux. The scripts use only POSIX-standard utilities found on both platforms; no GNU coreutils (`g*`) and no Python/Perl/Ruby.

## Installation

Copy the two scripts into a directory on your `PATH`:

```sh
cp bin/pbtalk bin/pbtrace ~/.local/bin/
```

## Quickstart

If you do not yet have a Pandorabots bot to talk to, the steps below walk you through provisioning a minimal one with the bundled [`examples/sample.aiml`](examples/sample.aiml) (a single `HELLO` category). The Pandorabots server ships a built-in wildcard fallback that responds to any non-matching input, so this one category is enough to demonstrate both a successful match and the fallback path. All steps use the public API — no dashboard required.

```sh
# 1) Pick a botname and create the bot.
export PB_APP_ID=your-app-id
export PB_USER_KEY=your-user-key
export PB_BOTNAME=mybot

curl -sS -X PUT \
  "https://api.pandorabots.com/bot/$PB_APP_ID/$PB_BOTNAME?user_key=$PB_USER_KEY"

# 2) Upload the sample AIML.
curl -sS -X PUT --data-binary @examples/sample.aiml \
  -H 'Content-Type: text/plain' \
  "https://api.pandorabots.com/bot/$PB_APP_ID/$PB_BOTNAME/file/sample?user_key=$PB_USER_KEY"

# 3) Compile the bot so the new content is live.
curl -sS \
  "https://api.pandorabots.com/bot/$PB_APP_ID/$PB_BOTNAME/verify?user_key=$PB_USER_KEY"

# 4) Drop credentials into a .env and start chatting.
cp examples/env.example .env
$EDITOR .env   # fill in PB_APP_ID / PB_USER_KEY / PB_BOTNAME
pbtalk
```

In the REPL, type `hello` and you should see `mybot> Hello, world.`. Type `--trace hello` to see how the bot matched it.

### Alternative: provisioning via pb-migrate

If you would rather not stitch the `curl` calls together, [`pb-migrate`](https://github.com/knlab/pb-migrate) is a higher-level CLI that wraps the same Pandorabots API into a single workflow with `bot:create`, `push`, `compile`, `diff`, `pull`, and more. It treats a local AIML directory as the source of truth and keeps the remote bot in sync.

```sh
composer global require knlab/pb-migrate

mkdir mybot && cp pb-talk/examples/sample.aiml mybot/
pb-migrate add ./mybot
pb-migrate bot:create
pb-migrate push
pb-migrate compile
```

After that, `pbtalk` against the same `.env` works the same as in the `curl`-based path above.

`pb-talk` does not depend on `pb-migrate`; choose whichever feels lighter for the situation. The two tools are complementary — `pb-migrate` for bot lifecycle and file sync, `pb-talk` for conversation and trace inspection.

## Configuration

`pbtalk` reads a `.env` file from the current directory, or from the path in `$PB_TALK_ENV_FILE`.

```env
# Required
PB_APP_ID=your-app-id
PB_USER_KEY=your-user-key
PB_BOTNAME=your-botname

# Optional
PB_HOST=https://api.pandorabots.com   # default
PB_BOT_KEY=your-bot-key               # required for --atalk
PB_CLIENT_NAME=                       # optional client_name passed to talk
PB_SEG_CMD=pbseg                      # word-segmentation command name
```

A template lives at [`examples/env.example`](examples/env.example). Copy it to `.env` next to the bot files you are testing.

The file is parsed, never executed, so a `.env` found in an untrusted directory cannot run code. Each line is `KEY=VALUE`, optionally prefixed with `export`. Blank lines and `#` comments are skipped, including a trailing `# comment` after an unquoted value. A value may be wrapped in single or double quotes. No shell expansion takes place: `$VAR`, `$(...)` and backslashes are taken literally. Keys other than the `PB_*` ones above are ignored with a warning. Values stay inside `pbtalk` and are not exported to the processes it runs (`curl`, `jq`, `pbtrace`, the segmentation hook).

Credentials (`user_key`, `botkey`) are sent in the request body, never in the URL query string, so error messages that echo a URL never leak them.

Bot replies, server error messages and trace fields are stripped of terminal control characters (C0, C1 and DEL, keeping TAB and LF) before they are printed, so a bot template or an `sraix` upstream cannot inject escape sequences into your terminal.

## Command reference (REPL)

```
<input>                  Talk to the bot.
--trace <input>          Talk once with trace=true; pretty-print the trace.
--reset <input>          Talk once with reset=true.
--reload <input>         Talk once with reload=true.
--reset --trace <input>  Combine reset and trace.
--atalk <input>          Switch to atalk mode (POST /atalk with botkey).
                         Requires PB_BOT_KEY.
atalkoff                 Leave atalk mode and return to /talk.
topic                    Prompt for a topic value, sent as `topic` on every
                         following talk request. Empty value clears it.
traceon / traceoff       Toggle always-on trace mode.
seg / noseg              Toggle word segmentation (see below). Default: off.
history                  Print the local input history.
historyc                 Clear the local input history.
historyf                 Append the input history to history.txt.
retype                   Re-send the previous input.
resession                Clear the saved sessionid.
clear                    Clear the screen.
q                        Quit.
h                        Show in-REPL help.
```

## Trace formatting

When you pipe a `trace=true` response through `pbtrace`, you get a hierarchical, color-coded view:

```sh
echo '{...trace JSON...}' | pbtrace
```

`pbtalk` does this automatically when `--trace` or `traceon` is in effect.

`pbtrace` honors `NO_COLOR` and the `--no-color` flag, and falls back to plain text when stdout is not a TTY.

## Word segmentation (optional)

Some languages, including Japanese, need explicit word segmentation as a preprocessing step before being sent to a Pandorabots bot whose AIML patterns are written in segmented form. `pbtalk` exposes a single hook for that.

- The hook is **off by default**. Type `seg` in the REPL to turn it on; `noseg` to turn it off.
- When on, `pbtalk` invokes `$PB_SEG_CMD` (default: `pbseg`) with the input string as `argv[1]`. Whatever the command writes to stdout is sent to the API as the talk input.
- `pb-talk` does not ship a segmenter. You provide one. For language-specific examples (e.g., implementing `pbseg` on top of off-the-shelf Japanese morphological analyzers), see [README.ja.md](README.ja.md).
- If `$PB_SEG_CMD` is not on `PATH` when you toggle `seg` on, the toggle is refused with a warning and segmentation stays off. If the command exists at toggle time but later fails for a particular input, `pbtalk` warns once and sends the raw input for that turn.

## Testing

Unit tests use [bats-core](https://github.com/bats-core/bats-core). They run without API credentials.

```sh
bats tests/unit
```

Integration tests in `tests/integration/` hit the real Pandorabots API and are skipped unless credentials are set:

```sh
PB_APP_ID=xxx PB_USER_KEY=yyy PB_BOTNAME=zzz \
  bats tests/integration
```

## Versioning

pb-talk follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html), with the standard pre-1.0 caveat:

- **0.x.y (current)** — public beta. The CLI surface (REPL commands, env vars, prompt format, exit codes) and the `pbtrace` output are still subject to revision based on user feedback. Within a `0.x` line, **minor bumps may include breaking changes**; patch bumps are bug fixes only.
- **1.0.0 onward** — strict SemVer:
  - **Major** for incompatible changes: REPL command rename or removal, env var rename, breaking change to `pbtrace` output shape, jq/curl/bash baseline raise.
  - **Minor** for backward-compatible additions: new REPL commands, new env vars with safe defaults, new optional `pbtrace` fields.
  - **Patch** for backward-compatible bug fixes.

Each release is recorded in [`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog format) and tagged in git as `vX.Y.Z`. Promotion from `0.9.x` to `1.0.0` will land once the public API has been exercised by external users without surfacing further breaking changes.

## License

[MIT](LICENSE).
