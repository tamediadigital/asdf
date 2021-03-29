module mir.ion.internal.stage4_s;

import mir.ion.exception: IonErrorCode;

///
struct IonErrorInfo
{
    ///
    IonErrorCode code;
    ///
    size_t location;
    /// refers tape or text
    const(char)[] key;
}

///
IonErrorInfo singleThreadJsonImpl(size_t nMax, alias fillBuffer, SymbolTable, TapeHolder)(
    ref SymbolTable table,
    ref TapeHolder tapeHolder,
    )
    if (nMax % 64 == 0 && nMax)
{
    version (LDC) pragma(inline, true);

    import mir.utility: _expect;
    import mir.ion.internal.stage3;

    enum k = nMax / 64;

    align(64) ubyte[64][k + 2] vector = void;
    if (__ctfe)
        foreach (ref v; vector)
            v[] = 0;
    ulong[2][k + 2] pairedMask1 = void;
    ulong[2][k + 2] pairedMask2 = void;

    bool backwardEscapeBit;

    vector[$ - 1] = ' ';
    pairedMask1[$ - 1] = [0UL,  0UL];
    pairedMask1[$ - 1] = [0UL,  ulong.max];

    Stage3Stage stage;

    size_t location;

    auto ret = stage3!((ref bool eof) @trusted
        {
            version (LDC) pragma(inline, true);
            tapeHolder.extend(stage.tape.length + nMax * 4);
            if (stage.tape !is null)
            {
                vector[0] = vector[$ - 2];
                pairedMask1[0] = pairedMask1[$ - 2];
                pairedMask2[0] = pairedMask2[$ - 2];
                stage.index -= stage.n;
                location += stage.n;
            }
            else
            {
                stage.strPtr = cast(const(ubyte)*)(vector.ptr.ptr + 64);
                stage.pairedMask1 = pairedMask1.ptr + 1;
                stage.pairedMask2 = pairedMask2.ptr + 1;
            }
            stage.tape = tapeHolder.data;
            if (_expect(!fillBuffer(cast(char*)(vector.ptr.ptr + 64), stage.n, eof), false))
                return false;

            assert (stage.n);
            auto vlen = stage.n / 64 + (stage.n % 64 != 0);
            import mir.ion.internal.stage1;
            import mir.ion.internal.stage2;
            stage1(vlen, vector.ptr + 1, pairedMask1.ptr + 1, backwardEscapeBit);
            stage2(vlen, vector.ptr + 1, pairedMask2.ptr + 1);
            return true;
        })(
        table,
        stage,
        tapeHolder.currentTapePosition,
    );
    location += stage.index;
    return typeof(return)(ret, location, stage.key);
}

///
IonErrorInfo singleThreadJsonText(size_t nMax, SymbolTable, TapeHolder)(
    ref SymbolTable table,
    ref TapeHolder tapeHolder,
    scope const(char)[] text,
)
    if (nMax % 64 == 0 && nMax)
{
    version(LDC) pragma(inline, true);

    return singleThreadJsonImpl!(nMax, (scope char* data, ref sizediff_t n, ref bool eof) @trusted
    {
        version (LDC) pragma(inline, true);

        import core.stdc.string: memcpy;
        import mir.utility: min;

        n = min(text.length, nMax);
        size_t spaceStart = n / 64 * 64;
        data[spaceStart .. spaceStart + 64] = ' ';
        memcpy(data, text.ptr, n);
        text = text[n .. text.length];
        eof = text.length == 0;
        return true;
    })(table, tapeHolder);
}

