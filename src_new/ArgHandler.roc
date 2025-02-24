module [handle_app]

import rtils.StrUtils

handle_app = |{ out_name, platform: pf_arg, packages: pkgs_arg }|
    platform =
        when pf_arg is
            Ok(s) ->
                { before: name, after: version } =
                    StrUtils.split_first_if(s, |c| List.contains([':', '='], c))
                    |> Result.with_default({ before: s, after: "latest" })
                { name, version }

            Err(_) -> { name: "basic-cli", version: "latest" }
    file_name =
        when out_name is
            Ok(s) -> if Str.ends_with(s, ".roc") then s else "${s}.roc"
            Err(_) -> "main.roc"
    packages = List.map(
        pkgs_arg,
        |pkg|
            { before: name, after: version } = Str.split_first(pkg, ":") |> Result.with_default({ before: pkg, after: "latest" })
            { name, version },
    )
    { file_name, platform, packages }
