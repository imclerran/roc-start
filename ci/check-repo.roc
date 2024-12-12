app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.17.0/lZFLstMUCUvd5bjnnpYromZJXkQUrdhbva4xdBInicE.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.3.0/6AqhP_-5msgMDvUgoJF-aFwcFpFGCSzmvL3sghcXUXM.tar.br",
}

import cli.Stdout
import rvn.Rvn
import "../repository/roc-repo.rvn" as bytes : List U8

RemoteRepoEntry : { repo : Str, owner : Str, alias : Str, platform : Bool, requires : List Str }

redFg = "\u(001b)[31m"
greenFg = "\u(001b)[32m"
resetStyle = "\u(001b)[0m"

main : Task {} _
main =
    repoRes : Result (List RemoteRepoEntry) _
    repoRes = Decode.fromBytes bytes Rvn.pretty
    when repoRes is
        Ok _ -> Stdout.line! "$(greenFg)0$(resetStyle) errors decoding repo"
        Err _ -> Task.err (Exit 1 "$(redFg)1$(resetStyle) error decoding repo")
