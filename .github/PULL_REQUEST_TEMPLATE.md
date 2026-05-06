## Summary

<!-- One or two sentences on what this PR changes and why. -->

## Changes

-
-

## Testing

- [ ] `shellcheck --shell=bash bin/pbtalk bin/pbtrace` passes
- [ ] `bats tests/unit` passes
- [ ] `bats tests/integration` passes (with credentials), or N/A
- [ ] Manually exercised the affected REPL commands

## Checklist

- [ ] Code, comments, error messages, and documentation are in English (Japanese only allowed in `README.ja.md`).
- [ ] No new runtime dependencies beyond `curl`, `jq`, and standard UNIX utilities.
- [ ] Credentials do not appear in the request URL or in any error output.
- [ ] CHANGELOG entry added under `[Unreleased]` if user-visible.
