module mir.internal.dec2flt;

import std.traits;
import mir.utility: _expect, extMul;
/++
+/
struct SoftFloat(T)
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
    ref SoftFloat opOpAssign(string op : "*")(SoftFloat rhs) return
    {
        this = this * rhs;
        return this;
    }

    ///
    SoftFloat opBinary(string op : "*")(SoftFloat rhs) const
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
        return SoftFloat(lhs.sign ^ rhs.sign, resultExp, mulResult.high);
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

SoftFloat!ulong approxPow10(int exp)
{
    import mir.internal.dec2flt_table;
    enum S = 9;
    enum P = 1 << (S - 1);
    static assert(min_p10_e <= -P);
    static assert(max_p10_e >= P);
    auto index = exp & 0x1F;
    auto p = SoftFloat!ulong(false, p10_exponents[index - min_p10_e], p10_coefficients[index - min_p10_e]);
    exp >>= S;
    if (_expect(exp == 0, true))
    {
        return p;
    }
    else
    {
        exp   = exp < 0 ? -exp : exp;
        index = exp < 0 ? -P : P;
        auto v = SoftFloat!ulong(false, p10_exponents[index - min_p10_e], p10_coefficients[index - min_p10_e]);
        do
        {
            if (exp & 1)
                p *= v;
            exp >>= 1;
            if (exp == 0)
                return p;
            v *= v;
        }
        while(true);
    }
}

T decimalToFloat(T)(size_t[] f, short e, out bool infinity)
    if (isFloatingPoint!T && T.mant_dig <= 64)
{
    enum expv = (1UL << (64 - T.mant_dig));
    enum mask = expv - 1;
    enum half = expv >> 1;

    auto slop = (f.length <= (ulong.sizeof / size_t.sizeof)) + 3 * (exp < 0);
    auto z = bigUIntToSoftFloat(f) * approxPow10(e);
    auto ret = cast(T) z;
    if (_expect((z.coefficient & mask - half) <= slop || T.mant_dig == 64, T.mant_dig == 64))
    {
        if (exp)
        ret = algorithmR(f, e, ret);
    }
    return ret;
}
