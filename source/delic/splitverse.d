module delic.splitverse;

import pegged.grammar;

import delic.common;

import std.stdio, std.typecons, std.format, std.conv, std.algorithm, std.array, std.range;

private {
	mixin(grammar(`
	Splitverse:
		Program < Statement* endOfInput
		Statement < DeclStmt / AssignStmt / OpAssignStmt / WaitStmt / BlockStmt / IfStmt / ReturnStmt / DieStmt / ExprStmt

		DeclStmt < ("global" / "local" / "split") Identifier "=" Expr ";"
		AssignStmt < Identifier "=" Expr ";"
		OpAssignStmt < Identifier ("+=" / "-=" / "*=" / "/=") Expr ";"
		WaitStmt < "wait" "(" Expr ")" ";"
		ExprStmt < Expr ";"
		BlockStmt < "{" Statement* "}"
		IfStmt < "if" "(" Expr ")" Statement ("else" Statement)?
		ReturnStmt < "return" Expr? ";"
		DieStmt < "die" ";"
		
		Expr    < Prec3 (And / Or)*
		And     < "&&" Prec3
		Or      < "||" Prec3
		Prec3   < Prec2 (Equ / Neq / Gt / Gte / Lt / Lte)*
		Equ     < "==" Prec2
		Neq     < "!=" Prec2
		Gt      < ">" Prec2
		Gte     < ">=" Prec2
		Lt      < "<" Prec2
		Lte     < "<=" Prec2
		Prec2   < Prec1 (Add / Sub)*
		Add     < "+" Prec1
		Sub     < "-" Prec1
		Prec1   < Primary (Mul / Div)*
		Mul     < "*" Primary
		Div     < "/" Primary
		
		Primary < Parens / Number / Neg / Pos / Not / Call / BuiltinCall / Index / String / Bool / Identifier / Array / Lambda
		Parens  < "(" Expr ")"
		Neg     < "-" Expr
		Pos     < "+" Expr
		Not     < "!" Expr
		Call    < Expr "(" ArgList(Expr) ")"
		BuiltinCall < "$" Identifier "(" ArgList(Expr) ")"
		Index < Expr "[" Expr "]"

		Array   < "[" ArgList(Expr) "]"
		Lambda  < "{" ((ArgList(Identifier) "->") / ^eps) Statement* "}"
		Bool <- "true" / "false"
		Identifier <~ [a-zA-Z0-9_]+
		Number <~ "-"? ([0-9]+) / ([0-9]* '.' [0-9]+)
		String <~ doublequote (!doublequote .)* doublequote
		
		ArgList(T) < (T (',' T)*) / eps

		Spacing <- ([ \t\r\n] / LineComment / BlockComment)*
		LineComment <- "//" (!endOfLine .)* endOfLine
		BlockComment <- "/*" (!"*/" .)* "*/"
	`));
}

/// Type of a Splitverse value
enum ValueType {
	NULL,
	BOOL,
	NUMBER,
	STRING,
	ARRAY,
	FUNCTION
}

/// A closure
struct Closure {
	size_t index; // function index
	string[] arguments; // argument names
	Variable[string] vars; // variables
}

