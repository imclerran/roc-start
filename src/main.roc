app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.11.0/SY4WWMhWQ9NvQgvIthcv15AUeA7rAIJHAHgiaSHGhdY.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.5/1JOFFXrqOrdoINq6C4OJ8k3UK0TJhgITLbcOb-6WMwY.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.0/KbIfTNbxShRX1A1FgXei1SpO5Jn8sgP6HP6PXbi-xyA.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.2.0/BBDPvzgGrYp-AhIDw0qmwxT0pWZIQP_7KOrUrZfp_xw.tar.br",
}

import ArgParser
import Controller
import Model exposing [Model]
import Repo exposing [RepositoryEntry, RemoteRepoEntry, CacheRepoEntry]
import View
import ansi.Core
import cli.Arg
import cli.Cmd
import cli.Dir
import cli.Env
import cli.File
import cli.Http
import cli.Path
import cli.Stdin
import cli.Stdout
import cli.Task exposing [Task]
import cli.Tty
import json.Json
import rvn.Rvn

Configuration : {
    fileName : Str,
    platform : Str,
    packages : List Str,
    type : [App, Pkg],
}

greenCheck = "✔" |> Core.withFg (Standard Green)
redCross = "✖" |> Core.withFg (Standard Red)

## The main entry point for the program.
main : Task {} _
main =
    when ArgParser.parseOrDisplayMessage Arg.list! is
        Ok args ->
            runWith args

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

## Run the program with the parsed commandline args.
runWith : _ -> Task {} _
runWith = \args ->
    when args.subcommand is
        Ok (Tui {}) ->
            runTuiApp args.update
            |> Task.onErr \_ -> Task.err (Exit 1 "")

        Ok (Update { doPfs, doPkgs, doStubs }) ->
            if doPfs == doPkgs && doPkgs == doStubs then
                runUpdates Bool.true Bool.true Bool.true
                |> Task.onErr \_ -> Task.err (Exit 1 "")
            else
                runUpdates doPfs doPkgs doStubs
                |> Task.onErr \_ -> Task.err (Exit 1 "")

        Ok (App { appName, platform, packages }) ->
            runCliApp App appName platform packages args.update 
            |> Task.onErr \_ -> Task.err (Exit 1 "")

        Ok (Pkg { packages }) ->
            runCliApp Pkg "main" "" packages args.update
            |> Task.onErr \_ -> Task.err (Exit 1 "")

        Err NoSubcommand ->
            Stdout.line! ArgParser.extendedUsage
            Task.err (Exit 1 "")

## Run the CLI application.
## Load the repository data, and create the roc file if it doesn't already exist.
runCliApp : [App, Pkg], Str, Str, List Str, Bool -> Task {} _
runCliApp = \type, fileName, platform, packages, forceUpdate ->
    reposRes <- loadRepoData forceUpdate |> Task.attempt
    when reposRes is
        Ok repos ->
            getAppStubsIfNeeded! (Dict.keys repos.platforms) forceUpdate
            fileExists = checkForFile! "$(fileName).roc"
            if fileExists then
                Stdout.line! "Error: $(fileName).roc already exists. $(redCross)"
                Task.err (Exit 1 "")
            else
                createRocFile! { fileName, platform, packages, type } repos
                Stdout.line! "Created $(fileName).roc $(greenCheck)"
        Err e -> Task.err e

## Run the TUI application.
## Load the repository data, run the main tui loop, and create the roc file when the user confirms their selections.
runTuiApp : Bool -> Task {} _
runTuiApp = \forceUpdate ->
    repos = loadRepoData! forceUpdate
    getAppStubsIfNeeded! (Dict.keys repos.platforms) forceUpdate
    Tty.enableRawMode!
    model = Task.loop! (Model.init (Dict.keys repos.platforms) (Dict.keys repos.packages)) runUiLoop
    Stdout.write! (Core.toStr Reset)
    Tty.disableRawMode!
    when model.state is
        UserExited -> Task.ok {}
        Finished { config } ->
            fileExists = checkForFile! "$(config.fileName).roc"
            if fileExists then
                Stdout.line! "Error: $(config.fileName).roc already exists. $(redCross)"
                Task.err (Exit 1 "")
            else
                createRocFile! config repos
                Stdout.line "Created $(config.fileName).roc $(greenCheck)"

        _ -> Stdout.line ("Oops! Something went wrong..." |> Core.withFg (Standard Yellow))

