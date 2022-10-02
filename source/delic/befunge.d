/// Interprets Befunge-98
///
/// More info: https://git.catseye.tc/Funge-98/blob/master/doc/funge98.markdown
module delic.befunge;

import delic.interpreterexception, delic.termutils;
import std.stdio, std.random;

private enum Direction {
  left, right, up, down
}

/// Interprets a string of Befunge-98 code
void interpret(string code) {
  char[][] program;
  // turn string into 2d char array
  {
    import std.string;
    foreach(line; code.splitLines) {
      program ~= cast(char[])line;
    }
  }
  Direction dir = Direction.right;
  size_t x;
  size_t y;
  int[] stack;
  bool stringMode = false;
  // stack ops
  void push(int i) {
    stack ~= i;
  }
  int peek() {
    if(stack.length == 0)
      return 0;
    return stack[$-1];
  }
  int pop() {
    if(stack.length == 0)
      return 0;
    int i = stack[$-1];
    stack = stack[0..$-1];
    return i;
  }
  // other
  void move() {
    final switch(dir) {
      case Direction.left:  x--; break;
      case Direction.right: x++; break;
      case Direction.up:    y--; break;
      case Direction.down:  y++; break;
    }
    if(y < 0)
      y = program.length-1;
    else if(y >= program.length)
      y = 0;
    if(x < 0)
      x = program[y].length-1;
    else if(x >= program[y].length)
      x = 0;
  }
  while(true) {
    // interpret instruction
    if(stringMode) {
      if(program[y][x] == '"') {
        stringMode = false;
      } else {
        push(program[y][x]);
      }
    } else {
      switch(program[y][x]) {
        case '+':
          push(pop+pop);
          break;
        case '-':
          push(pop-pop);
          break;
        case '*':
          push(pop*pop);
          break;
        case '/':
          push(pop/pop);
          break;
        case '%':
          push(pop%pop);
          break;
        case '!':
          push(pop ? 0 : 1);
          break;
        case '`':
          push(pop > pop);
          break;
        case '>':
          dir = Direction.right;
          break;
        case '<':
          dir = Direction.left;
          break;
        case '^':
          dir = Direction.up;
          break;
        case 'v':
          dir = Direction.down;
          break;
        case '?':
          final switch(uniform(0, 3)) {
            case 0: dir = Direction.left;  break;
            case 1: dir = Direction.right; break;
            case 2: dir = Direction.up;    break;
            case 3: dir = Direction.down;  break;
          }
          break;
        case '_':
          dir = pop ? Direction.left : Direction.right;
          break;
        case '|':
          dir = pop ? Direction.up : Direction.down;
          break;
        case '"':
          stringMode = true;
          break;
        case ':':
          push(peek);
          break;
        case '\\': {
          int a = pop;
          int b = pop;
          push(b);
          push(a);
          break;
        }
        case '$':
          pop;
          break;
        case '.':
          write(pop);
          break;
        case ',':
          write(cast(char)pop);
          break;
        case '#':
          move;
          break;
        case 'g': {
          int i = pop;
          int j = pop;
          push(program[j][i]);
          break;
        }
        case 'p': {
          int i = pop;
          int j = pop;
          int v = pop;
          program[j][i] = cast(char)v;
          break;
        }
        case '&': {
          import std.conv;
          push(readln()[0..$-1].to!int);
          break;
        }
        case '~':
          push(getch);
          break;
        case '@':
          return;
        case '0': .. case '9':
          push(program[y][x]-'0');
          break;
        default:
          break;
      }
    }
    move;
  }
}