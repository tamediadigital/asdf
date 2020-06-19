module mir.internal.dec2flt;

import mir.bignum.fp;
import mir.bignum.fixed;
import std.traits;
import mir.utility: _expect, extMul;
import mir.bignum.low_level_view;
/++
+/

Fp!64 approxPow10(int exp)
{
    import mir.internal.dec2flt_table;
    enum S = 9;
    enum P = 1 << (S - 1);
    static assert(min_p10_e <= -P);
    static assert(max_p10_e >= P);
    auto index = exp & 0x1F;
    auto p = Fp!64(false, p10_exponents[index - min_p10_e], UInt!64(p10_coefficients[index - min_p10_e][0]));
    exp >>= S;
    if (_expect(exp == 0, true))
    {
        return p;
    }
    else
    {
        exp   = exp < 0 ? -exp : exp;
        index = exp < 0 ? -P : P;
        auto v = Fp!64(false, p10_exponents[index - min_p10_e], UInt!64(p10_coefficients[index - min_p10_e][0]));
        do
        {
            if (exp & 1)
                p *= v;
            exp >>>= 1;
            if (exp == 0)
                return p;
            v *= v;
        }
        while(true);
    }
}

T decimalToFloat(T, UInt, WordEndian endian)(BigUInt!(size_t, endian)[] f, int e)
    if (isFloatingPoint!T && T.mant_dig <= 64)
{
    assert(f.length);
    enum expv = (1UL << (64 - T.mant_dig));
    enum mask = expv - 1;
    enum half = expv >> 1;
    auto slop = (f.length > (ulong.sizeof / size_t.sizeof)) + 3 * (exp < 0);
    auto z = bigUIntToFp(f) * approxPow10(e);
    auto ret = cast(Unqual!T) z;
    if (_expect((z.coefficient & mask - half) <= slop || T.mant_dig == 64, T.mant_dig == 64))
    {
        if (exp)
        ret = algorithmR(f, e, ret);
    }
    return ret;
}
