#!/bin/bash

set -euo pipefail

readonly EXPECTED_USER="${EXPECTED_USER:-sergio}"
readonly EXPECTED_ARCH="${EXPECTED_ARCH:-arm64}"
readonly HOST="${HOST:-matteing-mbp}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly NIX_INSTALLER_URL="https://install.determinate.systems/nix"
# Full app archives retain automatic updates. Keep these versions and SHA-256
# values in sync with the upstream 1password and 1password-cli Homebrew casks.
readonly ONEPASSWORD_VERSION="8.12.36"
readonly ONEPASSWORD_CLI_VERSION="2.39.0"
scratch=""

cleanup() {
  if [[ -n "$scratch" ]]; then
    rm -rf -- "$scratch"
  fi
}
trap cleanup EXIT

ensure_scratch() {
  if [[ -z "$scratch" ]]; then
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/nix-bootstrap.XXXXXX")"
  fi
}

say() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\nError: %s\n' "$1" >&2
  exit 1
}

download_archive() {
  local name="$1" url="$2" expected_hash="$3" actual_hash
  ensure_scratch
  say "Downloading $name"
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --silent --show-error --location \
    "$url" --output "$scratch/$name.zip"
  actual_hash="$(shasum -a 256 "$scratch/$name.zip")"
  [[ "${actual_hash%% *}" == "$expected_hash" ]] || fail "$name download failed SHA-256 verification; nothing from that download was installed"
  ditto -x -k "$scratch/$name.zip" "$scratch/$name"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "this configuration only supports macOS"
fi

if [[ "$(uname -m)" != "$EXPECTED_ARCH" ]]; then
  fail "host '$HOST' expects architecture '$EXPECTED_ARCH' (current architecture: '$(uname -m)')"
fi

if [[ "$(id -un)" != "$EXPECTED_USER" ]]; then
  fail "this configuration expects the macOS account '$EXPECTED_USER' (current account: '$(id -un)')"
fi

if ! groups | grep -qE '(^|[[:space:]])admin($|[[:space:]])'; then
  fail "the current macOS account must be an administrator"
fi

if [[ -n "${PRIVATE_IDENTITY_OP_REF:-}" ]]; then
  [[ "$PRIVATE_IDENTITY_OP_REF" == op://* ]] || fail "PRIVATE_IDENTITY_OP_REF must be an op:// secret reference"
fi

case "$(uname -m)" in
  arm64)
    app_arch="aarch64"
    cli_arch="arm64"
    app_hash="77d57273afbde862c814860623f0d1145fb85a73fb7e3202e2d1cc49a8372ce4"
    cli_hash="05391d3388a0c0b4f602691bedc1ab368541c487b6f14d2e3399743b4682af67"
    ;;
  x86_64)
    app_arch="x86_64"
    cli_arch="amd64"
    app_hash="1f117efbe8ab79386be1bb881496f0cb7d4b82d51a07e17ee1166fb38cc08506"
    cli_hash="753fbf56b00996426edbb8439d2f3c0be9227b9557cdff468fb144cd3621aa6e"
    ;;
  *) fail "no 1Password bootstrap downloads are configured for this architecture" ;;
esac

# Install prerequisites without depending on Nix or Homebrew already existing.
onepassword_app="${ONEPASSWORD_APP:-/Applications/1Password.app}"
onepassword_cli_dir="${ONEPASSWORD_CLI_DIR:-/usr/local/bin}"
export PATH="$PATH:$onepassword_cli_dir"

if [[ ! -d "$onepassword_app" ]] || ! command -v op >/dev/null 2>&1; then
  say "Requesting administrator access to install 1Password prerequisites"
  sudo -v
fi

