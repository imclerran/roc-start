app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.17.0/lZFLstMUCUvd5bjnnpYromZJXkQUrdhbva4xdBInicE.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.7.0/NmbsrdwKIOb1DtUIV7L_AhCvTx7nhfaW3KkOpT7VUZg.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.11.0/z45Wzc-J39TLNweQUoLw3IGZtkQiEN3lTBv3BXErRjQ.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.3.0/6AqhP_-5msgMDvUgoJF-aFwcFpFGCSzmvL3sghcXUXM.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.4.0/xgCr4fYD-5UsEArgh3kgk-JxqJcXBMbHlOb5jEl4yEk.tar.br",
}

import ArgParser
import Controller
import Model exposing [Model]
import Repo exposing [RepositoryEntry, RemoteRepoEntry, CacheRepoEntry]
import View
import ansi.ANSI
import cli.Arg
import cli.Cmd
import cli.Dir
import cli.Env
import cli.File
import cli.Http
import cli.Path
import cli.Stdin
import cli.Stdout
import cli.Tty
import json.Json
import rvn.Rvn

Configuration : {
    fileName : Str,
    platform : Str,
    packages : List Str,
    type : [App, Pkg],
}

greenCheck = "✔" |> ANSI.color { fg: Standard Green }
redCross = "✖" |> ANSI.color { fg: Standard Red }

## The main entry point for the program.
main : Task {} _
main =
    when ArgParser.parseOrDisplayMessage (Arg.list! {}) is
        Ok args ->
            runWith args

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

## Run the program with the parsed commandline args.
runWith : _ -> Task {} _
runWith = \args ->
    when args.subcommand is
        Ok (Tui s) ->
            runTuiApp args.update s
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

        Ok (Pkg packages) ->
            runCliApp Pkg "main" "" packages args.update
            |> Task.onErr \_ -> Task.err (Exit 1 "")

        Ok (Upgrade {filename, toUpgrade }) ->
            runUpgrades filename toUpgrade args.update
            |> Task.onErr \_ -> Task.err (Exit 1 "")


        Err NoSubcommand ->
            Stdout.line! ArgParser.extendedUsage
            Task.err (Exit 1 "")

## Run the CLI application.
## Load the repository data, and create the roc file if it doesn't already exist.
runCliApp : [App, Pkg], Str, Str, List Str, Bool -> Task {} _
runCliApp = \type, fileName, platform, packages, forceUpdate ->
    loadRepoData forceUpdate
        |> Task.attempt \reposRes ->
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
runTuiApp : Bool, Bool -> Task {} _
runTuiApp = \forceUpdate, showSplash ->
    repos = loadRepoData! forceUpdate
    getAppStubsIfNeeded! (Dict.keys repos.platforms) forceUpdate
    Tty.enableRawMode! {}
    initialModel =
        if showSplash then
            Model.init (Dict.keys repos.platforms) (Dict.keys repos.packages) { state: Splash { config: Model.emptyAppConfig } }
        else
            Model.init (Dict.keys repos.platforms) (Dict.keys repos.packages) {}
    model = Task.loop! initialModel runUiLoop #(Model.init (Dict.keys repos.platforms) (Dict.keys repos.packages) {}) runUiLoop
    Stdout.write! (ANSI.toStr Reset)
    Tty.disableRawMode! {}
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

        _ -> Stdout.line ("Oops! Something went wrong..." |> ANSI.color { fg: Standard Yellow })

## Run the update tasks for the platform, package, and app-stub repositories.
runUpdates : Bool, Bool, Bool -> Task {} _
runUpdates = \doPfs, doPkgs, doStubs ->
    Task.loop! [(doPfs, doPlatformUpdate), (doPkgs, doPackageUpdate), (doStubs, doAppStubUpdate)] \updateList ->
        when List.first updateList is
            Ok (doUpdate, updater) ->
                if doUpdate then
                    Task.attempt updater \_ ->
                        Task.ok (Step (List.dropFirst updateList 1))
                else
                    Task.ok (Step (List.dropFirst updateList 1))

            _ -> Task.ok (Done {})

