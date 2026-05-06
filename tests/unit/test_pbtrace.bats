#!/usr/bin/env bats

setup() {
  PBTRACE="${BATS_TEST_DIRNAME}/../../bin/pbtrace"
}

@test "pbtrace --version prints version" {
  run "$PBTRACE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^pbtrace ]]
}

@test "pbtrace --help prints usage" {
  run "$PBTRACE" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ Usage ]]
}

@test "pbtrace rejects unknown option" {
  run "$PBTRACE" --bogus
  [ "$status" -eq 2 ]
}

@test "pbtrace errors on empty stdin" {
  run bash -c "echo -n '' | '$PBTRACE' --no-color"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "empty input" ]]
}

@test "pbtrace errors on non-JSON input" {
  run bash -c "echo 'not json' | '$PBTRACE' --no-color"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "not valid JSON" ]]
}

@test "pbtrace renders header for ok response without trace" {
  run bash -c "echo '{\"status\":\"ok\",\"sessionid\":42,\"responses\":[\"hi\"]}' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[trace] sessionid=42 status=ok" ]]
  [[ "$output" =~ "(no trace data)" ]]
  [[ "$output" =~ "steps=0 responses=1" ]]
}

@test "pbtrace renders steps using the real Pandorabots schema" {
  json='{"status":"ok","sessionid":7,"responses":["hi"],"trace":[{"type":"begin","level":0,"input":["hello","<that>","unknown","<topic>","unknown"]},{"type":"match","level":0,"input":["hello","<that>","unknown","<topic>","unknown"],"matched":["HELLO"],"template":"<template>hi</template>","filename":"sample.aiml","status":"ok"},{"type":"end","level":0,"result":["hi"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "▸ begin" ]]
  [[ "$output" =~ "input: hello <that> unknown <topic> unknown" ]]
  [[ "$output" =~ "▸ match" ]]
  [[ "$output" =~ "matched: HELLO" ]]
  [[ "$output" =~ "template: hi" ]]
  [[ "$output" =~ "filename: sample.aiml" ]]
  [[ "$output" =~ "status: ok" ]]
  [[ "$output" =~ "▸ end" ]]
  [[ "$output" =~ "result: hi" ]]
  [[ "$output" =~ "steps=3" ]]
}

@test "pbtrace strips <template> wrapper tags" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"match","level":0,"matched":["X"],"template":"<template>plain text</template>"}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "template: plain text" ]]
  [[ ! "$output" =~ "<template>" ]]
}

@test "pbtrace shows level indentation and srai-begin/srai-end for nested steps" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"srai-begin","level":1,"input":["X"]},{"type":"match","level":1,"matched":["X"],"template":"<template>y</template>"},{"type":"srai-end","level":1,"result":["y"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "▸ srai-begin level=1" ]]
  [[ "$output" =~ "▸ srai-end level=1" ]]
  [[ "$output" =~ "result: y" ]]
}

@test "pbtrace renders sraix-begin with bot field" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"sraix-begin","level":0,"input":["x"],"bot":"external-bot"},{"type":"sraix-end","level":0,"result":["external response"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "▸ sraix-begin" ]]
  [[ "$output" =~ "bot: external-bot" ]]
  [[ "$output" =~ "▸ sraix-end" ]]
  [[ "$output" =~ "result: external response" ]]
}

@test "pbtrace filters whitespace-only entries from result arrays" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"end","level":0,"result":["hello",""," ","\n","world"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "result: hello world" ]]
}

@test "pbtrace honors NO_COLOR env" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"match","level":0,"matched":["X"]}]}'
  NO_COLOR=1 run bash -c "printf '%s' '$json' | '$PBTRACE'"
  [ "$status" -eq 0 ]
  # Output must not contain ESC (\033) when NO_COLOR is set.
  [[ ! "$output" =~ $'\033' ]]
}

@test "pbtrace handles error status responses" {
  run bash -c "echo '{\"status\":\"error\",\"message\":\"nope\"}' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "status=error" ]]
}
