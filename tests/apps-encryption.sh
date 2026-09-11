#!/usr/bin/env bash

set -euo pipefail

# Fixtures must not inherit a developer's real key or recipient overrides.
unset APPS_IDENTITY APPS_RECIPIENTS_FILE PRIVATE_IDENTITY PRIVATE_RECIPIENTS_FILE HOST NIX_BIN

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
command -v age >/dev/null || { printf 'Tests require age in PATH.\n' >&2; exit 1; }
command -v age-keygen >/dev/null || { printf 'Tests require age-keygen in PATH.\n' >&2; exit 1; }
command -v ssh-keygen >/dev/null || { printf 'Tests require ssh-keygen in PATH.\n' >&2; exit 1; }
AGE_BIN="$(command -v age)"
readonly AGE_BIN
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/apps-encryption.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
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
assert_private_mode() {
  local path mode
  for path in "$@"; do
    if [[ "$(uname -s)" == Darwin ]]; then
      mode="$(stat -f '%Lp' "$path")"
    else
      mode="$(stat -c '%a' "$path")"
    fi
    [[ "$mode" == 600 ]] || fail "Permissions for $path are $mode instead of 600"
  done
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

test_identity="$TEST_ROOT/missing-identity"
run_apps encrypt
test_identity="$IDENTITY"
[[ -s "$CIPHER" && -s "$HOST_DIR/apps.local.state" ]] || fail 'Encryption did not create ciphertext and receipt'
assert_private_mode "$PLAIN" "$HOST_DIR/apps.local.state"
age --decrypt -i "$IDENTITY" -o "$TEST_ROOT/roundtrip.nix" "$CIPHER"
cmp -s "$TEST_ROOT/original.nix" "$TEST_ROOT/roundtrip.nix" || fail 'Encryption roundtrip changed the module'
rm "$PLAIN"
run_apps ensure
cmp -s "$TEST_ROOT/original.nix" "$PLAIN" || fail 'Ensure did not restore the module'
assert_private_mode "$PLAIN" "$HOST_DIR/apps.local.state"

printf '\n# Local work in progress\n' >>"$PLAIN"
cp "$PLAIN" "$TEST_ROOT/edited.nix"
run_apps ensure
run_apps unlock
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
[[ "$(<"$TEST_ROOT/failure.log")" == *'outside the repository'* ]] || fail 'Symlink rejection did not reach identity boundary check'
ln -s "$FIXTURE" "$TEST_ROOT/repo-link"
test_identity="$TEST_ROOT/repo-link/identity.in-repo"
expect_failure run_apps ensure
[[ "$(<"$TEST_ROOT/failure.log")" == *'outside the repository'* ]] || fail 'A directory symlink bypassed the identity boundary check'
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
assert_private_mode "$NETWORK_PLAIN" "$NETWORK_DIR/network.local.state"
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

# A clone starts with only public files. A deliberately minimal PATH models a
# stock machine: no age, Nix, realpath, or GNU sha256sum; BSD shasum is sufficient.
readonly FRESH="$TEST_ROOT/fresh clone"
readonly FRESH_DIR="$FRESH/hosts/matteing-mbp"
readonly FRESH_PLAIN="$FRESH_DIR/apps.local.nix"
readonly FRESH_STATE="$FRESH_DIR/apps.local.state"
readonly BASE_BIN="$TEST_ROOT/base-bin"
readonly POISON_BIN="$TEST_ROOT/poison-bin"
mkdir -p "$FRESH/scripts" "$FRESH_DIR" "$FRESH/keys" "$BASE_BIN" "$POISON_BIN"
cp "$FIXTURE/scripts/private-config" "$FRESH/scripts/private-config"
cp "$CIPHER" "$FRESH_DIR/apps.nix.age"
cp "$FIXTURE/keys/sergio.pub" "$FRESH/keys/sergio.pub"
for utility in bash dirname cp chmod mktemp mv rm rmdir awk readlink shasum; do
  utility_path="$(command -v "$utility")" || fail "Test fixture requires $utility"
  ln -s "$utility_path" "$BASE_BIN/$utility"
done
[[ ! -e "$FRESH_PLAIN" && ! -e "$FRESH_STATE" ]] || fail 'Fresh fixture was already unlocked'
PATH="$BASE_BIN" PRIVATE_IDENTITY="$IDENTITY" expect_failure "$BASH" "$FRESH/scripts/private-config" unlock
[[ "$(<"$TEST_ROOT/failure.log")" == *'age and Nix are unavailable. Install age'* ]] || fail 'Missing tools did not give installation guidance'
[[ ! -e "$FRESH_PLAIN" && ! -e "$FRESH_STATE" ]] || fail 'Missing tools created local files'
assert_atomic "$FRESH_DIR"

# A fake Nix launcher checks the complete bootstrap invocation and delegates to
# real age. It proves the fallback does not require global flakes configuration.
cat >"$TEST_ROOT/nix-launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -ge 6 && "$1" == --extra-experimental-features && "$2" == 'nix-command flakes' ]]
shift 2
[[ "$1" == run && "$2" == --no-write-lock-file && "$3" == "path:$TEST_FIXTURE#age" && "$4" == -- ]]
shift 4
printf 'called\n' >>"$TEST_NIX_LOG"
exec "$TEST_AGE_BIN" "$@"
EOF
chmod +x "$TEST_ROOT/nix-launcher"
export TEST_FIXTURE="$FRESH" TEST_AGE_BIN="$AGE_BIN" TEST_NIX_LOG="$TEST_ROOT/nix.log"
mkdir "$TEST_ROOT/key-links"
ln -s ../identity "$TEST_ROOT/key-links/key"
ln -s key "$TEST_ROOT/key-links/key-again"
ln -s key-links "$TEST_ROOT/key-directory"
PATH="$BASE_BIN" NIX_BIN="$TEST_ROOT/nix-launcher" PRIVATE_IDENTITY="$TEST_ROOT/key-directory/key-again" "$BASH" "$FRESH/scripts/private-config" unlock
[[ -s "$TEST_NIX_LOG" ]] || fail 'Unlock did not invoke the Nix fallback'
cmp -s "$PLAIN" "$FRESH_PLAIN" || fail 'Fresh fallback unlock changed plaintext'
assert_private_mode "$FRESH_PLAIN" "$FRESH_STATE"
assert_atomic "$FRESH_DIR"

# Subsequent use needs neither a private key nor an encryption program, even
# with local edits. Poison launchers must not be invoked or prompt for anything.
cat >"$POISON_BIN/age" <<'EOF'
#!/usr/bin/env bash
printf 'unexpected invocation\n' >>"$TEST_POISON_LOG"
exit 99
EOF
chmod +x "$POISON_BIN/age"
ln -s age "$POISON_BIN/nix"
export TEST_POISON_LOG="$TEST_ROOT/poison.log"
printf '\n# Fresh checkout local edit\n' >>"$FRESH_PLAIN"
cp "$FRESH_PLAIN" "$TEST_ROOT/fresh-edited.nix"
for action in ensure unlock ensure; do
  chmod 644 "$FRESH_PLAIN" "$FRESH_STATE"
  PATH="$POISON_BIN:$BASE_BIN" PRIVATE_IDENTITY="$TEST_ROOT/no-private-key" "$BASH" "$FRESH/scripts/private-config" "$action"
  assert_private_mode "$FRESH_PLAIN" "$FRESH_STATE"
done
[[ ! -e "$TEST_POISON_LOG" ]] || fail 'An unlocked checkout invoked age or Nix'
cmp -s "$TEST_ROOT/fresh-edited.nix" "$FRESH_PLAIN" || fail 'Repeated unlock lost local edits'
PATH="$BASE_BIN" PRIVATE_IDENTITY="$TEST_ROOT/no-private-key" "$BASH" "$FRESH/scripts/private-config" ensure

# Saving edits also needs no private key: just the public recipients and age,
# supplied here by Nix. sha256sum is absent throughout this fresh-clone test.
PATH="$BASE_BIN" NIX_BIN="$TEST_ROOT/nix-launcher" PRIVATE_IDENTITY="$TEST_ROOT/no-private-key" "$BASH" "$FRESH/scripts/private-config" encrypt
"$AGE_BIN" --decrypt -i "$IDENTITY" -o "$TEST_ROOT/fresh-roundtrip.nix" "$FRESH_DIR/apps.nix.age"
cmp -s "$TEST_ROOT/fresh-edited.nix" "$TEST_ROOT/fresh-roundtrip.nix" || fail 'Public-only fallback encryption changed plaintext'
read -r fresh_cipher_digest fresh_plain_digest <"$FRESH_STATE"
[[ "$fresh_cipher_digest" == "$(shasum -a 256 "$FRESH_DIR/apps.nix.age" | awk '{ print $1 }')" ]] || fail 'Ciphertext receipt hash is stale'
[[ "$fresh_plain_digest" == "$(shasum -a 256 "$FRESH_PLAIN" | awk '{ print $1 }')" ]] || fail 'Plaintext receipt hash is stale'
assert_private_mode "$FRESH_PLAIN" "$FRESH_STATE"
assert_atomic "$FRESH_DIR"

# A hash command can print a plausible hash and still fail. Neither the first
# nor second receipt hash may be ignored before publishing decrypted/encrypted
# content. Let the initial synchronization check succeed and fail on temp files.
readonly BAD_HASH_BIN="$TEST_ROOT/bad-hash-bin"
mkdir "$BAD_HASH_BIN"
cat >"$BAD_HASH_BIN/sha256sum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
"$TEST_SHASUM_BIN" -a 256 "$1"
case "$1" in
  */.apps-tmp.*/"$TEST_HASH_TARGET") exit 77 ;;
