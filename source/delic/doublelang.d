/// Interprets double (named doublelang since double is a keyword in D)
/// 
/// More info: https://esolangs.org/wiki/Double
/// 
/// (also you probably want to check the source code of the python implementation since this page doesn't say much)
module delic.doublelang;

import delic.common;

import std.stdio, std.string, std.conv, std.uni, std.random;

/// Interprets double code
void interpret(string code, bool assemble) {
  // todo: write assembler
  enum size_t MEMORY_SIZE = 256;
  int[MEMORY_SIZE][MEMORY_SIZE] memory;
  size_t x = 0;
  size_t y = 0;
  int acc;
  int[] stack;
  int get(size_t x, size_t y) {
    if(x < 0 || x >= MEMORY_SIZE || y < 0 || y >= MEMORY_SIZE)
      throw new InterpreterException("Index out of bounds ("~x.to!string~", "~y.to!string~")");
    return memory[x][y];
  }
  void set(size_t x, size_t y, long value) {
    if(x < 0 || x >= MEMORY_SIZE || y < 0 || y >= MEMORY_SIZE)
      throw new InterpreterException("Index out of bounds ("~x.to!string~", "~y.to!string~")");
    memory[x][y] = cast(int)value;
  }
  void push(int i) {
    stack ~= i;
  }
  int pop() {
    if(stack.length == 0)
      throw new InterpreterException("Stack Underflow");
    int i = stack[$-1];
    stack = stack[0..$-1];
    return i;
  }
  string cond(string res) {
    return q{
      {
        int c = nexti;
        int loc = nexti;
        if(c != get(x, y)) {
          [res]
        }
        break;
      }
    }.replace("[res]", res);
  }
  string[] instructions = code.splitLines.join("").toUpper.split(" ");
  for(int i = 0; i < instructions.length; i++) {
    string next() {
      if(i >= instructions.length)
        throw new InterpreterException("Unexpected EOF");
      return instructions[++i];
    }
    int nexti() {
      string s = next;
      if(s.isNumeric)
        return s.to!int;
      return get(x, y);
    }
    string instr = instructions[i];
    switch(instr) {
      case "PV":
        write(get(x, y));
        break;
      case "PC":
        write(cast(char)get(x, y));
        break;
      case "SX":
        x = next.to!size_t;
        break;
      case "SY":
        y = next.to!size_t;
        break;
      case "IX":
        x++;
        break;
      case "IY":
        y++;
        break;
      case "DX":
        x--;
        break;
      case "DY":
        y--;
        break;
      case "SV":
        set(x, y, next.to!int);
        break;
      case "IV":
        set(x, y, get(x, y)+1);
        break;
      case "DV":
        set(x, y, get(x, y)-1);
        break;
      case "RS":
        i = -1;
        break;
      case "CR":
        mixin(cond("i = -1;"));
      case "GC":
        set(x, y, cast(int)getch);
        break;
      case "GV":
        set(x, y, readln()[0..$-1].to!int);
        break;
      case "XV":
        set(x, y, x);
        break;
      case "YV":
        set(x, y, y);
        break;
      case "JM":
        i = nexti-1;
        break;
      case "CJ":
        mixin(cond("i = loc-1;"));
      case "JF":
        i += nexti;
        break;
      case "JB":
        i -= nexti;
        break;
      case "CF":
        mixin(cond("i += nexti;"));
      case "CB":
        mixin(cond("i -= nexti;"));
      // TODO: GS
      case "JR":
        push(i);
        i = nexti-1;
        break;
      case "RR":
        i = pop;
        break;
      case "RC":
        mixin(cond(q{
          push(i);
          i = nexti-1;
        }));
      case "BC":
        mixin(cond("i = pop;"));
      case "RN":
        set(x, y, uniform(0, 255));
        break;
      // TODO: US
      case "DB": {
        size_t l = x;
        int s;
        while(s != 255) {
          l = (l+1)%MEMORY_SIZE;
          s = nexti;
          set(l, y, s);
        }
        break;
      }
      case "PS": {
        size_t l = x+1;
        int s;
        while(s != 255) {
          s = get(l, y);
          write(cast(char)s);
          l = (l+1)%MEMORY_SIZE;
        }
        break;
      }
      case "+C":
        acc += get(x, y);
        break;
      case "-C":
        acc -= get(x, y);
        break;
      case "IC":
        acc++;
        break;
      case "DC":
        acc--;
        break;
      case "SA":
        acc = nexti;
        break;
      case "AV":
        set(x, y, acc);
        break;
      case "PH":
        push(get(x, y));
        break;
      case "PL":
        set(x, y, pop);
        break;
      default:
        throw new InterpreterException("Invalid instruction "~instr);
    }
  }
}