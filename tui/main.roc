app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.11.0/SY4WWMhWQ9NvQgvIthcv15AUeA7rAIJHAHgiaSHGhdY.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.5/1JOFFXrqOrdoINq6C4OJ8k3UK0TJhgITLbcOb-6WMwY.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
}

import Model exposing [Model]
import Repos exposing [RepositoryEntry]
import UI
import cli.File
import cli.Dir
import cli.Env
import cli.Path
import cli.Stdout
import cli.Stdin
import cli.Tty
import cli.Task exposing [Task]
import ansi.Core
import rvn.Rvn

Configuration : {
    appName : Str,
    platform : Str,
    packages : List Str,
}

## Create the data directory if it doesn't exist, and return the string version of the path.
getAndCreateDataDir =
    home = Env.var! "HOME"
    dataDir = "$(home)/.roc-start"
    if checkForDir! dataDir then
        Task.ok dataDir
    else
        Dir.create! dataDir
        Task.ok dataDir

## Check if a directory exists at the given path.
checkForDir = \path ->
    Path.isDir (Path.fromStr path)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Load the package and platform dictionaries from the files on disk.
## If the data files do not yet exist, update to create them.
loadRepositories : Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadRepositories =
    dataDir = getAndCreateDataDir!
    #runUpdateIfNecessary! dataDir
    packageBytes = File.readBytes! "$(dataDir)/pkg-data.rvn"
    platformBytes = File.readBytes! "$(dataDir)/pf-data.rvn"
    packages = getPackageDict packageBytes
    platforms = getPlatformDict platformBytes
    Task.ok { packages, platforms }

## Convert the raw bytes from pkg-data.rvn to a Dictionary of RepositoryEntry with the repo name as the key.
getPackageDict : List U8 -> Dict Str RepositoryEntry
getPackageDict = \packageBytes ->
    res =
        Decode.fromBytes packageBytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

## Convert the raw bytes from pf-data.rvn to a Dictionary of RepositoryEntry with the repo name as the key.
getPlatformDict : List U8 -> Dict Str RepositoryEntry
getPlatformDict = \platformBytes ->
    res =
        Decode.fromBytes platformBytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

## Generate a roc file from the given appName, platform, and packageList.
createRocFile : Configuration, { packages: Dict Str RepositoryEntry, platforms: Dict Str RepositoryEntry } -> Task {} _
createRocFile = \config, repos ->
    #repos <- loadRepositories |> Task.await
    File.writeBytes "$(config.appName).roc" (buildRocFile config.platform config.packages repos)

## Build the raw byte representation of a roc file from the given platform, packageList, and repositories.
buildRocFile : Str, List Str, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } -> List U8
buildRocFile = \platform, packageList, repos ->
    pfStr =
        when Dict.get repos.platforms platform is
            Ok pf -> "    $(pf.shortName): platform \"$(pf.url)\",\n"
            Err KeyNotFound -> crash "Invalid platform: $(platform)"
    pkgsStr =
        List.walk packageList "" \str, package ->
            when Dict.get repos.packages package is
                Ok pkg -> Str.concat str "    $(pkg.shortName): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""
    "app [main] {\n$(pfStr)$(pkgsStr)}\n" |> Str.toUtf8

render : Model -> List Core.DrawFn
render = \model ->
    when model.state is
        InputAppName _ -> UI.renderInputAppName model
        PlatformSelect _ -> UI.renderPlatformSelect model
        PackageSelect _ -> UI.renderPackageSelect model
        SearchPage _ -> UI.renderSearchPage model
        Confirmation _ -> UI.renderConfirmation model
        _ -> []

getTerminalSize : Task.Task Core.ScreenSize _
getTerminalSize =
    # Move the cursor to bottom right corner of terminal
    cmd = [MoveCursor (To { row: 999, col: 999 }), GetCursor] |> List.map Control |> List.map Core.toStr |> Str.joinWith ""
    Stdout.write! cmd
    # Read the cursor position
    Stdin.bytes
        |> Task.map Core.parseCursor
        |> Task.map! \{ row, col } -> { width: col, height: row }

