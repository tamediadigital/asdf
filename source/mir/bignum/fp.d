/++
+/
module mir.bignum.fp;

import std.traits;
import mir.bitop;
import mir.utility;

/++
+/
struct Fp(size_t matissaSize)
    if ((matissaSize & 0x3F) == 0 && matissaSize / (size_t.sizeof * 8) >= 1)
{
    import mir.bignum.fixed_int: UInt;

    bool sign;
    int exponent;
    UInt!matissaSize coefficient;

@safe pure nothrow @nogc:

    /++
    +/
    this(bool sign, int exponent, UInt!matissaSize coefficient)
    {
        this.coefficient = coefficient;
        this.exponent = exponent;
        this.sign = sign;
    }

    /++
    +/
    this(size_t size)(UInt!size integer, bool normalizedInteger = false)
    {
        import mir.bignum.fixed_int: UInt;
        static if (size < matissaSize)
        {
            if (normalizedInteger)
            {
                this.exponent = size - matissaSize;
                this.coefficient = integer.toSize!matissaSize;
            }
            else
            {
                this(integer.toSize!matissaSize, false);
            }
        }
        else
        {
            this.exponent = size - matissaSize;
            if (!normalizedInteger)
            {
                if (auto c = integer.ctlz)
                {
                    integer <<= c;
                    this.exponent -= c;
                }
            }
            static if (size == matissaSize)
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
                enum tailSize = size - matissaSize;
                enum half = (){ UInt!tailSize ret; ret.signBit = true; return ret; }();
                auto cr = integer.toSize!tailSize.opCmp(half);
                version (LittleEndian)
                    auto inc = cr > 0 || cr == 0 && (integer.data[0] & 1);
                else
                    auto inc = cr > 0 || cr == 0 && (integer.data[$ - 1] & 1);
                if (inc)
                {
                    auto overflow = coefficient += 1;
                    if (overflow)
                    {
                        coefficient = half;
                        exponent++;
                    }
                }
            }
        }
    }

    // /++
    // +/
    // this(UInt, WordEndian endiand)(BigUIntView!(const UInt, endiand) integer)
    // {
    //     integer = integer.normalized;
    // }

    ///
    ref Fp opOpAssign(string op : "*")(Fp rhs) return
    {
        this = this.opBinary!"*"(rhs);
        return this;
    }

    ///
    Fp opBinary(string op : "*")(Fp rhs) const
    {
        return .extendedMul(this, rhs).ieeeRound!matissaSize;
    }

    ///
    T opCast(T)() const
        if (is(Unqual!T == bool))
    {
        return coefficient != 0;
    }

    ///
    T opCast(T)() const
        if (isFloatingPoint!T)
    {
        Unqual!T c = coefficient;
        if (sign)
            c = -c;
        return ldexp!(c, exponent);
    }

    ///
    bool bt()(size_t position)
    {
        return BigUIntView!size_t(coefficient).bt(position);
    }

    ///
    Fp!newMatntissaSize ieeeRound(size_t newMatntissaSize)() const
    {
        auto ret = typeof(return)(coefficient, true);
        ret.exponent += exponent;
        ret.sign = sign;
        return ret;
    }
}

///
Fp!(matissaSizeA + matissaSizeB) extendedMul(size_t matissaSizeA, size_t matissaSizeB)(Fp!matissaSizeA a, Fp!matissaSizeB b)
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
