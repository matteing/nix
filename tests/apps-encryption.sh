#!/usr/bin/env bash

set -euo pipefail

# Fixtures must not inherit a developer's real key or recipient overrides.
unset APPS_IDENTITY APPS_RECIPIENTS_FILE PRIVATE_IDENTITY PRIVATE_RECIPIENTS_FILE HOST

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
command -v age >/dev/null || { printf 'Tests require age in PATH.\n' >&2; exit 1; }
command -v age-keygen >/dev/null || { printf 'Tests require age-keygen in PATH.\n' >&2; exit 1; }
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/apps-encryption.XXXXXX")"
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT
readonly FIXTURE="$TEST_ROOT/repo with spaces"
readonly HOST_DIR="$FIXTURE/hosts/matteing-mbp"
readonly PLAIN="$HOST_DIR/apps.local.nix"
readonly CIPHER="$HOST_DIR/apps.nix.age"
readonly NETWORK_DIR="$FIXTURE/hosts/homelab"
readonly NETWORK_PLAIN="$NETWORK_DIR/network.local.nix"
readonly NETWORK_CIPHER="$NETWORK_DIR/network.nix.age"
readonly IDENTITY="$TEST_ROOT/identity"
readonly NETWORK_IDENTITY="$TEST_ROOT/network-identity"
test_identity="$IDENTITY"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
run_apps() { PRIVATE_IDENTITY='' APPS_IDENTITY="$test_identity" bash "$FIXTURE/scripts/apps" "$@"; }
run_private() { PRIVATE_IDENTITY="$test_identity" APPS_IDENTITY="$TEST_ROOT/ignored-identity" bash "$FIXTURE/scripts/private-config" "$@"; }
expect_failure() {
  if "$@" >"$TEST_ROOT/failure.log" 2>&1; then
    fail "Expected failure: $*"
  fi
}
assert_atomic() {
  local entry target_dir="${1:-$HOST_DIR}" stem="${2:-apps}"
  for entry in "$target_dir"/* "$target_dir"/.[!.]* "$target_dir"/..?*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    case "${entry##*/}" in
      "$stem.local.nix" | "$stem.local.state" | "$stem.nix.age") ;;
      *) fail "Unexpected leftover file: $entry" ;;
    esac
  done
}

mkdir -p "$FIXTURE/scripts" "$HOST_DIR" "$NETWORK_DIR" "$FIXTURE/keys"
cp "$REPO_ROOT/scripts/apps" "$FIXTURE/scripts/apps"
cp "$REPO_ROOT/scripts/private-config" "$FIXTURE/scripts/private-config"
chmod +x "$FIXTURE/scripts/apps" "$FIXTURE/scripts/private-config"
age-keygen -o "$IDENTITY" >/dev/null 2>&1
age-keygen -o "$TEST_ROOT/wrong-identity" >/dev/null 2>&1
age-keygen -o "$NETWORK_IDENTITY" >/dev/null 2>&1
age-keygen -y "$IDENTITY" >"$FIXTURE/keys/sergio.pub"
age-keygen -y "$NETWORK_IDENTITY" >"$TEST_ROOT/network-recipients.pub"
printf '{ ... }: { environment.systemPackages = []; }\n' >"$PLAIN"
cp "$PLAIN" "$TEST_ROOT/original.nix"

run_apps encrypt
[[ -s "$CIPHER" && -s "$HOST_DIR/apps.local.state" ]] || fail 'Encryption did not create ciphertext and receipt'
age --decrypt -i "$IDENTITY" -o "$TEST_ROOT/roundtrip.nix" "$CIPHER"
cmp -s "$TEST_ROOT/original.nix" "$TEST_ROOT/roundtrip.nix" || fail 'Encryption roundtrip changed the module'
rm "$PLAIN"
run_apps ensure
cmp -s "$TEST_ROOT/original.nix" "$PLAIN" || fail 'Ensure did not restore the module'
if [[ "$(uname -s)" == Darwin ]]; then
  mode="$(stat -f '%Lp' "$PLAIN")"
