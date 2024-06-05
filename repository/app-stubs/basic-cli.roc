import cli.Stdout
import cli.Task exposing [Task]

main : Task {} _
main =
    Stdout.line! "Hello, world!"