runUpgrades : Str, List Str, Bool -> Task {} _
runUpgrades =\filename, toUpgrade, forceUpdate ->
    { prefix, dependencies, rest: remainder } =
        File.readBytes filename 
        |> Task.onErr! \_ -> Task.ok []
        |> splitFile
        |> Task.fromResult!

    Stdout.line! "Found dependency lines:"
    Task.loop! dependencies \lines -> 
        when lines is
            [line, .. as rest] ->
                Stdout.line! (Str.fromUtf8 line |> Result.withDefault "")
                Task.ok (Step rest)
            [] -> 
                Task.ok (Done {})

    loadRepoData forceUpdate
        |> Task.attempt \reposRes ->
            when reposRes is
                Ok repos -> 
                    _ = upgradeUrlStr! (getLineUrl (dependencies |> List.first |> Result.withDefault []) ) toUpgrade repos
                    Task.ok {}
                    
                Err e -> Task.err e

splitFile : List U8 -> Result {prefix: List U8, dependencies: List (List U8), rest: List U8 } [NotFound]
splitFile =\bytes ->
    { before: prefix, after: most } = List.splitFirst? bytes '{'
    { before: deps, after: rest } = List.splitFirst? most '}'
    dependencies = List.splitOn deps '\n' |> List.dropIf List.isEmpty
    Ok { prefix, dependencies, rest }

getLineUrl : List U8 -> Str
getLineUrl =\line ->
    line 
        |> List.splitLast ' ' 
        |> Result.withDefault { before: [], after: [] } 
        |> \split -> split.after
        |> List.splitOn '\"'
        |> List.get 1
        |> Result.withDefault []
        |> Str.fromUtf8 
        |> Result.withDefault ""

upgradeUrlStr : Str, List Str, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } -> Task Str _
upgradeUrlStr =\urlStr, toUpgrade, repos ->
    segs = Str.splitOn urlStr "/" 
    repo = segs |> List.get 4 |> Result.withDefault ""
    Stdout.line! repo
    Task.ok ""

## The main loop for running the TUI.
## Checks the terminal size, draws the screen, reads input, and handles the input.
runUiLoop : Model -> Task [Step Model, Done Model] _
runUiLoop = \prevModel ->
    terminalSize = getTerminalSize!
    model = Controller.paginate { prevModel & screen: terminalSize }
    ANSI.drawScreen model (render model) |> Stdout.write!

    input = Stdin.bytes {} |> Task.map! ANSI.parseRawStdin
    modelWithInput = { model & inputs: List.append model.inputs input }
    handleInput modelWithInput input

## Get the size of the terminal window.
## Author: Luke Boswell
getTerminalSize : Task ANSI.ScreenSize _
getTerminalSize =
    # Move the cursor to bottom right corner of terminal
    cmd = [Cursor (Abs { row: 999, col: 999 }), Cursor (Position (Get))] |> List.map Control |> List.map ANSI.toStr |> Str.joinWith ""
    Stdout.write! cmd
    # Read the cursor position
    Stdin.bytes {}
        |> Task.map ANSI.parseCursor
        |> Task.map! \{ row, col } -> { width: col, height: row }

## Generate the list of draw functions which will be used to draw the screen.
render : Model -> List ANSI.DrawFn
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
handleInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
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
handleDefaultInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handleDefaultInput = \model, input ->
    action =
        when input is
            Ctrl C -> Exit
            _ -> None
    Task.ok (Controller.applyAction { model, action })

handleTypeSelectInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handleTypeSelectInput = \model, input ->
    action =
        when input is
            Ctrl C -> Exit
            Action Enter -> SingleSelect
            Arrow Up -> CursorUp
            Arrow Down -> CursorDown
            Arrow Right -> NextPage
            Symbol GreaterThanSign -> NextPage
            Symbol FullStop -> NextPage
            Arrow Left -> PrevPage
            Symbol LessThanSign -> PrevPage
            Symbol Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the PlatformSelect state.
handlePlatformSelectInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handlePlatformSelectInput = \model, input ->
    action =
        when input is
            Ctrl C -> Exit
            Lower S -> Search
            Upper S -> Search
            Action Enter -> SingleSelect
            Arrow Up -> CursorUp
            Arrow Down -> CursorDown
            Action Delete -> GoBack
            Action Escape -> ClearFilter
            Arrow Right -> NextPage
            Symbol GreaterThanSign -> NextPage
            Symbol FullStop -> NextPage
            Arrow Left -> PrevPage
            Symbol LessThanSign -> PrevPage
            Symbol Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the PackageSelect state.
handlePackageSelectInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handlePackageSelectInput = \model, input ->
    action =
        when input is
            Ctrl C -> Exit
            Lower S -> Search
            Upper S -> Search
            Action Enter -> MultiConfirm
            Action Space -> MultiSelect
            Arrow Up -> CursorUp
            Arrow Down -> CursorDown
            Action Delete -> GoBack
            Action Escape -> ClearFilter
            Arrow Right -> NextPage
            Symbol GreaterThanSign -> NextPage
            Symbol FullStop -> NextPage
            Arrow Left -> PrevPage
            Symbol LessThanSign -> PrevPage
            Symbol Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the Search state.
handleSearchInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handleSearchInput = \model, input ->
    (action, keyPress) =
        when input is
            Ctrl C -> (Exit, None)
            Action Enter -> (SearchGo, None)
            Action Escape -> (Cancel, None)
            Ctrl H -> (TextBackspace, None)
            Action Delete -> (TextBackspace, None)
            Action Space -> (TextInput, Action Space)
            Symbol symbol -> (TextInput, Symbol symbol)
            Number number -> (TextInput, Number number)
            Lower letter -> (TextInput, Lower letter)
            Upper letter -> (TextInput, Upper letter)
            _ -> (None, None)
    Task.ok (Controller.applyAction { model, action, keyPress })

## The input handler for the InputAppName state.
handleInputAppNameInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handleInputAppNameInput = \model, input ->
    bufferLen =
        when model.state is
            InputAppName { nameBuffer } -> List.len nameBuffer
            _ -> 0
    (action, keyPress) =
        when input is
            Ctrl C -> (Exit, None)
            Action Enter -> (TextSubmit, None)
            Ctrl H -> if bufferLen == 0 then (GoBack, None) else (TextBackspace, None)
            Action Delete -> if bufferLen == 0 then (GoBack, None) else (TextBackspace, None)
            Action Space -> (TextInput, Action Space)
            Symbol symbol -> (TextInput, Symbol symbol)
            Number number -> (TextInput, Number number)
            Lower letter -> (TextInput, Lower letter)
            Upper letter -> (TextInput, Lower letter)
            _ -> (None, None)
    Task.ok (Controller.applyAction { model, action, keyPress })

## The input handler for the Confirmation state.
handleConfirmationInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handleConfirmationInput = \model, input ->
    action =
        when input is
            Ctrl C -> Exit
            Action Enter -> Finish
            Action Delete -> GoBack
            _ -> None
    Task.ok (Controller.applyAction { model, action })

handleSplashInput : Model, ANSI.Input -> Task [Step Model, Done Model] _
handleSplashInput = \model, input ->
    action =
        when input is
            Ctrl C -> Exit
            Action Delete -> GoBack
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
# loadRepoData : Bool -> Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
# loadRepoData = \forceUpdate ->
#     if forceUpdate then
#         loadLatestRepoData
#     else
#         dataDir = getAndCreateDataDir! # <--
#         packageBytes = File.readBytes "$(dataDir)/pkg-data.rvn" |> Task.onErr! \_ -> Task.ok []
#         platformBytes = File.readBytes "$(dataDir)/pf-data.rvn" |> Task.onErr! \_ -> Task.ok []
#         packages = getRepoDict packageBytes # <--
#         platforms = getRepoDict platformBytes
#         if Dict.isEmpty platforms || Dict.isEmpty packages then
#             loadLatestRepoData # this will migrate tuples to records from old roc-start installs
#         else
#             Task.ok { packages, platforms }

## Load the latest repository data from the remote repository.
loadLatestRepoData : Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadLatestRepoData =
    Task.attempt doRepoUpdate \updateRes ->
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
    Task.attempt doPlatformUpdate \pfRes ->
        when pfRes is
            Ok _ ->
                Task.attempt doPackageUpdate \pkgRes ->
                    when pkgRes is
                        Ok _ -> Task.ok {}
                        Err e -> Task.err e

            Err e -> Task.err e

## Update the local package repository cache with the latest data from the remote repository.
doPackageUpdate : Task {} _
doPackageUpdate =
    Task.attempt (getRemoteRepoData Packages) \repoListRes ->
        when repoListRes is
            Ok repoList ->
                Stdout.write! "Updating package repository... "
                Task.attempt (updateRepoCache repoList "pkg-data.rvn") \res ->
                    when res is
                        Ok _ ->
                            Stdout.line! greenCheck

                        Err GhAuthError ->
                            Stdout.line! redCross
                            Stdout.line! ("Error: `gh` not authenticated." |> ANSI.color { fg: Standard Yellow })
                            Task.err GhAuthError

                        Err GhNotInstalled ->
                            Stdout.line! redCross
                            Stdout.line! ("Error: `gh` not installed." |> ANSI.color { fg: Standard Yellow })
                            Task.err GhNotInstalled

                        Err e ->
                            Stdout.line! redCross
                            Task.err e

            Err e ->
                Stdout.line! "Package update failed. $(redCross)"
                when e is
                    NetworkErr _ ->
                        Stdout.line! ("Error: network error." |> ANSI.color { fg: Standard Yellow })
                        Task.err e

                    _ ->
                        Task.err e