else
  mode="$(stat -c '%a' "$PLAIN")"
fi
[[ "$mode" == 600 ]] || fail "Plaintext permissions are $mode instead of 600"

printf '\n# Local work in progress\n' >>"$PLAIN"
cp "$PLAIN" "$TEST_ROOT/edited.nix"
run_apps ensure
run_apps unlock >/dev/null 2>&1 || true
cmp -s "$TEST_ROOT/edited.nix" "$PLAIN" || fail 'Ensure or unlock overwrote local edits'
run_apps encrypt
cp "$CIPHER" "$TEST_ROOT/saved.age"
APPS_RECIPIENTS_FILE="$TEST_ROOT/missing-recipients" expect_failure run_apps encrypt
cmp -s "$TEST_ROOT/saved.age" "$CIPHER" || fail 'Failed encryption damaged existing ciphertext'
assert_atomic

rm "$PLAIN"
test_identity="$TEST_ROOT/missing-identity"
expect_failure run_apps ensure
[[ ! -e "$PLAIN" ]] || fail 'Missing identity created plaintext'
assert_atomic
test_identity="$TEST_ROOT/wrong-identity"
expect_failure run_apps ensure
[[ ! -e "$PLAIN" ]] || fail 'Wrong identity created plaintext'
assert_atomic
test_identity="$IDENTITY"
printf 'Not valid age ciphertext\n' >"$CIPHER"
expect_failure run_apps ensure
[[ ! -e "$PLAIN" ]] || fail 'Invalid ciphertext created plaintext'
assert_atomic
truncated_size="$(( $(wc -c <"$TEST_ROOT/saved.age") - 24 ))"
dd if="$TEST_ROOT/saved.age" of="$CIPHER" bs=1 count="$truncated_size" 2>/dev/null
expect_failure run_apps ensure
[[ ! -e "$PLAIN" ]] || fail 'Truncated ciphertext created plaintext'
assert_atomic
cp "$TEST_ROOT/saved.age" "$CIPHER"
run_apps ensure
cmp -s "$TEST_ROOT/edited.nix" "$PLAIN" || fail 'Recovery after failed decrypt changed plaintext'

printf '{ ... }: { environment.systemPackages = []; }\n# Remote update\n' >"$TEST_ROOT/remote.nix"
age --encrypt -R "$FIXTURE/keys/sergio.pub" -o "$TEST_ROOT/remote.age" "$TEST_ROOT/remote.nix"
cp "$TEST_ROOT/remote.age" "$CIPHER"
run_apps ensure
cmp -s "$TEST_ROOT/remote.nix" "$PLAIN" || fail 'Changed ciphertext did not refresh clean plaintext'
printf '\n# Conflicting local edit\n' >>"$PLAIN"
cp "$PLAIN" "$TEST_ROOT/conflicting.nix"
printf '\n# Another remote update\n' >>"$TEST_ROOT/remote.nix"
age --encrypt -R "$FIXTURE/keys/sergio.pub" -o "$TEST_ROOT/conflicting.age" "$TEST_ROOT/remote.nix"
cp "$TEST_ROOT/conflicting.age" "$CIPHER"
expect_failure run_apps ensure
cmp -s "$TEST_ROOT/conflicting.nix" "$PLAIN" || fail 'Conflict handling overwrote local edits'
expect_failure run_apps encrypt
cmp -s "$TEST_ROOT/conflicting.age" "$CIPHER" || fail 'Encryption overwrote an unreviewed remote update'
assert_atomic

rm "$PLAIN"
run_apps ensure
cmp -s "$TEST_ROOT/remote.nix" "$PLAIN" || fail 'Explicit conflict recovery failed'
rm "$PLAIN"
cp "$IDENTITY" "$FIXTURE/identity.in-repo"
test_identity="$FIXTURE/identity.in-repo"
expect_failure run_apps ensure
[[ ! -e "$PLAIN" ]] || fail 'An in-repo identity was accepted'
ln -s "$FIXTURE/identity.in-repo" "$TEST_ROOT/identity-link"
test_identity="$TEST_ROOT/identity-link"
expect_failure run_apps ensure
[[ ! -e "$PLAIN" ]] || fail 'A symlink to an in-repo identity was accepted'
test_identity="$IDENTITY"
run_apps ensure
expect_failure run_apps unknown-command
assert_atomic

