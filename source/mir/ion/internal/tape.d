module mir.ion.internal.tape;


struct Tape
{
    ubyte[] data;
    size_t position;
    size_t[] stack; // except the current object/array/value
    size_t[] stackPosition;
    size_t currentLength;

    @disable this(this);

    void start(size_t jsonBlockSize)
    {
        reserve(jsonBlockSize);
        // fill header info data
    }

    void reserve(size_t jsonBlockSize)
    {
        // recompress existing data (memmove)
        // reserve stack and data
    }

    void finish()
    {
    }

    void putTrue()
    {
    }

    void putFalse()
    {
    }

    void putNull()
    {
    }

    void putNumberString(scope const(char)[] str)
    {
    }

    void putString(scope const(char)[] str)
    {
    }

    void putSymbol(size_t id)
    {
    }

    void startStringParts(scope const(char)[] str)
    {
        // put currentLength if any
    }

    void putStringPart(scope const(char)[] str)
    {
    }

    // in pair with {startStringParts, putStringPart,...}
    void finishStringParts(scope const(char)[] str)
    {
        // recompress or extend
    }

    void startObject()
    {
    }

    void finishObject()
    {
        // recompress or extend
    }

    void startArray()
    {
    }

    void finishArray()
    {
        // recompress or extend
    }
}
