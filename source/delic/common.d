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
else version(Posix) {
	import core.stdc.stdio;
	import core.sys.posix.termios;
	import core.sys.posix.unistd;
	char getch() {
		// some magic to change the terminal state to not line buffer
		termios oldt, newt;
		tcgetattr(STDIN_FILENO, &oldt);
		newt = oldt;
		newt.c_lflag &= ~(ICANON);
		// get char
		// NOTE: this does not check for EOF. piping something into stdin will result in garbage characters being read. In non-canonical mode, EOF is not returned by getchar(), so I can't just do that
		// TODO: fix
		char c = cast(char)(getchar());
		// restore old terminal state
		tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
		// return char
		return c;
	}
}
else static assert(0, "There is currently no implementation of getch() for your system. Please implement one in order to compile DELIC.");

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
