module mir.ion.deser.text.tokens;

/++
    Ion Token Types
+/
enum IonTokenType : ubyte 
{
    TokenInvalid,

    // EOF
    TokenEOF,

    // numbers
    TokenNumber,

    // 0b[01]+
    TokenBinary,

    // 0x[0-9a-fA-F]+
    TokenHex,

    // +inf
    TokenFloatInf,

    // -inf
    TokenFloatMinusInf,

    // 2020-01-01T00:00:00.000Z
    // All timestamps compliant to ISO-8601
    TokenTimestamp,

    // [a-zA-Z_]+
    TokenSymbol,

    // '[^']+'
    TokenSymbolQuoted,

    // [+-/*]
    TokenSymbolOperator,

    // "[^"]+"
    TokenString,

    // '''[^']+'''
    TokenLongString,

    // [.]
    TokenDot,

    // [,]
    TokenComma,

    // :
    TokenColon,

    // ::
    TokenDoubleColon,

    // (
    TokenOpenParen,

    // )
    TokenCloseParen,

    // {
    TokenOpenBrace,

    // }
    TokenCloseBrace,

    // [
    TokenOpenBracket,

    // ]
    TokenCloseBracket,

    // {{ 
    TokenOpenDoubleBrace,

    // }} 
    TokenCloseDoubleBrace
}

version(mir_ion_test) unittest 
{
    static assert(!IonTokenType.TokenInvalid);
    static assert(IonTokenType.TokenInvalid == IonTokenType.init);
    static assert(IonTokenType.TokenEOF > 0);
}

/++
Params:
    code = $(LREF IonTokenType)
Returns:
    Stringified version of the token
+/
    
string ionTokenMsg(IonTokenType token) @property
@safe pure nothrow @nogc
{
    static immutable string[] tokens = [
        "<invalid>",
        "<EOF>",
        "<number>",
        "<binary>",
        "<hex>",
        "+inf",
        "-inf",
        "<timestamp>",
        "<symbol>",
        "<quoted-symbol>",
        "<operator>",
        "<string>",
        "<long-string>",
        ".",
        ",",
        ":",
        "::",
        "(",
        ")",
        "{",
        "}",
        "[",
        "]",
        "{{",
        "}}",
        "<error>"
    ];
    return tokens[token - IonTokenType.min];
}

@safe pure nothrow @nogc
version(mir_ion_test) unittest
{
    static assert(IonTokenType.TokenInvalid.ionTokenMsg == "<invalid>");
    static assert(IonTokenType.TokenCloseDoubleBrace.ionTokenMsg == "}}");
}

enum ION_OPERATOR_CHARS = ['!', '#', '%', '&', '*', '+', '-', '.', '/', ';', '<', '=',
		'>', '?', '@', '^', '`', '|', '~'];

enum ION_WHITESPACE = [' ', '\t', '\n', '\r'];

enum ION_STOP_CHARS = [0, '{', '}', '[', ']', '(', ')', ',', '"', '\'',
		' ', '\t', '\n', '\r'];

import std.ascii : uppercase, lowercase, fullHexDigits, digits;
enum ION_DIGITS = digits;
enum ION_HEX_DIGITS = fullHexDigits;
enum ION_IDENTIFIER_START_CHARS = lowercase ~ uppercase ~ ['_', '$'];
enum ION_IDENTIFIER_CHARS = ION_IDENTIFIER_START_CHARS ~ digits;
enum ION_QUOTED_SYMBOLS = ["", "null", "true", "false", "nan"];

bool isDigit(ubyte c) {
    static foreach(member; ION_DIGITS) {
        if (c == member) return true;
    }
    return false;
}

bool isIdentifierStart(ubyte c) {
    static foreach(member; ION_IDENTIFIER_CHARS) {
        if (c == member) return true;
    }
    return false;
}

bool isIdentifierPart(ubyte c) {
    return isIdentifierStart(c) || isDigit(c);
}   

bool isOperatorChar(ubyte c) {
    static foreach(member; ION_OPERATOR_CHARS) {
        if (c == member) return true;
    }
    return false;
}

bool isStopChar(ubyte c) {
    static foreach(member; ION_STOP_CHARS) {
        if (c == member) return true;
    }
    return false;
}

bool isWhitespace(ubyte c) {
    static foreach(member; ION_WHITESPACE) {
        if (c == member) return true;
    }
    return false;
}


bool symbolNeedsQuotes(string symbol) {
    static foreach(member; ION_QUOTED_SYMBOLS) {
        if (symbol == member) return true;
    }

    if (!isIdentifierStart(symbol[0])) return true;
    for (auto i = 0; i < symbol.length; i++) {
        if (!isIdentifierPart(symbol[i])) return true;
    }
    return false;
}

version(D_Exceptions):
import mir.ion.exception;

/++
    Mir Ion Tokenizer Exception
+/
class MirIonTokenizerException : MirIonException 
{
    ///
    @safe pure nothrow @nogc
    this(string msg, string file = __FILE__, int line = __LINE__)
    {
        super(msg, file, line);
    }
}
