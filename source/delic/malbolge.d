/// Runs the malbolge virtual machine.
module delic.malbolge;

import delic.common;

import std.stdio;


private {
	/// The crazy operation
	trint crazy(trint a, trint b) {
		static const table = [
			// table such that (x << 2) | y gives the correct value
			0b01, 0b00, 0b00, 0,
			0b01, 0b00, 0b10, 0,
			0b10, 0b10, 0b01, 0
		];
		trint ret = 0;
		static foreach(pos; 0..10) {
			{
				trint x = (a & (0b11 << pos*2)) >> pos*2;
				trint y = (b & (0b11 << pos*2)) >> pos*2;
				ret |= table[(x << 2) | y] << pos*2;
			}
		}
		return ret;
	}

	/// Rotates a trint right
	trint rotRight(trint a) {
		trint end = a & 0b11;
		a >>= 2;
		a |= (end << 18);
		return a;
	}

	/// Converts a trint to an int
	uint trintToInt(trint a) {
		uint ret = 0;
		static foreach(pos; 0..10) {
			ret += 3^^pos*((a & (0b11 << pos*2)) >> pos*2);
		}
		return ret;
	}

	/// Converts an int to a trint
	trint intToTrint(uint a) {
		a %= 59049;
		trint ret = 0;
		static foreach_reverse(pos; 0..10) {
			{
				uint pow = 3^^pos;
				if(a >= 2*pow) {
					a -= 2*pow;
					ret |= 0b10 << pos*2;
				}
				else if(a >= pow) {
					a -= pow;
					ret |= 0b01 << pos*2;
				}
			}
		}
		return ret;
	}

	/// Converts a trint to a string
	string trintToString(trint a) {
		string ret;
		static const trits = "012?";
		static foreach_reverse(pos; 0..10) {
			ret ~= trits[(a & (0b11 << pos*2)) >> pos*2];
		}
		return ret;
	}
	
	unittest {
		foreach(i; 0..59048) {
			assert(trintToInt(intToTrint(i)) == i);
		}
		assert(crazy(0b00_01_10_00_01_10_00_01_10, 0b00_00_00_01_01_01_10_10_10) == 0b01_01_01_10_00_00_10_00_10_01);
	}

	enum string tbl1 = "+b(29e*j1VMEKLyC})8&m#~W>qxdRp0wkrUo[D7,XTcA\"lI.v%{gJh4G\-=O@5`_3i<?Z';FNQuY]szf$!BS/|t:Pn6^Ha";
	enum string tbl2 = "5z]&gqtyfr$(we4{WP)H-Zn,[%\\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK'X~xDl}REokN:#?G\"i@";
}


/// Interprets trint code
void interpret(string code) {
	// registers and memory
	trint c = 0, d = 0, a = 0;
	trint[59048] memory;
	// init memory
	{
		size_t i = 0;
		for(char c; code) {
			if(c == ' ' || c == '\t' || c == '\n' || c == '\r')
				continue;
			if(i >= memory.length)
				throw new InterpreterException("Input file too long.");
			// TODO: check validity
			memory[i] = intToTrint(cast(uint)c);
			i++;
		}
		// fill rest with crazy op
		while(i < 59049) {
			memory[i] = crazy(memory[(i-1)%memory.length], memory[(i-2)%memory.length]);
			i++;
		}
	}
	while(true) {

		char c = tbl1[
	}

}
