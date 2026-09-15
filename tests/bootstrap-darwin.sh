#!/usr/bin/env bash

set -euo pipefail

# This file also supplies isolated command stubs. All app/CLI installation
# targets and agent sockets are temporary fixtures; no stub uses the real
# network, sudo, agent, Nix, or private-config helper.
stub_stage() {
  printf '%s\n' "$1" >>"$STUB_LOG"
  [[ "${STUB_FAIL_STAGE:-}" != "$1" ]] || exit 1
}

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
    stub_stage clt-check
    exit 0
    ;;
  groups)
    printf '%s\n' "${STUB_GROUPS:-staff admin}"
    exit 0
    ;;
  ssh-add)
    [[ "$#" == 1 && "${1:-}" == -l ]] || exit 91
    [[ "${SSH_AUTH_SOCK:-}" == "$STUB_AGENT_SOCKET" ]] || exit 91
    stub_stage agent-check
    exit "${STUB_AGENT_STATUS:-0}"
    ;;
  op)
    [[ "$#" == 1 && "${1:-}" == --version ]] || {
      printf 'unexpected-op-invocation\n' >>"$STUB_LOG"
      exit 91
    }
    stub_stage cli-version
    printf '2.0.0-test\n'
    exit 0
    ;;
  open)
    [[ "$#" == 2 && "${1:-}" == -a && "${2:-}" == "$STUB_APP" ]] || exit 91
    [[ -d "$STUB_APP" ]] || exit 91
    stub_stage open-app
    exit 0
    ;;
  codesign)
    [[ "$#" == 4 && "$1" == --verify && "$2" == --deep && "$3" == --strict && "$4" == "$STUB_APP" ]] || exit 91
    stub_stage app-verify
    [[ -f "$STUB_APP/complete-fixture" ]] || exit 1
    exit 0
    ;;
  sudo)
    if [[ "$*" == -v ]]; then
      stub_stage sudo-auth
      exit 0
    fi
    case "${1:-}" in
      ditto | install)
        [[ "$(command -v "$1")" == "$STUB_BIN/$1" ]] || exit 91
        STUB_SUDO=1 "$@"
        exit $?
        ;;
      "$STUB_BIN/nix")
        stub_stage sudo-activation
        STUB_SUDO=1 "$@"
        exit $?
        ;;
      *) printf 'Unexpected sudo command: %s\n' "${1:-}" >&2; exit 91 ;;
    esac
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
    stub_stage nix-activation
    exit 0
    ;;
  private-config)
    [[ "${STUB_SUDO:-}" != 1 ]] || exit 91
    [[ "$*" == 'ensure matteing-mbp' ]] || exit 91
    [[ "${NIX_BIN:-}" == "$STUB_BIN/nix" ]] || exit 91
    [[ "${PRIVATE_IDENTITY:-}" == "$STUB_IDENTITY" ]] || exit 91
    [[ "${PRIVATE_IDENTITY_OP_REF:-}" == "${STUB_OP_REF:-}" ]] || exit 91
    stub_stage user-unlock
    exit "${STUB_UNLOCK_STATUS:-0}"
    ;;
  curl)
    if [[ "$*" == *'https://install.determinate.systems/nix'* ]]; then
      printf 'unexpected-nix-download\n' >>"$STUB_LOG"
      exit 91
    fi
    [[ $# -eq 12 && "$1" == --proto && "$2" == '=https' &&
      "$3" == --proto-redir && "$4" == '=https' && "$5" == --tlsv1.2 &&
      "$6" == --fail && "$7" == --silent && "$8" == --show-error &&
      "$9" == --location && "${11}" == --output ]] || exit 91
    archive="${12}"
    [[ "$archive" == "$STUB_TMP"/nix-bootstrap.*/* ]] || exit 91
    case "${10}" in
      "$STUB_APP_URL") kind=app ;;
      "$STUB_CLI_URL") kind=cli ;;
      *) printf 'unexpected-download\n' >>"$STUB_LOG"; exit 91 ;;
    esac
    stub_stage "download-$kind"
    printf '%s\n' "$kind" >"$archive"
    exit 0
    ;;
  shasum)
    [[ $# -eq 3 && "$1" == -a && "$2" == 256 ]] || exit 91
    [[ "$3" == "$STUB_TMP"/nix-bootstrap.*/* ]] || exit 91
    kind="$(<"$3")"
    case "$kind" in
      app) hash="$STUB_APP_HASH" ;;
      cli) hash="$STUB_CLI_HASH" ;;
      *) exit 91 ;;
    esac
    printf 'checksum-%s\n' "$kind" >>"$STUB_LOG"
    if [[ "${STUB_FAIL_STAGE:-}" == "checksum-$kind" ]]; then
      hash=0000000000000000000000000000000000000000000000000000000000000000
    fi
    printf '%s  %s\n' "$hash" "$3"
    exit 0
    ;;
  ditto)
    if [[ $# -eq 4 && "$1" == -x && "$2" == -k ]]; then
      [[ "${STUB_SUDO:-}" != 1 ]] || exit 91
      [[ "$3" == "$STUB_TMP"/nix-bootstrap.*/* && "$4" == "$STUB_TMP"/nix-bootstrap.*/* ]] || exit 91
      kind="$(<"$3")"
      case "$kind" in app | cli) ;; *) exit 91 ;; esac
      stub_stage "extract-$kind"
      if [[ "$kind" == app ]]; then
        /bin/mkdir -p "$4/1Password.app"
      else
        /bin/mkdir -p "$4"
        /bin/cp "$STUB_SCRIPT" "$4/op"
        /bin/chmod +x "$4/op"
      fi
    else
      [[ $# -eq 2 && "${STUB_SUDO:-}" == 1 ]] || exit 91
      [[ "$1" == "$STUB_TMP"/nix-bootstrap.*/*/1Password.app ]] || exit 91
      [[ -d "$1" && "$2" == "$STUB_APP" ]] || exit 91
      # A failed copy can still leave a destination directory. Only a completed
      # fixture receives the marker accepted by the codesign stub.
      /bin/mkdir -p "$STUB_APP"
      stub_stage install-app
      : >"$STUB_APP/complete-fixture"
    fi
    exit 0
    ;;
  install)
    [[ "${STUB_SUDO:-}" == 1 ]] || exit 91
    if [[ $# -eq 2 && "$1" == -d && "$2" == "$STUB_CLI_DIR" ]]; then
      stub_stage install-cli-dir
      /bin/mkdir -p "$STUB_CLI_DIR"
    else
      [[ $# -eq 4 && "$1" == -m && "$2" == 755 ]] || exit 91
      [[ "$3" == "$STUB_TMP"/nix-bootstrap.*/*/op && -f "$3" ]] || exit 91
      [[ "$4" == "$STUB_CLI_DIR/op" ]] || exit 91
      stub_stage install-cli
      /bin/cp "$3" "$4"
      /bin/chmod 755 "$4"
    fi
    exit 0
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
readonly STUB_APP="$TEST_ROOT/Applications with spaces/1Password.app"
readonly STUB_CLI_DIR="$TEST_ROOT/local bin"
readonly STUB_TMP="$TEST_ROOT/temporary downloads"
readonly STUB_AGENT_SOCKET="$TEST_ROOT/Group Containers/1Password/agent.sock"
readonly STUB_SCRIPT="$REPO_ROOT/tests/bootstrap-darwin.sh"
readonly STUB_VALID_OP_REF='op://Test Vault/Test identity/private key'
readonly STUB_APP_URL='https://downloads.1password.com/mac/1Password-8.12.36-aarch64.zip'
readonly STUB_APP_HASH='77d57273afbde862c814860623f0d1145fb85a73fb7e3202e2d1cc49a8372ce4'
readonly STUB_CLI_URL='https://cache.agilebits.com/dist/1P/op2/pkg/v2.39.0/op_darwin_arm64_v2.39.0.zip'
readonly STUB_CLI_HASH='05391d3388a0c0b4f602691bedc1ab368541c487b6f14d2e3399743b4682af67'
export STUB_BIN STUB_REPO STUB_LOG STUB_IDENTITY STUB_APP STUB_CLI_DIR STUB_TMP
export STUB_AGENT_SOCKET STUB_SCRIPT STUB_APP_URL STUB_APP_HASH STUB_CLI_URL STUB_CLI_HASH

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  if [[ -f "$TEST_ROOT/output.log" ]]; then
    sed -n '1,120p' "$TEST_ROOT/output.log" >&2
  fi
  if [[ -f "$STUB_LOG" ]]; then
    cat "$STUB_LOG" >&2
  fi
  exit 1
}

mkdir -p "$STUB_BIN" "$STUB_REPO/scripts" "$STUB_TMP"
cp "$REPO_ROOT/scripts/bootstrap-darwin.sh" "$STUB_REPO/scripts/bootstrap-darwin.sh"
for stub in uname id xcode-select groups ssh-add open codesign sudo nix curl shasum ditto install; do
  cp "$STUB_SCRIPT" "$STUB_BIN/$stub"
  chmod +x "$STUB_BIN/$stub"
done
cp "$STUB_SCRIPT" "$STUB_REPO/scripts/private-config"
chmod +x "$STUB_REPO/scripts/private-config"

reset_installed() {
  mkdir -p "$STUB_APP" "$STUB_CLI_DIR"
  : >"$STUB_APP/complete-fixture"
  cp "$STUB_SCRIPT" "$STUB_CLI_DIR/op"
  chmod +x "$STUB_CLI_DIR/op"
}

reset_missing() {
  rm -rf "$STUB_APP" "$STUB_CLI_DIR"
}

run_bootstrap() {
  local run_status=0 artifact
  : >"$STUB_LOG"
  # The restricted PATH and explicit installation/socket overrides keep all
  # operations within fixtures, even on an already-configured developer Mac.
  env -u EXPECTED_USER -u EXPECTED_ARCH -u HOST -u NIX_BIN -u STUB_SUDO \
    PATH="$STUB_BIN:/usr/bin:/bin" TMPDIR="$STUB_TMP" \
    PRIVATE_IDENTITY="$STUB_IDENTITY" PRIVATE_IDENTITY_OP_REF="${STUB_OP_REF:-}" \
    ONEPASSWORD_APP="$STUB_APP" ONEPASSWORD_CLI_DIR="$STUB_CLI_DIR" \
    SSH_AUTH_SOCK="$TEST_ROOT/unrelated-agent.sock" \
    ONEPASSWORD_SSH_AUTH_SOCK="$STUB_AGENT_SOCKET" \
    /bin/bash "$STUB_REPO/scripts/bootstrap-darwin.sh" >"$TEST_ROOT/output.log" 2>&1 || run_status=$?
  for artifact in "$STUB_TMP"/nix-bootstrap.*; do
    [[ ! -e "$artifact" ]] || fail 'Bootstrap left temporary installer files behind'
  done
  return "$run_status"
}

assert_before_nix() {
  local log
  log="$(<"$STUB_LOG")"
  [[ "$log" != *'user-unlock'* && "$log" != *'activation'* && "$log" != *'unexpected'* ]] ||
    fail "$1 reached Nix, private unlock, or an unexpected command"
}

expected_after_app=$'cli-version\nagent-check\nclt-check\nsudo-auth\nuser-unlock\nsudo-auth\nsudo-activation\nnix-activation'
expected_ready=$'app-verify\n'"$expected_after_app"
expected_app_install=$'download-app\nchecksum-app\nextract-app\ninstall-app\napp-verify'
expected_cli_install=$'download-cli\nchecksum-cli\nextract-cli\ninstall-cli-dir\ninstall-cli'
expected_install=$'sudo-auth\n'"$expected_app_install"$'\n'"$expected_cli_install"

reset_installed
run_bootstrap || fail 'Installed-prerequisite bootstrap did not complete with safe stubs'
[[ "$(<"$STUB_LOG")" == "$expected_ready" ]] || fail 'Installed prerequisites were reinstalled or command order changed'

STUB_OP_REF="$STUB_VALID_OP_REF" run_bootstrap || fail '1Password identity reference did not complete with the CLI available'
[[ "$(<"$STUB_LOG")" == "$expected_ready" ]] || fail 'Identity mode changed command order or retrieved a real key'

reset_missing
run_bootstrap || fail 'Installing both missing prerequisites failed'
[[ "$(<"$STUB_LOG")" == "$expected_install"$'\n'"$expected_after_app" ]] || fail 'Prerequisites were not installed and verified before Nix'
[[ -d "$STUB_APP" && -x "$STUB_CLI_DIR/op" ]] || fail 'Installer stubs did not create both prerequisites'

rm -rf "$STUB_APP"
run_bootstrap || fail 'Installing only the missing app failed'
[[ "$(<"$STUB_LOG")" == $'sudo-auth\n'"$expected_app_install"$'\n'"$expected_after_app" ]] || fail 'Existing CLI was not reused'

rm -rf "$STUB_CLI_DIR"
run_bootstrap || fail 'Installing only the missing CLI failed'
[[ "$(<"$STUB_LOG")" == $'sudo-auth\napp-verify\n'"$expected_cli_install"$'\n'"$expected_after_app" ]] || fail 'Existing app was not reused'

reset_missing
if STUB_AGENT_STATUS=1 run_bootstrap; then fail 'Unset agent did not stop bootstrap after installing prerequisites'; fi
[[ "$(<"$STUB_LOG")" == "$expected_install"$'\ncli-version\nagent-check\nopen-app' ]] || fail 'Agent setup was not requested before Nix'
[[ "$(<"$TEST_ROOT/output.log")" == *'Settings > Developer'*'SSH key'* ]] || fail 'Agent failure did not explain how to proceed'
assert_before_nix 'Agent setup failure'
run_bootstrap || fail 'Retry after agent setup did not complete'
[[ "$(<"$STUB_LOG")" == "$expected_ready" ]] || fail 'Retry downloaded or installed existing prerequisites'

if STUB_AGENT_STATUS=2 run_bootstrap; then fail 'Unreachable agent did not stop bootstrap'; fi
[[ "$(<"$STUB_LOG")" == $'app-verify\ncli-version\nagent-check\nopen-app' ]] || fail 'Unreachable agent reached privileged operations'

for stage in download-app checksum-app extract-app install-app app-verify download-cli checksum-cli extract-cli install-cli-dir install-cli cli-version; do
  reset_missing
  if STUB_FAIL_STAGE="$stage" run_bootstrap; then fail "Failure at $stage did not stop bootstrap"; fi
  [[ "$(<"$STUB_LOG")" == *"$stage"* ]] || fail "Failure at $stage was not exercised"
  assert_before_nix "Failure at $stage"
done

reset_installed
if STUB_FAIL_STAGE=app-verify run_bootstrap; then fail 'Invalid existing app signature did not stop bootstrap'; fi
[[ "$(<"$STUB_LOG")" == app-verify ]] || fail 'Invalid existing app signature reached privileged operations'

reset_missing
if STUB_FAIL_STAGE=install-app run_bootstrap; then fail 'Failed app copy did not stop bootstrap'; fi
[[ -d "$STUB_APP" && ! -f "$STUB_APP/complete-fixture" ]] || fail 'Partial app installation was not exercised'
if run_bootstrap; then fail 'Retry accepted a partial app installation'; fi
[[ "$(<"$STUB_LOG")" == $'sudo-auth\napp-verify' ]] || fail 'Partial app retry reached CLI installation or Nix'
[[ "$(<"$TEST_ROOT/output.log")" == *'incomplete'*'repair'* ]] || fail 'Partial app retry did not explain how to proceed'

reset_missing
if STUB_OP_REF='invalid-reference' run_bootstrap; then fail 'Invalid identity reference did not stop bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Invalid identity reference reached downloads or privileged operations'
[[ "$(<"$TEST_ROOT/output.log")" == *'op://'* ]] || fail 'Invalid identity reference did not explain its required format'

reset_installed
if STUB_UNLOCK_STATUS=1 run_bootstrap; then fail 'Failed unlocking did not stop bootstrap'; fi
[[ "$(<"$STUB_LOG")" == $'app-verify\ncli-version\nagent-check\nclt-check\nsudo-auth\nuser-unlock' ]] || fail 'Failed unlocking reached activation'

reset_missing
if STUB_OS=Linux run_bootstrap; then fail 'Linux entered the macOS bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Linux reached privileged operations'
if STUB_ARCH=x86_64 run_bootstrap; then fail 'Wrong architecture entered bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Wrong architecture reached privileged operations'
if STUB_USER=someone-else run_bootstrap; then fail 'Wrong user entered bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Wrong user reached privileged operations'
if STUB_GROUPS=staff run_bootstrap; then fail 'Non-administrator entered bootstrap'; fi
[[ ! -s "$STUB_LOG" ]] || fail 'Non-administrator reached privileged operations'

printf 'PASS: macOS bootstrap prerequisite installs, checksums, retries, failure stops, agent setup, pinned activation, platform/account guards, and cleanup (stubbed; no real installation or activation)\n'