# Omitting the generic helper's host selects the Mac module.
rm "$PLAIN"
run_private ensure
cmp -s "$TEST_ROOT/remote.nix" "$PLAIN" || fail 'Generic default dispatch did not restore the Mac module'
[[ ! -e "$NETWORK_PLAIN" && ! -e "$NETWORK_CIPHER" ]] || fail 'Generic default dispatch touched homelab'
run_private ensure matteing-mbp
cp "$CIPHER" "$TEST_ROOT/mac-before-unknown.age"
expect_failure run_private encrypt unknown-host
cmp -s "$TEST_ROOT/mac-before-unknown.age" "$CIPHER" || fail 'Unknown host changed Mac ciphertext'
expect_failure run_private ensure ../matteing-mbp

# A separate recipient verifies PRIVATE_* overrides and host isolation.
printf '{ ... }: { networking.hostName = "homelab-fixture"; }\n' >"$NETWORK_PLAIN"
cp "$NETWORK_PLAIN" "$TEST_ROOT/network-original.nix"
test_identity="$NETWORK_IDENTITY"
APPS_RECIPIENTS_FILE="$TEST_ROOT/missing-recipients" PRIVATE_RECIPIENTS_FILE="$TEST_ROOT/network-recipients.pub" run_private encrypt homelab
[[ -s "$NETWORK_CIPHER" && -s "$NETWORK_DIR/network.local.state" ]] || fail 'Homelab encryption did not create ciphertext and receipt'
age --decrypt -i "$NETWORK_IDENTITY" -o "$TEST_ROOT/network-roundtrip.nix" "$NETWORK_CIPHER"
cmp -s "$TEST_ROOT/network-original.nix" "$TEST_ROOT/network-roundtrip.nix" || fail 'Homelab encryption roundtrip changed the module'
rm "$NETWORK_PLAIN"
run_private unlock homelab
cmp -s "$TEST_ROOT/network-original.nix" "$NETWORK_PLAIN" || fail 'Homelab unlock did not restore the module'
if [[ "$(uname -s)" == Darwin ]]; then
  mode="$(stat -f '%Lp' "$NETWORK_PLAIN")"
else
  mode="$(stat -c '%a' "$NETWORK_PLAIN")"
fi
[[ "$mode" == 600 ]] || fail "Homelab plaintext permissions are $mode instead of 600"
rm "$NETWORK_PLAIN"
test_identity="$TEST_ROOT/wrong-identity"
expect_failure run_private unlock homelab
[[ ! -e "$NETWORK_PLAIN" ]] || fail 'Wrong identity created homelab plaintext'
assert_atomic "$NETWORK_DIR" network
test_identity="$NETWORK_IDENTITY"
run_private ensure homelab
cmp -s "$TEST_ROOT/network-original.nix" "$NETWORK_PLAIN" || fail 'Homelab recovery after wrong key changed plaintext'
cmp -s "$TEST_ROOT/mac-before-unknown.age" "$CIPHER" || fail 'Homelab operations changed Mac ciphertext'

# The legacy apps wrapper remains pinned to Mac even when HOST is set.
rm "$PLAIN"
test_identity="$IDENTITY"
HOST=homelab run_apps ensure
cmp -s "$TEST_ROOT/remote.nix" "$PLAIN" || fail 'Apps wrapper followed HOST instead of selecting the Mac module'
cmp -s "$TEST_ROOT/network-original.nix" "$NETWORK_PLAIN" || fail 'Apps wrapper changed the homelab module'
assert_atomic
assert_atomic "$NETWORK_DIR" network

printf 'PASS: Mac and homelab age roundtrips, host dispatch, overrides, local edits, conflicts, atomic failures, permissions, and identity boundaries\n'
