///
module mir.ion.value;

import mir.ion.exception;

import mir.utility: _expect;

/++
Ion Binary Version Marker
+/
struct IonVersionMarker
{
    /// Major Version
    ushort major = 1;
    /// Minor Version
    ushort minor = 0;
}

/++
Codes for $(HTTP amzn.github.io/ion-docs/docs/binary.html#typed-value-formats, Typed Value Formats)
+/
enum IonTypeCode
{
    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#0-null, 0: null)
    D_type: `typeof(null)`.
    +/
    null_,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#1-bool, 1: bool)
    D_type: $(LREF IonBool)
    +/
    bool_,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#2-and-3-int, 2 and 3: int)
    D_type: $(LREF IonUInt) and $(LREF IonNInt)
    +/
    uInt,
    /// ditto
    nInt,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#4-float, 4: float)
    D_type: $(LREF IonFloat)
    +/
    float_,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#5-decimal, 5: decimal)
    D_type: $(LREF IonDecimal)
    +/
    decimal,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#6-timestamp, 6: timestamp)
    D_type: $(LREF IonTimestamp)
    +/
    timestamp,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#7-symbol, 7: symbol)
    D_type: $(LREF IonSymbol)ID
    +/
    symbol,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#8-string, 8: string)
    D_type: $(LREF IonString)
    +/
    string,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#9-clob, 9: clob)
    D_type: $(LREF IonClob)
    +/
    clob,

    /++
    Spec: $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#0-blob, 10: blob)
    D_type: $(LREF IonBlob)
    +/
    blob,

    /++
    Spec: $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#1-list, 11: list)
    D_type: $(LREF IonList)
    +/
    list,

    /++
    Spec: $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#2-sexp, 12: sexp)
    D_type: $(LREF IonSexp)
    +/
    sexp,

    /++
    Spec: $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#3-struct, 13: struct)
    D_type: $(LREF IonStruct)
    +/
    struct_,

    /++
    Spec: $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#4-annotations, 14: Annotations)
    D_type: $(LREF IonAnnotationWrapper)
    +/
    annotations,
}

/// Aliases the $(LREF IonTypeCode) to the corresponding Ion Typed Value type.
alias IonType(IonTypeCode code : IonTypeCode.null_) = typeof(null);
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.bool_) = IonBool;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.uInt) = IonUInt;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.nInt) = IonNInt;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.float_) = IonFloat;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.decimal) = IonDecimal;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.timestamp) = IonTimestamp;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.symbol) = IonSymbolID;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.string) = IonString;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.clob) = IonClob;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.blob) = IonBlob;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.list) = IonList;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.sexp) = IonSexp;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.struct_) = IonStruct;
/// ditto
alias IonType(IonTypeCode code : IonTypeCode.annotations) = IonAnnotationWrapper;

/// Aliases the type to the corresponding $(LREF IonTypeCode).
alias IonTypeCodeOf(T : typeof(null)) = IonTypeCode.null_;
/// ditto
alias IonTypeCodeOf(T : IonBool) = IonTypeCode.bool_;
/// ditto
alias IonTypeCodeOf(T : IonUInt) = IonTypeCode.uInt;
/// ditto
alias IonTypeCodeOf(T : IonNInt) = IonTypeCode.nInt;
/// ditto
alias IonTypeCodeOf(T : IonFloat) = IonTypeCode.float_;
/// ditto
alias IonTypeCodeOf(T : IonDecimal) = IonTypeCode.decimal;
/// ditto
alias IonTypeCodeOf(T : IonTimestamp) = IonTypeCode.timestamp;
/// ditto
alias IonTypeCodeOf(T : IonSymbolID) = IonTypeCode.symbol;
/// ditto
alias IonTypeCodeOf(T : IonString) = IonTypeCode.string;
/// ditto
alias IonTypeCodeOf(T : IonClob) = IonTypeCode.clob;
/// ditto
alias IonTypeCodeOf(T : IonBlob) = IonTypeCode.blob;
/// ditto
alias IonTypeCodeOf(T : IonList) = IonTypeCode.list;
/// ditto
alias IonTypeCodeOf(T : IonSexp) = IonTypeCode.sexp;
/// ditto
alias IonTypeCodeOf(T : IonStruct) = IonTypeCode.struct_;
/// ditto
alias IonTypeCodeOf(T : IonAnnotationWrapper) = IonTypeCode.annotations;

