{ pkgs, ...}: {
  ##########################################################################
  # 
  #  Install all apps and packages here.
  #
  #  NOTE: Your can find all available options in:
  #    https://daiderd.com/nix-darwin/manual/index.html
  # 
  #
  ##########################################################################

  # Install packages from nix's official package repository.
  #
  # The packages installed here are available to all users, and are reproducible across machines, and are rollbackable.
  # But on macOS, it's less stable than homebrew.
  #
  # Related Discussion: https://discourse.nixos.org/t/darwin-again/29331
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
    # oh-my-zsh
  ];

  # 
  # The apps installed by homebrew are not managed by nix, and not reproducible!
  # But on macOS, homebrew has a much larger selection of apps than nixpkgs, especially for GUI apps!
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
      "wxwidgets"
    ];

    # `brew install --cask`
    casks = [
      "1password"
      "firefox"
      "visual-studio-code"
      "fork"
      "iterm2"
      "appcleaner"
      "cyberduck"
      "discord"
      "font-fira-code"
      "font-inconsolata"
      "font-inter"
      "font-jetbrains-mono"
      "rectangle"
      "sublime-text"
      "tableplus"
      "transmission"
      "utm"
      "sf-symbols"
      "raycast"
      "screen-studio"
      "obsidian"
      "figma"
      "postman"
      "postgres-unofficial"
      "steam"
      "dash"
      "orbstack"
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