if [[ ! -d "$onepassword_app" ]]; then
  [[ ! -e "$onepassword_app" && ! -L "$onepassword_app" ]] || fail "the 1Password app destination already exists but is not an app directory"
  download_archive 1Password "https://downloads.1password.com/mac/1Password-$ONEPASSWORD_VERSION-$app_arch.zip" "$app_hash"
  [[ -d "$scratch/1Password/1Password.app" ]] || fail "the 1Password download did not contain 1Password.app"
  say "Installing 1Password"
  sudo ditto "$scratch/1Password/1Password.app" "$onepassword_app"
  [[ -d "$onepassword_app" ]] || fail "1Password installation did not create the app"
fi
# A failed copy can leave a directory behind. Do not mistake it for a complete
# installation on the next run or proceed with an invalid existing app bundle.
codesign --verify --deep --strict "$onepassword_app" >/dev/null 2>&1 ||
  fail "the 1Password app is incomplete or its code signature is invalid; repair the app at '$onepassword_app', then rerun 'make bootstrap'"

if ! command -v op >/dev/null 2>&1; then
  download_archive 1PasswordCLI "https://cache.agilebits.com/dist/1P/op2/pkg/v$ONEPASSWORD_CLI_VERSION/op_darwin_${cli_arch}_v$ONEPASSWORD_CLI_VERSION.zip" "$cli_hash"
  [[ -f "$scratch/1PasswordCLI/op" ]] || fail "the 1Password CLI download did not contain op"
  say "Installing 1Password CLI"
  sudo install -d "$onepassword_cli_dir"
  sudo install -m 755 "$scratch/1PasswordCLI/op" "$onepassword_cli_dir/op"
fi
op --version >/dev/null || fail "1Password CLI is installed but cannot run; repair it before continuing"

say "Checking the 1Password SSH agent"
onepassword_socket="${ONEPASSWORD_SSH_AUTH_SOCK:-$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
# Query 1Password directly: ssh-add does not read IdentityAgent from ssh/config,
# and the inherited SSH_AUTH_SOCK may point to Apple's unrelated default agent.
if ! SSH_AUTH_SOCK="$onepassword_socket" ssh-add -l >/dev/null 2>&1; then
  open -a "$onepassword_app" >/dev/null 2>&1 || true
  fail "1Password and its CLI are installed. Sign in and unlock 1Password, enable its SSH agent and 'Integrate with 1Password CLI' in Settings > Developer, and make an SSH key available to the agent; then run 'make bootstrap' again. Nix has not been installed by this run"
fi

if ! xcode-select -p >/dev/null 2>&1; then
  say "Xcode Command Line Tools are required"
  xcode-select --install 2>/dev/null || true
  fail "finish the Command Line Tools installation, then run 'make bootstrap' again"
fi

say "Requesting administrator access"
sudo -v

nix_bin="$(command -v nix || true)"
if [[ -z "$nix_bin" && -x /nix/var/nix/profiles/default/bin/nix ]]; then
  nix_bin="/nix/var/nix/profiles/default/bin/nix"
fi

if [[ -z "$nix_bin" ]]; then
  ensure_scratch
  installer="$scratch/nix-installer"

  say "Downloading the Determinate Nix installer"
  curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
    "$NIX_INSTALLER_URL" --output "$installer"

  say "Installing Nix"
  /bin/sh "$installer" install --no-confirm

  nix_bin="/nix/var/nix/profiles/default/bin/nix"
  [[ -x "$nix_bin" ]] || fail "Nix finished installing, but '$nix_bin' was not found"
else
  say "Nix is already installed"
fi

say "Unlocking private configuration for $HOST"
NIX_BIN="$nix_bin" "$REPO_ROOT/scripts/private-config" ensure "$HOST"

say "Applying the nix-darwin configuration for $HOST"
sudo -v
sudo "$nix_bin" --extra-experimental-features 'nix-command flakes' run \
  --no-write-lock-file --inputs-from "path:$REPO_ROOT" nix-darwin#darwin-rebuild \
  -- switch --flake "path:$REPO_ROOT#$HOST"

say "Bootstrap complete"
printf 'Open a new terminal to load the configured environment.\n'
