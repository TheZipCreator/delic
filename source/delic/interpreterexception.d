module delic.interpreterexception;

class InterpreterException : Exception {
  this(string msg) {
    super(msg);
  }
}