## Run the update tasks for the platform, package, and app-stub repositories.
runUpdates : Bool, Bool, Bool -> Task {} _
runUpdates = \doPfs, doPkgs, doStubs ->
    Task.loop! [(doPfs, doPlatformUpdate), (doPkgs, doPackageUpdate), (doStubs, doAppStubUpdate)] \updateList ->
        when List.first updateList is
            Ok (doUpdate, updater) ->
                if doUpdate then
                    _ <- updater |> Task.attempt
                    Task.ok (Step (List.dropFirst updateList 1))
                else
                    Task.ok (Step (List.dropFirst updateList 1))

            _ -> Task.ok (Done {})

## The main loop for running the TUI.
## Checks the terminal size, draws the screen, reads input, and handles the input.
runUiLoop : Model -> Task [Step Model, Done Model] _
runUiLoop = \prevModel ->
    terminalSize = getTerminalSize!
    model = Controller.paginate { prevModel & screen: terminalSize }
    Core.drawScreen model (render model) |> Stdout.write!

    input = Stdin.bytes |> Task.map! Core.parseRawStdin
    modelWithInput = { model & inputs: List.append model.inputs input }
    handleInput modelWithInput input

## Get the size of the terminal window.
## Author: Luke Boswell
getTerminalSize : Task Core.ScreenSize _
getTerminalSize =
    # Move the cursor to bottom right corner of terminal
    cmd = [MoveCursor (To { row: 999, col: 999 }), GetCursor] |> List.map Control |> List.map Core.toStr |> Str.joinWith ""
    Stdout.write! cmd
    # Read the cursor position
    Stdin.bytes
        |> Task.map Core.parseCursor
        |> Task.map! \{ row, col } -> { width: col, height: row }

## Generate the list of draw functions which will be used to draw the screen.
render : Model -> List Core.DrawFn
render = \model ->
    when model.state is
        TypeSelect _ -> View.renderTypeSelect model
        InputAppName _ -> View.renderInputAppName model
        PlatformSelect _ -> View.renderPlatformSelect model
        PackageSelect _ -> View.renderPackageSelect model
        Search _ -> View.renderSearch model
        Confirmation _ -> View.renderConfirmation model
        Splash _ -> View.renderSplash model
        _ -> []

## Dispatch the input to the input handler for the current state.
handleInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleInput = \model, input ->
    when model.state is
        TypeSelect _ -> handleTypeSelectInput model input
        InputAppName _ -> handleInputAppNameInput model input
        PlatformSelect _ -> handlePlatformSelectInput model input
        PackageSelect _ -> handlePackageSelectInput model input
        Search _ -> handleSearchInput model input
        Confirmation _ -> handleConfirmationInput model input
        Splash _ -> handleSplashInput model input
        _ -> handleDefaultInput model input

## Default input handler which ensures that the program can always be exited.
## This ensures that even if you forget to handle input for a state, or end up
## in a state that doesn't have an input handler, the program can still be exited.
handleDefaultInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleDefaultInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            _ -> None
    Task.ok (Controller.applyAction { model, action })

handleTypeSelectInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleTypeSelectInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress Enter -> SingleSelect
            KeyPress Up -> CursorUp
            KeyPress Down -> CursorDown
            KeyPress Right -> NextPage
            KeyPress GreaterThanSign -> NextPage
            KeyPress FullStop -> NextPage
            KeyPress Left -> PrevPage
            KeyPress LessThanSign -> PrevPage
            KeyPress Comma -> PrevPage
            KeyPress GraveAccent -> Secret
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the PlatformSelect state.
handlePlatformSelectInput : Model, Core.Input -> Task [Step Model, Done Model] _
handlePlatformSelectInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress LowerS -> Search
            KeyPress UpperS -> Search
            KeyPress Enter -> SingleSelect
            KeyPress Up -> CursorUp
            KeyPress Down -> CursorDown
            KeyPress Delete -> GoBack
            KeyPress Escape -> ClearFilter
            KeyPress Right -> NextPage
            KeyPress GreaterThanSign -> NextPage
            KeyPress FullStop -> NextPage
            KeyPress Left -> PrevPage
            KeyPress LessThanSign -> PrevPage
            KeyPress Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the PackageSelect state.
handlePackageSelectInput : Model, Core.Input -> Task [Step Model, Done Model] _
handlePackageSelectInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress LowerS -> Search
            KeyPress UpperS -> Search
            KeyPress Enter -> MultiConfirm
            KeyPress Space -> MultiSelect
            KeyPress Up -> CursorUp
            KeyPress Down -> CursorDown
            KeyPress Delete -> GoBack
            KeyPress Escape -> ClearFilter
            KeyPress Right -> NextPage
            KeyPress GreaterThanSign -> NextPage
            KeyPress FullStop -> NextPage
            KeyPress Left -> PrevPage
            KeyPress LessThanSign -> PrevPage
            KeyPress Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the Search state.
handleSearchInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleSearchInput = \model, input ->
    (action, keyPress) =
        when input is
            CtrlC -> (Exit, None)
            KeyPress Enter -> (SearchGo, None)
            KeyPress Escape -> (Cancel, None)
            KeyPress Delete -> (TextBackspace, None)
            KeyPress key -> (TextInput, KeyPress key)
            _ -> (None, None)
    Task.ok (Controller.applyAction { model, action, keyPress })

## The input handler for the InputAppName state.
handleInputAppNameInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleInputAppNameInput = \model, input ->
    bufferLen =
        when model.state is
            InputAppName { nameBuffer } -> List.len nameBuffer
            _ -> 0
    (action, keyPress) =
        when input is
            CtrlC -> (Exit, None)
            KeyPress Enter -> (TextSubmit, None)
            KeyPress Delete -> if bufferLen == 0 then (GoBack, None) else (TextBackspace, None)
            KeyPress key -> (TextInput, KeyPress key)
            _ -> (None, None)
    Task.ok (Controller.applyAction { model, action, keyPress })

## The input handler for the Confirmation state.
handleConfirmationInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleConfirmationInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress Enter -> Finish
            KeyPress Delete -> GoBack
            _ -> None
    Task.ok (Controller.applyAction { model, action })

handleSplashInput : Model, Core.Input -> Task [Step Model, Done Model] _
handleSplashInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress Delete -> GoBack
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## Create the data directory if it doesn't exist, and return the string version of the path.
getAndCreateDataDir : Task Str _
getAndCreateDataDir =
    home = Env.var! "HOME"
    dataDir = "$(home)/.roc-start"
    if checkForDir! dataDir then
        Task.ok dataDir
    else
        Dir.create! dataDir
        Task.ok dataDir

## Check if a directory exists at the given path.
## Guarantee Task.ok Bool result.
checkForDir : Str -> Task Bool _
checkForDir = \path ->
    Path.isDir (Path.fromStr path)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Check if a file exists at the given path.
## Guarantee Task.ok Bool result.
checkForFile : Str -> Task Bool _
checkForFile = \filename ->
    Path.isFile (Path.fromStr filename)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Load the repository data from the local cache. If the cache does not exist,
