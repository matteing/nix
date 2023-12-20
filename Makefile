.PHONY: prepare init rebuild

prepare:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

init:
	nix run nix-darwin -- switch --flake .#matteing-mbp --extra-experimental-features 'nix-command flakes'

rebuild:
	darwin-rebuild switch --flake .#matteing-mbp