/++
+/
module mir.bignum.fp;

import std.traits;
import mir.bitop;
import mir.utility;

/++
+/
struct Fp(size_t coefficientSize)
    if ((coefficientSize & 0x3F) == 0 && coefficientSize / (size_t.sizeof * 8) >= 1)
{
    import mir.bignum.fixed_int: UInt;

    bool sign;
    int exponent;
    UInt!coefficientSize coefficient;

@safe pure @nogc:

    /++
    +/
    nothrow
    this(bool sign, int exponent, UInt!coefficientSize normalizedCoefficient)
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
                this(false, int(size) - int(coefficientSize), integer.rightExtend!(coefficientSize - size));
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
                if (auto c = integer.ctlz)
                {
                    integer <<= c;
                    this.exponent -= c;
                }
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
                enum half(size_t hs) = (){ UInt!hs ret; ret.signBit = true; return ret; }();
                auto cr = integer.toSize!tailSize.opCmp(half!tailSize);
                version (LittleEndian)
                    auto inc = cr > 0 || cr == 0 && (coefficient.data[0] & 1);
                else
                    auto inc = cr > 0 || cr == 0 && (coefficient.data[$ - 1] & 1);
                if (inc)
                {
                    auto overflow = coefficient += 1;
                    if (overflow)
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

    // /++
    // +/
    // this(UInt, WordEndian endiand)(BigUIntView!(const UInt, endiand) integer)
    // {
    //     integer = integer.normalized;
    // }

    ///
    ref Fp opOpAssign(string op : "*")(Fp rhs) nothrow return
    {
        this = this.opBinary!"*"(rhs);
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
    T opCast(T)() nothrow const
        if (isFloatingPoint!T)
    {
        Unqual!T c = coefficient;
        if (sign)
            c = -c;
        return ldexp!(c, exponent);
    }

    static if (coefficientSize == 128)
    ///
    @safe pure @nogc
    unittest
    {
        // todo
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
