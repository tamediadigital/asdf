module mir.ion.tests.tape;
import mir.ion.tape;

@system:
pure:
unittest
{
    ubyte[10] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0) == 1);
        assert(data[0] == 0x80);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 1) == 1);
        assert(data[0] == 0x81);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0x7F) == 1);
        assert(data[0] == 0xFF);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0xFF) == 2);
        assert(data[0] == 0x01);
        assert(data[1] == 0xFF);
    }

    foreach(T; AliasSeq!(ushort, uint, ulong))
    {

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0x3FFF) == 2);
        assert(data[0] == 0x7F);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0x7FFF) == 3);
        assert(data[0] == 0x01);
        assert(data[1] == 0x7F);
        assert(data[2] == 0xFF);

        data[] = 0;
        assert(ionPutVarUInt!T(data.ptr, 0xFFEE) == 3);
        assert(data[0] == 0x03);
        assert(data[1] == 0x7F);
        assert(data[2] == 0xEE);
    }

    data[] = 0;
    assert(ionPutVarUInt(data.ptr, uint.max) == 5);
    assert(data[0] == 0x0F);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0xFF);

    data[] = 0;
    assert(ionPutVarUInt!ulong(data.ptr, ulong.max >> 1) == 9);
    assert(data[0] == 0x7F);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0xFF);

    data[] = 0;
    assert(ionPutVarUInt(data.ptr, ulong.max) == 10);
    assert(data[0] == 0x01);
    assert(data[1] == 0x7F);
    assert(data[2] == 0x7F);
    assert(data[3] == 0x7F);
    assert(data[4] == 0x7F);
    assert(data[5] == 0x7F);
    assert(data[6] == 0x7F);
    assert(data[7] == 0x7F);
    assert(data[8] == 0x7F);
    assert(data[9] == 0xFF);
}

unittest
{
    ubyte[8] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0) == 0);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 1) == 1);
        assert(data[0] == 0x01);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0x3F) == 1);
        assert(data[0] == 0x3F);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0xFF) == 1);
        assert(data[0] == 0xFF);

        data[] = 0;
        assert(ionPutUIntField!T(data.ptr, 0x80) == 1);
        assert(data[0] == 0x80);
    }

    data[] = 0;
    assert(ionPutUIntField!uint(data.ptr, int.max) == 4);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);

    data[] = 0;
    assert(ionPutUIntField!uint(data.ptr, int.max + 1) == 4);
    assert(data[0] == 0x80);
    assert(data[1] == 0x00);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);

    data[] = 0;
    assert(ionPutUIntField!ulong(data.ptr, long.max >> 1) == 8);
    assert(data[0] == 0x3F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutUIntField!ulong(data.ptr, long.max) == 8);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutUIntField!ulong(data.ptr, long.max + 1) == 8);
    assert(data[0] == 0x80);
    assert(data[1] == 0x00);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);

    data[] = 0;
    assert(ionPutUIntField(data.ptr, ulong.max) == 8);
    assert(data[0] == 0xFF);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);
}

unittest
{
    ubyte[9] data;

    alias AliasSeq(T...) = T;

    foreach(T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0, false) == 0);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0, true) == 1);
        assert(data[0] == 0x80);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 1, false) == 1);
        assert(data[0] == 0x01);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 1, true) == 1);
        assert(data[0] == 0x81);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0x3F, true) == 1);
        assert(data[0] == 0xBF);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0xFF, false) == 2);
        assert(data[0] == 0x00);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0xFF, true) == 2);
        assert(data[0] == 0x80);
        assert(data[1] == 0xFF);

        data[] = 0;
        assert(ionPutIntField!T(data.ptr, 0x80, true) == 2);
        assert(data[0] == 0x80);
        assert(data[1] == 0x80);
    }

    data[] = 0;
    assert(ionPutIntField(data.ptr, int.max) == 4);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);

    data[] = 0;
    assert(ionPutIntField(data.ptr, int.min) == 5);
    assert(data[0] == 0x80);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);

    data[] = 0;
    assert(ionPutIntField(data.ptr, long.max >> 1) == 8);
    assert(data[0] == 0x3F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutIntField(data.ptr, long.max) == 8);
    assert(data[0] == 0x7F);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);

    data[] = 0;
    assert(ionPutIntField!ulong(data.ptr, long.max + 1, false) == 9);
    assert(data[0] == 0x00);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);

    data[] = 0;
    assert(ionPutIntField(data.ptr, ulong.max, true) == 9);
    assert(data[0] == 0x80);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);
    assert(data[8] == 0xFF);
}