## or the user requests an update, fetch the latest data from the remote repository.
loadRepoData : Bool -> Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadRepoData = \forceUpdate ->
    dataDir = getAndCreateDataDir!
    packageBytes = File.readBytes "$(dataDir)/pkg-data.rvn" |> Task.onErr! \_ -> Task.ok [] # if this block is placed inside if statement
    platformBytes = File.readBytes "$(dataDir)/pf-data.rvn" |> Task.onErr! \_ -> Task.ok [] # the compiler hangs indefinitely
    packages = getRepoDict packageBytes # it would be better not to do this read here
    platforms = getRepoDict platformBytes # but does not noticably slow UX.
    if forceUpdate then
        loadLatestRepoData
    else if Dict.isEmpty platforms || Dict.isEmpty packages then
        loadLatestRepoData # this will migrate tuples to records from old roc-start installs
    else
        Task.ok { packages, platforms }

## DO NOT DELETE ME!
## This is the perfered version of loadRepoData, but putting the logic to read the files inside the if statement
## causes the compiler to hang indefinitely. If this bug is fixed, the above version should be replaced with this one.
# loadRepoData = \forceUpdate ->
#     if forceUpdate then
#         loadLatestRepoData
#     else
# >         dataDir = getAndCreateDataDir!
#         packageBytes = File.readBytes "$(dataDir)/pkg-data.rvn" |> Task.onErr! \_ -> Task.ok []
#         platformBytes = File.readBytes "$(dataDir)/pf-data.rvn" |> Task.onErr! \_ -> Task.ok []
# >        packages = getRepoDict packageBytes
#         platforms = getRepoDict platformBytes
#         if Dict.isEmpty platforms || Dict.isEmpty packages then
#             loadLatestRepoData # this will migrate tuples to records from old roc-start installs
#         else
#             Task.ok { packages, platforms }

## Load the latest repository data from the remote repository.
loadLatestRepoData : Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadLatestRepoData =
    updateRes <- doRepoUpdate |> Task.attempt
    when updateRes is
        Ok _ ->
            dataDir = getAndCreateDataDir!
            packageBytes = File.readBytes! "$(dataDir)/pkg-data.rvn" # consider using in-memory data structure
            platformBytes = File.readBytes! "$(dataDir)/pf-data.rvn" # if the repo was loaded from remote
            packages = getRepoDict packageBytes
            platforms = getRepoDict platformBytes
            Task.ok { packages, platforms }
        
        Err e -> Task.err e

## Update the local repository cache with the latest data from the remote repository.
doRepoUpdate : Task {} _
doRepoUpdate =
    pfRes <- doPlatformUpdate |> Task.attempt
    when pfRes is
        Ok _ ->
            pkgRes <- doPackageUpdate |> Task.attempt
            when pkgRes is
                Ok _ -> Task.ok {}
                Err e -> Task.err e

        Err e -> Task.err e

## Update the local package repository cache with the latest data from the remote repository.
doPackageUpdate : Task {} _
doPackageUpdate =
    repoListRes <- getRemoteRepoData Packages |> Task.attempt
    when repoListRes is
        Ok repoList ->
            Stdout.write! "Updating package repository... "
            res <- updateRepoCache repoList "pkg-data.rvn" |> Task.attempt
            when res is
                Ok _ ->
                    Stdout.line! greenCheck
                Err GhAuthError ->
                    Stdout.line! redCross
                    Stdout.line! ("Error: `gh` not authenticated." |> Core.withFg (Standard Yellow))
                    Task.err GhAuthError
                Err GhNotInstalled ->
                    Stdout.line! redCross
                    Stdout.line! ("Error: `gh` not installed." |> Core.withFg (Standard Yellow))
                    Task.err GhNotInstalled
                Err e ->
                    Stdout.line! redCross
                    Task.err e

        Err e -> 
            Stdout.line! "Package update failed. $(redCross)"
            when e is
                NetworkErr _ -> 
                    Stdout.line! ("Error: network error." |> Core.withFg (Standard Yellow))
                    Task.err e
                _ -> 
                    Task.err e


