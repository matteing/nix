/* -------------------------------------------------------------------------- */
/*                    Shell scripts, dotfiles and aliases.                    */
/* -------------------------------------------------------------------------- */

{ config, pkgs, ... }:

let 
  username = "sergio";
in
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "z"
      ];
    };

    shellAliases = {
      workon = "cd ~/Projects/$1";
      django = "python manage.py";
      fly-proxy-db = "flyctl proxy 15432:5432 -s -a";
      npm = "pnpm";
      actually-npm = "npm";
    };

    sessionVariables = {
      EDITOR = "nano";
      VISUAL = "$EDITOR";
      ERL_AFLAGS = "-kernel shell_history enabled -kernel shell_history_file_bytes 1024000";
      KERL_CONFIGURE_OPTIONS="--enable-dynamic-ssl-lib --with-ssl=/opt/homebrew/opt/openssl@3 --enable-hipe --enable-shared-zlib --enable-smp-support --enable-threads --enable-wx --disable-debug --without-javac";
      KERL_BUILD_DOCS = "yes";
    };

    initExtra = ''
      ${(builtins.readFile ../zsh/themes/bubblegum.zsh-theme)}

      # Disable the right-hand side prompt (unsure why it's even set at all?)
      export RPROMPT=""

      # Initialize Brew.
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # Initialize applications that package optional CLI utilities.
      append_to_bin=(
        "/Applications/Postgres.app/Contents/Versions/latest/bin"
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
      )

      for dir in $append_to_bin; do
        # If path exists...
        if [ -d "$dir" ]; then
          export PATH="$dir:$PATH"
        fi
      done

      # Initialize the asdf version manager.
      . ${pkgs.asdf-vm}/share/asdf-vm/asdf.sh

      # Do something fun
      if [ $SHLVL -eq 1 ]; then
        FORTUNE_COMMAND="${pkgs.fortune}/bin/fortune -s art computers education food linux literature politics tao wisdom science"
        eval "$FORTUNE_COMMAND" | ${pkgs.lolcat}/bin/lolcat
      fi
    '';
  };
}