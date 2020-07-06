/++
+/
// TODO: tape building for Annotations
module mir.ion.tape;

import core.stdc.string: memmove, memcpy;
import mir.bignum.low_level_view;
import mir.bitop;
import mir.date;
import mir.ion.lob;
import mir.ion.timestamp: IonTimestamp;
import mir.ion.type_code;
import mir.utility: _expect;
import std.traits;

size_t ionPutVarUInt(T)(scope ubyte* ptr, const T num)
    if (isUnsigned!T)
{
    T value = num;
    enum s = T.sizeof * 8 / 7 + 1;
    uint len;
    do ptr[s - 1 - len++] = value & 0x7F;
    while (value >>>= 7);
    ptr[s - 1] |= 0x80;
    auto arr = *cast(ubyte[s-1]*)(ptr + s - len);
    *cast(ubyte[s-1]*)ptr = arr;
    return len;
}

size_t ionPutVarInt(T)(scope ubyte* ptr, const T num)
    if (isSigned!T)
{
    return .ionPutVarInt!(Unsigned!T)(ptr, num < 0 ? cast(Unsigned!T)(0-num) : num, num < 0);
}

size_t ionPutVarInt(T)(scope ubyte* ptr, const T num, bool sign)
    if (isUnsigned!T)
{
    T value = num; 
    if (_expect(value < 64, true))
    {
        *ptr = cast(ubyte)(value | 0x80 | (sign << 6));
        return 1;
    }
    enum s = T.sizeof * 8 / 7 + 1;
    size_t len;
    do ptr[s - 1 - len++] = value & 0x7F;
    while (value >>>= 7);
    auto sb = ptr[s - len] >>> 6;
    len += sb;
    auto r = ptr[s - len] & ~(~sb + 1);
    ptr[s - len] = cast(ubyte)r | (cast(ubyte)sign << 6);
    ptr[s - 1] |= 0x80;
    auto arr = *cast(ubyte[s-1]*)(ptr + s - len);
    *cast(ubyte[s-1]*)ptr = arr;
    return len;
}



size_t ionPutUIntField(W, WordEndian endian)(
    scope ubyte* ptr,
    BigUIntView!(const W, endian) value,
    )
    if (isUnsigned!W && (W.sizeof == 1 || endian == TargetEndian))
{
    pragma(inline, false);
    auto data = value.mostSignificantFirst;
    size_t ret;
    static if (W.sizeof > 1)
    {
        if (data.length)
        {
            ret = .ionPutUIntField(ptr, data[0]);
            data.popFront;
        }
    }
    foreach (W d; data)
    {
        version (LittleEndian)
        {
            import core.bitop: bswap;
            d = bswap(d);
        }
        *cast(ubyte[W.sizeof]*)(ptr + ret) = cast(ubyte[W.sizeof])cast(W[1])[d];
        ret += W.sizeof;
    }
    return ret;
}

size_t ionPutUIntField(T)(scope ubyte* ptr, const T num)
    if (isUnsigned!T && T.sizeof >= 4)
{
    T value = num;
    auto c = ctlzp(value);
    value <<= c & 0xF8;
    c >>>= 3;
    version (LittleEndian)
    {
        import core.bitop: bswap;
        value = bswap(value);
    }
    *cast(ubyte[T.sizeof]*)ptr = cast(ubyte[T.sizeof])cast(T[1])[value];
    return T.sizeof - c;
}

size_t ionPutUIntField(T)(scope ubyte* ptr, const T num)
    if (is(T == ubyte))
{
    *ptr = num;
    return num != 0;
}

size_t ionPutUIntField(T)(scope ubyte* ptr, const T num)
    if (is(T == ushort))
{
    return ionPutUIntField!uint(ptr, num);
}