## Update the local platform repository cache with the latest data from the remote repository.
doPlatformUpdate : Task {} _
doPlatformUpdate =
    repoListRes <- getRemoteRepoData Platforms |> Task.attempt
    when repoListRes is
        Ok repoList ->
            Stdout.write! "Updating platform repository... "
            res <- updateRepoCache repoList "pf-data.rvn" |> Task.attempt
            when res is
                Ok _ ->
                    Stdout.line! greenCheck
                Err GhAuthError ->
                    Stdout.line! redCross
                    Stdout.line! ("Error: `gh` not authenticated" |> Core.withFg (Standard Yellow))
                    Task.err GhAuthError
                Err GhNotInstalled ->
                    Stdout.line! redCross
                    Stdout.line! ("Error: `gh` not installed" |> Core.withFg (Standard Yellow))
                    Task.err GhNotInstalled
                Err e ->
                    Stdout.line! redCross
                    Task.err e

        Err e -> 
            Stdout.line! "Platform update failed. $(redCross)"
            when e is
                NetworkErr _ -> 
                    Stdout.line! ("Error: network error." |> Core.withFg (Standard Yellow))
                    Task.err e
                _ -> 
                    Task.err e

## Download the app stubs for the currently cached platforms.
doAppStubUpdate : Task {} _
doAppStubUpdate =
    dataDir = getAndCreateDataDir!
    platformBytesRes <- File.readBytes "$(dataDir)/pf-data.rvn" |> Task.attempt
    when platformBytesRes is
        Ok platformBytes ->
            platforms = getRepoDict platformBytes
            getAppStubs! (Dict.keys platforms)
        Err _ -> 
            Stdout.line! "App-stub update failed. $(redCross)"
            Stdout.line! ("Error: no platforms downloaded. Try updating platforms." |> Core.withFg (Standard Yellow))
            Task.err ErrReadingPlatforms

getRemoteRepoData : [Packages, Platforms] -> Task (List RemoteRepoEntry) _
getRemoteRepoData = \type ->
    request = getRequest "https://raw.githubusercontent.com/imclerran/roc-start/main/repository/roc-repo.rvn"
    respRes <- Http.send request |> Task.attempt
    when respRes is
        Ok resp ->
            when Decode.fromBytes resp.body Rvn.pretty is
                Ok repos ->
                    Task.ok (List.keepIf repos \repo -> repo.platform == (type == Platforms))

                Err e -> Task.err (DecodingErr e)
        
        Err e -> Task.err (NetworkErr e)

## Create an Http.Request object with the given url.
getRequest : Str -> Http.Request
getRequest = \url -> {
    method: Get,
    headers: [],
    url,
    mimeType: "",
    body: [],
    timeout: TimeoutMilliseconds 5000,
}

## Get the latest release for each package in the repository.
updateRepoCache : List RemoteRepoEntry, Str -> Task {} _
updateRepoCache = \repositoryList, filename ->
    if List.isEmpty repositoryList then
        Task.ok {}
    else
        dataDir = getAndCreateDataDir!
        pkgRvnStrRes <- Task.loop { repositoryList, rvnDataStr: "[\n" } reposToRvnStrLoop |> Task.attempt
        when pkgRvnStrRes is
            Ok pkgRvnStr ->
                File.writeBytes "$(dataDir)/$(filename)" (pkgRvnStr |> Str.toUtf8)

            Err e -> 
                Task.err e

RepositoryLoopState : { repositoryList : List RemoteRepoEntry, rvnDataStr : Str }

