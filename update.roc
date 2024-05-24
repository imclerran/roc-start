app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.0/KbIfTNbxShRX1A1FgXei1SpO5Jn8sgP6HP6PXbi-xyA.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
}

import cli.Cmd
import cli.Task exposing [Task]
import cli.Stdout
import cli.File
import cli.Path
import json.Json
import rvn.Rvn
import "repos/pkg-repos.rvn" as pkgRepos : List U8
import "repos/pf-repos.rvn" as pfRepos : List U8

main =
    pkgRvnStr = Task.loop! { repositoryList: getPackageList, rvnDataStr: "[\n" } loopRepositories
    File.writeBytes! (Path.fromStr "pkg-data.rvn") (pkgRvnStr |> Str.toUtf8)
    Stdout.line! "Package data updated."
    pfRvnStr = Task.loop! { repositoryList: getPlatformList, rvnDataStr: "[\n" } loopRepositories
    File.writeBytes! (Path.fromStr "pf-data.rvn") (pfRvnStr |> Str.toUtf8)
    Stdout.line! "Platform data updated."


loopRepositories : {repositoryList : List (Str, Str, Str), rvnDataStr: Str } -> Task [Step {repositoryList : List (Str, Str, Str), rvnDataStr: Str }, Done Str] _
loopRepositories = \{ repositoryList, rvnDataStr } ->
    when List.get repositoryList 0 is
        Ok (shortName, user, repo) ->
            response = latestReleaseCmd "$(user)/$(repo)" |> Cmd.output!
            releaseData = responseToReleaseData response
            when releaseData is
                Ok { tagName, browserDownloadUrl } ->
                    updatedStr = Str.concat rvnDataStr (repoDataToRvnEntry repo shortName tagName browserDownloadUrl)
                    updatedList = List.dropFirst repositoryList 1
                    Task.ok (Step { repositoryList: updatedList, rvnDataStr: updatedStr })
                Err _ -> Task.ok (Step { repositoryList, rvnDataStr })
        Err OutOfBounds -> Task.ok (Done (Str.concat rvnDataStr "]"))

latestReleaseCmd = \ownerSlashRepo ->
    Cmd.new "gh"
    |> Cmd.arg "api"
    |> Cmd.arg "-H"
    |> Cmd.arg "Accept: application/vnd.github+json"
    |> Cmd.arg "-H"
    |> Cmd.arg "X-GitHub-Api-Version: 2022-11-28"
    |> Cmd.arg "/repos/$(ownerSlashRepo)/releases/latest"

responseToReleaseData = \response ->
    jsonResponse = Decode.fromBytes response.stdout (Json.utf8With { fieldNameMapping: SnakeCase })
    when jsonResponse is
        Ok { tagName, assets } ->
            when assets |> List.keepIf isTarBr |>List.first  is
                Ok { browserDownloadUrl } -> Ok { tagName, browserDownloadUrl }
                Err ListWasEmpty -> Err NoAssetsFound

        Err _ -> Err ParsingError

isTarBr = \{ browserDownloadUrl } -> Str.endsWith browserDownloadUrl ".tar.br"

getPackageList : List (Str, Str, Str)
getPackageList =
    when Decode.fromBytes pkgRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []

getPlatformList : List (Str, Str, Str)
getPlatformList =
    when Decode.fromBytes pfRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []

repoDataToRvnEntry = \repo, shortName, tagName, browserDownloadUrl ->
    """
        ("$(repo)", "$(shortName)", "$(tagName)", "$(browserDownloadUrl)"),\n
    """
