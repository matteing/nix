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

      supportedSystems = lib.unique (map (host: host.system) (lib.attrValues inventory.hosts));
    in
    {
      inherit darwinConfigurations nixosConfigurations;

      # Available before the encrypted Darwin app module is unlocked.
      packages = lib.genAttrs supportedSystems (system: {
        age = nixpkgs.legacyPackages.${system}.age;
      });

      formatter = lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
