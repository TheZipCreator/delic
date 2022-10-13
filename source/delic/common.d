/// Contains some utilities used by other parts of this package
module delic.common;

/// Returns a single unbuffered character from stdin
char getch();

version(Windows) {
  extern(C) int _getch();
  char getch() {
    char c = cast(char)_getch;
    switch(c) {
      case '\r':
        return '\n';
      case 3: {
        // ctrl+c
        import core.stdc.stdlib : exit;
        exit(0);
      }
      default:
        return c;
    }
  }
}

// TODO: support linux & macos

/// Thrown when an error occurs in any of the interpreters
class InterpreterException : Exception {
  this(string msg) {
    super(msg);
  }
  import std.conv;
  this(int line, string msg) {
    super(line.to!string~": "~msg);
  }
  this(int line, int col, string msg) {
    super(line.to!string~":"~col.to!string~": "~msg);
  }
}