size_t ionPutIntField(W, WordEndian endian)(
    scope ubyte* ptr,
    BigIntView!(const W, endian) value,
    )
    if (isUnsigned!W && (W.sizeof == 1 || endian == TargetEndian))
{
    pragma(inline, false);
    auto data = value.unsigned.mostSignificantFirst;
    if (data.length == 0)
        return 0;
    size_t ret = .ionPutIntField(ptr, data[0], value.sign);
    data.popFront;
    foreach (W d; data)
    {
        version (LittleEndian)
        {
            import core.bitop: bswap;
            d = bswap(d);
        }
        *cast(ubyte[W.sizeof]*)(ptr + ret) = cast(ubyte[W.sizeof])cast(W[1])[d];
        ret += W.sizeof;
    }
    return ret;
}

size_t ionPutIntField(T)(scope ubyte* ptr, const T num)
    if (isSigned!T && isIntegral!T)
{
    T value = num;
    bool sign = value < 0;
    if (sign)
        value = cast(T)(0-value);
    return ionPutIntField!(Unsigned!T)(ptr, value, sign);
}

size_t ionPutIntField(T)(scope ubyte* ptr, const T num, bool sign)
    if (isUnsigned!T)
{
    T value = num;
    static if (T.sizeof >= 4)
    {
        size_t c = ctlzp(value);
        bool s = (c & 0x7) == 0;
        *ptr = sign << 7;
        ptr += s;
        value <<= c & 0xF8;
        c >>>= 3;
        value |= T(sign) << (T.sizeof * 8 - 1);
        c = T.sizeof - c + s - (value == 0);
        version (LittleEndian)
        {
            import core.bitop: bswap;
            value = bswap(value);
        }
        *cast(ubyte[T.sizeof]*)ptr = cast(ubyte[T.sizeof])cast(T[1])[value];
        return c;
    }
    else
    {
        return ionPutIntField!uint(ptr, value, sign);
    }
}

size_t ionPut(T : typeof(null))(scope ubyte* ptr, const T)
{
    *ptr++ = 0x0F;
    return 1;
}

size_t ionPut(T : bool)(scope ubyte* ptr, const T value)
{
    *ptr++ = 0x10 | value;
    return 1;
}

size_t ionPut(T)(scope ubyte* ptr, const T value, bool sign = false)
    if (isUnsigned!T)
{
    auto L = ionPutUIntField!T(ptr + 1, value);
    static if (T.sizeof <= 8)
    {
        *ptr = cast(ubyte) (0x20 | (sign << 4) | L);
        return L + 1;
    }
    else
    {
        static assert(0, "cent and ucent types not supported by mir.ion for now");
    }
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (isSigned!T && isIntegral!T)
{
    bool sign = value < 0;
    T num = value;
    if (sign)
        num = cast(T)(0-num);
    return ionPut!(Unsigned!T)(ptr, num, sign);
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == float))
{
    auto num = *cast(uint*)&value;
    auto s = (num != 0) << 2;
    *ptr = cast(ubyte)(0x40 + s);
    version (LittleEndian)
    {
        import core.bitop: bswap;
        num = bswap(num);
    }
    *cast(ubyte[4]*)(ptr + 1) = cast(ubyte[4])cast(uint[1])[num];
    return 1 + s;
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == double))
{
    auto num = *cast(ulong*)&value;
    auto s = (num != 0) << 3;
    *ptr = cast(ubyte)(0x40 + s);
    version (LittleEndian)
    {
        import core.bitop: bswap;
        num = bswap(num);
    }
    *cast(ubyte[8]*)(ptr + 1) = cast(ubyte[8])cast(ulong[1])[num];
    return 1 + s;
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == real))
{
    return ionPut!double(ptr, value);
}

size_t ionPut(W, WordEndian endian)(
    scope ubyte* ptr,
    BigUIntView!(const W, endian) value,
    )
    if (isUnsigned!W && (W.sizeof == 1 || endian == TargetEndian))
{
    return ionPut(ptr, value.signed);
}

