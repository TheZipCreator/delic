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
			writefln("% 4d: %s", iter++, state);
		Rule[] possibles; // all rules that currently could apply
		foreach(rule; rules) {
			if(state.indexOf(rule.pre) != -1)
				possibles ~= rule;
		}
		if(possibles.length == 0)
			break;
		Rule r = possibles[uniform(0, $)];
		// pick which thing to replace
		size_t[] indices;
		{
			long index = -1;
			while(true) {
				index = state.indexOf(r.pre, index+1);
				if(index == -1)
					break;
				indices ~= cast(size_t)index;
			}
		}
		size_t index = indices[uniform(0, $)], off = index+r.pre.length;
		// put to stdout
		if(r.post.startsWith("~")) {
			state = state[0..index]~state[off..$];
			writeln(r.post[1..$]);
			continue;
		}
		// read from stdin
		if(r.post == ":::") {
			state = state[0..index]~readln()[0..$-1]~state[off..$];
			continue;
		}
		state = state[0..index]~r.post~state[off..$];
	}
	return state;
}
