.PHONY: prepare init rebuild

prepare:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

init:
	nix run nix-darwin -- switch --flake .#matteing-mbp

rebuild:
	darwin-rebuild switch --flake .#matteing-mbp

langs:
	asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
	asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
	asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
	export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"
	asdf install erlang latest
	asdf install elixir latest
	asdf install nodejs latest

extras:
	touch ~/Projects
	touch ~/.hushlogin