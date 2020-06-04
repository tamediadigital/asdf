/++
Low-level betterC utilities for big integer arithmetic libraries.

The module provides $(REF BigUIntAccumulator), $(REF BigUIntView), and $(LREF BigIntView).
+/
module mir.bignum.low_level_view;

import mir.checkedint;
import std.traits;

private alias cop(string op : "-") = subu;
private alias cop(string op : "+") = addu;
private enum inverseSign(string op) = op == "+" ? "-" : "+";

private immutable hexStringErrorMsg = "Incorrect hex string for UInt.fromHexString";
version (D_Exceptions)
{
    private immutable hexStringException = new Exception(hexStringErrorMsg);
}

/++
+/
enum WordEndian
{
    ///
    little,
    ///
    big,
}

version(LittleEndian)
{
    /++
    +/
    enum TargetEndian = WordEndian.little;
}
else
{
    /++
    +/
    enum TargetEndian = WordEndian.big;
}

private template MaxWordPow5(T)
{
    static if (is(T == ubyte))
        enum MaxWordPow5 = 3;
    else
    static if (is(T == ushort))
        enum MaxWordPow5 = 6;
    else
    static if (is(T == uint))
        enum MaxWordPow5 = 13;
    else
    static if (is(T == ulong))
        enum MaxWordPow5 = 27;
    else
        static assert(0);
}

private template MaxFpPow5(T)
{
    static if (T.mant_dig == 24)
        enum MaxWordPow5 = 6;
    else
    static if (T.mant_dig == 53)
        enum MaxWordPow5 = 10;
    else
    static if (T.mant_dig == 64)
        enum MaxWordPow5 = 27;
    else
    static if (T.mant_dig == 113)
        enum MaxWordPow5 = 48;
    else
        static assert(0, "floating point format isn't supported");
}

