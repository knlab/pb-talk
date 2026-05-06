#!/usr/bin/env bats

setup() {
  PBTALK="${BATS_TEST_DIRNAME}/../../bin/pbtalk"
  TMPDIR_=$(mktemp -d)
  cd "$TMPDIR_"
}

teardown() {
  rm -rf "$TMPDIR_"
}

@test "pbtalk --version prints version" {
  run "$PBTALK" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^pbtalk ]]
}

@test "pbtalk --help prints help text" {
  run "$PBTALK" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Help:" ]]
  [[ "$output" =~ "<input>" ]]
  [[ "$output" =~ "--trace" ]]
  [[ "$output" =~ "--atalk" ]]
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
  [[ "$output" =~ "PB_APP_ID is not set" ]]
}

@test "pbtalk errors when PB_USER_KEY is missing" {
  cat > .env <<EOF
PB_APP_ID=app
PB_BOTNAME=bot
EOF
  run env -i PATH="$PATH" PB_TALK_ENV_FILE="$PWD/.env" "$PBTALK"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "PB_USER_KEY is not set" ]]
}

@test "pbtalk errors when PB_BOTNAME is missing" {
  cat > .env <<EOF
PB_APP_ID=app
PB_USER_KEY=key
EOF
  run env -i PATH="$PATH" PB_TALK_ENV_FILE="$PWD/.env" "$PBTALK"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "PB_BOTNAME is not set" ]]
}

@test "pbtalk exits cleanly on EOF" {
  cat > .env <<EOF
PB_APP_ID=app
PB_USER_KEY=key
PB_BOTNAME=bot
EOF
  run bash -c "echo 'q' | env PB_TALK_ENV_FILE='$PWD/.env' '$PBTALK'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(h for help)" ]]
}
