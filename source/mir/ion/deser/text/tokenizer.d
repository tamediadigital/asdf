/++
    Tokenizer to split up the contents of an Ion Text file into tokens
+/
module mir.ion.deser.text.tokenizer;
import mir.ion.deser.text.readers;
import mir.ion.deser.text.skippers;
import mir.ion.deser.text.tokens;
import mir.ion.internal.data_holder : IonTapeHolder;
import std.range;
import std.traits : Unqual;

/++
    Check to verify that a range meets the specifications (no UTF support, ATM)
+/
template isValidTokenizerInput(T) {
    const isValidElementType = is(Unqual!(ElementType!(T)) == ubyte);
    const isValidTokenizerInput = isValidElementType && isInputRange!(T);
}

/++
    Create a tokenizer for a given string.
    Params:
        input = String to tokenize
    Returns:
        [IonTokenizer]
+/
IonTokenizer!(ubyte[]) tokenizeString(string input) {
    return tokenize!(ubyte[])(cast(ubyte[])input);
}

/++
    Create a tokenizer for a given range.
    Params:
        input = Range to tokenize
    Returns:
        [IonTokenizer]
+/
IonTokenizer!(Input) tokenize(Input)(Input input) 
if (isValidTokenizerInput!(Input)) {
    IonTokenizer!(Input) tokenizer = IonTokenizer!(Input)(input);
    return tokenizer;
}

/++
    Tokenizer based off of how ion-go handles tokenization
