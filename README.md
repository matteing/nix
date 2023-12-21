<p align="center">
  <b>matteing/nix</b><br />
  <span align="center">My declarative system configuration for macOS.</span>
</p>

### What's here?
I've aimed to create a minimal, pragmatic setup for my machine using Nix. I won't go too off the deep-end here, but will try some Nix features to simplify my development environment.

1. Declarative package & app management
2. Flake-based configuration
3. iTerm2 settings support
4. Home Manager for setting up my Zsh environment 
5. `asdf` for language management
6. Other niceties ✨

## Prerequisites
To bring a device up into this repository, you must:

1. Install `git` via `xcode-select`. 
2. Install Nix using the Determinate Systems installer.
3. Install `brew`.

First, start installing the Xcode developer tools by attempting to clone this repo in a terminal. It will bring up a prompt and begin the installation. 

Next up, install the prerequisites by running:

```bash
make fresh-darwin
```
This command will complete the remaining two items to prepare your system for bringup.

## Installation
To kick things off:

```bash
make init
make langs # installs my programming languages
make extras # other random things I use
```

## More
Check the Makefile for more commands you can use!