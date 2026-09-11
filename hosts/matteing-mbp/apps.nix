{ ... }:

{
  imports = [
    (
      if builtins.pathExists ./apps.local.nix then
        ./apps.local.nix
      else
        throw "Mac apps are locked. Run 'make apps-unlock', then build with the repository's path: flake commands."
    )
  ];
}
