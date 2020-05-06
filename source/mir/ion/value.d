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
    package IonVersionMarker _versionMarker;

    /++
    Create Ion Value value using the `data`.
    Params:
        data = Ion Value binary data
        versionMarker = (optional) Binary Version Marker. The default value corresponds to the latest Ion Version supported by mir-ion library.
    +/
    this(const(ubyte)[] data, IonVersionMarker versionMarker = IonVersionMarker.init) scope
    {
        this._data = data;
        this._versionMarker = versionMarker;
    }

    /++
    Returns:
        Binary Version Marker
    +/
    @safe pure nothrow @nogc const @property
    IonVersionMarker versionMarker()
    {
        return _versionMarker;
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
}

/++
+/
struct IonSharedSymbolTable
{
}

/++
+/
struct IonSymbolTable
{
    size_t _maxId;
    const(char)[][] _symbols;
    IonSymbolTable* _next;

    @trusted pure nothrow @nogc
    const(char)[] getSymbol(size_t id) scope const
    {
        --id; // overflow is OK
        scope IonSymbolTable curr = cast()this;
        for (;;)
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
            if (!curr._next)
                break;
            curr = *curr._next;
            id = nextId;
        }
        return null;
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

/++
+/
struct Ion
{
    /++
    +/
    IonSymbolTable symbolTable;

    /++
    +/
    IonValue value;
}

/++
+/
struct IonValueStream
{

}