/++
A template to check if the type is one of Ion Typed Value types.
See_also: $(LREF IonTypeCode)
+/
enum isIonType(T) = false;
/// ditto
enum isIonType(T : typeof(null)) = true;
/// ditto
enum isIonType(T : IonBool) = true;
/// ditto
enum isIonType(T : IonUInt) = true;
/// ditto
enum isIonType(T : IonNInt) = true;
/// ditto
enum isIonType(T : IonFloat) = true;
/// ditto
enum isIonType(T : IonDecimal) = true;
/// ditto
enum isIonType(T : IonTimestamp) = true;
/// ditto
enum isIonType(T : IonSymbolID) = true;
/// ditto
enum isIonType(T : IonString) = true;
/// ditto
enum isIonType(T : IonClob) = true;
/// ditto
enum isIonType(T : IonBool) = true;
/// ditto
enum isIonType(T : IonList) = true;
/// ditto
enum isIonType(T : IonSexp) = true;
/// ditto
enum isIonType(T : IonStruct) = true;
/// ditto
enum isIonType(T : IonAnnotationWrapper) = true;

/++
Ion Value

The type descriptor octet has two subfields: a four-bit type code T, and a four-bit length L.

----------
       7       4 3       0
      +---------+---------+
value |    T    |    L    |
      +---------+---------+======+
      :     length [VarUInt]     :
      +==========================+
      :      representation      :
      +==========================+
----------
+/
struct IonValue
{
    const(ubyte)[] data;

    /++
    Describes value (nothrow version).
    Params:
        value = (out) $(LREF IonDescribedValue)
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode describe(scope ref IonDescribedValue value)
        @safe pure nothrow @nogc const
    {
        auto d = data[];
        if (auto error = parseValue(d, value))
            return error;
        if (_expect(d.length, false))
            return IonErrorCode.illegalBinaryData;
        return IonErrorCode.none;
    }

    version (D_Exceptions)
    {
        /++
        Describes value.
        Returns: $(LREF IonDescribedValue)
        +/
        IonDescribedValue describe()
            @safe pure @nogc const
        {
            IonDescribedValue ret;
            if (auto error = describe(ret))
                throw error.ionException;
            return ret;
        }
    }

    /++
    Returns: GC-allocated copy.
    +/
    @safe pure nothrow const
    IonValue gcCopy()
    {
        return IonValue(data.dup);
    }
}

/++
Ion Type Descriptor
+/
struct IonDescriptor
{
    /++
    The type descriptor octet has two subfields: a four-bit type code T, and a four-bit length L.
    +/
    const(ubyte)* reference;

    /// T
    IonTypeCode type() @safe pure nothrow @nogc const @property
    {
        assert(reference);
        return cast(typeof(return))((*reference) >> 4);
    }
    /// L
    uint L() @safe pure nothrow @nogc const @property
    {
        assert(reference);
        return cast(typeof(return))((*reference) & 0xF);
    }
}

/++
Ion Described Value stores type descriptor and rerpresentation.
+/
struct IonDescribedValue
{
    /// Type Descriptor
    IonDescriptor descriptor;
    /// Rerpresentation
    const(ubyte)[] data;

    /++
    Returns: true if the blob is `null.blob`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return descriptor.L != 0xF;
    }

    ///
    IonBool getTrustedIon(T : bool)()
        @safe pure nothrow @nogc const
    {
        assert(descriptor.type == IonTypeCode.bool_);
        return IonBool(descriptor);
    }

    /++
    Returns:
        Ion Typed Value
    Note:
        This function doesn't check the encoded value type.
    +/
    T trustedGetTypedValue(T)()
        @safe pure nothrow @nogc const
        if (isIonType!T)
    {
        assert(descriptor.type == IonTypeCodeOf!T);
        static if (is(T == typeof(null)))
        {
            return T.init;
        }
        else
        static if (is(T == IonBool))
        {
            return T(descriptor);
        }
        else
        static if (is(T == IonStruct))
        {
            return T(descriptor, data);
        }
        else
        static if (is(T == IonString) || is(T == IonClob))
        {
            return T(cast(const(char)[])data);
        }
        else
        {
            return T(data);
        }
    }
}

/++
Ion non-negative integer field.
+/
struct IonUIntField
{
    ///
    const(ubyte)[] data;

    /++
    Params:
        value = (out) unsigned integer
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode getImpl(U)(scope ref U value)
        @safe pure nothrow @nogc const
    {
        auto d = cast()data;
        size_t i;
        U f;
        if (d.length == 0)
            goto R;
        for(;;)
        {
            f |= d[0];
            d = d[1 .. $];
            if (d.length == 0)
            {
            R:
                value = f;
                return IonErrorCode.none;
            }
            i += cast(bool)f;
            f <<= 8;
            if (_expect(i >= U.sizeof, false))
                return IonErrorCode.overflowInIntegerValue;
        }
    }

    /// ditto
    alias get = getImpl!ubyte;
    /// ditto
    alias get = getImpl!ushort;
    /// ditto
    alias get = getImpl!uint;
    /// ditto
    alias get = getImpl!ulong;
}

/++
Ion integer field.
+/
struct IonIntField
{
    ///
    const(ubyte)[] data;

