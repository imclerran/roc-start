module [parseOrDisplayMessage, baseUsage, extendedUsage]

import weaver.Cli
import weaver.Help
import weaver.Opt
import weaver.Param
import weaver.SubCmd

parseOrDisplayMessage = \args -> Cli.parseOrDisplayMessage cliParser args

baseUsage = Help.usageHelp cliParser.config ["roc-start"] cliParser.textStyle

extendedUsage =
    ansiCode =
        when cliParser.textStyle is
            Color -> "\u(001b)[1m\u(001b)[4m"
            Plain -> ""
    usageHelpStr = Help.usageHelp cliParser.config ["roc-start"] cliParser.textStyle
    extendedUsageStr =
        when
            Help.helpText cliParser.config ["roc-start"] cliParser.textStyle
            |> Str.splitFirst "$(ansiCode)Commands:"
        is
            Ok { after } -> "$(ansiCode)Commands:$(after)"
            Err NotFound -> ""
    Str.joinWith [usageHelpStr, extendedUsageStr] "\n\n"

cliParser =
    { Cli.weave <-
        update: Opt.flag { short: "u", long: "update", help: "Update the platform and package repositories." },
        subcommand: SubCmd.optional [tuiSubcommand, updateSubcommand, appSubcommand, pkgSubcommand, upgradeSubcommand],
    }
    |> Cli.finish {
        name: "roc-start",
        version: "v0.5.1",
        authors: ["Ian McLerran <imclerran@protonmail.com>"],
        description: "A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.",
        textStyle: Color,
    }
    |> Cli.assertValid

appSubcommand =
    { Cli.weave <-
        appName: Param.str { name: "app-name", help: "Name your new roc app." },
        platform: Param.str { name: "platform", help: "The platform to use." },
        packages: Param.strList { name: "packages", help: "Any packages to use." },
    }
    |> SubCmd.finish {
        name: "app",
        description: "Create a new roc app with the specified name, platform, and packages.",
        mapper: App,
    }

pkgSubcommand =
    Param.strList { name: "packages", help: "Any packages to use." }
    |> SubCmd.finish {
        name: "pkg",
        description: "Create a new roc package main file with any other specified packages dependencies.",
        mapper: Pkg,
    }

tuiSubcommand =
    Opt.flag { short: "s", long: "secret" }
    |> SubCmd.finish {
        name: "tui",
        description: "Use the TUI app to browse and search for platforms and packages.",
        mapper: Tui,
    }

updateSubcommand =
    { Cli.weave <-
        doPkgs: Opt.flag { short: "k", long: "packages", help: "Update the package repositories." },
        doPfs: Opt.flag { short: "f", long: "platforms", help: "Update the platform repositories." },
        doStubs: Opt.flag { short: "s", long: "app-stubs", help: "Update the app stubs." },
    }
    |> SubCmd.finish {
        name: "update",
        description: "Update the platform and package repositories and app stubs. Update all, or specify which to update.",
        mapper: Update,
    }

upgradeSubcommand = 
    { Cli.weave <-
        filename: Param.str { name: "filename", help: "The name of the file who's platforms and/or packages should be upgraded." },
        toUpgrade: Param.strList { name: "to-upgrade", help: "List of platform and package names to upgrade. If ommitted, all will be upgraded." },
    }
    |> SubCmd.finish {
        name: "upgrade",
        description: "Upgrade the platform and/or packages in an app or package",
        mapper: Upgrade,
    }
