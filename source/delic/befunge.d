/// Interprets Befunge-98
///
/// More info: https://git.catseye.tc/Funge-98/blob/master/doc/funge98.markdown
module delic.befunge;

import delic.common : InterpreterException, getch;
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
		size_t largest = 0;
		foreach(i, line; code.splitLines) {
			program ~= cast(char[])line;
			// make sure it's an actual box
			if(line.length > largest) {
				largest = line.length;
			}
			while(program[i].length < largest)
				program[i] ~= ' ';
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
	// moving
	void wrap() {
		if(y < 0)
			y = program.length-1;
		else if(y >= program.length)
			y = 0;
		if(x < 0)
			x = program[y].length-1;
		else if(x >= program[y].length)
			x = 0;
	}
	void move() {
		final switch(dir) {
			case Direction.left:	x--; break;
			case Direction.right: x++; break;
			case Direction.up:		y--; break;
			case Direction.down:	y++; break;
		}
		wrap;
	}
	void unmove() {
		final switch(dir) {
			case Direction.left:	x++; break;
			case Direction.right: x--; break;
			case Direction.up:		y++; break;
			case Direction.down:	y--; break;
		}
		wrap;
	}
	char curr() {
		return program[y][x];
	}
	while(true) {
		// interpret instruction
		if(stringMode) {
			if(curr == '"') {
				stringMode = false;
			} else if(curr == ' ') {
				// SGML-Style string
				while(curr == ' ') {
					move;
				}
				unmove;
				push(' ');
			} else {
				push(curr);
			}
		} else {
			string op(string op) {
				import std.string;
				return q{
					int a = pop;
					int b = pop;
					push(b[op]a);
				}.replace("[op]", op);
			}
			switch(curr) {
				case '+':
					mixin(op("+"));
					break;
				case '-':
					mixin(op("-"));
					break;
				case '*':
					mixin(op("*"));
					break;
				case '/':
					mixin(op("/"));
					break;
				case '%':
					mixin(op("%"));
					break;
				case '!':
					push(pop ? 0 : 1);
					break;
				case '`':
					mixin(op(">"));
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
						case 0: dir = Direction.left;	break;
						case 1: dir = Direction.right; break;
						case 2: dir = Direction.up;		break;
						case 3: dir = Direction.down;	break;
					}
					break;
				case '_':
					dir = pop == 0 ? Direction.right : Direction.left;
					break;
				case '|':
					dir = pop == 0 ? Direction.down : Direction.up;
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
					push(a);
					push(b);
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
					push(curr-'0');
					break;
				case 'a': .. case 'f':
					push((curr-'a')+10);
					break;
				case '\'':
					move;
					push(curr);
					break;
				case 's':
					move;
					program[y][x] = cast(char)pop;
					break;
				case 'n':
					stack = [];
					break;
				case ';':
					do move; while(curr != ';');
					break;
				case 'r':
					final switch(dir) {
						case Direction.left:	dir = Direction.right; break;
						case Direction.right: dir = Direction.left;	break;
						case Direction.up:		dir = Direction.down;	break;
						case Direction.down:	dir = Direction.up;		break;
					}
					break;
				case 'j': {
					int count = pop;
					for(int i = 0; i < count; i++)
						move;
					break;
				}
				case 'q': {
					import core.stdc.stdlib : exit;
					exit(pop);
				}
				case 'z':
					break;
				// TODO: m { u } i o y = t x
				default:
					break;
			}
		}
		move;
	}
}
