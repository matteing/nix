.PHONY: prepare init rebuild

prepare:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

init:
	nix run nix-darwin -- switch --flake .#matteing-mbp

rebuild:
	darwin-rebuild switch --flake .#matteing-mbp

extras:
	touch ~/Projects
	touch ~/.hushlogin