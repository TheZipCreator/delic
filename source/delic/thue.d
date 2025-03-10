/// Interprets Thue code
///
/// More info: https://esolangs.org/wiki/Thue
module delic.thue;
import std.stdio, std.string, std.random;

private struct Rule {
	string pre;
	string post;
}

/// Interprets a string of Thue code
/// Returns: the final state after execution ends
string interpret(string code, bool printIterations) {
	Rule[] rules;
	string[] lines = code.splitLines();
	string state;
	// find rules
	bool foundEnd = false;
	foreach(string line; lines) {
		if(line == "::=") {
			foundEnd = true;
			continue;
		}
		if(foundEnd) {
			state ~= line;
			continue;
		}
		long dec = line.indexOf("::=");
		if(dec != -1) {
			rules ~= Rule(line[0..dec], line[dec+3..$]);
		}
	}
	uint iter = 0; // current iteration
	while(true) {
		if(printIterations)
			writeln(iter++, ": ", state);
		Rule[] possibles; // all rules that currently could apply
		foreach(rule; rules) {
			if(state.indexOf(rule.pre) != -1)
				possibles ~= rule;
		}
		if(possibles.length == 0)
			break;
		Rule r = possibles[uniform(0, $)];
		// put to stdout
		if(r.post.startsWith("~")) {
			state = state.replace(r.pre, "");
			writeln(r.post[1..$]);
			continue;
		}
		// read from stdin
		if(r.post == ":::") {
			state = state.replace(r.pre, readln()[0..$-1]);
		}
		state = state.replace(r.pre, r.post);
	}
	return state;
}
