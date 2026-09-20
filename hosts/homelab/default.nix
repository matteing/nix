{
  host,
  pkgs,
  user,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./maintenance.nix
    ./network.nix
  ];

  # The EliteDesk boots in UEFI mode. Secure Boot can be layered on later;
  # this is the ordinary systemd-boot setup used for installation.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # Services below open only the ports they own. Time Machine's SMB endpoint is
  # limited to the physical LAN; it is never intended to be forwarded by the
  # router.
  networking.firewall = {
    enable = true;
    interfaces.eno1.allowedTCPPorts = [ 445 ];
    interfaces.wlp0s20f3.allowedTCPPorts = [ 445 ];
  };

  # Keep the PSK in a file readable only by wpa_supplicant so it never enters
  # the world-readable Nix store.
  networking.wireless = {
    enable = true;
    interfaces = [ "wlp0s20f3" ];
    secretsFile = "/var/lib/wifi/wireless.conf";
  };

  programs.zsh.enable = true;

  users.users.${user.username} = {
    isNormalUser = true;
    description = user.fullName;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles = user.sshPublicKeyFiles;
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  services.openssh = {
    enable = true;
    openFirewall = true;

    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  virtualisation.docker.enable = true;

  # Authentication is intentionally not stored in Nix. Run
  # `sudo tailscale up` once, then manage access through the tailnet policy.
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;

    # Docker uses bridge networking for Samba because Avahi already owns mDNS
    # on the host. Advertise the mapped SMB port here so macOS discovers the
    # share as a native Time Machine destination without duplicate responders.
    extraServiceFiles.timemachine = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
        <service>
          <type>_device-info._tcp</type>
          <port>9</port>
          <txt-record>model=TimeCapsule8,119</txt-record>
        </service>
        <service>
          <type>_adisk._tcp</type>
          <port>9</port>
          <txt-record>dk0=adVN=TimeMachine,adVF=0x82</txt-record>
          <txt-record>sys=adVF=0x100</txt-record>
        </service>
      </service-group>
    '';

    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Keep rescue and administration tools independent of Home Manager.
  environment.systemPackages = with pkgs; [
    curl
    git
    gnumake
    tmux
  ];

  home-manager.users.${user.username} = {
    # Keep this at the Home Manager release used for the initial activation.
    home.stateVersion = "26.05";
  };

  assertions = [
    {
      assertion = host.primaryUser == user.username;
      message = "homelab's selected primary user must match its user context";
    }
  ];

  # Keep this at the release used for the initial installation. It controls
  # compatibility defaults and should not be bumped during routine upgrades.
  system.stateVersion = "26.05";
}
