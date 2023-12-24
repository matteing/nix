/* -------------------------------------------------------------------------- */
/*                       Declarative package management.                      */
/* -------------------------------------------------------------------------- */

{ pkgs, ...}: 

{
  # Packages to be installed from Nixpkgs.
  environment.systemPackages = with pkgs; [
    git
    asdf-vm
    flyctl
    neofetch
    mas
    pipx
    yt-dlp
    wget
    swift-format
    dockutil
    poetry
    nano
    fortune
    lolcat
    nodePackages_latest.pnpm
  ];

  # Homebrew is the best option for some packages, especially GUI apps.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      # 'zap': uninstalls all formulae(and related files) not listed here.
      cleanup = "zap";
    };

    taps = [
      "homebrew/cask"
      "homebrew/cask-fonts"
      "homebrew/services"
      "homebrew/cask-versions"
    ];

    # `brew install`
    brews = [
      # Dependency for building Python.
      "readline"
      "xz"
      # This is the best optimized version of OpenSSl for macOS.
      # Tried using the nixpkgs version, but no .dylibs in the include folder.
      "openssl@3"
      # Erlang's :observer module needs WXWidgets.
      "wxwidgets"
      # Can't find this in nixpkgs
      "trash"
    ];

    # `brew install --cask`
    casks = [
      # Fonts
      "font-fira-code"
      "font-inconsolata"
      "font-inter"
      "font-jetbrains-mono"
      "sf-symbols"

      # Apps
      "1password"
      "firefox"
      "visual-studio-code"
      "fork"
      "iterm2"
      "appcleaner"
      "cyberduck"
      "discord"
      "rectangle"
      "sublime-text"
      # Uhhh, this is the only version of TablePlus that I have a key for
      # 5.9.0,490
      # "https://raw.githubusercontent.com/Homebrew/homebrew-cask/581d8845ef4ed6d731b547bb152486f97ce7e34e/Casks/tableplus.rb"
      "transmission"
      "utm"
      "raycast"
      "screen-studio"
      "obsidian"
      "figma"
      "postman"
      "postgres-unofficial"
      "steam"
      "dash"
      "orbstack"
      "logi-options-plus"
      "spotify"
      "adobe-creative-cloud"
      "streamlabs"
      "coconutbattery"
    ];

    # Mac App Store apps.
    masApps = {
      Things = 904280696;
      "iA Writer" = 775737590;
      Wipr = 1320666476;
      Xcode = 497799835;
      Tailscale = 1475387142;
      Amphetamine = 937984704;
      WhatsApp = 310633997;
      Unarchiver = 425424353;
      Vinegar = 1591303229;
      TestFlight = 899247664;
      "1Password for Safari" = 1569813296;
      Gifski = 1351639930;
      iMovie = 408981434;
      Telegram = 747648890;
      "Little Snitch Mini" = 1629008763;
    };
  };
}
