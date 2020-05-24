/++
+/
module mir.bignum.fp;

import std.traits;
import mir.bitop;
import mir.utility;

struct UInt(size_t size)
    if ((size & 0x3F) == 0 && size / (size_t.sizeof * 8) > 1)
{
    ///
    size_t[size / (size_t.sizeof * 8)] data;

    /++
    +/
    bool opOpAssign(string op)(UInt rhs, bool overflow = false)
        @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        import mir.bignum.low_level_view;
        return BigUIntView!size_t(data).opOpAssign!op(BigUIntView!size_t(rhs.data), overflow);
    }

    /++
    +/
    UInt opBinary(string op)(UInt rhs)
        const @safe pure nothrow @nogc
    {
        UInt ret = this;
        ret.opOpAssign!op(rhs);
        return ret;
    }

    UInt!(newSize) toSize(size_t newSize)()
    {
        typeof(return) ret;
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
UInt!(size + size_t.sizeof * 8)
    extendedMul(size_t size)(UInt!size a, size_t b)
{
    import mir.bignum.low_level_view;
    size_t overflow = BigUIntView!size_t(a.data) *= b;
    auto ret = a.toSize!(size + size_t.sizeof * 8);
    BigUIntView!size_t(ret.data).mostSignificantFirst.front = overflow;
    return ret;
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

alias D = extendedMul!(256, 128);

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
