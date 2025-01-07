/* -------------------------------------------------------------------------- */
/*                       Declarative package management.                      */
/* -------------------------------------------------------------------------- */

{ pkgs, ...}: 

{
  # Packages to be installed from Nixpkgs.
  environment.systemPackages = with pkgs; [
    git
    neofetch
    mas
    pipx
    yt-dlp
    wget
    swift-format
    dockutil
    poetry
    pdm
    nano
    fortune
    lolcat
    jq
    unixtools.watch
    htop
    redis
  ];

  # Homebrew is the best option for some packages, especially GUI apps.
  homebrew = {
    enable = true;

    onActivation = {
      # 'zap': uninstalls all formulae(and related files) not listed here.
      cleanup = "zap";
      upgrade = true;
    };

    taps = [
      "homebrew/cask-fonts"
      "homebrew/services"
      "homebrew/cask-versions"
    ];

    # `brew install`
    brews = [
      # Dependencies for building Python.
      "readline"
      "xz"
      # This is the best optimized version of OpenSSl for macOS.
      # Tried using the nixpkgs version, but no .dylibs in the include folder.
      "openssl@3"
      # Erlang's :observer module needs WXWidgets.
      "wxwidgets"
      # Can't find this in nixpkgs
      "trash"
      # Nixpkgs version is outdated and no upgrade path
      "pnpm"
      # old as fuck on Nixpkgs
      "uv"
      # fly is more up to date
      "flyctl"
      # fucking nix pkgs can go to hell
      "asdf"
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
      "logi-options+"
      "spotify"
      "adobe-creative-cloud"
      "streamlabs"
      "coconutbattery"
      "handbrake"
      # minecraft
      "curseforge"
      # markdown preview in finder
      "qlmarkdown"
      # etcher
      "balenaetcher"
      # chrome
      "google-chrome"
    ];

    # Mac App Store apps.
    masApps = {
      # Things = 904280696;
      "iA Writer" = 775737590;
      Bear = 1091189122;
      Wipr = 1320666476;
      Xcode = 497799835;
      Tailscale = 1475387142;
      Amphetamine = 937984704;
      WhatsApp = 310633997;
      Unarchiver = 425424353;
      # Vinegar = 1591303229;
      TestFlight = 899247664;
      # "1Password for Safari" = 1569813296;
      Gifski = 1351639930;
      iMovie = 408981434;
      # Telegram = 747648890;
      # "Little Snitch Mini" = 1629008763;
      # "Save to Pocket" = 1477385213;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Keynote" = 409183694;
      "FoodNoms" = 1479461686;
    };
  };
}
