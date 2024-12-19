{
  description = "roc-start";

  inputs = {
    roc.url = "github:roc-lang/roc";
    nixpkgs.follows = "roc/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      supportedSystems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
        roc-cli = inputs.roc.packages.${system}.cli;
      in {
        devShell = pkgs.mkShell { packages = [ roc-cli ]; };

        packages = rec {
          default = roc-start;
          roc-start = import ./buildRocPackage.nix {
            inherit pkgs roc-cli;
            src = ./.;
            outputHash = "sha256-huhu+fXYoxxf8WT2eQ5teGM6t1ziWyaTVdUAz6mBaTo=";
          };

          formatter = pkgs.nixpkgs-fmt;

        };
      });

  nixConfig = {
    extra-trusted-public-keys =
      "roc-lang.cachix.org-1:6lZeqLP9SadjmUbskJAvcdGR2T5ViR57pDVkxJQb8R4=";
    extra-trusted-substituters = "https://roc-lang.cachix.org";
  };

}
