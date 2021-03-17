/++
Helpers to skip over a given Ion Text token.

Authors: Harrison Ford
+/
module mir.ion.deser.text.skippers;
import mir.ion.deser.text.tokenizer;
import mir.ion.deser.text.tokens;
import mir.ion.type_code;
import std.traits : isInstanceOf;
import std.range;

/++
Skip over the contents of a S-Exp/Struct/List/Blob.
Params:
    t = The tokenizer
    term = The last character read from the tokenizer's input range
Returns:
    A character located after the [s-exp, struct, list, blob].
+/
ubyte skipContainer(T)(ref T t, ubyte term) @safe @nogc pure 
if (isInstanceOf!(IonTokenizer, T)) {
    skipContainerInternal!T(t, term);
    return t.readInput();
}

/++
Skip over the contents of a S-Exp/Struct/List/Blob, but do not read any character after the terminator.

Params:
    t = The tokenizer
    term = The last character read from the tokenizer's input range
+/
void skipContainerInternal(T)(ref T t, ubyte term) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) 
in {
    assert(term == ']' || term == '}' || term == ')', "Unexpected character for skipping");
} body {
    ubyte c;
    while (true) {
        c = t.skipWhitespace();
        if (c == term) return;
        t.expect!("a != 0", true)(c);
        switch (c) {
            case '"':
                t.skipStringInternal();
                break;
            case '\'':
                if (t.isTripleQuote()) {
                    skipLongStringInternal!(T, true, false)(t);
                } else {
                    t.skipSymbolQuotedInternal();
                }
                break;
            case '(':
                skipContainerInternal!(T)(t, ')');
                break;
            case '[':
                skipContainerInternal!(T)(t, ']');
                break;
            case '{':
                c = t.peekOne();
                if (c == '{') {
                    t.expect!"a != 0";
                    t.skipBlobInternal();
                } else if (c == '}') {
                    t.expect!"a != 0";
                } else {
                    skipContainerInternal!(T)(t, '}');
                }
                break;
            default:
                break;
        }


    }
}

/++
Skip over a single line comment. This will read input up until a newline or the EOF is hit.
Params:
    t = The tokenizer
Returns:
    true if it was able to skip over the comment.
+/
bool skipSingleLineComment(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    while (true) {
        const(ubyte) c = t.readInput();
        if (c == '\n' || c == 0) {
            return true;
        }
    }
}
/// Test skipping over single-line comments.
version(mir_ion_parser_test) unittest 
{
    import mir.ion.deser.text.tokenizer : tokenizeString, testRead;
    auto t = tokenizeString("single-line comment\r\nok");
    assert(t.skipSingleLineComment());

    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}
/// Test skipping of a single-line comment on the last line
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString, testRead;
    auto t = tokenizeString("single-line comment");
    assert(t.skipSingleLineComment());
    t.testRead(0);
}

/++
    Skip over a block comment. This will read up until `*/` is hit.
    Params:
        t = The tokenizer
    Returns:
        true if the block comment was able to be skipped, false if EOF was hit
+/
bool skipBlockComment(T)(ref T t) @safe @nogc pure 
if (isInstanceOf!(IonTokenizer, T)) {
    bool foundStar = false;
    while (true) {
        const(ubyte) c = t.readInput();
        if (foundStar && c == '/') {
            return true;
        }
        if (c == 0) {
            return false;
        }

        if (c == '*') {
            foundStar = true;
        }
    }
}
/// Test skipping of an invalid comment
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    auto t = tokenizeString("this is a string that never ends");
    assert(!t.skipBlockComment());
}
/// Test skipping of a multi-line comment
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString, testRead;
    auto t = tokenizeString("this is/ a\nmulti-line /** comment.**/ok");
    assert(t.skipBlockComment());

    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}

/++
Skip over a comment (block or single-line) after reading a '/'
Params:
    t = The tokenizer
Returns:
    true if it was able to skip over the comment
