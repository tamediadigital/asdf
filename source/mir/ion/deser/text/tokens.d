/++
    Token definitions for parsing Ion Text.
+/
module mir.ion.deser.text.tokens;

/++
    Ion Token Types
+/
enum IonTokenType : ubyte 
{
    /++ Invalid token +/
    TokenInvalid,

    /++ EOF +/
    TokenEOF,

    /++ numbers +/
    TokenNumber,

    /++ 0b[01]+ +/
    TokenBinary,

    /++ 0x[0-9a-fA-F]+ +/
    TokenHex,

    /++ +inf +/
    TokenFloatInf,

    /++ -inf +/
    TokenFloatMinusInf,

    /++
       2020-01-01T00:00:00.000Z

       All timestamps *must* be compliant to ISO-8601
    +/
    TokenTimestamp,

    /++ [a-zA-Z_]+ +/
    TokenSymbol,

    /++ '[^']+' +/
    TokenSymbolQuoted,

    /++ [+-/*] +/
    TokenSymbolOperator,

    /++ "[^"]+" +/
    TokenString,

    /++ '''[^']+''' +/
    TokenLongString,

    /++ [.] +/
    TokenDot,

    /++ [,] +/
    TokenComma,

    /++ : +/
    TokenColon,

    /++ :: +/
    TokenDoubleColon,

    /++ ( +/
    TokenOpenParen,

    /++ ) +/
    TokenCloseParen,

    /++ { +/
    TokenOpenBrace,

    /++ } +/
    TokenCloseBrace,

    /++ [ +/
    TokenOpenBracket,

    /++ ] +/
    TokenCloseBracket,

    /++ {{ +/ 
    TokenOpenDoubleBrace,

    /++ }} +/ 
    TokenCloseDoubleBrace
}

///
version(mir_ion_test) unittest 
{
    static assert(!IonTokenType.TokenInvalid);
    static assert(IonTokenType.TokenInvalid == IonTokenType.init);
    static assert(IonTokenType.TokenEOF > 0);
}

/++
Get a stringified version of a token.
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
///
@safe pure nothrow @nogc
version(mir_ion_test) unittest
{
    static assert(IonTokenType.TokenInvalid.ionTokenMsg == "<invalid>");
    static assert(IonTokenType.TokenCloseDoubleBrace.ionTokenMsg == "}}");
}


/++
    All valid Ion operator characters.
+/
static immutable ION_OPERATOR_CHARS = ['!', '#', '%', '&', '*', '+', '-', '.', '/', ';', '<', '=',
		'>', '?', '@', '^', '`', '|', '~'];

/++
    All characters that Ion considers to be whitespace
+/
static immutable ION_WHITESPACE = [' ', '\t', '\n', '\r'];

/++
    All characterst that Ion considers to be the end of a token (stop chars)
+/
static immutable ION_STOP_CHARS = [0, '{', '}', '[', ']', '(', ')', ',', '"', '\'',
		' ', '\t', '\n', '\r'];

import std.ascii : uppercase, lowercase, fullHexDigits, digits;
/++
    All valid digits within Ion (0-9)
+/
static immutable ION_DIGITS = digits;

/++
    All valid hex digits within Ion ([a-fA-F0-9])
+/
static immutable  ION_HEX_DIGITS = fullHexDigits;

/++
    All valid characters which can be the beginning of an identifier (a-zA-Z_$)
+/
static immutable  ION_IDENTIFIER_START_CHARS = lowercase ~ uppercase ~ ['_', '$'];

/++
    All valid characters which can be within an identifier (a-zA-Z$_0-9)
+/
static immutable  ION_IDENTIFIER_CHARS = ION_IDENTIFIER_START_CHARS ~ digits;

/++
    All symbols which must be surrounded by quotes
+/
static immutable ION_QUOTED_SYMBOLS = ["", "null", "true", "false", "nan"];

@safe:
/++
    Check if a character is considered by Ion to be a digit.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a digit.
+/
bool isDigit(ubyte c) {
    static foreach(member; ION_DIGITS) {
        if (c == member) return true;
    }
    return false;
}

/++
    Check if a character is considered by Ion to be a hex digit.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a hex digit.
+/
bool isHexDigit(ubyte c) {
    static foreach(member; ION_HEX_DIGITS) {
        if (c == member) return true;
    }
    return false;
}

/++
    Check if a character is considered by Ion to be a valid start to an identifier.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a valid start to an identifier.
+/
bool isIdentifierStart(ubyte c) {
    static foreach(member; ION_IDENTIFIER_CHARS) {
        if (c == member) return true;
    }
    return false;
}

/++
    Check if a character is considered by Ion to be a valid part of an identifier.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a valid part of an identifier.
+/
bool isIdentifierPart(ubyte c) {
    return isIdentifierStart(c) || isDigit(c);
}   

/++
    Check if a character is considered by Ion to be a symbol operator character.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a symbol operator character.
+/
bool isOperatorChar(ubyte c) {
    static foreach(member; ION_OPERATOR_CHARS) {
        if (c == member) return true;
    }
    return false;
}

/++
    Check if a character is considered by Ion to be a "stop" character.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a "stop" character.
+/
bool isStopChar(ubyte c) {
    static foreach(member; ION_STOP_CHARS) {
        if (c == member) return true;
    }

    return false;
}

/++
    Check if a character is considered by Ion to be whitespace.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be whitespace.
+/
bool isWhitespace(ubyte c) {
    static foreach(member; ION_WHITESPACE) {
        if (c == member) return true;
    }
    return false;
}

/++
    Check if a character is considered by Ion to be a hex digit.
    Params:
        c = The character to check
    Returns:
        true if the character is considered by Ion to be a hex digit.
+/
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
