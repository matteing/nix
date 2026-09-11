{ host, user, ... }:

{
  imports = [
    ./apps.nix
    ./settings.nix
  ];

  networking.computerName = host.name;

  nix.enable = false;
  nix.settings.trusted-users = [ user.username ];

  programs.zsh.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults.smb.NetBIOSName = host.name;
  system.primaryUser = user.username;

  system.stateVersion = 6;

  users.users.${user.username} = {
    home = user.homeDirectory;
    description = user.fullName;
  };

  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "uninstall";
      upgrade = false;
    };

    taps = [ ];
  };

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = user.username;
  };

  home-manager.users.${user.username} = {
    imports = [ ../../home/macos.nix ];

    home.stateVersion = "23.11";
  };
}
