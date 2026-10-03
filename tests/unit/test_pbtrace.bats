#!/usr/bin/env bats

load 'helpers'

setup() {
  PBTRACE="${BATS_TEST_DIRNAME}/../../bin/pbtrace"
}

@test "pbtrace --version prints version" {
  run "$PBTRACE" --version
  [ "$status" -eq 0 ]
  assert_starts_with "$output" "pbtrace"
}

@test "pbtrace --help prints usage" {
  run "$PBTRACE" --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "Usage"
}

@test "pbtrace rejects unknown option" {
  run "$PBTRACE" --bogus
  [ "$status" -eq 2 ]
}

@test "pbtrace errors on empty stdin" {
  run bash -c "echo -n '' | '$PBTRACE' --no-color"
  [ "$status" -eq 2 ]
  assert_contains "$output" "empty input"
}

@test "pbtrace errors on non-JSON input" {
  run bash -c "echo 'not json' | '$PBTRACE' --no-color"
  [ "$status" -eq 2 ]
  assert_contains "$output" "not valid JSON"
}

@test "pbtrace renders header for ok response without trace" {
  run bash -c "echo '{\"status\":\"ok\",\"sessionid\":42,\"responses\":[\"hi\"]}' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "[trace] sessionid=42 status=ok"
  assert_contains "$output" "(no trace data)"
  assert_contains "$output" "steps=0 responses=1"
}

@test "pbtrace renders steps using the real Pandorabots schema" {
  json='{"status":"ok","sessionid":7,"responses":["hi"],"trace":[{"type":"begin","level":0,"input":["hello","<that>","unknown","<topic>","unknown"]},{"type":"match","level":0,"input":["hello","<that>","unknown","<topic>","unknown"],"matched":["HELLO"],"template":"<template>hi</template>","filename":"sample.aiml","status":"ok"},{"type":"end","level":0,"result":["hi"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "▸ begin"
  assert_contains "$output" "input: hello <that> unknown <topic> unknown"
  assert_contains "$output" "▸ match"
  assert_contains "$output" "matched: HELLO"
  assert_contains "$output" "template: hi"
  assert_contains "$output" "filename: sample.aiml"
  assert_contains "$output" "status: ok"
  assert_contains "$output" "▸ end"
  assert_contains "$output" "result: hi"
  assert_contains "$output" "steps=3"
}

@test "pbtrace strips <template> wrapper tags" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"match","level":0,"matched":["X"],"template":"<template>plain text</template>"}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "template: plain text"
  assert_not_contains "$output" "<template>"
}

@test "pbtrace shows level indentation and srai-begin/srai-end for nested steps" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"srai-begin","level":1,"input":["X"]},{"type":"match","level":1,"matched":["X"],"template":"<template>y</template>"},{"type":"srai-end","level":1,"result":["y"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "▸ srai-begin level=1"
  assert_contains "$output" "▸ srai-end level=1"
  assert_contains "$output" "result: y"
}

@test "pbtrace renders sraix-begin with bot field" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"sraix-begin","level":0,"input":["x"],"bot":"external-bot"},{"type":"sraix-end","level":0,"result":["external response"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "▸ sraix-begin"
  assert_contains "$output" "bot: external-bot"
  assert_contains "$output" "▸ sraix-end"
  assert_contains "$output" "result: external response"
}

@test "pbtrace filters whitespace-only entries from result arrays" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"end","level":0,"result":["hello",""," ","\n","world"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "result: hello world"
}

@test "pbtrace honors NO_COLOR env" {
  json='{"status":"ok","sessionid":1,"trace":[{"type":"match","level":0,"matched":["X"]}]}'
  NO_COLOR=1 run bash -c "printf '%s' '$json' | '$PBTRACE'"
  [ "$status" -eq 0 ]
  # Output must not contain ESC (\033) when NO_COLOR is set.
  assert_not_contains "$output" $'\033'
}

@test "pbtrace handles error status responses" {
  run bash -c "echo '{\"status\":\"error\",\"message\":\"nope\"}' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_contains "$output" "status=error"
}

@test "pbtrace strips control characters from server-supplied fields" {
  json='{"status":"ok","sessionid":"s\u001b1","trace":[{"type":"ma\u001btch","level":0,"input":["\u001b[2Jx"],"template":"<template>\u001b]52;c;cHdu\u0007t</template>","result":["r\u009b"]}]}'
  run bash -c "printf '%s' '$json' | '$PBTRACE' --no-color"
  [ "$status" -eq 0 ]
  assert_not_contains "$output" $'\033'
  assert_not_contains "$output" $'\a'
  assert_contains "$output" "sessionid=s1"
  assert_contains "$output" "▸ match"
  assert_contains "$output" "input: [2Jx"
  assert_contains "$output" "template: ]52;c;cHdut"
  assert_contains "$output" "result: r"
}
