module mir.ion.value;

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
    none,
    illegalTypeDescriptor,
    unexpectedEndOfData,
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

/++
+/


/++
+/
struct IonList
{
    const(ubyte)[] data;

    /++
    +/
    IonErrorCode forEach(alias fun)()
    {
        auto d = data;
        while (d.length)
        {
            ubyte descriptorData = d[0];
            d = d[1 .. $];

            if (_expect(descriptorData > 0xEE, false))
                return IonErrorCode.illegalTypeDescriptor;

            auto describedValue = IonDescribedValue(IonDescriptor(descriptorData));

            // if not null
            if (describedValue.descriptor.L != 0xF)
            {
                // if bool
                if (describedValue.descriptor.type == Type.bool_)
                {
                    if (_expect(describedValue.descriptor.L > 1, false))
                        return IonErrorCode.illegalTypeDescriptor;
                }
                else
                {
                    size_t length = describedValue.descriptor.L;
                    // if large
                    if (length == 0xE)
                    {
                        if (auto error = parseVarInt(d, length))
                            return error;
                    }
                    if (_expect(length > d.length, false))
                        return IonErrorCode.unexpectedEndOfData;
                    describedValue.data = d[0 .. length];
                    d = d[length .. $];

                    // NOP Padding
                    if (describedValue.descriptor.type == Type.null_)
                        continue;
                }
            }

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