/// A Splitverse value
struct Value {
	ValueType type;
	union {
		double asNumber;
		bool asBool;
		string asString;
		Value[] asArray;
		Closure asClosure;
	}
	enum NULL = Value(ValueType.NULL);
	this(double number) {
		type = ValueType.NUMBER;
		asNumber = number;
	}
	this(string str) {
		type = ValueType.STRING;
		asString = str;
	}
	this(bool b) {
		type = ValueType.BOOL;
		asBool = b;
	}
	this(Value[] arr) {
		type = ValueType.ARRAY;
		asArray = arr;
	}
	this(Closure c) {
		type = ValueType.FUNCTION;
		asClosure = c;
	}
	this(ValueType vt) {
		type = vt;
	}
	Value opUnary(string op)() {
		static if(op == "+" || op == "-") {
			if(type != ValueType.NUMBER)
				throw new InterpreterException(format("%s can not be performed on value of types %s.", op, type));
			mixin(`return Value(`~op~`asNumber);`);
		}
		else static assert(false, "Can't do operation "~op~" on values.");
	}
	Value opBinary(string op)(Value rhs) {
		static if(op == "+" || op == "-" || op == "*" || op == "/") {
			if(type != ValueType.NUMBER && rhs.type != ValueType.NUMBER)
				throw new InterpreterException(format("%s can not be performed on values of types %s and %s.", op, type, rhs.type));
			mixin(`return Value(asNumber`~op~`rhs.asNumber);`);
		}
		else static assert(false, "Can't do operation "~op~" on values.");
	}
	bool opEquals(Value rhs) {
		if(type != rhs.type)
			return false;
		final switch(type) {
			case ValueType.NULL:
				return true;
			case ValueType.BOOL:
				return asBool == rhs.asBool;
			case ValueType.NUMBER:
				return asNumber == rhs.asNumber;
			case ValueType.STRING:
				return asString == rhs.asString;
			case ValueType.ARRAY: {
				if(asArray.length == rhs.asArray.length)
					return false;
				foreach(i, elem; rhs.asArray)
					if(asArray[i] != rhs.asArray[i])
						return false;
				return true;
			}
			case ValueType.FUNCTION:
				return asClosure == rhs.asClosure;
		}
	}
	int opCmp(Value rhs) {
		noreturn doThrow() {
			throw new InterpreterException(format("Can not compare values of types %s and %s.", type, rhs.type));
		}
		if(type != rhs.type)
			doThrow();
		switch(type) {
			case ValueType.NUMBER:
				return asNumber < rhs.asNumber ? -1 : 1;
			case ValueType.STRING:
				return asString < rhs.asString ? -1 : 1;
			default:
				doThrow();
		}
	}

	bool opCast(T : bool)() {
		final switch(type) {
			case ValueType.NULL: return false;
			case ValueType.BOOL: return asBool;
			case ValueType.NUMBER: return true;
			case ValueType.STRING: return true;
			case ValueType.ARRAY: return true;
			case ValueType.FUNCTION: return true;
		}
	}

	Value clone() {
		final switch(type) {
			case ValueType.NULL:
			case ValueType.BOOL:
			case ValueType.NUMBER:
			case ValueType.STRING:
				return this;
			case ValueType.ARRAY:
				return Value(asArray.map!(x => x.clone()).array);
			case ValueType.FUNCTION:
				// TODO: figure out how variables should be cloned
				return Value(Closure(asClosure.index, asClosure.arguments.dup, asClosure.vars.dup));
		}
	}

	Value opIndex(Value v) {
		final switch(type) {
			case ValueType.NULL:
			case ValueType.BOOL:
			case ValueType.NUMBER:
			case ValueType.STRING:
			case ValueType.FUNCTION:
				throw new InterpreterException("Can't index value of type '"~type.to!string~"'.");
			case ValueType.ARRAY: {
				if(v.type != ValueType.NUMBER)
					throw new InterpreterException("Array indices must be numbers.");
				long index = cast(long)v.asNumber;
				if(index < 0 || index >= asArray.length)
					throw new InterpreterException("Index "~index.to!string~" is out of bounds.");
				return asArray[index];
			}
		}
	}

	string toString() {
		final switch(type) {
			case ValueType.NULL:
				return "null";
			case ValueType.BOOL:
				return asBool ? "true" : "false";
			case ValueType.NUMBER:
				return format("%g", asNumber);
			case ValueType.STRING:
				return asString;
			case ValueType.ARRAY: {
				auto ap = appender!string;
				ap ~= "[";
				foreach(i, x; asArray) {
					if(i != 0)
						ap ~= ", ";
					ap ~= x.toString();
				}
				ap ~= "]";
				return ap[];
			}
			case ValueType.FUNCTION:
				return format("<function @ %08x>", asClosure.index);
		}
	}
}

/// An instruction that can be run
interface Instr {
	/// Executes an instruction on a verse
	void run(Verse verse);
}

/// Instruction that kills the Verse
class DieInstr : Instr {
	this() {}
	void run(Verse verse) {
		verse.inter.kill(verse.id);
	}
	override string toString() => "Die";
}

/// Instruction that pushes a value to a Verse's top frame
class PushInstr : Instr {
	/// The value to push
	Value value;

	this(Value value) {
		this.value = value;
	}
	void run(Verse verse) {
		verse.frame.stack ~= value;
	}
	override string toString() => "Push "~value.toString();
}