## Update the local platform repository cache with the latest data from the remote repository.
doPlatformUpdate : Task {} _
doPlatformUpdate =
    Task.attempt (getRemoteRepoData Platforms) \repoListRes ->
        when repoListRes is
            Ok repoList ->
                Stdout.write! "Updating platform repository... "
                Task.attempt (updateRepoCache repoList "pf-data.rvn") \res ->
                    when res is
                        Ok _ ->
                            Stdout.line! greenCheck

                        Err GhAuthError ->
                            Stdout.line! redCross
                            Stdout.line! ("Error: `gh` not authenticated" |> ANSI.color { fg: Standard Yellow })
                            Task.err GhAuthError

                        Err GhNotInstalled ->
                            Stdout.line! redCross
                            Stdout.line! ("Error: `gh` not installed" |> ANSI.color { fg: Standard Yellow })
                            Task.err GhNotInstalled

                        Err e ->
                            Stdout.line! redCross
                            Task.err e

            Err e ->
                Stdout.line! "Platform update failed. $(redCross)"
                when e is
                    NetworkErr _ ->
                        Stdout.line! ("Error: network error." |> ANSI.color { fg: Standard Yellow })
                        Task.err e

                    _ ->
                        Task.err e

## Download the app stubs for the currently cached platforms.
doAppStubUpdate : Task {} _
doAppStubUpdate =
    dataDir = getAndCreateDataDir!
    Task.attempt (File.readBytes "$(dataDir)/pf-data.rvn") \platformBytesRes ->
        when platformBytesRes is
            Ok platformBytes ->
                platforms = getRepoDict platformBytes
                getAppStubs! (Dict.keys platforms)

            Err _ ->
                Stdout.line! "App-stub update failed. $(redCross)"
                Stdout.line! ("Error: no platforms downloaded. Try updating platforms." |> ANSI.color { fg: Standard Yellow })
                Task.err ErrReadingPlatforms

getRemoteRepoData : [Packages, Platforms] -> Task (List RemoteRepoEntry) _
getRemoteRepoData = \type ->
    request = getRequest "https://raw.githubusercontent.com/imclerran/roc-start/main/repository/roc-repo.rvn"
    Task.attempt (Http.send request) \respRes ->
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
        Task.attempt (Task.loop { repositoryList, rvnDataStr: "[\n" } reposToRvnStrLoop) \pkgRvnStrRes ->
            when pkgRvnStrRes is
                Ok pkgRvnStr ->
                    File.writeBytes (pkgRvnStr |> Str.toUtf8) "$(dataDir)/$(filename)"

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
            Task.attempt (getLatestRelease owner repo) \responseRes ->
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
        Task.attempt (Task.loop { platforms, dir: appStubsDir } getAppStubsLoop) \res ->
            when res is
                Err (NetworkErr _) ->
                    Stdout.line! redCross
                    Stdout.line! ("Error: network error." |> ANSI.color { fg: Standard Yellow })

                Err _ ->
                    Stdout.line! redCross

                Ok {} ->
                    Stdout.line! greenCheck
    else
        Stdout.line! redCross
        Stdout.line! ("Error: no platforms downloaded. Try updating platforms." |> ANSI.color { fg: Standard Yellow })

AppStubsLoopState : { platforms : List Str, dir : Str }

## Loop function which processes each platform in the platform list, gets the app-stub for each.
getAppStubsLoop : AppStubsLoopState -> Task [Step AppStubsLoopState, Done {}] _
getAppStubsLoop = \{ platforms, dir } ->
    when List.get platforms 0 is
        Ok platform ->
            updatedList = List.dropFirst platforms 1
            request = getRequest "https://raw.githubusercontent.com/imclerran/roc-start/main/repository/app-stubs/$(platform).roc"
            Task.attempt (Http.send request) \responseRes ->
                when responseRes is
                    Err e ->
                        when e is
                            HttpErr (BadStatus { code }) if code == 404 -> Task.ok (Step { platforms: updatedList, dir })
                            _ -> Task.err (NetworkErr e)

                    Ok response ->
                        File.writeBytes! response.body "$(dir)/$(platform)"
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
    File.writeBytes bytes "$(config.fileName).roc"

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

# getFileContents : Str -> Task (List Str) _
# getFileContents = \filename ->


