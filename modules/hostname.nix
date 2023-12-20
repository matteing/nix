
{ ... } @ args:

#############################################################
#
#  Host & Users configuration
#
#############################################################

let
  hostname = "matteing-mbp";
  username = "sergio";
in
{
  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${username}"= {
    home = "/Users/${username}";
    description = username;
  };

  nix.settings.trusted-users = [ username ];
}