/++
Arbitrary length unsigned integer view.
+/
struct BigUIntView(UInt, WordEndian endian = TargetEndian)
    if (__traits(isUnsigned, UInt) || !(UInt.size == 1 && endian != TargetEndian))
{
    import mir.bignum.fp: Fp, half;

    /++
    A group of coefficients for a radix `UInt.max + 1`.

    The order corresponds to endianness.
    +/
    UInt[] coefficients;

    /++
    Retrurns: signed integer view using the same data payload
    +/
    BigIntView!(UInt, endian) signed() @safe pure nothrow @nogc @property
    {
        return typeof(return)(this);
    }

    /++
    +/
    BigUIntView!(NewUInt, NewUInt.sizeof == 1 ? TargetEndian : endian)
        coefficientsCast(NewUInt)()
        pure nothrow @nogc
        if (NewUInt.sizeof <= UInt.sizeof && (NewUInt.sizeof == 1 || NewUInt.sizeof == UInt.sizeof || endian == TargetEndian))
    {
        return typeof(return)(cast(NewUInt[])coefficients);
    }

    ///
    T opCast(T, bool wordNormalized = false, bool nonZero = false)() const
        if (isFloatingPoint!T)
    {
        import mir.bignum.fp;
        enum md = T.mant_dig;
        enum b = size_t.sizeof * 8;
        enum n = md / b + (md % b != 0);
        enum s = n * b;
        return opCast!(Fp!s, s - md, wordNormalized, nonZero).opCast!(T, true);
    }

    static if (UInt.sizeof == size_t.sizeof && endian == TargetEndian)
    ///
    unittest
    {
        auto a = cast(double) BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(a == 0xa.fbbfae3cd0bp+124);
        assert(cast(double) BigUIntView!size_t.init == 0);
        assert(cast(double) BigUIntView!size_t([0]) == 0);
    }

    ///
    T opCast(T : Fp!coefficientSize, size_t internalRoundLastBits = 0, bool wordNormalized = false, bool nonZero = false, size_t coefficientSize)() const
        if (internalRoundLastBits < size_t.sizeof * 8 && (size_t.sizeof >= UInt.sizeof || endian == TargetEndian))
    {
        static if (isMutable!UInt)
        {
            return lightConst.opCast!(T, internalRoundLastBits, wordNormalized, nonZero);
        }
        else
        static if (UInt.sizeof > size_t.sizeof)
        {
            integer.coefficientsCast!size_t.opCast!(internalRoundLastBits, false, nonZero);
        }
        else
        {
            import mir.utility: _expect;
            import mir.bitop: ctlz;
            Fp!coefficientSize ret;
            auto integer = lightConst;
            static if (!wordNormalized)
                integer = integer.normalized;
            static if (!nonZero)
                if (integer.coefficients.length == 0)
                    goto R;
            {
                assert(integer.coefficients.length);
                enum N = ret.coefficient.data.length;
                auto ms = integer.mostSignificant;
                auto c = cast(uint) ctlz(ms);
                sizediff_t size = integer.coefficients.length * (UInt.sizeof * 8);
                sizediff_t expShift = size - coefficientSize;
                ret.exponent = expShift - c;
                if (_expect(expShift <= 0, true))
                {
                    static if (N == 1 && UInt.sizeof == size_t.sizeof)
                    {
                        ret.coefficient.data[0] = ms;
                    }
                    else
                    {
                        BigUIntView!size_t(ret.coefficient.data)
                            .coefficientsCast!(Unqual!UInt)
                            .leastSignificantFirst
                                [$ - integer.coefficients.length .. $] = integer.leastSignificantFirst;
                    }
                    ret.coefficient = ret.coefficient.smallLeftShift(c);
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
                            .coefficientsCast!(Unqual!UInt)
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
                        ret.coefficient.data = holder.data[0 .. $ - 1];
                    else
                        ret.coefficient.data = holder.data[1 .. $];
                    auto tail = BigUIntView!size_t(holder.data).leastSignificant;

                    static if (internalRoundLastBits)
                    {
                        enum half = size_t(1) << (internalRoundLastBits - 1);
                        enum mask0 = (size_t(1) << internalRoundLastBits) - 1;
                        auto tail0 = BigUIntView!size_t(ret.coefficient.data).leastSignificant & mask0;
                        BigUIntView!size_t(ret.coefficient.data).leastSignificant &= ~mask0;
                        auto condInc = tail0 >= half
                            && (   tail0 > half
                                || tail
                                || (BigUIntView!size_t(ret.coefficient.data).leastSignificant & 1)
                                || nonZeroTail);
                    }
                    else
                    {
                        enum half = cast(size_t)Signed!size_t.min;
                        auto condInc = tail >= half
                            && (    tail > half
                                || (BigUIntView!size_t(ret.coefficient.data).leastSignificant & 1)
                                || nonZeroTail);
                    }

                    if (condInc)
                    {
                        enum inc = size_t(1) << internalRoundLastBits;
                        if (auto overflow = ret.coefficient += inc)
                        {
                            import mir.bignum.fp: half;
                            ret.coefficient = half!coefficientSize;
                            ret.exponent++;
                        }
                    }
                }
            }
        R:
            return ret;
        }
    }

    static if (UInt.sizeof == size_t.sizeof && endian == TargetEndian)
    ///
    @safe pure
    unittest
    {
        import mir.bignum.fp: Fp;
        import mir.bignum.fixed_int: UInt;

        auto fp = cast(Fp!128) BigUIntView!ulong.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(fp.exponent == 0);
        assert(fp.coefficient == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));

        fp = cast(Fp!128) BigUIntView!uint.fromHexString("ae3cd0aff2714a1de7022b0029d");
        assert(fp.exponent == -20);
        assert(fp.coefficient == UInt!128.fromHexString("ae3cd0aff2714a1de7022b0029d00000"));

        fp = cast(Fp!128) BigUIntView!ushort.fromHexString("e7022b0029d");
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));

        fp = cast(Fp!128) BigUIntView!ubyte.fromHexString("e7022b0029d");
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));

        fp = cast(Fp!128) BigUIntView!size_t.fromHexString("e7022b0029d");
        assert(fp.exponent == -84);
        assert(fp.coefficient == UInt!128.fromHexString("e7022b0029d000000000000000000000"));
    
        fp = cast(Fp!128) BigUIntView!size_t.fromHexString("ffffffffffffffffffffffffffffffff1000000000000000");
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("ffffffffffffffffffffffffffffffff"));

        fp = cast(Fp!128) BigUIntView!size_t.fromHexString("ffffffffffffffffffffffffffffffff8000000000000000");
        assert(fp.exponent == 65);
        assert(fp.coefficient == UInt!128.fromHexString("80000000000000000000000000000000"));

        fp = cast(Fp!128) BigUIntView!size_t.fromHexString("fffffffffffffffffffffffffffffffe8000000000000000");
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("fffffffffffffffffffffffffffffffe"));

        fp = cast(Fp!128) BigUIntView!size_t.fromHexString("fffffffffffffffffffffffffffffffe8000000000000001");
        assert(fp.exponent == 64);
        assert(fp.coefficient == UInt!128.fromHexString("ffffffffffffffffffffffffffffffff"));
    }

    ///
    BigUIntView!(const UInt, endian) lightConst()
        const @safe pure nothrow @nogc @property
    {
        return typeof(return)(coefficients);
    }
    ///ditto
    alias lightConst this;

    /++
    +/
    sizediff_t opCmp(BigUIntView!(const UInt, endian) rhs)
        const @safe pure nothrow @nogc
    {
        import mir.algorithm.iteration: cmp;
        if (auto d = this.coefficients.length - rhs.coefficients.length)
            return d;
        return cmp(this.lightConst.normalized.mostSignificantFirst, rhs.lightConst.normalized.mostSignificantFirst);
    }

    ///
    bool opEquals(BigUIntView!(const UInt, endian) rhs)
        const @safe pure nothrow @nogc
    {
        return this.coefficients == rhs.coefficients;
    }

    /++
    +/
    ref inout(UInt) mostSignificant() inout @property
    {
        static if (endian == WordEndian.big)
            return coefficients[0];
        else
            return coefficients[$ - 1];
    }

    /++
    +/
    ref inout(UInt) leastSignificant() inout @property
    {
        static if (endian == WordEndian.little)
            return coefficients[0];
        else
            return coefficients[$ - 1];
    }

    /++
    +/
    void popMostSignificant()
    {
        static if (endian == WordEndian.big)
            coefficients = coefficients[1 .. $];
        else
            coefficients = coefficients[0 .. $ - 1];
    }

    /++
    +/
    void popLeastSignificant()
    {
        static if (endian == WordEndian.little)
            coefficients = coefficients[1 .. $];
        else
            coefficients = coefficients[0 .. $ - 1];
    }

    /++
    +/
    BigUIntView topMostSignificantPart(size_t length)
    {
        static if (endian == WordEndian.big)
            return BigUIntView(coefficients[0 .. length]);
        else
            return BigUIntView(coefficients[$ - length .. $]);
    }

    /++
    +/
    BigUIntView topLeastSignificantPart(size_t length)
    {
        static if (endian == WordEndian.little)
            return BigUIntView(coefficients[0 .. length]);
        else
            return BigUIntView(coefficients[$ - length .. $]);
    }

    /++
    Shifts left using at most `size_t.sizeof * 8 - 1` bits
    +/
    void smallLeftShiftInPlace()(uint shift)
    {
        assert(shift < UInt.sizeof * 8);
        if (shift == 0)
            return;
        auto csh = UInt.sizeof * 8 - shift;
        auto d = leastSignificantFirst;
        assert(d.length);
        foreach_reverse (i; 1 .. d.length)
            d[i] = (d[i] << shift) | (d[i - 1] >>> csh);
        d.front <<= shift;
    }

    static if (UInt.sizeof == size_t.sizeof && endian == TargetEndian)
    ///
    @safe pure
    unittest
    {
        auto a = BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        a.smallLeftShiftInPlace(4);
        assert(a == BigUIntView!size_t.fromHexString("fbbfae3cd0aff2714a1de7022b0029d0"));
        a.smallLeftShiftInPlace(0);
        assert(a == BigUIntView!size_t.fromHexString("fbbfae3cd0aff2714a1de7022b0029d0"));
    }

    /++
    Shifts right using at most `size_t.sizeof * 8 - 1` bits
    +/
    void smallRightShiftInPlace()(uint shift)
    {
        assert(shift < UInt.sizeof * 8);
        if (shift == 0)
            return;
        auto csh = UInt.sizeof * 8 - shift;
        auto d = leastSignificantFirst;
        assert(d.length);
        foreach (i; 0 .. d.length - 1)
            d[i] = (d[i] >>> shift) | (d[i + 1] << csh);
        d.back >>>= shift;
    }

    static if (UInt.sizeof == size_t.sizeof && endian == TargetEndian)
    ///
    @safe pure
    unittest
    {
        auto a = BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        a.smallRightShiftInPlace(4);
        assert(a == BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029"));
    }

    /++
    +/
    static BigUIntView fromHexString(scope const(char)[] str)
        @trusted pure
    {
        auto length = str.length / (UInt.sizeof * 2) + (str.length % (UInt.sizeof * 2) != 0);
        auto data = new Unqual!UInt[length];
        BigUIntView!(Unqual!UInt, endian)(data).fromHexStringImpl(str);
        return BigUIntView(cast(UInt[])data);
    }

    static if (isMutable!UInt)
    /++
    +/
    void fromHexStringImpl(scope const(char)[] str)
        @safe pure @nogc
    {
        pragma(inline, false);
        import mir.utility: _expect;
        if (_expect(str.length == 0 || str.length > coefficients.length * UInt.sizeof * 2, false))
        {
            version(D_Exceptions)
                throw hexStringException;
            else
                assert(0, hexStringErrorMsg);
        }
        auto rdata = leastSignificantFirst;
        UInt current;
        size_t i;
        do
        {
            ubyte c;
            switch(str[$ - ++i])
            {
                case '0': c = 0x0; break;
                case '1': c = 0x1; break;
                case '2': c = 0x2; break;
                case '3': c = 0x3; break;
                case '4': c = 0x4; break;
                case '5': c = 0x5; break;
                case '6': c = 0x6; break;
                case '7': c = 0x7; break;
                case '8': c = 0x8; break;
                case '9': c = 0x9; break;
                case 'A':
                case 'a': c = 0xA; break;
                case 'B':
                case 'b': c = 0xB; break;
                case 'C':
                case 'c': c = 0xC; break;
                case 'D':
                case 'd': c = 0xD; break;
                case 'E':
                case 'e': c = 0xE; break;
                case 'F':
                case 'f': c = 0xF; break;
                default:
                    version(D_Exceptions)
                        throw hexStringException;
                    else
                        assert(0, hexStringErrorMsg);
            }
            enum s = UInt.sizeof * 8 - 4;
            UInt cc = cast(UInt)(UInt(c) << s);
            current >>>= 4;
            current |= cc;
            if (i % (UInt.sizeof * 2) == 0)
            {
                rdata.front = current;
                rdata.popFront;
                current = 0;
            }
        }
        while(i < str.length);
        if (current)
        {
            current >>>= 4 * (UInt.sizeof * 2 - i % (UInt.sizeof * 2));
            rdata.front = current;
        }
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `bool overflow = big +(-)= big` operatrion.
    Params:
        rhs = value to add with non-empty coefficients
        overflow = (overflow) initial iteration overflow
    Precondition: non-empty coefficients length of greater or equal to the `rhs` coefficients length.
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op)(BigUIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        assert(this.coefficients.length > 0);
        assert(rhs.coefficients.length <= this.coefficients.length);
        auto ls = this.leastSignificantFirst;
        auto rs = rhs.leastSignificantFirst;
        do
        {
            bool overflowM, overflowG;
            ls.front = ls.front.cop!op(rs.front, overflowM).cop!op(overflow, overflowG);
            overflow = overflowG | overflowM;
            ls.popFront;
            rs.popFront;
        }
        while(rs.length);
        if (overflow && ls.length)
            return topMostSignificantPart(ls.length).opOpAssign!op(UInt(overflow));
        return overflow;
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /// ditto
    bool opOpAssign(string op)(BigIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        return rhs.sign == false ?
            opOpAssign!op(rhs.unsigned, overflow):
            opOpAssign!(inverseSign!op)(rhs.unsigned, overflow);
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `bool Overflow = big +(-)= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = value to add
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op, T)(const T rhs)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && is(T == UInt))
    {
        assert(this.coefficients.length > 0);
        auto ns = this.leastSignificantFirst;
        UInt additive = rhs;
        do
        {
            bool overflow;
            ns.front = ns.front.cop!op(additive, overflow);
            if (!overflow)
                return overflow;
            additive = overflow;
            ns.popFront;
        }
        while (ns.length);
        return true;
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /// ditto
    bool opOpAssign(string op, T)(const T rhs)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && is(T == Signed!UInt))
    {
        return rhs >= 0 ?
            opOpAssign!op(cast(UInt)rhs):
            opOpAssign!(inverseSign!op)(cast(UInt)(-rhs));
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `UInt overflow = big *= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = unsigned value to multiply by
    Returns:
        unsigned overflow value
    +/
    UInt opOpAssign(string op : "*")(UInt rhs, UInt overflow = 0u)
        @safe pure nothrow @nogc
    {
        assert(coefficients.length);
        auto ns = this.leastSignificantFirst;
        do
        {
            import mir.utility: extMul;
            bool overflowM;
            static if (is(UInt == uint))
            {
                auto ext = ulong(ns.front) * ulong(rhs);
                ns.front = (cast(uint)(ext)).cop!"+"(overflow, overflowM);
                overflow = cast(uint)(ext >>> 32) + overflowM;
            }
            else
            {
                auto ext = ns.front.extMul(rhs);
                ns.front = ext.low.cop!"+"(overflow, overflowM);
                overflow = ext.high + overflowM;
            }
            ns.popFront;
        }
        while (ns.length);
        return overflow;
    }

    /++
    Returns: the same intger view with inversed sign
    +/
    BigIntView!(UInt, endian) opUnary(string op : "-")()
    {
        return typeof(return)(this, true);
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    +/
    void bitwiseNotInPlace()
    {
        foreach (ref coefficient; this.coefficients)
            coefficient = cast(UInt)~(0 + coefficient);
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `number=-number` operatrion.
    Precondition: non-empty coefficients
    Returns:
        true if 'number=-number=0' and false otherwise
    +/
    bool twoComplementInPlace()
    {
        assert(coefficients.length);
        bitwiseNotInPlace();
        return this.opOpAssign!"+"(UInt(1));
    }

    /++
    Returns: a slice of coefficients starting from the least significant.
    +/
    auto leastSignificantFirst()
        @safe pure nothrow @nogc @property
    {
        import mir.ndslice.slice: sliced;
        static if (endian == WordEndian.little)
        {
            return coefficients.sliced;
        }
        else
        {
            import mir.ndslice.topology: retro;
            return coefficients.sliced.retro;
        }
    }

    /++
    Returns: a slice of coefficients starting from the most significant.
    +/
    auto mostSignificantFirst()
        @safe pure nothrow @nogc @property
    {
        import mir.ndslice.slice: sliced;
        static if (endian == WordEndian.big)
        {
            return coefficients.sliced;
        }
        else
        {
            import mir.ndslice.topology: retro;
            return coefficients.sliced.retro;
        }
    }

    auto mostSignificantFirst()
        const @safe pure nothrow @nogc @property
    {
        import mir.ndslice.slice: sliced;
        static if (endian == WordEndian.big)
        {
            return coefficients.sliced;
        }
        else
        {
            import mir.ndslice.topology: retro;
            return coefficients.sliced.retro;
        }
    }

    /++
    Strips most significant zero coefficients.
    +/
    BigUIntView normalized()
    {
        auto number = this;
        if (number.coefficients.length) do
        {
            static if (endian == WordEndian.big)
            {
                if (number.coefficients[0])
                    break;
                number.coefficients = number.coefficients[1 .. $];
            }
            else
            {
                if (number.coefficients[$ - 1])
                    break;
                number.coefficients = number.coefficients[0 .. $ - 1];
            }
        }
        while (number.coefficients.length);
        return number;
    }

    /++
    +/
    bool bt()(size_t position)
    {
        import mir.ndslice.topology: bitwise;
        assert(position < coefficients.length * UInt.sizeof * 8);
        return leastSignificantFirst.bitwise[position];
    }

    /++
    +/
    size_t ctlz()() const @property
        @safe pure nothrow @nogc
    {
        import mir.bitop: ctlz;
        assert(coefficients.length);
        auto d = mostSignificantFirst;
        size_t ret;
        do
        {
            if (auto c = d.front)
            {
                ret += ctlz(c);
                break;
            }
            ret += UInt.sizeof * 8;
            d.popFront;
        }
        while(d.length);
        return ret;
    }

    ///
    BigIntView!(UInt, endian) withSign(bool sign)
    {
        return typeof(return)(this, sign);
    }

    /++
    Params:
        value = (out) unsigned integer
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    bool get(U)(scope out U value)
        @safe pure nothrow @nogc const
        if (isUnsigned!U)
    {
        auto d = lightConst.mostSignificantFirst;
        if (d.length == 0)
            return false;
        static if (U.sizeof > UInt.sizeof)
        {
            size_t i;
            for(;;)
            {
                value |= d[0];
                d = d[1 .. $];
                if (d.length == 0)
                    return false;
                i += cast(bool)value;
                value <<= UInt.sizeof * 8;
                import mir.utility: _expect;
                if (_expect(i >= U.sizeof / UInt.sizeof, false))
                    return true;
            }
        }
        else
        {
            for(;;)
            {
                UInt f = d[0];
                d = d[1 .. $];
                if (d.length == 0)
                {
                    value = cast(U)f;
                    static if (U.sizeof < UInt.sizeof)
                    {
                        if (value != f)
                            return true;
                    }
                    return false;
                }
                if (f)
                    return true;
            }
        }
    }

    /++
    Returns: true if the integer and equals to `rhs`.
    +/
    bool opEquals(ulong rhs)
        @safe pure nothrow @nogc const
    {
        foreach_reverse(d; lightConst.leastSignificantFirst)
        {
            static if (UInt.sizeof >= ulong.sizeof)
            {
                if (d != rhs)
                    return false;
                rhs = 0;
            }
            else
            {
                if (d != (rhs & UInt.max))
                    return false;
                rhs >>>= UInt.sizeof * 8;
            }
        }
        return rhs == 0;
    }
}

///
@safe pure nothrow
unittest
{
    import std.traits;
    alias AliasSeq(T...) = T;

    foreach (T; AliasSeq!(ubyte, ushort, uint, ulong))
    foreach (endian; AliasSeq!(WordEndian.little, WordEndian.big))
    {
        static if (endian == WordEndian.little)
        {
            T[3] lhsData = [1, T.max-1, 0];
            T[3] rhsData = [T.max, T.max, 0];
        }
        else
        {
            T[3] lhsData = [0, T.max-1, 1];
            T[3] rhsData = [0, T.max, T.max];
        }

        auto lhs = BigUIntView!(T, endian)(lhsData).normalized;

        /// bool overflow = bigUInt op= scalar
        assert(lhs.leastSignificantFirst == [1, T.max-1]);
        assert(lhs.mostSignificantFirst == [T.max-1, 1]);
        static if (T.sizeof >= 4)
        {
            assert((lhs += T.max) == false);
            assert(lhs.leastSignificantFirst == [0, T.max]);
            assert((lhs += T.max) == false);
            assert((lhs += T.max) == true); // overflow bit
            assert(lhs.leastSignificantFirst == [T.max-1, 0]);
            assert((lhs -= T(1)) == false);
            assert(lhs.leastSignificantFirst == [T.max-2, 0]);
            assert((lhs -= T.max) == true); // underflow bit
            assert(lhs.leastSignificantFirst == [T.max-1, T.max]);
            assert((lhs -= Signed!T(-4)) == true); // overflow bit
            assert(lhs.leastSignificantFirst == [2, 0]);
            assert((lhs += Signed!T.max) == false); // overflow bit
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0]);

            ///  bool overflow = bigUInt op= bigUInt/bigInt
            lhs = BigUIntView!(T, endian)(lhsData);
            auto rhs = BigUIntView!(T, endian)(rhsData).normalized;
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0, 0]);
            assert(rhs.leastSignificantFirst == [T.max, T.max]);
            assert((lhs += rhs) == false);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 1, 0, 1]);
            assert((lhs -= rhs) == false);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0, 0]);
            assert((lhs += -rhs) == true);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 3, 0, T.max]);
            assert((lhs += -(-rhs)) == true);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0, 0]);

            /// UInt overflow = bigUInt *= scalar
            assert((lhs *= T.max) == 0);
            assert((lhs += T(Signed!T.max + 2)) == false);
            assert(lhs.leastSignificantFirst == [0, Signed!T.max + 2, 0]);
            lhs = lhs.normalized;
            lhs.leastSignificantFirst[1] = T.max / 2 + 3;
            assert(lhs.leastSignificantFirst == [0, T.max / 2 + 3]);
            assert((lhs *= 8u) == 4);
            assert(lhs.leastSignificantFirst == [0, 16]);
        }
    }
}