+/
bool skipComment(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    if (t.input.empty) {
        return false;
    }
    const(ubyte) c = t.peekOne();
    switch(c) {
        case '/':
            return t.skipSingleLineComment();
        case '*':
            return t.skipBlockComment();
        default:
            break;
    }

    return false;
}
/// Test single-line skipping
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString, testRead;
    auto t = tokenizeString("/comment\nok");
    assert(t.skipComment());
    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}
/// Test block skipping
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString, testRead;
    auto t = tokenizeString("*comm\nent*/ok");
    assert(t.skipComment());
    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}
/// Test false-alarm skipping
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString, testRead;
    auto t = tokenizeString(" 0)");
    assert(!t.skipComment());
    t.testRead(' ');
    t.testRead('0');
    t.testRead(')');
    t.testRead(0);
}

/++
Skip any digits after the last character read.
Params:
    t = The tokenizer
    _c = The last character read from the tokenizer input range.
Returns:
    A character located after the last digit skipped.
+/
ubyte skipDigits(T)(ref T t, ubyte _c) @safe @nogc pure 
if(isInstanceOf!(IonTokenizer, T)) {
    auto c = _c;
    while (c.isDigit()) {
        c = t.readInput();
    }
    return c;
}

/++
Skip over a non-[hex, binary] number.
Params:
    t = The tokenizer
Returns:
    A character located after the number skipped.
+/
ubyte skipNumber(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte c = t.readInput();
    if (c == '-') {
        c = t.readInput();
    }

    c = skipDigits!T(t, c);
    if (c == '.') {
        c = t.readInput();
        c = skipDigits!T(t, c);
    }

    if (c == 'd' || c == 'D' || c == 'e' || c == 'E') {
        c = t.readInput();
        if (c == '+' || c == '-') {
            c = t.readInput();
        }
        c = skipDigits!T(t, c);
    }

    return t.expect!(t.isStopChar, true)(c);
}
/// Test skipping over numbers
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    import mir.ion.deser.text.tokens : MirIonTokenizerException;

    void test(string ts, ubyte expected) {
        auto t = tokenizeString(ts);
        assert(t.skipNumber() == expected);
    }

    void testFail(string ts) {
        import std.exception : assertThrown;
        auto t = tokenizeString(ts);
        assertThrown!MirIonTokenizerException(t.skipNumber());
    }

    test("", 0);
    test("0", 0);
    test("-1234567890,", ',');
    test("1.2 ", ' ');
    test("1d45\n", '\n');
    test("1.4e-12//", '/');
    testFail("1.2d3d");
}

/++
Skip over a binary number.
Params:
    t = The tokenizer
Returns:
    A character located after the number skipped.
+/
ubyte skipBinary(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    return skipRadix!(T, "a == 'b' || a == 'B'", "a == '0' || a == '1'")(t);   
}
/// Test skipping over binary numbers
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    import mir.ion.deser.text.tokens : MirIonTokenizerException;

    void test(string ts, ubyte expected) {
        auto t = tokenizeString(ts);
        assert(t.skipBinary() == expected);
    }

    void testFail(string ts) {
        import std.exception : assertThrown;
        auto t = tokenizeString(ts);
        assertThrown!MirIonTokenizerException(t.skipBinary());
    }

    test("0b0", 0);
    test("-0b10 ", ' ');
    test("0b010101,", ',');

    testFail("0b2");
}

/++
Skip over a hex number.
Params:
    t = The tokenizer
Returns:
    A character located after the number skipped.
+/
ubyte skipHex(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    return skipRadix!(T, "a == 'x' || a == 'X'", isHexDigit)(t); 
}
/// Test skipping over hex numbers
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    import mir.ion.deser.text.tokens : MirIonTokenizerException;

    void test(string ts, ubyte expected) {
        auto t = tokenizeString(ts);
        assert(t.skipHex() == expected);
    }

    void testFail(string ts) {
        import std.exception : assertThrown;
        auto t = tokenizeString(ts);
        assertThrown!MirIonTokenizerException(t.skipHex());
    }

    test("0xDEADBABE,0xDEADBABE", ',');
    test("0x0", 0);
    test("-0x0F ", ' ');
    test("0x1234567890abcdefABCDEF,", ',');

    testFail("0xG");
}

