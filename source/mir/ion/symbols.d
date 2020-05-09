
module mir.ion.symbols;

import mir.ion.exception;
import mir.ion.value;

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
