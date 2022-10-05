/// Interprets turimg code
///
/// More info: https://esolangs.org/wiki/Turimg
module delic.turimg;

import delic.common;
import std.stdio, std.array, std.conv;

// this code isn't great since I took it from the original repo which was written when I was new to D

private struct State {
  ubyte dir; //0 = none, 1 = left, 2 = right
  ubyte set; //0 = none, 1 = 0, 2 = 1, 3 = . 4 = ,
  string next0;
  string next1;
  this(byte dir, byte set, string next0, string next1) {
    this.dir = dir;
    this.set = set;
    this.next0 = next0;
    this.next1 = next1;
  }
}

/// Interprets turimg code
void interpret(string code, bool ascii) {
  State[string] states;
  bool[0x10000] tape;
  char[] asciibuf;
  int pos = 0;
  string state;
  code = code.replace("\r\n", "\n"); //windows :P
  string[] lines = code.split("\n");
  bool[] input;
  for(int i = 0; i < lines.length; i++) {
    if(lines[i].length == 0) 
      continue;
    if(lines[i][0] == ';') 
      continue;
    string[] tmp = lines[i].split("\t");
    if(tmp.length != 5 && tmp.length != 4) {
      throw new InterpreterException("Invalid line format");
    }
    string name = tmp[0];
    byte dir;
    switch(tmp[1]) {
      case "":
        dir = 0;
        break;
      case "<":
        dir = 1;
        break;
      case ">":
        dir = 2;
        break;
      default:
        throw new InterpreterException("Invalid direction");
    }
    byte set;
    switch(tmp[2]) {
      case "":
        set = 0;
        break;
      case "0":
        set = 1;
        break;
      case "1":
        set = 2;
        break;
      case ".":
        set = 3;
        break;
      case ",":
        set = 4;
        break;
      default:
        throw new InterpreterException("Invalid set");
    }
    string next0 = tmp[3];
    string next1;
    if(tmp.length == 4) next1 = tmp[3];
    else next1 = tmp[4];
    if(name in states) {
      throw new InterpreterException("State "~name~" already exists");
    } else {
      states[name] = State(dir, set, next0, next1);
    }
    if(state == "") state = name; //use the first state as the initial state
  }
  while(state != "halt") {
    if(state !in states)
      throw new InterpreterException("State "~state~" not found");
    State s = states[state];
    if(tape[pos]) state = s.next1;
    else state = s.next0;
    final switch(s.set) {
      case 0:
        break;
      case 1:
        tape[pos] = false;
        break;
      case 2:
        tape[pos] = true;
        break;
      case 3:
        if(ascii) {
          asciibuf ~= tape[pos];
          if(asciibuf.length == 8) {
            char c = to!char((asciibuf[0] << 7) | (asciibuf[1] << 6) | (asciibuf[2] << 5) | 
              (asciibuf[3] << 4) | (asciibuf[4] << 3) | (asciibuf[5] << 2) | (asciibuf[6] << 1) | asciibuf[7]);
            write(c);
            asciibuf = [];
          }
        } else write(tape[pos] ? "1" : "0");
        break;
      case 4:
        if(input.length == 0) {
          char c = getch;
          if(ascii) {
            for(int i = 7; i >= 0; i--) {
              input ~= ((c >> i) & 1) != 0;
            }
          } else {
            input ~= c == '1';
          }
        }
        tape[pos] = input[0];
        input = input[1..$];
        break;
    }
    final switch(s.dir) {
      case 0:
        break;
      case 1:
        pos--;
        if(pos < 0)
          throw new InterpreterException("Pointer out of bounds");
        break;
      case 2:
        pos++;
        if(pos >= tape.length)
          throw new InterpreterException("Pointer out of bounds");
        break;
    }
  }
}