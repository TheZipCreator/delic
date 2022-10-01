/// Interprets Thue code
///
/// More info: https://esolangs.org/wiki/Thue
module delic.thue;
import std.stdio, std.string, std.random;

private struct Rule {
  string pre;
  string post;
}

string interpret(string code) {
  Rule[] rules;
  string[] lines = code.splitLines();
  string state;
  // find rules
  foreach(string line; lines) {
    if(line == "::=")
      continue;
    long dec = line.indexOf("::=");
    if(dec != -1) {
      rules ~= Rule(line[0..dec], line[dec+3..$]);
    } else if(line != "") {
      state = line;
    }
  }
  while(true) {
    Rule[] possibles; // all rules that currently could apply
    foreach(rule; rules) {
      if(state.indexOf(rule.pre) != -1)
        possibles ~= rule;
    }
    if(possibles.length == 0)
      break;
    Rule r = possibles[uniform(0, $)];
    if(r.post.startsWith("~")) {
      state = state.replace(r.pre, "");
      writeln(r.post[1..$]);
      continue;
    }
    if(r.post == ":::") {
      state = state.replace(r.pre, readln()[0..$-1]);
    }
    state = state.replace(r.pre, r.post);
  }
  return state;
}