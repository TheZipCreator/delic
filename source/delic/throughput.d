module delic.throughput;

import std.variant, std.stdio, std.conv;
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

      Emitter <  'emitter' '[' Value (Number)? ']'
      Output <  'output'
      Halter <  'halter'

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
                  n = new Emitter(name, value(nodeType[0]));
                  break;
                case 2:
                  n = new Emitter(name, value(nodeType[0]), value(nodeType[1]).get!int);
                  break;
                case 3:
                  n = new Emitter(name, value(nodeType[0]), value(nodeType[1]).get!int, value(nodeType[2]).get!int);
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
  auto ast = Throughput(code)[0];
  //writeln(ast);
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

  }
}