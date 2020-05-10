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
$(HTTP amzn.github.io/ion-docs/docs/binary.html#typed-value-formats, Typed Value Formats)
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
    D_type: $(LREF IonSymbol)
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

/// Aliases the $(LREF IonTypeCode) to the corresponding Ion type.
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
alias IonType(IonTypeCode code : IonTypeCode.symbol) = IonSymbol;
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
alias IonType(IonTypeCode code : IonTypeCode.annotations) = IonAnnotations;

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
    ubyte[] data;

    /++
    Describes value (nothrow version).
    Params:
        value = (out) $(LREF IonDescribedValue)
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode describe(out IonDescribedValue value)
        @safe pure nothrow @nogc
    {
        auto result = parseValue(data, value);
        if (_expect(result.error, false))
            return result.error;
        if (_expect(result.length != data.length, false))
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
            @safe pure @nogc
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
    ubyte* reference;

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
    ubyte[] data;
}

/++
Ion non-negative integer field.
+/
struct IonUIntField
{
    ///
    ubyte[] data;

    alias D = getUInt!ubyte;
    alias D = getUInt!ushort;
    alias D = getUInt!uint;
    alias D = getUInt!ulong;
    /++
    Params:
        value = (out) unsigned integer
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode getUInt(U)(out U value)
        @safe pure nothrow @nogc const
        if (is(U == ubyte) || is(U == ushort) || is(U == uint) || is(U == ulong))
    {
        auto d = cast()data;
        U f;
        if (d.length == 0)
            goto R;
        do
        {
            f = d[0];
            if (_expect(f, true))
            {
                if (_expect(d.length <= U.sizeof, true))
                {
                    for(;;)
                    {
                        d = d[1 .. $];
                        if (d.length == 0)
                        {
                            value = f;
                        R:
                            return IonErrorCode.none;
                        }
                        f <<= 8;
                        f = d[0];
                    }
                }
                return IonErrorCode.overflowInIntegerValue;
            }
            d = d[1 .. $];
        }
        while (d.length);
        goto R;
    }
}

/++
Ion integer field.
+/
struct IonIntField
{
    ///
    ubyte[] data;


    alias D = getInt!byte;
    alias D = getInt!short;
    alias D = getInt!int;
    alias D = getInt!long;

    /++
    Params:
        value = (out) signed integer
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode getInt(S)(out S value)
        @safe pure nothrow @nogc const
        if (is(S == byte) || is(S == short) || is(S == int) || is(S == long))
    {
        auto d = cast()data;
        S f;
        bool s;
        if (d.length == 0)
            goto R;
        f = d[0] & 0x7F;
        s = d[0] >> 7;
        goto S;
        do
        {
            f = d[0];
        S:
            if (_expect(f, true))
            {
                if (_expect(d.length <= S.sizeof, true))
                {
                    for(;;)
                    {
                        d = d[1 .. $];
                        if (d.length == 0)
                        {
                            if (_expect(f < 0, false))
                                goto O;
                            if (s)
                                f = cast(S)(0-f);
                            value = f;
                        R:
                            return IonErrorCode.none;
                        }
                        f <<= 8;
                        f = d[0];
                    }
                }
            O:
                return IonErrorCode.overflowInIntegerValue;
            }
            d = d[1 .. $];
        }
        while (d.length);
        goto R;
    }
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
    Params:
        value = (out) `bool`
    Returns: $(SUBREF exception, IonErrorCode)
    Note: `null.bool` will return `IonErrorCode.nullBool` error.
    +/
    IonErrorCode getBool(out bool value)
    {
        auto d = *descriptor.reference;
        value = d == 0x11;
        if (_expect(d <= 0x11, true))
            return IonErrorCode.none;
        if (d == 0x1F)
            return IonErrorCode.nullBool;
        return IonErrorCode.wrongBoolDescriptor;
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
        value = (out) unsigned integer
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode getUInt(U)(out U value)
        @safe pure nothrow @nogc const
        if (is(U == ubyte) || is(U == ushort) || is(U == uint) || is(U == ulong))
    {
        assert(this != null);
        return field.getUInt(value);
    }

    /++
    Params:
        value = (out) signed integer
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode getInt(S)(out S value)
        @trusted pure nothrow @nogc const
        if (is(S == byte) || is(S == short) || is(S == int) || is(S == long))
    {
        import std.traits: Unsigned;
        assert(this != null);
        if (auto error = field.getUInt(*cast(Unsigned!S*)&value))
            return error;
        if (_expect(value < 0, false))
            return IonErrorCode.overflowInIntegerValue;
        return IonErrorCode.none;
    }
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
        assert(field.data.length || this == null);
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
    IonErrorCode getUInt(U)(out U value)
        @safe pure nothrow @nogc const
        if (is(U == ubyte) || is(U == ushort) || is(U == uint) || is(U == ulong))
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
    IonErrorCode getInt(S)(out S value)
        @trusted pure nothrow @nogc const
        if (is(S == byte) || is(S == short) || is(S == int) || is(S == long))
    {
        import std.traits: Unsigned;
        assert(this != null);
        if (auto error = field.getUInt(*cast(Unsigned!S*)&value))
            return error;
        value = cast(S)(0-value);
        if (_expect(value >= 0, false))
            return IonErrorCode.overflowInIntegerValue;
        return IonErrorCode.none;
    }
}

/++
Ion floating point number.
+/
struct IonFloat
{
    ///
    ubyte[] data;

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
        value = (out) `double`
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode get(T : double)(out T value)
    {
        version (LittleEndian) import core.bitop : bswap;
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

    /++
    Params:
        value = (out) `float`
    Returns: $(SUBREF exception, IonErrorCode)
    Precondition: `this != null`.
    +/
    IonErrorCode get(T : float)(out T value)
    {
        version (LittleEndian) import core.bitop : bswap;
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
}

/++
Ion described decimal number.
+/
struct IonDecimal
{
    ///
    ubyte[] data;

    /++
    Returns: true if the decimal is `null.decimal`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
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
    ubyte[] data;

    /++
    Returns: true if the timestamp is `null.timestamp`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }
}

/++
Ion Symbol Id

In the binary encoding, all Ion symbols are stored as integer symbol IDs whose text values are provided by a symbol table.
If L is zero then the symbol ID is zero and the length and symbol ID fields are omitted.
+/
struct IonSymbol
{
    ///
    ubyte[] data;

    /++
    Returns: true if the symbol is `null.symbol`.
    +/
    bool opEquals(typeof(null))
        @safe pure nothrow @nogc const
    {
        return data is null;
    }
}

/++
Ion String.

These are always sequences of Unicode characters, encoded as a sequence of UTF-8 octets.
+/
struct IonString
{
    ///
    char[] data;

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
    char[] data;

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
    ubyte[] data;

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
    ubyte[] data;
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
    bool empty() const @property
        @safe pure nothrow @nogc
    {
        return data.length == 0;
    }

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
        size_t shift;
        while (shift < data.length)
        {
            IonDescribedValue describedValue;
            auto result = parseValue(data[shift .. $], describedValue);
            shift += result.length;
            if (result.error == IonErrorCode.nop)
                continue;
            if (auto ret = dg(result.error, describedValue))
                return ret;
            assert(result.error == IonErrorCode.none, "User provided delegate MUST break the iteration when error has non-zero value.");
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
    ubyte[] data;

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
    bool empty() const @property
        @safe pure nothrow @nogc
    {
        return data.length == 0;
    }

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
    ubyte[] data;
    private alias DG = scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value) @safe pure nothrow @nogc;
    private alias EDG = scope int delegate(size_t symbolId, IonDescribedValue value) @safe pure nothrow @nogc;

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
    bool empty() const @property
        @safe pure nothrow @nogc
    {
        return data.length == 0;
    }

    version (D_Exceptions)
    {
        /++
        +/
        @safe pure @nogc
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value) @safe pure @nogc dg)
        {
            return opApply((IonErrorCode error, size_t symbolId, IonDescribedValue value) {
                if (_expect(error, false))
                    throw error.ionException;
                return dg(symbolId, value);
            });
        }

        /// ditto
        @trusted @nogc
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @safe @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted pure
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @safe pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @trusted
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @safe dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure @nogc
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @system pure @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system @nogc
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @system @nogc dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system pure
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @system pure dg) { return opApply(cast(EDG) dg); }

        /// ditto
        @system
        int opApply(scope int delegate(size_t symbolId, IonDescribedValue value)
        @system dg) { return opApply(cast(EDG) dg); }
    }

    /++
    +/
    @safe pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value) @safe pure nothrow @nogc dg)
    {
        size_t shift;
        while (shift < data.length)
        {
            IonErrorCode error;
            size_t symbolId;
            IonDescribedValue describedValue;
            error = parseVarUInt(data, shift, symbolId);
            if (!error)
            {
                auto result = parseValue(data[shift .. $], describedValue);
                shift += result.length;
                error = result.error;
                if (!error == IonErrorCode.nop)
                    continue;
            }
            if (auto ret = dg(error, symbolId, describedValue))
                return ret;
            assert(error == IonErrorCode.none, "User provided delegate MUST break the iteration when error has non-zero value.");
        }
        return 0;
    }

    /// ditto
    @trusted nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @safe dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system pure nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value)
    @system dg) { return opApply(cast(DG) dg); }
}

