{ config, inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  dmsPkgs = inputs.dms.inputs.nixpkgs.legacyPackages.${system};
  dms = inputs.dms.packages.${system}.dms-shell;
  dsearch = inputs.dsearch.packages.${system}.default;
  quickshell = inputs.dms.packages.${system}.quickshell;
  mesa = dmsPkgs.mesa;
in {
  programs.dank-material-shell = {
    enable = true;
    package = dms;
    quickshell.package = quickshell;
    systemd.enable = true;
    systemd.target = "niri.service";
  };

  home.packages = [ dsearch ];

  # Ubuntu's user systemd manager does not include the Nix profile in PATH.
  # The Nix Quickshell closure also needs an explicit Mesa EGL/DRI provider.
  systemd.user.services.dms.Service.Environment = [
    "PATH=${quickshell}/bin:${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
    "LIBGL_DRIVERS_PATH=${mesa}/lib/dri"
    "GBM_BACKENDS_PATH=${mesa}/lib/gbm"
    "__EGL_VENDOR_LIBRARY_FILENAMES=${mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
  ];

  home.file.".local/bin/dms" = {
    executable = true;
    text = ''
      #!/bin/sh
      PATH="$HOME/.nix-profile/bin:$PATH"
      export PATH
      exec "$HOME/.nix-profile/bin/dms" "$@"
    '';
  };

  home.file.".local/bin/danksearch" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec "$HOME/.nix-profile/bin/dsearch" "$@"
    '';
  };
}
