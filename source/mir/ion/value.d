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
    Returns: $(LREF IonErrorCode)
    +/
    IonErrorCode describe(out IonDescribedValue value)
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
Nullable boolean type.
+/
struct IonBool
{
    ///
    IonDescriptor descriptor;

    /++
    Returns: true if the boolean is `null.bool`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        assert (descriptor.type == IonTypeCode.bool_);
        return *descriptor.reference == 0x1F;
    }

    /++
    Params:
        rhs = right hand side value for `==` and `!=` expressions.
    Returns: true if the boolean isn't `null.bool` and equals to the `rhs`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(bool rhs) const
    {
        assert (descriptor.type == IonTypeCode.bool_);
        return descriptor.L == rhs;
    }
}

/++
Ion non-negative integer number.
+/
struct IonUInt
{
    ///
    ubyte[] data;

    /++
    Returns: true if the integer is `null.int`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
Ion negative integer number.
+/
struct IonNInt
{
    ///
    ubyte[] data;

    /++
    Returns: true if the integer is `null.int`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
Ion decimal number.
+/
struct IonDecimal
{
    ///
    ubyte[] data;

    /++
    Returns: true if the decimal is `null.decimal`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }

    /++
    Returns: true if the sexp is `null.sexp`, `null`, or `()`.
    Note: a NOP padding makes in the struct makes it non-empty.
    +/
    @safe pure nothrow @nogc
    bool empty() const @property
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }

    /++
    Returns: true if the sexp is `null.sexp`, `null`, or `()`.
    Note: a NOP padding makes in the struct makes it non-empty.
    +/
    @safe pure nothrow @nogc
    bool empty() const @property
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
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }

    /++
    Returns: true if the struct is `null.struct`, `null`, or `()`.
    Note: a NOP padding makes in the struct makes it non-empty.
    +/
    @safe pure nothrow @nogc
    bool empty() const @property
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
    Returns: $(LREF IonErrorCode)
    +/
    IonErrorCode unwrap(out IonAnnotations annotations, out IonDescribedValue value)
    {
        IonValue v;
        if (auto error = unwrap(annotations, v))
            return error;
        return v.describe(value);
    }

    /// ditto
    IonErrorCode unwrap(out IonAnnotations annotations, out IonValue value)
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
        {
            IonDescribedValue ret;
            if (auto error = unwrap(annotations, ret))
                throw error.ionException;
            return ret;
        }

        /// ditto
        IonDescribedValue unwrap()
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
    @safe pure nothrow @nogc
    bool empty() const @property
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

@safe pure nothrow @nogc
private IonErrorCode parseVarUInt(scope const(ubyte)[] data, ref size_t shift, out size_t result)
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

private @safe pure nothrow @nogc
IonErrorCode parseVarInt(scope const(ubyte)[] data, ref size_t shift, out sizediff_t result)
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

private @safe pure nothrow @nogc
IonParseResult parseValue(ubyte[] data, out IonDescribedValue describedValue)
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
