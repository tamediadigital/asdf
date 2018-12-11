/++
Json Parser

Copyright: Tamedia Digital, 2016-2017

Authors: Ilya Yaroshenko

License: MIT

Macros:
SUBMODULE = $(LINK2 asdf_$1.html, asdf.$1)
SUBREF = $(LINK2 asdf_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
+/
module asdf.jsonparser;

import asdf.asdf;
import asdf.outputarray;
import std.experimental.allocator.gc_allocator;
import std.meta;
import std.range.primitives;
import std.traits;
import std.typecons;


version(LDC)
{
    import ldc.attributes: optStrategy;
    enum minsize = optStrategy("minsize");

    static if (__traits(targetHasFeature, "sse4.2"))
    {
        import core.simd;
        import ldc.simd;
        import ldc.gccbuiltins_x86;
        pragma(msg, "Info: SSE4.2 instructions are used for ASDF.");
        version = SSE42;
    }
    else
    {
        pragma(msg, "Info: SSE4.2 instructions are not used for ASDF.");
    }
}
else
{
    enum minsize;
}

version(X86_64)
    version = X86_Any;
else
version(X86)
    version = X86_Any;

import std.experimental.allocator.gc_allocator;
static if (__VERSION__ < 2.080)
    private alias ASDFGCAllocator = shared GCAllocator;
else
    private alias ASDFGCAllocator = shared const GCAllocator;

/++
Parses json value
Params:
    chunks = input range composed of elements type of `const(ubyte)[]`.
        `chunks` can use the same buffer for each chunk.
    initLength = initial output buffer length. Minimum value is 32.
Returns:
    ASDF value
+/
Asdf parseJson(
    Flag!"includingNewLine" includingNewLine = Yes.includingNewLine,
    Flag!"spaces" spaces = Yes.spaces,
    Chunks)
    (Chunks chunks, size_t initLength = 32)
    if(is(ElementType!Chunks : const(ubyte)[]))
{
    import std.format: format;
    import std.conv: ConvException;
    enum assumeValid = false;
    ASDFGCAllocator allocator;
    auto parser = JsonParser!(includingNewLine, spaces, assumeValid, ASDFGCAllocator, Chunks)(allocator, chunks);
    if (parser.parse)
        throw new AsdfException(parser.lastError);
    return Asdf(parser.result);
}

///
unittest
{
    import std.range: chunks;
    auto text = cast(const ubyte[])`true `;
    auto ch = text.chunks(3);
    assert(ch.parseJson(32).data == [1]);
}


/++
Parses json value
Params:
    str = input string
    allocator = (optional) memory allocator
Returns:
    ASDF value
+/
Asdf parseJson(
    Flag!"includingNewLine" includingNewLine = Yes.includingNewLine,
    Flag!"spaces" spaces = Yes.spaces, 
    Flag!"assumeValid" assumeValid = No.assumeValid,
    Allocator,
    )
    (in char[] str, Allocator allocator)
{
    auto parser = JsonParser!(includingNewLine, spaces, assumeValid, Allocator, const(char)[])(allocator, str);
    if (parser.parse)
        throw new AsdfException(parser.lastError);
    return Asdf(parser.result);
}

/// ditto
Asdf parseJson(
    Flag!"includingNewLine" includingNewLine = Yes.includingNewLine,
    Flag!"spaces" spaces = Yes.spaces, 
    Flag!"assumeValid" assumeValid = No.assumeValid,
    )
    (in char[] str)
{
    import std.experimental.allocator;
    ASDFGCAllocator allocator;
    auto parser = JsonParser!(includingNewLine, spaces, assumeValid, ASDFGCAllocator, const(char)[])(allocator, str);
    if (parser.parse)
        throw new AsdfException(parser.lastError);
    return Asdf(parser.result);
}

///
unittest
{
    assert(`{"ak": {"sub": "subval"} }`.parseJson["ak", "sub"] == "subval");
}

deprecated("please remove the initBufferLength argument (latest)")
auto parseJsonByLine(
    Flag!"spaces" spaces = Yes.spaces,
    Input)
    (Input input, sizediff_t initBufferLength)
{
    return .parseJsonByLine!(spaces,  No.throwOnInvalidLines, Input)(input);
}

/++
Parses JSON value in each line from a Range of buffers.
Params:
    spaces = adds support for spaces beetwen json tokens. Default value is Yes.
    throwOnInvalidLines = throws an $(LREF AsdfException) on invalid lines if Yes and ignore invalid lines if No. Default value is No.
    input = input range composed of elements type of `const(ubyte)[]` or string / const(char)[].
        `chunks` can use the same buffer for each chunk.
Returns:
    Input range composed of ASDF values. Each value uses the same internal buffer.
+/
auto parseJsonByLine(
    Flag!"spaces" spaces = Yes.spaces,
    Flag!"throwOnInvalidLines" throwOnInvalidLines = No.throwOnInvalidLines,
    Input)
    (Input input)
{
    alias Parser = JsonParser!(false, cast(bool)spaces, false, ASDFGCAllocator, Input);
    struct ByLineValue
    {
        Parser parser;
        private bool _empty, _nextEmpty;

        void popFront()
        {
            for(;;)
            {
                assert(!empty);
                if(_nextEmpty)
                {
                    _empty = true;
                    return;
                }
                // parser.oa.shift = 0;
                parser.dataLength = 0;
                auto error = parser.parse;
                if(!error)
                {
                    auto t = parser.skipSpaces_;
                    if(t != '\n' && t != 0)
                    {
                        error = AsdfErrorCode.unexpectedValue;
                        parser._lastError = "expected new line or end of input";
                    }
                    else
                    if(t == 0)
                    {
                        _nextEmpty = true;
                        return;
                    }
                    else
                    {
                        parser.skipNewLine;
                        _nextEmpty = !parser.skipSpaces_;
                        return;
                    }
                }
                static if (throwOnInvalidLines)
                    throw new AsdfException(parser.lastError);
                else
                    parser.skipLine();
            }
        }

        auto front() @property
        {
            assert(!empty);
            return Asdf(parser.result);
        }

        bool empty()
        {
            return _empty;
        }
    }
    ByLineValue ret; 
    if(input.empty)
    {
        ret._empty = ret._nextEmpty = true;
    }
    else
    {
        ASDFGCAllocator allocator;
        ret = ByLineValue(Parser(allocator, input));
        ret.popFront;
    }
    return ret;
}

///
unittest
{
    import asdf.jsonparser;
    import std.range: chunks;
    auto text = cast(const ubyte[])"\t true \r\r\n false\t";
    auto values = text.chunks(3).parseJsonByLine;
    assert(values.front.data == [1]);
    values.popFront;
    assert(values.front.data == [2]);
    values.popFront;
    assert(values.empty);
}

///
unittest
{
    import std.conv;
    import std.algorithm : map;
    import std.range : array;
    string text =  "\t " ~ `{"key": "a"}` ~ "\r\r\n" ~ `{"key2": "b"}`;
    auto values = text.parseJsonByLine();
    assert( values.front["key"] == "a");
    values.popFront;
    assert( values.front["key2"] == "b");
    values.popFront;
}

version(LDC)
{
    public import ldc.intrinsics: _expect = llvm_expect;
}
else
{
    T _expect(T)(T val, T expected_val) if (__traits(isIntegral, T))
    {
        return val;
    }
}

enum AsdfErrorCode
{
    success,
    unexpectedEnd,
    unexpectedValue,
}

private __gshared immutable ubyte[256] parseFlags = [
 // 0 1 2 3 4 5 6 7   8 9 A B C D E F
    0,0,0,0,0,0,0,0,  0,6,2,0,0,6,0,0, // 0
    0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0, // 1
    7,1,0,1,1,1,1,1,  1,1,1,9,1,9,9,1, // 2
    9,9,9,9,9,9,9,9,  9,9,1,1,1,1,1,1, // 3

    1,1,1,1,1,9,1,1,  1,1,1,1,1,1,1,1, // 4
    1,1,1,1,1,1,1,1,  1,1,1,1,0,1,1,1, // 5
    1,1,1,1,1,9,1,1,  1,1,1,1,1,1,1,1, // 6
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1, // 7

    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,

    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,  1,1,1,1,1,1,1,1,
];

private __gshared immutable byte[256] uniFlags = [
 //  0  1  2  3  4  5  6  7    8  9  A  B  C  D  E  F
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 0
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 1
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 2
     0, 1, 2, 3, 4, 5, 6, 7,   8, 9,-1,-1,-1,-1,-1,-1, // 3

    -1,10,11,12,13,14,15,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 4
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 5
    -1,10,11,12,13,14,15,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 6
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1, // 7

    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,

    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,  -1,-1,-1,-1,-1,-1,-1,-1,
];


pragma(inline, true)
bool isPlainJsonCharacter()(size_t c)
{
    return (parseFlags[c] & 1) != 0;
}

pragma(inline, true)
bool isJsonWhitespace()(size_t c)
{
    return (parseFlags[c] & 2) != 0;
}

pragma(inline, true)
bool isJsonLineWhitespace()(size_t c)
{
    return (parseFlags[c] & 4) != 0;
}

pragma(inline, true)
bool isJsonNumber()(size_t c)
{
    return (parseFlags[c] & 8) != 0;
}

package auto assumePure(T)(T t)
    if (isFunctionPointer!T || isDelegate!T)
{
    enum attrs = functionAttributes!T | FunctionAttribute.pure_;
    return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

package auto callPure(alias fn,T...)(T args)
{
    auto fp = assumePure(&fn);
    return (*fp)(args);
}

/+
Fast picewise stack
+/
private struct Stack
{
    import core.stdc.stdlib: cmalloc = malloc, cfree = free;
    @disable this(this);

    struct Node
    {
        enum length = 32; // 2 power
        Node* prev;
        size_t* buff;
    }

    size_t[Node.length] buffer = void;
    size_t length = 0;
    Node node;

pure:

    void push()(size_t value)
    {
        version(LDC) 
            pragma(inline, true);
        immutable local = length++ & (Node.length - 1);
        if (local)
        {
            node.buff[local] = value;
        }
        else
        if (length == 1)
        {
            node = Node(null, buffer.ptr);
            buffer[0] = value;
        }
        else
        {
            auto prevNode = cast(Node*) callPure!cmalloc(Node.sizeof);
            *prevNode = node;
            node.prev = prevNode;
            node.buff = cast(size_t*) callPure!cmalloc(Node.length * size_t.sizeof);
            node.buff[0] = value;
        }
    }

    size_t top()()
    {
        version(LDC) 
            pragma(inline, true);
        assert(length);
        immutable local = (length - 1) & (Node.length - 1);
        return node.buff[local];
    }

    size_t pop()()
    {
        version(LDC) 
            pragma(inline, true);
        assert(length);
        immutable local = --length & (Node.length - 1);
        immutable ret = node.buff[local];
        if (local == 0)
        {
            if (node.buff != buffer.ptr)
            {
                callPure!cfree(node.buff);
                node = *node.prev;
            }
        }
        return ret;
    }

    pragma(inline, false)
    void free()()
    {
        version(LDC) 
            pragma(inline, true);
        if (node.buff is null)
            return;
        while(node.buff !is buffer.ptr)
        {
            callPure!cfree(node.buff);
            node = *node.prev;
        }
    }
}

unittest
{
    Stack stack;
    assert(stack.length == 0);
    foreach(i; 1 .. 100)
    {
        stack.push(i);
        assert(stack.length == i);
        assert(stack.top() == i);
    }
    foreach_reverse(i; 1 .. 100)
    {
        assert(stack.length == i);
        assert(stack.pop() == i);
    }
    assert(stack.length == 0);
}

///
struct JsonParser(bool includingNewLine, bool hasSpaces, bool assumeValid, Allocator, Input = const(ubyte)[])
{

    ubyte[] data;
    Allocator* allocator;
    Input input;
    static if (chunked)
        ubyte[] front;
    else
        alias front = input;
    size_t dataLength;

    string _lastError;

    enum bool chunked = !is(Input : const(char)[]);

    this(ref Allocator allocator, Input input) 

    {
        this.input = input;
        this.allocator = &allocator;
    }

    bool prepareInput_()()
    {
        static if (chunked)
        {
            if (front.length == 0)
            {
                assert(!input.empty);
                input.popFront;
                if (input.empty)
                    return false;
                front = cast(typeof(front)) input.front;
            }
        }
        return front.length != 0;
    }

    void skipNewLine()()
    {
        assert(front.length);
        assert(front[0] == '\n');
        front = front[1 .. $];
    }

    char skipSpaces_()()
    {
        static if (hasSpaces)
        for(;;)
        {
            if (prepareInput_ == false)
                return 0;
            static if (includingNewLine)
                alias isWhite = isJsonWhitespace;
            else
                alias isWhite = isJsonLineWhitespace;
            if (isWhite(front[0]))
            {
                front = front[1 .. $];
                continue;
            }
            return front[0];
        }
        else
        {
            if (prepareInput_ == false)
                return 0;
            return front[0];
        }
    }

    bool skipLine()()
    {
        for(;;)
        {
            if (_expect(!prepareInput_, false))
                return false;
            auto c = front[0];
            front = front[1 .. $];
            if (c == '\n')
                return true;
        }
    }

    auto result()()
    {
        return data[0 .. dataLength];
    }

    string lastError()() @property
    {
        return _lastError;
    }

    pragma(inline, false)
    AsdfErrorCode parse()
    {
        version(SSE42)
        {
            enum byte16 str2E = [
                '\u0001', '\u001F',
                '\"', '\"',
                '\\', '\\',
                '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0', '\0'];
            enum byte16 num2E = ['+', '-', '.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'e', 'E', '\0'];
            byte16 str2 = str2E;
            byte16 num2 = num2E;
        }

        const(ubyte)* strPtr;
        const(ubyte)* strEnd;
        ubyte* dataPtr;
        ubyte* stringAndNumberShift = void;
        static if (chunked)
        {
            bool prepareInput()()
            {
                pragma(inline, false);
                if(strPtr)
                {
                    input.popFront;
                    if (input.empty)
                    {
                        return false;
                    }
                }
                front = cast(typeof(front)) input.front;
                if (front.length == 0)
                    return false;
                strPtr = front.ptr;
                strEnd = front.ptr + front.length;
                const dataAddLength = front.length * 6;
                const dataLength = dataPtr - data.ptr;
                const dataRequiredLength = dataLength + dataAddLength;
                if (data.length < dataRequiredLength)
                {
                    const valueLength = stringAndNumberShift - dataPtr;
                    import std.algorithm.comparison: max;
                    const len = max(data.length * 2, dataRequiredLength);
                    static if (is(Unqual!Allocator == GCAllocator))
                    {
                        import core.memory: GC;
                        data = cast(ubyte[]) GC.realloc(data.ptr, len)[0 .. len];
                    }
                    else
                    {
                        allocator.reallocate(*cast(void[]*)&data, len);
                    }
                    dataPtr = data.ptr + dataLength;
                    stringAndNumberShift = dataPtr + valueLength;
                }
                return true;
            }
            strPtr = front.ptr;
            strEnd = front.ptr + front.length;
        }
        else
        {
            strPtr = cast(const(ubyte)*) input.ptr;
            strEnd = cast(const(ubyte)*) input.ptr + input.length;
            enum bool prepareInput = false;
        }

        auto rl = (strEnd - strPtr) * 6;
        if (data.ptr !is null && data.length < rl)
        {
            static if (is(Unqual!Allocator == GCAllocator))
            {
                import core.memory: GC;
                GC.free(data.ptr);
            }
            else
            {
                allocator.deallocate(data);
            }
            data = null;
        }
        if (data.ptr is null)
        {
            static if (is(Unqual!Allocator == GCAllocator))
            {
                import core.memory: GC;
                data = cast(ubyte[]) GC.malloc(rl)[0 .. rl];
            }
            else
            {
                data = cast(ubyte[])allocator.allocate(rl);
            }
        }
        dataPtr = data.ptr;

        bool skipSpaces()()
        {
            version(LDC)
                pragma(inline, true);
            static if (includingNewLine)
                alias isWhite = isJsonWhitespace;
            else
                alias isWhite = isJsonLineWhitespace;
            F:
            {
                if (_expect(strEnd != strPtr, true))
                {
                L:
                    static if (hasSpaces)
                    {
                        if (isWhite(strPtr[0]))
                        {
                            strPtr++;
                            goto F;
                        }
                    }
                    return true;
                }
                else
                {
                    if (prepareInput)
                        goto L;
                    return false;
                }
            }

        }

        @minsize
        int readUnicode()(ref dchar d)
        {
            version(LDC)
                pragma(inline, true);
            uint e = 0;
            size_t i = 4;
            do
            {
                if (strEnd == strPtr && !prepareInput)
                    return 1;
                int c = uniFlags[*strPtr++];
                assert(c < 16);
                if (c == -1)
                    return -1;
                assert(c >= 0);
                e <<= 4;
                e ^= c;
            }
            while(--i);
            d = e;
            return 0;
        }

        Stack stack;

        typeof(return) retCode;
        bool currIsKey = void;
        size_t stackValue = void;
        goto value;

/////////// RETURN
    ret:
        front = front[cast(typeof(front.ptr)) strPtr - front.ptr .. $];
        dataLength = dataPtr - data.ptr;
        assert(stack.length == 0);
    ret_final:
        return retCode;
///////////

    key:
        if (!skipSpaces)
            goto object_key_unexpectedEnd;
    key_start:
        if (*strPtr != '"')
            goto object_key_start_unexpectedValue;
        currIsKey = true;
        stringAndNumberShift = dataPtr;
        // reserve 1 byte for the length
        dataPtr += 1;
        goto string;
    next:
        if (stack.length == 0)
            goto ret;
        {
            if (!skipSpaces)
                goto next_unexpectedEnd;
            stackValue = stack.top;
            const isObject = stackValue & 1;
            auto v = *strPtr++;
            if (isObject)
            {
                if (v == ',')
                    goto key;
                if (v != '}')
                    goto next_unexpectedValue;
            }
            else
            {
                if (v == ',')
                    goto value;
                if (v != ']')
                    goto next_unexpectedValue;
            }
        }
    structure_end: {
        stackValue = stack.pop();
        const structureShift = stackValue >> 1;
        const structureLengthPtr = data.ptr + structureShift;
        const size_t structureLength = dataPtr - structureLengthPtr - 4;
        if (structureLength > uint.max)
            goto object_or_array_is_to_large;
        version(X86_Any)
            *cast(uint*) structureLengthPtr = cast(uint) structureLength;
        else
            *cast(ubyte[4]*) structureLengthPtr = cast(ubyte[4]) cast(uint[1]) [cast(uint) structureLength];
        goto next;
    }
    value:
        if (!skipSpaces)
            goto value_unexpectedEnd;
    value_start:
        switch(*strPtr)
        {
            stringValue:
            case '"':
                currIsKey = false;
                *dataPtr++ = Asdf.Kind.string;
                stringAndNumberShift = dataPtr;
                // reserve 4 byte for the length
                dataPtr += 4;
                goto string;
            case '-':
            case '0':
            ..
            case '9': {
                *dataPtr++ = Asdf.Kind.number;
                stringAndNumberShift = dataPtr;
                // reserve 1 byte for the length
                dataPtr++; // write the first character
                *dataPtr++ = *strPtr++;
                for(;;)
                {
                    if (strEnd == strPtr && !prepareInput)
                        goto number_found;
                    version(SSE42)
                    {
                        while (strEnd >= strPtr + 16)
                        {
                            byte16 str1 = loadUnaligned!ubyte16(cast(ubyte*)strPtr);
                            size_t ecx = __builtin_ia32_pcmpistri128(num2, str1, 0x10);
                            storeUnaligned!ubyte16(str1, dataPtr);
                            strPtr += ecx;
                            dataPtr += ecx;
                            if(ecx != 16)
                                goto number_found;
                        }
                    }
                    else
                    {
                        while(strEnd >= strPtr + 4)
                        {
                            char c0 = strPtr[0]; dataPtr += 4;     if (!isJsonNumber(c0)) goto number_found0;
                            char c1 = strPtr[1]; dataPtr[-4] = c0; if (!isJsonNumber(c1)) goto number_found1;
                            char c2 = strPtr[2]; dataPtr[-3] = c1; if (!isJsonNumber(c2)) goto number_found2;
                            char c3 = strPtr[3]; dataPtr[-2] = c2; if (!isJsonNumber(c3)) goto number_found3;
                            strPtr += 4;         dataPtr[-1] = c3;
                        }
                    }
                    while(strEnd > strPtr)
                    {
                        char c0 = strPtr[0]; if (!isJsonNumber(c0)) goto number_found; dataPtr[0] = c0;
                        strPtr += 1;
                        dataPtr += 1;
                    }
                }
            version(SSE42){} else
            {
                number_found3: dataPtr++; strPtr++;
                number_found2: dataPtr++; strPtr++;
                number_found1: dataPtr++; strPtr++;
                number_found0: dataPtr -= 4;
            }
            number_found:

                auto numberLength = dataPtr - stringAndNumberShift - 1;
                if (numberLength > ubyte.max)
                    goto number_length_unexpectedValue;
                *stringAndNumberShift = cast(ubyte) numberLength;
                goto next;
            }
            case '{':
                strPtr++;
                *dataPtr++ = Asdf.Kind.object;
                stack.push(((dataPtr - data.ptr) << 1) ^ 1);
                dataPtr += 4;
                if (!skipSpaces)
                    goto object_first_value_start_unexpectedEnd;
                if (*strPtr != '}')
                    goto key_start;
                strPtr++;
                goto structure_end;
            case '[':
                strPtr++;
                *dataPtr++ = Asdf.Kind.array;
                stack.push(((dataPtr - data.ptr) << 1) ^ 0);
                dataPtr += 4;
                if (!skipSpaces)
                    goto array_first_value_start_unexpectedEnd;
                if (*strPtr != ']')
                    goto value_start;
                strPtr++;
                goto structure_end;
            foreach (name; AliasSeq!("false", "null", "true"))
            {
            case name[0]:
                    if (_expect(strEnd - strPtr >= name.length, true))
                    {
                        static if (!assumeValid)
                        {
                            version(X86_Any)
                            {
                                enum uint referenceValue =
                                        (uint(name[$ - 4]) << 0x00) ^ 
                                        (uint(name[$ - 3]) << 0x08) ^ 
                                        (uint(name[$ - 2]) << 0x10) ^ 
                                        (uint(name[$ - 1]) << 0x18);
                                if (*cast(uint*)(strPtr + bool(name.length == 5)) != referenceValue)
                                {
                                    static if (name == "true")
                                        goto true_unexpectedValue;
                                    else
                                    static if (name == "false")
                                        goto false_unexpectedValue;
                                    else
                                        goto null_unexpectedValue;
                                }
                            }
                            else
                            {
                                char[name.length - 1] c = void;
                                import std.range: iota;
                                foreach (i; aliasSeqOf!(iota(1, name.length)))
                                    c[i - 1] = strPtr[i];
                                foreach (i; aliasSeqOf!(iota(1, name.length)))
                                {
                                    if (c[i - 1] != name[i])
                                    {
                                        
                                        static if (name == "true")
                                            goto true_unexpectedValue;
                                        else
                                        static if (name == "false")
                                            goto false_unexpectedValue;
                                        else
                                            goto null_unexpectedValue;
                                    }
                                }
                            }
                        }
                        static if (name == "null")
                            *dataPtr++ = Asdf.Kind.null_;
                        else
                        static if (name == "false")
                            *dataPtr++ = Asdf.Kind.false_;
                        else
                            *dataPtr++ = Asdf.Kind.true_;
                        strPtr += name.length;
                        goto next;
                    }
                    else
                    {
                        strPtr += 1;
                        foreach (i; 1 .. name.length)
                        {
                            if (strEnd == strPtr && !prepareInput)
                            {
                                static if (name == "true")
                                    goto true_unexpectedEnd;
                                else
                                static if (name == "false")
                                    goto false_unexpectedEnd;
                                else
                                    goto null_unexpectedEnd;
                            }
                            static if (!assumeValid)
                            {
                                if (_expect(strPtr[0] != name[i], false))
                                {
                                    static if (name == "true")
                                        goto true_unexpectedValue;
                                    else
                                    static if (name == "false")
                                        goto false_unexpectedValue;
                                    else
                                        goto null_unexpectedValue;
                                }
                            }
                            strPtr++;
                        }
                        static if (name == "null")
                            *dataPtr++ = Asdf.Kind.null_;
                        else
                        static if (name == "false")
                            *dataPtr++ = Asdf.Kind.false_;
                        else
                            *dataPtr++ = Asdf.Kind.true_;
                        goto next;
                    }
            }

            default :
                import std.conv;
                assert(0, strPtr[0].to!string);
        }

    string:
        assert(*strPtr == '"');
        strPtr += 1;

    StringLoop: {
        for(;;)
        {
            if (strEnd == strPtr && !prepareInput)
                goto string_unexpectedEnd;
            version(SSE42)
            {
                while (strEnd >= strPtr + 16)
                {
                    byte16 str1 = loadUnaligned!ubyte16(cast(ubyte*)strPtr);
                    size_t ecx = __builtin_ia32_pcmpistri128(str2, str1, 0x04);
                    storeUnaligned!ubyte16(str1, dataPtr);
                    strPtr += ecx;
                    dataPtr += ecx;
                    if(ecx != 16)
                        goto string_found;
                }
            }
            else
            {
                while(strEnd >= strPtr + 4)
                {
                    char c0 = strPtr[0]; dataPtr += 4;     if (!isPlainJsonCharacter(c0)) goto string_found0;
                    char c1 = strPtr[1]; dataPtr[-4] = c0; if (!isPlainJsonCharacter(c1)) goto string_found1;
                    char c2 = strPtr[2]; dataPtr[-3] = c1; if (!isPlainJsonCharacter(c2)) goto string_found2;
                    char c3 = strPtr[3]; dataPtr[-2] = c2; if (!isPlainJsonCharacter(c3)) goto string_found3;
                    strPtr += 4;         dataPtr[-1] = c3;
                }
            }
            while(strEnd > strPtr)
            {
                char c0 = strPtr[0]; if (!isPlainJsonCharacter(c0)) goto string_found; dataPtr[0] = c0;
                strPtr += 1;
                dataPtr += 1;
            }
        }
        version(SSE42) {} else
        {
            string_found3: dataPtr++; strPtr++;
            string_found2: dataPtr++; strPtr++;
            string_found1: dataPtr++; strPtr++;
            string_found0: dataPtr -= 4;
        }
        string_found:

        uint c = strPtr[0];
        if (c == '\"')
        {
            strPtr += 1;
            if (currIsKey)
            {
                auto stringLength = dataPtr - stringAndNumberShift - 1;
                if (stringLength > ubyte.max)
                    goto key_is_to_large;
                *cast(ubyte*)stringAndNumberShift = cast(ubyte) stringLength;
                if (!skipSpaces)
                    goto failed_to_read_after_key;
                if (*strPtr != ':')
                    goto unexpected_character_after_key;
                strPtr++;
                goto value;
            }
            else
            {
                auto stringLength = dataPtr - stringAndNumberShift - 4;
                if (stringLength > uint.max)
                    goto string_length_is_too_large;
                version(X86_Any)
                    *cast(uint*)stringAndNumberShift = cast(uint) stringLength;
                else
                    *cast(ubyte[4]*)stringAndNumberShift = cast(ubyte[4]) cast(uint[1]) [cast(uint) stringLength];
                goto next;
            }
        }
        if (c == '\\')
        {
            strPtr += 1;
            if (strEnd == strPtr && !prepareInput)
                goto string_unexpectedEnd;
            c = *strPtr++;
            switch(c)
            {
                case '/' :
                case '\"':
                case '\\':
                    *dataPtr++ = cast(ubyte) c;
                    goto StringLoop;
                case 'b' : *dataPtr++ = '\b'; goto StringLoop;
                case 'f' : *dataPtr++ = '\f'; goto StringLoop;
                case 'n' : *dataPtr++ = '\n'; goto StringLoop;
                case 'r' : *dataPtr++ = '\r'; goto StringLoop;
                case 't' : *dataPtr++ = '\t'; goto StringLoop;
                case 'u' :
                    uint wur = void;
                    dchar d = void;
                    if (auto r = (readUnicode(d)))
                    {
                        if (r == 1)
                            goto string_unexpectedEnd;
                        goto string_unexpectedValue;
                    }
                    if (_expect(0xD800 <= d && d <= 0xDFFF, false))
                    {
                        if (d >= 0xDC00)
                            goto string_unexpectedValue;
                        if (strEnd == strPtr && !prepareInput)
                            goto string_unexpectedEnd;
                        if (*strPtr++ != '\\')
                            goto string_unexpectedValue;
                        if (strEnd == strPtr && !prepareInput)
                            goto string_unexpectedEnd;
                        if (*strPtr++ != 'u')
                            goto string_unexpectedValue;
                        d = (d & 0x3FF) << 10;
                        dchar trailing;
                        if (auto r = (readUnicode(trailing)))
                        {
                            if (r == 1)
                                goto string_unexpectedEnd;
                            goto string_unexpectedValue;
                        }
                        if (!(0xDC00 <= trailing && trailing <= 0xDFFF))
                            goto invalid_trail_surrogate;
                        {
                            d |= trailing & 0x3FF;
                            d += 0x10000;
                        }
                    }
                    if (!(d < 0xD800 || (d > 0xDFFF && d <= 0x10FFFF)))
                        goto invalid_utf_value;
                    encodeUTF8(d, dataPtr);
                    goto StringLoop;
                default: goto string_unexpectedValue;
            }
        }
        goto string_unexpectedValue;
    }

    ret_error:
        dataLength = dataPtr - data.ptr;
        stack.free();
        goto ret_final;
    unexpectedEnd:
        retCode = AsdfErrorCode.unexpectedEnd;
        goto ret_error;
    unexpectedValue:
        retCode = AsdfErrorCode.unexpectedValue;
        goto ret_error;
    object_key_unexpectedEnd:
        _lastError = "unexpected end of object key";
        goto unexpectedEnd;
    object_key_start_unexpectedValue:
        _lastError = "expected '\"' when when start parsing object key";
        goto unexpectedValue;
    key_is_to_large:
        _lastError = "key length is limited to 255 characters";
        goto unexpectedValue;
    object_or_array_is_to_large:
        _lastError = "object or array serialized size is limited to 2^32-1";
        goto unexpectedValue;
    next_unexpectedEnd:
        stackValue = stack.top;
        _lastError = (stackValue & 1) ? "unexpected end when parsing object" : "unexpected end when parsing array";
        goto unexpectedEnd;
    next_unexpectedValue:
        stackValue = stack.top;
        _lastError = (stackValue & 1) ? "expected ',' or `}` when parsing object" : "expected ',' or `]` when parsing array";
        goto unexpectedValue;
    value_unexpectedEnd:
        _lastError = "unexpected end when start parsing JSON value";
        goto unexpectedEnd;
    number_length_unexpectedValue:
        _lastError = "number length is limited to 255 characters";
        goto unexpectedValue;
    object_first_value_start_unexpectedEnd:
        _lastError = "unexpected end of input data after '{'";
        goto unexpectedEnd;
    array_first_value_start_unexpectedEnd:
        _lastError = "unexpected end of input data after '['";
        goto unexpectedEnd;
    false_unexpectedEnd:
        _lastError = "unexpected end when parsing 'false'";
        goto unexpectedEnd;
    false_unexpectedValue:
        _lastError = "unexpected character when parsing 'false'";
        goto unexpectedValue;
    null_unexpectedEnd:
        _lastError = "unexpected end when parsing 'null'";
        goto unexpectedEnd;
    null_unexpectedValue:
        _lastError = "unexpected character when parsing 'null'";
        goto unexpectedValue;
    true_unexpectedEnd:
        _lastError = "unexpected end when parsing 'true'";
        goto unexpectedEnd;
    true_unexpectedValue:
        _lastError = "unexpected character when parsing 'true'";
        goto unexpectedValue;
    string_unexpectedEnd:
        _lastError = "unexpected end when parsing string";
        goto unexpectedEnd;
    string_unexpectedValue:
        _lastError = "unexpected character when parsing string";
        goto unexpectedValue;
    failed_to_read_after_key:
        _lastError = "unexpected end after object key";
        goto unexpectedEnd;
    unexpected_character_after_key:
        _lastError = "unexpected character after key";
        goto unexpectedValue;
    string_length_is_too_large:
        _lastError = "string size is limited to 2^32-1";
        goto unexpectedValue;
    invalid_trail_surrogate:
        _lastError = "invalid UTF-16 trail surrogate";
        goto unexpectedValue;
    invalid_utf_value:
        _lastError = "invalid UTF value";
        goto unexpectedValue;
    }
}

unittest
{
    import std.conv;
    auto asdf_data = parseJson(` [ true, 123 , [ false, 123.0 , "123211" ], "3e23e" ] `);
    auto str = asdf_data.to!string;
    auto str2 = `[true,123,[false,123.0,"123211"],"3e23e"]`;
    assert( str == str2);
}

pragma(inline, true)
void encodeUTF8()(dchar c, ref ubyte* ptr)
{   
    if (c < 0x80)
    {
        ptr[0] = cast(ubyte) (c);
        ptr += 1;
    }
    else
    if (c < 0x800)
    {
        ptr[0] = cast(ubyte) (0xC0 | (c >> 6));
        ptr[1] = cast(ubyte) (0x80 | (c & 0x3F));
        ptr += 2;
    }
    else
    if (c < 0x10000)
    {
        ptr[0] = cast(ubyte) (0xE0 | (c >> 12));
        ptr[1] = cast(ubyte) (0x80 | ((c >> 6) & 0x3F));
        ptr[2] = cast(ubyte) (0x80 | (c & 0x3F));
        ptr += 3;
    }
    else
    {
    //    assert(c < 0x200000);
        ptr[0] = cast(ubyte) (0xF0 | (c >> 18));
        ptr[1] = cast(ubyte) (0x80 | ((c >> 12) & 0x3F));
        ptr[2] = cast(ubyte) (0x80 | ((c >> 6) & 0x3F));
        ptr[3] = cast(ubyte) (0x80 | (c & 0x3F));
        ptr += 4;
    }
}

unittest
{
    auto asdf = "[\"\u007F\"]".parseJson;
}

unittest
{
    auto f = `"\uD801\uDC37"`.parseJson;
    assert(f == "\"\U00010437\"".parseJson);
}

unittest
{
    import std.string;
    import std.range;
    static immutable str = `"1234567890qwertyuiopasdfghjklzxcvbnm"`;
    auto data = Asdf(str[1..$-1]);
    assert(data == parseJson(str));
    foreach(i; 1 .. str.length)
    {
        auto s  = parseJson(str.representation.chunks(i));
        assert(data == s);
    }
}

unittest
{
    import std.string;
    import std.range;
    static immutable str = `"\t\r\f\b\"\\\/\t\r\f\b\"\\\/\t\r\f\b\"\\\/\t\r\f\b\"\\\/"`;
    auto data = Asdf("\t\r\f\b\"\\/\t\r\f\b\"\\/\t\r\f\b\"\\/\t\r\f\b\"\\/");
    assert(data == parseJson(str));
    foreach(i; 1 .. str.length)
        assert(data == parseJson(str.representation.chunks(i)));
}

unittest
{
    import std.string;
    import std.range;
    static immutable str = `"\u0026"`;
    auto data = Asdf("&");
    assert(data == parseJson(str));
}

version(unittest) immutable string test_data =
q{{
  "coordinates": [
    {
      "x": 0.29811521136061625,
      "y": 0.47980763779335556,
      "z": 0.1704431616620138,
      "name": "tqxvsg 2780",
      "opts": {
        "1": [
          1,
          true
        ]
      }
    }
  ],
  "info": "some info"
}
};
