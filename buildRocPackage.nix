{ pkgs, roc-cli, src, outputHash, ... }:
let
  aggregatedSources = pkgs.stdenv.mkDerivation {
    inherit src;
    name = "roc-dependencies";
    buildInputs = with pkgs; [ gnutar brotli ripgrep wget ];

    buildPhase = ''
      list=$(rg -o 'https://github.com[^"]*' src/main.roc)
      for url in $list; do
        path=$(echo $url | awk -F'github.com/|/[^/]*$' '{print $2}')
        packagePath=$out/roc/packages/github.com/$path
        mkdir -p $packagePath
        wget -P $packagePath $url --no-check-certificate
        cd $packagePath
        brotli -d *.tar.br
        tar -xf *.tar --one-top-level
      done
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = outputHash;
  };
in pkgs.stdenv.mkDerivation {
  name = "roc-start";
  src = ./.;
  buildInputs = [ roc-cli ];
  buildPhase = ''
    export XDG_CACHE_HOME=${aggregatedSources}
    roc build src/main.roc --output roc-start --optimize --linker=legacy

    mkdir -p $out/bin
    mv roc-start $out/bin/roc-start
  '';
}

