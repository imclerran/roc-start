module [stubForMain]

import Model

stubForMain = {}

emptyConfig = { appName: "", platform: "", packages: [] }

#====================
# TEST MODEL
#====================

expect # TEST: Model.init
    model = Model.init [] []
    model.menuRow == 2 &&
    model.pageFirstItem == 0 &&
    model.cursor == { row: 2, col: 2 } &&
    model.state == InputAppName { nameBuffer: [], config: emptyConfig }

expect # TEST: InputAppName to PlatformSelect w/ empty buffer
    model = Model.init [] []
    newModel = Model.toPlatformSelectState model
    newModel.state == PlatformSelect { config: { emptyConfig & appName: "main" } } &&
    newModel.cursor.row == newModel.menuRow

expect # TEST: InputAppName to PlatformSelect w/ non-empty buffer
    initModel = Model.init [] []
    model = { initModel &
        state: InputAppName { nameBuffer: ['h', 'e', 'l', 'l', 'o'], config: emptyConfig }
    }
    newModel = Model.toPlatformSelectState model
    newModel.state == PlatformSelect { config: { emptyConfig & appName: "hello" } } && 
    newModel.cursor.row == newModel.menuRow

expect # TEST: InputAppName to PlatformSelect w/ non-empty config
    initModel = Model.init [] []
    model = { initModel &
        state: InputAppName { nameBuffer: [], config: { appName: "main", platform: "test", packages: ["test"] } }
    }
    newModel = Model.toPlatformSelectState model
    newModel.state == PlatformSelect { config: { appName: "main", platform: "test", packages: ["test"] } } &&
    newModel.cursor.row == newModel.menuRow

expect # TEST: PlatformSelect to PackageSelect w/ empty buffer & existing appName in config
    initModel = Model.init [] []
    model = { initModel &
        state: InputAppName { nameBuffer: [], config: { emptyConfig & appName: "hello" } }
    }
    newModel = Model.toPlatformSelectState model
    newModel.state == PlatformSelect { config: { emptyConfig & appName: "main" } } &&
    newModel.cursor.row == newModel.menuRow


    





