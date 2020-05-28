/++
+/
module mir.bignum.fixed_int;

import std.traits;
import mir.bitop;
import mir.utility;

/++
Fixed-length Unsigned Integer

Params:
    size = size in bits
+/
struct UInt(size_t size)
    if ((size & 0x3F) == 0 && size / (size_t.sizeof * 8) >= 1)
{
    /++
    Payload. The data is located in the target endianness.
    +/
    size_t[size / (size_t.sizeof * 8)] data;

    ///
    enum UInt max = ((){UInt ret; ret.data = size_t.max; return ret;})();

    ///
    enum UInt min = UInt.init;

    ///
    static UInt fromHexString(scope const(char)[] str)
    {
        import mir.bignum.low_level_view;
        typeof(return) ret;
        BigUIntView!size_t(ret.data).fromHexStringImpl(str);
        return ret;
    }

    /++
    +/
    auto opCmp(UInt integer)
    {
        import mir.bignum.low_level_view: BigUIntView;
        return BigUIntView!size_t(data).opCmp(BigUIntView!size_t(integer.data));
    }

    /++
    `bool overflow = a += b ` and `bool overflow = a -= b` operations.
    +/
    bool opOpAssign(string op)(UInt rhs, bool overflow = false)
        @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        import mir.bignum.low_level_view;
        return BigUIntView!size_t(data).opOpAssign!op(BigUIntView!size_t(rhs.data), overflow);
    }

    /// ditto
    bool opOpAssign(string op)(size_t rhs)
        @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        import mir.bignum.low_level_view;
        return BigUIntView!size_t(data).opOpAssign!op(rhs);
    }

    /// ditto
    bool opOpAssign(string op, size_t rsize)(UInt!rsize rhs, bool overflow = false)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && rsize < size)
    {
        return opOpAssign!op(rhs.toSize!size);
    }

    ///
    ref UInt opOpAssign(string op)(size_t s)
        @safe pure nothrow @nogc return
        if (op == "<<")
    {
        import mir.bignum.low_level_view;
        auto d = BigUIntView!size_t(data).leastSignificantFirst;
        if (_expect(s < size, false))
        {
            auto index = s / (size_t.sizeof * 8);
            auto bs = s % (size_t.sizeof * 8);
            auto ss = size_t.sizeof * 8 - bs;
            foreach_reverse (j; index + 1 .. data.length)
            {
                data[j] = (data[j - index] << bs) | (data[j - (index + 1)] >> ss);
            }
            data[index] = data[0] << bs;
            foreach_reverse (j; 0 .. index)
            {
                data[j] = 0;
            }
        }
        else
        {
            this = this.init;
        }
        return this;
    }

    /++
    `auto c = a + b` and `auto c = a - b` operations.
    +/
    UInt opBinary(string op, size_t rsize)(UInt!rsize rhs)
        const @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && rsize <= size)
    {
        UInt ret = this;
        ret.opOpAssign!op(rhs);
        return ret;
    }

    /++
    Shift using at most `size_t.sizeof * 8` bits
    +/
    UInt smallLeftShift()(uint shift)
    {
        assert(shift <= size_t.sizeof * 8);
        UInt ret;
        auto csh = size_t.sizeof * 8 - shift;
        version (LittleEndian)
        {
            static foreach_reverse (i; 1 .. data.length)
            {
                ret.data[i] = (data[i] << shift) | (data[i - 1] - csh);
            }
            ret.data[0] = data[0] << shift;
        }
        else
        {
            static foreach (i; 0 .. data.length - 1)
            {
                ret.data[i] = (data[i] << shift) | (data[i + 1] - csh);
            }
            ret.data[$ - 1] = data[$ - 1] << shift;
        }
        return ret;
    }

    /++
    Returns:
        the number with shrinked or extended size.
    +/
    UInt!newSize toSize(size_t newSize)() const
    {
        typeof(return) ret;
        import mir.utility: min;
        enum N = min(ret.data.length, data.length);
        version (LittleEndian)
            ret.data[0 .. N] = data[0 .. N];
        else
            ret.data[N - $ .. $] = data[N - $ .. $];
        return ret;
    }

    /++
    +/
    bool bt()(size_t position) const
        @safe pure nothrow @nogc
    {
        import mir.bignum.low_level_view;
        assert(position < coefficients.length * size_t.sizeof * 8);
        return BigUIntView!(const size_t)(data).bt(position);
    }

    /++
    +/
    size_t ctlz()() const @property
        @safe pure nothrow @nogc
    {
        import mir.bignum.low_level_view;
        return BigUIntView!(const size_t)(data).ctlz;
    }

    /++
    +/
    bool signBit()() const @property
    {
        version (LittleEndian)
            return data[$ - 1] >> (size_t.sizeof * 8 - 1);
        else
            return data[0] >> (size_t.sizeof * 8 - 1);
    }

    /++
    +/
    void signBit()(bool value) @property
    {
        enum signMask = ptrdiff_t.max;
        version (LittleEndian)
            data[$ - 1] = (data[$ - 1] & ptrdiff_t.max) | (size_t(value) << (size_t.sizeof * 8 - 1));
        else
            data[    0] = (data[    0] & ptrdiff_t.max) | (size_t(value) << (size_t.sizeof * 8 - 1));
    }
}

