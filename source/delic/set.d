/// Interpreter for the Set language
///
/// More info: https://esolangs.org/wiki/Set
module delic.set;

import std.string;
import std.stdio;
import std.uni : toLower;
import delic.common : InterpreterException, getch;

/// Interprets a string of set code
void interpret(string code) {
  string[][] program;
  foreach(line; code.splitLines) {
    string[] tokens;
    size_t start = 0;
    bool comment = false;
    outer:
    foreach(i, c; line) {
      switch(c) {
        case ' ':
          if(start-i > 0)
            tokens ~= line[start..i];
          start = i+1;
          break;
        case '>':
          if(start-i > 0)
            tokens ~= line[start..i];
          comment = true;
          break outer;
        default:
          break;
      }
    }
    if(!comment && start != line.length)
      tokens ~= line[start..$];
    program ~= tokens;
  }
  long[52] vars;
  // initialize uppercase vars
  for(int i = 'A'; i <= 'Z'; i++) {
    vars[i-'A'] = i;
  }
  long pos;
  long get(string s) {
    if(s.isNumeric) {
      import std.conv;
      return s.to!long;
    } else if(s.startsWith("(") && s.endsWith(")")) {
      size_t idx = s.indexOf("+");
      if(idx != -1)
        return get(s[1..idx])+get(s[idx+1..$-1]);
      idx = s.indexOf("-");
      if(idx != -1)
        return get (s[1..idx])-get(s[idx+1..$-1]);
    }
    if(s.length != 1)
      throw new InterpreterException("Invalid Rvalue "~s~".");
    char c = s[0];
    switch(c) {
      case '?':
        return pos+1; // lines are 1-indexed
      case '!':
        return cast(long)getch;
      default:
        if(c < '[')
          return vars[c-'A'];
        else
          return vars[(c-'a')+27];
    }
  }
  void set(string s, long value) {
    if(s.length != 1)
      throw new InterpreterException("Invalid Lvalue "~s~".");
    char c = s[0];
    switch(c) {
      case '?':
        pos = value-2; // lines are 1-indexed, and another -1 since it gets incremented automatically at the end
        break;
      case '!':
        write(cast(char)value);
        break;
      default:
        if(c < '[')
          vars[c-'A'] = value;
        else
          vars[(c-'a')+27] = value;
    }
  }
  while(pos < program.length) {
    string[] tokens = program[pos];
    if(tokens.length == 0) {
      pos++;
      continue;
    }
    if(tokens[0].toLower == "set") {
      if(tokens.length != 3)
        throw new InterpreterException("Invalid amount of arguments for set.");
      set(tokens[1], get(tokens[2]));
    } else if(tokens[0].startsWith("[") && tokens[0].endsWith("]")) {
      if(tokens.length != 4)
        throw new InterpreterException("Invalid amount of arguments for conditional set.");
      if(tokens[1] != "set")
        throw new InterpreterException("Unexpected "~tokens[1]);
      string s = tokens[0];
      size_t idx = s.indexOf("=");
      if(idx != -1) {
        if(get(s[1..idx]) == get(s[idx+1..$-1]))
          set(tokens[2], get(tokens[3]));
      } else {
        idx = s.indexOf("/");
        if(idx != -1) {
          if(get(s[1..idx]) != get(s[idx+1..$-1]))
            set(tokens[2], get(tokens[3]));
        } else {
          throw new InterpreterException("Invalid comparison");
        }
      }
    }
    pos++;
    if(pos < 0)
      pos = 0;
  }
}