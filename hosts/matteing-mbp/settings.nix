{ ... }:

{
  system.defaults = {
    dock = {
      autohide = false;
      show-recents = false;
      tilesize = 68;
    };

    finder = {
      ShowPathbar = true;
      FXPreferredViewStyle = "Nlsv";
    };

    loginwindow.LoginwindowText = "matteing.com";

    WindowManager = {
      EnableTiledWindowMargins = false;
      EnableTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableTopTilingByEdgeDrag = false;
    };

    trackpad.TrackpadRightClick = true;
  };

  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
