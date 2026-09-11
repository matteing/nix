#!/usr/bin/env bash

set -euo pipefail

# This file also supplies the isolated command stubs. No stub invokes sudo,
# Nix, an installer, or the real private-config helper.
case "${0##*/}" in
  uname)
    case "${1:-}" in
      -s) printf '%s\n' "${STUB_OS:-Darwin}" ;;
      -m) printf '%s\n' "${STUB_ARCH:-arm64}" ;;
      *) exit 91 ;;
    esac
    exit 0
    ;;
  id)
    [[ "${1:-}" == -un ]] || exit 91
    printf '%s\n' "${STUB_USER:-sergio}"
    exit 0
    ;;
  xcode-select)
    [[ "${1:-}" == -p ]] || exit 91
    exit 0
    ;;
  groups)
    printf 'staff admin\n'
    exit 0
    ;;
  sudo)
    if [[ "$*" == -v ]]; then
      printf 'sudo-auth\n' >>"$STUB_LOG"
      exit 0
    fi
    [[ "${1:-}" == "$STUB_BIN/nix" ]] || exit 91
    printf 'sudo-activation\n' >>"$STUB_LOG"
    STUB_SUDO=1 "$@"
    exit 0
    ;;
  nix)
    [[ "${STUB_SUDO:-}" == 1 ]] || { printf 'Nix did not run through the sudo stub.\n' >&2; exit 91; }
    expected=(--extra-experimental-features 'nix-command flakes' run
      --no-write-lock-file --inputs-from "path:$STUB_REPO" nix-darwin#darwin-rebuild
      -- switch --flake "path:$STUB_REPO#matteing-mbp")
    [[ $# -eq ${#expected[@]} ]] || { printf 'Unexpected Nix argument count: %s\n' "$#" >&2; exit 91; }
    index=0
    for argument in "$@"; do
      [[ "$argument" == "${expected[$index]}" ]] || {
        printf 'Unexpected Nix argument %s: <%s> (expected <%s>)\n' "$index" "$argument" "${expected[$index]}" >&2
        exit 91
      }
      index=$((index + 1))
    done
    printf 'nix-activation\n' >>"$STUB_LOG"
    exit 0
    ;;
  private-config)
    [[ "${STUB_SUDO:-}" != 1 ]] || exit 91
    [[ "$*" == 'ensure matteing-mbp' ]] || exit 91
    [[ "${NIX_BIN:-}" == "$STUB_BIN/nix" ]] || exit 91
    [[ "${PRIVATE_IDENTITY:-}" == "$STUB_IDENTITY" ]] || exit 91
    printf 'user-unlock\n' >>"$STUB_LOG"
    exit "${STUB_UNLOCK_STATUS:-0}"
    ;;
  curl)
    printf 'FAIL: bootstrap tried to download an installer.\n' >&2
    exit 91
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO_ROOT
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-darwin.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

readonly STUB_BIN="$TEST_ROOT/bin"
readonly STUB_REPO="$TEST_ROOT/repo with spaces"
readonly STUB_LOG="$TEST_ROOT/commands.log"
readonly STUB_IDENTITY="$TEST_ROOT/nonexistent-private-key"
export STUB_BIN STUB_REPO STUB_LOG STUB_IDENTITY

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  if [[ -f "$TEST_ROOT/output.log" ]]; then
    sed -n '1,120p' "$TEST_ROOT/output.log" >&2
  fi
  exit 1
}

mkdir -p "$STUB_BIN" "$STUB_REPO/scripts"
cp "$REPO_ROOT/scripts/bootstrap-darwin.sh" "$STUB_REPO/scripts/bootstrap-darwin.sh"
for stub in uname id xcode-select groups sudo nix curl; do
  cp "$REPO_ROOT/tests/bootstrap-darwin.sh" "$STUB_BIN/$stub"
  chmod +x "$STUB_BIN/$stub"
done
cp "$REPO_ROOT/tests/bootstrap-darwin.sh" "$STUB_REPO/scripts/private-config"
chmod +x "$STUB_REPO/scripts/private-config"

run_bootstrap() {
  : >"$STUB_LOG"
  # A restricted PATH guarantees the fake commands win, even on configured
  # developer machines. The nonexistent identity is forwarded, never read.
  env -u EXPECTED_USER -u EXPECTED_ARCH -u HOST -u NIX_BIN -u STUB_SUDO \
    PATH="$STUB_BIN:/usr/bin:/bin" PRIVATE_IDENTITY="$STUB_IDENTITY" \
    /bin/bash "$STUB_REPO/scripts/bootstrap-darwin.sh" >"$TEST_ROOT/output.log" 2>&1
}

run_bootstrap || fail 'Nix-present bootstrap did not complete with safe stubs'
expected_log=$'sudo-auth\nuser-unlock\nsudo-auth\nsudo-activation\nnix-activation'
[[ "$(<"$STUB_LOG")" == "$expected_log" ]] || fail 'Bootstrap command order changed'

if STUB_UNLOCK_STATUS=1 run_bootstrap; then
  fail 'Failed unlocking did not stop bootstrap'
fi
[[ "$(<"$STUB_LOG")" == $'sudo-auth\nuser-unlock' ]] || fail 'Failed unlocking reached activation'

if STUB_OS=Linux run_bootstrap; then fail 'Linux entered the macOS bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Linux reached privileged operations'
if STUB_ARCH=x86_64 run_bootstrap; then fail 'Wrong architecture entered bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Wrong architecture reached privileged operations'
if STUB_USER=someone-else run_bootstrap; then fail 'Wrong user entered bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Wrong user reached privileged operations'

printf 'PASS: macOS bootstrap ordering, pinned input, root activation, unlock failures, platform/account guards, and paths with spaces (stubbed; no installation or activation)\n'
