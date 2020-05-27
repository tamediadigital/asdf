/++
+/
module mir.bignum.fp;

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
    bool opOpAssign(string op, size_t rsize)(UInt!rsize rhs, bool overflow = false)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && rsize < size)
    {
        return opOpAssign!op(rhs.toSize!size);
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
    Returns:
        the number with shrinked on extended size.
    +/
    UInt!(newSize) toSize(size_t newSize)()
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

/++
+/
struct Fp(T)
    if (isUnsigned!T && T.sizeof >= 4)
{
    bool sign;
    int exponent;
    T coefficient;

@safe pure nothrow @nogc:

    /++
    +/
    this(bool sign, int exponent, T coefficient)
    {
        this.coefficient = coefficient;
        this.exponent = exponent;
        this.sign = sign;
    }

    ///
    ref Fp opOpAssign(string op : "*")(Fp rhs) return
    {
        this = this * rhs;
        return this;
    }

    ///
    Fp opBinary(string op : "*")(Fp rhs) const
    {
        import mir.checkedint: addu;
        auto lhs = this;
        auto mulResult = extMul(lhs.coefficient, rhs.coefficient);
        int resultExp = lhs.exponent + rhs.exponent;
        auto c = (mulResult.high >> (T.sizeof * 8 - 1)) == 0;
        mulResult.high <<= c;
        auto d = T.sizeof * 8 - c;
        resultExp += d;
        mulResult.high |= mulResult.low >>> d;
        mulResult.low <<= c;
        enum half = T(1) << (T.sizeof * 8 - 1);
        auto carry = (mulResult.low > half) | ((mulResult.low == half) & mulResult.high);
        bool overflow;
        mulResult.high = addu(mulResult.high, carry, overflow);
        resultExp += overflow;
        if (overflow)
            mulResult.high = half;
        return Fp(lhs.sign ^ rhs.sign, resultExp, mulResult.high);
    }

    ///
    T opCast(T)()
        if (is(Unqual!T == bool))
    {
        return coefficient != 0;
    }

    ///
    T opCast(T)()
        if (isFloatingPoint!T)
    {
        Unqual!T c = coefficient;
        if (sign)
            c = -c;
        // TODO: optimise
        return ldexp!(c, exponent);
    }
}
