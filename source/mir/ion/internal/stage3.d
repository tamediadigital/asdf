module mir.ion.internal.stage3;

import core.stdc.string: memcpy;
import mir.utility: _expect;
import mir.primitives;
import mir.bitop;
import mir.ion.tape;
import mir.ion.type_code;
import std.traits;
import std.meta: AliasSeq, aliasSeqOf;

enum JsonParsingErrorCode
{
    success,
    unexpectedEnd,
    unexpectedValue,
}

struct Stage3Stage
{
    ubyte[] tape;
    size_t currentTapePosition;
    size_t index;
    size_t n;
    const(ubyte)* strPtr;
    ulong[2]* pairedMask1;
    ulong[2]* pairedMask2;
}

pragma(inline, false)
JsonParsingErrorCode stage3(
    bool delegate(ref Stage3Stage stage) fetchNext,
)
{
    string _lastError;

    Stage3Stage stage;

    fetchNext(stage);

    with(stage) {

    bool prepareInput()
    {
        pragma(inline, false);
        // if(strPtr)
        // {
        //     input.popFront;
        //     if (input.empty)
        //     {
        //         return false;
        //     }
        // }
        // front = cast(typeof(front)) input.front;
        // if (front.length == 0)
        //     return false;
        // strPtr = front.ptr;
        // const dataAddLength = front.length * 6;
        // const dataLength = dataPtr - data.ptr;
        // const dataRequiredLength = dataLength + dataAddLength;
        // if (data.length < dataRequiredLength)
        // {
        //     const valueLength = stringAndNumberShift - dataPtr;
        //     import std.algorithm.comparison: max;
        //     const len = max(data.length * 2, dataRequiredLength);
        //     allocator.reallocate(*cast(void[]*)&data, len);
        //     dataPtr = data.ptr + dataLength;
        //     stringAndNumberShift = dataPtr + valueLength;
        // }
        return true;
    }
    // strPtr = front.ptr;

    int prepareSmallInput()
    {
        // TODO: implement
        return 0;
    }

    // auto rl = (n - index) * 6;
    // if (data.ptr !is null && data.length < rl)
    // {
    //     allocator.deallocate(data);
    //     data = null;
    // }
    // if (data.ptr is null)
    // {
    //     data = cast(ubyte[])allocator.allocate(rl);
    // }

    bool skipSpaces()
    {
        F: if (_expect(index < n, true))
        {
        L:
            auto indexG = index >> 6;
            auto indexL = index & 0x3F;
            auto spacesMask = pairedMask2[indexG][0] >> indexL;
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

    int readUnicode()(ref dchar d)
    {
        uint e = 0;
        size_t i = 4;
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

    size_t[1024] stack = void;
    sizediff_t stackPos = stack.length;

    typeof(return) retCode;
    bool currIsKey = void;
    size_t stackValue = void;
    goto value;

/////////// RETURN
ret:
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
    // reserve 1 byte for the length
string:
    assert(strPtr[index] == '"', "Internal ASDF logic error. Please report an issue.");
    index++;
StringLoop: {
    
    const stringCodeStart = currentTapePosition;
    currentTapePosition += ionPutStartLength;
    for(;;)
    {
        int smallInputLength = prepareSmallInput;
        auto indexG = index >> 6;
        auto indexL = index & 0x3F;
        auto mask = pairedMask1[indexG];
        mask[0] >>= indexL;
        mask[1] >>= indexL;
        auto strMask = mask[0] | mask[1];
        // TODO: memcpy optimisation for DMD
        memcpy(tape.ptr + currentTapePosition, strPtr + index, 64);
        auto value = strMask == 0 ? ctlz(strMask) : 64 - indexL;
        smallInputLength -= cast(int) value;
        if (smallInputLength <= 0)
            goto string_unexpectedEnd;
        currentTapePosition += value;
        index += value;
        if (strMask == 0)
            continue;
        if (_expect(((mask[1] >> value) & 1) == 0, true)) // no escape value
        {
            assert(strPtr[index] == '"');
            auto stringLength = currentTapePosition - (stringCodeStart + ionPutStartLength);
            if (!currIsKey)
            {
                ionPutEnd(tape.ptr + stringCodeStart, IonTypeCode.string, stringLength);
                goto next;
            }
            currentTapePosition -= stringLength;
            auto key = tape[currentTapePosition .. currentTapePosition + stringLength];
            currentTapePosition -= ionPutStartLength;
            size_t id;
            // TODO find id using the key
            ionPutSymbolId(tape.ptr + currentTapePosition, id);
            if (!skipSpaces)
                goto unexpectedEnd;
            if (strPtr[index++] != ':')
                goto object_after_key_is_missing;
            goto value;
        }
        else
        {
            assert(strPtr[index] == '\\');
            if ((smallInputLength -= 2) <= 0)
                goto string_unexpectedEnd;
            dchar d = void;
            auto c = strPtr[index + 1];
            index += 2;
            switch(c)
            {
                case '/' :
                case '\"':
                case '\\':
                    d = cast(ubyte) c;
                    goto PutASCII;
                case 'b' : d = '\b'; goto PutASCII;
                case 'f' : d = '\f'; goto PutASCII;
                case 'n' : d = '\n'; goto PutASCII;
                case 'r' : d = '\r'; goto PutASCII;
                case 't' : d = '\t'; goto PutASCII;
                case 'u' :
                    if ((smallInputLength -= 4) <= 0)
                        goto string_unexpectedEnd;
                    if (auto r = readUnicode(d))
                        goto unexpectedValue; //unexpected \u
                    if (_expect(0xD800 <= d && d <= 0xDFFF, false))
                    {
                        if (d >= 0xDC00)
                            goto invalid_utf_value;
                        if ((smallInputLength -= 6) < 0)
                            goto string_unexpectedEnd;
                        if (strPtr[index++] != '\\')
                            goto invalid_utf_value;
                        if (strPtr[index++] != 'u')
                            goto invalid_utf_value;
                        d = (d & 0x3FF) << 10;
                        dchar trailing = void;
                        if (auto r = readUnicode(trailing))
                            goto unexpectedValue; //unexpected \u
                        if (!(0xDC00 <= trailing && trailing <= 0xDFFF))
                            goto invalid_trail_surrogate;
                        {
                            d |= trailing & 0x3FF;
                            d += 0x10000;
                        }
                    }
                    if (d < 0x80)
                    {
                    PutASCII:
                        tape[currentTapePosition] = cast(ubyte) (d);
                        currentTapePosition += 1;
                        continue;
                    }
                    if (d < 0x800)
                    {
                        tape[currentTapePosition + 0] = cast(ubyte) (0xC0 | (d >> 6));
                        tape[currentTapePosition + 1] = cast(ubyte) (0x80 | (d & 0x3F));
                        currentTapePosition += 2;
                        continue;
                    }
                    if (!(d < 0xD800 || (d > 0xDFFF && d <= 0x10FFFF)))
                        goto invalid_trail_surrogate;
                    if (d < 0x10000)
                    {
                        tape[currentTapePosition + 0] = cast(ubyte) (0xE0 | (d >> 12));
                        tape[currentTapePosition + 1] = cast(ubyte) (0x80 | ((d >> 6) & 0x3F));
                        tape[currentTapePosition + 2] = cast(ubyte) (0x80 | (d & 0x3F));
                        currentTapePosition += 3;
                        continue;
                    }
                    //    assert(d < 0x200000);
                    tape[currentTapePosition + 0] = cast(ubyte) (0xF0 | (d >> 18));
                    tape[currentTapePosition + 1] = cast(ubyte) (0x80 | ((d >> 12) & 0x3F));
                    tape[currentTapePosition + 2] = cast(ubyte) (0x80 | ((d >> 6) & 0x3F));
                    tape[currentTapePosition + 3] = cast(ubyte) (0x80 | (d & 0x3F));
                    currentTapePosition += 4;
                    continue;
                default: goto unexpectedValue; // unexpected escape
            }
        }
    }
}
next:
    if (stack.length == 0)
        goto ret;
next_start: {
    if (!skipSpaces)
        goto next_unexpectedEnd;
    assert(stackPos >= 0);
    assert(stackPos < stack.length);
    const isObject = (tape[stack[stackPos]] & 0x40) != 0;
    const v = strPtr[index++];
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
    assert(stackPos >= 0);
    assert(stackPos < stack.length);
    stackValue = stack[stackPos++];
    const structureLength = currentTapePosition - (stackValue + ionPutStartLength);
    ionPutEnd(tape.ptr + stackValue, structureLength);
    goto next;
}
value: {
    if (!skipSpaces)
        goto value_unexpectedEnd;
    auto startC = strPtr[index];
    if (startC <= '9')
    {
        currIsKey = false;
        if (startC == '"')
            goto string;

        if (startC == '+')
            goto unexpectedValue;

        size_t numberLength;            
        for(;;)
        {
            int smallInputLength = prepareSmallInput;
            auto indexG = index >> 6;
            auto indexL = index & 0x3F;
            auto spacesMask = pairedMask2[indexG][0] >> indexL;
            // TODO: memcpy optimisation for DMD
            memcpy(tape.ptr + currentTapePosition + numberLength, strPtr + index, 64);
            numberLength += spacesMask == 0 ? ctlz(spacesMask) : 64 - indexL;
            if (spacesMask == 0)
                continue;
            break;
        }
        auto numberStringView = cast(const(char)[]) (tape.ptr + currentTapePosition)[0 .. numberLength];

        import mir.bignum.decimal;
        Decimal!256 decimal;
        DecimalExponentKey key;
        if (!parseDecimal(numberStringView, decimal, key))
            goto unexpectedValue;
        if (!key) // integer
        {
            currentTapePosition += ionPut(tape.ptr + currentTapePosition, decimal.coefficient.view);
            goto next;
        }
        if ((key | 0x20) != DecimalExponentKey.e) // decimal
        {
            currentTapePosition += ionPut(tape.ptr + currentTapePosition, decimal.view);
            goto next;
        }
        // sciencific
        currentTapePosition += ionPut(tape.ptr + currentTapePosition, cast(double)decimal);
        goto next;
    }
    if ((startC | 0x20) == '{')
    {
        index++;
        assert(stackPos <= stack.length);
        if (--stackPos < 0)
            goto stack_overflow;
        stack[stackPos] = currentTapePosition;
        tape[currentTapePosition] = startC == '{' ? IonTypeCode.struct_ << 4 : IonTypeCode.list << 4;
        currentTapePosition += ionPutStartLength;
        goto next_start;
    }
    prepareSmallInput;
    static foreach(name; AliasSeq!("true", "false", "null"))
    if (*cast(ubyte[name.length]*)strPtr == cast(ubyte[name.length]) name)
    {
        currentTapePosition += ionPut(tape.ptr + currentTapePosition, true);
        strPtr += name.length;
        goto next;
    }
    goto value_unexpectedStart;
}

ret_error:
    goto ret_final;
unexpectedEnd:
    retCode = JsonParsingErrorCode.unexpectedEnd;
    goto ret_error;
unexpectedValue:
    retCode = JsonParsingErrorCode.unexpectedValue;
    goto ret_error;
object_key_unexpectedEnd:
    _lastError = "unexpected end of object key";
    goto unexpectedEnd;
object_after_key_is_missing:
    _lastError = "expected ':' after key";
    goto unexpectedValue;
object_key_start_unexpectedValue:
    _lastError = "expected '\"' when start parsing object key";
    goto unexpectedValue;
key_is_to_large:
    _lastError = "key length is limited to 255 characters";
    goto unexpectedValue;
next_unexpectedEnd:
    assert(stackPos >= 0);
    assert(stackPos < stack.length);
    stackValue = stack[stackPos];
    _lastError = (stackValue & 1) ? "unexpected end when parsing object" : "unexpected end when parsing array";
    goto unexpectedEnd;
next_unexpectedValue:
    assert(stackPos >= 0);
    assert(stackPos < stack.length);
    stackValue = stack[stackPos];
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
stack_overflow:
    _lastError = "overflow of internal stack";
    goto unexpectedValue;
}}

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