unittest
{
    ubyte[1] data;
    assert(ionPut(data.ptr, null) == 1);
    assert(data[0] == 0x0F);
}

unittest
{
    ubyte[1] data;
    assert(ionPut(data.ptr, true) == 1);
    assert(data[0] == 0x11);
    assert(ionPut(data.ptr, false) == 1);
    assert(data[0] == 0x10);
}

unittest
{
    ubyte[10] data;
    assert(ionPut(data.ptr, 0u) == 1);
    assert(data[0] == 0x20);
    assert(ionPut(data.ptr, 0u, true) == 1);
    assert(data[0] == 0x30);
    assert(ionPut(data.ptr, 0xFFu) == 2);
    assert(data[0] == 0x21);
    assert(data[1] == 0xFF);
    assert(ionPut(data.ptr, 0xFFu, true) == 2);
    assert(data[0] == 0x31);
    assert(data[1] == 0xFF);

    assert(ionPut(data.ptr, ulong.max, true) == 9);
    assert(data[0] == 0x38);
    assert(data[1] == 0xFF);
    assert(data[2] == 0xFF);
    assert(data[3] == 0xFF);
    assert(data[4] == 0xFF);
    assert(data[5] == 0xFF);
    assert(data[6] == 0xFF);
    assert(data[7] == 0xFF);
    assert(data[8] == 0xFF);
}

unittest
{
    ubyte[10] data;
    assert(ionPut(data.ptr, -16) == 2);
    assert(data[0] == 0x31);
    assert(data[1] == 0x10);

    assert(ionPut(data.ptr, 258) == 3);
    assert(data[0] == 0x22);
    assert(data[1] == 0x01);
    assert(data[2] == 0x02);
}

unittest
{
    ubyte[5] data;
    assert(ionPut(data.ptr, -16f) == 5);
    assert(data[0] == 0x44);
    assert(data[1] == 0xC1);
    assert(data[2] == 0x80);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);

    assert(ionPut(data.ptr, 0f) == 1);
    assert(data[0] == 0x40);

    assert(ionPut(data.ptr, -0f) == 5);
    assert(data[0] == 0x44);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
}

unittest
{
    ubyte[9] data;
    assert(ionPut(data.ptr, -16.0) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0xC0);
    assert(data[2] == 0x30);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);

    assert(ionPut(data.ptr, 0.0) == 1);
    assert(data[0] == 0x40);

    assert(ionPut(data.ptr, -0.0) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);
}

unittest
{
    ubyte[9] data;
    assert(ionPut(data.ptr, -16.0L) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0xC0);
    assert(data[2] == 0x30);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);

    assert(ionPut(data.ptr, 0.0L) == 1);
    assert(data[0] == 0x40);

    assert(ionPut(data.ptr, -0.0L) == 9);
    assert(data[0] == 0x48);
    assert(data[1] == 0x80);
    assert(data[2] == 0x00);
    assert(data[3] == 0x00);
    assert(data[4] == 0x00);
    assert(data[5] == 0x00);
    assert(data[6] == 0x00);
    assert(data[7] == 0x00);
    assert(data[8] == 0x00);
}

unittest
{
    import mir.bignum.low_level_view : BigUIntView, WordEndian;
    ubyte[32] data;
    // big unsigned integer
    assert(ionPut(data.ptr, BigUIntView!size_t.fromHexString("88BF4748507FB9900ADB624CCFF8D78897DC900FB0460327D4D86D327219").lightConst) == 32);
    assert(data[0] == 0x2E);
    assert(data[1] == 0x9E);
    assert(data[2 .. 32] == BigUIntView!(ubyte, WordEndian.big).fromHexString("88BF4748507FB9900ADB624CCFF8D78897DC900FB0460327D4D86D327219").coefficients);
}

unittest
{
    import mir.bignum.low_level_view : BigUIntView;
    ubyte[3] data;
    // big unsigned integer
    assert(ionPut(data.ptr, -BigUIntView!size_t.fromHexString("45be").lightConst) == 3);
    assert(data[0] == 0x32);
    assert(data[1] == 0x45);
    assert(data[2] == 0xbe);
}