/// Calls a builtin
class BuiltinInstr : Instr {
	/// The builtin to call
	string builtin;
	/// The amount of arguments to call with;
	size_t args;

	this(string builtin, size_t args) {
		this.builtin = builtin;
		this.args = args;
	}

	void run(Verse verse) {
		if(builtin !in verse.inter.builtins)
			throw new InterpreterException("No builtin $"~builtin~".");
		verse.frame.push(verse.inter.builtins[builtin](verse, verse.frame.popN(args)));
	}
	override string toString() => format("Builtin %s %d", builtin, args);
}
/// Does an operation between the top two values
class OpInstr(string op) : Instr {
	this() {}

	void run(Verse verse) {
		auto b = verse.frame.pop();
		auto a = verse.frame.pop();
		mixin(`auto res = a`~op~`b;`);
		static if(is(typeof(res) == Value))
			verse.frame.push(res);
		else
			verse.frame.push(Value(res));
	}
	override string toString() => "Op "~op;
}
/// Does an operation on the top value
class UnaryOpInstr(string op) : Instr {
	this() {}

	void run(Verse verse) {
		mixin(`auto res = `~op~`verse.frame.pop();`);
		static if(is(typeof(res) == Value))
			verse.frame.push(res);
		else
			verse.frame.push(Value(res));
	}
	override string toString() => "UnaryOp "~op;
}

/// Pops the top of the stack
class PopInstr : Instr {
	this() {}

	void run(Verse verse) {
		verse.frame.pop();
	}
	override string toString() => "Pop";
}

/// Declares a var
class DeclareVarInstr : Instr {
	bool global;
	string name;

	this(bool global, string name) {
		this.global = global;
		this.name = name;
	}
	
	void run(Verse verse) {
		verse.frame.declareVar(global, name, verse.frame.pop());
	}

	override string toString() => "DeclareVar "~(global ? "global " : "local ")~name;
}

/// Pushes a var
class PushVarInstr : Instr {
	string name;

	this(string name) {
		this.name = name;
	}

	void run(Verse verse) {
		verse.frame.push(verse.frame.resolveVar(name));
	}

	override string toString() => "PushVar "~name;
}

/// Sets a var
class SetVarInstr : Instr {
	string name;

	this(string name) {
		this.name = name;
	}

	void run(Verse verse) {
		verse.frame.setVar(name, verse.frame.pop());
	}

	override string toString() => "SetVar "~name;
}

/// Enters a scope
class EnterScopeInstr : Instr {
	this() {}

	void run(Verse verse) {
		verse.frame.enterScope();
	}

	override string toString() => "EnterScope";
}

/// Exits a scope
class ExitScopeInstr : Instr {
	this() {}

	void run(Verse verse) {
		verse.frame.exitScope();
	}

	override string toString() => "ExitScope";
}
/// Conditionally jumps by an offset
class ConditionalJumpInstr : Instr {
	long offset;
	this(long offset) {
		this.offset = offset;
	}
	void run(Verse verse) {
		if(verse.frame.pop())
			verse.frame.pos += offset-1;
	}

	override string toString() => "ConditionalJump "~offset.to!string;
}
/// Unconditionally jumps by an offset
class JumpInstr : Instr {
	long offset;
	this(long offset) {
		this.offset = offset;
	}
	void run(Verse verse) {
		verse.frame.pos += offset-1;
	}

	override string toString() => "Jump "~offset.to!string;
}
/// No operation
class NopInstr : Instr {
	this() {}
	void run(Verse verse) {}
	override string toString() => "Nop";
}
/// Wraps the current context around a closure
class WrapClosureInstr : Instr {
	this() {}
	void run(Verse verse) {
		auto val = verse.frame.peek();
		if(val == null || val.type != ValueType.FUNCTION)
			throw new InterpreterException("Attempted to wrap a non-closure value.");
		auto closure = &val.asClosure;
		closure.vars = new Variable[string];
		foreach(key, value; verse.frame.vars) {
			closure.vars[key] = value.var;
		}
	}

