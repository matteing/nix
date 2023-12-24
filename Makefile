.PHONY: prepare init rebuild checkin checkin-lock pull sync langs langs extras

current_datetime := $(shell date +"%Y-%m-%d %H:%M:%S")

prepare:
	curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

init:
	nix run nix-darwin -- switch --flake .#matteing-mbp

rebuild:
	darwin-rebuild switch --flake .#matteing-mbp
	neofetch

checkin:
	git add .
	git commit -m "[checkin] $(current_datetime)"
	git push

pull:
	git pull

checkin-lock:
	git add flake.lock
	git commit -m "[checkin] $(current_datetime)"
	git push

sync:
	git pull
	darwin-rebuild switch --flake .#matteing-mbp
	neofetch

determinate-fix:
	sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
	sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
	sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin

langs:
	asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
	asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
	asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
	asdf plugin add python
	asdf install erlang latest
	asdf install elixir latest
	asdf install nodejs latest
	asdf install python latest
	asdf global erlang latest
	asdf global elixir latest
	asdf global nodejs latest
	asdf global python latest

extras:
	mkdir -p ~/Projects
	touch ~/.hushlogin