    /++
    Params:
        value = (out) signed integer
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode getImpl(S)(scope ref S value)
        @safe pure nothrow @nogc const
    {

        auto d = cast()data;
        size_t i;
        S f;
        bool s;
        if (d.length == 0)
            goto R;
        f = d[0] & 0x7F;
        s = d[0] >> 7;
        for(;;)
        {
            d = d[1 .. $];
            if (d.length == 0)
            {
                if (_expect(f < 0, false))
                    break;
                if (s)
                    f = cast(S)(0-f);
            R:
                value = f;
                return IonErrorCode.none;
            }
            i += cast(bool)f;
            f <<= 8;
            f |= d[0];
            if (_expect(i >= S.sizeof, false))
                break;
        }
        return IonErrorCode.overflowInIntegerValue;
    }

    /// ditto
    alias get = getImpl!byte;
    /// ditto
    alias get = getImpl!short;
    /// ditto
    alias get = getImpl!int;
    /// ditto
    alias get = getImpl!long;
}

/++
Nullable boolean type. Encodes `false`, `true`, and `null.bool`.
+/
struct IonBool
{
    ///
    IonDescriptor descriptor;

    /++
    Returns: true if the boolean is `null.bool`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        assert (descriptor.type == IonTypeCode.bool_);
        return *descriptor.reference == 0x1F;
    }

    /++
    Params:
        rhs = right hand side value for `==` and `!=` expressions.
    Returns: true if the boolean isn't `null.bool` and equals to the `rhs`.
    +/
    bool opEquals(bool rhs)
        @safe pure nothrow @nogc const
    {
        assert (descriptor.type == IonTypeCode.bool_);
        return descriptor.L == rhs;
    }

    /++
    Returns: `bool`
    Note: value must not be equal to `null.bool`.
    +/
    bool get()
        @safe pure nothrow @nogc const
    {
        assert(descriptor.reference);
        auto d = *descriptor.reference;
        assert((d | 1) == 0x11);
        return cast(bool)(d | 1);
    }
}

/++
Ion non-negative integer number.
+/
struct IonUInt
{
    ///
    IonUIntField field;

    /++
    Returns: true if the integer is `null.int`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return field.data is null;
    }

    /++
    Returns: true if the integer isn't `null.int` and equals to `rhs`.
    +/
    bool opEquals(ulong rhs)
        @safe pure nothrow @nogc const
    {
        if (this == null)
            return false;
        foreach_reverse(d; field.data)
        {
            if (d != (rhs & 0xFF))
                return false;
            rhs >>>= 8;
        }
        return true;
    }

    /++
    Params:
        value = (out) unsigned or signed integer
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode getImplSigned(U)(scope ref U value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        return field.getImpl(value);
    }

    /// ditto
    IonErrorCode getImplUnsigned(S)(scope ref S value)
        @trusted pure nothrow @nogc const
    {
        import std.traits: Unsigned;
        assert(this != null);
        if (auto error = field.getImpl(*cast(Unsigned!S*)&value))
            return error;
        if (_expect(value < 0, false))
            return IonErrorCode.overflowInIntegerValue;
        return IonErrorCode.none;
    }

    /// ditto
    alias get = getImplUnsigned!ubyte;
    /// ditto
    alias get = getImplUnsigned!ushort;
    /// ditto
    alias get = getImplUnsigned!uint;
    /// ditto
    alias get = getImplUnsigned!ulong;
    /// ditto
    alias get = getImplSigned!byte;
    /// ditto
    alias get = getImplSigned!short;
    /// ditto
    alias get = getImplSigned!int;
    /// ditto
    alias get = getImplSigned!long;
}

/++
Ion negative integer number.
+/
struct IonNInt
{
    ///
    IonUIntField field;

    /++
    Returns: true if the integer is `null.int`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return field.data is null;
    }

    /++
    Returns: true if the integer isn't `null.int` and equals to `rhs`.
    +/
    bool opEquals(long rhs)
        @safe pure nothrow @nogc const
    {
        if (rhs >= 0)
            return false;
        return IonUInt(IonUIntField((()@trusted => cast(ubyte[])field.data)())) == ulong(rhs);
    }

    /++
    Params:
        value = (out) unsigned integer
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode getImplUnsigned(U)(scope ref U value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        return IonErrorCode.overflowInIntegerValue;
    }

    /++
    Params:
        value = (out) signed integer
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode getImplSigned(S)(scope ref S value)
        @trusted pure nothrow @nogc const
    {
        import std.traits: Unsigned;
        assert(this != null);
        if (auto error = field.get(*cast(Unsigned!S*)&value))
            return error;
        value = cast(S)(0-value);
        if (_expect(value >= 0, false))
            return IonErrorCode.overflowInIntegerValue;
        return IonErrorCode.none;
    }

    /// ditto
    alias get = getImplUnsigned!ubyte;
    /// ditto
    alias get = getImplUnsigned!ushort;
    /// ditto
    alias get = getImplUnsigned!uint;
    /// ditto
    alias get = getImplUnsigned!ulong;
    /// ditto
    alias get = getImplSigned!byte;
    /// ditto
    alias get = getImplSigned!short;
    /// ditto
    alias get = getImplSigned!int;
    /// ditto
    alias get = getImplSigned!long;
}