size_t ionPut(W, WordEndian endian)(
    scope ubyte* ptr,
    BigIntView!(const W, endian) value,
    )
    if (isUnsigned!W && (W.sizeof == 1 || endian == TargetEndian))
{
    auto length = ionPutUIntField(ptr + 1, value.unsigned);
    auto q = 0x20 | (value.sign << 4);
    if (_expect(length < 0xE, true))
    {
        *ptr = cast(ubyte)(q | length);
        return length + 1;
    }
    else
    {
        *ptr = cast(ubyte)(q | 0xE);
        ubyte[10] lengthPayload;
        auto lengthLength = ionPutVarUInt(lengthPayload.ptr, length);
        memmove(ptr + 1 + lengthLength, ptr + 1, length);
        memcpy(ptr + 1, lengthPayload.ptr, lengthLength);
        return length + 1 + lengthLength;
    }
}

size_t ionPut(W, WordEndian endian)(
    scope ubyte* ptr,
    DecimalView!(const W, endian) value,
    )
    if (isUnsigned!W && (W.sizeof == 1 || endian == TargetEndian))
{
    size_t length;
    if (value.coefficient.coefficients.length == 0)
        goto L;
    length = ionPutVarInt(ptr + 1, value.exponent);
    length += ionPutIntField(ptr + 1 + length, value.signedCoefficient);
    if (_expect(length < 0xE, true))
    {
    L:
        *ptr = cast(ubyte)(0x50 | length);
        return length + 1;
    }
    else
    {
        *ptr = 0x5E;
        ubyte[10] lengthPayload;
        auto lengthLength = ionPutVarUInt(lengthPayload.ptr, length);
        memmove(ptr + 1 + lengthLength, ptr + 1, length);
        memcpy(ptr + 1, lengthPayload.ptr, lengthLength);
        return length + 1 + lengthLength;
    }
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == IonTimestamp))
{
    size_t ret = 1;
    ret += ionPutVarInt(ptr + ret, value.offset);
    ret += ionPutVarUInt(ptr + ret, value.year);
    if (value.precision >= IonTimestamp.precision.month)
    {
        ptr[ret++] = cast(ubyte) (0x80 | value.month);
        if (value.precision >= IonTimestamp.precision.day)
        {
            ptr[ret++] = cast(ubyte) (0x80 | value.day);
            if (value.precision >= IonTimestamp.precision.minute)
            {
                ptr[ret++] = cast(ubyte) (0x80 | value.hour);
                ptr[ret++] = cast(ubyte) (0x80 | value.minute);
                if (value.precision >= IonTimestamp.precision.second)
                {
                    ptr[ret++] = cast(ubyte) (0x80 | value.second);
                    if (value.precision > IonTimestamp.precision.second) //fraction
                    {
                        ret += ionPutVarInt(ptr + ret, value.fractionExponent);
                        ret += ionPutIntField(ptr + ret, value.fractionCoefficient);
                    }
                }
            }
        }
    }
    auto length = ret - 1;
    if (_expect(ret < 0xF, true))
    {
        *ptr = cast(ubyte) (0x60 | length);
        return ret;
    }
    else
    {
        memmove(ptr + 2, ptr + 1, length);
        *ptr = 0x6E;
        ptr[1] = cast(ubyte) (0x80 | length);
        return ret + 1;
    }
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == Date))
{
    size_t ret = 1;
    auto ymd = value.yearMonthDay;
    ptr[ret++] = 0x80;
    ret += ionPutVarUInt(ptr + ret, cast(ushort)value.year);
    ptr[ret++] = cast(ubyte) (0x80 | value.month);
    ptr[ret++] = cast(ubyte) (0x80 | value.day);
    auto length = ret - 1;
    *ptr = cast(ubyte) (0x60 | length);
    return ret;
}

size_t ionPutSymbolId(T)(scope ubyte* ptr, const T value)
    if (isUnsigned!T)
{
    auto length = ionPutVarUInt(ptr + 1, value);
    *ptr = cast(ubyte)(0x70 | length);
    return length + 1;
}

