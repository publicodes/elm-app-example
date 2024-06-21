// @ts-ignore
import { Elm } from "./Main.elm";
import Engine, { PublicodesExpression } from "publicodes";
import rules from "../model.json";

type RuleName = string;

// Load the situation from local storage
const situation = JSON.parse(localStorage.getItem("situation") ?? "{}");

// Initialize the engine
const engine = new Engine(rules).setSituation(situation);

// Initialize the Elm app
const app = Elm.Main.init({
  flags: { rules, situation },
  node: document.getElementById("elm-app"),
});

// Evaluate all rules when requested by the Elm app and send the results back
//
// NOTE: you probably want to store if the rule is applicable or not, to know
// if the question should be displayed or not.
app.ports.evaluateAll.subscribe((rules: RuleName[]) => {
  const results = rules.map((rule) => [
    rule,
    engine.evaluate(rule)?.nodeValue ?? null,
  ]);
  app.ports.evaluatedRules.send(results);
});

// Update the situation when requested by the Elm app and send a signal back
// when the situation has been updated both in the engine and in local storage.
app.ports.updateSituation.subscribe(
  ([rule, value]: [RuleName, PublicodesExpression]) => {
    const newSituation = { ...engine.getSituation(), [rule]: value };
    engine.setSituation(newSituation);
    localStorage.setItem("situation", JSON.stringify(newSituation));
    app.ports.situationUpdated.send(null);
  },
);
