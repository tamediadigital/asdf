/++
+/
module mir.bignum.fp;

import std.traits;
import mir.bitop;
import mir.utility;

private enum half(size_t hs) = (){
    import mir.bignum.fixed_int: UInt;
    UInt!hs ret; ret.signBit = true; return ret;
}();

/++
+/
struct Fp(size_t coefficientSize)
    if (coefficientSize % 64 == 0 && coefficientSize >= 64)
{
    import mir.bignum.fixed_int: UInt;
    import mir.bignum.low_level_view: BigUIntView, BigIntView, WordEndian;

    bool sign;
    sizediff_t exponent;
    UInt!coefficientSize coefficient;

    /++
    +/
    nothrow
    this(bool sign, sizediff_t exponent, UInt!coefficientSize normalizedCoefficient)
    {
        this.coefficient = normalizedCoefficient;
        this.exponent = exponent;
        this.sign = sign;
    }

    /++
    +/
    this(size_t size)(UInt!size integer, bool normalizedInteger = false)
        // nothrow
    {
        import mir.bignum.fixed_int: UInt;
        static if (size < coefficientSize)
        {
            if (normalizedInteger)
            {
                this(false, sizediff_t(size) - coefficientSize, integer.rightExtend!(coefficientSize - size));
            }
            else
            {
                this(integer.toSize!coefficientSize, false);
            }
        }
        else
        {
            this.exponent = size - coefficientSize;
            if (!normalizedInteger)
            {
                auto c = integer.ctlz;
                integer <<= c;
                this.exponent -= c;
            }
            static if (size == coefficientSize)
            {
                coefficient = integer;
            }
            else
            {
                enum N = coefficient.data.length;
                version (LittleEndian)
                    coefficient.data = integer.data[$ - N .. $];
                else
                    coefficient.data = integer.data[0 .. N];
                enum tailSize = size - coefficientSize;
                auto cr = integer.toSize!tailSize.opCmp(half!tailSize);
                if (cr > 0 || cr == 0 && coefficient.bt(0))
                {
                    if (auto overflow = coefficient += 1)
                    {
                        coefficient = half!coefficientSize;
                        exponent++;
                    }
                }
            }
        }
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto fp = Fp!128(UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));
        assert(fp.exponent == 0);
        assert(fp.coefficient == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));

        fp = Fp!128(UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"), true);
        assert(fp.exponent == 0);
        assert(fp.coefficient == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));

        fp = Fp!128(UInt!128.fromHexString("ae3cd0aff2714a1de7022b0029d"));
        assert(fp.exponent == -20);
        assert(fp.coefficient == UInt!128.fromHexString("ae3cd0aff2714a1de7022b0029d00000"));

        fp = Fp!128(UInt!128.fromHexString("e7022b0029d"));
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));

        fp = Fp!128(UInt!64.fromHexString("e7022b0029d"));
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));

        fp = Fp!128(UInt!64.fromHexString("e7022b0029dd0aff"), true);
        assert(fp.exponent == -64);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029dd0aff0000000000000000"));

        fp = Fp!128(UInt!64.fromHexString("e7022b0029d"));
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));
    
        fp = Fp!128(UInt!192.fromHexString("ffffffffffffffffffffffffffffffff1000000000000000"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("ffffffffffffffffffffffffffffffff"));

        fp = Fp!128(UInt!192.fromHexString("ffffffffffffffffffffffffffffffff8000000000000000"));
        assert(fp.exponent == 65);
        assert(fp.coefficient == UInt!128.fromHexString("80000000000000000000000000000000"));

        fp = Fp!128(UInt!192.fromHexString("fffffffffffffffffffffffffffffffe8000000000000000"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("fffffffffffffffffffffffffffffffe"));

        fp = Fp!128(UInt!192.fromHexString("fffffffffffffffffffffffffffffffe8000000000000001"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("ffffffffffffffffffffffffffffffff"));
    }

    /++
    +/
    this(UInt, WordEndian endian)(BigIntView!(const UInt, endian) integer)
    {
        this(integer.unsigned);
        this.sign = integer.sign;
    }

    static if (coefficientSize == 128)
    ///
    @safe pure
    unittest
    {
        import mir.bignum.low_level_view: BigUIntView;

        auto fp = Fp!128(-BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));
        assert(fp.sign);
        assert(fp.exponent == 0);
        assert(fp.coefficient == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));
    }

    /++
    +/
    this(UInt, WordEndian endian)(BigUIntView!(const UInt, endian) integer)
    {
        ctorImpl(integer);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure
    unittest
    {
        import mir.bignum.low_level_view: BigUIntView;

        auto fp = Fp!128(BigUIntView!ulong.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));
        assert(fp.exponent == 0);
        assert(fp.coefficient == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));

        fp = Fp!128(BigUIntView!uint.fromHexString("ae3cd0aff2714a1de7022b0029d"));
        assert(fp.exponent == -20);
        assert(fp.coefficient == UInt!128.fromHexString("ae3cd0aff2714a1de7022b0029d00000"));

        fp = Fp!128(BigUIntView!ushort.fromHexString("e7022b0029d"));
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));

        fp = Fp!128(BigUIntView!ubyte.fromHexString("e7022b0029d"));
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));

        fp = Fp!128(BigUIntView!size_t.fromHexString("e7022b0029d"));
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));
    
        fp = Fp!128(BigUIntView!size_t.fromHexString("ffffffffffffffffffffffffffffffff1000000000000000"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("ffffffffffffffffffffffffffffffff"));

        fp = Fp!128(BigUIntView!size_t.fromHexString("ffffffffffffffffffffffffffffffff8000000000000000"));
        assert(fp.exponent == 65);
        assert(fp.coefficient == UInt!128.fromHexString("80000000000000000000000000000000"));

        fp = Fp!128(BigUIntView!size_t.fromHexString("fffffffffffffffffffffffffffffffe8000000000000000"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("fffffffffffffffffffffffffffffffe"));

        fp = Fp!128(BigUIntView!size_t.fromHexString("fffffffffffffffffffffffffffffffe8000000000000001"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("ffffffffffffffffffffffffffffffff"));
    }

    package void ctorImpl(size_t internalRoundLastBits = 0, bool wordNormalized = false, bool nonZero = false, UInt, WordEndian endian)(BigUIntView!(const UInt, endian) integer)
        if (internalRoundLastBits < size_t.sizeof * 8 && (size_t.sizeof >= UInt.sizeof || endian == TargetEndian))
    {
        static if (UInt.sizeof > size_t.sizeof)
        {
            ctorImpl!internalRoundLastBits(integer.coefficientsCast!size_t, false, nonZero);
        }
        else
        {
            static if (!wordNormalized)
                integer = integer.normalized;
            static if (!nonZero)
                if (integer.coefficients.length == 0)
                    return;
            assert(integer.coefficients.length);
            enum N = coefficient.data.length;
            auto ms = integer.mostSignificant;
            auto c = cast(uint) ctlz(ms);
            sizediff_t size = integer.coefficients.length * (UInt.sizeof * 8);
            sizediff_t expShift = size - coefficientSize;
            this.exponent = expShift - c;
            if (_expect(expShift <= 0, true))
            {
                static if (N == 1 && UInt.sizeof == size_t.sizeof)
                {
                    coefficient.data[0] = ms;
                }
                else
                {
                    BigUIntView!size_t(coefficient.data)
                        .coefficientsCast!UInt
                        .leastSignificantFirst
                            [$ - integer.coefficients.length .. $] = integer.leastSignificantFirst;
                }
                coefficient = coefficient.smallLeftShift(c);
            }
            else
            {
                mir.bignum.fixed_int.UInt!(coefficientSize + size_t.sizeof * 8) holder;

                static if (N == 1 && UInt.sizeof == size_t.sizeof)
                {
                    version (BigEndian)
                    {
                        holder.data[0] = ms;
                        holder.data[1] = integer.mostSignificantFirst[1];
                    }
                    else
                    {
                        holder.data[0] = integer.mostSignificantFirst[1];
                        holder.data[1] = ms;
                    }
                }
                else
                {
                    auto holderView = BigUIntView!size_t(holder.data)
                        .coefficientsCast!UInt
                        .leastSignificantFirst;
                    holderView[] = integer.leastSignificantFirst[$ - holderView.length .. $];
                }

                bool nonZeroTail()
                {
                    while(_expect(integer.leastSignificant == 0, false))
                    {
                        integer.popLeastSignificant;
                        assert(integer.coefficients.length);
                    }
                    return integer.coefficients.length > (N + 1) * (size_t.sizeof / UInt.sizeof);
                }

                holder = holder.smallLeftShift(c);
                version (BigEndian)
                    coefficient.data = holder.data[0 .. $ - 1];
                else
                    coefficient.data = holder.data[1 .. $];
                auto tail = BigUIntView!size_t(holder.data).leastSignificant;

                static if (internalRoundLastBits)
                {
                    enum half = size_t(1) << (internalRoundLastBits - 1);
                    enum mask0 = (size_t(1) << internalRoundLastBits) - 1;
                    auto tail0 = BigUIntView!size_t(coefficient.data).leastSignificant & mask0;
                    BigUIntView!size_t(coefficient.data).leastSignificant &= ~mask0;
                    auto condInc = tail0 >= half
                        && (   tail0 > half
                            || tail
                            || (BigUIntView!size_t(coefficient.data).leastSignificant & 1)
                            || nonZeroTail);
                }
                else
                {
                    enum half = cast(size_t)Signed!size_t.min;
                    auto condInc = tail >= half
                        && (    tail > half
                            || (BigUIntView!size_t(coefficient.data).leastSignificant & 1)
                            || nonZeroTail);
                }

                if (condInc)
                {
                    enum inc = size_t(1) << internalRoundLastBits;
                    if (auto overflow = coefficient += inc)
                    {
                        coefficient = .half!coefficientSize;
                        exponent++;
                    }
                }
            }
        }
    }

    ///
    ref Fp opOpAssign(string op : "*")(Fp rhs) nothrow return
    {
        this = this.opBinary!op(rhs);
        return this;
    }

    ///
    Fp opBinary(string op : "*")(Fp rhs) nothrow const
    {
        return cast(Fp) .extendedMul(this, rhs);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto a = Fp!128(0, -13, UInt!128.fromHexString("dfbbfae3cd0aff2714a1de7022b0029d"));
        auto b = Fp!128(1, 100, UInt!128.fromHexString("e3251bacb112c88b71ad3f85a970a314"));
        auto fp = a * b;
        assert(fp.sign);
        assert(fp.exponent == 100 - 13 + 128);
        assert(fp.coefficient == UInt!128.fromHexString("c6841dd302415d785373ab6d93712988"));
    }

    ///
    T opCast(T)() nothrow const
        if (is(Unqual!T == bool))
    {
        return coefficient != 0;
    }

    ///
    T opCast(T, bool noHalf = false)() nothrow const
        if (isFloatingPoint!T)
    {
        import mir.math.ieee: ldexp;
        auto exp = cast()exponent;
        static if (coefficientSize == 32)
        {
            Unqual!T c = cast(uint) coefficient;
        }
        else
        static if (coefficientSize == 64)
        {
            Unqual!T c = cast(ulong) coefficient;
        }
        else
        {
            enum rMask = (UInt!coefficientSize(1) << (coefficientSize - T.mant_dig)) - UInt!coefficientSize(1);
            enum rHalf = UInt!coefficientSize(1) << (coefficientSize - T.mant_dig - 1);
            enum rInc = UInt!coefficientSize(1) << (coefficientSize - T.mant_dig);
            UInt!coefficientSize adC = coefficient;
            static if (!noHalf)
            {
                auto cr = (coefficient & rMask).opCmp(rHalf);
                if ((cr > 0) | (cr == 0) & coefficient.bt(T.mant_dig))
                {
                    if (auto overflow = adC += rInc)
                    {
                        adC = half!coefficientSize;
                        exp++;
                    }
                }
            }
            adC >>= coefficientSize - T.mant_dig;
            exp += coefficientSize - T.mant_dig;
            Unqual!T c = cast(ulong) adC;
            static if (T.mant_dig > 64) //
            {
                static assert (T.mant_dig <= 128);
                c += ldexp(cast(T) cast(ulong) (adC >> 64), 64);
            }
        }
        if (sign)
            c = -c;
        static if (exp.sizeof > int.sizeof)
        {
            import mir.utility: min, max;
            exp = exp.max(int.min).min(int.max);
        }
        return ldexp(c, cast(int)exp);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto fp = Fp!128(1, 100, UInt!128.fromHexString("e3251bacb112cb8b71ad3f85a970a314"));
        assert(cast(double)fp == -0xE3251BACB112C8p+172);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto fp = Fp!128(1, 100, UInt!128.fromHexString("e3251bacb112cb8b71ad3f85a970a314"));
        static if (real.mant_dig == 64)
            assert(cast(real)fp == -0xe3251bacb112cb8bp+164L);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto fp = Fp!64(1, 100, UInt!64(0xe3251bacb112cb8b));
        assert(cast(double)fp == -0xE3251BACB112C8p+108);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto fp = Fp!64(1, 100, UInt!64(0xe3251bacb112cb8b));
        static if (real.mant_dig == 64)
            assert(cast(real)fp == -0xe3251bacb112cb8bp+100L);
    }

    ///
    T opCast(T : Fp!newCoefficientSize, size_t newCoefficientSize)() nothrow const
    {
        auto ret = Fp!newCoefficientSize(coefficient, true);
        ret.exponent += exponent;
        ret.sign = sign;
        return ret;
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        auto fp = cast(Fp!64) Fp!128(UInt!128.fromHexString("afbbfae3cd0aff2784a1de7022b0029d"));
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!64.fromHexString("afbbfae3cd0aff28"));
    }
}

///
Fp!(coefficientizeA + coefficientizeB) extendedMul(size_t coefficientizeA, size_t coefficientizeB)(Fp!coefficientizeA a, Fp!coefficientizeB b)
    @safe pure nothrow @nogc
{
    import mir.bignum.fixed_int: extendedMul;
    auto coefficient = extendedMul(a.coefficient, b.coefficient);
    auto exponent = a.exponent + b.exponent;
    auto sign = a.sign ^ b.sign;
    if (!coefficient.signBit)
    {
        --exponent;
        coefficient = coefficient.smallLeftShift(1);
    }
    return typeof(return)(sign, exponent, coefficient);
}