unittest
{
    import mir.bignum.low_level_view : BigUIntView, DecimalView, WordEndian;
    ubyte[34] data;
    // 0.6
    assert(ionPut(data.ptr, DecimalView!size_t(false, -1, BigUIntView!size_t.fromHexString("06")).lightConst) == 3);
    assert(data[0] == 0x52);
    assert(data[1] == 0xC1);
    assert(data[2] == 0x06);

    // -0.6
    assert(ionPut(data.ptr, DecimalView!size_t(true, -1, BigUIntView!size_t.fromHexString("06")).lightConst) == 3);
    assert(data[0] == 0x52);
    assert(data[1] == 0xC1);
    assert(data[2] == 0x86);


    // 0e-3
    assert(ionPut(data.ptr, DecimalView!size_t(false, 3, BigUIntView!size_t.fromHexString("00")).lightConst) == 2);
    assert(data[0] == 0x51);
    assert(data[1] == 0x83);

    // -0e+0
    assert(ionPut(data.ptr, DecimalView!size_t(true, 0, BigUIntView!size_t.fromHexString("00")).lightConst) == 3);
    assert(data[0] == 0x52);
    assert(data[1] == 0x80);
    assert(data[2] == 0x80);

    // 0e+0
    assert(ionPut(data.ptr, DecimalView!size_t(false, 0, BigUIntView!size_t.fromHexString("00")).lightConst) == 2);
    assert(data[0] == 0x51);
    assert(data[1] == 0x80);

    // 0e+0 (minimal)
    assert(ionPut(data.ptr, DecimalView!size_t(false, 0, BigUIntView!size_t.init).lightConst) == 1);
    assert(data[0] == 0x50);

    // big decimal
    assert(ionPut(data.ptr, DecimalView!size_t(false, -9, BigUIntView!size_t.fromHexString("88BF4748507FB9900ADB624CCFF8D78897DC900FB0460327D4D86D327219")).lightConst) == 34);
    assert(data[0] == 0x5E);
    assert(data[1] == 0xA0);
    assert(data[2] == 0xC9);
    assert(data[3] == 0x00);
    assert(data[4 .. 34] == BigUIntView!(ubyte, WordEndian.big).fromHexString("88BF4748507FB9900ADB624CCFF8D78897DC900FB0460327D4D86D327219").coefficients);
}

unittest
{
    import mir.ion.timestamp : IonTimestamp;
    ubyte[13] data;

    ubyte[] result = [0x68, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84];
    auto ts = IonTimestamp(2000, 7, 8, 2, 3, 4);
    assert(data[0 .. ionPut(data.ptr, ts)] == result);

    result = [0x69, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0xC2];
    ts = IonTimestamp(2000, 7, 8, 2, 3, 4, -2, 0);
    assert(data[0 .. ionPut(data.ptr, ts)] == result);

    result = [0x6A, 0x80, 0x0F, 0xD0, 0x87, 0x88, 0x82, 0x83, 0x84, 0xC3, 0x10];
    ts = IonTimestamp(2000, 7, 8, 2, 3, 4, -3, 16);
    assert(data[0 .. ionPut(data.ptr, ts)] == result);
}

unittest
{
    import mir.date : Date;
    ubyte[13] data;

    ubyte[] result = [0x65, 0x80, 0x0F, 0xD0, 0x87, 0x88];
    auto ts = Date(2000, 7, 8);
    assert(data[0 .. ionPut(data.ptr, ts)] == result);
}

unittest
{
    ubyte[8] data;

    ubyte[] result = [0x72, 0x01, 0xFF];
    auto id = 0xFFu;
    assert(data[0 .. ionPutSymbolId(data.ptr, id)] == result);
}

unittest
{
    ubyte[18] data;

    ubyte[] result = [0x85, 'v', 'a', 'l', 'u', 'e'];
    auto str = "value";
    assert(data[0 .. ionPut(data.ptr, str)] == result);

    result = [ubyte(0x8E), ubyte(0x90)] ~ cast(ubyte[])"hexadecimal23456";
    str = "hexadecimal23456";
    assert(data[0 .. ionPut(data.ptr, str)] == result);
}

unittest
{
    import mir.ion.lob;

    ubyte[18] data;

    ubyte[] result = [0x95, 'v', 'a', 'l', 'u', 'e'];
    auto str = IonClob("value");
    assert(data[0 .. ionPut(data.ptr, str)] == result);

    result = [ubyte(0x9E), ubyte(0x90)] ~ cast(ubyte[])"hexadecimal23456";
    str = IonClob("hexadecimal23456");
    assert(data[0 .. ionPut(data.ptr, str)] == result);
}