runUiLoop : Model -> Task.Task [Step Model, Done Model] _
runUiLoop = \prevModel ->
    terminalSize = getTerminalSize!
    model = Model.paginate { prevModel & screen: terminalSize }
    Core.drawScreen model (render model)
        |> Stdout.write!

    input = Stdin.bytes |> Task.map! Core.parseRawStdin
    modelWithInput = { model & inputs: List.append model.inputs input }
    when model.state is
        InputAppName _ -> handleInputAppNameInput modelWithInput input
        PlatformSelect _ -> handlePlatformSelectInput modelWithInput input
        PackageSelect _ -> handlePackageSelectInput modelWithInput input
        SearchPage { sender } -> handleSearchPageInput modelWithInput input sender
        Confirmation _ -> handleConfirmationInput modelWithInput input
        _ -> handleBasicInput modelWithInput input

handleBasicInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleBasicInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        _ -> Task.ok (Step model)

handlePlatformSelectInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handlePlatformSelectInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress LowerS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress UpperS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress Enter -> Task.ok (Step (Model.toPackageSelectState model))
        KeyPress Up -> Task.ok (Step (Model.moveCursor model Up))
        KeyPress Down -> Task.ok (Step (Model.moveCursor model Down))
        KeyPress Delete -> Task.ok (Step (Model.toInputAppNameState model))
        KeyPress Escape -> Task.ok (Step (Model.clearSearchFilter model))
        KeyPress Right -> Task.ok (Step (Model.nextPage model))
        KeyPress GreaterThanSign -> Task.ok (Step (Model.nextPage model))
        KeyPress FullStop -> Task.ok (Step (Model.nextPage model))
        KeyPress Left -> Task.ok (Step (Model.prevPage model))
        KeyPress LessThanSign -> Task.ok (Step (Model.prevPage model))
        KeyPress Comma -> Task.ok (Step (Model.prevPage model))
        _ -> Task.ok (Step model)

handlePackageSelectInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handlePackageSelectInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress LowerS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress UpperS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress Enter -> Task.ok (Step (Model.toConfirmationState model))
        KeyPress Space -> Task.ok (Step (Model.toggleSelected model))
        KeyPress Up -> Task.ok (Step (Model.moveCursor model Up))
        KeyPress Down -> Task.ok (Step (Model.moveCursor model Down))
        KeyPress Delete -> Task.ok (Step (Model.toPlatformSelectState model))
        KeyPress Escape -> Task.ok (Step (Model.clearSearchFilter model))
        KeyPress Right -> Task.ok (Step (Model.nextPage model))
        KeyPress GreaterThanSign -> Task.ok (Step (Model.nextPage model))
        KeyPress FullStop -> Task.ok (Step (Model.nextPage model))
        KeyPress Left -> Task.ok (Step (Model.prevPage model))
        KeyPress LessThanSign -> Task.ok (Step (Model.prevPage model))
        KeyPress Comma -> Task.ok (Step (Model.prevPage model))
        _ -> Task.ok (Step model)

handleSearchPageInput : Model, Core.Input, [Platform, Package] -> Task.Task [Step Model, Done Model] _
handleSearchPageInput = \model, input, sender ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter ->
            when sender is
                Platform -> Task.ok (Step (Model.toPlatformSelectState model))
                Package -> Task.ok (Step (Model.toPackageSelectState model))
        KeyPress Escape -> Task.ok (Step (model |> Model.clearSearchBuffer |> Model.toPlatformSelectState))
        KeyPress Delete -> Task.ok (Step (Model.backspaceBuffer model))
        KeyPress c -> Task.ok (Step (Model.appendToBuffer model c))
        _ -> Task.ok (Step model)

handleInputAppNameInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleInputAppNameInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter -> Task.ok (Step (Model.toPlatformSelectState model))
        KeyPress Delete -> Task.ok (Step (Model.backspaceBuffer model))
        KeyPress c -> Task.ok (Step (Model.appendToBuffer model c))
        _ -> Task.ok (Step model)

handleConfirmationInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleConfirmationInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter -> Task.ok (Done (Model.toFinishedState model))
        KeyPress Delete -> Task.ok (Step (Model.toPackageSelectState model))
        _ -> Task.ok (Step model)

main =
    repos = loadRepositories!
    Tty.enableRawMode!
    model = Task.loop! (Model.init repos.platforms repos.packages) runUiLoop
    Stdout.write! (Core.toStr Reset)
    Tty.disableRawMode!
    when model.state is
        UserExited -> Task.ok {}
        Finished { config } -> 
            createRocFile! config repos
            Stdout.line! "Created $(config.appName).roc"
        _ -> Stdout.line! "Something went wrong..."
