/++
Mir Ion error codes, messages, and exceptions.
+/
module mir.ion.exception;

/++
Ion Error Codes
+/
enum IonErrorCode
{
    ///
    none,
    ///
    nop,
    ///
    illegalTypeDescriptor,
    ///
    unexpectedEndOfData,
    ///
    unexpectedIonType,
    ///
    overflowInParseVarUInt,
    ///
    overflowInParseVarInt,
    ///
    overflowInIntegerValue,
    ///
    zeroAnnotations,
    ///
    illegalBinaryData,
    ///
    illegalTimeStamp,
    ///
    wrongBoolDescriptor,
    ///
    wrongIntDescriptor,
    ///
    wrongFloatDescriptor,
    ///
    nullBool,
    ///
    nullInt,
    ///
    nullFloat,
    ///
    nullTimestamp,
}

///
unittest
{
    static assert(!IonErrorCode.none);
    static assert(IonErrorCode.none == IonErrorCode.init);
    static assert(IonErrorCode.nop > 0);
}

/++
Params:
    code = $(LREF IonErrorCode)
Returns:
    corresponding error message
+/
string ionErrorMsg(IonErrorCode code) @property
@safe pure nothrow @nogc
{
    static immutable string[] msgs = [
        null,
        "unexpected NOP Padding",
        "illegal type descriptor",
        "unexpected end of data",
        "unexpected Ion type",
        "overflow in parseVarUInt",
        "overflow in parseVarInt",
        "overflow in integer value",
        "at least one annotation is required",
        "illegal binary data",
        "illegal timestamp",
        "wrong bool descriptor",
        "wrong int descriptor",
        "wrong float descriptor",
        "null bool",
        "null int",
        "null float",
        "null timestamp",
    ];
    return msgs[code - IonErrorCode.min];
}

///
@safe pure nothrow @nogc
unittest
{
    static assert(IonErrorCode.nop.ionErrorMsg == "unexpected NOP Padding", IonErrorCode.nop.ionErrorMsg);
    static assert(IonErrorCode.none.ionErrorMsg is null);
}

version (D_Exceptions):

/++
Mir Ion Exception Class
+/
class MirIonException : Exception
{
    ///
    @safe pure nothrow @nogc
    this(string msg, string file = __FILE__, int line = __LINE__)
    {
        super(msg, file, line);
    }
}

/++
Params:
    code = $(LREF IonErrorCode)
Returns:
    $(LREF MirIonException)
+/
MirIonException ionException(IonErrorCode code) @property
@trusted pure nothrow @nogc
{
    import mir.array.allocation: array;
    import mir.ndslice.topology: map;
    import std.traits: EnumMembers;

    static immutable MirIonException[] exceptions =
        [EnumMembers!IonErrorCode]
        .map!(code => code ? new MirIonException("MirIonException: " ~ code.ionErrorMsg) : null)
        .array;
    return cast(MirIonException) exceptions[code - IonErrorCode.min];
}

///
@safe pure nothrow @nogc
unittest
{
    static assert(IonErrorCode.nop.ionException.msg == "MirIonException: unexpected NOP Padding", IonErrorCode.nop.ionException.msg);
    static assert(IonErrorCode.none.ionException is null);
}
