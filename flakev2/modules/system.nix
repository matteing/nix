{ pkgs, self, ... }:

  ###################################################################################
  #
  #  macOS's System configuration
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  #
  ###################################################################################
{

  system = {
    # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults = {
      menuExtraClock.ShowSeconds = true;
      # NSGlobalDomain.AppleInterfaceStyle = "Dark";
      # other macOS's defaults configuration.
      # ......

      CustomSystemPreferences = {
        "com.apple.Safari.SandboxBroker" = {
          ShowDevelopMenu = true;
        };

        "com.apple.Safari" = {
          IncludeDevelopMenu = true;
        };
      };

      CustomUserPreferences = {
        "com.googlecode.iterm2" = {
          "PrefsCustomFolder" = "${self}/iterm";
          "LoadPrefsFromCustomFolder" = true;
        };
      };
    };
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  time.timeZone = "America/Puerto_Rico";

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh = {
    enable = true;
    interactiveShellInit = ''
      export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh";
      source $ZSH/oh-my-zsh.sh;
      ${(builtins.readFile ../zsh/bubblegum.zsh-theme)}
    '';
    promptInit = "";
  };

  environment.shellAliases = {
    workon = "cd ~/Projects/$1";
  };
}