unittest
{
    import mir.ion.lob;

    ubyte[18] data;

    ubyte[] result = [0xA5, 'v', 'a', 'l', 'u', 'e'];
    auto payload = IonBlob(cast(ubyte[])"value");
    assert(data[0 .. ionPut(data.ptr, payload)] == result);

    result = [ubyte(0xAE), ubyte(0x90)] ~ cast(ubyte[])"hexadecimal23456";
    payload = IonBlob(cast(ubyte[])"hexadecimal23456");
    assert(data[0 .. ionPut(data.ptr, payload)] == result);
}

unittest
{
    import mir.ion.type_code : IonTypeCode;
    ubyte[1024] data;
    auto pos = ionPutStartLength();

    ubyte[] result = [0xB0];
    assert(data[0 .. ionPutEnd(data.ptr, IonTypeCode.list, 0)] == result);

    result = [ubyte(0xB6), ubyte(0x85)] ~ cast(ubyte[])"hello";
    auto len = ionPut(data.ptr + pos, "hello");
    assert(data[0 .. ionPutEnd(data.ptr, IonTypeCode.list, len)] == result);

    result = [0xCE, 0x90, 0x8E, 0x8E];
    result ~= cast(ubyte[])"hello world!!!";
    len = ionPut(data.ptr + pos, "hello world!!!");
    assert(data[0 .. ionPutEnd(data.ptr, IonTypeCode.sexp, len)] == result);

    auto bm = `
Generating test runner configuration 'mir-ion-test-library' for 'library' (library).
Performing "unittest" build using /Users/9il/dlang/ldc2/bin/ldc2 for x86_64.
mir-core 1.1.7: target for configuration "library" is up to date.
mir-algorithm 3.9.2: target for configuration "default" is up to date.
mir-cpuid 1.2.6: target for configuration "library" is up to date.
mir-ion 0.5.7+commit.70.g7dcac11: building configuration "mir-ion-test-library"...
Linking...
To force a rebuild of up-to-date targets, run again with --force.
Running ./mir-ion-test-library`;

    result = [0xBE, 0x04, 0xB0, 0x8E, 0x04, 0xAD];
    result ~= cast(ubyte[])bm;
    len = ionPut(data.ptr + pos, bm);
    assert(data[0 .. ionPutEnd(data.ptr, IonTypeCode.list, len)] == result);
}

unittest
{
    import mir.ion.type_code : IonTypeCode;
    ubyte[1024] data;
    auto pos = ionPutStartLength(data.ptr, IonTypeCode.list);

    ubyte[] result = [0xB0];
    assert(data[0 .. ionPutEnd(data.ptr, 0)] == result);

    result = [ubyte(0xB6), ubyte(0x85)] ~ cast(ubyte[])"hello";
    pos = ionPutStartLength(data.ptr, IonTypeCode.list);
    auto len = ionPut(data.ptr + pos, "hello");
    assert(data[0 .. ionPutEnd(data.ptr, len)] == result);

    result = [0xCE, 0x90, 0x8E, 0x8E];
    result ~= cast(ubyte[])"hello world!!!";
    pos = ionPutStartLength(data.ptr, IonTypeCode.sexp);
    len = ionPut(data.ptr + pos, "hello world!!!");
    assert(data[0 .. ionPutEnd(data.ptr, IonTypeCode.sexp, len)] == result);

    auto bm = `
Generating test runner configuration 'mir-ion-test-library' for 'library' (library).
Performing "unittest" build using /Users/9il/dlang/ldc2/bin/ldc2 for x86_64.
mir-core 1.1.7: target for configuration "library" is up to date.
mir-algorithm 3.9.2: target for configuration "default" is up to date.
mir-cpuid 1.2.6: target for configuration "library" is up to date.
mir-ion 0.5.7+commit.70.g7dcac11: building configuration "mir-ion-test-library"...
Linking...
To force a rebuild of up-to-date targets, run again with --force.
Running ./mir-ion-test-library`;

    result = [0xBE, 0x04, 0xB0, 0x8E, 0x04, 0xAD];
    result ~= cast(ubyte[])bm;
    pos = ionPutStartLength(data.ptr, IonTypeCode.list);
    len = ionPut(data.ptr + pos, bm);
    assert(data[0 .. ionPutEnd(data.ptr, len)] == result);
}
