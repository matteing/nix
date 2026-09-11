{
  programs = {
    starship = {
      enable = true;
      settings = {
        add_newline = true;
        directory = {
          truncation_length = 0;
          truncate_to_repo = false;
          home_symbol = "~";
        };
      };
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };

      shellAliases = {
        home = "cd ~";
        rebuild = "make -C ~/nix switch";
      };

      sessionVariables = {
        EDITOR = "nano";
        VISUAL = "$EDITOR";
      };
    };
  };
}