esac
EOF
chmod +x "$BAD_HASH_BIN/sha256sum"
TEST_SHASUM_BIN="$(command -v shasum)"
export TEST_SHASUM_BIN
cp "$FRESH_DIR/apps.nix.age" "$TEST_ROOT/before-hash-failure.age"
cp "$FRESH_STATE" "$TEST_ROOT/before-hash-failure.state"
for hash_target in content input; do
  PATH="$BAD_HASH_BIN:$BASE_BIN" NIX_BIN="$TEST_ROOT/nix-launcher" TEST_HASH_TARGET="$hash_target" PRIVATE_IDENTITY="$TEST_ROOT/no-private-key" expect_failure "$BASH" "$FRESH/scripts/private-config" encrypt
  cmp -s "$TEST_ROOT/before-hash-failure.age" "$FRESH_DIR/apps.nix.age" || fail 'Failed receipt hash replaced ciphertext'
  cmp -s "$TEST_ROOT/before-hash-failure.state" "$FRESH_STATE" || fail 'Failed receipt hash replaced state'
  cmp -s "$TEST_ROOT/fresh-edited.nix" "$FRESH_PLAIN" || fail 'Failed receipt hash changed plaintext'
  assert_atomic "$FRESH_DIR"
done
rm "$FRESH_PLAIN"
for hash_target in content input; do
  PATH="$BAD_HASH_BIN:$BASE_BIN" NIX_BIN="$TEST_ROOT/nix-launcher" TEST_HASH_TARGET="$hash_target" PRIVATE_IDENTITY="$IDENTITY" expect_failure "$BASH" "$FRESH/scripts/private-config" unlock
  [[ ! -e "$FRESH_PLAIN" ]] || fail 'Failed receipt hash published plaintext'
  cmp -s "$TEST_ROOT/before-hash-failure.age" "$FRESH_DIR/apps.nix.age" || fail 'Failed unlock hash changed ciphertext'
  cmp -s "$TEST_ROOT/before-hash-failure.state" "$FRESH_STATE" || fail 'Failed unlock hash replaced state'
  assert_atomic "$FRESH_DIR"
