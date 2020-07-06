module mir.ion.tests.value;
import mir.ion.value;

@safe pure
unittest
{
    assert(IonValue([0x1F]).describe.get!IonBool == null);
    assert(IonValue([0x10]).describe.get!IonBool.get == false);
    assert(IonValue([0x11]).describe.get!IonBool.get == true);
}

///
@safe pure
unittest
{
    import mir.ion.exception : IonErrorCode;
    assert(IonValue([0x2F]).describe.get!IonUInt == null);
    assert(IonValue([0x21, 0x07]).describe.get!IonUInt.get!int == 7);

    int v;
    assert(IonValue([0x22, 0x01, 0x04]).describe.get!IonUInt.get(v) == IonErrorCode.none);
    assert(v == 260);
}

@safe pure
unittest
{
    import mir.ion.exception : IonErrorCode;
    alias AliasSeq(T...) = T;
    foreach (T; AliasSeq!(byte, short, int, long, ubyte, ushort, uint, ulong))
    {
        assert(IonValue([0x20]).describe.get!IonUInt.getErrorCode!T == 0);
        assert(IonValue([0x21, 0x00]).describe.get!IonUInt.getErrorCode!T == 0);

        assert(IonValue([0x21, 0x07]).describe.get!IonUInt.get!T == 7);
        assert(IonValue([0x2E, 0x81, 0x07]).describe.get!IonUInt.get!T == 7);
        assert(IonValue([0x2A, 0,0,0, 0,0,0, 0,0,0, 0x07]).describe.get!IonUInt.get!T == 7);
    }

    assert(IonValue([0x21, 0x7F]).describe.get!IonUInt.get!byte == byte.max);
    assert(IonValue([0x22, 0x7F, 0xFF]).describe.get!IonUInt.get!short == short.max);
    assert(IonValue([0x24, 0x7F, 0xFF,0xFF,0xFF]).describe.get!IonUInt.get!int == int.max);
    assert(IonValue([0x28, 0x7F, 0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF]).describe.get!IonUInt.get!long == long.max);
    assert(IonValue([0x2A, 0,0, 0x7F, 0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF]).describe.get!IonUInt.get!long == long.max);

    assert(IonValue([0x21, 0xFF]).describe.get!IonUInt.get!ubyte == ubyte.max);
    assert(IonValue([0x22, 0xFF, 0xFF]).describe.get!IonUInt.get!ushort == ushort.max);
    assert(IonValue([0x24, 0xFF, 0xFF,0xFF,0xFF]).describe.get!IonUInt.get!uint == uint.max);
    assert(IonValue([0x28, 0xFF, 0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF]).describe.get!IonUInt.get!ulong == ulong.max);
    assert(IonValue([0x2A, 0,0, 0xFF, 0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF]).describe.get!IonUInt.get!ulong == ulong.max);

    assert(IonValue([0x21, 0x80]).describe.get!IonUInt.getErrorCode!byte == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x22, 0x80, 0]).describe.get!IonUInt.getErrorCode!short == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x24, 0x80, 0,0,0]).describe.get!IonUInt.getErrorCode!int == IonErrorCode.overflowInIntegerValue);

    assert(IonValue([0x22, 1, 0]).describe.get!IonUInt.getErrorCode!ubyte == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x23, 1, 0,0]).describe.get!IonUInt.getErrorCode!ushort == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x25, 1, 0,0,0,0]).describe.get!IonUInt.getErrorCode!uint == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x29, 1, 0,0,0,0,0,0,0,0]).describe.get!IonUInt.getErrorCode!ulong == IonErrorCode.overflowInIntegerValue);
}

