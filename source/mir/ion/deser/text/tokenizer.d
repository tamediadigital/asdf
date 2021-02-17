module mir.ion.deser.text.tokenizer;
import mir.ion.deser.text.tokens;
import mir.ion.internal.data_holder : IonTapeHolder;
import std.range;
import std.stdio : writeln;

/++
    Implement a tokenizer similar to how Ion-Go handles tokenization
+/
import std.traits : Unqual;
template isValidTokenizerInput(T) {
    const isValidElementType = is(Unqual!(ElementType!(T)) == ubyte);
    const isValidTokenizerInput = isValidElementType && isInputRange!(T);
}

struct IonTokenizer(Allocator, Input) 
if (isValidTokenizerInput!(Input)) {
    Allocator* allocator;
    Input input;
    enum TAPE_HOLDER_MAX = 4096;
    enum TAPE_HOLDER_VAL = TAPE_HOLDER_MAX * 8;
    IonTapeHolder!(TAPE_HOLDER_VAL) tapeHolder;
    
    enum bool chunked = is(Input: const(char)[]);
    inputType[] buffer;

    alias inputType = Unqual!(ElementType!(Input));
    bool finished;
    size_t position;
    IonTokenType currentToken;

    this(ref Allocator allocator, Input input) {
        this.allocator = &allocator;   
        this.input = input;
        this.tapeHolder = IonTapeHolder!(TAPE_HOLDER_VAL)(TAPE_HOLDER_VAL);
    }

    void unread(inputType c) {
        if (this.position <= 0) {
            throw new MirIonTokenizerException("Cannot unread when at position >= 0");
        }

        this.position--;
        this.buffer ~= c; 
    }

    inputType popFromPeekBuffer() 
    in {
        assert(this.buffer.length != 0, "Cannot pop from empty peek buffer");
    } body {
        inputType c = this.buffer[$ - 1];
        this.buffer = this.buffer.dropBack(1);
        return c; 
    }

    bool skipOne() {
        inputType c = readInput();
        if (c == 0) {
            return false;
        }
        return true;
    }

    /++
    Skip exactly n input characters from the input range
    Note:
        This function only returns true if it was able to skip *the entire amount specified*
    Params:
        n = Number of characters to skip
    Returns:
        bool
    +/
    bool skipExactly(int n) {
        for (int i = 0; i < n; i++) {
            if (!skipOne()) { 
                return false;
            }
        }
        return true;
    }

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
            if (this.input.empty) {
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

    bool skipSingleLineComment() {
        while (true) {
            auto c = readInput();
            if (c == '\n' || c == 0) {
                return true;
            }
        }
    }

    bool skipBlockComment() {
        bool foundStar = false;
        while (true) {
            auto c = readInput();
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

    bool skipComment() {
        if (this.input.empty) {
            return false;
        }
        auto c = peekOne();
        switch(c) {
            case '/':
                return skipSingleLineComment();
            case '*':
                return skipBlockComment();
            default:
                break;
        }

        return false;
    }

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
                        if (skipComment()) 
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

    inputType skipLobWhitespace() {
        return skipWhitespace!(false, false);
    }

    bool isInf(inputType c) {
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

    void ok(IonTokenType token, bool finished) {
        this.currentToken = token;
        this.finished = finished;
    }

    bool nextToken() {
        inputType c;
        if (this.finished) {
            assert(false, "Stub");
        } else {
            c = skipWhitespace();
        }
        
        with(IonTokenType) tokens: switch(c) {
            case 0:
                ok(TokenEOF, true);
                break;
            case ':':
                break;
            case '{': 
                break;
            case '}':
                break;
            case '[':
                break;
            case ']':
                break;
            case '(':
                break;
            case ')':
                break;
            case ',':
                break;
            case '.':
                break;
            case '\'':
                break;
            case '+':
                break;
            case '-':
                break;
           static foreach(member; ION_OPERATOR_CHARS) {
                static if (member != '+' && member != '-' && member != '"' && member != '.') {
                    case member:
                        unread(c);
                        ok(TokenSymbolOperator, true);
                        return true;
                }
            }
            case '"':
                break;
            static foreach(member; ION_IDENTIFIER_START_CHARS) {
                case member:
                    unread(c);
                    ok(TokenSymbol, true);
                    return true;
            } 
            static foreach(member; ION_DIGITS) {
                case member:

                    break tokens;
            }

            default:
                break;
        }

        return true;

    }

}

import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.showcase;
auto tokenizeString(string input) {
    StackFront!(1024, Mallocator) allocator;
    IonTokenizer!(typeof(allocator), const(ubyte)[]) tokenizer = 
        IonTokenizer!(typeof(allocator), const(ubyte)[])(allocator, cast(ubyte[])input);

    return tokenizer;
}

auto tokenize(Input)(Input input) 
if (isValidTokenizerInput!(Input)) {
    StackFront!(1024, Mallocator) allocator;
    IonTokenizer!(typeof(allocator), Input) tokenizer = 
        IonTokenizer!(typeof(allocator), Input)(allocator, input);
}

version(mir_ion_parser_test):

import unit_threaded;

template testRead(T) {
    void testRead(ref T t, ubyte expected) {
        t.readInput().shouldEqual(expected);
    }
} 

template testPeek(T) {
    void testPeek(ref T t, ubyte expected) {
        t.peekOne().shouldEqual(expected);
    }
}

///
@("Test peekExactly()") unittest
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

///
@("Test peekOne()") unittest
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

///
@("Test read()/unread()") unittest
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

///
@("Test skipping of an invalid comment") unittest
{
    auto t = tokenizeString("this is a string that never ends");
    t.skipBlockComment().shouldEqual(false);
}

///
@("Test skipping of a block comment") unittest
{
    auto t = tokenizeString("this is/ a\nmulti-line /** comment.**/ok");
    t.skipBlockComment().shouldEqual(true);

    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}

@("Test skipping of a single-line comment") unittest 
{
    auto t = tokenizeString("single-line comment\r\nok");
    t.skipSingleLineComment().shouldEqual(true);

    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}

@("Test skipping of a single-line comment on the last line") unittest
{
    auto t = tokenizeString("single-line comment");
    t.skipSingleLineComment().shouldEqual(true);
}

@("Test different skipping methods (single-line)") unittest
{
    auto t = tokenizeString("/comment\nok");
    t.skipComment().shouldEqual(true);
    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}

@("Test different skipping methods (block)") unittest
{
    auto t = tokenizeString("*comm\nent*/ok");
    t.skipComment().shouldEqual(true);
    t.testRead('o');
    t.testRead('k');
    t.testRead(0);
}

@("Test different skipping methods (false-alarm)") unittest
{
    auto t = tokenizeString(" 0)");
    t.skipComment().shouldEqual(false);
    t.testRead(' ');
    t.testRead('0');
    t.testRead(')');
    t.testRead(0);
}

@("Test skipping whitespace") unittest
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

@("Test skipping lob whitespace") unittest
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

@("Test scanning for inf") unittest
{
    void test(string txt, bool inf, ubyte after) {
        auto t = tokenizeString(txt);
        auto c = t.readInput();
        t.isInf(c).shouldEqual(inf);
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