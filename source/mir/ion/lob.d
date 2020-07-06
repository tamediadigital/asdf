/++
+/
module mir.ion.lob;

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
