{
  inputs,
  self,
  users,
}:

let
  contextFor =
    name: spec:
    let
      user =
        users.${spec.primaryUser}
          or (throw "Unknown primary user `${spec.primaryUser}` for host `${name}`");
    in
    {
      host = builtins.removeAttrs spec [ "module" ] // {
        inherit name;
      };

      user = user // {
        homeDirectory =
          spec.homeDirectory
            or (if spec.platform == "darwin" then "/Users/${user.username}" else "/home/${user.username}");
      };
    };

  hostModule = name: spec: {
    networking.hostName = name;
    nixpkgs.hostPlatform = spec.system;
    system.configurationRevision = self.rev or self.dirtyRev or null;
  };

  homeManagerModule =
    { host, user, ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = { inherit host user; };

        users.${user.username} = {
          imports = [ user.homeModule ];

          home = {
            username = user.username;
            homeDirectory = user.homeDirectory;
          };

          programs.home-manager.enable = true;
        };
      };
    };
in
{
  mkDarwin =
    name: spec:
    assert spec.platform == "darwin";
    assert spec.channel == "unstable";
    inputs.nix-darwin.lib.darwinSystem {
      system = spec.system;
      specialArgs = contextFor name spec;

      modules = [
        (hostModule name spec)
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        homeManagerModule
        spec.module
      ];
    };

  mkNixos =
    name: spec:
    assert spec.platform == "nixos";
    assert spec.channel == "stable";
    inputs.nixpkgs-stable.lib.nixosSystem {
      specialArgs = contextFor name spec;

      modules = [
        (hostModule name spec)
        inputs.home-manager-stable.nixosModules.home-manager
        homeManagerModule
        spec.module
      ];
    };
}
