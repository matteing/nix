{ ... }:

{
  imports = [
    (
      if builtins.pathExists ./network.local.nix then
        ./network.local.nix
      else
        throw "Homelab network settings are locked. Run 'make private-unlock HOST=homelab', then build with the repository's path: flake commands."
    )
  ];
}
