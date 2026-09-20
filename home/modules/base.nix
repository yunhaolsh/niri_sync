{ pkgs, ... }:

{
  home.username = "yunhao";
  home.homeDirectory = "/home/yunhao";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
  ];

  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    NIXOS_OZONE_WL = "1";
  };

  home.packages = with pkgs; [
    atuin
    bat
    eza
    fd
    fzf
    gh
    git
    jq
    nirius
    pyenv
    ripgrep
    rsync
    starship
    zoxide
  ];

  xdg.enable = true;

  home.file.".local/bin/nirius" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec "$HOME/.nix-profile/bin/nirius" "$@"
    '';
  };

  home.file.".local/bin/niriusd" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec "$HOME/.nix-profile/bin/niriusd" "$@"
    '';
  };
}
