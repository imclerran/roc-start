app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
}

import cli.Stdout
import cli.File
import cli.Path
import cli.Task
import rvn.Rvn
import "packages.rvn" as packages : List U8
import "platforms.rvn" as platforms : List U8

Configuration : { platform : Str, packages : List Str }

main =
    packageRepo = loadPackageRepo
    platformRepo = loadPlatformRepo

    configBytes = File.readBytes! (Path.fromStr "config.rvn")
    configuration =
        when loadConfiguration configBytes is
            Ok config -> config
            Err _ -> { platform: "", packages: [] }
    pfStr =
        when Dict.get platformRepo configuration.platform is
            Ok pf -> "    $(pf.shortName): platform \"$(pf.url)\",\n"
            Err KeyNotFound -> crash "Invalid platform: $(configuration.platform)"
    pkgsStr =
        List.walk configuration.packages "" \str, package ->
            when Dict.get packageRepo package is
                Ok pkg -> Str.concat str "    $(pkg.shortName): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""
    Stdout.line! "app [main] {\n$(pfStr)$(pkgsStr)}\n"

loadPackageRepo : Dict Str { shortName : Str, version : Str, url : Str }
loadPackageRepo =
    res =
        Decode.fromBytes packages Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

loadPlatformRepo : Dict Str { shortName : Str, version : Str, url : Str }
loadPlatformRepo =
    res =
        Decode.fromBytes platforms Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

loadConfiguration : List U8 -> Result Configuration _
loadConfiguration = \bytes -> Decode.fromBytes bytes Rvn.pretty