size_t ionPut()(scope ubyte* ptr, const(char)[] value)
{
    size_t ret = 1;
    if (value.length < 0xE)
    {
        *ptr = cast(ubyte) (0x80 | value.length);
    }
    else
    {
        *ptr = 0x8E;
        ret += ionPutVarUInt(ptr + 1, value.length);
    }
    memcpy(ptr + ret, value.ptr, value.length);
    return ret + value.length;
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == IonClob))
{
    size_t ret = 1;
    if (value.data.length < 0xE)
    {
        *ptr = cast(ubyte) (0x90 | value.data.length);
    }
    else
    {
        *ptr = 0x9E;
        ret += ionPutVarUInt(ptr + 1, value.data.length);
    }
    memcpy(ptr + ret, value.data.ptr, value.data.length);
    return ret + value.data.length;
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == IonBlob))
{
    size_t ret = 1;
    if (value.data.length < 0xE)
    {
        *ptr = cast(ubyte) (0xA0 | value.data.length);
    }
    else
    {
        *ptr = 0xAE;
        ret += ionPutVarUInt(ptr + 1, value.data.length);
    }
    memcpy(ptr + ret, value.data.ptr, value.data.length);
    return ret + value.data.length;
}

size_t ionPutStartLength()()
{
    return 3;
}

size_t ionPutEnd()(ubyte* startPtr, IonTypeCode tc, size_t totalElementLength)
{
    assert (tc == IonTypeCode.string || tc == IonTypeCode.list || tc == IonTypeCode.sexp || tc == IonTypeCode.struct_);
    auto tck = tc << 4;
    if (totalElementLength < 0x80)
    {
        if (totalElementLength < 0xE)
        {
            *startPtr = cast(ubyte) (tck | totalElementLength);
            memmove(startPtr + 1, startPtr + 3, 16);
            return 1 + totalElementLength;
        }
        else
        {
            *startPtr = cast(ubyte)(tck | 0xE);
            startPtr[1] = cast(ubyte) (0x80 | totalElementLength);
            memmove(startPtr + 2, startPtr + 3, 128);
            return 2 + totalElementLength;
        }
    }
    else
    {
        *startPtr = cast(ubyte)(tck | 0xE);
        if (_expect(totalElementLength < 0x4000, true))
        {
            startPtr[1] = cast(ubyte) (totalElementLength >> 7);
            startPtr[2] = cast(ubyte) (totalElementLength | 0x80);
            return 3 + totalElementLength;
        }
        else
        {
            ubyte[10] lengthPayload;
            auto lengthLength = ionPutVarUInt(lengthPayload.ptr, totalElementLength);
            memmove(startPtr + 1 + lengthLength, startPtr + 3, totalElementLength);
            memcpy(startPtr + 1, lengthPayload.ptr, lengthLength);
            return totalElementLength + 1 + lengthLength;
        }
    }
}

size_t ionPutStartLength()(ubyte* startPtr, IonTypeCode tc)
{
    *startPtr = cast(ubyte)(tc << 4);
    return ionPutStartLength;
}

size_t ionPutEnd()(ubyte* startPtr, size_t totalElementLength)
{
    if (totalElementLength < 0x80)
    {
        if (totalElementLength < 0xE)
        {
            *startPtr |= cast(ubyte) (totalElementLength);
            memmove(startPtr + 1, startPtr + 3, 16);
            return 1 + totalElementLength;
        }
        else
        {
            *startPtr |= cast(ubyte)(0xE);
            startPtr[1] = cast(ubyte) (0x80 | totalElementLength);
            memmove(startPtr + 2, startPtr + 3, 128);
            return 2 + totalElementLength;
        }
    }
    else
    {
        *startPtr |= cast(ubyte)(0xE);
        if (_expect(totalElementLength < 0x4000, true))
        {
            startPtr[1] = cast(ubyte) (totalElementLength >> 7);
            startPtr[2] = cast(ubyte) (totalElementLength | 0x80);
            return 3 + totalElementLength;
        }
        else
        {
            ubyte[10] lengthPayload;
            auto lengthLength = ionPutVarUInt(lengthPayload.ptr, totalElementLength);
            memmove(startPtr + 1 + lengthLength, startPtr + 3, totalElementLength);
            memcpy(startPtr + 1, lengthPayload.ptr, lengthLength);
            return totalElementLength + 1 + lengthLength;
        }
    }
}

