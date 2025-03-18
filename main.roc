app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
}

import cli.Stdout
import cli.Dir
import cli.Path

main! = |_args|
    when Dir.list!("./src/") is
        Ok(files) ->
            List.for_each_try!(
                files,
                |file|
                    path_str = Path.display(file) |> Str.drop_prefix("./src/")
                    if Str.ends_with(path_str, ".roc") then
                        Stdout.line!(path_str)
                    else
                        Ok({}),
            )

        _ -> Err(Exit(1, "Failed to list files"))