done
PRIVATE_IDENTITY="$IDENTITY" "$BASH" "$FRESH/scripts/private-config" unlock

# Match the repository's recipient type with a disposable OpenSSH key. Only
# this synthetic test key is unprotected; real passphrases are never modified.
ssh-keygen -q -t ed25519 -N '' -C encryption-fixture -f "$TEST_ROOT/ssh-identity"
PRIVATE_IDENTITY="$TEST_ROOT/no-private-key" PRIVATE_RECIPIENTS_FILE="$TEST_ROOT/ssh-identity.pub" "$BASH" "$FRESH/scripts/private-config" encrypt
rm "$FRESH_PLAIN"
PRIVATE_IDENTITY="$TEST_ROOT/ssh-identity" "$BASH" "$FRESH/scripts/private-config" unlock
cmp -s "$TEST_ROOT/fresh-edited.nix" "$FRESH_PLAIN" || fail 'SSH-ed25519 roundtrip changed plaintext'
assert_private_mode "$FRESH_PLAIN" "$FRESH_STATE"
assert_atomic "$FRESH_DIR"

printf 'PASS: Mac and Linux-compatible age roundtrips, fresh clones, decrypt-once reuse, Nix/SHA fallbacks, host isolation, conflicts, permissions, and identity boundaries\n'
