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
    if (size % (size_t.sizeof * 8) == 0 && size >= (size_t.sizeof * 8))
{
    /++
    Payload. The data is located in the target endianness.
    +/
    size_t[size / (size_t.sizeof * 8)] data;

    ///
    this(size_t N)(size_t[N] data)
        if (N <= this.data.length)
    {
        version(LittleEndian)
            this.data[0 .. N] = data;
        else
            this.data[$ - N .. $] = data;
    }

    static if (size >= 64)
    ///
    this(ulong data)
    {
        import mir.bignum.low_level_view;
        auto d = BigUIntView!size_t(this.data).leastSignificantFirst;
        static if (size_t.sizeof == ulong.sizeof)
        {
            d.front = data;
        }
        else
        {
            d.front = cast(uint) data;
            d[1] = cast(uint) (data >> 32);
        }
    }

    static if (size < 64)
    ///
    this(uint data)
    {
        import mir.bignum.low_level_view;
        BigUIntView!size_t(this.data).leastSignificant = data;
    }

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
    ref UInt opOpAssign(string op)(UInt rhs) nothrow return
        if (op == "^" || op == "|" || op == "&")
    {
        static foreach (i; 0 .. data.length)
           mixin(`data[i] ` ~ op ~ `= rhs.data[i];`);
        return this;
    }

    static if (size == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = UInt!128.fromHexString("dfbbfae3cd0aff2714a1de7022b0029d");
        auto b = UInt!128.fromHexString("e3251bacb112c88b71ad3f85a970a314");
        assert((a.opBinary!"|"(b)) == UInt!128.fromHexString("ffbffbeffd1affaf75adfff5abf0a39d"));
    }

    ///
    ref UInt opOpAssign(string op)(size_t shift)
        @safe pure nothrow @nogc return
        if (op == "<<" || op == ">>>" || op == ">>")
    {
        import mir.bignum.low_level_view;
        auto d = BigUIntView!size_t(data).leastSignificantFirst;
        assert(shift < size);
        auto index = shift / (size_t.sizeof * 8);
        auto bs = shift % (size_t.sizeof * 8);
        auto ss = size_t.sizeof * 8 - bs;
        static if (op == ">>>" || op == ">>")
        {
            if (bs)
            {
                foreach (j; 0 .. data.length - (index + 1))
                {
                    d[j] = (d[j + index] >>> bs) | (d[j + (index + 1)] << ss);
                }
            }
            else
            {
                foreach (j; 0 .. data.length - (index + 1))
                {
                    d[j] = d[j + index];
                }
            }
            d[$ - (index + 1)] = d.back >>> bs;
            foreach (j; data.length - index .. data.length)
            {
                d[j] = 0;
            }
        }
        else
        {
            if (bs)
            {
                foreach_reverse (j; index + 1 .. data.length)
                {
                    d[j] = (d[j - index] << bs) | (d[j - (index + 1)] >> ss);
                }
            }
            else
            {
                foreach_reverse (j; index + 1 .. data.length)
                {
                    d[j] = d[j - index];
                }
            }
            d[index] = d.front << bs;
            foreach_reverse (j; 0 .. index)
            {
                d[j] = 0;
            }
        }
        return this;
    }

    /++
    `auto c = a << b` operation.
    +/
    UInt opBinary(string op)(size_t rhs)
        const @safe pure nothrow @nogc
        if (op == "<<" || op == ">>>" || op == ">>")
    {
        UInt ret = this;
        ret.opOpAssign!op(rhs);
        return ret;
    }

    static if (size == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(a << 0 == a);
        assert(a << 4 == UInt!128.fromHexString("fbbfae3cd0aff2714a1de7022b0029d0"));
        assert(a << 68 == UInt!128.fromHexString("4a1de7022b0029d00000000000000000"));
        assert(a << 127 == UInt!128.fromHexString("80000000000000000000000000000000"));
        assert(a >> 0 == a);
        assert(a >> 4 == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029"));
        assert(a >> 68 == UInt!128.fromHexString("afbbfae3cd0aff2"));
        assert(a >> 127 == UInt!128(1));
    }

    /++
    `auto c = a << b`, and `^`, `|`, `&` operations.
    +/
    UInt opBinary(string op)(UInt rhs)
        const @safe pure nothrow @nogc
        if (op == "^" || op == "|" || op == "&")
    {
        UInt ret = this;
        ret.opOpAssign!op(rhs);
        return ret;
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
    Shifts left using at most `size_t.sizeof * 8 - 1` bits
    +/
    UInt smallLeftShift()(uint shift) const
    {
        assert(shift < size_t.sizeof * 8);
        UInt ret = this;
        if (shift)
        {
            auto csh = size_t.sizeof * 8 - shift;
            version (LittleEndian)
            {
                static foreach_reverse (i; 1 .. data.length)
                {
                    ret.data[i] = (ret.data[i] << shift) | (ret.data[i - 1] >>> csh);
                }
                ret.data[0] = ret.data[0] << shift;
            }
            else
            {
                static foreach (i; 0 .. data.length - 1)
                {
                    ret.data[i] = (ret.data[i] << shift) | (ret.data[i + 1] >>> csh);
                }
                ret.data[$ - 1] = ret.data[$ - 1] << shift;
            }
        }
        return ret;
    }

    static if (size == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(a.smallLeftShift(4) == UInt!128.fromHexString("fbbfae3cd0aff2714a1de7022b0029d0"));
    }

    /++
    Shifts right using at most `size_t.sizeof * 8 - 1` bits
    +/
    UInt smallRightShift()(uint shift) const
    {
        assert(shift < size_t.sizeof * 8);
        UInt ret = this;
        if (shift)
        {
            auto csh = size_t.sizeof * 8 - shift;
            version (LittleEndian)
            {
                static foreach (i; 0 .. data.length - 1)
                {
                    ret.data[i] = (ret.data[i] >>> shift) | (ret.data[i + 1] << csh);
                }
                ret.data[$ - 1] = ret.data[$ - 1] >>> shift;
            }
            else
            {
                static foreach_reverse (i; 1 .. data.length)
                {
                    ret.data[i] = (ret.data[i] >>> shift) | (ret.data[i - 1] << csh);
                }
                ret.data[0] = ret.data[0] >>> shift;
            }
        }
        return ret;
    }

    static if (size == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(a.smallRightShift(4) == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029"));
    }

    /++
    +/
    ulong opCast(T)() const
        if (is(Unqual!T == ulong))
    {
        import mir.bignum.low_level_view;
        auto d = BigUIntView!(const size_t)(data).leastSignificantFirst;
        static if (size_t.sizeof == ulong.sizeof)
        {
            return d.front;
        }
        else
        {
            return d.front | (ulong(d[1]) << 32);
        }
    }

    /++
    Returns:
        the number with shrinked or extended size.
    +/
    UInt!newSize toSize(size_t newSize)()
        const @safe pure @nogc nothrow
    {
        typeof(return) ret;
        import mir.utility: min;
        enum N = min(ret.data.length, data.length);
        version (LittleEndian)
            ret.data[0 .. N] = data[0 .. N];
        else
            ret.data[$ - N .. $] = data[$ - N .. $];
        return ret;
    }

    ///
    UInt!(size + additionalRightBits) rightExtend(size_t additionalRightBits)()
        const @safe pure @nogc nothrow
        if (additionalRightBits)
    {
        typeof(return) ret;
        version (BigEndian)
            ret.data[0 .. data.length] = data;
        else
            ret.data[$ - data.length .. $] = data;
        return ret;
    }

    /++
    +/
    bool bt()(size_t position) const
        @safe pure nothrow @nogc
    {
        import mir.bignum.low_level_view;
        assert(position < data.sizeof * 8);
        return BigUIntView!(const size_t)(data).bt(position);
    }

    static if (size == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(a.bt(127) == 1);
        assert(a.bt(126) == 0);
        assert(a.bt(125) == 1);
        assert(a.bt(124) == 0);
        assert(a.bt(0) == 1);
        assert(a.bt(1) == 0);
        assert(a.bt(2) == 1);
        assert(a.bt(3) == 1);
    }

    /++
    +/
    size_t ctlz()() const @property
        @safe pure nothrow @nogc
    {
        import mir.bignum.low_level_view;
        return BigUIntView!(const size_t)(data).ctlz;
    }

    static if (size == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = UInt!128.fromHexString("dfbbfae3cd0aff2714a1de7022b0029d");
        assert (a.ctlz == 0);
        a = UInt!128.init;
        assert (a.ctlz == 128);
        a = UInt!128.fromHexString("3");
        assert (a.ctlz == 126);
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

    /// ditto
    void signBit()(bool value) @property
    {
        enum signMask = ptrdiff_t.max;
        version (LittleEndian)
            data[$ - 1] = (data[$ - 1] & ptrdiff_t.max) | (size_t(value) << (size_t.sizeof * 8 - 1));
        else
            data[    0] = (data[    0] & ptrdiff_t.max) | (size_t(value) << (size_t.sizeof * 8 - 1));
    }

    ///
    unittest
    {
        auto a = UInt!128.fromHexString("dfbbfae3cd0aff2714a1de7022b0029d");
        assert(a.signBit);
        a.signBit = false;
        assert(a == UInt!128.fromHexString("5fbbfae3cd0aff2714a1de7022b0029d"));
        assert(!a.signBit);
        a.signBit = true;
        assert(a == UInt!128.fromHexString("dfbbfae3cd0aff2714a1de7022b0029d"));
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
    import mir.bignum.low_level_view: BigUIntView;
    size_t overflow = BigUIntView!size_t(a.data) *= b;
    auto ret = a.toSize!(size + size_t.sizeof * 8);
    BigUIntView!size_t(ret.data).mostSignificant = overflow;
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
    view.mostSignificant += view.topLeastSignificantPart(a.data.length) += BigUIntView!size_t(c.data);
    return ret;
}
