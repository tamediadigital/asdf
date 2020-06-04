/++
+/
module mir.bignum.big_int;

import std.traits;
import mir.bitop;
import mir.utility;

/++
Stack-allocated big fixed length signed integer for.
+/
struct BigInt(size_t maxSize64)
    if (maxSize64 && maxSize64 <= ushort.max)
{
    bool sign;
    uint length;
    size_t[ulong.sizeof / size_t.sizeof * size64] data = void;

    @disable this(this);

    ///
    BigInt copy() @property
    {
        return BigInt(sign, length, data);
    }

    ///
    BigIntView!size_t view() @property
    {
        version (LittleEndian)
            return typeof(return)(sign, data[0 .. length]);
        else
            return typeof(return)(sign, data[$ - length .. $]);
    }

    ///
    alias this view;

    ///
    void normalize()
    {
        length = view.normalize.length;
    }

    /++
    +/
    void putCoefficient(size_t value)
    {
        assert(length < data.length);
        version (LittleEndian)
            data[length++] = value;
        else
            data[$ - ++length] = value;
    }

    /++
    Performs `size_t overflow = big *= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = unsigned value to multiply by
    Returns:
        unsigned overflow value
    +/
    size_t opOpAssign(string op : "*")(size_t rhs, size_t overflow = 0u)
        @safe pure nothrow @nogc
    {
        overflow = view.unsigned.opOpAssign!op(rhs, overflow);
        if (overflow && length < data.length)
        {
            putCoefficient(overflow);
            overflow = 0;
        }
        return overflow;
    }

    /++
    Performs `size_t overflow = big *= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = signed value to multiply by
    Returns:
        unsigned overflow value
    +/
    size_t opOpAssign(string op : "*")(sizediff_t rhs, size_t overflow = 0u)
        @safe pure nothrow @nogc
    {
        auto flip = rhs < 0;
        this.sign ^= flip;
        return opOpAssign!"*"(cast(size_t) (flip ? -rhs : rhs), overflow);
    }

    /++
    Performs `size_t overflow = big *= scalar` operatrion.
    Precondition: non-empty coefficients
    Params:
        rhs = signed value to multiply by
    Returns:
        unsigned overflow value
    +/
    bool opOpAssign(string op : "*")(BigIntView!(const size_t) rhs)
        @safe pure nothrow @nogc
    {
        auto flip = rhs < 0;
        this.sign ^= flip;
        return opOpAssign!"*"(cast(size_t) (flip ? -rhs : rhs), overflow);
    }
}
