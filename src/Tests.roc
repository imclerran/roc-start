module [stubForMain]

import Model

stubForMain = {}

emptyConfig = { appName: "", platform: "", packages: [] }

# ====================
# TEST MODEL
# ====================

expect
    # TEST: Model.init
    model = Model.init [] []
    model.menuRow
    == 2
    && model.pageFirstItem
    == 0
    && model.cursor
    == { row: 2, col: 2 }
    && model.state
    == InputAppName { nameBuffer: [], config: emptyConfig }

expect
    # TEST: InputAppName to PlatformSelect w/ empty buffer
    model = Model.init [] []
    newModel = Model.toPlatformSelectState model
    newModel.state
    == PlatformSelect { config: { emptyConfig & appName: "main" } }
    && newModel.cursor.row
    == newModel.menuRow

expect
    # TEST: InputAppName to PlatformSelect w/ non-empty buffer
    initModel = Model.init [] []
    model = { initModel &
        state: InputAppName { nameBuffer: ['h', 'e', 'l', 'l', 'o'], config: emptyConfig },
    }
    newModel = Model.toPlatformSelectState model
    newModel.state
    == PlatformSelect { config: { emptyConfig & appName: "hello" } }
    && newModel.cursor.row
    == newModel.menuRow

expect
    # TEST: InputAppName to PlatformSelect w/ non-empty config
    initModel = Model.init [] []
    model = { initModel &
        state: InputAppName { nameBuffer: [], config: { appName: "main", platform: "test", packages: ["test"] } },
    }
    newModel = Model.toPlatformSelectState model
    newModel.state
    == PlatformSelect { config: { appName: "main", platform: "test", packages: ["test"] } }
    && newModel.cursor.row
    == newModel.menuRow

expect
    # TEST: InputAppName to PlatformSelect w/ empty buffer & existing appName in config
    initModel = Model.init [] []
    model = { initModel &
        state: InputAppName { nameBuffer: [], config: { emptyConfig & appName: "hello" } },
    }
    newModel = Model.toPlatformSelectState model
    newModel.state
    == PlatformSelect { config: { emptyConfig & appName: "main" } }
    && newModel.cursor.row
    == newModel.menuRow

expect
    # TEST: InputAppName to UserExited
    model = Model.init [] []
    newModel = Model.toUserExitedState model
    newModel.state == UserExited

expect
    # TEST: paginate InputAppName
    initModel = Model.init [] []
    model = { initModel & state: InputAppName { nameBuffer: ['a'], config: { appName: "b", platform: "c", packages: ["d", "e"] } } }
    newModel = Model.paginate model
    model == newModel

expect
    # TEST: InputAppName - appendToBuffer w/ legal Key
    model = Model.init [] []
    newModel =
        model
        |> Model.appendToBuffer LowerA
        |> Model.appendToBuffer UpperA
        |> Model.appendToBuffer LowerZ
        |> Model.appendToBuffer UpperZ
        |> Model.appendToBuffer Space
        |> Model.appendToBuffer Hyphen
        |> Model.appendToBuffer Underscore
        |> Model.appendToBuffer Number0
        |> Model.appendToBuffer Number9
    newModel.state == InputAppName { nameBuffer: ['a', 'A', 'z', 'Z', '_', '-', '_', '0', '9'], config: emptyConfig }

expect
    # TEST: InputAppName - appendToBuffer w/ illegal Key
    model = Model.init [] []
    newModel =
        model
        |> Model.appendToBuffer Up
        |> Model.appendToBuffer Down
        |> Model.appendToBuffer Left
        |> Model.appendToBuffer Right
        |> Model.appendToBuffer Escape
        |> Model.appendToBuffer Enter
        |> Model.appendToBuffer ExclamationMark
        |> Model.appendToBuffer QuotationMark
        |> Model.appendToBuffer NumberSign
        |> Model.appendToBuffer DollarSign
        |> Model.appendToBuffer PercentSign
        |> Model.appendToBuffer Ampersand
        |> Model.appendToBuffer Apostrophe
        |> Model.appendToBuffer RoundOpenBracket
        |> Model.appendToBuffer RoundCloseBracket
        |> Model.appendToBuffer Asterisk
        |> Model.appendToBuffer PlusSign
        |> Model.appendToBuffer Comma
        |> Model.appendToBuffer FullStop
        |> Model.appendToBuffer ForwardSlash
        |> Model.appendToBuffer Colon
        |> Model.appendToBuffer SemiColon
        |> Model.appendToBuffer LessThanSign
        |> Model.appendToBuffer EqualsSign
        |> Model.appendToBuffer GreaterThanSign
        |> Model.appendToBuffer QuestionMark
        |> Model.appendToBuffer AtSign
        |> Model.appendToBuffer SquareOpenBracket
        |> Model.appendToBuffer Backslash
        |> Model.appendToBuffer SquareCloseBracket
        |> Model.appendToBuffer Caret
        |> Model.appendToBuffer GraveAccent
        |> Model.appendToBuffer CurlyOpenBrace
        |> Model.appendToBuffer VerticalBar
        |> Model.appendToBuffer CurlyCloseBrace
        |> Model.appendToBuffer Tilde
        |> Model.appendToBuffer Delete
    newModel == model

expect
    # TEST: InputAppName - backspaceBuffer
    model = Model.init [] []
    newModel =
        model
        |> Model.appendToBuffer LowerA
        |> Model.backspaceBuffer
    newModel.state == InputAppName { nameBuffer: [], config: emptyConfig }

expect
    # TEST: PlatformSelect - moveCursor Up w/ only one item
    initModel = Model.init ["platform1"] []
    model = Model.toPlatformSelectState initModel
    newModel = model |> Model.moveCursor Up
    newModel == model

expect
    # TEST: PlatformSelect - moveCursor Down w/ only one item
    initModel = Model.init ["platform1"] []
    model = Model.toPlatformSelectState initModel
    newModel = model |> Model.moveCursor Down
    newModel == model

expect
    # TEST: PlatformSelect - moveCursor Up w/ cursor starting at bottom
    initModel =
        Model.init ["platform1", "platform2", "platform3"] []
        |> Model.toPlatformSelectState
    model = { initModel &
        cursor: { row: initModel.menuRow + 2, col: 2 },
    }
    newModel = model |> Model.moveCursor Up
    newModel.cursor.row == model.menuRow + 1

expect
    # TEST: PlatformSelect - moveCursor Down w/ cursor starting at top
    model =
        Model.init ["platform1", "platform2", "platform3"] []
        |> Model.toPlatformSelectState
    newModel = model |> Model.moveCursor Down
    newModel.cursor.row == model.menuRow + 1

expect
    # TEST: PlatformSelect - moveCursor Up w/ cursor starting at top
    model =
        Model.init ["platform1", "platform2", "platform3"] []
        |> Model.toPlatformSelectState
    newModel = model |> Model.moveCursor Up
    newModel.cursor.row == model.menuRow + 2

expect
    # TEST: PlatformSelect - moveCursor Down w/ cursor starting at bottom
    initModel =
        Model.init ["platform1", "platform2", "platform3"] []
        |> Model.toPlatformSelectState
    model = { initModel &
        cursor: { row: initModel.menuRow + 2, col: 2 },
    }
    newModel = model |> Model.moveCursor Down
    newModel.cursor.row == model.menuRow

