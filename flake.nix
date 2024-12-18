{
  description = "roc-start";

  inputs = {
    roc.url = "github:roc-lang/roc";
    nixpkgs.follows = "roc/nixpkgs";

    # to easily make configs for multiple architectures
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, roc, nixpkgs, flake-utils }:
    let
      supportedSystems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };

        rocPkgs = roc.packages.${system};
      in {
        devShell = pkgs.mkShell { packages = [ rocPkgs.cli ]; };

        formatter = pkgs.nixpkgs-fmt;
      });
}