	override string toString() => "WrapClosure";
}
/// Calls a function
class CallInstr : Instr {
	size_t args;
	this(size_t args) {
		this.args = args;
	}
	void run(Verse verse) {
		auto vargs = verse.frame.popN(args);
		auto val = verse.frame.pop();
		if(val.type != ValueType.FUNCTION)
			throw new InterpreterException("Attempted to call value of type '"~val.type.to!string~"'.");
		auto fn = val.asClosure;
		auto frame = new Frame(fn.index, 0, verse.frame);
		// set arguments
		foreach(i, arg; fn.arguments) {
			frame.vars[arg] = VarScope(-1, new Variable(true, i >= vargs.length ? Value.NULL : vargs[i]));
		}
		// set vars over which we have a closure
		foreach(key, value; fn.vars) {
			frame.vars[key] = VarScope(-1, value);
		}
		verse.frame = frame;
	}

	override string toString() => "Call "~args.to!string;
}
/// Returns from a function
class ReturnInstr : Instr {
	this() {}
	void run(Verse verse) {
		// if there is nothing to return from, just die
		if(verse.frame.last is null) {
			verse.inter.kill(verse.id);
			return;
		}
		auto ret = verse.frame.pop();
		verse.frame = verse.frame.last;
		verse.frame.push(ret);
	}
	
	override string toString() => "Return";
}
/// Creates an array from items on the stack
class ArrayInstr : Instr {
	size_t args;
	this(size_t args) {
		this.args = args;
	}
	void run(Verse verse) {
		verse.frame.push(Value(verse.frame.popN(args)));
	}
	override string toString() => "Array "~args.to!string;
}
/// Splits the verse into multiple
class SplitVarInstr : Instr {
	string name;

	this(string name) {
		this.name = name;
	}

	void run(Verse verse) {
		auto val = verse.frame.pop();
		if(val.type != ValueType.ARRAY)
			throw new InterpreterException("Attempted to split on a non-array value.");
		auto arr = val.asArray;
		// split into 0 threads, which would just be dying
		if(arr.length == 0) {
			verse.inter.kill(verse.id);
			return;
		}
		// split
		for(size_t i = 1; i < arr.length; i++) {
			Verse child = verse.clone();
			child.frame.declareVar(false, name, arr[i]);
			verse.inter.spawn(child);
		}
		verse.frame.declareVar(false, name, arr[0]);
	}

	override string toString() => "SplitVar "~name;
}
class OpSetVarInstr(string op) : Instr {
	string name;

	this(string name) {
		this.name = name;
	}

	void run(Verse verse) {
		auto b = verse.frame.pop();
		auto a = verse.frame.resolveVar(name);
		mixin("auto res = a"~op~"b;");
		verse.frame.setVar(name, res);
	}

	override string toString() => "OpSetVar "~op~" "~name;
}
/// Indexes a value
class IndexInstr : Instr {
	this() {}

	void run(Verse verse) {
		auto b = verse.frame.pop();
		auto a = verse.frame.pop();
		verse.frame.push(a[b]);
	}
	override string toString() => "Index";
}

/// An instruction and a file position
struct InstrPos {
	Instr instr;
	FilePos pos;
	string toString() => format("%s\t%s", pos, instr);
}

/// Compiles Splitverse code
private class Compiler {
	/// Filename
	string filename;
	/// Source code
	string code;
	/// Function indices
	InstrPos[][] funcs;

	this(string filename, string code) {
		this.filename = filename;
		this.code = code;
	}
	
	// temporary marker that refers to function indices
	class PushFunctionIndexInstr : Instr {
		size_t idx;
		string[] vars;
		this(size_t idx, string[] vars) {
			this.idx = idx;
			this.vars = vars;
		}
		void run(Verse verse) {}
	}
	
	InstrPos[] compile() {
		ParseTree pt = Splitverse(code);
		if(!pt.successful) {
			throw new InterpreterException(filepos(pt.failEnd), pt.failMsg);
		}
		funcs ~= new InstrPos[0];
		eval(0, pt[0]);
		if(funcs[0].length == 0 || cast(DieInstr)funcs[0][$-1].instr is null)
			funcs[0] ~= InstrPos(new DieInstr(), filepos(pt[0].end-1));

		// assemble instructions together
		size_t[] idxToPos;
		InstrPos[] ret;
		foreach(size_t i, InstrPos[] func; funcs) {
			idxToPos ~= ret.length;
			ret ~= func;
		}
		foreach(size_t i, ref InstrPos ip; ret) {
			if(auto pfii = cast(PushFunctionIndexInstr)ip.instr)
				ip.instr = new PushInstr(Value(Closure(idxToPos[pfii.idx], pfii.vars)));
		}
		
		debug {
			foreach(i, ip; ret)
				writefln("%0x\t%s", i, ip);
			writeln("---");
		}
		return ret;
	}