@safe pure
unittest
{
    import mir.ion.exception : IonErrorCode;
    assert(IonValue([0x3F]).describe.get!IonNInt == null);
    assert(IonValue([0x31, 0x07]).describe.get!IonNInt.get!int == -7);

    long v;
    assert(IonValue([0x32, 0x01, 0x04]).describe.get!IonNInt.get(v) == IonErrorCode.none);
    assert(v == -260);

    // IonNInt can't store zero according to the Ion Binary format specification.
    assert(IonValue([0x30]).describe.get!IonNInt.getErrorCode!byte == IonErrorCode.overflowInIntegerValue);
}

@safe pure
unittest
{
    import mir.ion.exception : IonErrorCode;
    alias AliasSeq(T...) = T;
    foreach (T; AliasSeq!(byte, short, int, long, ubyte, ushort, uint, ulong))
    {
        assert(IonValue([0x30]).describe.get!IonNInt.getErrorCode!T == IonErrorCode.overflowInIntegerValue);
        assert(IonValue([0x31, 0x00]).describe.get!IonNInt.getErrorCode!T == IonErrorCode.overflowInIntegerValue);

        static if (!__traits(isUnsigned, T))
        {   // signed
            assert(IonValue([0x31, 0x07]).describe.get!IonNInt.get!T == -7);
            assert(IonValue([0x3E, 0x81, 0x07]).describe.get!IonNInt.get!T == -7);
            assert(IonValue([0x3A, 0,0,0, 0,0,0, 0,0,0, 0x07]).describe.get!IonNInt.get!T == -7);
        }
        else
        {   // unsigned integers can't represent negative numbers
            assert(IonValue([0x31, 0x07]).describe.get!IonNInt.getErrorCode!T == IonErrorCode.overflowInIntegerValue);
            assert(IonValue([0x3E, 0x81, 0x07]).describe.get!IonNInt.getErrorCode!T == IonErrorCode.overflowInIntegerValue);
            assert(IonValue([0x3A, 0,0,0, 0,0,0, 0,0,0, 0x07]).describe.get!IonNInt.getErrorCode!T == IonErrorCode.overflowInIntegerValue);
        }
    }

    assert(IonValue([0x31, 0x80]).describe.get!IonNInt.get!byte == byte.min);
    assert(IonValue([0x32, 0x80, 0]).describe.get!IonNInt.get!short == short.min);
    assert(IonValue([0x34, 0x80, 0,0,0]).describe.get!IonNInt.get!int == int.min);
    assert(IonValue([0x38, 0x80, 0,0,0, 0,0,0,0]).describe.get!IonNInt.get!long == long.min);

    assert(IonValue([0x31, 0x81]).describe.get!IonNInt.getErrorCode!byte == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x32, 0x80, 1]).describe.get!IonNInt.getErrorCode!short == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x34, 0x80, 0,0,1]).describe.get!IonNInt.getErrorCode!int == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x38, 0x80, 0,0,0, 0,0,0,1]).describe.get!IonNInt.getErrorCode!long == IonErrorCode.overflowInIntegerValue);
}

///
@safe pure
unittest
{
    // null
    assert(IonValue([0x4F]).describe.get!IonFloat == null);

    // zero
    auto ionFloat = IonValue([0x40]).describe.get!IonFloat;
    assert(ionFloat.get!float == 0);
    assert(ionFloat.get!double == 0);
    assert(ionFloat.get!real == 0);

    // single
    ionFloat = IonValue([0x44, 0x42, 0xAA, 0x40, 0x00]).describe.get!IonFloat;
    assert(ionFloat.get!float == 85.125);
    assert(ionFloat.get!double == 85.125);
    assert(ionFloat.get!real == 85.125);

    // double
    ionFloat = IonValue([0x48, 0x40, 0x55, 0x48, 0x00, 0x00, 0x00, 0x00, 0x00]).describe.get!IonFloat;
    assert(ionFloat.get!float == 85.125);
    assert(ionFloat.get!double == 85.125);
    assert(ionFloat.get!real == 85.125);
}

