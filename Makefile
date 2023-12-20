.PHONY: prepare init rebuild

prepare:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

init:
	nix run nix-darwin -- switch --flake .#mbp

rebuild:
	darwin-rebuild switch --flake .#mbp

extras:
	touch ~/.hushlogin