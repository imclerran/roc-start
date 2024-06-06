import webserver.Webserver exposing [Request, Response]

Program : {
    decodeModel : [Init, Existing (List U8)] -> Result Model Str,
    encodeModel : Model -> List U8,
    handleReadRequest : Request, Model -> Response,
    handleWriteRequest : Request, Model -> (Response, Model),
}

Model : # TODO: Define your model here

main : Program
main = {
    decodeModel,
    encodeModel,
    handleReadRequest,
    handleWriteRequest,
}

decodeModel : [Init, Existing (List U8)] -> Result Model Str
decodeModel = \fromPlatform -> crash "TODO: Implement decodeModel"

encodeModel : Model -> List U8
encodeModel = \model -> crash "TODO: Implement encodeModel"

handleReadRequest : Request, Model -> Response
handleReadRequest = \_request, model -> crash "TODO: Implement handleReadRequest"

handleWriteRequest : Request, Model -> (Response, Model)
handleWriteRequest = \request, _model -> crash "TODO: Implement handleWriteRequest"