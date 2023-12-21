.PHONY: fresh-darwin init rebuild checkin pull sync langs extras

current_datetime := $(shell date +"%Y-%m-%d %H:%M:%S")

fresh-darwin:
	curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

init:
	nix run nix-darwin -- switch --flake .#matteing-mbp

rebuild:
	darwin-rebuild switch --flake .#matteing-mbp

checkin:
	git add .
	git commit -m "[checkin] $(current_datetime)"
	git push

pull:
	git pull

sync:
	git pull
	darwin-rebuild switch --flake .#matteing-mbp
	neofetch
	@echo "\033[32mAll done!\033[0m"

langs:
	asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
	asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
	asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
	export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"
	asdf install erlang latest
	asdf install elixir latest
	asdf install nodejs latest
	asdf global erlang latest
	asdf global elixir latest
	asdf global nodejs latest

extras:
	touch ~/Projects
	touch ~/.hushlogin