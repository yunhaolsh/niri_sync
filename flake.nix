{
  description = "Reproducible Ubuntu Niri workstation for yunhao";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      # Keep the UI compatible with the source workstation.
      url = "github:AvengeMedia/DankMaterialShell/v1.4.6";
    };

    dsearch = {
      url = "github:AvengeMedia/danksearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, dms, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHome = hostModule: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          dms.homeModules.dank-material-shell
          ./home
          hostModule
        ];
      };
    in {
      homeConfigurations = {
        # Use this profile on new machines unless a host-specific profile exists.
        yunhao = mkHome ./hosts/default.nix;
        "yunhao@legion" = mkHome ./hosts/legion.nix;
      };

      checks.${system}.home = self.homeConfigurations.yunhao.activationPackage;
      formatter.${system} = pkgs.nixfmt;
    };
}
