module [parseOrDisplayMessage, baseUsage]

import weaver.Cli
import weaver.Help
import weaver.Opt
import weaver.Param
import weaver.Subcommand

parseOrDisplayMessage = \args -> Cli.parseOrDisplayMessage cliParser args

baseUsage = Help.usageHelp cliParser.config ["roc-start"] cliParser.textStyle

cliParser =
    Cli.weave {
        update: <- Opt.flag { short: "u", long: "update", help: "Update the platform and package repositories." },
        subcommand: <- Subcommand.optional [tuiSubcommand],
        appName: <- Param.maybeStr { name: "app-name", help: "Name your new roc app." },
        platform: <- Param.maybeStr { name: "platform", help: "The platform to use." },
        packages: <- Param.strList { name: "files", help: "Any packages to use." },
        
    }
    |> Cli.finish {
        name: "roc-start",
        version: "v0.2.0",
        authors: ["Ian McLerran <imclerran@protonmail.com>"],
        description: "A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.",
    }
    |> Cli.assertValid

tuiSubcommand = 
    Cli.weave {}
    |> Subcommand.finish { 
        name: "tui",
        description: "Use the TUI app to browse and search for platforms and packages.",
        mapper: Tui,
    }