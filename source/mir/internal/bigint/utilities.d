module mir.bigint.utilities;

import std.traits;
import mir.checkedint;

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

    ///
    alias ConstThis = BigUIntView!(const UInt, endian);

    /++
    Retrurns: signed integer view using the same data payload
    +/
    BigIntView!(Signed!UInt, endian) signed() @safe pure nothrow @nogc @property
    {
        return typeof(return)(this);
    }

    ///
    ConstThis lightConst()
        const @safe pure nothrow @nogc @property
    {
        return typeof(return)(coefficients);
    }
    ///ditto
    alias lightConst this;

    /++
    +/
    sizediff_t opCmp(ConstThis rhs) const @safe pure nothrow @nogc
    {
        import mir.algorithm.iteration: cmp;
        if (auto d = this.coefficients.length - rhs.coefficients.length)
            return d;
        return cmp(coefficientsFromMostSignificant(normalize(this.lightConst)), coefficientsFromMostSignificant(normalize(rhs)));
    }

    ///
    bool opEquals(ConstThis rhs) const @safe pure nothrow @nogc @property
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
    Performs `big+=big` operatrion.
    Params:
        additive = value to add with non-empty coefficients
        overflow = (overflow) initial iteration overflow
    Precondition: non-empty coefficients length of greater or equal to the `rhs` coefficients length.
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op : "+")(ConstThis rhs, bool overflow = false)
        @safe pure nothrow @nogc
    {
        assert(this.coefficients.length > 0);
        assert(rhs.coefficients.length <= this.coefficients.length);
        auto ls = this.coefficientsFromLeastSignificant;
        auto rs = rhs.coefficientsFromLeastSignificant;
        do
        {
            bool overflowM;
            ls.front = addu(ls.front, ls.front, overflowM);
            ls.front = addu(ls.front, overflow, overflow);
            overflow |= overflowM;
            ls.popFront;
            rs.popFront;
        }
        while(rs.length);
        if (overflow && ls.length)
            return topMostSignificantPart(ls.length) += overflow;
        else
            return overflow;
    }

    /++
    Performs `big+=scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        additive = value to add
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op : "+")(UInt additive)
        @safe pure nothrow @nogc
    {
        assert(this.coefficients.length > 0);
        auto ns = this.coefficientsFromLeastSignificant;
        do
        {
            ns.front = addu(ns.front, additive, overflow);
            if (!overflow)
                return overflow;
            additive = overflow;
            ns.popFront;
        }
        while (ns.length);
        return true; // number is zero
    }

    /++
    Returns: the same intger view with inversed sign
    +/
    BigIntView!(UInt, endian) opUnary(string op : "-")()
    {
        return typeof(return)(unsigned, true);
    }
}

alias MyBitUint = BigUIntView!ulong;

/++
Strips zero most significant coefficients.
+/
BigUIntView!(T, endian) normalize(T, WordEndian endian)(BigUIntView!(T, endian) number)
{
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
Strips zero most significant coefficients.
Sets sign to zero if no coefficients were left.
+/
BigIntView!(T, endian) normalize(T, WordEndian endian)(BigIntView!(T, endian) number)
{
    number.unsigned = normalize(number.unsigned);
    number.sign = number.unsigned.coefficients.length == 0 ? false : number.sign;
    return number;
}

/++
Returns: a slice of coefficients starting from the least significant.
+/
auto coefficientsFromLeastSignificant(T, WordEndian endian)(BigUIntView!(T, endian) number)
    @safe pure nothrow @nogc
{
    import mir.ndslice.slice: sliced;
    static if (endian == WordEndian.little)
    {
        return number.coefficients.sliced;
    }
    else
    {
        import mir.ndslice.topology: retro;
        return number.coefficients.sliced.retro;
    }
}

/++
Returns: a slice of coefficients starting from the most significant.
+/
auto coefficientsFromMostSignificant(UInt, WordEndian endian)(BigUIntView!(UInt, endian) number)
    @safe pure nothrow @nogc
{
    import mir.ndslice.slice: sliced;
    static if (endian == WordEndian.big)
    {
        return number.coefficients.sliced;
    }
    else
    {
        import mir.ndslice.topology: retro;
        return number.coefficients.sliced.retro;
    }
}

/++
Arbitrary length signed integer view.
+/
struct BigIntView(Int, WordEndian endian = MachineEndian)
    if (isSigned!Int)
{
    /++
    Self-assigned to unsigned integer view $(MREF BigUIntView).

    Sign is stored in the most significant bit.

    The number is encoded in two's-complement number system the same way
    as common fixed length signed intgers.
    +/
    BigUIntView!(Unsigned!Int, endian) unsigned;

    /++
    Sign bit
    +/
    bool sign;

    ///
    alias ConstThis = BigIntView!(const Int, endian);
    alias ConstUThis = BigUIntView!(const Unsigned!Int, endian);;

    ///
    ConstThis lightConst()
        const @safe pure nothrow @nogc @property
    {
        return typeof(return)(unsigned.lightConst, sign);
    }
    ///ditto
    alias lightConst this;

    /++
    +/
    sizediff_t opCmp(ConstThis rhs) const @safe pure nothrow @nogc
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
    bool opEquals(ConstThis rhs) const @safe pure nothrow @nogc @property
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
    Performs `big-=big` operatrion.
    Params:
        additive = unsigned value to add with non-empty coefficients
        overflow = (overflow) initial iteration overflow
    Precondition: non-empty coefficients length of greater or equal to the `rhs` coefficients length.
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op : "-")(ConstUThis rhs, bool overflow = false)
        @safe pure nothrow @nogc
    {
        assert(rhs.unsigned.coefficients.length > 0);
        assert(this.unsigned.coefficients.length >= rhs.unsigned.coefficients.length);
        if (sign)
            return unsigned.opOpAssign!"+"(additive, overflow);
        do
        {
            bool overflowM;
            ls.front = subu(ls.front, ls.front, overflowM);
            ls.front = subu(ls.front, overflow, overflow);
            overflow |= overflowM;
            ls.popFront;
            rs.popFront;
        }
        while(rs.length);
        if (overflow)
        {
            if (ls.length) do
            {
                ls.front = subu(ls.front, additive, overflow);
                if (!overflow)
                    return overflow;
                additive = overflow;
                ls.popFront;
            }
            while (ls.length);
            sign = !sign;
            applyNegative_assumeNonEmpty(unsigned);
        }
        return false;
    }

    bool opOpAssign(string op : "+")(ConstUThis rhs, bool overflow = false)
        @safe pure nothrow @nogc
    {
        assert(rhs.unsigned.coefficients.length > 0);
        assert(this.unsigned.coefficients.length >= rhs.unsigned.coefficients.length);
        sign = !sign;
        auto ret = this.opOpAssign!"-"(rhs, overflow);
        sign = !sign;
        return ret;
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
    bool opOpAssign(string op : "-")(ConstThis rhs, bool overflow = false)
        @safe pure nothrow @nogc
    {
        assert(rhs.unsigned.coefficients.length > 0);
        assert(this.unsigned.coefficients.length >= rhs.unsigned.coefficients.length);
        return rhs.sign
            ? this.opOpAssign!(op == "+" ? "-" : "+")(rhs.unsigned, overflow)
            : this.opOpAssign!op(rhs.unsigned, overflow);
    }

    bool opOpAssign(string op)(Int rhs)
        @safe pure nothrow @nogc
        if (op == "+" || op == "-")
    {
        assert(this.coefficients.length > 0);
        return additive < 0
            ? this.opOpAssign!(op == "+" ? "-" : "+")(cast(UInt)(-rhs))
            : this.opOpAssign!op(cast(UInt)(rhs));
    }

    /++
    Performs `big-=scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        additive = unsigned value to add
    Returns:
        true in case of unsigned overflow
    +/
    bool opOpAssign(string op : "-")(UInt additive)
        @safe pure nothrow @nogc
    {
        assert(this.coefficients.length > 0);
        if (sign)
            return unsigned += additive;
        auto ns = this.coefficientsFromLeastSignificant;
        do
        {
            ns.front = subu(ns.front, additive, overflow);
            if (!overflow)
                return overflow;
            additive = overflow;
            ns.popFront;
        }
        while (ns.length);
        sign != sign;
        applyNegative_assumeNonEmpty(unsigned);
        return false;
    }

    /++
    Returns: the same intger view with inversed sign
    +/
    BigIntView opUnary(string op : "-")(ConstThis rhs, bool overflow = false)
    {
        return BigIntView(unsigned, !sign);
    }
}

/++
Performs `number=-number` operatrion.
Params:
    number = (un)signed number view with non-empty coefficients
Returns:
    true if 'number=-number=0' and false otherwise
+/
bool applyNegative_assumeNonEmpty(UInt)(BigUIntView!UInt number)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
}
do {
    applyBitwiseNot_assumeNonEmpty(number);
    return applyUnsignedAdd_assumeNonEmpty(number, 1);
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

/++
An utility type to wrap a local buffer to accumulate unsigned numbers.
+/
struct BigIntAccumulator(Int, WordEndian endian = MachineEndian)
    if (isSigned!Int)
{
    /++
    Self-assigned to unsigned integer accumulator $(MREF BigUIntAccumulator).

    Sign is stored in the most significant bit of the current mist significant coeffecient.

    The number is encoded in two's-complement number system the same way
    as common fixed length signed intgers.
    +/
    BigUIntView!(Unsigned!Int) unsigned;
    /// Sign
    bool sign;

    /++
    Returns:
        Current signed integer view.
    +/
    BigIntView!Int view() @safe pure nothrow @nogc @property
    {
        return typeof(return)(unsigned.view, sign);
    }
}
