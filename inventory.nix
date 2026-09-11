{
  users.sergio = {
    username = "sergio";
    fullName = "Sergio Mattei";
    email = "me@matteing.com";
    sshPublicKeyFiles = [ ./keys/sergio.pub ];
    homeModule = ./home/common.nix;
  };

  hosts = {
    matteing-mbp = {
      platform = "darwin";
      system = "aarch64-darwin";
      channel = "unstable";
      primaryUser = "sergio";
      module = ./hosts/matteing-mbp;
    };

    homelab = {
      platform = "nixos";
      system = "x86_64-linux";
      channel = "stable";
      primaryUser = "sergio";
      module = ./hosts/homelab;
    };
  };
}
