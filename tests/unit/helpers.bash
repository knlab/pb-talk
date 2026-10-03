# Shared assertion helpers for the bats unit tests.
#
# Why not plain `[[ "$output" =~ ... ]]` lines? bash 3.2 (the default on
# macOS) does not abort a `set -e` function when a `[[ ... ]]` compound
# command fails, and bats relies on `set -e` to detect assertion failures.
# A failed `[[` assertion is therefore only noticed when it happens to be
# the last line of the test. These helpers return their verdict through a
# simple command, which every bash honors, and print what was expected so a
# failure is readable in the bats output.

# assert_contains <haystack> <needle>  (literal substring)
assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
  esac
  printf 'expected output to contain: %q\n' "$2" >&2
  return 1
}

# assert_not_contains <haystack> <needle>  (literal substring)
assert_not_contains() {
  case "$1" in
    *"$2"*)
      printf 'expected output NOT to contain: %q\n' "$2" >&2
      return 1
      ;;
  esac
  return 0
}

# assert_starts_with <string> <prefix>  (literal prefix)
assert_starts_with() {
  case "$1" in
    "$2"*) return 0 ;;
  esac
  printf 'expected output to start with: %q\n' "$2" >&2
  return 1
}