///
@safe pure
unittest
{
    // null.decimal
    assert(IonValue([0x5F]).describe.get!IonDecimal == null);

    auto describedDecimal = IonValue([0x56, 0x50, 0xcb, 0x80, 0xbc, 0x2d, 0x86]).describe.get!IonDecimal.get;
    assert(describedDecimal.exponent == -2123);
    assert(describedDecimal.coefficient.get!int == -12332422);

    describedDecimal = IonValue([0x56, 0x00, 0xcb, 0x80, 0xbc, 0x2d, 0x86]).describe.get!IonDecimal.get;
    assert(describedDecimal.get!double == -12332422e75);

    assert(IonValue([0x50]).describe.get!IonDecimal.get!double == 0);
    assert(IonValue([0x51, 0x83]).describe.get!IonDecimal.get!double == 0);
}

///
@safe pure
unittest
{
    import mir.ion.timestamp;

    // null.timestamp
    assert(IonValue([0x6F]).describe.get!IonTimestampValue == null);

    ubyte[][] set = [
        [0x68, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84,         ], // 2000-07-08T02:03:04Z with no fractional seconds
        [0x69, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0x80,   ], // The same instant with 0d0 fractional seconds and implicit zero coefficient
        [0x6A, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0x80, 00], // The same instant with 0d0 fractional seconds and explicit zero coefficient
        [0x69, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0xC0,   ], // The same instant with 0d-0 fractional seconds
        [0x69, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0x81,   ], // The same instant with 0d1 fractional seconds
    ];

    auto r = IonTimestamp(2000, 7, 8, 2, 3, 4);

    foreach(data; set)
    {
        assert(IonValue(data).describe.get!IonTimestampValue.get == r);
    }

    assert(IonValue([0x69, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0xC2])
        .describe
        .get!IonTimestampValue
        .get ==
            IonTimestamp(2000, 7, 8, 2, 3, 4, -2, 0));

    assert(IonValue([0x6A, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0xC3, 0x10])
        .describe
        .get!IonTimestampValue
        .get ==
            IonTimestamp(2000, 7, 8, 2, 3, 4, -3, 16));
}

///
@safe pure
unittest
{
    import mir.ion.exception : IonErrorCode;
    assert(IonValue([0x7F]).describe.get!IonSymbolID == null);
    assert(IonValue([0x71, 0x07]).describe.get!IonSymbolID.get == 7);

    size_t v;
    assert(IonValue([0x72, 0x01, 0x04]).describe.get!IonSymbolID.get(v) == IonErrorCode.none);
    assert(v == 260);
}

@safe pure
unittest
{
    import mir.ion.exception : IonErrorCode;
    assert(IonValue([0x70]).describe.get!IonSymbolID.getErrorCode == 0);
    assert(IonValue([0x71, 0x00]).describe.get!IonSymbolID.getErrorCode == 0);

    assert(IonValue([0x71, 0x07]).describe.get!IonSymbolID.get == 7);
    assert(IonValue([0x7E, 0x81, 0x07]).describe.get!IonSymbolID.get == 7);
    assert(IonValue([0x7A, 0,0,0, 0,0,0, 0,0,0, 0x07]).describe.get!IonSymbolID.get == 7);

    assert(IonValue([0x71, 0xFF]).describe.get!IonSymbolID.get!ubyte == ubyte.max);
    assert(IonValue([0x72, 0xFF, 0xFF]).describe.get!IonSymbolID.get!ushort == ushort.max);
    assert(IonValue([0x74, 0xFF, 0xFF,0xFF,0xFF]).describe.get!IonSymbolID.get!uint == uint.max);
    assert(IonValue([0x78, 0xFF, 0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF]).describe.get!IonSymbolID.get!ulong == ulong.max);
    assert(IonValue([0x7A, 0,0, 0xFF, 0xFF,0xFF,0xFF, 0xFF,0xFF,0xFF,0xFF]).describe.get!IonSymbolID.get!ulong == ulong.max);

    assert(IonValue([0x72, 1, 0]).describe.get!IonSymbolID.getErrorCode!ubyte == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x73, 1, 0,0]).describe.get!IonSymbolID.getErrorCode!ushort == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x75, 1, 0,0,0,0]).describe.get!IonSymbolID.getErrorCode!uint == IonErrorCode.overflowInIntegerValue);
    assert(IonValue([0x79, 1, 0,0,0,0,0,0,0,0]).describe.get!IonSymbolID.getErrorCode!ulong == IonErrorCode.overflowInIntegerValue);
}