/++
Arbitrary length signed integer view.
+/
struct BigIntView(UInt, WordEndian endian = TargetEndian)
    if (is(Unqual!UInt == ubyte) || is(Unqual!UInt == ushort) || is(Unqual!UInt == uint) || is(Unqual!UInt == ulong))
{
    import mir.bignum.fp: Fp;

    /++
    Self-assigned to unsigned integer view $(MREF BigUIntView).

    Sign is stored in the most significant bit.

    The number is encoded as pair of `unsigned` and `sign`.
    +/
    BigUIntView!(UInt, endian) unsigned;

    /++
    Sign bit
    +/
    bool sign;

    ///
    inout(UInt)[] coefficients() inout @property
    {
        return unsigned.coefficients;
    }

    ///
    this(UInt[] coefficients, bool sign = false)
    {
        this(BigUIntView!(UInt, endian)(coefficients), sign);
    }

    ///
    this(BigUIntView!(UInt, endian) unsigned, bool sign = false)
    {
        this.unsigned = unsigned;
        this.sign = sign;
    }

    ///
    T opCast(T, bool wordNormalized = false, bool nonZero = false)() const
        if (isFloatingPoint!T)
    {
        auto ret = this.unsigned.opCast!(T, wordNormalized, nonZero);
        if (sign)
            ret = -ret;
        return ret;
    }


    static if (UInt.sizeof == size_t.sizeof && endian == TargetEndian)
    ///
    unittest
    {
        auto a = cast(double) -BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(a == -0xa.fbbfae3cd0bp+124);
    }

    /++
    +/
    T opCast(T : Fp!coefficientSize, size_t internalRoundLastBits = 0, bool wordNormalized = false, bool nonZero = false, size_t coefficientSize)() const
        if (internalRoundLastBits < size_t.sizeof * 8 && (size_t.sizeof >= UInt.sizeof || endian == TargetEndian))
    {
        auto ret = unsigned.opCast!(Fp!coefficientSize, internalRoundLastBits, wordNormalized, nonZero);
        ret.sign = sign;
        return ret;
    }

    static if (UInt.sizeof == size_t.sizeof && endian == TargetEndian)
    ///
    @safe pure
    unittest
    {
        import mir.bignum.fixed_int: UInt;
        import mir.bignum.fp: Fp;

        auto fp = cast(Fp!128) -BigUIntView!size_t.fromHexString("afbbfae3cd0aff2714a1de7022b0029d");
        assert(fp.sign);
        assert(fp.exponent == 0);
        assert(fp.coefficient == UInt!128.fromHexString("afbbfae3cd0aff2714a1de7022b0029d"));
    }

    ///
    BigIntView!(const UInt, endian) lightConst()
        const @safe pure nothrow @nogc @property
    {
        return typeof(return)(unsigned.lightConst, sign);
    }
    ///ditto
    alias lightConst this;

    /++
    +/
    sizediff_t opCmp(BigIntView!(const UInt, endian) rhs) 
        const @safe pure nothrow @nogc
    {
        import mir.algorithm.iteration: cmp;
        if (auto s = rhs.sign - this.sign)
        {
            return s;
        }
        sizediff_t d = this.unsigned.opCmp(rhs.unsigned);
        return sign ? -d : d;
    }

    ///
    bool opEquals(BigIntView!(const UInt, endian) rhs)
        const @safe pure nothrow @nogc
    {
        return this.sign == rhs.sign && this.unsigned == rhs.unsigned;
    }

    /++
    +/
    BigIntView topMostSignificantPart(size_t length)
    {
        return BigIntView(unsigned.topMostSignificantPart(length), sign);
    }

    /++
    +/
    BigIntView topLeastSignificantPart(size_t length)
    {
        return BigIntView(unsigned.topLeastSignificantPart(length), sign);
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `bool overflow = big +(-)= big` operatrion.
    Params:
        rhs = value to add with non-empty coefficients
        overflow = (overflow) initial iteration overflow
    Precondition: non-empty coefficients length of greater or equal to the `rhs` coefficients length.
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op)(BigIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        assert(rhs.coefficients.length > 0);
        assert(this.coefficients.length >= rhs.coefficients.length);
        enum sum = op == "+";
        // pos += pos
        // neg += neg
        // neg -= pos
        // pos -= neg
        if ((sign == rhs.sign) == sum)
            return unsigned.opOpAssign!"+"(rhs.unsigned, overflow);
        // pos -= pos
        // pos += neg
        // neg += pos
        // neg -= neg
        if (unsigned.opOpAssign!"-"(rhs.unsigned, overflow))
        {
            sign = !sign;
            unsigned.twoComplementInPlace;
        }
        return false;
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /// ditto
    bool opOpAssign(string op)(BigUIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        return opOpAssign!op(rhs.signed, overflow);
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `bool overflow = big +(-)= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = value to add
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op, T)(const T rhs)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && is(T == Signed!UInt))
    {
        assert(this.coefficients.length > 0);
        enum sum = op == "+";
        // pos += pos
        // neg += neg
        // neg -= pos
        // pos -= neg
        auto urhs = cast(UInt) (rhs < 0 ? -rhs : rhs);
        if ((sign == (rhs < 0)) == sum)
            return unsigned.opOpAssign!"+"(urhs);
        // pos -= pos
        // pos += neg
        // neg += pos
        // neg -= neg
        if (unsigned.opOpAssign!"-"(urhs))
        {
            sign = !sign;
            unsigned.twoComplementInPlace;
        }
        return false;
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /// ditto
    bool opOpAssign(string op, T)(const T rhs)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && is(T == UInt))
    {
        assert(this.coefficients.length > 0);
        enum sum = op == "+";
        // pos += pos
        // neg -= pos
        if ((sign == false) == sum)
            return unsigned.opOpAssign!"+"(rhs);
        // pos -= pos
        // neg += pos
        if (unsigned.opOpAssign!"-"(rhs))
        {
            sign = !sign;
            unsigned.twoComplementInPlace;
        }
        return false;
    }

    static if (isMutable!UInt && UInt.sizeof >= 4)
    /++
    Performs `UInt overflow = big *= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = unsigned value to multiply by
    Returns:
        unsigned overflow value
    +/
    UInt opOpAssign(string op : "*")(UInt rhs, UInt overflow = 0u)
        @safe pure nothrow @nogc
    {
        return unsigned.opOpAssign!op(rhs, overflow);
    }

    /++
    Returns: the same intger view with inversed sign
    +/
    BigIntView opUnary(string op : "-")()
    {
        return BigIntView(unsigned, !sign);
    }

    /++
    Returns: a slice of coefficients starting from the least significant.
    +/
    auto leastSignificantFirst()
        @safe pure nothrow @nogc @property
    {
        return unsigned.leastSignificantFirst;
    }

    /++
    Returns: a slice of coefficients starting from the most significant.
    +/
    auto mostSignificantFirst()
        @safe pure nothrow @nogc @property
    {
        return unsigned.mostSignificantFirst;
    }

    /++
    Strips zero most significant coefficients.
    Strips most significant zero coefficients.
    Sets sign to zero if no coefficients were left.
    +/
    BigIntView normalized()
    {
        auto number = this;
        number.unsigned = number.unsigned.normalized;
        number.sign = number.coefficients.length == 0 ? false : number.sign;
        return number;
    }
}

///
@safe pure nothrow
unittest
{
    import std.traits;
    alias AliasSeq(T...) = T;

    foreach (T; AliasSeq!(ubyte, ushort, uint, ulong))
    foreach (endian; AliasSeq!(WordEndian.little, WordEndian.big))
    {
        static if (endian == WordEndian.little)
        {
            T[3] lhsData = [1, T.max-1, 0];
            T[3] rhsData = [T.max, T.max, 0];
        }
        else
        {
            T[3] lhsData = [0, T.max-1, 1];
            T[3] rhsData = [0, T.max, T.max];
        }

        auto lhs = BigIntView!(T, endian)(lhsData).normalized;

        ///  bool overflow = bigUInt op= scalar
        assert(lhs.leastSignificantFirst == [1, T.max-1]);
        assert(lhs.mostSignificantFirst == [T.max-1, 1]);

        static if (T.sizeof >= 4)
        {

            assert((lhs += T.max) == false);
            assert(lhs.leastSignificantFirst == [0, T.max]);
            assert((lhs += T.max) == false);
            assert((lhs += T.max) == true); // overflow bit
            assert(lhs.leastSignificantFirst == [T.max-1, 0]);
            assert((lhs -= T(1)) == false);
            assert(lhs.leastSignificantFirst == [T.max-2, 0]);
            assert((lhs -= T.max) == false);
            assert(lhs.leastSignificantFirst == [2, 0]);
            assert(lhs.sign);
            assert((lhs -= Signed!T(-4)) == false);
            assert(lhs.leastSignificantFirst == [2, 0]);
            assert(lhs.sign == false);
            assert((lhs += Signed!T.max) == false);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0]);

            ///  bool overflow = bigUInt op= bigUInt/bigInt
            lhs = BigIntView!(T, endian)(lhsData);
            auto rhs = BigUIntView!(T, endian)(rhsData).normalized;
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0, 0]);
            assert(rhs.leastSignificantFirst == [T.max, T.max]);
            assert((lhs += rhs) == false);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 1, 0, 1]);
            assert((lhs -= rhs) == false);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0, 0]);
            assert((lhs += -rhs) == false);
            assert(lhs.sign);
            assert(lhs.leastSignificantFirst == [T.max - (Signed!T.max + 2), T.max, 0]);
            assert(lhs.sign);
            assert((lhs -= -rhs) == false);
            assert(lhs.leastSignificantFirst == [Signed!T.max + 2, 0, 0]);
            assert(lhs.sign == false);
        }
    }
}

