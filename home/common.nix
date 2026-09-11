{ pkgs, user, ... }:

{
  imports = [ ./shell.nix ];

  home.packages = with pkgs; [
    codex
    htop
    jq
    nano
  ];

  programs = {
    gh.enable = true;

    git = {
      enable = true;
      settings = {
        user = {
          name = user.fullName;
          email = user.email;
        };
        init.defaultBranch = "main";
      };
    };
  };
}
