module mir.bigint.utilities;

import std.traits;
import mir.checkedint;

private enum inverseSign(string op) = op == "+" ? "-" : "+";

/++
+/
enum WordEndian
{
    little,
    big,
}

version(LittleEndian)
{
    /++
    +/
    enum MachineEndian = WordEndian.little;
}
else
{
    enum MachineEndian = WordEndian.big;
}

/++
Arbitrary length unsigned integer view.
+/
struct BigUIntView(UInt, WordEndian endian = MachineEndian)
    if (isUnsigned!UInt)
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
    sizediff_t opCmp(BigUIntView!(const UInt, endian) rhs) const @safe pure nothrow @nogc
    {
        import mir.algorithm.iteration: cmp;
        if (auto d = this.coefficients.length - rhs.coefficients.length)
            return d;
        return cmp(this.lightConst.normalized.coefficientsFromMostSignificant, rhs.lightConst.normalized.coefficientsFromMostSignificant);
    }

    ///
    bool opEquals(BigUIntView!(const UInt, endian) rhs) const @safe pure nothrow @nogc @property
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

    /++
    Performs `big+=big`, `big-=big` operatrion.
    Params:
        additive = value to add with non-empty coefficients
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
        auto ls = this.coefficientsFromLeastSignificant;
        auto rs = rhs.coefficientsFromLeastSignificant;
        do
        {
            bool overflowM;
            static if (op == "+")
            {
                ls.front = addu(addu(ls.front, rs.front, overflowM), overflow, overflow);
            }
            else
            {
                ls.front = subu(subu(ls.front, rs.front, overflowM), overflow, overflow);
            }
            overflow |= overflowM;
            ls.popFront;
            rs.popFront;
        }
        while(rs.length);
        if (overflow && ls.length)
            return topMostSignificantPart(ls.length).opOpAssign!op(overflow);
        return overflow;
    }

    /// ditto
    bool opOpAssign(string op)(BigIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        return rhs.sign == false ?
            opOpAssign!op(rhs.unsigned):
            opOpAssign!(inverseSign!op)(cast(UInt)(rhs.unsigned));
    }

    /++
    Performs `big+=scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        additive = value to add
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op, T)(const T rhs)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && is(T == UInt))
    {
        assert(this.coefficients.length > 0);
        auto ns = this.coefficientsFromLeastSignificant;
        UInt additive = rhs;
        do
        {
            bool overflow;
            static if (op == "+")
                ns.front = addu(ns.front, additive, overflow);
            else
                ns.front = subu(ns.front, additive, overflow);
            if (!overflow)
                return overflow;
            additive = overflow;
            ns.popFront;
        }
        while (ns.length);
        return true;
    }

    /// ditto
    bool opOpAssign(string op, T)(const T rhs)
        @safe pure nothrow @nogc
        if ((op == "+" || op == "-") && is(T == Signed!UInt))
    {
        return rhs >= 0 ?
            opOpAssign!op(cast(UInt)rhs):
            opOpAssign!(inverseSign!op)(cast(UInt)(-rhs));
    }

    /++
    Returns: the same intger view with inversed sign
    +/
    BigIntView!(UInt, endian) opUnary(string op : "-")()
    {
        return typeof(return)(unsigned, true);
    }

    static if (isMutable!UInt)
    /++
    +/
    void bitwiseNotInPlace()
    {
        foreach(coefficient; this.coefficients)
            coefficient = ~coefficient;
    }

    static if (isMutable!UInt)
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
    auto coefficientsFromLeastSignificant()
        @safe pure nothrow @nogc
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
    auto coefficientsFromMostSignificant()
        @safe pure nothrow @nogc
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
    Strips zero most significant coefficients.
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
}

unittest
{
    alias UBig = BigUIntView!(ulong, WordEndian.little);

    ulong[] data = [1, ulong.max-1, 0];

    auto num = UBig(data).normalized;
    assert(num.coefficientsFromLeastSignificant == [1, ulong.max-1]);
    assert(num.coefficientsFromMostSignificant == [ulong.max-1, 1]);
    assert((num += ulong.max) == false);
    assert(num.coefficientsFromLeastSignificant == [0, ulong.max]);
    assert((num += ulong.max) == false);
    assert((num += ulong.max) == true); // overflow bit
    assert(num.coefficientsFromLeastSignificant == [ulong.max-1, 0]);
    assert((num -= ulong(1)) == false);
    assert(num.coefficientsFromLeastSignificant == [ulong.max-2, 0]);
    assert((num -= ulong.max) == true); // underflow bit
    assert(num.coefficientsFromLeastSignificant == [ulong.max-1, ulong.max]);
    assert((num -= long(-4)) == true); // overflow bit
    assert(num.coefficientsFromLeastSignificant == [2, 0]);
    // assert((num -= ulong.max - 3) == false);
    // assert(num.coefficientsFromLeastSignificant == [3, ulong.max-1]);
}

alias MyBitUint1 = BigUIntView!(const ulong);
alias MyBitUint2 = BigUIntView!ulong;
alias MyBitInt1 = BigIntView!(const ulong);
alias MyBitInt2 = BigIntView!ulong;

/++
Arbitrary length signed integer view.
+/
struct BigIntView(UInt, WordEndian endian = MachineEndian)
    if (isUnsigned!UInt)
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
    BigIntView!(const UInt, endian) lightConst()
        const @safe pure nothrow @nogc @property
    {
        return typeof(return)(unsigned.lightConst, sign);
    }
    ///ditto
    alias lightConst this;

    /++
    +/
    sizediff_t opCmp(BigIntView!(const UInt, endian) rhs) const @safe pure nothrow @nogc
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
    bool opEquals(BigIntView!(const UInt, endian) rhs) const @safe pure nothrow @nogc @property
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

    /++
    Performs `big+=big` operatrion.
    Params:
        additive = unsigned value to add with non-empty coefficients
        overflow = (overflow) initial iteration overflow
    Precondition: non-empty coefficients length of greater or equal to the `rhs` coefficients length.
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op)(BigIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        assert(rhs.unsigned.coefficients.length > 0);
        assert(this.unsigned.coefficients.length >= rhs.unsigned.coefficients.length);
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
            twoComplementInPlace;
        }
        return false;
    }

    bool opOpAssign(string op)(BigUIntView!(const UInt, endian) rhs, bool overflow = false)
    @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        return opOpAssign!op(rhs.signed, overflow);
    }

    /++
    Performs `big+=scalar` or `big-=scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        additive = unsigned value to add
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
            return unsigned.opOpAssign!"+"(urhs, overflow);
        // pos -= pos
        // pos += neg
        // neg += pos
        // neg -= neg
        if (unsigned.opOpAssign!"-"(urhs, overflow))
        {
            sign = !sign;
            twoComplementInPlace;
        }
        return false;
    }

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
            return unsigned.opOpAssign!"+"(rhs, overflow);
        // pos -= pos
        // neg += pos
        if (unsigned.opOpAssign!"-"(rhs, overflow))
        {
            sign = !sign;
            twoComplementInPlace;
        }
        return false;
    }

    /++
    Returns: the same intger view with inversed sign
    +/
    BigIntView opUnary(string op : "-")()
    {
        return BigIntView(unsigned, !sign);
    }

    /++
    Strips zero most significant coefficients.
    Sets sign to zero if no coefficients were left.
    +/
    BigIntView normalized()
    {
        auto number = this;
        number.unsigned = number.unsigned.normalized;
        number.sign = number.unsigned.coefficients.length == 0 ? false : number.sign;
        return number;
    }
}

/++
An utility type to wrap a local buffer to accumulate unsigned numbers.
+/
struct BigUIntAccumulator(UInt, WordEndian endian = MachineEndian)
    if (isUnsigned!UInt)
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
    +/
    size_t length;

    /++
    Returns:
        Current unsigned integer view
    +/
    BigUIntView!UInt view() @safe pure nothrow @nogc @property
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
    bool canPut()
    {
        return length < coeffecients.length;
    }

    /++
    Places coefficient to the next most significant position.
    +/
    void put(UInt coeffecient)
    in {
        assert(length < coeffecients.length);
    }
    do {
        static if (endian == WordEndian.little)
            coefficients[length++] = coeffecient;
        else
            coefficients[$ - ++length] = coeffecient;
    }
}
