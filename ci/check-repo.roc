app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.2.0/omuMnR9ZyK4n5MaBqi7Gg73-KS50UMs-1nTu165yxvM.tar.br",
}

import cli.Stdout
import cli.Task exposing [Task]
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
