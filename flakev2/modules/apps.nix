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
    oh-my-zsh
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
    # TODO Feel free to add your favorite apps here.
    brews = [
      "wxwidgets"
    ];

    # `brew install --cask`
    # TODO Feel free to add your favorite apps here.
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

  # environment.etc."bashrc".knownSha256Hashes = ["08ffbf991a9e25839d38b80a0d3bce3b5a6c84b9be53a4b68949df4e7e487bb7"];
  # environment.etc."zshrc".knownSha256Hashes = ["2af1b563e389d11b76a651b446e858116d7a20370d9120a7e9f78991f3e5f336"];
  # environment.etc."zshenv".knownSha256Hashes = ["d07015be6875f134976fce84c6c7a77b512079c1c5f9594dfa65c70b7968b65f"];
  # environment.etc."nix/nix.conf".knownSha256Hashes = ["97f4135d262ca22d65c9554aad795c10a4491fa61b67d9c2430f4d82bbfec9a2"];
}