/++
Ion floating point number.
+/
struct IonFloat
{
    ///
    const(ubyte)[] data;

    /++
    Returns: true if the float is `null.float`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }

    /++
    Params:
        value = (out) `float`, `double`, or `real`
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode get(scope ref float value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        value = 0;
        if (data.length == 4)
        {
            value = parseSingle(data);
            return IonErrorCode.none;
        }
        if (data.length == 8)
        {
            value = parseDouble(data);
            return IonErrorCode.none;
        }
        if (_expect(data.length, false))
            return IonErrorCode.wrongFloatDescriptor;
        return IonErrorCode.none;
    }

    /// ditto
    IonErrorCode get(scope ref double value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        value = 0;
        if (data.length == 8)
        {
            value = parseDouble(data);
            return IonErrorCode.none;
        }
        if (data.length == 4)
        {
            value = parseSingle(data);
            return IonErrorCode.none;
        }
        if (_expect(data.length, false))
            return IonErrorCode.wrongFloatDescriptor;
        return IonErrorCode.none;
    }

    /// ditto
    IonErrorCode get(scope ref real value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        value = 0;
        if (data.length == 8)
        {
            value = parseDouble(data);
            return IonErrorCode.none;
        }
        if (data.length == 4)
        {
            value = parseSingle(data);
            return IonErrorCode.none;
        }
        if (_expect(data.length, false))
            return IonErrorCode.wrongFloatDescriptor;
        return IonErrorCode.none;
    }
}

/++
+/
struct IonDescribedDecimal
{
    import std.traits: isFloatingPoint;

    ///
    sizediff_t exponent;
    ///
    IonIntField coefficient;

    /++
    Params:
        value = (out) `float`, `double`, or `real`
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode getImpl(F)(scope ref F value)
        @safe pure nothrow @nogc const
    {
        // TODO: more precise algorithm
        long coeff;
        if (auto error = coefficient.get(coeff))
            return error;
        F v = coeff;
        if (v)
        {
            import mir.utility: min, max;
            import mir.math.common: powi;
            v *= powi(F(10), cast(int) exponent.max(int.min).max(int.min));
        }
        value = v;
        return IonErrorCode.none;
    }

    ///ditto
    alias get = getImpl!float;
    ///ditto
    alias get = getImpl!double;
    ///ditto
    alias get = getImpl!real;
}

/++
Ion described decimal number.
+/
struct IonDecimal
{
    ///
    const(ubyte)[] data;

    /++
    Returns: true if the decimal is `null.decimal`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }

    /++
    Describes decimal (nothrow version).
    Params:
        value = (out) $(LREF IonDescribedDecimal)
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode describe(scope ref IonDescribedDecimal value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        const(ubyte)[] d = data;
        if (auto error = parseVarInt(d, value.exponent))
            return error;
        value.coefficient = IonIntField(d);
        return IonErrorCode.none;
    }

    version (D_Exceptions)
    {
        /++
        Describes decimal.
        Returns: $(LREF IonDescribedDecimal)
        +/
        IonDescribedDecimal describe()
            @safe pure @nogc const
        {
            IonDescribedDecimal ret;
            if (auto error = describe(ret))
                throw error.ionException;
            return ret;
        }
    }
}

/++
Ion Timestamp

Timestamp representations have 7 components, where 5 of these components are optional depending on the precision of the timestamp.
The 2 non-optional components are offset and year.
The 5 optional components are (from least precise to most precise): `month`, `day`, `hour` and `minute`, `second`, `fraction_exponent` and `fraction_coefficient`.
All of these 7 components are in Universal Coordinated Time (UTC).
+/
struct IonTimestamp
{
    ///
    const(ubyte)[] data;

