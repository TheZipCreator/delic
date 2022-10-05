import std.stdio, std.getopt, std.file;
import delic;

enum Language {
  none,
  brainfuck,
  thue,
  befunge,
  set,
  turimg,
  selt
}

int main(string[] args) {
  Language lang;
  bool outputFinalState = false;
  bool asciiMode = false;
  try {
    auto opt = getopt(args,
      "language|l", "The language to interpret", &lang,
      "outputFinalState", "(Thue) Output the final state after program execution finishes", &outputFinalState,
      "asciiMode", "(Turimg) Enable ascii mode", &asciiMode
    );
    if(opt.helpWanted) {
      defaultGetoptPrinter("Options:", opt.options);
      return 0;
    }
    foreach(string file; args[1..$]) {
      string code = readText(file);
      final switch(lang) {
        case Language.none:
          writeln("Please specify a language");
          return 2;
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
      }
    }
  } catch(GetOptException e) {
    writeln(e.msg);
    return 1;
  } catch(FileException e) {
    writeln(e.msg);
    return 4;
  } catch(InterpreterException e) {
    writeln(e.msg);
    return 3;
  }
  return 0;
}