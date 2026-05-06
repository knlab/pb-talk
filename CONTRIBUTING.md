# Contributing to pb-talk

Thanks for your interest. This is a small personal OSS project, so the contribution loop is intentionally lightweight.

## Scope

pb-talk is a thin shell client for the **public** Pandorabots API as documented at <https://www.pandorabots.com/docs/api-endpoints/>. Features that depend on private/legacy endpoints, or that require non-shell runtimes, are out of scope.

## Getting set up

1. Fork and clone the repo.
2. Install local dev dependencies (one-time):
   - `bash` 4+ or `zsh` 5+
   - `curl`
   - `jq`
   - `shellcheck` (e.g. `brew install shellcheck`)
   - `bats-core` (e.g. `brew install bats-core`)
3. Copy `examples/env.example` to `.env` and fill in your own Pandorabots credentials. This file is `.gitignore`d.

## Running the checks locally

```sh
shellcheck --shell=bash bin/pbtalk bin/pbtrace
bash -n bin/pbtalk && bash -n bin/pbtrace
zsh -n bin/pbtalk && zsh -n bin/pbtrace
bats tests/unit
PB_APP_ID=xxx PB_USER_KEY=yyy PB_BOTNAME=zzz bats tests/integration
```

CI runs the same matrix on macOS and Ubuntu under both `bash` and `zsh`.

## Coding conventions

- Shell: target `bash` 4+ but keep `zsh` 5+ compatibility (e.g. avoid `${!name}` indirect expansion). Do not introduce non-portable GNU coreutils flags.
- Dependencies: limit to `curl`, `jq`, and tools shipped by default on macOS and Ubuntu.
- Language: English everywhere except `README.ja.md`. CI enforces this.
- Credentials: never let `user_key` or `botkey` reach a URL string that could appear in error output. Use `--data-urlencode` to put them in the request body.
- Comments: explain the *why* when it's not obvious from the code. Keep them short.

## Submitting a change

1. Open an issue first for non-trivial proposals so the scope can be agreed.
2. Branch off `main`, make the change, add or update tests.
3. Update `CHANGELOG.md` under `[Unreleased]` if the change is user-visible.
4. Open a PR. Fill in the template.

## License

By contributing, you agree your contributions will be licensed under the MIT License (see `LICENSE`).
