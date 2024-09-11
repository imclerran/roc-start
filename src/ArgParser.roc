module [parseOrDisplayMessage, baseUsage, extendedUsage]

import cli.Arg.Cli as Cli
import cli.Arg.Help as Help
import cli.Arg.Opt as Opt
import cli.Arg.Param as Param
import cli.Arg.SubCmd as Subcommand

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
    { Cli.combine <-
        update: Opt.flag { short: "u", long: "update", help: "Update the platform and package repositories." },
        subcommand: Subcommand.optional [tuiSubcommand, updateSubcommand, appSubcommand, pkgSubcommand],
    }
    |> Cli.finish {
        name: "roc-start",
        version: "v0.4.0",
        authors: ["Ian McLerran <imclerran@protonmail.com>"],
        description: "A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.",
        textStyle: Color,
    }
    |> Cli.assertValid

appSubcommand =
    { Cli.combine <-
        appName: Param.str { name: "app-name", help: "Name your new roc app." },
        platform: Param.str { name: "platform", help: "The platform to use." },
        packages: Param.strList { name: "packages", help: "Any packages to use." },
    }
    |> Subcommand.finish {
        name: "app",
        description: "Create a new roc app with the specified name, platform, and packages.",
        mapper: App,
    }

pkgSubcommand =
    Param.strList { name: "packages", help: "Any packages to use." }
    |> Subcommand.finish {
        name: "pkg",
        description: "Create a new roc package main file with any other specified packages dependencies.",
        mapper: Pkg,
    }

tuiSubcommand =
    Opt.flag { short: "s", long: "secret" }
    |> Subcommand.finish {
        name: "tui",
        description: "Use the TUI app to browse and search for platforms and packages.",
        mapper: Tui,
    }

updateSubcommand =
    { Cli.combine <-
        doPkgs: Opt.flag { short: "k", long: "packages", help: "Update the package repositories." },
        doPfs: Opt.flag { short: "f", long: "platforms", help: "Update the platform repositories." },
        doStubs: Opt.flag { short: "s", long: "app-stubs", help: "Update the app stubs." },
    }
    |> Subcommand.finish {
        name: "update",
        description: "Update the platform and package repositories and app stubs. Update all, or specify which to update.",
        mapper: Update,
    }