	private void eval(size_t fnidx, ParseTree pt) {
		switch(pt.name) {
			case "Splitverse.Program":
				foreach(stmt; pt.children) {
					eval(fnidx, stmt[0]);
				}
				break;
			case "Splitverse.BlockStmt":
				funcs[fnidx] ~= InstrPos(new EnterScopeInstr(), filepos(pt));
				foreach(stmt; pt.children) {
					eval(fnidx, stmt[0]);
				}
				funcs[fnidx] ~= InstrPos(new ExitScopeInstr(), filepos(pt));
				break;
			case "Splitverse.ExprStmt":
				eval(fnidx, pt[0]);
				funcs[fnidx] ~= InstrPos(new PopInstr(), filepos(pt));
				break;
			case "Splitverse.DeclStmt": {
				string type = pt.matches[0];
				auto id = pt[0];
				eval(fnidx, pt[1]);
				final switch(type) {
					case "global":
					case "local":
						funcs[fnidx] ~= InstrPos(new DeclareVarInstr(type == "global", id.matches[0]), filepos(pt));
						break;
					case "split":
						funcs[fnidx] ~= InstrPos(new SplitVarInstr(id.matches[0]), filepos(pt));
						break;
				}
				break;
			}
			case "Splitverse.AssignStmt": {
				eval(fnidx, pt[1]);
				funcs[fnidx] ~= InstrPos(new SetVarInstr(pt[0].matches[0]), filepos(pt));
				break;
			}
			case "Splitverse.OpAssignStmt": {
				eval(fnidx, pt[1]);
				void add(string op)() {
					funcs[fnidx] ~= InstrPos(new OpSetVarInstr!op(pt[0].matches[0]), filepos(pt));
				}
				final switch(pt.matches[1]) {
					case "+=": add!"+"; break; 
					case "-=": add!"-"; break;
					case "*=": add!"*"; break;
					case "/=": add!"/"; break;
				}
				break;
			}
			case "Splitverse.WaitStmt": {
				// When thinking about this originally, I was going to have the wait
				// statement have a special implementation, but I now realize it's just
				// a while() without a body.
				long pos = cast(long)funcs[fnidx].length;
				eval(fnidx, pt[0]);
				funcs[fnidx] ~= InstrPos(new UnaryOpInstr!"!"(), filepos(pt[0]));
				funcs[fnidx] ~= InstrPos(new ConditionalJumpInstr(pos-cast(long)funcs[fnidx].length), filepos(pt));
				break;
			}
			case "Splitverse.IfStmt": {
				if(pt.children.length == 3) {
					// if/else
					eval(fnidx, pt[0]);
					long pos1 = cast(long)funcs[fnidx].length;
					funcs[fnidx] ~= InstrPos(null);
					eval(fnidx, pt[2][0]);
					long pos2 = cast(long)funcs[fnidx].length;
					funcs[fnidx] ~= InstrPos(null);
					eval(fnidx, pt[1][0]);

					// create actual jumps
					funcs[fnidx][pos1] = InstrPos(new ConditionalJumpInstr(pos2-pos1+1), filepos(pt));
					funcs[fnidx][pos2] = InstrPos(new JumpInstr(cast(long)funcs[fnidx].length-pos2), filepos(pt));
				} else {
					// if
					eval(fnidx, pt[0]);
					funcs[fnidx] ~= InstrPos(new UnaryOpInstr!"!"(), filepos(pt[0]));
					long pos = cast(long)funcs[fnidx].length;
					funcs[fnidx] ~= InstrPos(null);
					eval(fnidx, pt[1][0]);
					
					// create actual jump
					funcs[fnidx][pos] = InstrPos(new ConditionalJumpInstr(cast(long)funcs[fnidx].length-pos), filepos(pt));
				}
				break;
			}
			case "Splitverse.ReturnStmt": {
				if(pt.children.length == 1)
					eval(fnidx, pt[0]);
				else
					funcs[fnidx] ~= InstrPos(new PushInstr(Value.NULL), filepos(pt));
				funcs[fnidx] ~= InstrPos(new ReturnInstr(), filepos(pt));
				break;
			}
			case "Splitverse.DieStmt":
				funcs[fnidx] ~= InstrPos(new DieInstr(), filepos(pt));
				break;
			case "Splitverse.Expr":
				eval(fnidx, pt[0]);
				foreach(op; pt[1..$]) {
					final switch(op.name) {
						case "Splitverse.And":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"&&"(), filepos(op));
							break;
						case "Splitverse.Or":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"||"(), filepos(op));
							break;
					}
				}
				break;
			case "Splitverse.Prec3":
				eval(fnidx, pt[0]);
				foreach(op; pt[1..$]) {
					final switch(op.name) {
						case "Splitverse.Equ":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"=="(), filepos(op));
							break;
						case "Splitverse.Neq":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"!="(), filepos(op));
							break;
						case "Splitverse.Gt":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!">"(), filepos(op));
							break;
						case "Splitverse.Gte":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!">="(), filepos(op));
							break;
						case "Splitverse.Lt":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"<"(), filepos(op));
							break;
						case "Splitverse.Lte":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"<="(), filepos(op));
							break;
					}
				}
				break;
			case "Splitverse.Prec2":
				eval(fnidx, pt[0]);
				foreach(op; pt[1..$]) {
					final switch(op.name) {
						case "Splitverse.Add":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"+"(), filepos(op));
							break;
						case "Splitverse.Sub":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"-"(), filepos(op));
							break;
					}
				}
				break;
			case "Splitverse.Prec1":
				eval(fnidx, pt[0]);
				foreach(op; pt[1..$]) {
					final switch(op.name) {
						case "Splitverse.Mul":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"*"(), filepos(op));
							break;
						case "Splitverse.Div":
							eval(fnidx, op[0]);
							funcs[fnidx] ~= InstrPos(new OpInstr!"/"(), filepos(op));
							break;
					}
				}
				break;
			case "Splitverse.Primary": {
				auto inner = pt[0];
				switch(inner.name) {
					case "Splitverse.Parens":
						eval(fnidx, inner);
						break;
					case "Splitverse.Neg":
						eval(fnidx, inner[0]);
						funcs[fnidx] ~= InstrPos(new UnaryOpInstr!"-"(), filepos(inner));
						break;
					case "Splitverse.Pos":
						eval(fnidx, inner[0]);
						funcs[fnidx] ~= InstrPos(new UnaryOpInstr!"+"(), filepos(inner));
						break;
					case "Splitverse.Not":
						eval(fnidx, inner[0]);
						funcs[fnidx] ~= InstrPos(new UnaryOpInstr!"!"(), filepos(inner));
						break;
					case "Splitverse.Call":
						eval(fnidx, inner[0]);
						foreach(arg; inner[1].children)
							eval(fnidx, arg);
						funcs[fnidx] ~= InstrPos(new CallInstr(inner[1].children.length), filepos(inner));
						// TODO
						break;
					case "Splitverse.BuiltinCall": {
						string name = inner[0].matches[0];
						foreach(expr; inner[1].children)
							eval(fnidx, expr);
						funcs[fnidx] ~= InstrPos(new BuiltinInstr(name, inner[1].children.length), filepos(inner));
						break;
					}
					case "Splitverse.Bool":
						funcs[fnidx] ~= InstrPos(new PushInstr(Value(inner.matches[0] == "true")), filepos(inner));
						break;
					case "Splitverse.String":
						// TODO: escapes
						funcs[fnidx] ~= InstrPos(new PushInstr(Value(inner.matches[0][1..$-1])), filepos(inner));
						break;
					case "Splitverse.Number":
						funcs[fnidx] ~= InstrPos(new PushInstr(Value(inner.matches[0].to!double)), filepos(inner));
						break;
					case "Splitverse.Identifier":
						funcs[fnidx] ~= InstrPos(new PushVarInstr(inner.matches[0]), filepos(inner));
						break;
					case "Splitverse.Array":
						foreach(child; inner[0])
							eval(fnidx, child);
						funcs[fnidx] ~= InstrPos(new ArrayInstr(inner[0].children.length), filepos(inner));
						break;
					case "Splitverse.Lambda": {
						string[] args = inner[0].children.map!(x => x.matches[0]).array;
						ParseTree[] stmts = inner.children[1..$];

						funcs ~= new InstrPos[0];
						size_t idx = funcs.length-1;
						foreach(stmt; stmts) {
							eval(idx, stmt[0]);
						}
						if(funcs[idx].length == 0 || cast(ReturnInstr)funcs[idx][$-1].instr is null)
							funcs[idx] ~= InstrPos(new ReturnInstr(), filepos(inner));
						funcs[fnidx] ~= InstrPos(new PushFunctionIndexInstr(idx, args), filepos(inner));
						funcs[fnidx] ~= InstrPos(new WrapClosureInstr(), filepos(inner));
						break;
					}
					case "Splitverse.Index":
						eval(fnidx, inner[0]);
						eval(fnidx, inner[1]);
						funcs[fnidx] ~= InstrPos(new IndexInstr(), filepos(inner));
						break;
					default:
						throw new Exception("Invalid parse tree name (inner) '"~inner.name~"'. (THIS IS A DELIC BUG!)");
				}
				break;
			}
			default:
				throw new Exception("Invalid parse tree name (outer) '"~pt.name~"'. (THIS IS A DELIC BUG!)");
		}
	}

	private FilePos filepos(ParseTree pt) => filepos(pt.begin);
	
	private FilePos filepos(size_t pos) {
		int line = 0;
		int col = 0;
		for(size_t i = 0; i < pos; i++) {
			if(code[i] == '\r')
				continue;
			col++;
			if(code[i] == '\n') {
				line++;
				col = 0;
			}
		}
		return FilePos(filename, line, col);
	}
}

