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
    package const(ubyte)[] _data;

    /++
    Creates Ion Value value with the binary `data`.
    Params:
        data = Ion Value binary data
    +/
    @safe pure nothrow @nogc
    this(const(ubyte)[] data) scope
    {
        this._data = data;
    }

    /++
    Returns:
        Binary Data
    +/
    @safe pure nothrow @nogc scope const @property
    const(ubyte)[] data()
    {
        return _data;
    }

    /++
    Returns: GC-allocated copy.
    +/
    @safe pure nothrow const
    IonValue gcCopy()
    {
        return IonValue(_data.dup);
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
}

struct IonParsed
{
    IonType type;
    uint L;
    package const(ubyte)[] data;
}

/++
+/
struct IonDescriptor
{
    ///
    IonType type;
    ///
    uint L;

    ///
    @safe pure nothrow @nogc
    this(ubyte data)
    {
        type = cast(IonType) (data >> 4);
        L = data & 0xF;
    }
}

/++
+/
struct IonDescribedValue
{
    ///
    IonDescriptor descriptor;
    ///
    const(ubyte)[] data;
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
IonErrorCode parseVarUInt(scope const(ubyte)[] data, out size_t shift, out size_t result)
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
IonErrorCode parseVarInt(scope const(ubyte)[] data, out size_t shift, out sizediff_t result)
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
ParseResult parseValue(const(ubyte)[] data, out IonDescribedValue describedValue)
{
    version(LDC) pragma(inline, false);
    // import mir.bitop: ctlz;

    size_t shift = 0;

    if (_expect(data.length == 0, false))
        return typeof(return)(IonErrorCode.unexpectedEndOfData, shift);

    shift = 1;
    ubyte descriptorData = data[0];

    if (_expect(descriptorData > 0xEE, false))
        return typeof(return)(IonErrorCode.illegalTypeDescriptor, shift);

    describedValue = IonDescribedValue(IonDescriptor(descriptorData));
    // if null
    if (describedValue.descriptor.L == 0xF)
        return typeof(return)(IonErrorCode.none, shift);
    // if bool
    if (describedValue.descriptor.type == IonType.bool_)
    {
        if (_expect(describedValue.descriptor.L > 1, false))
            return typeof(return)(IonErrorCode.illegalTypeDescriptor, shift);
        return typeof(return)(IonErrorCode.none, shift);
    }
    size_t length = describedValue.descriptor.L;
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
    return typeof(return)(describedValue.descriptor.type == IonType.null_ ? IonErrorCode.nop : IonErrorCode.none, shift);
}

/++
+/
struct IonList
{
    const(ubyte)[] data;

    /++
    +/
    IonErrorCode forEach(alias fun)()
    {
        size_t shift;
        while (shift < d.length)
        {
            IonDescribedValue describedValue;
            auto result = parseValue(data[shift .. $], describedValue);
            shift += result.length;
            if (result.error < 0) // NOP
                continue;
            if (_expect(result.error, false))
                return error;
            if (auto error = fun(describedValue))
                return error;
        }
        return IonErrorCode.none;
    }
}

/++
$(HTTP amzn.github.io/ion-docs/docs/binary.html#typed-value-formats, Typed Value Formats)
+/
enum IonType
{
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#0-null, 0: null)
    null_,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#1-bool, 1: bool)
    bool_,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#2-and-3-int, 2 and 3: int)
    posInt,
    /// ditto
    negInt,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#4-float, 4: float)
    float_,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#5-decimal, 5: decimal)
    decimal,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#6-timestamp, 6: timestamp)
    timestamp,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#7-symbol, 7: symbol)
    symbol,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#8-string, 8: string)
    string,
    /// $(HTTP http://amzn.github.io/ion-docs/docs/binary.html#9-clob, 9: clob)
    clob,
    /// $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#0-blob, 10: blob)
    blob,
    /// $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#1-list, 11: list)
    list,
    /// $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#2-sexp, 12: sexp)
    sexp,
    /// $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#3-struct, 13: struct)
    struct_,
    /// $(HTTP 1http://amzn.github.io/ion-docs/docs/binary.html#4-annotations, 14: Annotations)
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
