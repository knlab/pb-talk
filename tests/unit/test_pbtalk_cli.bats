#!/usr/bin/env bats

load 'helpers'

setup() {
  PBTALK="${BATS_TEST_DIRNAME}/../../bin/pbtalk"
  TMPDIR_=$(mktemp -d)
  cd "$TMPDIR_"
}

teardown() {
  rm -rf "$TMPDIR_"
}

# Installs a fake `curl` ahead of the real one on PATH. It records its argv
# and environment and prints the canned body in $TMPDIR_/curl.response, so
# the talk path can be exercised with no network access and no credentials.
make_fake_curl() {
  mkdir -p "$TMPDIR_/bin"
  cat > "$TMPDIR_/bin/curl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > '$TMPDIR_/curl.args'
env > '$TMPDIR_/curl.env'
cat '$TMPDIR_/curl.response'
EOF
  chmod +x "$TMPDIR_/bin/curl"
  FAKE_PATH="$TMPDIR_/bin:$PATH"
}

write_minimal_env() {
  cat > .env <<EOF
PB_APP_ID=app
PB_USER_KEY=key
PB_BOTNAME=bot
EOF
}

# run_pbtalk <stdin text, printf %b syntax>
# Runs pbtalk with a clean environment so only .env supplies configuration.
run_pbtalk() {
  run bash -c "printf '%b' '$1' | env -i PATH='$FAKE_PATH' PB_TALK_ENV_FILE='$PWD/.env' '$PBTALK'"
}

@test "pbtalk --version prints version" {
  run "$PBTALK" --version
  [ "$status" -eq 0 ]
  assert_starts_with "$output" "pbtalk"
}

@test "pbtalk --help prints help text" {
  run "$PBTALK" --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "Help:"
  assert_contains "$output" "<input>"
  assert_contains "$output" "--trace"
  assert_contains "$output" "--atalk"
}

@test "pbtalk rejects unknown option" {
  run "$PBTALK" --bogus
  [ "$status" -eq 2 ]
}

@test "pbtalk errors when PB_APP_ID is missing" {
  # Empty .env, no PB_APP_ID inherited.
  : > .env
  run env -i PATH="$PATH" PB_TALK_ENV_FILE="$PWD/.env" "$PBTALK"
  [ "$status" -eq 2 ]
  assert_contains "$output" "PB_APP_ID is not set"
}

@test "pbtalk errors when PB_USER_KEY is missing" {
  cat > .env <<EOF
PB_APP_ID=app
PB_BOTNAME=bot
EOF
  run env -i PATH="$PATH" PB_TALK_ENV_FILE="$PWD/.env" "$PBTALK"
  [ "$status" -eq 2 ]
  assert_contains "$output" "PB_USER_KEY is not set"
}

@test "pbtalk errors when PB_BOTNAME is missing" {
  cat > .env <<EOF
PB_APP_ID=app
PB_USER_KEY=key
EOF
  run env -i PATH="$PATH" PB_TALK_ENV_FILE="$PWD/.env" "$PBTALK"
  [ "$status" -eq 2 ]
  assert_contains "$output" "PB_BOTNAME is not set"
}

@test "pbtalk exits cleanly on EOF" {
  cat > .env <<EOF
PB_APP_ID=app
PB_USER_KEY=key
PB_BOTNAME=bot
EOF
  run bash -c "echo 'q' | env PB_TALK_ENV_FILE='$PWD/.env' '$PBTALK'"
  [ "$status" -eq 0 ]
  assert_contains "$output" "(h for help)"
}

# -------- .env parsing --------

@test ".env is parsed, not executed as shell code" {
  make_fake_curl
  cat > .env <<'EOF'
PB_APP_ID=app
PB_USER_KEY=key
PB_BOTNAME=bot
touch pwned_command
PB_SEG_CMD=$(touch pwned_substitution)
PB_HOST=`touch pwned_backtick`
EOF
  printf '%s' '{"status":"ok","responses":["hi"]}' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  [ ! -e pwned_command ]
  [ ! -e pwned_substitution ]
  [ ! -e pwned_backtick ]
  assert_contains "$output" ".env:4: not a KEY=VALUE line"
  grep -qF '`touch pwned_backtick`/talk/app/bot' curl.args
}

