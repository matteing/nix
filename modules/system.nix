/* -------------------------------------------------------------------------- */
/*             This file manages app defaults and system settings.            */
/* -------------------------------------------------------------------------- */

{ pkgs, inputs, ... }:

let
  wallpaper-name = "orange-wave.jpg";
  
  # Dock setup
  apps = [
    "Finder.app" 
    "Launchpad.app"
    "Safari.app"
    "Mail.app"
    "Calendar.app"
    "Visual Studio Code.app"
    # "Things.app"
    # "iA Writer.app"
    "Music.app"
    # "WhatsApp.app"
    "iTerm.app"
  ];

  dockutil = "${pkgs.dockutil}/bin/dockutil";
  addApp = app: "${dockutil} --add \"/Applications/${app^}\" --no-restart";
  dockutilCommands = builtins.concatMap (app: [addApp app]) apps;
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

      # Set up the dock.
      ${dockutilCommands}
    '';

    defaults = {
      menuExtraClock.ShowSeconds = false;

      dock.autohide = true;
      dock.autohide-delay = 0.75;
      dock.autohide-time-modifier = 0.75;

      finder.ShowPathbar = true;

      loginwindow.LoginwindowText = "matteing.com";

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
