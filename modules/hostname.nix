
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
  # I don't need this right now--I'm setting Darwin up for my personal account.
  # users.users."${username}"= {
  #   home = "/Users/${username}";
  #   description = username;
  # };

  nix.settings.trusted-users = [ username ];
}
