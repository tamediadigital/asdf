module mir.ion.internal.stage3;

import mir.utility: _expect;
import mir.primitives;
import mir.bitop;
import std.traits;
import std.meta: AliasSeq, aliasSeqOf;

version(LDC)
{
    import ldc.attributes: optStrategy;
    enum minsize = optStrategy("minsize");

    static if (__traits(targetHasFeature, "sse4.2"))
    {
        import core.simd;
        import ldc.simd;
        import ldc.gccbuiltins_x86;
        version = SSE42;
    }
}
else
{
    enum minsize;
}

enum TapeState : ubyte
{
    start,
    inNumber,
    inString,
    inArray,
    inObject,
}

struct TapeStack
{
    enum maxLength = 1024;
    size_t position = maxLength;
    uint[maxLength] tapeIndex = void;
    TapeState[maxLength] tapeState = void;
}

void stage3(
    size_t index,
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask1,
    scope ulong[2]* pairedMask2,
    scope ubyte* tape,
    ref TapeStack stack,
    )
{
    foreach (i; 0 .. n)
    {
        auto v = vector[i];
        size_t[4] m = pairedMask1[i] ~ pairedMask2[i];
        // foreach ()
        // {
            
        // }
    }
}

enum AsdfErrorCode
{
    success,
    unexpectedEnd,
    unexpectedValue,
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

    size_t top()
    {
        version(LDC)
            pragma(inline, true);
        assert(length);
        immutable local = (length - 1) & (Node.length - 1);
        return node.buff[local];
    }

    size_t pop()
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
    void free()
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

///
struct JsonParser
{
    enum bool includingNewLine = true;
    enum bool assumeValid = false;
    import std.experimental.allocator.mallocator;

    alias Allocator = shared Mallocator;
    alias Input = const(char)[][];
    enum bool chunked = !is(Input : const(char)[]);

    ubyte[] data;
    Allocator* allocator;
    Input input;
    static if (chunked)
        ubyte[] front;
    else
        alias front = input;
    size_t dataLength;

    string _lastError;

    size_t index;
    size_t n;
    size_t maxLength;
    const(ubyte[64])* vector;
    ulong[2]* pairedMask1;
    ulong[2]* pairedMask2;
    ubyte* tapePtr;
    ubyte* currentTapePtr;
    size_t length;

    bool delegate(scope const(ubyte[64])* vector, scope ulong[2]* pairedMask1, scope ulong[2]* pairedMask2) fetchNext;

    // this(ref Allocator allocator, Input input)
    // {
    //     this.input = input;
    //     this.allocator = &allocator;
    // }

    auto result()
    {
        return data[0 .. dataLength];
    }

    string lastError() @property
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
        size_t maxLength;
        ubyte* dataPtr;
        ubyte* stringAndNumberShift = void;
        static if (chunked)
        {
            bool prepareInput()
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
                const dataAddLength = front.length * 6;
                const dataLength = dataPtr - data.ptr;
                const dataRequiredLength = dataLength + dataAddLength;
                if (data.length < dataRequiredLength)
                {
                    const valueLength = stringAndNumberShift - dataPtr;
                    import std.algorithm.comparison: max;
                    const len = max(data.length * 2, dataRequiredLength);
                    allocator.reallocate(*cast(void[]*)&data, len);
                    dataPtr = data.ptr + dataLength;
                    stringAndNumberShift = dataPtr + valueLength;
                }
                return true;
            }
            strPtr = front.ptr;
        }
        else
        {
            strPtr = cast(const(ubyte)*) input.ptr;
            enum bool prepareInput = false;
        }

        int prepareSmallInput()
        {
            // TODO: implement
            return 0;
        }

        auto rl = (maxLength - index) * 6;
        if (data.ptr !is null && data.length < rl)
        {
            allocator.deallocate(data);
            data = null;
        }
        if (data.ptr is null)
        {
            data = cast(ubyte[])allocator.allocate(rl);
        }
        dataPtr = data.ptr;

        bool skipSpaces()
        {
            F: if (_expect(index < maxLength, true))
            {
            L:
                auto indexG = index >> 6;
                auto indexL = index & 0x3F;
                auto spacesMask = pairedMask2[indexG][0] << indexL;
                if (_expect(spacesMask != 0, true))
                {
                    index += ctlz(spacesMask);
                    return true;
                }
                else
                {
                    index = (indexG + 1) << 6;
                    goto F;
                }
            }
            else
            {
                if (prepareInput)
                    goto L;
                return false;
            }
        }