/++
Ion Annotation Wrapper
+/
struct IonAnnotationWrapper
{
    ///
    ubyte[] data;

    /++
    Unwraps Ion annotations (nothrow version).
    Params:
        annotations = (out) $(LREF IonAnnotations)
        value = (out) $(LREF IonDescribedValue) or $(LREF IonValue)
    Returns: $(SUBREF exception, IonErrorCode)
    +/
    IonErrorCode unwrap(out IonAnnotations annotations, out IonDescribedValue value)
        @safe pure nothrow @nogc
    {
        IonValue v;
        if (auto error = unwrap(annotations, v))
            return error;
        return v.describe(value);
    }

    /// ditto
    IonErrorCode unwrap(out IonAnnotations annotations, out IonValue value)
        @safe pure nothrow @nogc
    {
        size_t shift;
        size_t length;
        if (auto error = parseVarUInt(data, shift, length))
            return error;
        auto d = data[shift .. $];
        if (_expect(length == 0, false))
            return IonErrorCode.zeroAnnotations;
        if (_expect(length >= data.length, false))
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
        IonDescribedValue unwrap(out IonAnnotations annotations)
            @safe pure @nogc
        {
            IonDescribedValue ret;
            if (auto error = unwrap(annotations, ret))
                throw error.ionException;
            return ret;
        }

        /// ditto
        IonDescribedValue unwrap()
            @safe pure @nogc
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
    ubyte[] data;
    private alias DG = int delegate(IonErrorCode error, size_t symbolId) @safe pure nothrow @nogc;

    /++
    Returns: true if no annotations provided.
    +/
    bool empty() const @property
        @safe pure nothrow @nogc
    {
        return data.length == 0;
    }

    /++
    +/
    @safe pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId) @safe pure nothrow @nogc dg)
    {
        size_t shift;
        assert(data.length);
        while (shift < data.length)
        {
            size_t symbolId;
            auto error = parseVarUInt(data, shift, symbolId);
            if (auto ret = dg(error, symbolId))
                return ret;
            assert(error == IonErrorCode.none, "User provided delegate MUST break the iteration when error has non-zero value.");
        }
        return 0;
    }

    /// ditto
    @trusted nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @trusted
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @safe dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system pure nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system nothrow @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system pure @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system pure nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system @nogc
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system @nogc dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system pure
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system pure dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system nothrow
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system nothrow dg) { return opApply(cast(DG) dg); }

    /// ditto
    @system
    int opApply(scope int delegate(IonErrorCode error, size_t symbolId)
    @system dg) { return opApply(cast(DG) dg); }
}

