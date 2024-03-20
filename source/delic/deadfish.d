/// Interprets deadfish code
module delic.deadfish;

import std.stdio;

import delic.common;

void interpret(string code) {
	// deadfish is dead (hah) simple
	// not much comment is needed on this code, I don't think
	int acc;
	foreach(dchar c; code) {
		switch(c) {
			case 'i':
				acc++;
				break;
			case 'd':
				acc--;
				break;
			case 's':
				acc *= acc;
				break;
			case 'o':
				writeln(acc);
				break;
			case 'h':
				return;
			default:
				break;
		}
		if(acc == -1 || acc == 256)
			acc = 0;
	}
}
