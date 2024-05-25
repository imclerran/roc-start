app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
}

import cli.Stdout
import cli.File
import cli.Path
import cli.Task
import cli.Cmd
import rvn.Rvn
import "pkg-data.rvn" as packages : List U8
import "pf-data.rvn" as platforms : List U8

main =
    createConfigIfNone!
    configBytes = File.readBytes! (Path.fromStr "config.rvn")
    configuration =
        when Decode.fromBytes configBytes Rvn.pretty is
            Ok config -> config
            Err _ -> { platform: "", packages: [], appName: "" }
    pfStr =
        when Dict.get platformRepo configuration.platform is
            Ok pf -> "    $(pf.shortName): platform \"$(pf.url)\",\n"
            Err KeyNotFound -> crash "Invalid platform: $(configuration.platform)"
    pkgsStr =
        List.walk configuration.packages "" \str, package ->
            when Dict.get packageRepo package is
                Ok pkg -> Str.concat str "    $(pkg.shortName): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""
    bytes = "app [main] {\n$(pfStr)$(pkgsStr)}\n" |> Str.toUtf8
    File.writeBytes! (Path.fromStr "$(configuration.appName).roc") bytes
    Stdout.line! "Created $(configuration.appName).roc"

packageRepo : Dict Str { shortName : Str, version : Str, url : Str }
packageRepo =
    res =
        Decode.fromBytes packages Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

platformRepo : Dict Str { shortName : Str, version : Str, url : Str }
platformRepo =
    res =
        Decode.fromBytes platforms Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

createConfigIfNone =
    isFile = Path.isFile (Path.fromStr "config.rvn")
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false
    if !isFile then
        File.writeUtf8! (Path.fromStr "config.rvn") configTemplate
        Cmd.exec "nano" ["config.rvn"]
    else
        Task.ok {}

configTemplate =
    """
    {
        appName: "new-app",
        platform: "basic-cli",
        packages: [], # packages list may be empty
    }
    """
