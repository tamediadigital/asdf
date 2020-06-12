///
module mir.ion.tape;

import std.traits;
import mir.bitop;
import mir.utility: _expect;

@system pure nothrow @nogc:

/++
+/
struct SmallDecimal(T)
    if (is(T == ulong) || is(T == uint))
{
    T coefficient;
    uint exponent;
    bool sign;
    bool exponentSign;

@safe pure nothrow @nogc:

    /++
    +/
    this(bool sign, T coefficient, bool exponentSign, uint exponent)
    {
        this.coefficient = coefficient;
        this.exponent = exponent;
        this.sign = sign;
        this.exponentSign = exponentSign;
    }
}

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

unittest
{
    ubyte[10] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0) == 1);
        assert(data[0] == 0x80);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 1) == 1);
        assert(data[0] == 0x81);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0x7F) == 1);
        assert(data[0] == 0xFF);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0xFF) == 2);
        assert(data[0] == 0x01);
        assert(data[1] == 0xFF);
    }

    foreach(T; AliasSeq!(ushort, uint, ulong))
    {

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0x3FFF) == 2);
        assert(data[0] == 0x7F);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0x7FFF) == 3);
        assert(data[0] == 0x01);
        assert(data[1] == 0x7F);
        assert(data[2] == 0xFF);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0xFFEE) == 3);
        assert(data[0] == 0x03);
        assert(data[1] == 0x7F);
        assert(data[2] == 0xEE);
    }

    data[] = 0;
    assert(ionPutVarUInt(data.ptr, uint.max) == 5);
    assert(data[0] == 0x0F);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0xFF);

    data[] = 0;
    assert(ionPutVarUInt!ulong(data.ptr, ulong.max >> 1) == 9);
    assert(data[0] == 0x7F);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0xFF);

    data[] = 0;
    assert(ionPutVarUInt(data.ptr, ulong.max) == 10);
    assert(data[0] == 0x01);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0x7F);
    assert(data[9] == 0xFF);
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

unittest
{
    ubyte[10] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 0, false) == 1);
        assert(data[0] == 0x80);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 1, false) == 1);
        assert(data[0] == 0x81);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 0x3F, false) == 1);
        assert(data[0] == 0xBF);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 0x3F, true) == 1);
        assert(data[0] == 0xFF);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 0x7F, false) == 2);
        assert(data[0] == 0x00);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 128, true) == 2);
        assert(data[0] == 0x41);
        assert(data[1] == 0x80);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 127, true) == 2);
        assert(data[0] == 0x40);
        assert(data[1] == 0xFF);


        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 3, true) == 1);
        assert(data[0] == 0xC3);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 127, true) == 2);
        assert(data[0] == 0x40);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutVarInt!T(data.ptr, 63, true) == 1);
        assert(data[0] == 0xFF);
    }

    data[] = 0;
    assert(ionPutVarInt!uint(data.ptr, int.max, false) == 5);
    assert(data[0] == 0x07);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0xFF);

    data[] = 0;
    assert(ionPutVarInt!uint(data.ptr, int.max, true) == 5);
    assert(data[0] == 0x47);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0xFF);

    data[] = 0;
    assert(ionPutVarInt!uint(data.ptr, int.max + 1, true) == 5);
    assert(data[0] == 0x48);
    assert(data[1] == 0x00);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x80);

    data[] = 0;
    assert(ionPutVarInt!ulong(data.ptr, long.max >> 1, false) == 9);
    assert(data[0] == 0x3F);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0xFF);

    data[] = 0;
    assert(ionPutVarInt!ulong(data.ptr, long.max, false) == 10);
    assert(data[0] == 0x00);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0x7F);
    assert(data[9] == 0xFF);

    data[] = 0;
    assert(ionPutVarInt!ulong(data.ptr, long.max, true) == 10);
    assert(data[0] == 0x40);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0x7F);
    assert(data[9] == 0xFF);

    data[] = 0;
    assert(ionPutVarInt!ulong(data.ptr, -long.min, true) == 10);
    assert(data[0] == 0x41);
    assert(data[1] == 0x00);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);
    assert(data[9] == 0x80);

    data[] = 0;
    assert(ionPutVarInt(data.ptr, ulong.max, true) == 10);
    assert(data[0] == 0x41);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0x7F);
    assert(data[9] == 0xFF);

    data[] = 0;
    assert(ionPutVarInt(data.ptr, ulong.max, false) == 10);
    assert(data[0] == 0x01);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0x7F);
    assert(data[9] == 0xFF);
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