///
@safe pure
unittest
{
    // null.string
    assert(IonValue([0x8F]).describe.get!IonString == null);
    // empty string
    assert(IonValue([0x80]).describe.get!IonString != null);
    assert(IonValue([0x80]).describe.get!IonString.data == "");

    assert(IonValue([0x85, 0x63, 0x6f, 0x76, 0x69, 0x64]).describe.get!IonString.data == "covid");
}

///
unittest
{
    // check parsing with NOP padding:
    // (NOP int NOP double NOP)
    auto list = IonValue([0xce, 0x91, 0x00, 0x00, 0x21, 0x0c, 0x00, 0x00, 0x48, 0x43, 0x0c, 0x6b, 0xf5, 0x26, 0x34, 0x00, 0x00, 0x00, 0x00])
        .describe.get!IonSexp;
    size_t i;
    foreach (elem; list)
    {
        if (i == 0)
            assert(elem.get!IonUInt.get!int == 12);
        if (i == 1)
            assert(elem.get!IonFloat.get!double == 100e13);
        i++;
    }
    assert(i == 2);
}


unittest
{
    // check parsing with NOP padding:
    // [NOP, int, NOP, double, NOP]
    auto list = IonValue([0xbe, 0x91, 0x00, 0x00, 0x21, 0x0c, 0x00, 0x00, 0x48, 0x43, 0x0c, 0x6b, 0xf5, 0x26, 0x34, 0x00, 0x00, 0x00, 0x00])
        .describe.get!IonList;
    size_t i;
    foreach (elem; list)
    {
        if (i == 0)
            assert(elem.get!IonUInt.get!int == 12);
        if (i == 1)
            assert(elem.get!IonFloat.get!double == 100e13);
        i++;
    }
    assert(i == 2);
}

///
@safe pure
unittest
{
    // null.struct
    assert(IonValue([0xDF]).describe.get!IonStruct == null);

    // empty struct
    auto ionStruct = IonValue([0xD0]).describe.get!IonStruct;
    size_t i;
    assert(ionStruct != null);
    foreach (symbolID, elem; ionStruct)
        i++;
    assert(i == 0);

    // added two 2-bytes NOP padings 0x8F 0x00
    ionStruct = IonValue([0xDE, 0x91, 0x8F, 0x00, 0x8A, 0x21, 0x0C, 0x8B, 0x48, 0x43, 0x0C, 0x6B, 0xF5, 0x26, 0x34, 0x00, 0x00, 0x8F, 0x00])
        .describe
        .get!IonStruct;

    foreach (symbolID, elem; ionStruct)
    {
        if (i == 0)
        {
            assert(symbolID == 10);
            assert(elem.get!IonUInt.get!int == 12);
        }
        if (i == 1)
        {
            assert(symbolID == 11);
            assert(elem.get!IonFloat.get!double == 100e13);
        }
        i++;
    }
    assert(i == 2);
}

///
@safe pure
unittest
{
    // null.struct
    IonAnnotations annotations;
    assert(IonValue([0xE7, 0x82, 0x8A, 0x8B, 0x53, 0xC3, 0x04, 0x65])
        .describe
        .get!IonAnnotationWrapper
        .unwrap(annotations)
        .get!IonDecimal
        .get!double == 1.125);

    size_t i;
    foreach (symbolID; annotations)
    {
        if (i == 0)
        {
            assert(symbolID == 10);
        }
        if (i == 1)
        {
            assert(symbolID == 11);
        }
        i++;
    }
    assert(i == 2);
}


