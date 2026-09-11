.DEFAULT_GOAL := help

HOST ?= $(shell hostname -s)
BOOTSTRAP_HOST ?= matteing-mbp
SYSTEM ?= $(shell nix --extra-experimental-features 'nix-command flakes' eval --impure --raw --expr builtins.currentSystem 2>/dev/null)
FLAKE ?= path:$(CURDIR)\#$(HOST)
SSH_PUBLIC_KEY ?= $(HOME)/.ssh/matteing-2026.pub
REPO_SSH_PUBLIC_KEY := keys/sergio.pub

.PHONY: help bootstrap init build test switch sync-ssh-key check check-host fmt update unlock encrypt apps-unlock apps-encrypt private-unlock private-encrypt

help:
	@echo "Available targets:"
	@echo "  bootstrap  Install Nix and apply a nix-darwin host"
	@echo "  init       Re-run the initial nix-darwin activation"
	@echo "  build      Build the current host without activating"
	@echo "  test       Check Darwin or temporarily activate NixOS"
	@echo "  switch     Build and activate the current host"
	@echo "  sync-ssh-key  Copy and validate the homelab SSH public key"
	@echo "  check      Evaluate every configuration"
	@echo "  check-host Evaluate only the current host"
	@echo "  fmt        Format all Nix files"
	@echo "  update     Update flake inputs"
	@echo "  unlock     Unlock once for HOST; retain local files between builds"
	@echo "  encrypt    Save private edits for HOST as encrypted files"
	@echo "  apps-unlock   Decrypt or refresh the local Mac app list"
	@echo "  apps-encrypt  Encrypt local Mac app edits for Git"
	@echo "  private-unlock   Decrypt or refresh private settings for HOST"
	@echo "  private-encrypt  Encrypt private settings for HOST"

bootstrap:
	@HOST=$(BOOTSTRAP_HOST) ./scripts/bootstrap-darwin.sh

init:
	@./scripts/private-config ensure "$(HOST)"
	sudo nix --extra-experimental-features 'nix-command flakes' run \
		--no-write-lock-file --inputs-from "path:$(CURDIR)" nix-darwin\#darwin-rebuild -- switch --flake "$(FLAKE)"

build:
	@HOST=$(HOST) ./scripts/rebuild build

test:
	@HOST=$(HOST) ./scripts/rebuild test

switch:
	@HOST=$(HOST) ./scripts/rebuild switch

sync-ssh-key:
	@test -f "$(SSH_PUBLIC_KEY)" || { echo "Public key not found: $(SSH_PUBLIC_KEY)" >&2; exit 1; }
	@test "$$(awk 'END { print NR }' "$(SSH_PUBLIC_KEY)")" -eq 1 || { echo "Expected exactly one public key in $(SSH_PUBLIC_KEY)" >&2; exit 1; }
	@grep -Eq '^ssh-ed25519[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$$' "$(SSH_PUBLIC_KEY)" || { echo "Expected an ssh-ed25519 public key: $(SSH_PUBLIC_KEY)" >&2; exit 1; }
	@ssh-keygen -lf "$(SSH_PUBLIC_KEY)" >/dev/null
	@install -m 0644 "$(SSH_PUBLIC_KEY)" "$(REPO_SSH_PUBLIC_KEY)"
	@echo "Synced $(SSH_PUBLIC_KEY) -> $(REPO_SSH_PUBLIC_KEY)"
	@ssh-keygen -lf "$(REPO_SSH_PUBLIC_KEY)"

check:
	@./scripts/private-config ensure matteing-mbp
	@./scripts/private-config ensure homelab
	nix --extra-experimental-features 'nix-command flakes' flake check "path:$(CURDIR)" --all-systems --no-build

check-host:
	@HOST=$(HOST) ./scripts/rebuild eval

apps-unlock:
	@./scripts/apps unlock

apps-encrypt:
	@./scripts/apps encrypt

unlock private-unlock:
	@./scripts/private-config unlock "$(HOST)"

encrypt private-encrypt:
	@./scripts/private-config encrypt "$(HOST)"

fmt:
	nix --extra-experimental-features 'nix-command flakes' run "path:$(CURDIR)#formatter.$(SYSTEM)" -- \
		--excludes hosts/homelab/hardware-configuration.nix \
		"$(CURDIR)"

update:
	nix --extra-experimental-features 'nix-command flakes' flake update
