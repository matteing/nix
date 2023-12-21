{ pkgs, inputs, ... }:

  ###################################################################################
  #
  #  macOS's System configuration
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  #
  ###################################################################################
let
  wallpaper-name = "orange-wave.jpg";
in
{
  system = {
    # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

      # Set a wallpaper.
      osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"${inputs.self}/wallpapers/${wallpaper-name}\" as POSIX file"
    '';

    defaults = {
      # Just some `defaults` examples...
      # menuExtraClock.ShowSeconds = true;
      # NSGlobalDomain.AppleInterfaceStyle = "Dark";

      # Load up my custom iTerm2 preferences.
      CustomUserPreferences = {
        "com.googlecode.iterm2" = {
          "PrefsCustomFolder" = "${inputs.self}/iterm";
          "LoadPrefsFromCustomFolder" = true;
        };
      };
    };
  };

  # Allow using Touch ID to authenticate `sudo` requests.
  security.pam.enableSudoTouchIdAuth = true;

  time.timeZone = "America/Puerto_Rico";
}
