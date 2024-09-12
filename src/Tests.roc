module []

import Model
import Controller

## ===============================
## HELPER FUNCTIONS

applyAction = \model, action ->
    when Controller.applyAction { model, action } is
        Step newModel -> newModel
        Done newModel -> newModel

applyActionWithKey = \model, action, keyPress ->
    when Controller.applyAction { model, action, keyPress } is
        Step newModel -> newModel
        Done newModel -> newModel

## ===============================
## HELPER OBJECTS

emptyAppConfig = { fileName: "", platform: "", packages: [], type: App }
emptyPkgConfig = { fileName: "main", platform: "", packages: [], type: Pkg }

## ===============================
## MODEL OBJECTS IN VARIOUS STATES

typeSelectModel = Model.init ["pf1", "pf2"] ["pk1", "pk2", "pk3"] {}
inputAppNameModel = typeSelectModel |> applyAction SingleSelect
platformSelectModel = inputAppNameModel |> applyAction TextSubmit
packageSelectModel = platformSelectModel |> applyAction SingleSelect
confirmationModel = packageSelectModel |> applyAction MultiConfirm
finishedModel = confirmationModel |> applyAction Finish
splashModel = typeSelectModel |> applyAction Secret

## ===============================
## model object tests

expect
    # TEST: init model
    model = typeSelectModel
    (model.state == TypeSelect { config: emptyAppConfig })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.menu == ["App", "Package"])
    && (model.fullMenu == ["App", "Package"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)
    && (Model.getHighlightedItem model == "App")

expect
    # TEST: transition from TypeSelect to InputAppName
    model = inputAppNameModel
    (model.state == InputAppName { nameBuffer: [], config: emptyAppConfig })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from InputAppName to PlatformSelect (empty buffer)
    model = platformSelectModel
    (model.state == PlatformSelect { config: { emptyAppConfig & fileName: "main" } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.menu == ["pf1", "pf2"])
    && (model.fullMenu == ["pf1", "pf2"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from PlatformSelect to PackageSelect
    model = packageSelectModel
    (model.state == PackageSelect { config: { emptyAppConfig & fileName: "main", platform: "pf1" } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.menu == ["pk1", "pk2", "pk3"])
    && (model.fullMenu == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from PackageSelect to Confirmation
    model = confirmationModel
    (model.state == Confirmation { config: { emptyAppConfig & fileName: "main", platform: "pf1", packages: [] } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from Confirmation to Finished
    model = finishedModel
    (model.state == Finished { config: { emptyAppConfig & fileName: "main", platform: "pf1", packages: [] } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # Test: transition from TypeSelect to Splash
    model = splashModel
    (model.state == Splash { config: emptyAppConfig })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

## ===============================
## Exit tests

expect
    # TEST: exit from TypeSelect
    model = typeSelectModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: exit from InputAppName
    model = inputAppNameModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: exit from PlatformSelect
    model = platformSelectModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: exit from PackageSelect
    model = packageSelectModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: exit from Confirmation
    model = confirmationModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: exit from Finished
    model = finishedModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: exit from Splash
    model = splashModel |> applyAction Exit
    model.state == UserExited

## ===============================
## Cursor movement tests

expect
    # TEST: move cursor down from top of menu
    model = typeSelectModel |> applyAction CursorDown
    model.cursor == { row: model.menuRow + 1, col: 2 }

expect
    # TEST: move cursor up from bottom of menu
    model = typeSelectModel |> applyAction CursorDown |> applyAction CursorUp
    model.cursor == { row: model.menuRow, col: 2 }

expect
    # TEST: move cursor up from top of menu
    model = typeSelectModel |> applyAction CursorUp
    model.cursor == { row: model.menuRow + 1, col: 2 }

expect
    # TEST: move cursor down from bottom of menu
    model = typeSelectModel |> applyAction CursorDown |> applyAction CursorDown
    model.cursor == { row: model.menuRow, col: 2 }

expect
    # TEST: move cursor down with only one item in menu
    model = { typeSelectModel & menu: ["App"] } |> applyAction CursorDown
    model.cursor == { row: model.menuRow, col: 2 }

expect
    # TEST: move cursor up with only one item in menu
    model = { typeSelectModel & menu: ["App"] } |> applyAction CursorUp
    model.cursor == { row: model.menuRow, col: 2 }

## ===============================
## Pagination tests

expect
    # TEST: paginate TypeSelect with no need to paginate
    screen = { height: 5, width: 0 }
    model = { typeSelectModel & screen } |> Controller.paginate
    (model.menu == ["App", "Package"])
    && (model.fullMenu == ["App", "Package"])
    && !(Controller.actionIsAvailable model NextPage)
    && !(Controller.actionIsAvailable model PrevPage)

expect
    # TEST: paginate TypeSelect
    model = { typeSelectModel & screen: { height: 4, width: 0 } } |> Controller.paginate
    (model.menu == ["App"])
    && (model.fullMenu == ["App", "Package"])
    && (Controller.actionIsAvailable model NextPage)
    && !(Controller.actionIsAvailable model PrevPage)

expect
    # TEST: prev and next available on middle page
    model =
        { packageSelectModel & screen: { height: 4, width: 0 } }
        |> Controller.paginate
        |> applyAction NextPage
    (model.menu == ["pk2"])
    && (model.fullMenu == ["pk1", "pk2", "pk3"])
    && (Controller.actionIsAvailable model NextPage)
    && (Controller.actionIsAvailable model PrevPage)

expect
    # TEST: paginate - undersized menu fills screen (available rows > remaining menu items)
    model =
        { packageSelectModel & screen: { height: 5, width: 0 } }
        |> Controller.paginate
    nextModel =
        model
        |> applyAction NextPage
        |> Controller.paginate
    (model.menu == ["pk1", "pk2"])
    && (nextModel.menu == ["pk2", "pk3"])

expect
    # TEST: first item on page does not change when paginating
    model =
        { packageSelectModel & screen: { height: 5, width: 0 } }
        |> Controller.paginate
        |> applyAction NextPage
        |> Controller.paginate
    smallSizeModel =
        { model & screen: { height: 4, width: 0 } }
        |> Controller.paginate
    resetSizeModel =
        { smallSizeModel & screen: { height: 5, width: 0 } }
        |> Controller.paginate
    (model.menu == ["pk2", "pk3"])
    && (smallSizeModel.menu == ["pk2"])
    && (resetSizeModel == model)

expect
    # TEST: previous page - available rows exceed previous menu items
    model =
        { packageSelectModel & screen: { height: 5, width: 0 } }
        |> Controller.paginate
        |> applyAction NextPage
        |> Controller.paginate
    prevModel =
        model
        |> applyAction PrevPage
        |> Controller.paginate
    (
        model.menu
        == ["pk2", "pk3"]
        && prevModel.menu
        == ["pk1", "pk2"]
    )

## ===============================
## TypeSelect tests

expect
    # TEST: SingleSelect from TypeSelect (App)
    model = typeSelectModel |> applyAction SingleSelect
    model.state == InputAppName { nameBuffer: [], config: emptyAppConfig }

expect
    # TEST: SingleSelect from TypeSelect (Package)
    model = { typeSelectModel & cursor: { row: 3, col: 2 } } |> applyAction SingleSelect
    model.state == PackageSelect { config: emptyPkgConfig }

## ===============================
## InputAppName tests

expect
    # TEST: InputAppName back to TypeSelect
    model = inputAppNameModel |> applyAction GoBack
    model.state == TypeSelect { config: emptyAppConfig }

expect
    # TEST: InuptAppName to PlatformSelect w/ non-empty buffer
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (Lower A)
        |> applyAction TextSubmit
    model.state == PlatformSelect { config: { emptyAppConfig & fileName: "a" } }

expect
    # TEST: InputAppName to PlatformSelect w/ non-empty config
    config = { fileName: "main", platform: "test", packages: ["test"], type: App }
    state = InputAppName { nameBuffer: [], config }
    model =
        { inputAppNameModel & state }
        |> applyAction TextSubmit
    model.state == PlatformSelect { config }

expect
    # TEST: InputAppName to PlatformSelect w/ empty buffer & different fileName in config
    config = { emptyAppConfig & fileName: "hello" }
    state = InputAppName { nameBuffer: [], config }
    model = { inputAppNameModel & state } |> applyAction TextSubmit
    model.state == PlatformSelect { config: { emptyAppConfig & fileName: "main" } }

expect
    # TEST: paginate InputAppName (should not change model)
    model = inputAppNameModel |> Controller.paginate
    model == inputAppNameModel

expect
    # TEST: valid text input to InputAppName
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (Lower A)
        |> applyActionWithKey TextInput (Upper A)
        |> applyActionWithKey TextInput (Lower Z)
        |> applyActionWithKey TextInput (Upper Z)
        |> applyActionWithKey TextInput (Action Space)
        |> applyActionWithKey TextInput (Symbol Hyphen)
        |> applyActionWithKey TextInput (Symbol Underscore)
        |> applyActionWithKey TextInput (Number N0)
        |> applyActionWithKey TextInput (Number N9)
    model.state == InputAppName { nameBuffer: ['a', 'A', 'z', 'Z', '_', '-', '_', '0', '9'], config: emptyAppConfig }

expect
    # TEST: invalid text input to InputAppName
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (Symbol ExclamationMark)
        |> applyActionWithKey TextInput (Symbol QuotationMark)
        |> applyActionWithKey TextInput (Symbol NumberSign)
        |> applyActionWithKey TextInput (Symbol DollarSign)
        |> applyActionWithKey TextInput (Symbol PercentSign)
        |> applyActionWithKey TextInput (Symbol Ampersand)
        |> applyActionWithKey TextInput (Symbol Apostrophe)
        |> applyActionWithKey TextInput (Symbol RoundOpenBracket)
        |> applyActionWithKey TextInput (Symbol RoundCloseBracket)
        |> applyActionWithKey TextInput (Symbol Asterisk)
        |> applyActionWithKey TextInput (Symbol PlusSign)
        |> applyActionWithKey TextInput (Symbol Comma)
        |> applyActionWithKey TextInput (Symbol FullStop)
        |> applyActionWithKey TextInput (Symbol ForwardSlash)
        |> applyActionWithKey TextInput (Symbol Colon)
        |> applyActionWithKey TextInput (Symbol SemiColon)
        |> applyActionWithKey TextInput (Symbol LessThanSign)
        |> applyActionWithKey TextInput (Symbol EqualsSign)
        |> applyActionWithKey TextInput (Symbol GreaterThanSign)
        |> applyActionWithKey TextInput (Symbol QuestionMark)
        |> applyActionWithKey TextInput (Symbol AtSign)
        |> applyActionWithKey TextInput (Symbol SquareOpenBracket)
        |> applyActionWithKey TextInput (Symbol Backslash)
        |> applyActionWithKey TextInput (Symbol SquareCloseBracket)
        |> applyActionWithKey TextInput (Symbol Caret)
        |> applyActionWithKey TextInput (Symbol GraveAccent)
        |> applyActionWithKey TextInput (Symbol CurlyOpenBrace)
        |> applyActionWithKey TextInput (Symbol VerticalBar)
        |> applyActionWithKey TextInput (Symbol CurlyCloseBrace)
        |> applyActionWithKey TextInput (Symbol Tilde)
    model.state == InputAppName { nameBuffer: [], config: emptyAppConfig }

expect
    # TEST: backspace with InputAppName
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (Lower A)
        |> applyActionWithKey TextInput (Lower B)
        |> applyActionWithKey TextInput (Lower C)
        |> applyAction TextBackspace
    model.state == InputAppName { nameBuffer: ['a', 'b'], config: emptyAppConfig }

expect
    # TEST: backspace with empty buffer in InputAppName
    model = inputAppNameModel |> applyAction TextBackspace
    model == inputAppNameModel

expect
    # TEST: transition from TypeSelect to InputAppName state
    model = typeSelectModel |> applyAction SingleSelect
    model.state == InputAppName { nameBuffer: [], config: emptyAppConfig }

# expect
#     # TEST: PlatformSelect to InputAppName
#     initModel =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         state: PlatformSelect { config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } },
#     }
#     newModel = Model.toInputAppNameState model
#     newModel.state
#     == InputAppName { nameBuffer: ['a'], config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: PlatformSelect to Search
#     initModel =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         state: PlatformSelect { config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } },
#     }
#     newModel = Model.toSearchState model
#     newModel.state
#     == Search { searchBuffer: [], sender: Platform, config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } }
#     && newModel.cursor.row
#     == newModel.menuRow