/++
Skip over a number given two predicates to determine the number's marker (`0x`, `0b`) and if any input is valid.
Params:
    isMarker = A predicate which determines if the marker in a number is valid.
    isValid = A predicate which determines the validity of digits within a number.
    t = The tokenizer
Returns:
    A character located after the number skipped.
+/
template skipRadix(T, alias isMarker, alias isValid)
if (isInstanceOf!(IonTokenizer, T)) {
    import mir.functional : naryFun;
    ubyte skipRadix(ref T t) @safe @nogc pure {
        auto c = t.readInput();

        // Skip over negatives 
        if (c == '-') {
            c = t.readInput();
        }

        t.expect!("a == '0'", true)(c); // 0
        t.expect!(isMarker); // 0(x || b)
        while (true) {
            c = t.readInput();
            if (!naryFun!isValid(c)) {
                break;
            }
        }
        return t.expect!(isStopChar, true)(c);
    }
}

/++
Skip over a timestamp (compliant to ISO 8601)
Params:
    t = The tokenizer
Returns:
    A character located after the timestamp skipped.
+/
ubyte skipTimestamp(T)(ref T t) @safe @nogc pure 
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte skipTSDigits(int count) {
        int i = count;
        while (i > 0) {
            t.expect!(isDigit);
            i--;
        }
        return t.readInput();
    }

    ubyte skipTSOffset(ubyte c) {
        if (c != '+' && c != '-') {
            return c;
        }

        t.expect!("a == ':'", true)(skipTSDigits(2));
        return skipTSDigits(2);
    }

    ubyte skipTSOffsetOrZ(ubyte c) {
        t.expect!("a == '+' || a == '-' || a == 'z' || a == 'Z'", true)(c);
        if (c == '+' || c == '-') 
            return skipTSOffset(c);
        if (c == 'z' || c == 'Z') 
            return t.readInput();
        assert(0); // should never hit this
    }

    ubyte skipTSFinish(ubyte c) {
        return t.expect!(isStopChar, true)(c);
    }

    // YYYY(T || '-')
    const(ubyte) afterYear = t.expect!("a == 'T' || a == '-'", true)(skipTSDigits(4));
    if (afterYear == 'T') {
        // skipped yyyyT
        return t.readInput();
    }

    // YYYY-MM('T' || '-')
    const(ubyte) afterMonth = t.expect!("a == 'T' || a == '-'", true)(skipTSDigits(2));
    if (afterMonth == 'T') {
        // skipped yyyy-mmT
        return t.readInput();
    }

    // YYYY-MM-DD('T')?
    ubyte afterDay = skipTSDigits(2);
    if (afterDay != 'T') {
        // skipped yyyy-mm-dd
        return skipTSFinish(afterDay);
    }

    // YYYY-MM-DDT('+' || '-' || 'z' || 'Z' || isDigit)
    ubyte offsetH = t.readInput();
    if (!offsetH.isDigit()) {
        // YYYY-MM-DDT('+' || '-' || 'z' || 'Z')
        // skipped yyyy-mm-ddT(+hh:mm)
        ubyte afterOffset = skipTSOffset(offsetH);
        return skipTSFinish(afterOffset);
    }

    // YYYY-MM-DDT[0-9][0-9]:
    t.expect!("a == ':'", true)(skipTSDigits(1));

    // YYYY-MM-DDT[0-9][0-9]:[0-9][0-9](':' || '+' || '-' || 'z' || 'Z')
    ubyte afterOffsetMM = t.expect!("a == ':' || a == '+' || a == '-' || a == 'z' || a == 'Z'", true)
                                                                                            (skipTSDigits(2));
    if (afterOffsetMM != ':') {
        // skipped yyyy-mm-ddThh:mmZ
        ubyte afterOffset = skipTSOffsetOrZ(afterOffsetMM);
        return skipTSFinish(afterOffset);
    }
    // YYYY-MM-DDT[0-9][0-9]:[0-9][0-9]:[0-9][0-9]('.')?
    ubyte afterOffsetSS = skipTSDigits(2);
    if (afterOffsetSS != '.') {
        ubyte afterOffset = skipTSOffsetOrZ(afterOffsetSS);
        return skipTSFinish(afterOffset); 
    }

    // YYYY-MM-DDT[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9]*
    ubyte offsetNS = t.readInput();
    if (isDigit(offsetNS)) {
        offsetNS = skipDigits!T(t, offsetNS);
    }

    // YYYY-MM-DDT[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9]*('+' || '-' || 'z' || 'Z')([0-9][0-9]:[0-9][0-9])?
    ubyte afterOffsetNS = skipTSOffsetOrZ(offsetNS);
    return skipTSFinish(afterOffsetNS);  
}
/// Test skipping over timestamps
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    import mir.ion.deser.text.tokens : MirIonTokenizerException;

    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipTimestamp() == result);
    }

    void testFail(string ts) {
        import std.exception : assertThrown;
        auto t = tokenizeString(ts);
        assertThrown!MirIonTokenizerException(t.skipTimestamp());
    }

    test("2001T", 0);
    test("2001-01T,", ',');
    test("2001-01-02}", '}');
    test("2001-01-02T ", ' ');
    test("2001-01-02T+00:00\t", '\t');
    test("2001-01-02T-00:00\n", '\n');
    test("2001-01-02T03:04+00:00 ", ' ');
    test("2001-01-02T03:04-00:00 ", ' ');
    test("2001-01-02T03:04Z ", ' ');
    test("2001-01-02T03:04z ", ' ');
    test("2001-01-02T03:04:05Z ", ' ');
    test("2001-01-02T03:04:05+00:00 ", ' ');
    test("2001-01-02T03:04:05.666Z ", ' ');
    test("2001-01-02T03:04:05.666666z ", ' ');

    testFail(""); 
    testFail("2001");
    testFail("2001z");
    testFail("20011");
    testFail("2001-0");
    testFail("2001-01");
    testFail("2001-01-02Tz");
    testFail("2001-01-02T03");
    testFail("2001-01-02T03z");
    testFail("2001-01-02T03:04x ");
    testFail("2001-01-02T03:04:05x ");
}

