app [main!] { 
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    ai: "https://github.com/imclerran/roc-ai/releases/download/v0.10.1/iIKfbjobbmHIC5lW5pIWKkdMqVHX4IEgpdOO7EReYUM.tar.br",
}

import cli.Stdout

main! = |_args|
    Stdout.line!("Hello, World!")