    /++
    Returns: true if the timestamp is `null.timestamp`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }

    /++
    Describes decimal (nothrow version).
    Params:
        value = (out) $(LREF IonDescribedTimestamp)
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode describe(scope ref IonDescribedTimestamp value)
        @safe pure nothrow @nogc const
    {
        pragma(inline, false);
        assert(this != null);
        auto d = data[];
        IonDescribedTimestamp v;
        if (auto error = parseVarInt(d, v.offset))
            return error;
        if (auto error = parseVarInt(d, v.year))
            return error;

        if (d.length == 0)
            goto R;
        if (auto error = parseVarUInt(d, v.month))
            return error;
        if (v.month == 0 || v.month > 12)
            return IonErrorCode.illegalTimeStamp;
        v.precision = v.precision.month;

        import mir.date: maxDay;
        if (d.length == 0)
            goto R;
        if (auto error = parseVarUInt(d, v.day))
            return error;
        if (v.day == 0 || v.day > maxDay(v.year, v.month))
            return IonErrorCode.illegalTimeStamp;
        v.precision = v.precision.day;

        if (d.length == 0)
            goto R;
        if (auto error = parseVarUInt(d, v.hour))
            return error;
        if (v.hour >= 24)
            return IonErrorCode.illegalTimeStamp;
        {            
            typeof(v.minute) minute;
            if (auto error = parseVarUInt(d, minute))
                return error;
            if (v.minute >= 60)
                return IonErrorCode.illegalTimeStamp;
            v.minute = minute;
        }
        v.precision = v.precision.minute;

        if (d.length == 0)
            goto R;
        {
            typeof(v.second) second;
            if (auto error = parseVarUInt(d, second))
                return error;
            if (v.second >= 60)
                return IonErrorCode.illegalTimeStamp;
            v.second = second;
        }
        v.precision = v.precision.second;

        if (d.length == 0)
            goto R;
        {
            typeof(v.fractionExponent) fractionExponent;
            long fractionCoefficient;
            if (auto error = parseVarInt(d, fractionExponent))
                return error;
            if (auto error = IonIntField(d).get(fractionCoefficient))
                return error;
            if (fractionCoefficient == 0 && fractionExponent >= 0)
                goto R;
            static immutable exps = [
                1L,
                10L,
                100L,
                1_000L,
                10_000L,
                100_000L,
                1_000_000L,
                10_000_000L,
                100_000_000L,
                1_000_000_000L,
                10_000_000_000L,
                100_000_000_000L,
                1_000_000_000_000L,
            ];
            if (fractionExponent < -12
             || fractionExponent > 0
             || fractionCoefficient < 0
             || fractionCoefficient > exps[0-fractionExponent])
                return IonErrorCode.illegalTimeStamp;
            v.fractionExponent = fractionExponent;
            v.fractionCoefficient = fractionCoefficient;
        }
        v.precision = v.precision.fraction;
    R:
        value = v;
        return IonErrorCode.none;
    }

    version (D_Exceptions)
    {
        /++
        Describes decimal.
        Returns: $(LREF IonDescribedTimestamp)
        +/
        IonDescribedTimestamp describe()
            @safe pure @nogc const
        {
            IonDescribedTimestamp ret;
            if (auto error = describe(ret))
                throw error.ionException;
            return ret;
        }
    }
}

/++
Ion Described Timestamp

Note: The component values in the binary encoding are always in UTC, while components in the text encoding are in the local time! This means that transcoding requires a conversion between UTC and local time.

`IonDescribedTimestamp` precision is up to `10^-12` seconds;
+/
struct IonDescribedTimestamp
{
    ///
    enum Precision : ubyte
    {
        ///
        year,
        ///
        month,
        ///
        day,
        ///
        minute,
        ///
        second,
        ///
        fraction,
    }

    /++
    The offset denotes the local-offset portion of the timestamp, in minutes difference from UTC.
    +/
    short offset;
    /++
    Year
    +/
    short year;
    /++
    +/
    Precision precision;

    /++
    Month
    
    If the value equals to thero then this and all the following members are undefined.
    +/
    ubyte month;
    /++
    Day
    
    If the value equals to thero then this and all the following members are undefined.
    +/
    ubyte day;
    /++
    Hour
    +/
    ubyte hour;

    version(D_Ddoc)
    {
    
        /++
        Minute

        Note: the field is implemented as property.
        +/
        ubyte minute;
        /++
        Second

        Note: the field is implemented as property.
        +/
        ubyte second;
        /++
        Fraction

        The `fraction_exponent` and `fraction_coefficient` denote the fractional seconds of the timestamp as a decimal value
        The fractional seconds’ value is `coefficient * 10 ^ exponent`.
        It must be greater than or equal to zero and less than 1.
        A missing coefficient defaults to zero.
        Fractions whose coefficient is zero and exponent is greater than -1 are ignored.
        
        'fractionCoefficient' allowed values are [0 ... 10^12-1].
        'fractionExponent' allowed values are [-12 ... 0].

        Note: the fields are implemented as property.
        +/
        byte fractionExponent;
        /// ditto
        ulong fractionCoefficient;
    }
    else
    {
        import mir.bitmanip: bitfields;
        version (LittleEndian)
        {

            mixin(bitfields!(
                    ubyte, "minute", 8,
                    ubyte, "second", 8,
                    byte, "fractionExponent", 8,
                    ulong, "fractionCoefficient", 40,
            ));
        }
        else
        {
            mixin(bitfields!(
                    ulong, "fractionCoefficient", 40,
                    byte, "fractionExponent", 8,
                    ubyte, "second", 8,
                    ubyte, "minute", 8,
            ));
        }
    }
}

/++
Ion Symbol Id

In the binary encoding, all Ion symbols are stored as integer symbol IDs whose text values are provided by a symbol table.
If L is zero then the symbol ID is zero and the length and symbol ID fields are omitted.
+/
struct IonSymbolID
{
    ///
    IonUIntField representation;

