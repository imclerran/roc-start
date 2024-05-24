app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
}

import pf.Task
import pf.Cmd
import pf.Stdout
import pf.File
import pf.Path

main =
    configExists <- Path.isFile (Path.fromStr "config.rvn") |> Task.await
    if configExists then
        File.writeUtf8! (Path.fromStr "config.rvn") configTemplate
        editFile
    else
        editFile

editFile =
    Cmd.exec! "nano" ["config.rvn"]
    contents = File.readUtf8! (Path.fromStr "config.rvn")
    Stdout.line "file contents: $(contents)"

configTemplate =
    """
    {
        appName: "new-app",
        platform: "basic-cli",
        packages: [], # packages list may be empty
    }
    """
