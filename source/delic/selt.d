/// Interprets selt code
/// 
/// More info: https://esolangs.org/wiki/Selt
module delic.selt;

import std.typecons, std.string, std.stdio, std.conv;
import delic.common;

// this was also just taken from a different github repo, which is why there's some weird things here

private {
	class LabelException : InterpreterException {
		this(string msg) {
			super(msg);
		}
	}

	Tuple!(string,string)[] label(string code) {
		Tuple!(string,string)[] result;
		string[] lines = code.splitLines();
		for(int i = 0; i < lines.length; i++) {
			string[] l = lines[i].split(":");
			if(l.length > 2) {
				throw new LabelException(format("Too many colons on line %d", i+1));
			}
			if(l.length == 2) {
				if(l[0].length > 0 && l[0][0] == '#') result ~= tuple("", ""); // ignore comments
				else {
					// remove any spaces or tabs from the start of the label
					// (there's probably a better way to do this but this works; regex maybe?)
					int j;
					for(j = 0; j < l[0].length; j++) {
						if(l[0][j] != ' ' && l[0][j] != '\t') break;
					}
					result ~= tuple(l[0][j..$], l[1]);
				}
			} else if(l.length == 1) {
				result ~= tuple("", l[0]);
			} else {
				result ~= tuple("", "");
			}
		}
		return result;
	}


	interface Node {
		string toString();
		string name();
	}

	string nodeArrayToString(Node[] nodes) {
		string s = "";
		for (int i = 0; i < nodes.length; i++) {
			if(i > 0) s ~= " ";
			s ~= nodes[i].toString();
		}
		return s;
	}

	class Lexeme : Node {
		enum LexemeType {
			TERM,
			ADD, SUB, MUL, DIV, MOD, CON, // + - * / % ~
			AT, LINE, DELINE, INDEX, LENGTH, // @ & | . ?
			EQ, NE, LT, LE, GT, GE, AND, OR, NOT, // == != < <= > >= && || !
			ASSIGN, // =
			LPAREN, RPAREN, // ( )
			EOL, STOP // end of line, tell parser to stop
		}

		string value;
		LexemeType type;
		this(string value, LexemeType type) {
			this.value = value;
			this.type = type;
		}
		override string toString() {
			switch(type) {
				case Ltype.EOL:
					return "EOL";
				case Ltype.STOP:
					return "STOP";
				default:
					return value;
			}
		}
		override string name() {
			return value;
		}
	}
	alias Ltype = Lexeme.LexemeType;

	class Expression : Node {
		enum ExpressionType {
			BIN, UN
		}
		Node[] contents;
		ExpressionType type;
		this(Node[] contents, ExpressionType type) {
			this.contents = contents;
			this.type = type;
		}
		override string toString() {
			return format("EXPR_%s(%s)", type, nodeArrayToString(contents));
		}
		override string name() {
			return "EXPRESSION";
		}
	}
	alias Etype = Expression.ExpressionType;

	class Statement : Node {
		enum StatementType {
			PRINT, PRINTLN, GOTO, CALL, RETURN, ASSIGN, NOP
		}
		Node[] contents;
		StatementType type;
		this(Node[] contents, StatementType type) {
			this.contents = contents;
			this.type = type;
		}
		override string toString() {
			return format("STMT_%s(%s)", type, nodeArrayToString(contents));
		}
		override string name() {
			return "STATEMENT";
		}
	}
	alias Stype = Statement.StatementType;
	Lexeme[] lex(string code) {
		Lexeme[] result;
		string value;
		enum State {
			START, COMMENT
		}
		State state;
		void add() {
			if(value != "") {
				result ~= new Lexeme(value, Ltype.TERM);
				value = "";
			}
		}
		void op(string o, Ltype t) {
			add();
			result ~= new Lexeme(o, t);
		}
		for(int i = 0; i < code.length; i++) {
			char c = code[i];
			char next = i+1 < code.length ? code[i+1] : '\0';
			final switch(state) {
				case State.START:
					switch(c) {
						case ' ':
						case '\t':
							add();
							break;
						case '+':
							op("+", Ltype.ADD);
							break;
						case '-':
							op("-", Ltype.SUB);
							break;
						case '*':
							op("*", Ltype.MUL);
							break;
						case '/':
							op("/", Ltype.DIV);
							break;
						case '%':
							op("%", Ltype.MOD);
							break;
						case '~':
							op("~", Ltype.CON);
							break;
						case '@':
							op("@", Ltype.AT);
							break;
						case '&':
							if(next == '&') {
								op("&&", Ltype.AND);
								i++;
							} else {
								op("&", Ltype.LINE);
							}
							break;
						case '|':
							if(next == '|') {
								op("||", Ltype.OR);
								i++;
							} else {
								op("|", Ltype.DELINE);
							}
							break;
						case '=':
							if(next == '=') {
								op("==", Ltype.EQ);
								i++;
							} else {
								op("=", Ltype.ASSIGN);
							}
							break;
						case '!':
							if(next == '=') {
								op("!=", Ltype.NE);
								i++;
							} else {
								op("!", Ltype.NOT);
							}
							break;
						case '<':
							if(next == '=') {
								op("<=", Ltype.LE);
								i++;
							} else {
								op("<", Ltype.LT);
							}
							break;
						case '>':
							if(next == '=') {
								op(">=", Ltype.GE);
								i++;
							} else {
								op(">", Ltype.GT);
							}
							break;
						case '.':
							op(".", Ltype.INDEX);
							break;
						case '?':
							op("?", Ltype.LENGTH);
							break;
						case '(':
							op("(", Ltype.LPAREN);
							break;
						case ')':
							op(")", Ltype.RPAREN);
							break;
						case '#':
							state = State.COMMENT;
							break;
						case '`':
							op("", Ltype.TERM); // backtick represents the empty string
							break;
						case '\\':
							value ~= next;
							i++;
							break;
						default:
							value ~= c;
							break;
					}
					break;
				case State.COMMENT:
					break; // only individual lines are lexed so we don't need to find the end of the comment
			}
		}
		op("", Ltype.EOL);
		op("", Ltype.STOP);
		return result;
	}
	Node[] parse(Lexeme[] lexemes) {
		Node[] stack;
		Lexeme next() {
			Lexeme l = lexemes[0];
			lexemes = lexemes[1..$];
			return l;
		}
		Lexeme peek() {
			return lexemes[0];
		}
		bool isLexeme(Node n, Ltype t) {
			return cast(Lexeme)n && (cast(Lexeme)n).type == t;
		}
		bool isTerm(Node n, string s) {
			return cast(Lexeme)n && (cast(Lexeme)n).type == Ltype.TERM && (cast(Lexeme)n).value == s;
		}
		bool exprOrTerm(Node n) {
			if(cast(Expression)n) return true;
			else return isLexeme(n, Ltype.TERM);
		}
		bool binop(Node n) {
			if(Lexeme l = cast(Lexeme)n)
				switch(l.type) {
					case Ltype.ADD:
					case Ltype.SUB:
					case Ltype.MUL:
					case Ltype.DIV:
					case Ltype.MOD:
					case Ltype.CON:
					case Ltype.EQ:
					case Ltype.NE:
					case Ltype.LT:
					case Ltype.LE:
					case Ltype.GT:
					case Ltype.GE:
					case Ltype.AND:
					case Ltype.OR:
					case Ltype.INDEX:
						return true;
					default:
						return false;
				}
			return false;
		}
		bool unop(Node n) {
			if(Lexeme l = cast(Lexeme)n)
				switch(l.type) {
					case Ltype.AT:
					case Ltype.LINE:
					case Ltype.DELINE:
					case Ltype.NOT:
					case Ltype.LENGTH:
						return true;
					default:
						return false;
				}
			return false;
		}
		int precedence(Node n) {
			if(Lexeme l = cast(Lexeme)n)
				switch(l.type) {
					case Ltype.CON:
						return 1;
					case Ltype.ADD:
					case Ltype.SUB:
						return 2;
					case Ltype.MUL:
					case Ltype.DIV:
					case Ltype.MOD:
						return 3;
					case Ltype.EQ:
					case Ltype.NE:
					case Ltype.LT:
					case Ltype.LE:
					case Ltype.GT:
					case Ltype.GE:
						return 4;
					case Ltype.AND:
						return 5;
					case Ltype.OR:
						return 6;
					case Ltype.AT:
					case Ltype.LINE:
					case Ltype.DELINE:
					case Ltype.NOT:
					case Ltype.INDEX:
					case Ltype.LENGTH:
						return 7;
					default:
						return 0;
				}
			return 0;
		}
		while(true) {
			Lexeme nxt = next();
			if(isLexeme(nxt, Ltype.STOP)) return stack;
			stack ~= nxt;
			bool reduced = true;
			while(reduced) {
				reduced = false;
				for(int i = 0; i < stack.length; i++) {
					Node[] seg = stack[i..$];
					void reduce(Node n) {
						stack = stack[0..i];
						stack ~= n;
						reduced = true;
					}
					// ==== Expression ====
					// e/t binop e/t
					if(seg.length == 3) {
						if(exprOrTerm(seg[0]) && binop(seg[1]) && exprOrTerm(seg[2]) && precedence(seg[1]) >= precedence(peek())) {
							reduce(new Expression([seg[0], seg[1], seg[2]], Etype.BIN));
							break;
						}
					}
					// unop e/t
					if(seg.length == 2) {
						if(unop(seg[0]) && exprOrTerm(seg[1]) && precedence(seg[0]) >= precedence(peek())) {
							reduce(new Expression([seg[0], seg[1]], Etype.UN));
							break;
						}
					}
					// ( e/t )
					if(seg.length == 3) {
						if(isLexeme(seg[0], Ltype.LPAREN) && exprOrTerm(seg[1]) && isLexeme(seg[2], Ltype.RPAREN)) {
							reduce(seg[1]);
							break;
						}
					}
					// ==== Statement ====
					if(seg.length == 3) {
						// print e/t EOL
						if(isTerm(seg[0], "print") && exprOrTerm(seg[1]) && isLexeme(seg[2], Ltype.EOL)) {
							reduce(new Statement([seg[1]], Stype.PRINT));
							break;
						}
						// println e/t EOL
						if(isTerm(seg[0], "println") && exprOrTerm(seg[1]) && isLexeme(seg[2], Ltype.EOL)) {
							reduce(new Statement([seg[1]], Stype.PRINTLN));
							break;
						}
						// goto e/t EOL
						if(isTerm(seg[0], "goto") && exprOrTerm(seg[1]) && isLexeme(seg[2], Ltype.EOL)) {
							reduce(new Statement([seg[1]], Stype.GOTO));
							break;
						}
						// call e/t EOL
						if(isTerm(seg[0], "call") && exprOrTerm(seg[1]) && isLexeme(seg[2], Ltype.EOL)) {
							reduce(new Statement([seg[1]], Stype.CALL));
							break;
						}
					}
					if(seg.length == 4) {
						// e/t = e/t EOL
						if(exprOrTerm(seg[0]) && isLexeme(seg[1], Ltype.ASSIGN) && exprOrTerm(seg[2]) && isLexeme(seg[3], Ltype.EOL)) {
							reduce(new Statement([seg[0], seg[2]], Stype.ASSIGN));
							break;
						}
					}
					if(seg.length == 1) {
						// EOL
						if(isLexeme(seg[0], Ltype.EOL)) {
							reduce(new Statement([], Stype.NOP));
							break;
						}
					}
					if(seg.length == 2) {
						// return EOL
						if(isTerm(seg[0], "return") && isLexeme(seg[1], Ltype.EOL)) {
							reduce(new Statement([], Stype.RETURN));
							break;
						}
					}
				}
			}
		}
	}
	class SeltInterpreterException : InterpreterException {
		int line;
		this(int line, string msg) {
			super(line, msg);
			this.line = line;
		}
	}

	void interpret_(Tuple!(string, string)[] program) {
		int[] stack;
		loop:
		for(int i = 0; i < program.length; i++) {
			bool truthy(string s) {
				return s == "1";
			}
			int findLabel(string s) {
				for(int j = 0; j < program.length; j++) {
					if(program[j][0] == s) {
						return j;
					}
				}
				throw new SeltInterpreterException(i+1, format("Unknown label %s", s));
			}
			int num(string s) {
				try {
					return to!int(s);
				} catch(ConvException e) {
					throw new SeltInterpreterException(i+1, format("%s is not an integer", s));
				}
			}
			string valueOf(Node n) {
				if(Lexeme l = cast(Lexeme)n) {
					if(l.type == Ltype.TERM) {
						return l.value;
					} else {
						throw new SeltInterpreterException(i+1, format("Unexpected lexeme %s", l));
					}
				} else if(Expression e = cast(Expression)n) {
					final switch(e.type) {
						case Etype.BIN: {
							Lexeme op = cast(Lexeme)e.contents[1];
							string left = valueOf(e.contents[0]);
							string right = valueOf(e.contents[2]);
							switch(op.type) {
								default:
									return ""; // unreachable but compiler doesn't know that (or really can't)
								case Ltype.ADD:
									return to!string(num(left) + num(right));
								case Ltype.SUB:
									return to!string(num(left) - num(right));
								case Ltype.MUL:
									return to!string(num(left) * num(right));
								case Ltype.DIV:
									return to!string(num(left) / num(right));
								case Ltype.MOD:
									return to!string(num(left) % num(right));
								case Ltype.CON:
									return left~right;
								case Ltype.INDEX: {
									int idx = num(right);
									if(idx < 0 || idx >= left.length) {
										throw new SeltInterpreterException(i+1, format("Index %s out of bounds", idx));
									}
									return to!string(left[idx]);
								}
								case Ltype.EQ:
									return left == right ? "1" : "0";
								case Ltype.NE:
									return left != right ? "1" : "0";
								case Ltype.LT:
									return num(left) < num(right) ? "1" : "0";
								case Ltype.GT:
									return num(left) > num(right) ? "1" : "0";
								case Ltype.LE:
									return num(left) <= num(right) ? "1" : "0";
								case Ltype.GE:
									return num(left) >= num(right) ? "1" : "0";
								case Ltype.AND:
									return truthy(left) && truthy(right) ? "1" : "0";
								case Ltype.OR:
									return truthy(left) || truthy(right) ? "1" : "0";
							}
						}
						case Etype.UN: {
							Lexeme op = cast(Lexeme)e.contents[0];
							string arg = valueOf(e.contents[1]);
							switch(op.type) {
								default:
									return "";
								case Ltype.NOT:
									return truthy(arg) ? "0" : "1";
								case Ltype.AT:
									if(arg == "stdin") return readln()[0..$-1]; // remove newline
									return program[findLabel(arg)][1];
								case Ltype.LINE:
									return to!string(findLabel(arg)+1);
								case Ltype.DELINE: {
									int line = num(arg);
									if(line > 0 && line <= program.length) {
										return program[line-1][1];
									} else {
										throw new SeltInterpreterException(i+1, format("Line %d is out of bounds", line));
									}
								}
								case Ltype.LENGTH:
									return to!string(arg.length);
							}
						}
					}
				} else {
					throw new SeltInterpreterException(i+1, format("Unexpected node %s", n));
				}
			}
			string label = program[i][0];
			string code = program[i][1];
			Lexeme[] lexemes = lex(code);
			Node[] nodes = parse(lexemes);
			if(nodes.length > 1) {
				throw new SeltInterpreterException(i+1, format("Unexpected node %s", nodes[1]));
			} else {
				if(Statement s = cast(Statement)nodes[0]) {
					final switch(s.type) {
						case Stype.PRINT:
							write(valueOf(s.contents[0]));
							break;
						case Stype.PRINTLN:
							writeln(valueOf(s.contents[0]));
							break;
						case Stype.GOTO:
							i = findLabel(valueOf(s.contents[0]))-1;
							break;
						case Stype.CALL:
							stack ~= i;
							i = findLabel(valueOf(s.contents[0]))-1;
							break;
						case Stype.RETURN:
							if(stack.length > 0) {
								i = stack[$-1];
								stack = stack[0..$-1];
							} else {
								break loop;
							}
							break;
						case Stype.ASSIGN: {
							int l = findLabel(valueOf(s.contents[0]));
							string value = valueOf(s.contents[1]);
							program[l][1] = value;
							break;
						}
						case Stype.NOP:
							break;
					}
				} else {
					throw new SeltInterpreterException(i+1, format("Unexpected node %s", nodes[0]));
				}
			}
		}
	
	}
}

/// Interprets a string of Selt code
void interpret(string code) {
	auto labels = label(code);
	interpret_(labels);
}