/++
Skip over a symbol.
Params:
    t = The tokenizer
Returns:
    A character located after the symbol skipped.
+/
ubyte skipSymbol(T)(ref T t) @safe @nogc pure 
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte c = t.readInput();
    while (isIdentifierPart(c)) { 
        c = t.readInput();
    }

    return c;
}
/// Test skipping over symbols
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;

    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipSymbol() == result);
    }

    test("f", 0);
    test("foo:", ':');
    test("foo,", ',');
    test("foo ", ' ');
    test("foo\n", '\n');
    test("foo]", ']');
    test("foo}", '}');
    test("foo)", ')');
    test("foo\\n", '\\');
}

/++
Skip over a quoted symbol, but do not read the character after.
Params:
    t = The tokenizer
+/
void skipSymbolQuotedInternal(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte c;
    while (true) {
        c = t.expect!"a != 0 && a != '\\n'";
        switch (c) {
            case '\'':
                return;
            case '\\':
                t.expect!"a != 0";
                break;
            default:
                break;
        }
    }
}

/++
Skip over a quoted symbol
Params:
    t = The tokenizer
Returns:
    A character located after the quoted symbol skipped.
+/
ubyte skipSymbolQuoted(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    t.skipSymbolQuotedInternal();
    return t.readInput();  
}
/// Test skipping over quoted symbols
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    import mir.ion.deser.text.tokens : MirIonTokenizerException;

    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipSymbolQuoted() == result);
    }

    void testFail(string ts) {
        import std.exception : assertThrown;
        auto t = tokenizeString(ts);
        assertThrown!MirIonTokenizerException(t.skipSymbolQuoted());
    }

    test("'", 0);
    test("foo',", ',');
    test("foo\\'bar':", ':');
    test("foo\\\nbar',", ',');
    testFail("foo");
    testFail("foo\n");
}

