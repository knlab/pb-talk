#!/usr/bin/env bats
#
# Integration tests against the real Pandorabots API.
# Skipped unless PB_APP_ID and PB_USER_KEY are set in the environment.
#
# Run with:
#   PB_APP_ID=xxx PB_USER_KEY=yyy PB_BOTNAME=zzz \
#   bats tests/integration

setup() {
  PBTALK="${BATS_TEST_DIRNAME}/../../bin/pbtalk"
  if [[ -z "${PB_APP_ID:-}" || -z "${PB_USER_KEY:-}" || -z "${PB_BOTNAME:-}" ]]; then
    skip "PB_APP_ID, PB_USER_KEY, PB_BOTNAME must be set for integration tests"
  fi
  TMPDIR_=$(mktemp -d)
  cd "$TMPDIR_"
  cat > .env <<EOF
PB_APP_ID=$PB_APP_ID
PB_USER_KEY=$PB_USER_KEY
PB_BOTNAME=$PB_BOTNAME
${PB_HOST:+PB_HOST=$PB_HOST}
${PB_BOT_KEY:+PB_BOT_KEY=$PB_BOT_KEY}
EOF
}

teardown() {
  rm -rf "$TMPDIR_"
}

@test "talk: sending a simple input returns a response" {
  run bash -c "printf 'hello\nq\n' | env PB_TALK_ENV_FILE='$PWD/.env' '$PBTALK'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(h for help)" ]]
  [[ "$output" =~ "done." ]]
}

@test "talk --trace: trace output includes [trace] header" {
  run bash -c "printf -- '--trace hello\nq\n' | env PB_TALK_ENV_FILE='$PWD/.env' '$PBTALK'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[trace]" ]]
}

@test "atalk: requires PB_BOT_KEY" {
  if [[ -z "${PB_BOT_KEY:-}" ]]; then
    skip "PB_BOT_KEY not set"
  fi
  run bash -c "printf -- '--atalk hello\nq\n' | env PB_TALK_ENV_FILE='$PWD/.env' '$PBTALK'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Switched to atalk" ]]
}