size_t ionPutUIntField(T : ubyte)(scope ubyte* ptr, const T num)
{
    *ptr = num;
    return num != 0;
}

size_t ionPutUIntField(T : ushort)(scope ubyte* ptr, const T num)
{
    return ionPutUIntField!uint(ptr, num);
}

unittest
{
    ubyte[8] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0) == 0);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 1) == 1);
        assert(data[0] == 0x01);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0x3F) == 1);
        assert(data[0] == 0x3F);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0xFF) == 1);
        assert(data[0] == 0xFF);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0x80) == 1);
        assert(data[0] == 0x80);
    }

    data[] = 0;
    assert(ionPutUIntField!uint(data.ptr, int.max) == 4);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);

    data[] = 0;
    assert(ionPutUIntField!uint(data.ptr, int.max + 1) == 4);
    assert(data[0] == 0x80);
    assert(data[1] == 0x00);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);

    data[] = 0;
    assert(ionPutUIntField!ulong(data.ptr, long.max >> 1) == 8);
    assert(data[0] == 0x3F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutUIntField!ulong(data.ptr, long.max) == 8);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutUIntField!ulong(data.ptr, long.max + 1) == 8);
    assert(data[0] == 0x80);
    assert(data[1] == 0x00);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);

    data[] = 0;
    assert(ionPutUIntField(data.ptr, ulong.max) == 8);
    assert(data[0] == 0xFF);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);
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

unittest
{
    ubyte[9] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0, false) == 0);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0, true) == 1);
        assert(data[0] == 0x80);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 1, false) == 1);
        assert(data[0] == 0x01);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 1, true) == 1);
        assert(data[0] == 0x81);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0x3F, true) == 1);
        assert(data[0] == 0xBF);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0xFF, false) == 2);
        assert(data[0] == 0x00);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0xFF, true) == 2);
        assert(data[0] == 0x80);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0x80, true) == 2);
        assert(data[0] == 0x80);
        assert(data[1] == 0x80);
    }

    data[] = 0;
    assert(ionPutIntField(data.ptr, int.max) == 4);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);

    data[] = 0;
    assert(ionPutIntField(data.ptr, int.min) == 5);
    assert(data[0] == 0x80);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);

    data[] = 0;
    assert(ionPutIntField(data.ptr, long.max >> 1) == 8);
    assert(data[0] == 0x3F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutIntField(data.ptr, long.max) == 8);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutIntField!ulong(data.ptr, long.max + 1, false) == 9);
    assert(data[0] == 0x00);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);

    data[] = 0;
    assert(ionPutIntField(data.ptr, ulong.max, true) == 9);
    assert(data[0] == 0x80);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);
    assert(data[8] == 0xFF);
}

size_t ionPut(T : typeof(null))(scope ubyte* ptr, const T)
{
    *ptr++ = 0x0F;
    return 1;
}

unittest
{
    ubyte[1] data;
    assert(ionPut(data.ptr, null) == 1);
    assert(data[0] == 0x0F);
}

size_t ionPut(T : bool)(scope ubyte* ptr, const T value)
{
    *ptr++ = 0x10 | value;
    return 1;
}

