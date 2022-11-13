module Api exposing (routes)

import ApiRoute exposing (ApiRoute)
import DataSource exposing (DataSource)
import Form
import Form.Field as Field
import Form.Validation as Validation
import Html exposing (Html)
import Json.Decode as Decode
import Json.Encode as Encode
import Pages
import Random
import Result.Extra
import Route exposing (Route)
import Server.Request as Request
import Server.Response as Response exposing (Response)
import Test.Glob
import Test.Runner.Html
import Time
import Xml.Decode


routes :
    DataSource (List Route)
    -> (Maybe { indent : Int, newLines : Bool } -> Html Never -> String)
    -> List (ApiRoute.ApiRoute ApiRoute.Response)
routes getStaticRoutes htmlToString =
    let
        html : Html Never -> Response data Never
        html htmlValue =
            htmlToString Nothing htmlValue
                |> Response.body
                |> Response.withHeader "Content-Type" "text/html; charset=UTF-8"
    in
    [ greet
    , ApiRoute.succeed
        (Request.succeed
            (Test.Glob.all
                |> DataSource.map viewHtmlResults
                |> DataSource.map html
            )
        )
        |> ApiRoute.literal "tests"
        |> ApiRoute.serverRender
    , requestPrinter
    , xmlDecoder
    , multipleContentTypes
    ]


xmlDecoder : ApiRoute ApiRoute.Response
xmlDecoder =
    let
        dataDecoder : Xml.Decode.Decoder String
        dataDecoder =
            Xml.Decode.path [ "path", "to", "string", "value" ] (Xml.Decode.single Xml.Decode.string)
    in
    ApiRoute.succeed
        (Request.map2
            (\_ xmlString ->
                xmlString
                    |> Xml.Decode.run dataDecoder
                    |> Result.Extra.merge
                    |> Response.plainText
                    |> DataSource.succeed
            )
            (Request.expectContentType "application/xml")
            Request.expectBody
        )
        |> ApiRoute.literal "api"
        |> ApiRoute.slash
        |> ApiRoute.literal "xml"
        |> ApiRoute.serverRender


multipleContentTypes : ApiRoute ApiRoute.Response
multipleContentTypes =
    let
        dataDecoder : Xml.Decode.Decoder String
        dataDecoder =
            Xml.Decode.path [ "path", "to", "string", "value" ] (Xml.Decode.single Xml.Decode.string)
    in
    ApiRoute.succeed
        (Request.oneOf
            [ Request.map2
                (\_ xmlString ->
                    xmlString
                        |> Xml.Decode.run dataDecoder
                        |> Result.Extra.merge
                        |> Response.plainText
                        |> DataSource.succeed
                )
                (Request.expectContentType "application/xml")
                Request.expectBody
            , Request.map
                (\decodedValue ->
                    decodedValue
                        |> Response.plainText
                        |> DataSource.succeed
                )
                (Request.expectJsonBody (Decode.at [ "path", "to", "string", "value" ] Decode.string))
            ]
        )
        |> ApiRoute.literal "api"
        |> ApiRoute.slash
        |> ApiRoute.literal "multiple-content-types"
        |> ApiRoute.serverRender


requestPrinter : ApiRoute ApiRoute.Response
requestPrinter =
    ApiRoute.succeed
        (Request.map4
            (\rawBody method cookies queryParams ->
                Encode.object
                    [ ( "rawBody"
                      , Maybe.map Encode.string rawBody
                            |> Maybe.withDefault Encode.null
                      )
                    , ( "method"
                      , method |> Request.methodToString |> Encode.string
                      )
                    , ( "cookies"
                      , cookies |> Encode.dict identity Encode.string
                      )
                    , ( "queryParams"
                      , queryParams |> Encode.dict identity (Encode.list Encode.string)
                      )
                    ]
                    |> Response.json
                    |> DataSource.succeed
            )
            Request.rawBody
            Request.method
            Request.allCookies
            Request.queryParams
        )
        |> ApiRoute.literal "api"
        |> ApiRoute.slash
        |> ApiRoute.literal "request-test"
        |> ApiRoute.serverRender


config : Test.Runner.Html.Config
config =
    Random.initialSeed (Pages.builtAt |> Time.posixToMillis)
        |> Test.Runner.Html.defaultConfig
        |> Test.Runner.Html.hidePassedTests


viewHtmlResults tests =
    Html.div []
        [ Html.h1 [] [ Html.text "My Test Suite" ]
        , Html.div [] [ Test.Runner.Html.viewResults config tests ]
        ]


greet : ApiRoute ApiRoute.Response
greet =
    ApiRoute.succeed
        (Request.oneOf
            [ Request.formData
                (Form.init
                    (\bar ->
                        { combine =
                            Validation.succeed identity
                                |> Validation.andMap bar
                        , view =
                            \_ -> ()
                        }
                    )
                    |> Form.field "first" (Field.text |> Field.required "Required")
                    |> Form.initCombined identity
                )
                |> Request.andThen
                    (\result ->
                        result
                            |> Result.mapError (\_ -> "")
                            |> Request.fromResult
                    )
            , Request.expectJsonBody (Decode.field "first" Decode.string)
            , Request.expectQueryParam "first"
            , Request.expectMultiPartFormPost
                (\{ field, optionalField } ->
                    field "first"
                )
            ]
            |> Request.map
                (\firstName ->
                    Response.plainText ("Hello " ++ firstName)
                        |> DataSource.succeed
                )
        )
        |> ApiRoute.literal "api"
        |> ApiRoute.slash
        |> ApiRoute.literal "greet"
        |> ApiRoute.serverRender
