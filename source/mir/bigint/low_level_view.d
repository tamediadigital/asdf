/++
Low-level betterC utilities for big integer arithmetic libraries.

The module provides $(REF BigUIntAccumulator), $(REF BigUIntView), and $(LREF BigIntView).
+/
module mir.bigint.low_level_view;

import mir.checkedint;
import std.traits;

private alias cop(string op : "-") = subu;
private alias cop(string op : "+") = addu;
private enum inverseSign(string op) = op == "+" ? "-" : "+";

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

/++
Arbitrary length unsigned integer view.
+/
struct BigUIntView(UInt, WordEndian endian = TargetEndian)
    if (is(Unqual!UInt == ubyte) || is(Unqual!UInt == ushort) || is(Unqual!UInt == uint) || is(Unqual!UInt == ulong))
{
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
            bool overflowM;
            ls.front = ls.front.cop!op(rs.front, overflowM).cop!op(overflow, overflow);
            overflow |= overflowM;
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
        // 0xD13F6370F96865DF5DD54000000
        static if (is(T == uint))
            assert(accumulator.view.mostSignificantFirst == [0xD13, 0xF6370F96, 0x865DF5DD, 0x54000000]);
        else
            assert(accumulator.view.mostSignificantFirst == [0xD13F6370F96, 0x865DF5DD54000000]);
    }
}
