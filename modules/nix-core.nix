
{ pkgs, ... }:

{
  # enable flakes globally
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  programs.nix-index.enable = true;
  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;
  nixpkgs.hostPlatform = "aarch64-darwin";
  
}