unittest
{
    ubyte[1] data;
    assert(ionPut(data.ptr, true) == 1);
    assert(data[0] == 0x11);
    assert(ionPut(data.ptr, false) == 1);
    assert(data[0] == 0x10);
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

unittest
{
    ubyte[10] data;
    assert(ionPut(data.ptr, 0u) == 1);
    assert(data[0] == 0x20);
    assert(ionPut(data.ptr, 0u, true) == 1);
    assert(data[0] == 0x30);
    assert(ionPut(data.ptr, 0xFFu) == 2);
    assert(data[0] == 0x21);
    assert(data[1] == 0xFF);
    assert(ionPut(data.ptr, 0xFFu, true) == 2);
    assert(data[0] == 0x31);
    assert(data[1] == 0xFF);

    assert(ionPut(data.ptr, ulong.max, true) == 9);
    assert(data[0] == 0x38);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);
    assert(data[8] == 0xFF);
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

unittest
{
    ubyte[10] data;
    assert(ionPut(data.ptr, -16) == 2);
    assert(data[0] == 0x31);
    assert(data[1] == 0x10);

    assert(ionPut(data.ptr, 258) == 3);
    assert(data[0] == 0x22);
    assert(data[1] == 0x01);
    assert(data[2] == 0x02);
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

unittest
{
    ubyte[5] data;
    assert(ionPut(data.ptr, -16f) == 5);
    assert(data[0] == 0x44);
    assert(data[1] == 0xC1);
    assert(data[2] == 0x80);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);

    assert(ionPut(data.ptr, 0f) == 1);
    assert(data[0] == 0x40);

    assert(ionPut(data.ptr, -0f) == 5);
    assert(data[0] == 0x44);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
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

unittest
{
    ubyte[9] data;
    assert(ionPut(data.ptr, -16.0) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0xC0);
    assert(data[2] == 0x30);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);

    assert(ionPut(data.ptr, 0.0) == 1);
    assert(data[0] == 0x40);

    assert(ionPut(data.ptr, -0.0) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);
}

size_t ionPut(T)(scope ubyte* ptr, const T value)
    if (is(T == real))
{
    return ionPut!double(ptr, value);
}

unittest
{
    ubyte[9] data;
    assert(ionPut(data.ptr, -16.0L) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0xC0);
    assert(data[2] == 0x30);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);

    assert(ionPut(data.ptr, 0.0L) == 1);
    assert(data[0] == 0x40);

    assert(ionPut(data.ptr, -0.0L) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);
}

size_t ionPut(T)(
    scope ubyte* ptr,
    const T value,
    )
    if (is(T == SmallDecimal!U, U))
{
    with(value)
    {
        if ((coefficient | exponent | sign) == 0)
        {
            *ptr = 0x50;
            return 1;
        }
        auto L = .ionPutVarInt(ptr + 1, exponent, exponentSign);
        L += .ionPutIntField(ptr + 1 + L, coefficient, sign);
        // should always fits into 1+14 bytes
        assert(L <= 14);
        *ptr = cast(ubyte)(0x50 | L);
        return L + 1;
    }
}

unittest
{
    ubyte[15] data;
    // 0.6
    assert(ionPut(data.ptr, SmallDecimal!ulong(false, 0x06u, true, 1)) == 3);
    assert(data[0] == 0x52);
    assert(data[1] == 0xC1);
    assert(data[2] == 0x06);

    // 0e-3
    assert(ionPut(data.ptr, SmallDecimal!ulong(false, 0x00u, false, 3)) == 2);
    assert(data[0] == 0x51);
    assert(data[1] == 0x83);

    // 0e-0
    assert(ionPut(data.ptr, SmallDecimal!ulong(false, 0x00u, true, 0)) == 1);
    assert(data[0] == 0x50);

    // -0e+0
    assert(ionPut(data.ptr, SmallDecimal!ulong(true, 0x00u, false, 0)) == 3);
    assert(data[0] == 0x52);
    assert(data[1] == 0x80);
    assert(data[2] == 0x80);

    // 0e+0
    assert(ionPut(data.ptr, SmallDecimal!ulong(false, 0x00u, false, 0)) == 1);
    assert(data[0] == 0x50);
}