/++
An utility type to wrap a local buffer to accumulate unsigned numbers.
+/
struct BigUIntAccumulator(UInt, WordEndian endian = TargetEndian)
    if (is(Unqual!UInt == uint) || is(Unqual!UInt == ulong))
{
    /++
    A group of coefficients for a $(MREF DecimalRadix)`!UInt`.

    The order corresponds to endianness.

    The unused part can be uninitialized.
    +/
    UInt[] coefficients;

    /++
    Current length of initialized coefficients.

    The initialization order corresponds to endianness.

    The `view` method may return a view with empty coefficients, which isn't usable.
    Put `0` or another number first to make the accumulator maintain a non-empty view.
    +/
    size_t length;

    /++
    Returns:
        Current unsigned integer view.
    Note:
        The method may return a view with empty coefficients, which isn't usable.
        Put `0` or another number first to make the accumulator maintain a non-empty view.
    +/
    BigUIntView!(UInt, endian) view() @safe pure nothrow @nogc @property
    {
        static if (endian == WordEndian.little)
            return typeof(return)(coefficients[0 .. length]);
        else
            return typeof(return)(coefficients[$ - length .. $]);
    }

    /++
    Returns:
        True if the accumulator can accept next most significant coefficient 
    +/
    bool canPut() @property
    {
        return length < coefficients.length;
    }

    /++
    Places coefficient to the next most significant position.
    +/
    void put(UInt coeffecient)
    in {
        assert(length < coefficients.length);
    }
    do {
        static if (endian == WordEndian.little)
            coefficients[length++] = coeffecient;
        else
            coefficients[$ - ++length] = coeffecient;
    }

    /++
    Strips most significant zero coefficients from the current `view`.
    Note:
        The `view` method may return a view with empty coefficients, which isn't usable.
        Put `0` or another number first to make the accumulator maintain a non-empty view.
    +/
    void normalize()
    {
        length = view.normalized.coefficients.length;
    }

    ///
    bool canPutN(size_t n)
    {
        return length + n <= coefficients.length;
    }

    ///
    bool approxCanMulPow5(size_t degree)
    {
        // TODO: more precise result
        enum n = MaxWordPow5!UInt;
        return canPutN(degree / n + (degree % n != 0));
    }

    ///
    bool canMulPow2(size_t degree)
    {
        import mir.bitop: ctlz;
        enum n = UInt.sizeof * 8;
        return canPutN(degree / n + (degree % n > ctlz(view.mostSignificant)));
    }

    ///
    void mulPow5(size_t degree)
    {
        // assert(approxCanMulPow5(degree));
        enum n = MaxWordPow5!UInt;
        enum wordInit = UInt(5) ^^ n;
        UInt word = wordInit;
        while(degree)
        {
            if (degree >= n)
            {
                degree -= n;
            }
            else
            {
                word = 1;
                do word *= 5;
                while(--degree);
            }
            if (auto overflow = view *= word)
            {
                put(overflow);
            }
        }
    }

    ///
    void mulPow2(size_t degree)
    {
        import mir.bitop: ctlz;
        assert(canMulPow2(degree));
        enum n = UInt.sizeof * 8;
        auto ws = degree / n;
        auto oldLength = length;
        length += ws;
        if (ws)
        {
            auto v = view.leastSignificantFirst;
            foreach_reverse (i; 0 .. oldLength)
            {
                v[i + ws] = v[i];
            }
            do v[--ws] = 0;
            while(ws);
        }

        if (auto tail = cast(uint)(degree % n))
        {
            if (tail > ctlz(view.mostSignificant))
            {
                put(0);
                oldLength++;
            }
            view.topMostSignificantPart(oldLength).smallLeftShiftInPlace(tail);
        }
    }
}

