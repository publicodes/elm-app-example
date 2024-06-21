module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Effect
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode
import Json.Decode.Pipeline as Decode
import Json.Encode
import Publicodes as P


main : Program Json.Encode.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Flags =
    { rules : P.RawRules
    , situation : P.Situation
    }


flagsDecoder : Json.Decode.Decoder Flags
flagsDecoder =
    Json.Decode.succeed Flags
        |> Decode.required "rules" P.rawRulesDecoder
        |> Decode.required "situation" P.situationDecoder


type alias Model =
    { rules : P.RawRules
    , situation : P.Situation
    , evaluations : Dict P.RuleName P.NodeValue
    , result : Maybe P.NodeValue
    , errorMsg : Maybe String
    }


emptyModel : Model
emptyModel =
    { rules = Dict.empty
    , situation = Dict.empty
    , evaluations = Dict.empty
    , result = Nothing
    , errorMsg = Nothing
    }


init : Json.Encode.Value -> ( Model, Cmd Msg )
init flags =
    case Json.Decode.decodeValue flagsDecoder flags of
        Ok { rules, situation } ->
            ( { emptyModel | rules = rules, situation = situation }
            , Effect.evaluateAll (Dict.keys rules)
            )

        Err e ->
            ( { emptyModel | errorMsg = Just (Json.Decode.errorToString e) }
            , Cmd.none
            )



-- UPDATE


type Msg
    = NewAnswer ( P.RuleName, P.NodeValue )
    | Evaluate
    | UpdateEvaluations (List ( P.RuleName, Json.Encode.Value ))
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewAnswer ( rule, value ) ->
            ( { model | situation = Dict.insert rule value model.situation }
            , Effect.updateSituation ( rule, P.nodeValueEncoder value )
            )

        Evaluate ->
            ( model, Effect.evaluateAll (Dict.keys model.rules) )

        UpdateEvaluations evaluations ->
            ( List.foldl updateEvaluation model evaluations
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )


updateEvaluation : ( P.RuleName, Json.Encode.Value ) -> Model -> Model
updateEvaluation ( name, encodedValue ) model =
    case Json.Decode.decodeValue P.nodeValueDecoder encodedValue of
        Ok eval ->
            { model | evaluations = Dict.insert name eval model.evaluations }

        Err e ->
            { model | errorMsg = Just (Json.Decode.errorToString e) }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Effect.situationUpdated (\_ -> Evaluate)
        , Effect.evaluatedRules UpdateEvaluations
        ]



-- VIEW


view : Model -> Html Msg
view model =
    let
        rules =
            Dict.toList model.rules
    in
    div []
        [ h2 [] [ text "Questions" ]
        , div []
            (List.map (viewQuestion model) rules)
        , h2 [] [ text "Résultats" ]
        , div []
            (List.map (viewResult model) rules)
        ]


viewQuestion : Model -> ( P.RuleName, P.RawRule ) -> Html Msg
viewQuestion model ( name, rule ) =
    case ( rule.question, Dict.get name model.evaluations ) of
        ( Just question, Just value ) ->
            div []
                [ p [] [ text question ]
                , viewInput name value
                ]

        _ ->
            text ""


viewResult : Model -> ( P.RuleName, P.RawRule ) -> Html Msg
viewResult model ( name, rule ) =
    case ( rule.question, Dict.get name model.evaluations ) of
        ( Nothing, Just value ) ->
            let
                desc =
                    rule.title
                        |> Maybe.withDefault name
            in
            div []
                [ p [] [ text desc, text " : ", text (P.nodeValueToString value) ]
                ]

        _ ->
            text ""


viewInput : P.RuleName -> P.NodeValue -> Html Msg
viewInput name nodeValue =
    let
        newAnswer val =
            case String.toFloat val of
                Just value ->
                    let
                        _ =
                            Debug.log "NewAnswer" ( name, P.Num value )
                    in
                    NewAnswer ( name, P.Num value )

                Nothing ->
                    if String.isEmpty val then
                        NoOp

                    else
                        NewAnswer ( name, P.Str val )
    in
    case nodeValue of
        P.Str s ->
            input
                [ type_ "text"
                , value s
                , onInput newAnswer
                ]
                []

        P.Num n ->
            input
                [ type_ "number"
                , value (String.fromFloat n)
                , onInput newAnswer
                ]
                []

        P.Boolean b ->
            input
                [ type_ "checkbox"
                , checked b
                , onClick (NewAnswer ( name, P.Boolean (not b) ))
                ]
                []

        P.Empty ->
            text ""