    /++
    Returns: true if the symbol is `null.symbol`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return representation.data is null;
    }

    /++
    Params:
        value = (out) symbol id
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode get(scope ref size_t value)
        @safe pure nothrow @nogc const
    {
        assert(this != null);
        return representation.getImpl(value);
    }
}

/++
Ion String.

These are always sequences of Unicode characters, encoded as a sequence of UTF-8 octets.
+/
struct IonString
{
    ///
    const(char)[] data;

    /++
    Returns: true if the string is `null.string`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }
}

/++
Ion Clob

Values of type clob are encoded as a sequence of octets that should be interpreted as text
with an unknown encoding (and thus opaque to the application).
+/
struct IonClob
{
    ///
    const(char)[] data;

    /++
    Returns: true if the clob is `null.clob`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }
}

/++
Ion Blob

This is a sequence of octets with no interpretation (and thus opaque to the application).
+/
struct IonBlob
{
    ///
    const(ubyte)[] data;

    /++
    Returns: true if the blob is `null.blob`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }
}

/++
Ion List (array)
+/
struct IonList
{
    ///
    const(ubyte)[] data;
    private alias DG = scope int delegate(IonErrorCode error, IonDescribedValue value) @safe pure nothrow @nogc;
    private alias EDG = scope int delegate(IonDescribedValue value) @safe pure @nogc;

    /++
    Returns: true if the sexp is `null.sexp`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }

    /++
    Returns: true if the sexp is `null.sexp`, `null`, or `()`.
    Note: a NOP padding makes in the struct makes it non-empty.
    +/
    bool empty()
        @safe pure nothrow @nogc const @property
    {
        return data.length == 0;
    }

const:

    version (D_Exceptions)
    {
        /++
        +/
        @safe pure @nogc
        int opApply(scope int delegate(IonDescribedValue value) @safe pure @nogc dg)
        {
            return opApply((IonErrorCode error, IonDescribedValue value) {
                if (_expect(error, false))
                    throw error.ionException;
                return dg(value);
            });
        }

        /// ditto
        @trusted @nogc
        int opApply(scope int delegate(IonDescribedValue value)
        @safe @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted pure
        int opApply(scope int delegate(IonDescribedValue value)
        @safe pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted
        int opApply(scope int delegate(IonDescribedValue value)
        @safe dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure @nogc
        int opApply(scope int delegate(IonDescribedValue value)
        @system pure @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system @nogc
        int opApply(scope int delegate(IonDescribedValue value)
        @system @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure
        int opApply(scope int delegate(IonDescribedValue value)
        @system pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system
        int opApply(scope int delegate(IonDescribedValue value)
        @system dg) { return opApply(cast(EDG) dg); }
    }

    /++
    +/
    @safe pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value) @safe pure nothrow @nogc dg)
    {
        auto d = data[];
        while (d.length)
        {
            IonDescribedValue describedValue;
            auto error = parseValue(d, describedValue);
            if (error == IonErrorCode.nop)
                continue;
            if (auto ret = dg(error, describedValue))
                return ret;
            assert(!error, "User provided delegate MUST break the iteration when error has non-zero value.");
        }
        return 0;
    }

    /// ditto
    @trusted nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system dg) { return opApply(cast(DG) dg); }
}

unittest
{
    foreach (errorCode, describedValue; IonList.init)
    {
        if (errorCode)
            break;
        //
    }
}

/++
Ion Sexp (symbol expression, array)
+/
struct IonSexp
{
    /// data view.
    const(ubyte)[] data;

    private alias DG = IonList.DG;
    private alias EDG = IonList.EDG;

    /++
    Returns: true if the sexp is `null.sexp`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }

    /++
    Returns: true if the sexp is `null.sexp`, `null`, or `()`.
    Note: a NOP padding makes in the struct makes it non-empty.
    +/
    bool empty()
        @safe pure nothrow @nogc const @property
    {
        return data.length == 0;
    }

const:

    version (D_Exceptions)
    {
        /++
        +/
        @safe pure @nogc
        int opApply(scope int delegate(IonDescribedValue value) @safe pure @nogc dg)
        {
            return IonList(data).opApply(dg);
        }

        /// ditto
        @trusted @nogc
        int opApply(scope int delegate(IonDescribedValue value)
        @safe @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted pure
        int opApply(scope int delegate(IonDescribedValue value)
        @safe pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted
        int opApply(scope int delegate(IonDescribedValue value)
        @safe dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure @nogc
        int opApply(scope int delegate(IonDescribedValue value)
        @system pure @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system @nogc
        int opApply(scope int delegate(IonDescribedValue value)
        @system @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure
        int opApply(scope int delegate(IonDescribedValue value)
        @system pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system
        int opApply(scope int delegate(IonDescribedValue value)
        @system dg) { return opApply(cast(EDG) dg); }
    }

    /++
    +/
    @safe pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value) @safe pure nothrow @nogc dg)
    {
        return IonList(data).opApply(dg);
    }

    /// ditto
    @trusted nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @safe dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system @nogc
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system
    int opApply(scope int delegate(IonErrorCode error, IonDescribedValue value)
    @system dg) { return opApply(cast(DG) dg); }
}

/++
Ion struct (object)
+/
struct IonStruct
{
    ///
    IonDescriptor descriptor;
    ///
    const(ubyte)[] data;

    private alias DG = scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value) @safe pure nothrow @nogc;
    private alias EDG = scope int delegate(size_t symbolID, IonDescribedValue value) @safe pure nothrow @nogc;

    ///
    bool sorted()
        @safe pure nothrow @nogc const @property
    {
        return descriptor.L == 1;
    }

    /++
    Returns: true if the struct is `null.struct`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }

    /++
    Returns: true if the struct is `null.struct`, `null`, or `()`.
    Note: a NOP padding makes in the struct makes it non-empty.
    +/
    bool empty()
        @safe pure nothrow @nogc const @property
    {
        return data.length == 0;
    }

const:

    version (D_Exceptions)
    {
        /++
        +/
        @safe pure @nogc
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value) @safe pure @nogc dg)
        {
            return opApply((IonErrorCode error, size_t symbolID, IonDescribedValue value) {
                if (_expect(error, false))
                    throw error.ionException;
                return dg(symbolID, value);
            });
        }

        /// ditto
        @trusted @nogc
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @safe @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted pure
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @safe pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @safe dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure @nogc
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @system pure @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system @nogc
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @system @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @system pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system
        int opApply(scope int delegate(size_t symbolID, IonDescribedValue value)
        @system dg) { return opApply(cast(EDG) dg); }
    }

    /++
    +/
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value) @safe pure nothrow @nogc dg)
        @safe pure nothrow @nogc
    {
        size_t shift;
        auto d = data[];
        while (d.length)
        {
            size_t symbolID;
            IonDescribedValue describedValue;
            auto error = parseVarUInt(d, symbolID);
            if (!error)
            {
                error = parseValue(d, describedValue);
                if (error == IonErrorCode.nop)
                    continue;
            }
            if (auto ret = dg(error, symbolID, describedValue))
                return ret;
            assert(!error, "User provided delegate MUST break the iteration when error has non-zero value.");
        }
        return 0;
    }

    /// ditto
    @trusted nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @safe dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system pure nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID, IonDescribedValue value)
    @system dg) { return opApply(cast(DG) dg); }
}