///
version(mir_ion_test) unittest
{
    static ubyte[] jsonToIonTest(scope const(char)[] text)
    @trusted pure
    {
        import mir.serde: SerdeMirException;
        import mir.ion.exception: ionErrorMsg;
        import mir.ion.internal.data_holder;
        import mir.ion.symbol_table;

        enum nMax = 128u;

        IonSymbolTable!false table;
        table.initialize;
        auto tapeHolder = IonTapeHolder!(nMax * 4)(nMax * 4);

        auto errorInfo = singleThreadJsonText!nMax(table, tapeHolder, text);
        if (errorInfo.code)
            throw new SerdeMirException(errorInfo.code.ionErrorMsg, ". location = ", errorInfo.location, ", last input key = ", errorInfo.key);

        return tapeHolder.tapeData.dup;
    }

    import mir.ion.value;
    import mir.ion.type_code;

    assert(jsonToIonTest("1 2 3") == [0x21, 1, 0x21, 2, 0x21, 3]);
    assert(IonValue(jsonToIonTest("12345")).describe.get!IonUInt.get!ulong == 12345);
    assert(IonValue(jsonToIonTest("-12345")).describe.get!IonNInt.get!long == -12345);
    assert(IonValue(jsonToIonTest("-12.345")).describe.get!IonDecimal.get!double == -12.345);
    assert(IonValue(jsonToIonTest("\t \r\n-12345e-3 \t\r\n")).describe.get!IonFloat.get!double == -12.345);
    assert(IonValue(jsonToIonTest(" -12345e-3 ")).describe.get!IonFloat.get!double == -12.345);
    assert(IonValue(jsonToIonTest("   null")).describe.get!IonNull == IonNull(IonTypeCode.null_));
    assert(IonValue(jsonToIonTest("true ")).describe.get!bool == true);
    assert(IonValue(jsonToIonTest("  false")).describe.get!bool == false);
    assert(IonValue(jsonToIonTest(` "string"`)).describe.get!(const(char)[]) == "string");

    enum str = "iwfpwqocbpwoewouivhqpeobvnqeon wlekdnfw;lefqoeifhq[woifhdq[owifhq[owiehfq[woiehf[  oiehwfoqwewefiqweopurefhqweoifhqweofihqeporifhq3eufh38hfoidf";
    auto data = jsonToIonTest(`"` ~ str ~ `"`);
    assert(IonValue(jsonToIonTest(`"` ~ str ~ `"`)).describe.get!(const(char)[]) == str);

    assert(IonValue(jsonToIonTest(`"hey \uD801\uDC37tee"`)).describe.get!(const(char)[]) == "hey 𐐷tee");
    assert(IonValue(jsonToIonTest(`[]`)).describe.get!IonList.data.length == 0);
    assert(IonValue(jsonToIonTest(`{}`)).describe.get!IonStruct.data.length == 0);

    assert(jsonToIonTest(" [ {}, true , \t\r\nfalse, null, \"string\", 12.3 ]") ==
        cast(ubyte[])"\xbe\x8e\xd0\x11\x10\x0f\x86\x73\x74\x72\x69\x6e\x67\x52\xc1\x7b");

    data = jsonToIonTest(` { "a": "b",  "key": ["array", {"a": "c" } ] } `);
    assert(data == cast(ubyte[])"\xde\x8f\x8a\x81b\x8b\xba\x85array\xd3\x8a\x81c");

    data = jsonToIonTest(
    `{
        "tags":[
            "russian",
            "novel",
            "19th century"
        ]
    }`);

}

///
pragma(inline, true)
IonErrorInfo singleThreadJsonFile(size_t nMax, SymbolTable, TapeHolder)(
    ref SymbolTable table,
    ref TapeHolder tapeHolder,
    scope const(char)[] fileName,
)
    if (nMax % 64 == 0 && nMax)
{
    version(LDC) pragma(inline, true);

    import mir.utility: _expect;
    import core.stdc.stdio: fopen, fread, fclose, ferror, feof;
    import core.stdc.string: memcpy, memset;
    import mir.appender: ScopedBuffer;

    ScopedBuffer!(char, 256) filenameBuffer;
    filenameBuffer.put(fileName);
    filenameBuffer.put('\0');

    auto fp = fopen(filenameBuffer.data.ptr, "r");
    if (_expect(fp is null, false))
        return IonErrorInfo(IonErrorCode.unableToOpenFile);
    scope(exit) fclose(fp);
    return singleThreadJsonImpl!(nMax, (scope char* data, ref sizediff_t n, ref bool eof) @trusted
    {
        version (LDC) pragma(inline, true);
        n = fread(data, char.sizeof, nMax, fp);
        if (_expect(ferror(fp), false))
            return false;
        memset(data + n, ' ', 64 - (n & 63));
        eof = feof(fp) != 0;
        return true;
    })(table, tapeHolder);
}
