{
  config,
  user,
  ...
}:

{
  home.file = {
    iCloud.source = config.lib.file.mkOutOfStoreSymlink "${user.homeDirectory}/Library/Mobile Documents/com~apple~CloudDocs";
    ".hushlogin".text = "";
  };

  programs = {
    mise = {
      enable = true;
      enableZshIntegration = true;

      globalConfig = {
        tools = {
          node = "26.5.0";
          erlang = "28.3.1";
          elixir = "1.18.4";
          python = "3.14.6";
          pnpm = "11.17.0";
          uv = "0.11.32";
        };

        settings.idiomatic_version_file_enable_tools = [
          "node"
          "python"
        ];
      };
    };

    zsh = {
      shellAliases = {
        django = "python manage.py";
        npm = "pnpm";
        actually-npm = "command npm";
      };
    };
  };
}
