module delic.throughput;

import std.variant, std.stdio, std.conv, std.typecons;
import delic.common;
import pegged.grammar;

private {
  mixin(grammar(`
    Throughput:
      Program <  (Connection / Declaration)* endOfInput

      Connection <  Identifier ('->' Identifier)+
      Declaration <  Identifier ':' NodeType

      NodeType <  Emitter
        / Output
        / Halter
        / Operator
        / Buffer

      Emitter <  'emitter' '[' Value (Number Number?)? ']'
      Output <  'output'
      Halter <  'halter'
      Operator <  OperatorName ('[' Value ']')?
      OperatorName <  'adder' / 'subtractor' / 'multiplier' / 'divider' / 'moduler' / 'concatenator'
      Buffer <  'buffer' ('[' Value ']')?

      Value <  Number
        / String
        / ^'in'
        / ^'out'
      Number <~ '-'? [0-9]+
      String <~ doublequote (!doublequote .)* doublequote
      EscapeSequence <- backslash (doublequote / backslash / [rn])
      Identifier <~ [0-9a-zA-Z$_\-]+
  `));
  struct Var {
    enum Type {
      NUMBER, STRING
    }
    Type type;
    Variant value;
    this(int n) {
      type = Type.NUMBER;
      value = n;
    }
    this(string s) {
      type = Type.STRING;
      value = s;
    }
    T get(T)() {
      return value.get!T;
    }
    string toString() {
      final switch(type) {
        case Type.NUMBER:
          return get!int.to!string;
        case Type.STRING:
          return get!string;
      }
    }
    mixin template genOp(string s) {
      import std.string;
      mixin(q{
        int res;
        foreach(Var v; vars) {
          if(v.type != Type.NUMBER)
            throw new InterpreterException("Attempted to add the non-number value "~v.toString);
          res {op}= v.get!int;
        }
        return Var(res);
      }.replace("{op}", s));
    }
    static Var add(Var[] vars) {
      mixin genOp!"+";
    }
    static Var sub(Var[] vars) {
      mixin genOp!"-";
    }
    static Var mul(Var[] vars) {
      mixin genOp!"*";
    }
    static Var div(Var[] vars) {
      mixin genOp!"/";
    }
    static Var mod(Var[] vars) {
      mixin genOp!"%";
    }
  }
  mixin template NodeConstructor() {
    this(string name) {
      super(name);
    }
  }
  abstract class Node {
    Node*[] outputs;
    string name;
    this(string name) {
      this.name = name;
    }
    void input(int tick, Var value) {}
    void output(int tick) {}
    void addOutput(Node* n) {
      outputs ~= n;
    }
    string outputArrayString() {
      string s = "";
      foreach(o; outputs)
        s ~= "-> "~o.toString~" ";
      return s;
    }
  }
  class Emitter : Node {
    Var value;
    int frequency = 0;
    int offset = 0;
    bool triggered = false;
    this(string name, Var value) {
      super(name);
      this.value = value;
    }
    this(string name, Var value, int frequency) {
      super(name);
      this.value = value;
      this.frequency = frequency;
    }
    this(string name, Var value, int frequency, int offset) {
      super(name);
      this.value = value;
      this.frequency = frequency;
      this.offset = offset;
    }
    override void input(int tick, Var value) {
      triggered = true;
    }
    override void output(int tick) {
      if(triggered || frequency == 0 ? false : (tick+offset)%frequency == 0) {
        triggered = false;
        foreach(n; outputs)
          n.input(tick, value);
      }
    }
    override string toString() {
      return "emitter["~value.toString~" "~frequency.to!string~" "~offset.to!string~"] "~outputArrayString;
    }
  }
  struct Triggered(T) {
    bool triggered = false;
    T payload;
    this(T payload) {
      triggered = true;
      this.payload = payload;
    }
  }
  class Output : Node {
    mixin NodeConstructor;
    Var[] inputs;
    override void input(int tick, Var value) {
      write(value);
      inputs ~= value;
    }
    override void output(int tick) {
      if(inputs.length > 0) {
        foreach(o; outputs)
          foreach(i; inputs)
            o.input(tick, i);
        inputs = [];
      }
    }
    override string toString() {
      return "output "~outputArrayString;
    }
  }
  class HaltException : Exception {
    this() {
      super("");
    }
  }
  class Halter : Node {
    mixin NodeConstructor;
    override void input(int tick, Var value) {
      throw new HaltException;
    }
    override string toString() {
      return "halter "~outputArrayString;
    }
  }
  // op should be a static Var function (add, sub, mul, div, con)
  class Operator(string op) : Node {
    Var[] inputs;
    Var value;
    this(string name) {
      super(name);
    }
    this(string name, Var value) {
      super(name);
      this.value = value;
    }
    override void input(int tick, Var value) {
      inputs ~= value;
    }
    override void output(int tick) {
      mixin(`Var res = Var.`~op~`(inputs);`);
      inputs = [];
      return res;
    }
  }

  Var value(ParseTree v) {
    if(v.children.length > 0)
      v = v[0];
    final switch(v.name) {
      case "Throughput.Number":
        return Var(v.matches[0].to!int);
      case "Throughput.String":
        return Var(v.matches[0][1..$-1]); // TODO: parse escape codes
    }
  }
  
  Node[] generateNodes(ParseTree ast) {
    Node[] nodes;
    Node*[string] names;
    foreach(child; ast) {
      final switch(child.name) {
        case "Throughput.Declaration": {
          string name = child[0].matches[0];
          auto nodeType = child[1][0];
          Node n;
          final switch(nodeType.name) {
            case "Throughput.Emitter":
              final switch(nodeType.children.length) {
                case 1:
                  n = new Emitter(name, nodeType[0].value);
                  break;
                case 2:
                  n = new Emitter(name, nodeType[0].value, nodeType[1].value.get!int);
                  break;
                case 3:
                  n = new Emitter(name, nodeType[0].value, nodeType[1].value.get!int, nodeType[2].value.get!int);
                  break;
              }
              break;
            case "Throughput.Output":
              n = new Output(name);
              break;
            case "Throughput.Halter":
              n = new Halter(name);
              break;
          }
          nodes ~= n;
          names[name] = &nodes[$-1];
          break;
        }
        case "Throughput.Connection": {
          string srcString = child[0].matches[0];
          if(srcString !in names)
            throw new InterpreterException("Unknown Node "~srcString);
          Node* src = names[srcString];
          foreach(n; child[1..$]) {
            string destString = n.matches[0];
            if(destString !in names)
              throw new InterpreterException("Unknown Node "~destString);
            src.addOutput(names[destString]);
          }
        }
      }
    }
    return nodes;
  }
}

/// Interprets Throughput Code
void interpret(string code) {
  auto ast = Throughput(code);
  if(!ast.successful)
    throw new InterpreterException(ast.failMsg);
  ast = ast[0]; // grab Throughput.Program
  Node[] nodes = generateNodes(ast);
  int tick;
  try {
    while(true) {
      foreach(Node n; nodes) {
        n.output(tick);
      }
      tick++;
    }
  } catch(HaltException) {
    // halter triggered: stop execution
  }
}