/// A variable
class Variable {
	Value value; /// Current value
	bool global; /// Whether it's shared between verses

	this(bool global, Value value) {
		this.global = global;
		this.value = value;
	}
}
/// A variable with a scope
struct VarScope {
	int varScope;
	Variable var;
}

/// A stack frame in a Verse
class Frame {
	size_t pos; /// instruction position
	Value[] stack; /// Value stack
	Frame last; /// Frame to return to
	VarScope[string] vars; /// Variables
	int varScope; /// Variable scope

	this(size_t pos, int varScope = 0, Frame last = null) {
		this.pos = pos;
		this.varScope = varScope;
		this.last = last;
	}

	private this() {}

	Frame clone() {
		auto frame = new Frame();
		frame.pos = pos;
		frame.stack = stack.map!(x => x.clone()).array;
		frame.last = last is null ? null : last.clone();
		foreach(name, vs; vars) {
			if(!vs.var.global)
				frame.vars[name] = VarScope(vs.varScope, new Variable(false, vs.var.value.clone()));
			else
				frame.vars[name] = vs;
		}
		frame.varScope = varScope;
		return frame;
	}
	
	/// pushes a value
	void push(Value v) {
		stack ~= v;
	}
	
	/// pops a value
	Value pop() {
		if(stack.length == 0)
			return Value.NULL;
		auto v = stack[$-1];
		stack = stack[0..$-1];
		return v;
	}