///
@safe pure
unittest
{
    import std.traits;
    alias AliasSeq(T...) = T;

    foreach (T; AliasSeq!(uint, ulong))
    foreach (endian; AliasSeq!(WordEndian.little, WordEndian.big))
    {
        T[16 / T.sizeof] buffer;
        auto accumulator = BigUIntAccumulator!(T, endian)(buffer);
        assert(accumulator.length == 0);
        assert(accumulator.coefficients.length == buffer.length);
        assert(accumulator.view.coefficients.length == 0);
        // needs to put a number before any operations on `.view`
        accumulator.put(1);
        // compute N factorial
        auto N = 30;
        foreach(i; 1 .. N + 1)
        {
            if (auto overflow = accumulator.view *= i)
            {
                if (!accumulator.canPut)
                    throw new Exception("Factorial buffer overflow");
                accumulator.put(overflow);
            }
        }
        assert(accumulator.view == BigUIntView!(T, endian).fromHexString("D13F6370F96865DF5DD54000000"));
    }
}

/// Computes `13 * 10^^60`
@safe pure
unittest
{
    uint[7] buffer;
    auto accumulator = BigUIntAccumulator!uint(buffer);
    accumulator.put(13); // initial value
    assert(accumulator.approxCanMulPow5(60));
    accumulator.mulPow5(60);
    assert(accumulator.canMulPow2(60));
    accumulator.mulPow2(60);
    assert(accumulator.view == BigUIntView!uint.fromHexString("81704fcef32d3bd8117effd5c4389285b05d000000000000000"));
}