/++
Skip over a symbol operator.
Params:
    t = The tokenizer
Returns:
    A character located after the symbol operator skipped.
+/
ubyte skipSymbolOperator(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte c = t.readInput();

    while (isOperatorChar(c)) {
        c = t.readInput();
    }
    return c; 
}
/// Test skipping over symbol operators
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;

    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipSymbolOperator() == result);
    }

    test("+", 0);
    test("++", 0);
    test("+= ", ' ');
    test("%b", 'b');
}

/++
Skip over a string, but do not read the character following it.
Params:
    t = The tokenizer
+/
void skipStringInternal(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte c;
    while (true) {
        c = t.expect!("a != 0 && a != '\\n'");
        switch (c) {
            case '"':
                return;
            case '\\':
                t.expect!"a != 0";
                break;
            default:
                break;
        }
    }
}

/++
Skip over a string.
Params:
    t = The tokenizer
Returns:
    A character located after the string skipped.
+/
ubyte skipString(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    t.skipStringInternal();
    return t.readInput();  
}
/// Test skipping over strings
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
    import mir.ion.deser.text.tokens : MirIonTokenizerException;
 
    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipString() == result);
    }

    void testFail(string ts) {
        import std.exception : assertThrown;
        auto t = tokenizeString(ts);
        assertThrown!MirIonTokenizerException(t.skipString());
    }

    test("\"", 0);
    test("\",", ',');
    test("foo\\\"bar\"], \"\"", ']');
    test("foo\\\nbar\" \t\t\t", ' ');

    testFail("foobar");
    testFail("foobar\n"); 
}

/++
Skip over a long string, but do not read the character following it.
Params:
    t = The tokenizer
+/
void skipLongStringInternal(T, bool skipComments = true, bool failOnComment = false)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T) && __traits(compiles, { t.skipWhitespace!(skipComments, failOnComment); })) {
    ubyte c;
    while (true) {
        c = t.expect!("a != 0");
        switch (c) {
            case '\'':
                if(skipLongStringEnd!(T, skipComments, failOnComment)(t)) {
                    return;
                }
                break;
            case '\\':
                t.expect!("a != 0");
                break;
            default:
                break;
        }
    }
}

