/* -------------------------------------------------------------------------- */
/*             This file manages app defaults and system settings.            */
/* -------------------------------------------------------------------------- */

{ pkgs, inputs, ... }:

let
  wallpaper-name = "orange-wave.jpg";
  
  # Dock setup
  apps = [
    "/System/Applications/Launchpad.app"
    "/Applications/Safari.app"
    "/System/Applications/Mail.app"
    "/System/Applications/Calendar.app"
    "/Applications/Visual\\ Studio\\ Code.app"
    # "/Applications/Things.app"
    # "/Applications/iA Writer.app"
    "/System/Applications/Music.app"
    # "WhatsApp.app"
    "/Applications/iTerm.app"
  ];

  makeDockutilCommand = appPath: "${pkgs.dockutil}/bin/dockutil --add ${appPath} --no-restart";
  dockutilCommands = map makeDockutilCommand apps;
  dockutilCommandsString = builtins.concatStringsSep "\n" dockutilCommands;
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
      ${pkgs.dockutil}/bin/dockutil --remove all --no-restart
      ${dockutilCommandsString}
      killall Dock
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