	/// Peeks at the top of the stack
	Value* peek() {
		if(stack.length == 0)
			return null;
		return &stack[$-1];
	}
	
	/// pops N values and returns them in the same order they were on the stack
	Value[] popN(size_t n) {
		Value[] ret = new Value[n];
		for(size_t i = 0; i < n; i++)
			ret[n-i-1] = pop();
		return ret;
	}

	/// Attempts to resolve a variable
	Value resolveVar(string id) {
		if(id !in vars)
			throw new InterpreterException("Could not resolve variable '"~id~"'.");
		return vars[id].var.value;
	}

	/// Declares a variable
	void declareVar(bool global, string id, Value val) {
		if(id in vars)
			throw new InterpreterException("Variable '"~id~"' already declared.");
		vars[id] = VarScope(varScope, new Variable(global, val));
	}
	/// Sets a variable
	void setVar(string id, Value val) {
		if(id !in vars)
			throw new InterpreterException("Could not resolve variable '"~id~"'.");
		vars[id].var.value = val;
	}
	/// Enters a scope
	void enterScope() {
		varScope++;
	}
	/// Exits a scope
	void exitScope() {
		varScope--;
		// cull vars
		foreach(key; vars.keys) {
			if(vars[key].varScope > varScope)
				vars.remove(key);
		}
	}
}