private IonErrorCode parseVarUInt(scope const(ubyte)[] data, ref size_t shift, out size_t result)
    @safe pure nothrow @nogc
{
    version(LDC) pragma(inline, true);
    enum mLength = size_t(1) << (size_t.sizeof * 8 / 7 * 7);
    for(;;)
    {
        if (_expect(data.length <= shift, false))
            return IonErrorCode.unexpectedEndOfData;
        ubyte b = data[shift++];
        result <<= 7;
        result |= b & 0x7F;
        if (cast(byte)b < 0)
            return IonErrorCode.none;
        if (_expect(result >= mLength, false))
            return IonErrorCode.overflowInParseVarUInt;
    }
}

private IonErrorCode parseVarInt(scope const(ubyte)[] data, ref size_t shift, out sizediff_t result)
    @safe pure nothrow @nogc
{
    version(LDC) pragma(inline, true);
    enum mLength = size_t(1) << (size_t.sizeof * 8 / 7 * 7 - 1);
    size_t length;
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
            result = neg ? -length : length;
            return IonErrorCode.none;
        }
        if (_expect(length >= mLength, false))
            return IonErrorCode.overflowInParseVarUInt;
    }
}

private struct IonParseResult
{
    IonErrorCode error;
    size_t length;
}

private IonParseResult parseValue(ubyte[] data, out IonDescribedValue describedValue)
    @safe pure nothrow @nogc
{
    version(LDC) pragma(inline, false);
    // import mir.bitop: ctlz;

    size_t shift = 0;

    if (_expect(data.length == 0, false))
        return typeof(return)(IonErrorCode.unexpectedEndOfData, shift);

    shift = 1;
    describedValue = IonDescribedValue(IonDescriptor((()@trusted => data.ptr)()));
    ubyte descriptorData = *describedValue.descriptor.reference;

    if (_expect(descriptorData > 0xEE, false))
        return typeof(return)(IonErrorCode.illegalTypeDescriptor, shift);

    const L = uint(descriptorData & 0xF);
    const type = cast(IonTypeCode)(descriptorData >> 4);
    // if null
    if (L == 0xF)
        return typeof(return)(IonErrorCode.none, shift);
    // if bool
    if (type == IonTypeCode.bool_)
    {
        if (_expect(L > 1, false))
            return typeof(return)(IonErrorCode.illegalTypeDescriptor, shift);
        return typeof(return)(IonErrorCode.none, shift);
    }
    size_t length = L;
    // if large
    if (length == 0xE)
    {
        if (auto error = parseVarUInt(data, shift, length))
            return typeof(return)(error, shift);
    }
    auto newShift = length + shift;
    if (_expect(newShift > data.length, false))
        return typeof(return)(IonErrorCode.unexpectedEndOfData, shift);
    describedValue.data = data[shift .. newShift];
    shift = newShift;

    // NOP Padding
    return typeof(return)(type == IonTypeCode.null_ ? IonErrorCode.nop : IonErrorCode.none, shift);
}

private double parseDouble(scope const(ubyte)[] data)
    @trusted pure nothrow @nogc
{
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
    version (LittleEndian) import core.bitop : bswap;
    assert(data.length == 4);
    float value;
    *cast(ubyte[4]*) &value = cast(ubyte[4]) data[0 .. 4];
    version (LittleEndian) *cast(uint*)&value = bswap(*cast(uint*)&value);
    return value;
}