@test ".env parser handles quotes, comments, export, CRLF and a missing final newline" {
  make_fake_curl
  printf '%s\n' \
    '# full-line comment' \
    '' \
    '  export PB_APP_ID="my app"  ' \
    "PB_USER_KEY='k#1' # comment after a quoted value" \
    'PB_BOTNAME=bot[1-2] # comment after an unquoted value' \
    $'PB_HOST=https://example.test/\r' \
    'PB_CLIENT_NAME=cn' > .env
  printf '%s' 'PB_BOT_KEY=nolf' >> .env
  printf '%s' '{"status":"ok","responses":["hi"]}' > curl.response

  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  grep -qxF 'user_key=k#1' curl.args
  grep -qxF 'client_name=cn' curl.args
  grep -qxF 'https://example.test/talk/my app/bot[1-2]' curl.args

  run_pbtalk '--atalk hello\nq\n'
  [ "$status" -eq 0 ]
  grep -qxF 'botkey=nolf' curl.args
}

@test ".env parser warns about and ignores unknown keys" {
  make_fake_curl
  write_minimal_env
  printf 'FOO=bar\n' >> .env
  printf '%s' '{"status":"ok","responses":["hi"]}' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  assert_contains "$output" 'ignoring unknown key "FOO"'
  [ "$(grep -c '^FOO=' curl.env)" -eq 0 ]
}

@test ".env values are not exported to child processes" {
  make_fake_curl
  write_minimal_env
  printf '%s' '{"status":"ok","responses":["hi"]}' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  [ -s curl.env ]
  [ "$(grep -c '^PB_USER_KEY=' curl.env)" -eq 0 ]
  [ "$(grep -c '^PB_APP_ID=' curl.env)" -eq 0 ]
}

# -------- Request shape --------

@test "curl is invoked with --globoff" {
  make_fake_curl
  write_minimal_env
  printf '%s' '{"status":"ok","responses":["hi"]}' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  grep -qxF -- '--globoff' curl.args
  assert_contains "$output" "bot> hi"
}

# -------- Output sanitization --------

@test "control characters in bot responses are stripped" {
  make_fake_curl
  write_minimal_env
  # OSC title change + BEL, then a C1 CSI (U+009B); TAB and LF are kept.
  printf '%s' '{"status":"ok","responses":["\u001b]0;pwned\u0007hi\u009bx\tt\nnext"]}' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  assert_not_contains "$output" $'\033'
  assert_not_contains "$output" $'\a'
  assert_contains "$output" "bot> ]0;pwnedhix"$'\t'"t"
  [ "${lines[3]}" = "next" ]
}

@test "control characters in server error messages are stripped" {
  make_fake_curl
  write_minimal_env
  printf '%s' '{"status":"error","message":"\u001b[31mnope"}' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  assert_not_contains "$output" $'\033'
  assert_contains "$output" "Server: [31mnope"
}

@test "control characters in a non-JSON server body are stripped" {
  make_fake_curl
  write_minimal_env
  printf '<html>\033[2Jbad</html>' > curl.response
  run_pbtalk 'hello\nq\n'
  [ "$status" -eq 0 ]
  assert_not_contains "$output" $'\033'
  assert_contains "$output" "Server: <html>[2Jbad</html>"
}

@test "--trace output contains no control characters from trace fields" {
  make_fake_curl
  write_minimal_env
  printf '%s' '{"status":"ok","sessionid":"s\u001b1","responses":["ok"],"trace":[{"type":"match","level":0,"input":["\u001b[2Jx"],"template":"<template>\u001b]52;c;cHdu\u0007t</template>"}]}' > curl.response
  run_pbtalk '--trace hello\nq\n'
  [ "$status" -eq 0 ]
  assert_not_contains "$output" $'\033'
  assert_not_contains "$output" $'\a'
  assert_contains "$output" "sessionid=s1"
  assert_contains "$output" "template: ]52;c;cHdut"
}