## Loop function which processes each git repo in the platform or package list, gets the latest release for each,
## and creates a string in rvn format containing the data for each package or platform. Used with `Task.loop`.
reposToRvnStrLoop : RepositoryLoopState -> Task [Step RepositoryLoopState, Done Str] [GhAuthError, GhNotInstalled]
reposToRvnStrLoop = \{ repositoryList, rvnDataStr } ->
    when List.first repositoryList is
        Ok { owner, repo, alias, platform, requires } ->
            updatedList = List.dropFirst repositoryList 1
            responseRes <- getLatestRelease owner repo |> Task.attempt
            when responseRes is
                Ok response ->
                    releaseData = responseToReleaseData response
                    when releaseData is
                        Ok { tagName, browserDownloadUrl } ->
                            updatedStr = Str.concat rvnDataStr (repoDataToRvnEntry { repo, owner, alias, version: tagName, url: browserDownloadUrl, platform, requires })
                            Task.ok (Step { repositoryList: updatedList, rvnDataStr: updatedStr })

                        Err _ -> Task.ok (Step { repositoryList: updatedList, rvnDataStr })
                
                Err (CmdOutputError (_, ExitCode 4)) -> Task.err GhAuthError
                Err (CmdOutputError (_, IOError _)) -> Task.err GhNotInstalled
                Err _ -> Task.ok (Step { repositoryList: updatedList, rvnDataStr })

        Err ListWasEmpty -> Task.ok (Done (Str.concat rvnDataStr "]"))

## Use the github cli to get the latest release for a given repository.
getLatestRelease : Str, Str -> Task { stdout : List U8, stderr : List U8 } _
getLatestRelease = \owner, repo ->
    Cmd.new "gh"
        |> Cmd.arg "api"
        |> Cmd.arg "-H"
        |> Cmd.arg "Accept: application/vnd.github+json"
        |> Cmd.arg "-H"
        |> Cmd.arg "X-GitHub-Api-Version: 2022-11-28"
        |> Cmd.arg "/repos/$(owner)/$(repo)/releases/latest"
        |> Cmd.output

## Parse the response from the github cli to get the tagName and browserDownloadUrl for the tar.br file for a given release.
responseToReleaseData : { stdout : List U8 }* -> Result { tagName : Str, browserDownloadUrl : Str } [NoAssetsFound, ParsingError]
responseToReleaseData = \response ->
    isTarBr = \{ browserDownloadUrl } -> Str.endsWith browserDownloadUrl ".tar.br"
    jsonResponse = Decode.fromBytes response.stdout (Json.utf8With { fieldNameMapping: SnakeCase })
    when jsonResponse is
        Ok { tagName, assets } ->
            when assets |> List.keepIf isTarBr |> List.first is
                Ok { browserDownloadUrl } -> Ok { tagName, browserDownloadUrl }
                Err ListWasEmpty -> Err NoAssetsFound

        Err _ -> Err ParsingError

## Convert the data for a single repository entry to a string in rvn format.
repoDataToRvnEntry : CacheRepoEntry -> Str
repoDataToRvnEntry = \entry ->
    Encode.toBytes entry Rvn.compact
    |> Str.fromUtf8
    |> Result.withDefault ""
    |> \str -> if !(Str.isEmpty str) then "    $(str),\n" else str # Str.concat str ",\n" else str

## Convert the raw bytes from pkg-data.rvn to a Dictionary of RepositoryEntry with the repo name as the key.
getRepoDict : List U8 -> Dict Str RepositoryEntry
getRepoDict = \bytes ->
    res =
        Decode.fromBytes bytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, entry ->
                Dict.insert dict entry.repo { alias: entry.alias, version: entry.version, url: entry.url, requires: entry.requires }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

## Update the app-stubs for the given platforms if they don't already exist, or if the user requests an update.
getAppStubsIfNeeded : List Str, Bool -> Task {} _
getAppStubsIfNeeded = \platforms, forceUpdate ->
    dataDir = getAndCreateDataDir!
    dirExists = checkForDir! "$(dataDir)/app-stubs"
    if !dirExists || forceUpdate then
        getAppStubs! platforms
    else
        Task.ok {}

## Update the app-stubs for the given platforms.
getAppStubs : List Str -> Task {} _
getAppStubs = \platforms ->
    dataDir = getAndCreateDataDir!
    appStubsDir = getAndCreateDir! "$(dataDir)/app-stubs"
    Stdout.write! "Updating app-stubs... "
    if List.len platforms > 0 then
        res <- Task.loop { platforms, dir: appStubsDir } getAppStubsLoop |> Task.attempt
        when res is
            Err (NetworkErr _) -> 
                Stdout.line! redCross
                Stdout.line! ("Error: network error." |> Core.withFg (Standard Yellow))

            Err _ ->
                Stdout.line! redCross

            Ok {} -> 
                Stdout.line! greenCheck
    else
        Stdout.line! redCross
        Stdout.line! ("Error: no platforms downloaded. Try updating platforms." |> Core.withFg (Standard Yellow))

