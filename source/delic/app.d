import std.stdio, std.getopt, std.file, std.traits, std.algorithm, std.conv, std.string;
import delic;

enum Language {
	none,
	befunge,
	brainfuck,
	deadfish,
	malbolge,
	selt,
	set,
	thue,
	turimg,
}

struct LanguageInfo {
	string name;
	string desc;
	string page;
}

immutable LanguageInfo[Language] languageInfo;

shared static this() {
	languageInfo = [
		Language.befunge: LanguageInfo(
			"Befunge",
			"A two-dimensional language with the design goal of being as difficult to compile as possible.\nThis specific implementation is for Befunge-98",
			"Befunge"
		),
		Language.brainfuck: LanguageInfo(
			"Brainfuck", 
			"One of the most famous esolangs. Extremely minimalist, containing only 6 commands.",
			"Brainfuck"
		),
		Language.deadfish: LanguageInfo(
			"Deadfish", 
			"A simple, non-turing-complete language that has many implementations due to its extreme simplicity.",
			"Deadfish"
		),
		Language.malbolge: LanguageInfo(
			"Malbolge", 
			"Another famous esolang. Designed to be as hard to program in as possible.",
			"Malbolge"
		),
		Language.set: LanguageInfo(
			"Set",
			"A language with only one command - set.",
			"Set"
		),			
		Language.selt: LanguageInfo(
			"Selt",
			"A self-modifying programming language with strings as the only datatype.",
			"Selt"
		),			
		Language.thue: LanguageInfo(
			"Thue",
			"A non-deterministic string rewriting language.",
			"Thue"
		),			
		Language.turimg: LanguageInfo(
			"Turimg",
			"A language meant to directly emulate a turing machine.",
			"Turimg"
		),			
	];  			

}

int main(string[] args) {
	Language lang;
	bool outputFinalState = false;
	bool asciiMode = false;
	bool assembleDouble = false;
	bool source = false;
	try {
		auto opt = getopt(args,
			"source|s", "Understand arguments as source code and not as files to read from (one argument per source).", &source,
			"language|l", "The language to interpret. One of: "~[EnumMembers!Language][1..$].map!(x => x.to!string).join(", ")~".", &lang,
			"outputFinalState", "(Thue) Output the final state after program execution finishes.", &outputFinalState,
			"asciiMode", "(Turimg) Enable ascii mode", &asciiMode,
		);
		if(opt.helpWanted || args.length == 1) {
			defaultGetoptPrinter("Options:", opt.options);
			writeln("Languages:");
			foreach(l; [EnumMembers!Language][1..$]) {
				auto info = languageInfo[l];
				writeln(l, " - ", info.name);
				writeln("\t", info.desc.replace("\n", "\n\t"));
				writeln("\thttps://esolangs.org/wiki/", info.page);
			}
			return 0;
		}
		if(lang == Language.none) {
			writeln("No language specified.");
			return 1;
		}
		void run(string code) {
			final switch(lang) {
				case Language.none:
					// unreachable
					break;
				case Language.brainfuck: {
					ubyte[] tape;
					delic.brainfuck.interpret(code, tape);
					break;
				}
				case Language.thue: {
					string s = delic.thue.interpret(code);
					if(outputFinalState)
						writeln("\n", s);
					break;
				}
				case Language.befunge: {
					delic.befunge.interpret(code);
					break;
				}
				case Language.set:
					delic.set.interpret(code);
					break;
				case Language.turimg:
					delic.turimg.interpret(code, asciiMode);
					break;
				case Language.selt:
					delic.selt.interpret(code);
					break;
				case Language.deadfish:
					delic.deadfish.interpret(code);
					break;
				case Language.malbolge:
					delic.malbolge.interpret(code);
			}
		}
		if(source) {
			foreach(string code; args[1..$]) {
				run(code);
			}
		} else {
			foreach(string file; args[1..$]) {
				string code = readText(file);
				run(code);
			}
		}
	} catch(GetOptException e) {
		writeln(e.msg);
		return 1;
	} catch(FileException e) {
		writeln(e.msg);
		return 1;
	} catch(InterpreterException e) {
		writeln(e.msg);
		return 1;
	}
	return 0;
}
