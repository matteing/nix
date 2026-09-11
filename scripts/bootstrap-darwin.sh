#!/bin/bash

set -euo pipefail

readonly EXPECTED_USER="${EXPECTED_USER:-sergio}"
readonly EXPECTED_ARCH="${EXPECTED_ARCH:-arm64}"
readonly HOST="${HOST:-matteing-mbp}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly NIX_INSTALLER_URL="https://install.determinate.systems/nix"

say() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\nError: %s\n' "$1" >&2
  exit 1
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

if ! xcode-select -p >/dev/null 2>&1; then
  say "Xcode Command Line Tools are required"
  xcode-select --install 2>/dev/null || true
  fail "finish the Command Line Tools installation, then run 'make bootstrap' again"
fi

if ! groups | grep -qE '(^|[[:space:]])admin($|[[:space:]])'; then
  fail "the current macOS account must be an administrator"
fi

say "Requesting administrator access"
sudo -v

nix_bin="$(command -v nix || true)"
if [[ -z "$nix_bin" && -x /nix/var/nix/profiles/default/bin/nix ]]; then
  nix_bin="/nix/var/nix/profiles/default/bin/nix"
fi

if [[ -z "$nix_bin" ]]; then
  installer="$(mktemp -t nix-installer.XXXXXX)"
  trap 'rm -f "$installer"' EXIT

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