/// A verse
class Verse {
	/// The interpreter
	Interpreter inter;
	/// The Verse ID
	size_t id;
	/// The current stack frame
	Frame frame;

	this(Interpreter inter, size_t id, size_t pos) {
		this.inter = inter;
		this.id = id;
		frame = new Frame(pos);
	}
	
	private this() {}

	Verse clone() {
		Verse verse = new Verse();
		verse.inter = inter;
		verse.id = id;
		verse.frame = frame.clone();
		return verse;
	}

	void step() {
		auto instr = inter.instructions[frame.pos++].instr;
		// writeln(frame.stack);
		// writefln("%x\t%s", frame.pos, instr);
		try {
			instr.run(this);
		} catch(InterpreterException e) {
			throw new InterpreterException(inter.instructions[frame.pos-1].pos, e.msg);
		}
	}

	override string toString() => format("Verse @ %08x", frame.pos);
}

/// A builtin function
alias Builtin = Value delegate(Verse verse, Value[] args);

/// Creates the stdlib
Builtin[string] stdlib() {
	return [
		"print": (Verse verse, Value[] args) {
			foreach(a; args) {
				write(a.toString());
			}
			return Value.NULL;
		},
		"println": (Verse verse, Value[] args) {
			foreach(a; args) {
				write(a.toString());
			}
			writeln();
			return Value.NULL;
		},
		"len": (Verse verse, Value[] args) {
			if(args.length != 1 || args[0].type != ValueType.ARRAY)
				throw new InterpreterException("$len expects arguments: (Array)");
			return Value(cast(double)args[0].asArray.length);
		},
		"range": (Verse verse, Value[] args) {
			noreturn err() {
				throw new InterpreterException("$range expects arguments: (Number? start, Number end, Number? step)");
			}
			foreach(arg; args)
				if(arg.type != ValueType.NUMBER)
					err();
			double start = 0;
			double end = 0;
			double step = 1;
			switch(args.length) {
				case 1:
					end = args[0].asNumber;
					break;
				case 2:
					start = args[0].asNumber;
					end = args[1].asNumber;
					break;
				case 3:
					start = args[0].asNumber;
					end = args[1].asNumber;
					step = args[2].asNumber;
					break;
				default:
					err();
			}
			step = (end > start) != (step > 0) ? -step : step;
			return Value(iota(start, end, step).map!(x => Value(x)).array);
		},
		"permute": (Verse verse, Value[] args) {
			if(args.length != 1 || args[0].type != ValueType.ARRAY)
				throw new InterpreterException("$permute expects arguments: (Array)");
			return Value(permutations(args[0].asArray).map!(x => Value(x.array)).array);
		}
	];
}


/// An interpreter
class Interpreter {
	/// Instructions
	InstrPos[] instructions;
	/// Current verses
	Verse[size_t] verses;
	/// Builtins
	Builtin[string] builtins;
	/// Number of current active verses
	size_t nverses = 0;
	/// ID of the last verse created
	size_t lastID = 0;

	this(string filename, string code) {
		builtins = stdlib();
		instructions = new Compiler(filename, code).compile();
		spawn(0);
	}
	

	/// Steps once
	void step() {
		// debug writeln(verses);
		foreach(i; verses.keys) {
			verses[i].step();
		}
	}
	
	/// Runs until no more verses remain
	void run() {
		while(nverses != 0)
			step();
	}
	
	/// Spawns a verse
	size_t spawn(size_t pos) {
		verses[lastID++] = new Verse(this, lastID-1, pos);
		nverses++;
		return lastID-1;
	}

	/// Spawns a verse from a verse object
	size_t spawn(Verse verse) {
		verse.id = lastID;
		verses[lastID++] = verse;
		nverses++;
		return verse.id;
	}
	
	/// Kills a verse
	void kill(size_t id) {
		verses.remove(id);
		nverses--;
	}
}

void interpret(string filename, string code) {
	auto inter = new Interpreter(filename, code);
	inter.run();
}