/++
+/
UInt!(sizeA + sizeB) extendedMul(size_t sizeA, size_t sizeB)(UInt!sizeA a, UInt!sizeB b)
{
    UInt!(sizeA + sizeB) ret;
    enum al = a.data.length;
    enum alp1 = a.data.length + 1;
    version (LittleEndian)
    {
        ret.data[0 .. alp1] = extendedMul(a, b.data[0]).data;
        static foreach ( i; 1 .. b.data.length)
            ret.data[i .. i + alp1] = extendedMulAdd(a, b.data[i], UInt!sizeA(ret.data[i .. i + al])).data;
    }
    else
    {
        ret.data[$ - alp1 .. $] = extendedMul(a, b.data[$ - 1]).data;
        static foreach_reverse ( i; 0 .. b.data.length - 1)
            ret.data[i .. i + alp1] = extendedMulAdd(a, b.data[i], UInt!sizeA(ret.data[i .. i + al])).data;
    }
    return ret;
}

/// ditto
UInt!(size + size_t.sizeof * 8)
    extendedMul(size_t size)(UInt!size a, size_t b)
{
    import mir.bignum.low_level_view;
    size_t overflow = BigUIntView!size_t(a.data) *= b;
    auto ret = a.toSize!(size + size_t.sizeof * 8);
    BigUIntView!size_t(ret.data).mostSignificantFirst.front = overflow;
    return ret;
}

/// ditto
UInt!128 extendedMul()(ulong a, ulong b)
{
    import mir.utility: extMul;
    auto e = extMul(a, b);
    version(LittleEndian)
        return typeof(return)([e.low, e.high]);
    else
        return typeof(return)([e.high, e.low]);
}

/// ditto
UInt!64 extendedMul()(uint a, uint b)
{
    static if (size_t.sizeof == uint.sizeof)
    {
        import mir.utility: extMul;
        auto e = extMul(a, b);
        version(LittleEndian)
            return typeof(return)([e.low, e.high]);
        else
            return typeof(return)([e.high, e.low]);
    }
    else
    {
        return typeof(return)([ulong(a) * b]);
    }
}

///
@safe pure @nogc
unittest
{
    auto a = UInt!128.max;
    auto b = UInt!256.max;
    auto c = UInt!384.max;
    assert(extendedMul(a, a) == UInt!256.max - UInt!128.max - UInt!128.max);
    assert(extendedMul(a, b) == UInt!384.max - UInt!128.max - UInt!256.max);
    assert(extendedMul(b, a) == UInt!384.max - UInt!128.max - UInt!256.max);

    a = UInt!128.fromHexString("dfbbfae3cd0aff2714a1de7022b0029d");
    b = UInt!256.fromHexString("3fe48f2dc8aad570d037bc9b323fc0cfa312fcc2f63cb521bd8a4ca6157ef619");
    c = UInt!384.fromHexString("37d7034b86e8d58a9fc564463fcedef9e2ad1126dd2c0f803e61c72852a9917ef74fa749e7936a9e4e224aeeaff91f55");
    assert(extendedMul(a, b) == c);
    assert(extendedMul(b, a) == c);

    a = UInt!128.fromHexString("23edf5ff44ee3a4feafc652607aa1eb9");
    b = UInt!256.fromHexString("d3d79144b8941fb50c9102e3251bacb112c88b71ad3f85a970a31458ce24297b");
    c = UInt!384.fromHexString("1dbb62fe6ca5fed101068eda7222d6a9857633ecdfed37a2d156ff6309065ecc633f31465727677a93a7acbd1dac63e3");
    assert(extendedMul(a, b) == c);
    assert(extendedMul(b, a) == c);
}

/// ulong
@safe pure @nogc
unittest
{
    ulong a = 0xdfbbfae3cd0aff27;
    ulong b = 0x14a1de7022b0029d;
    auto c = UInt!128.fromHexString("120827399968ea2a2db185d16e8cc8eb");
    assert(extendedMul(a, b) == c);
    assert(extendedMul(b, a) == c);
}

/// uint
@safe pure @nogc
unittest
{
    uint a = 0xdfbbfae3;
    uint b = 0xcd0aff27;
    auto c = UInt!64.fromHexString("b333243de8695595");
    assert(extendedMul(a, b) == c);
    assert(extendedMul(b, a) == c);
}

/++
+/
UInt!(size + size_t.sizeof * 8)
    extendedMulAdd(size_t size)(UInt!size a, size_t b, UInt!size c)
{
    import mir.bignum.low_level_view;
    auto ret = extendedMul(a, b);
    auto view = BigUIntView!size_t(ret.data);
    view.leastSignificantFirst.back += view.topLeastSignificantPart(a.data.length) += BigUIntView!size_t(c.data);
    return ret;
}
