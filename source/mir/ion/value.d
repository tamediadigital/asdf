module mir.ion.value;

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
Ion Value
+/
struct IonValue
{
    ubyte[] data;

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
+/
enum IonErrorCode
{
    nop = -1,
    none = 0,
    illegalTypeDescriptor,
    unexpectedEndOfData,
    overflowInParseVarUInt,
    overflowInParseVarInt,
    zeroAnnotations,
}

/++
+/
struct IonDescriptor
{
    ubyte* reference;

    ///
    IonType type() @safe pure nothrow @nogc const @property
    {
        assert(reference);
        return cast(typeof(return))((*reference) >> 4);
    }
    ///
    uint L() @safe pure nothrow @nogc const @property
    {
        assert(reference);
        return cast(typeof(return))((*reference) & 0xF);
    }
}

/++
+/
struct IonDescribedValue
{
    ///
    IonDescriptor descriptor;
    ///
    ubyte[] data;
}

struct VarUIntResult
{
    IonErrorCode error;
    size_t result;
}

struct VarIntResult
{
    IonErrorCode error;
    sizediff_t result;
}

struct ParseResult
{
    IonErrorCode error;
    size_t length;
}

/++
+/
@safe pure nothrow @nogc
IonErrorCode parseVarUInt(scope const(ubyte)[] data, ref size_t shift, out size_t result)
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

/++
+/
@safe pure nothrow @nogc
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

/++
+/
@safe pure nothrow @nogc
ParseResult parseValue(ubyte[] data, out IonDescribedValue describedValue)
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
    const type = cast(IonType)(descriptorData >> 4);
    // if null
    if (L == 0xF)
        return typeof(return)(IonErrorCode.none, shift);
    // if bool
    if (type == IonType.bool_)
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
    return typeof(return)(type == IonType.null_ ? IonErrorCode.nop : IonErrorCode.none, shift);
}


/++
+/
struct IonClobChar
{
    ///
    ubyte code;
}

/++
Nullable boolean type.
+/
enum IonBool : byte
{
    ///
    null_ = -1,
    ///
    false_ = 0,
    ///
    true_ = 1,
}

/++
+/
struct IonUInt
{
    ///
    ubyte[] data;

    /++
    Returns: true if the integer is `null.int` or `null`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
+/
struct IonNInt
{
    ///
    ubyte[] data;

    /++
    Returns: true if the integer is `null.int` or `null`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
+/
struct IonFloat
{
    ///
    ubyte[] data;

    /++
    Returns: true if the float is `null.float` or `null`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
+/
struct IonDecimal
{
    ///
    ubyte[] data;

    /++
    Returns: true if the decimal is `null.decimal` or `null`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
+/
struct IonTimestamp
{
    ///
    ubyte[] data;

    /++
    Returns: true if the timestamp is `null.timestamp` or `null`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

/++
+/
struct IonSymbol
{
    ///
    ubyte[] data;

    /++
    Returns: true if the symbol is `null.symbol` or `null`.
    +/
    @safe pure nothrow @nogc
    bool opEquals(typeof(null)) const
    {
        return data is null;
    }
}

static immutable Exception[] ionExceptions;

/++
+/
struct IonList
{
    ///
    ubyte[] data;
    private alias DG = scope int delegate(IonErrorCode error, IonDescribedValue value) @safe pure nothrow @nogc;
    private alias EDG = scope int delegate(IonDescribedValue value) @safe pure @nogc;

    /++
    Returns: true if the sexp is `null.sexp` or `null`.
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

