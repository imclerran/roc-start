module
    {
        cmd_new,
        cmd_args,
        cmd_output!,
        delete_dirs!,
    } -> [install!]

install! = |cache_dir|
    roc_present_cmd({})
    |> cmd_output!
    |> .status
    |> Result.map_err(|_| Exit(1, "Roc binary could not be found."))
    |> Result.map_ok(|_| {})?
    delete_repo!(cache_dir)
    |> Result.on_err(|DirErr(e)| if e == NotFound then Ok({}) else Err(DirErr(e)))
    |> Result.map_err(|e| Exit(1, "Could not delete previous repository at ${cache_dir}/repo: ${Inspect.to_str(e)}"))?
    clone_cmd(cache_dir)
    |> cmd_output!
    |> .status
    |> Result.map_err(|e| Exit(1, "Could not clone roc-start repository: ${Inspect.to_str(e)}"))
    |> Result.map_ok(|_| {})?
    chmod_cmd(cache_dir)
    |> cmd_output!
    |> .status
    |> Result.map_err(|e| Exit(1, "Could not make install script executable: ${Inspect.to_str(e)}"))
    |> Result.map_ok(|_| {})?
    output =
        install_cmd(cache_dir)
        |> cmd_output!
    output.status
    |> Result.on_err!(
        |err|
            _ =
                delete_repo!(cache_dir)
                |> Result.map_ok(|_| 0)
            Err(err),
    )
    |> Result.map_err(
        |e|
            prefix = "ERROR: "
            sterr = output.stderr |> strip_ansi_control |> Str.from_utf8_lossy |> Str.trim_end |> Str.drop_prefix(prefix)
            when e is
                Other(_) -> Exit(1, "Error installing update: ${sterr}")
                _ -> Exit(1, "Error running install script: ${Inspect.to_str(e)}"),
    )
    |> Result.map_ok(|_| {})?
    delete_repo!(cache_dir)
    |> Result.map_err(|e| Exit(1, "Could not delete repository at ${cache_dir}/repo: ${Inspect.to_str(e)}"))

roc_present_cmd = |{}|
    cmd_new("/usr/bin/env")
    |> cmd_args(["roc", "version"])

clone_cmd = |cache_dir|
    cmd_new("gh")
    |> cmd_args(["repo", "clone", "imclerran/roc-start", "${cache_dir}/repo"])

chmod_cmd = |cache_dir|
    cmd_new("chmod")
    |> cmd_args(["+x", "${cache_dir}/repo/install.sh"])

install_cmd = |cache_dir|
    cmd_new("${cache_dir}/repo/install.sh")
    |> cmd_args(["-y"])

delete_repo! = |cache_dir|
    delete_dirs!("${cache_dir}/repo")

## Strip ANSI control sequences from a list of bytes. (Ensures proper JSON serialization)
strip_ansi_control : List U8 -> List U8
strip_ansi_control = |bytes|
    when List.find_first_index(bytes, |b| b == 27) is
        Ok(escape_index) ->
            { before: lhs, others: remainder } = List.split_at(bytes, escape_index)
            when List.find_first_index(remainder, |b| (b >= 'A' and b <= 'Z') or (b >= 'a' and b <= 'z')) is
                Ok(control_index) ->
                    { before: _, others: rhs } = List.split_at(remainder, (control_index + 1))
                    List.concat(lhs, strip_ansi_control(rhs))

                Err(_) -> bytes

        Err(_) -> bytes
