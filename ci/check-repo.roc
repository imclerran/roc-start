app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
}

import cli.Stdout
import cli.Task exposing [Task]
import rvn.Rvn
import "../repository/roc-repo.rvn" as bytes : List U8

RemoteRepoEntry : { repo : Str, owner : Str, alias : Str, platform : Bool, requires : List Str }

main : Task {} _
main =
    repoRes : Result (List RemoteRepoEntry) _
    repoRes = Decode.fromBytes bytes Rvn.pretty
    when repoRes is
        Ok _ -> Stdout.line! "Repo decoded successfully"
        Err _ -> Task.err (Exit 1 "Failed to decode repo")