/++
+/
struct DecimalView(UInt, WordEndian endian = TargetEndian, Exp = int)
{
    ///
    bool sign;
    ///
    Exp exponent;
    ///
    BigUIntView!(UInt, endian) coefficient;

    ///
    T opCast(T, bool wordNormalized = false, bool nonZero = false)() const
        if (isFloatingPoint!T && isMutable!T)
    {
        import mir.internal.dec2flt_table;
        import mir.bignum.fp;
        auto coeff = coefficient;
        T ret = 0;
        static if (!wordNormalized)
            coeff = coeff.normalized;
        static if (!nonZero)
            if (coeff.coefficients.length == 0)
                goto R;
        enum S = 9;
        enum P = 1 << (S - 1);
        static assert(min_p10_e <= -P);
        static assert(max_p10_e >= P);
        static if (T.mant_dig < 64)
        {
            UInt!64 load(Exp e)
            {
                auto p10Coeff = p10_coefficients[e - min_p10_e][0];
                auto p10exp = p10_exponents[e - min_p10_e];
                return Fp!64(false, p10exp, p10coeff);
            }

            auto expSign = exponent < 0;
            if (_expect((expSign ? -exponent : exponent) >>> S == 0, true))
            {
                enum ulong mask = (1UL << (64 - T.mant_dig)) - 1;
                enum ulong half = (1UL << (64 - T.mant_dig - 1));
                enum ulong bound = ulong(1) << T.mant_dig;

                auto c = coeff.opCast!(Fp!64, 64, true, true);
                auto z = c.extemdedMul(load(exponent));
                ret = cast(T) z;
                auto slop = (coeff.coefficients.length > (ulong.sizeof / UInt.sizeof)) + 3 * expSign;
                long bitsDiff = (cast(ulong) cast(Fp!64) z & mask) - half;
                if (_expect((bitsDiff < 0 ? -bitsDiff : bitsDiff) > slop, true))
                    goto R;
                if (slop == 0 && exponent <= MaxWordPow5!ulong || exponent == 0)
                    goto R;
                if (slop == 3 && MaxFpPow5!T >= -exponent && cast(ulong)c < bound)
                {
                    auto e = load(-exponent);
                    ret =  c.opCast!(T, true) / cast(T) (cast(ulong)e.coeffecient >> e.exponent);
                    goto R;
                }
                goto AlgoR;
            }
            ret = expSign ? 0 : T.infinity;
            goto R;
        }
        else
        {
            UInt!128 load(Exp e)
            {
                auto h = p10_coefficients[e - min_p10_e][0];
                auto l = p10_coefficients[e - min_p10_e][1];
                if (l >= cast(ulong)long.min)
                    h--;
                version(BigEndian)
                    auto p10Coeff = UInt!128(cast(size_t[ulong.sizeof / size_t.sizeof * 2])cast(ulong[2])[h, l]);
                else
                    auto p10Coeff = UInt!128(cast(size_t[ulong.sizeof / size_t.sizeof * 2])cast(ulong[2])[l, h]);
                auto p10exp = p10_exponents[e - min_p10_e] - 64;
                return Fp!128(false, p10exp, p10coeff);
            }

            auto expSign = exponent < 0;
            Unsigned!Exp exp = exponent;
            exp = expSign ? -exp : exp;
            auto index = exp & 0x1F;
            bool gotoAlgoR;
            auto c = load(expSign ? -index : index);
            {
                exp >>= S;
                gotoAlgoR = exp != 0;
                if (_expect(gotoAlgoR, false))
                {
                    if (!expSign)
                        goto AlgoR;
                    exp   = -exp;
                    auto v = load(-P);
                    do
                    {
                        if (exp & 1)
                            c *= v;
                        exp >>>= 1;
                        if (exp == 0)
                            break;
                        v *= v;
                    }
                    while(true);
                }
            }
            {
                auto z = coeff.opCast!(Fp!128, 128, true, true).extendedMul(c);
                ret = cast(T) z;
                if (!gotoAlgoR)
                {
                    static if (T.mant_dig == 64)
                        enum ulong mask = ulong.max;
                    else
                        enum ulong mask = (1UL << (128 - T.mant_dig)) - 1;
                    enum ulong half = (1UL << (128 - T.mant_dig - 1));
                    enum Fp!128 bound = Fp!128(1) << T.mant_dig;

                    auto slop = (coeff.coefficients.length > (ulong.sizeof * 2 / UInt.sizeof)) + 3 * expSign;
                    long bitsDiff = (cast(ulong) cast(Fp!64) z & mask) - half;
                    if (_expect((bitsDiff < 0 ? -bitsDiff : bitsDiff) > slop, true))
                        goto R;
                    if (slop == 0 && exponent <= 55 || exponent == 0)
                        goto R;
                    if (slop == 3 && MaxFpPow5!T >= -exponent && c < bound)
                    {
                        auto e = load(-exponent);
                        ret =  c.opCast!(T, true) / cast(T) e;
                        goto R;
                    }
                }
            }
        }

    AlgoR:
        // fast path
        if (exponent >= 0)
        {
            assert(exponent >= 0);
            size_t[128] buffer = void;
            if ()
        }
        else
        {

        }

    R:
        if (sign)
            ret = -ret;
        return ret;
    }
}

/++
+/
struct BinaryView(UInt, WordEndian endian = TargetEndian, Exp = int)
{
    ///
    bool sign;
    ///
    Exp exponent;
    ///
    BigUIntView!(UInt, endian) coefficient;
}