/++
Skip over the end of a long string (`'''``)
Params:
    t = The tokenizer
Returns:
    true if it was able to skip over the end of the long string.
+/
bool skipLongStringEnd(T, bool skipComments = true, bool failOnComment = false)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T) && __traits(compiles, { t.skipWhitespace!(skipComments, failOnComment); })) {
    auto cs = t.peekMax(2);
    if (cs.length < 2 || cs[0] != '\'' || cs[1] != '\'') {
        return false;
    }

    t.skipExactly(2);
    ubyte c = t.skipWhitespace!(skipComments, failOnComment);
    if (c == '\'') {
        if (t.isTripleQuote()) {
            return false;
        }
    }

    t.unread(c);
    return true;
}

/++
Skip over a long string (marked by `'''`)
Params:
    t = The tokenizer
Returns:
    A character located after the long string skipped.
+/
ubyte skipLongString(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    skipLongStringInternal!(T, true, false)(t);
    return t.readInput();
}
/// Test skipping over long strings
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;

    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipLongString() == result);
    }
}

/++
Skip over a blob.
Params:
    t = The tokenizer
Returns:
    A character located after the blob skipped.
+/
ubyte skipBlob(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    t.skipBlobInternal();
    return t.readInput();  
}
/// Test skipping over blobs
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;

    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipBlob() == result);
    } 

    test("}}", 0);
    test("oogboog}},{{}}", ',');
    test("'''not encoded'''}}\n", '\n');
}

/++
Skip over a blob, but do not read the character following it.
Params:
    t = The tokenizer
+/
void skipBlobInternal(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte c = t.skipLobWhitespace();
    while (c != '}') {
        c = t.skipLobWhitespace();
        t.expect!("a != 0", true)(c);
    }

    t.expect!("a == '}'");

    return;
}

/++
Skip over a struct.
Params:
    t = The tokenizer
Returns:
    A character located after the struct skipped.
+/
ubyte skipStruct(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    return skipContainer!T(t, '}');
}
/// Test skipping over structs
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
 
    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipStruct() == result);
    }

    test("},", ',');
    test("[\"foo bar baz\"]},", ',');
    test("{}},{}", ','); // skip over an embedded struct inside of a struct
}

/++
Skip over a struct, but do not read the character following it.
Params:
    t = The tokenizer
+/
void skipStructInternal(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    skipContainerInternal!T(t, '}');
    return;
}

/++
Skip over a S-expression.
Params:
    t = The tokenizer
Returns:
    A character located after the S-expression skipped.
+/
ubyte skipSexp(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    return skipContainer!T(t, ')');
}
/// Test skipping over S-expressions
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
 
    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipSexp() == result);
    }

    test("1231 + 1123),", ',');
    test("0xF00DBAD)", 0);
}

/++
Skip over a S-expression, but do not read the character following it.
Params:
    t = The tokenizer
+/
void skipSexpInternal(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    skipContainerInternal!T(t, ')');
    return;
}

/++
Skip over a list.
Params:
    t = The tokenizer
Returns:
    A character located after the list skipped.
+/
ubyte skipList(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    return skipContainer!T(t, ']'); 
}
/// Test skipping over lists
version(mir_ion_parser_test) unittest
{
    import mir.ion.deser.text.tokenizer : tokenizeString;
 
    void test(string ts, ubyte result) {
        auto t = tokenizeString(ts);
        assert(t.skipList() == result);
    }

    test("\"foo\", \"bar\", \"baz\"],", ',');
    test("\"foobar\"]", 0);
}

/++
Skip over a list, but do not read the character following it.
Params:
    t = The tokenizer
+/
void skipListInternal(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    skipContainerInternal!T(t, ']');
    return;
}

/++
Skip over the current token.
Params:
    t = The tokenizer
Returns:
    A non-whitespace character following the current token.
+/
ubyte skipValue(T)(ref T t) @safe @nogc pure  
if (isInstanceOf!(IonTokenizer, T)) {
    ubyte ret;
    with(IonTokenType) switch(t.currentToken) {
        case TokenNumber:
            ret = t.skipNumber();
            break;
        case TokenBinary:
            ret = t.skipBinary();
            break;
        case TokenHex:
            ret = t.skipHex();
            break;
        case TokenTimestamp:
            ret = t.skipTimestamp();
            break;
        case TokenSymbol:
            ret = t.skipSymbol();
            break;
        case TokenSymbolQuoted:
            ret = t.skipSymbolQuoted();
            break;
        case TokenSymbolOperator:
            ret = t.skipSymbolOperator();
            break;
        case TokenString:
            ret = t.skipString();
            break;
        case TokenLongString:
            ret = t.skipLongString();
            break;
        case TokenOpenDoubleBrace:
            ret = t.skipBlob();
            break;
        case TokenOpenBrace:
            ret = t.skipStruct();
            break;
        case TokenOpenParen:
            ret = t.skipSexp();
            break;
        case TokenOpenBracket:
            ret = t.skipList();
            break;
        default:
            assert(0, "unhandled token");
    }

    if (ret.isWhitespace()) {
        ret = t.skipWhitespace();
    }

    t.finished = true;
    return ret;
}