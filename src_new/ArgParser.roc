module [parse_or_display_message, base_usage, extended_usage]

import weaver.Cli
import weaver.Help
import weaver.Opt
import weaver.Param
import weaver.SubCmd

parse_or_display_message = |args, to_os| Cli.parse_or_display_message(cli_parser, args, to_os)

base_usage = Help.usage_help(cli_parser.config, ["roc-start"], cli_parser.text_style)

extended_usage =
    ansi_code =
        when cli_parser.text_style is
            Color -> "\u(001b)[1m\u(001b)[4m"
            Plain -> ""
    usage_help_str = Help.usage_help(cli_parser.config, ["roc-start"], cli_parser.text_style)
    extended_usage_str =
        when
            Help.help_text(cli_parser.config, ["roc-start"], cli_parser.text_style)
            |> Str.split_first("${ansi_code}Commands:")
        is
            Ok({ after }) -> "${ansi_code}Commands:${after}"
            Err(NotFound) -> ""
    Str.join_with([usage_help_str, extended_usage_str], "\n\n")

cli_parser =
    SubCmd.optional([tui_subcommand, update_subcommand, app_subcommand, pkg_subcommand, upgrade_subcommand])
    |> Cli.finish(
        {
            name: "roc-start",
            version: "v0.5.1",
            authors: ["Ian McLerran <imclerran@protonmail.com>"],
            description: "A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.",
            text_style: Color,
        },
    )
    |> Cli.assert_valid

app_subcommand =
    { Cli.weave <-
        force: Opt.flag({ short: "f", long: "force", help: "Force overwrite of existing file." }),
        out_name: Opt.maybe_str({ short: "o", long: "out", help: "The name of the output file (Defaults to `main.roc`). Extension is not required." }),
        platform: Opt.maybe_str({ short: "p", long: "platform", help: "The platform to use (Defaults to `basic-cli=latest`). Set the version with `--platform <platform>=<version>`." }),
        packages: Param.str_list({ name: "packages", help: "Any packages to use." }), 
    }
    |> SubCmd.finish(
        {
            name: "app",
            description: "Create a new roc app with the specified name, platform, and packages.",
            mapper: App,
        },
    )

pkg_subcommand =
    Param.str_list({ name: "packages", help: "Any packages to use." })
    |> SubCmd.finish(
        {
            name: "pkg",
            description: "Create a new roc package main file with any other specified packages dependencies.",
            mapper: Pkg,
        },
    )

tui_subcommand =
    Opt.flag({ short: "s", long: "secret" })
    |> SubCmd.finish(
        {
            name: "tui",
            description: "Use the TUI app to browse and search for platforms and packages.",
            mapper: Tui,
        },
    )

update_subcommand =
    { Cli.weave <-
        do_packages: Opt.flag({ short: "k", long: "packages", help: "Update the package repositories." }),
        do_platforms: Opt.flag({ short: "f", long: "platforms", help: "Update the platform repositories." }),
        do_scripts: Opt.flag({ short: "s", long: "scripts", help: "Update the platform scripts." }),
    }
    |> SubCmd.finish(
        {
            name: "update",
            description: "Update the platform and package repositories and scripts. Update all, or specify which to update.",
            mapper: Update,
        },
    )

upgrade_subcommand =
    { Cli.weave <-
        filename: Param.str({ name: "filename", help: "The name of the file who's platforms and/or packages should be upgraded." }),
        to_upgrade: Param.str_list({ name: "to-upgrade", help: "List of platform and package names to upgrade. If ommitted, all will be upgraded." }),
    }
    |> SubCmd.finish(
        {
            name: "upgrade",
            description: "Upgrade the platform and/or packages in an app or package",
            mapper: Upgrade,
        },
    )
