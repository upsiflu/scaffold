port module Cli exposing (main)

{-| -}

import Cli.Option as Option
import Cli.OptionsParser as OptionsParser
import Cli.Program as Program
import Cli.Validate
import Elm
import Elm.Annotation
import Elm.Case
import Gen.DataSource
import Gen.Effect
import Gen.Html.Styled
import Gen.Platform.Sub
import Gen.Server.Request
import Gen.Server.Response
import Gen.View
import Pages.Generate exposing (Type(..))


type alias CliOptions =
    { moduleName : String
    }


program : Program.Config CliOptions
program =
    Program.config
        |> Program.add
            (OptionsParser.build CliOptions
                |> OptionsParser.with
                    (Option.requiredPositionalArg "module"
                        |> Option.validate (Cli.Validate.regex moduleNameRegex)
                    )
            )


moduleNameRegex : String
moduleNameRegex =
    "([A-Z][a-zA-Z0-9_]*)(\\.([A-Z][a-zA-Z_0-9_]*))*"


main : Program.StatelessProgram Never {}
main =
    Program.stateless
        { printAndExitFailure = printAndExitFailure
        , printAndExitSuccess = printAndExitSuccess
        , init = init
        , config = program
        }


type alias Flags =
    Program.FlagsIncludingArgv {}


init : Flags -> CliOptions -> Cmd Never
init flags cliOptions =
    let
        file : Elm.File
        file =
            createFile (cliOptions.moduleName |> String.split ".")
    in
    writeFile
        { path = file.path
        , body = file.contents
        }


createFile : List String -> Elm.File
createFile moduleName =
    Pages.Generate.serverRender
        { moduleName = moduleName
        , action =
            ( Alias (Elm.Annotation.record [])
            , \routeParams ->
                Gen.Server.Request.succeed
                    (Gen.DataSource.succeed
                        (Gen.Server.Response.render
                            (Elm.record [])
                        )
                    )
            )
        , data =
            ( Alias (Elm.Annotation.record [])
            , \routeParams ->
                Gen.Server.Request.succeed
                    (Gen.DataSource.succeed
                        (Gen.Server.Response.render
                            (Elm.record [])
                        )
                    )
            )
        , head = \app -> Elm.list []
        }
        --|> Pages.Generate.buildNoState
        --    { view =
        --        \_ _ _ ->
        --            Gen.View.make_.view
        --                { title = moduleName |> String.join "." |> Elm.string
        --                , body = Elm.list [ Gen.Html.text "Here is your generated page!!!" ]
        --                }
        --    }
        |> Pages.Generate.buildWithLocalState
            { view =
                \maybeUrl sharedModel model app ->
                    Gen.View.make_.view
                        { title = moduleName |> String.join "." |> Elm.string
                        , body = Elm.list [ Gen.Html.Styled.text "Here is your generated page!!!" ]
                        }
            , update =
                \pageUrl sharedModel app msg model ->
                    Elm.Case.custom msg
                        (Elm.Annotation.named [] "Msg")
                        [ Elm.Case.branch0 "NoOp"
                            (Elm.tuple model
                                (Gen.Effect.none
                                    |> Elm.withType effectType
                                )
                            )
                        ]
            , init =
                \pageUrl sharedModel app ->
                    Elm.tuple (Elm.record [])
                        (Gen.Effect.none
                            |> Elm.withType effectType
                        )
            , subscriptions =
                \maybePageUrl routeParams path sharedModel model ->
                    Gen.Platform.Sub.none
            , model =
                Alias (Elm.Annotation.record [])
            , msg =
                Custom [ Elm.variant "NoOp" ]
            }


effectType : Elm.Annotation.Annotation
effectType =
    Elm.Annotation.namedWith [ "Effect" ] "Effect" [ Elm.Annotation.var "msg" ]


port print : String -> Cmd msg


port printAndExitFailure : String -> Cmd msg


port printAndExitSuccess : String -> Cmd msg


port writeFile : { path : String, body : String } -> Cmd msg