+/
struct IonTokenizer(Input) 
if (isValidTokenizerInput!(Input)) {
    /++ Our input range that we read from +/
    Input input;
//    enum TAPE_HOLDER_MAX = 4096;
//    enum TAPE_HOLDER_VAL = TAPE_HOLDER_MAX * 8;
//    IonTapeHolder!(TAPE_HOLDER_VAL) tapeHolder;

    /++ The raw input type that reading an element from our range will return (typically `ubyte`) +/
    alias inputType = Unqual!(ElementType!(Input));

    /++ Peek buffer (to support look-ahead) +/
    inputType[] buffer;

    /++ Bool specifying if we want to read through the contents of the current token +/
    bool finished;

    /++ Current position within our input range +/
    size_t position;

    /++ Current token that we're located on +/
    IonTokenType currentToken;

    /++ 
        Constructor
        Params:
            input = The input range to read over 
    +/
    this(Input input) {
        this.input = input;
//        this.tapeHolder = IonTapeHolder!(TAPE_HOLDER_VAL)(TAPE_HOLDER_VAL);
    }

    /++ 
        Unread a given character and append it to the peek buffer 
        Params:
            c = Character to append to the top of the peek buffer.
    +/
    void unread(inputType c) {
        if (this.position <= 0) {
            throw new MirIonTokenizerException("Cannot unread when at position >= 0");
        }

        this.position--;
        this.buffer ~= c; 
    }
    ///
    version(mir_ion_parser_test) @("Test read()/unread()") unittest
    {
        auto t = tokenizeString("abc\rd\ne\r\n");

        t.testRead('a');
        t.unread('a');

        t.testRead('a');
        t.testRead('b');
        t.testRead('c');
        t.unread('c');
        t.unread('b');

        t.testRead('b');
        t.testRead('c');
        t.testRead('\n');
        t.unread('\n');

        t.testRead('\n');
        t.testRead('d');
        t.testRead('\n');
        t.testRead('e');
        t.testRead('\n');
        t.testRead(0); // test EOF

        t.unread(0); // unread EOF
        t.unread('\n');

        t.testRead('\n');
        t.testRead(0); // test EOF
        t.testRead(0); // test EOF
    }

    /++ 
        Pop the top-most character off of the peek buffer, and return it 
        Returns:
            a character representing the top-most character on the peek buffer.
    +/
    inputType popFromPeekBuffer() 
    in {
        assert(this.buffer.length != 0, "Cannot pop from empty peek buffer");
    } body {
        inputType c = this.buffer[$ - 1];
        this.buffer = this.buffer.dropBack(1);
        return c; 
    }

    /++ 
        Skip a single character within our input range, and discard it 
        Returns:
            true if it was able to skip a single character

            false if it was unable (due to hitting an EOF or the like)
    +/
    bool skipOne() {
        const inputType c = readInput();
        if (c == 0) {
            return false;
        }
        return true;
    }

    /++
    Skip exactly n input characters from the input range

    $(NOTE
        This function will only return true IF it is able to skip *the entire amount specified*)
    Params:
        n = Number of characters to skip
    Returns:
        true if skipped the entire range,
        false if unable to skip the full range specified.
    +/
    bool skipExactly(int n) {
        for (int i = 0; i < n; i++) {
            if (!skipOne()) { 
                return false;
            }
        }
        return true;
    }

    /++
    Read ahead at most n characters from the input range without discarding them.

    $(NOTE
        This function does not require n characters to be present.
        If it encounters an EOF, it will simply return a shorter range.)
    Params:
        n = Max number of characters to peek
    Returns:
        Array of peeked characters
    +/
    inputType[] peekMax(int n) {
        inputType[] ret;
        for (auto i = 0; i < n; i++) {
            inputType c = readInput();
            if (c == 0) {
                break;
            }
            ret ~= c;
        }

        foreach_reverse(c; ret) { 
            unread(c);
        }
        return ret;
    }

    /++
    Read ahead exactly n characters from the input range without discarding them.

    $(NOTE
        This function will throw if all n characters are not present.
        If you would like to peek as many as possible, use [peekMax] instead.)
    Params:
        n = Number of characters to peek
    Returns:
        An array filled with n characters.
    Throws:
        [MirIonTokenizerException]
    +/
    inputType[] peekExactly(int n) {
        inputType[] ret;
        bool hitEOF;
        for (auto i = 0; i < n; i++) {
            inputType c = readInput();
            if (c == 0) {
                hitEOF = true;
                break;
            }
            ret ~= c;
        }

        foreach_reverse(c; ret) { 
            unread(c);
        }

        if (hitEOF) {
            throw new MirIonTokenizerException("EOF");
        }

        return ret;
    }
    ///
    version(mir_ion_parser_test) @("Test peekExactly()") unittest
    {
        auto t = tokenizeString("abc\r\ndef");
        
        t.peekExactly(1).shouldEqual("a");
        t.peekExactly(2).shouldEqual("ab");
        t.peekExactly(3).shouldEqual("abc");

        t.testRead('a');
        t.testRead('b');
        
        t.peekExactly(3).shouldEqual("c\nd");
        t.peekExactly(2).shouldEqual("c\n");
        t.peekExactly(3).shouldEqual("c\nd");

        t.testRead('c');
        t.testRead('\n');
        t.testRead('d');

        t.peekExactly(3).shouldEqual("ef").shouldThrow();
        t.peekExactly(3).shouldEqual("ef").shouldThrow();
        t.peekExactly(2).shouldEqual("ef");

        t.testRead('e');
        t.testRead('f');
        t.testRead(0);

        t.peekExactly(10).shouldThrow();
    }

    /++
    Read ahead one character from the input range without discarding it.

    $(NOTE
        This function will throw if it cannot read one character ahead.
        Use [peekMax] if you want to read without throwing.)
    Returns:
        A single character read ahead from the input range.
    Throws:
        [MirIonTokenizerException]
    +/
    inputType peekOne() {
        if (this.buffer.length != 0) {
            return this.buffer[$ - 1];
        }

        if (this.input.empty) {
            throw new MirIonTokenizerException("EOF");
        }

        inputType c;
        c = readInput();
        unread(c);
        
        return c;
    }
    ///
    version(mir_ion_parser_test) @("Test peekOne()") unittest
    {
        auto t = tokenizeString("abc");

        t.testPeek('a');
        t.testPeek('a');
        t.testRead('a');

        t.testPeek('b');
        t.unread('a');

        t.testPeek('a');
        t.testRead('a');
        t.testRead('b');
        t.testPeek('c');
        t.testPeek('c');
        t.testRead('c');
        
        t.peekOne().shouldEqual(0).shouldThrow();
        t.peekOne().shouldEqual(0).shouldThrow();
        t.readInput().shouldEqual(0);
    }

    /++
        Read a single character from the input range (or from the peek buffer, if it's not empty)

        $(NOTE `readInput` normalizes CRLF to a simple new-line.)
        Returns:
            a single character from the input range, or 0 if the EOF is encountered.
        Throws:
            [MirIonTokenizerException]
    +/
    inputType readInput() {
        this.position++;
        if (this.buffer.length != 0) {
            return popFromPeekBuffer();
        }

        if (this.input.empty) {
            return 0;
        }

        inputType c = this.input.front;
        this.input.popFront();

        if (c == '\r') {
            // Normalize EOFs
            if (this.input.empty) { // TODO: verify if this functionality is correct
                throw new MirIonTokenizerException("Could not normalize EOF");
            }
            auto cs = this.input.front;
            if (cs == '\n') {
                this.input.popFront();
            }
            return '\n';
        }

        return c;
    }
    ///
    version(mir_ion_parser_test) @("Test readInput()") unittest 
    {
        auto t = tokenizeString("abcdefghijklmopqrstuvwxyz1234567890");
        t.testRead('a');
        t.testRead('b');
        t.testRead('c');
        t.testRead('d');
        t.testRead('e');
        t.testRead('f');
        t.testRead('g');
        t.testRead('h');
        t.testRead('i');
    }
    ///
    version(mir_ion_parser_test) @("Test normalization of CRLF") unittest
    {
        auto t = tokenizeString("a\r\nb\r\nc\rd");
        t.testRead('a');
        t.testRead('\n');
        t.testRead('b');
        t.testRead('\n');
        t.testRead('c');
        t.testRead('\n');
        t.testRead('d');
        t.testRead(0);
    }

    /++
        Skip any whitespace that is present between our current token and the next valid token.

        Additionally, skip comments (or fail on comments).

        $(NOTE `skipComments` and `failOnComment` cannot both be true.)
        Returns:
            The character located directly after the whitespace.
        Throws:
            [MirIonTokenizerException]
    +/
    inputType skipWhitespace(bool skipComments = true, bool failOnComment = false)() 
    if (skipComments != failOnComment || (skipComments == false && skipComments == failOnComment)) { // just a sanity check, we cannot skip comments and also fail on comments -- it is one or another (fail or skip)
        while (true) {
            inputType c = readInput();
            sw: switch(c) {
                static foreach(member; ION_WHITESPACE) {
                    case member:
                        break sw;
                }
                
                case '/': {
                    static if (failOnComment) {
                        throw new MirIonTokenizerException("Comments are not allowed within this token.");
                    } else static if(skipComments) {
                        // Peek on the next letter, and check if it's a second slash / star
                        // This may fail if we read a comment and do not find the end (newline / '*/')
                        // Undetermined if I need to unread the last char if this happens?
                        if (this.skipComment()) 
                            break;
                        else
                            goto default;
                    } else {
                        return '/';
                    }
                }
                // If this is a non-whitespace character, unread it
                default:
                    return c;
            }
        }
        return 0;
    }
    ///
    version(mir_ion_parser_test) @("Test skipping whitespace") unittest
    {
        void test(string txt, ubyte expectedChar) {
            auto t = tokenizeString(txt);
            t.skipWhitespace().shouldEqual(expectedChar).shouldNotThrow();
        }

        test("/ 0)", '/');
        test("xyz_", 'x');
        test(" / 0)", '/');
        test(" xyz_", 'x');
        test(" \t\r\n / 0)", '/');
        test("\t\t  // comment\t\r\n\t\t  x", 'x');
        test(" \r\n /* comment *//* \r\n comment */x", 'x');
    }

    inputType skipLobWhitespace() {
        return skipWhitespace!(false, false);
    }
    ///
    version(mir_ion_parser_test) @("Test skipping lob whitespace") unittest
    {
        void test(string txt, ubyte expectedChar)() {
            auto t = tokenizeString(txt);
            t.skipLobWhitespace().shouldEqual(expectedChar).shouldNotThrow();
        }

        test!("///=", '/');
        test!("xyz_", 'x');
        test!(" ///=", '/');
        test!(" xyz_", 'x');
        test!("\r\n\t///=", '/');
        test!("\r\n\txyz_", 'x');
    }

    /++
        Check if the next characters within the input range are the special "infinity" type.

        Params:
            c = The last character read off of the stream (typically '+' or '-')
        Returns:
            true if it is the infinity type, false if it is not.
    +/
    bool isInfinity(inputType c) {
        if (c != '+' && c != '-') return false;

        inputType[] cs = peekMax(5);

        if (cs.length == 3 || (cs.length >= 3 && isStopChar(cs[3]))) {
            if (cs[0] == 'i' && cs[1] == 'n' && cs[2] == 'f') {
                skipExactly(3);
                return true;
            }
        }

        if ((cs.length > 3 && cs[3] == '/') && cs.length > 4 && (cs[4] == '/' || cs[4] == '*')) {
            skipExactly(3);
            return true;
        }

        return false;
    }
    ///
    version(mir_ion_parser_test) @("Test scanning for inf") unittest
    {
        void test(string txt, bool inf, ubyte after) {
            auto t = tokenizeString(txt);
            auto c = t.readInput();
            t.isInfinity(c).shouldEqual(inf);
            t.readInput().shouldEqual(after);
        }
        
        test("+inf", true, 0);
        test("-inf", true, 0);
        test("+inf ", true, ' ');
        test("-inf\t", true, '\t');
        test("-inf\n", true, '\n');
        test("+inf,", true, ',');
        test("-inf}", true, '}');
        test("+inf)", true, ')');
        test("-inf]", true, ']');
        test("+inf//", true, '/');
        test("+inf/*", true, '/');

        test("+inf/", false, 'i');
        test("-inf/0", false, 'i');
        test("+int", false, 'i');
        test("-iot", false, 'i');
        test("+unf", false, 'u');
        test("_inf", false, 'i');

        test("-in", false, 'i');
        test("+i", false, 'i');
        test("+", false, 0);
        test("-", false, 0);
    }

    /++
        Check if the current character selected is part of a triple quote (''')

        $(NOTE This function will not throw if an EOF is hit. It will simply return false.)
        Returns:
            true if the character is part of a triple quote,
            false if it is not.
    +/
    bool isTripleQuote() {
        inputType[] cs;
        try {
            cs = peekExactly(2);
        } catch (MirIonTokenizerException e) {
            return false;
        }

        if (cs[0] == '\'' && cs[1] == '\'') {
            skipExactly(2);
            return true;
        }
        return false;
    }

    /++
        Check if the current character selected is part of a whole number.

        If it is part of a whole number, then return the type of number (hex, binary, timestamp, number)
        Params:
            c = The last character read from the range
        Returns:
            the corresponding number type (or invalid)
    +/
    IonTokenType scanForNumber(inputType c) in {
        assert(isDigit(c), "Scan for number called with non-digit number");
    } body {
        inputType[] cs;
        try {
            cs = peekMax(4);
        } catch(MirIonTokenizerException e) {
            return IonTokenType.TokenInvalid;
        }

        if (c == '0' && cs.length > 0) {
            switch(cs[0]) {
                case 'b':
                case 'B':
                    return IonTokenType.TokenBinary;
                
                case 'x':
                case 'X':
                    return IonTokenType.TokenHex;
                
                default:
                    break;
            }
        }

        if (cs.length == 4) {
            foreach(i; 0 .. 3) {
                if (!isDigit(cs[i])) return IonTokenType.TokenNumber;
            }

            if (cs[3] == '-' || cs[3] == 'T') {
                return IonTokenType.TokenTimestamp;
            }
        }
        return IonTokenType.TokenNumber;

    }
    ///
    @("Test scanning for numbers") unittest
    {
        void test(string txt, IonTokenType expectedToken) {
            auto t = tokenizeString(txt);
            auto c = t.readInput();
            t.scanForNumber(c).shouldEqual(expectedToken);
        }

        test("0b0101", IonTokenType.TokenBinary);
        test("0B", IonTokenType.TokenBinary);
        test("0xABCD", IonTokenType.TokenHex);
        test("0X", IonTokenType.TokenHex);
        test("0000-00-00", IonTokenType.TokenTimestamp);
        test("0000T", IonTokenType.TokenTimestamp);

        test("0", IonTokenType.TokenNumber);
        test("1b0101", IonTokenType.TokenNumber);
        test("1B", IonTokenType.TokenNumber);
        test("1x0101", IonTokenType.TokenNumber);
        test("1X", IonTokenType.TokenNumber);
        test("1234", IonTokenType.TokenNumber);
        test("12345", IonTokenType.TokenNumber);
        test("1,23T", IonTokenType.TokenNumber);
        test("12,3T", IonTokenType.TokenNumber);
        test("123,T", IonTokenType.TokenNumber);
    }

    /++
        Set the current token, and if we want to go into the token.
        Params:
            token = The updated token type
            finished = Whether or not we want to go into the token (and parse it)
    +/
    void ok(IonTokenType token, bool finished) {
        this.currentToken = token;
        this.finished = finished;
    }

    /++
        Read the next token from the range.
        Returns:
            true if it was able to read a valid token from the range.
    +/
    bool nextToken() {
        inputType c;
        if (this.finished) {
            c = this.skipValue();
        } else {
            c = skipWhitespace();
        }

        bool inf;
        inputType cs;
        
        with(IonTokenType) switch(c) {
            case 0:
                ok(TokenEOF, true);
                break;
            case ':':
                cs = peekOne();
                if (cs == ':') {
                    auto val = readInput();
                    ok(TokenDoubleColon, false);
                } else {
                    ok(TokenColon, false);
                }
                return true;
            case '{': 
                cs = peekOne();
                if (cs == '{') {
                    auto val = readInput();
                    ok(TokenOpenDoubleBrace, true);
                } else {
                    ok(TokenOpenBrace, true);
                }
                return true;
            case '}':
                ok(TokenCloseBrace, false);
                return true;
            case '[':
                ok(TokenOpenBracket, true);
                return true;
            case ']':
                ok(TokenCloseBracket, true);
                return true;
            case '(':
                ok(TokenOpenParen, true);
                return true;
            case ')':
                ok(TokenCloseParen, true);
                return true;
            case ',':
                ok(TokenComma, false);
                return true;
            case '.':
                cs = peekOne();
                if (isOperatorChar(cs)) {
                    unread(cs);
                    ok(TokenSymbolOperator, true);
                    return true;
                }

                if (cs == ' ' || isIdentifierPart(cs)) {
                    unread(cs);
                }
                ok(TokenDot, false);
                return true;
            case '\'':
                if (isTripleQuote()) {
                    ok(TokenLongString, true);
                    return true;
                }
                ok(TokenSymbolQuoted, true);
                return true;
            case '+':
                inf = isInfinity(c);
                if (inf) {
                    ok(TokenFloatInf, false);
                    return true;
                }
                unread(c);
                ok(TokenSymbolOperator, true);
                return true;
            case '-':
                cs = peekOne();
                if (isDigit(cs)) {
                    auto num = readInput();
                    IonTokenType tokenType = scanForNumber(cs);
                    if (tokenType == TokenTimestamp) {
                        throw new MirIonTokenizerException("Cannot have negative timestamps");
                    }
                    unread(cs);
                    unread(c);
                    ok(tokenType, true);
                    return true;
                }

                inf = isInfinity(c);
                if (inf) {
                    ok(TokenFloatMinusInf, false);
                    return true;
                }
                unread(c);
                ok(TokenSymbolOperator, true);
                return true;
           static foreach(member; ION_OPERATOR_CHARS) {
                static if (member != '+' && member != '-' && member != '"' && member != '.') {
                    case member:
                        unread(c);
                        ok(TokenSymbolOperator, true);
                        return true;
                }
            }
            case '"':
                ok(TokenString, true);
                break;
            static foreach(member; ION_IDENTIFIER_START_CHARS) {
                case member:
                    unread(c);
                    ok(TokenSymbol, true);
                    return true;
            } 
            static foreach(member; ION_DIGITS) {
                case member:
                    IonTokenType t = scanForNumber(c);
                    unread(c);
                    ok(t, true);
                    return true;
            }

            default:
                throw new MirIonTokenizerException("Unexpected token " ~ cast(char)c);
        }

        return false;

    }

    /++
        Check if the given character is a "stop" character.

        Stop characters are typically terminators of objects, but here we overload and check if there's a comment after our character.
        Params:
            c = The last character read from the input range.
        Returns:
            true if the character is the "stop" character.
    +/
    bool isStopChar(inputType c) {
        if (mir.ion.deser.text.tokens.isStopChar(c)) { // make sure
            return true;
        }

        if (c == '/') {
            inputType c2 = peekOne();
            if (c2 == '/' || c2 == '*') {
                return true;
            }
        }

        return false;
    }

    /++
        Ensure that the next item in the range fulfills the predicate given.
        Params:
            pred = A predicate that the next character in the range must fulfill
        Throws:
            [MirIonTokenizerException] if the predicate is not fulfilled
    +/
    template expect(alias pred = "a") {
        import std.functional : unaryFun;
        void expect() {
            inputType c = readInput();
            if (!unaryFun!pred(c)) {
                throw new MirIonTokenizerException("Unexpected token " ~ cast(char)c);
            }
        }
    }
    ///
    version(mir_ion_parser_test) @("Test expect()") unittest
    {
        void testIsHex(string ts) {
            auto t = tokenizeString(ts);
            while (!t.input.empty) {
                t.expect!(isHexDigit).shouldNotThrow();
            }
        }

        void testFailHex(string ts) {
            auto t = tokenizeString(ts);
            while (!t.input.empty) {
                t.expect!(isHexDigit).shouldThrow();
            }
        }

        testIsHex("1231231231");
        testIsHex("BADBAB3");
        testIsHex("F00BAD");
        testIsHex("420");
        testIsHex("41414141");
        testIsHex("BADF00D");
        testIsHex("BaDf00D");
        testIsHex("badf00d");
        testIsHex("AbCdEf123");

        testFailHex("HIWORLT");
        testFailHex("Tst");
    }

}

version(mir_ion_parser_test):

import unit_threaded;

/++
    Generic helper to verify the functionality of the parsing code
+/
template testRead(T) {
    void testRead(ref T t, ubyte expected) {
        t.readInput().shouldEqual(expected);
    }
} 

/++
    Generic helper to verify the functionality of the parsing code
+/
template testPeek(T) {
    void testPeek(ref T t, ubyte expected) {
        t.peekOne().shouldEqual(expected);
    }
}