/++
Ion Annotation Wrapper
+/
struct IonAnnotationWrapper
{
    ///
    const(ubyte)[] data;

    /++
    Unwraps Ion annotations (nothrow version).
    Params:
        annotations = (out) $(LREF IonAnnotations)
        value = (out, optional) $(LREF IonDescribedValue) or $(LREF IonValue)
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode unwrap(scope ref IonAnnotations annotations, scope ref IonDescribedValue value)
        @safe pure nothrow @nogc const
    {
        IonValue v;
        if (auto error = unwrap(annotations, v))
            return error;
        return v.describe(value);
    }

    /// ditto
    IonErrorCode unwrap(scope ref IonAnnotations annotations, scope ref IonValue value)
        @safe pure nothrow @nogc const
    {
        size_t shift;
        size_t length;
        const(ubyte)[] d = data;
        if (auto error = parseVarUInt(d, length))
            return error;
        if (_expect(length == 0, false))
            return IonErrorCode.zeroAnnotations;
        if (_expect(length >= d.length, false))
            return IonErrorCode.unexpectedEndOfData;
        annotations = IonAnnotations(d[0 .. length]);
        value = IonValue(d[length .. $]);
        return IonErrorCode.none;
    }

    version (D_Exceptions)
    {
        /++
        Unwraps Ion annotations.
        Params:
            annotations = (optional out) $(LREF IonAnnotations)
        Returns: $(LREF IonDescribedValue)
        +/
        IonDescribedValue unwrap(scope ref IonAnnotations annotations)
            @safe pure @nogc const
        {
            IonDescribedValue ret;
            if (auto error = unwrap(annotations, ret))
                throw error.ionException;
            return ret;
        }

        /// ditto
        IonDescribedValue unwrap()
            @safe pure @nogc const
        {
            IonAnnotations annotations;
            return unwrap(annotations);
        }
    }

}

/++
+/
struct IonAnnotations
{
    ///
    const(ubyte)[] data;
    private alias DG = int delegate(IonErrorCode error, size_t symbolID) @safe pure nothrow @nogc;

    /++
    Returns: true if no annotations provided.
    +/
    bool empty()
        @safe pure nothrow @nogc const @property
    {
        return data.length == 0;
    }

const:

    /++
    +/
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID) @safe pure nothrow @nogc dg)
        @safe pure nothrow @nogc
    {
        auto d = data[];
        while (d.length)
        {
            size_t symbolID;
            auto error = parseVarUInt(d, symbolID);
            if (auto ret = dg(error, symbolID))
                return ret;
            assert(!error, "User provided delegate MUST break the iteration when error has non-zero value.");
        }
        return 0;
    }

    /// ditto
    @trusted nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @safe dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system pure nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system
    int opApply(scope int delegate(IonErrorCode error, size_t symbolID)
    @system dg) { return opApply(cast(DG) dg); }
}

private IonErrorCode parseVarUInt(U)(scope ref const(ubyte)[] data, scope out U result)
    @safe pure nothrow @nogc
    if (is(U == ubyte) || is(U == ushort) || is(U == uint) || is(U == ulong))
{
    version(LDC) pragma(inline, true);
    enum mLength = size_t(1) << (size_t.sizeof * 8 / 7 * 7);
    for(;;)
    {
        if (_expect(data.length == 0, false))
            return IonErrorCode.unexpectedEndOfData;
        ubyte b = data[0];
        result <<= 7;
        result |= b & 0x7F;
        if (cast(byte)b < 0)
            return IonErrorCode.none;
        if (_expect(result >= mLength, false))
            return IonErrorCode.overflowInParseVarUInt;
    }
}

private IonErrorCode parseVarInt(S)(scope ref const(ubyte)[] data, scope out S result)
    @safe pure nothrow @nogc
    if (is(S == byte) || is(S == short) || is(S == int) || is(S == long))
{
    version(LDC) pragma(inline, true);
    enum mLength = S(1) << (S.sizeof * 8 / 7 * 7 - 1);
    S length;
    if (_expect(data.length == 0, false))
        return IonErrorCode.unexpectedEndOfData;
    ubyte b = data[0];
    data = data[1 .. $];
    bool neg;
    if (b & 0x40)
    {
        neg = true;
        b ^= 0x40;
    }
    length =  b & 0x7F;
    goto L;
    for(;;)
    {
        if (_expect(data.length == 0, false))
            return IonErrorCode.unexpectedEndOfData;
        b = data[0];
        data = data[1 .. $];
        length <<= 7;
        length |= b & 0x7F;
    L:
        if (cast(byte)b < 0)
        {
            result = neg ? cast(S)(0-length) : length;
            return IonErrorCode.none;
        }
        if (_expect(length >= mLength, false))
            return IonErrorCode.overflowInParseVarUInt;
    }
}

private IonErrorCode parseValue(ref const(ubyte)[] data, scope ref IonDescribedValue describedValue)
    @safe pure nothrow @nogc
{
    version(LDC) pragma(inline, true);

    if (_expect(data.length == 0, false))
        return IonErrorCode.unexpectedEndOfData;
    auto descriptorPtr = &data[0];
    data = data[1 .. 0];
    ubyte descriptorData = *descriptorPtr;

    if (_expect(descriptorData > 0xEE, false))
        return IonErrorCode.illegalTypeDescriptor;

    describedValue = IonDescribedValue(IonDescriptor(descriptorPtr));

    const L = uint(descriptorData & 0xF);
    const type = cast(IonTypeCode)(descriptorData >> 4);
    // if null
    if (L == 0xF)
        return IonErrorCode.none;
    // if bool
    if (type == IonTypeCode.bool_)
    {
        if (_expect(L > 1, false))
            return IonErrorCode.illegalTypeDescriptor;
        return IonErrorCode.none;
    }
    size_t length = L;
    // if large
    bool sortedStruct = descriptorData == 0xD1;
    if (length == 0xE || sortedStruct)
    {
        if (auto error = parseVarUInt(data, length))
            return error;
    }
    if (_expect(length > data.length, false))
        return IonErrorCode.unexpectedEndOfData;
    describedValue.data = data[0 .. length];
    data = data[length .. $];
    // NOP Padding
    return type == IonTypeCode.null_ ? IonErrorCode.nop : IonErrorCode.none;
}

private double parseDouble(scope const(ubyte)[] data)
    @trusted pure nothrow @nogc
{
    version(LDC) pragma(inline, true);
    version (LittleEndian) import core.bitop : bswap;
    assert(data.length == 8);
    double value;
    *cast(ubyte[8]*) &value = cast(ubyte[8]) data[0 .. 8];
    version (LittleEndian) *cast(ulong*)&value = bswap(*cast(ulong*)&value);
    return value;
}

private float parseSingle(scope const(ubyte)[] data)
    @trusted pure nothrow @nogc
{
    version(LDC) pragma(inline, true);
    version (LittleEndian) import core.bitop : bswap;
    assert(data.length == 4);
    float value;
    *cast(ubyte[4]*) &value = cast(ubyte[4]) data[0 .. 4];
    version (LittleEndian) *cast(uint*)&value = bswap(*cast(uint*)&value);
    return value;
}
