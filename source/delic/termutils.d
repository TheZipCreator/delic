module delic.termutils;

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