        @minsize
        int readUnicode()(ref dchar d)
        {
            uint e = 0;
            size_t i = 4;
            if (prepareSmallInput < 4)
                return 1;
            do
            {
                int c = uniFlags[strPtr[index++]];
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

        @minsize
        int readEscaped()(ref dchar d)
        {
            assert(strPtr[index] == '\\');
            index++;
            if (index == maxLength && !prepareInput)
                goto string_unexpectedEnd;
            c = strPtr[index];
            switch(c)
            {
                case '/' :
                case '\"':
                case '\\':
                    d = cast(ubyte) c;
                    goto StringLoop;
                case 'b' : d = '\b'; goto StringLoop;
                case 'f' : d = '\f'; goto StringLoop;
                case 'n' : d = '\n'; goto StringLoop;
                case 'r' : d = '\r'; goto StringLoop;
                case 't' : d = '\t'; goto StringLoop;
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
                        if (index == maxLength && !prepareInput)
                            goto string_unexpectedEnd;
                        if (strPtr[index++] != '\\')
                            goto string_unexpectedValue;
                        if (index == maxLength && !prepareInput)
                            goto string_unexpectedEnd;
                        if (strPtr[index++] != 'u')
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

        Stack stack;

        typeof(return) retCode;
        bool currIsKey = void;
        size_t stackValue = void;
        goto value;

/////////// RETURN
    ret:
        dataLength = dataPtr - data.ptr;
        assert(stack.length == 0);
    ret_final:
        return retCode;
///////////

    key:
        if (!skipSpaces)
            goto object_key_unexpectedEnd;
    key_start:
        if (strPtr[index] != '"')
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
            auto v = strPtr[index++];
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
        switch(strPtr[index])
        {
            stringValue:
            case '"':
                currIsKey = false;
                *dataPtr++ = AsdfKind.string;
                stringAndNumberShift = dataPtr;
                // reserve 4 byte for the length
                dataPtr += 4;
                goto string;
            case '-':
            case '0':
            ..
            case '9': {
                *dataPtr++ = AsdfKind.number;
                stringAndNumberShift = dataPtr;
                // reserve 1 byte for the length
                dataPtr++; // write the first character
                *dataPtr++ = strPtr[index++];
                for(;;)
                {
                    if (index == maxLength && !prepareInput)
                        goto number_found;
                    while(index < maxLength)
                    {
                        char c0 = strPtr[index]; if (!isJsonNumber(c0)) goto number_found; dataPtr[0] = c0;
                        index++;
                        dataPtr += 1;
                    }
                }
            number_found:

                auto numberLength = dataPtr - stringAndNumberShift - 1;
                if (numberLength > ubyte.max)
                    goto number_length_unexpectedValue;
                *stringAndNumberShift = cast(ubyte) numberLength;
                goto next;
            }
            case '{':
                index++;
                *dataPtr++ = AsdfKind.object;
                stack.push(((dataPtr - data.ptr) << 1) ^ 1);
                dataPtr += 4;
                if (!skipSpaces)
                    goto object_first_value_start_unexpectedEnd;
                if (strPtr[index] != '}')
                    goto key_start;
                index++;
                goto structure_end;
            case '[':
                index++;
                *dataPtr++ = AsdfKind.array;
                stack.push(((dataPtr - data.ptr) << 1) ^ 0);
                dataPtr += 4;
                if (!skipSpaces)
                    goto array_first_value_start_unexpectedEnd;
                if (strPtr[index] != ']')
                    goto value_start;
                index++;
                goto structure_end;
            foreach (name; AliasSeq!("false", "null", "true"))
            {
            case name[0]:
                    if (prepareSmallInput < name.length)
                    {
                        static if (name == "true")
                            goto true_unexpectedEnd;
                        else
                        static if (name == "false")
                            goto false_unexpectedEnd;
                        else
                            goto null_unexpectedEnd;
                    }
                    enum ubyte[4] referenceValue = [
                        name[$ - 4],
                        name[$ - 3],
                        name[$ - 2],
                        name[$ - 1],
                    ];
                    enum startShift = name.length == 5;
                    if (*cast(ubyte[4]*)(strPtr + startShift) != referenceValue)
                    {
                        static if (name == "true")
                            goto true_unexpectedValue;
                        else
                        static if (name == "false")
                            goto false_unexpectedValue;
                        else
                            goto null_unexpectedValue;
                    }
                    static if (name == "null")
                        *dataPtr++ = AsdfKind.null_;
                    else
                    static if (name == "false")
                        *dataPtr++ = AsdfKind.false_;
                    else
                        *dataPtr++ = AsdfKind.true_;
                    strPtr += name.length;
                    goto next;
            }
            default: goto value_unexpectedStart;
        }

    string:
        debug assert(strPtr[index] == '"', "Internal ASDF logic error. Please report an issue.");
        index++;

    StringLoop: {
        
        // size_t strLength;
        auto strEndIndex = index;
        for(;;)
        {
            F: if (_expect(index < maxLength, true))
            {
            L:
                auto indexG = index >> 6;
                auto indexL = index & 0x3F;
                auto mask = pairedMask1[indexG];
                mask[0] <<= indexL;
                mask[1] <<= indexL;
                auto strMask = mask[0] | mask[1];
                if (strMask)
                {
                    auto value = ctlz(strMask);
                    strEndIndex += value;
                    if ((mask[1] >> value) & 1) // escape value
                    {
                        readUnicode();
                    }
                }
                else
                {
                    index = (indexG + 1) << 6;
                    goto F;
                }
            }
            else
            {
                if (prepareInput)
                    goto L;
                return false;
            }

            if (index == maxLength && !prepareInput)
                goto string_unexpectedEnd;
        }

        for(;;)
        {
            if (index == maxLength && !prepareInput)
                goto string_unexpectedEnd;
            while(index < maxLength)
            {
                char c0 = strPtr[index]; if (!isPlainJsonCharacter(c0)) goto string_found; dataPtr[0] = c0;
                index++;
                dataPtr += 1;
            }
        }
        string_found:

        uint c = strPtr[index];
        if (c == '\"')
        {
            index++;
            if (currIsKey)
            {
                auto stringLength = dataPtr - stringAndNumberShift - 1;
                if (stringLength > ubyte.max)
                    goto key_is_to_large;
                *cast(ubyte*)stringAndNumberShift = cast(ubyte) stringLength;
                if (!skipSpaces)
                    goto failed_to_read_after_key;
                if (strPtr[index] != ':')
                    goto unexpected_character_after_key;
                index++;
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
        _lastError = "expected '\"' when start parsing object key";
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
    value_unexpectedStart:
        _lastError = "unexpected character when start parsing JSON value";
        goto unexpectedEnd;
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

enum AsdfKind : ubyte
{
    null_  = 0x00,
    true_  = 0x01,
    false_ = 0x02,
    number = 0x03,
    string = 0x05,
    array  = 0x09,
    object = 0x0A,
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
