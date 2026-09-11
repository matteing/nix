{
  description = "matteing.com's nix config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager-stable.url = "github:nix-community/home-manager/release-26.05";
    home-manager-stable.inputs.nixpkgs.follows = "nixpkgs-stable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      lib = nixpkgs.lib;
      inventory = import ./inventory.nix;
      builders = import ./lib/mk-host.nix {
        inherit inputs self;
        inherit (inventory) users;
      };

      darwinHosts = lib.filterAttrs (_: host: host.platform == "darwin") inventory.hosts;
      nixosHosts = lib.filterAttrs (_: host: host.platform == "nixos") inventory.hosts;

      darwinConfigurations = lib.mapAttrs builders.mkDarwin darwinHosts;
      nixosConfigurations = lib.mapAttrs builders.mkNixos nixosHosts;

      # Unlocking/editing is portable even when this checkout does not define a
      # complete system configuration for the machine running the helper.
      toolSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      inherit darwinConfigurations nixosConfigurations;

      # Available before either private module is unlocked.
      packages = lib.genAttrs toolSystems (system: {
        age = nixpkgs.legacyPackages.${system}.age;
      });

      formatter = lib.genAttrs toolSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
