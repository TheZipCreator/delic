/// Interprets brainfuck code
///
/// More info: https://esolangs.org/wiki/Brainfuck
module delic.brainfuck;
import delic.common : InterpreterException, getch;
import std.stdio;

/// Interprets a string of brainfuck code
void interpret(string code, ref ubyte[] tape) {
  // remove non-bf characters
  {
    import std.array;
    auto ap = appender!string;
    foreach(char c; code) {
      import std.string;
      switch(c) {
        case '+': case '-': case '>': case '<': case '[': case ']': case '.': case ',':
          ap ~= c;
          break;
        default:
          break;
      }
    }
    code = ap[];
  }
  size_t pointer = 0;
  if(tape.length == 0)
    tape ~= 0;
  for(int i = 0; i < code.length; i++) {
    char c = code[i];
    switch(c) {
      case '+':
        tape[pointer]++;
        break;
      case '-':
        tape[pointer]--;
        break;
      case '<':
        if(--pointer < 0)
          throw new InterpreterException("Pointer out of bounds");
        break;
      case '>':
        if(++pointer >= tape.length)
          tape ~= 0;
        break;
      case '[':
        if(tape[pointer] == 0) {
          int brack = 1;
          while(brack > 0) {
            i++;
            if(code[i] == '[') brack++;
            else if(code[i] == ']') brack--;
          }
        }
        break;
      case ']':
        if(tape[pointer] != 0) {
          int brack = 1;
          while(brack > 0) {
            i--;
            if(code[i] == '[') brack--;
            else if(code[i] == ']') brack++;
          }
        }
        break;
      case '.':
        write(cast(char)tape[pointer]);
        break;
      case ',':
        tape[pointer] = cast(ubyte)getch;
        break;
      default:
        break;
    }
  }
}
