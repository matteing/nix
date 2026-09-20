{ ... }:
{
  # Compressed swap provides a cushion for concurrent builds and Minecraft.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  # Container logs use journald as well; keep retention bounded.
  services.journald.extraConfig = ''
    SystemMaxUse=512M
    SystemKeepFree=2G
    MaxRetentionSec=30day
  '';

  services.openssh.settings = {
    LoginGraceTime = 30;
    MaxAuthTries = 6;
  };
}