    /++
    +/
    @safe pure @nogc
    int opApply(scope int delegate(IonDescribedValue value) @safe pure @nogc dg)
    {
        return opApply((IonErrorCode error, IonDescribedValue value) {
            if (_expect(error, false))
                throw ionExceptions[error];
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
+/
struct IonSexp
{
    /// data view.
    ubyte[] data;

    private alias DG = IonList.DG;
    private alias EDG = IonList.EDG;

    /++
    Returns: true if the sexp is `null.sexp` or `null`.
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
+/
struct IonStruct
{
    ///
    ubyte[] data;
    private alias DG = scope int delegate(IonErrorCode error, size_t symbolId, IonDescribedValue value) @safe pure nothrow @nogc;
    private alias EDG = scope int delegate(size_t symbolId, IonDescribedValue value) @safe pure nothrow @nogc;

    /++
    Returns: true if the struct is `null.struct` or `null`.
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

    /++
    +/
    @safe pure @nogc
    int opApply(scope int delegate(size_t symbolId, IonDescribedValue value) @safe pure @nogc dg)
    {
        return opApply((IonErrorCode error, size_t symbolId, IonDescribedValue value) {
            if (_expect(error, false))
                throw ionExceptions[error];
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
+/
struct IonAnnotationWrapper
{
    ///
    ubyte[] data;

    /++
    +/
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

/++
$(HTTP amzn.github.io/ion-docs/docs/binary.html#typed-value-formats, Typed Value Formats)
+/
enum IonType
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
    D_type: `char[]`
    +/
    string,

    /++
    Spec: $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#9-clob, 9: clob)
    D_type: `IonClobChar[]`
    +/
    clob,

    /++
    Spec: $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#0-blob, 10: blob)
    D_type: `ubyte[]`
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

/++
+/
struct IonSymbolTable
{
    size_t _maxId;
    const(char[])[] _symbols;
    IonSymbolTable* _next;

    /++
    Returns:
        empty non-null or non-empty string if the table contains the `id` and null string otherwise.
    +/
    @trusted pure nothrow @nogc
    const(char)[] getSymbol(size_t id) scope const
    {
        --id; // overflow is OK
        scope curr = &this;
        do
        {
            import mir.checkedint;
            bool overflow;
            auto nextId = subu(id, curr._maxId, overflow);
            if (overflow)
            {
                if (curr._symbols.length < id)
                    return curr._symbols[id];
                break;
            }
            curr = curr._next;
            id = nextId;
        }
        while(curr);
        return null;
    }

    /++
    Returns: GC-allocated copy.
    +/
    @safe pure nothrow const
    IonSymbolTable gcCopy()
    {
        IonSymbolTable ret;
        scope currentOut = (()@trusted => &ret)();
        scope currentIn = (()@trusted => &this)();
        for(;;)
        {
            import mir.ndslice.topology: map;
            import mir.array.allocation: array;
            *currentOut = IonSymbolTable(currentIn._maxId, currentIn._symbols.map!idup.array);
            if (currentIn._next is null)
                break;
            currentIn = currentIn._next;
            currentOut = new IonSymbolTable();
        }
        return ret;
    }
}

/++
+/
struct IonDeserValue
{
    /++
    +/
    IonValue value;
    /++
    +/
    const(size_t)[] idMap;
}

/++
+/
struct IonInverseSymbolTable
{
    /++
    +/
    struct Node
    {
        ///
        size_t hash;
        ///
        size_t id;
    }

    /++
    +/
    IonSymbolTable symbolTable;
    /++
    Node array length of power of 2.
    +/
    const(Node)[] nodes;

    /++
    Returns: GC-allocated copy.
    +/
    @safe pure nothrow const
    IonInverseSymbolTable gcCopy()
    {
        return IonInverseSymbolTable(symbolTable.gcCopy, nodes.dup);
    }

    /++
    Returns:
        non-zero id if the table contains the symbol and zero otherwise.
    +/
    @trusted pure nothrow @nogc
    size_t getId(scope const(char)[] symbol) scope const
    {
        if  (nodes.length)
        {
            // TODO use custom hash function
            size_t hash = hashOf(symbol);
            {
                version(assert)
                {
                    import mir.bitop;
                    assert(size_t(1) << cttz(nodes.length) == nodes.length, "nodes.length must be power of 2");
                }
                size_t mask = nodes.length - 1;
                size_t startIndex = hash & mask;
                size_t index = startIndex;
                do
                {
                    if (nodes[index].hash != hash)
                        continue;
                    auto candidateId = nodes[index].id;
                    if (symbol != symbolTable.getSymbol(candidateId))
                        continue;
                    return candidateId;
                }
                while((++index &= mask) != startIndex);
            }
        }
        return 0;
    }
}

/++
Each version of the Ion specification defines the corresponding system symbol table version.
Ion 1.0 uses the `"$ion"` symbol table, version 1,
and future versions of Ion will use larger versions of the `"$ion"` symbol table.
`$ion_1_1` will probably use version 2, while `$ion_2_0` might use version 5.

Applications and users should never have to care about these symbol table versions,
since they are never explicit in user data: this specification disallows (by ignoring) imports named `"$ion"`.

Here are the system symbols for Ion 1.0.
+/
static immutable string[] IonSystemSymbolTable_v1 = [
    "$ion",
    "$ion_1_0",
    "$ion_symbol_table",
    "name",
    "version",
    "imports",
    "symbols",
    "max_id",
    "$ion_shared_symbol_table",
];

// deser(IonValue, IonInverseSymbolTable, IonVersionMarker, )

/++
Ion User Type
+/
struct Ion
{
    /// $(LREF IonInverseSymbolTable)
    IonInverseSymbolTable inverseSymbolTable;

    /// $(LREF IonValue)
    IonValue value;

    // Ion has only one spec version for now.
    // /// $(LREF IonVersionMarker)
    // IonVersionMarker versionMarker;

    /++
    Returns: GC-allocated copy.
    +/
    @safe pure nothrow const
    Ion gcCopy()
    {
        return Ion(
            inverseSymbolTable.gcCopy,
            value.gcCopy,
            // versionMarker
        );
    }
}

// pragma(Ion);

// /++
// +/
// struct IonStream(IonValueStream, IonSharedTableLoader = void)
// {
//     private IonValueStream 
// }