AppStubsLoopState : { platforms : List Str, dir : Str }

## Loop function which processes each platform in the platform list, gets the app-stub for each.
getAppStubsLoop : AppStubsLoopState -> Task [Step AppStubsLoopState, Done {}] _
getAppStubsLoop = \{ platforms, dir } ->
    when List.get platforms 0 is
        Ok platform ->
            updatedList = List.dropFirst platforms 1
            request = getRequest "https://raw.githubusercontent.com/imclerran/roc-start/main/repository/app-stubs/$(platform).roc"
            responseRes <- Http.send request |> Task.attempt
            when responseRes is   
                Err e ->
                    when e is
                        HttpErr (BadStatus code ) if code == 404 -> Task.ok (Step { platforms: updatedList, dir })
                        _ -> Task.err (NetworkErr e)

                Ok response ->
                    File.writeBytes! "$(dir)/$(platform)" response.body
                    Task.ok (Step { platforms: updatedList, dir })

        Err OutOfBounds -> Task.ok (Done {})

## Create a directory at the given path if it doesn't already exist.
getAndCreateDir : Str -> Task Str _
getAndCreateDir = \dirPath ->
    if checkForDir! dirPath then
        Task.ok dirPath
    else
        Dir.create! dirPath
        Task.ok dirPath

## Generate a roc file from the given fileName, platform, and packageList.
createRocFile : Configuration, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } -> Task {} _
createRocFile = \config, repos ->
    appStub = getAppStub! config.platform
    bytes =
        when config.type is
            App -> buildRocApp config.platform config.packages repos appStub
            Pkg -> buildRocPackage config.packages repos.packages
    File.writeBytes "$(config.fileName).roc" bytes

## Build the raw byte representation of a roc file from the given platform, packageList, and repositories.
buildRocApp : Str, List Str, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry }, List U8 -> List U8
buildRocApp = \platform, packageList, repos, appStub ->
    pfStr =
        when Dict.get repos.platforms platform is
            Ok pf -> "    $(pf.alias): platform \"$(pf.url)\",\n"
            Err KeyNotFound -> crash "Invalid platform: $(platform)"
    pkgsStr =
        List.walk packageList "" \str, package ->
            when Dict.get repos.packages package is
                Ok pkg -> Str.concat str "    $(pkg.alias): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""
    requiresStr =
        Dict.get repos.platforms platform
        |> Result.withDefault { requires: ["main"], alias: "", url: "", version: "" }
        |> \pf -> pf.requires
        |> Str.joinWith ", "

    "app [$(requiresStr)] {\n$(pfStr)$(pkgsStr)}\n" |> Str.toUtf8 |> List.concat appStub

## Get the application stub for the platform, if it exists
getAppStub : Str -> Task (List U8) _
getAppStub = \platform ->
    dataDir = getAndCreateDataDir!
    File.readBytes "$(dataDir)/app-stubs/$(platform)"
        |> Task.onErr \_ -> Task.ok []
        |> Task.map! \bytes -> if List.isEmpty bytes then bytes else List.prepend bytes '\n'

buildRocPackage : List Str, Dict Str RepositoryEntry -> List U8
buildRocPackage = \packageList, packageRepo ->
    pkgsStr =
        List.walk packageList "" \str, package ->
            when Dict.get packageRepo package is
                Ok pkg -> Str.concat str "    $(pkg.alias): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""
    if Str.isEmpty pkgsStr then
        "package [] {}\n" |> Str.toUtf8
    else
        "package [] {\n$(pkgsStr)}\n" |> Str.toUtf8

