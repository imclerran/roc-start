app [Model, init!, respond!] { 
    web: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.12.0/Q4h_In-sz1BqAvlpmCsBHhEJnn_YvfRRMiNACB_fBbk.tar.br",
    rtils: "https://github.com/imclerran/rtils/releases/download/v0.1.0/MlQteKwQcjXWC51T52AuLGbORPRb9aPRSUUjdwSpHdA.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
    parse: "https://github.com/imclerran/roc-tinyparse/releases/download/v0.3.3/kKiVNqjpbgYFhE-aFB7FfxNmkXQiIo2f_mGUwUlZ3O0.tar.br",
}

import web.Stdout
import web.Http exposing [Request, Response]
import web.Utc


# Model is produced by `init`.
Model : {}

# With `init` you can set up a database connection once at server startup,
# generate css by running `tailwindcss`,...
# In this case we don't have anything to initialize, so it is just `Ok({})`.
init! : {} => Result Model []
init! = |{}| Ok({})

respond! : Request, Model => Result Response [ServerErr Str]_
respond! = |req, _|
    # Log request datetime, method and url
    datetime = Utc.to_iso_8601(Utc.now!({}))

    "${datetime} ${Inspect.to_str(req.method)} ${req.uri}" |> Stdout.line!?

    Ok(
        {
            status: 200,
            headers: [],
            body: "<b>Hello from server</b></br>" |> Str.to_utf8,
        },
    )

