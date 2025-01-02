{
  description = "roc-start";

  inputs = {
    roc.url = "github:nxy7/roc";
    nixpkgs.follows = "roc/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, roc, ... }:
    let
      supportedSystems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
        roc-cli = roc.packages.${system}.cli;
      in {
        devShell = pkgs.mkShell { packages = [ roc-cli ]; };

        packages = rec {
          default = roc-start;
          roc-start = roc.lib.buildRocPackage {
            inherit pkgs roc-cli;
            linker = "legacy";
            name = "roc-start";
            src = ./.;
            entryPoint = "src/main.roc";
            outputHash = "sha256-R0LtKuWpsNQxB1OS3sRMkvYuDy0tTPScdMrhIBUGpRc=";
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
