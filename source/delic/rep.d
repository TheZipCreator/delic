module delic.rep;

import pegged.grammar;
import std.stdio, std.conv;
import delic.common;

private {
  mixin(grammar(`
    Rep:
      Program <  Unit* endOfInput

      Unit <  (Identifier ':' (Statement)*)

      # TODO: Comment <- '#' .* endOfLine

      Statement <  RepStmt
        / EmptyStmt
        / ExprStmt
        / AssignStmt

      RepStmt <  'rep' Expression Statement
      EmptyStmt <  ';'
      ExprStmt <  Expression ';'
      BlockStmt <  '{' Statement* '}'
      AssignStmt <  Identifier '=' Expression ';'

      Expression <  PipeExpr
        / LitExpr
      
      PipeExpr <  Expression '|' Identifier
      LitExpr <  Cycles / Char / Identifier / Number

      Cycles <- '$'
      Identifier <~ [a-zA-Z_] [a-zA-Z0-9_]*
      Number <~ [0-9]*
      Char <- quote .
  `));
  ParseTree[][string] units;
  struct State {
    ubyte cycles;
    ubyte[string] vars;
  }
  void interpret(ParseTree[] code, State* state) {
    ubyte eval(ParseTree expr) {
      expr = expr[0];
      final switch(expr.name) {
        case "Rep.LitExpr":
          expr = expr[0];
          final switch(expr.name) {
            case "Rep.Cycles":
              return state.cycles;
            case "Rep.Identifier": {
              string name = expr.matches[0];
              if(name == "stdin")
                return cast(ubyte)getch;
              if(name in state.vars)
                return state.vars[name];
              throw new InterpreterException("No variable "~name);
            }
            case "Rep.Number":
              return expr.matches[0].to!ubyte;
            case "Rep.Char":
              return cast(ubyte)expr.matches[1][0];
          }
        case "Rep.PipeExpr": {
          ubyte input = eval(expr[0]);
          string unit = expr[1].matches[0];
          if(unit == "stdout") {
            write(cast(char)input);
            return 0;
          }
          else if(unit !in units)
            throw new InterpreterException("No unit "~unit);
          State s = State(input);
          interpret(units[unit], &s);
          return s.cycles;
        }
      }
    }
    foreach(stmt; code) {
      stmt = stmt[0];
      final switch(stmt.name) {
        case "Rep.EmptyStmt":
          state.cycles++;
          break;
        case "Rep.RepStmt":
          for(int i = 0; i < eval(stmt[0]); i++)
            interpret([stmt[1]], state);
          break;
        case "Rep.BlockStmt":
          interpret(stmt.children, state);
          break;
        case "Rep.ExprStmt":
          eval(stmt[0]);
          state.cycles++;
          break;
        case "Rep.AssignStmt":
          state.vars[stmt[0].matches[0]] = eval(stmt[1]);
          state.cycles++;
          break;
      }
    }
  }
}

void interpret(string code) {
  auto ast = Rep(code);
  //writeln(ast);
  foreach(c; ast[0]) {
    units[c[0].matches[0]] = c[1..$];
  }
  if("main" !in units)
    throw new InterpreterException("Program must contain 'main' unit");
  State s = State(0);
  interpret(units["main"], &s);
}