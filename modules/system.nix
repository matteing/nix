/* -------------------------------------------------------------------------- */
/*             This file manages app defaults and system settings.            */
/* -------------------------------------------------------------------------- */

{ pkgs, inputs, ... }:

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
      menuExtraClock.ShowSeconds = false;

      dock.autohide = true;
      dock.autohide-delay = 0.50;
      dock.autohide-time-modifier = 0.50;

      finder.ShowPathbar = true;

      loginwindow.LoginwindowText = "matteing.com";

      # Load up my custom iTerm2 preferences.
      CustomUserPreferences = {
        # You can find new user preferences by running `defaults read <app bundle name here>`.

        "com.googlecode.iterm2" = {
          "PrefsCustomFolder" = "${inputs.self}/iterm";
          "LoadPrefsFromCustomFolder" = true;
        };

        # Set some basic options for iA Writer.
        "pro.writer.mac" = {
          "Document Path Extension" = "md";
        };

        # Set some basic options for Rectangle.
        "com.knollsoft.Rectangle" = {
          "gapSize" = 16;
          "launchOnLogin" = true;
        };
      };
    };
  };

  # Allow using Touch ID to authenticate `sudo` requests.
  security.pam.enableSudoTouchIdAuth = true;

  time.timeZone = "America/Puerto_Rico";
}
