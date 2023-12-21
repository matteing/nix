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
      # Faster NPM
      "pnpm"
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
      "tableplus"
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
    ];

    # Mac App Store apps.
    # masApps = [
    #   "904280696" # Things
    #   "775737590" # iA Writer
    #   "1320666476" # Wipr
    #   "497799835" # Xcode
    #   "1475387142" # Tailscale
    #   "937984704" # Amphetamine
    #   "310633997" # WhatsApp
    #   "425424353" # Unarchiver
    #   "1591303229" # Vinegar
    #   "899247664" # TestFlight
    #   "1569813296" # 1Password for Safari
    #   "1351639930" # Gifski
    #   "408981434" # iMovie
    #   "747648890" # Telegram
    # ]
  };
}
