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
        subcommand: <- Subcommand.optional [configFileSubcommand, updateSubcommand],
        appName: <- Param.maybeStr { name: "app-name", help: "Name your new roc app." },
        platform: <- Param.maybeStr { name: "platform", help: "The platform to use." },
        packages: <- Param.strList { name: "files", help: "Any packages to use." },
        
    }
    |> Cli.finish {
        name: "roc-start",
        version: "v0.1.0",
        authors: ["Ian McLerran <imclerran@protonmail.com>"],
        description: "A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.",
    }
    |> Cli.assertValid

updateSubcommand = 
    Cli.weave {}
    |> Subcommand.finish { 
        name: "update",
        description: "Update the platform and package repositories.",
        mapper: Update,
    }

configFileSubcommand =
    Cli.weave {
        delete: <- Opt.flag { short: "d", help: "Delete config file when finished." },
        file: <- Param.maybeStr { name: "file", help: "The .rvn file to use." },
    }
    |> Subcommand.finish {
        name: "config",
        description: "Use a configuration file to describes the application and dependencies.",
        mapper: Config,
    }