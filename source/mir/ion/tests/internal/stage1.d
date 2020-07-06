module mir.ion.tests.internal.stage1;
import mir.ion.internal.stage1;

unittest
{
    bool backwardEscapeBit = 0;
    align(64) ubyte[64][4] dataA;

    auto data = dataA.ptr.ptr[0 .. dataA.length * 64];

    foreach (i; 0 .. 256)
        data[i] = cast(ubyte)i;
    
    ulong[2][dataA.length] pairedMasks;

    stage1(pairedMasks.length, dataA.ptr, pairedMasks.ptr, backwardEscapeBit);

    import mir.ndslice;
    auto maskData = pairedMasks.sliced;
    auto qbits = maskData.map!"a[0]".bitwise;
    auto ebits = maskData.map!"a[1]".bitwise;
    assert(qbits.length == 256);
    assert(ebits.length == 256);

    foreach (i; 0 .. 128)
    {
        assert (qbits[i] == (i == '\"'));
        assert (i == 0 || ebits[i] == (i-1 == '\\'));
    }

    foreach (i; 128 .. 256)
    {
        assert (!qbits[i]);
        assert (!ebits[i]);
    }
}

unittest
{
    bool backwardEscapeBit = 0;
    align(64) ubyte[64][4] dataA;

    auto data = dataA.ptr.ptr[0 .. dataA.length * 64];

    data[160] = '\\';
    data[161] = '\\';
    data[162] = '\\';

    data[165] = '\\';
    data[166] = '\"';

    data[63] = '\\';
    data[64] = '\\';
    data[65] = '\\';
    data[66] = '\"';

    data[70] = '\"';
    data[71] = '\\';
    data[72] = '\\';
    data[73] = '\\';
    data[74] = '\\';
    data[75] = '\"';

    ulong[2][dataA.length] pairedMasks;

    stage1(pairedMasks.length, dataA.ptr, pairedMasks.ptr, backwardEscapeBit);

    import mir.ndslice;
    auto maskData = pairedMasks.sliced;
    auto qbits = maskData.map!"a[0]".bitwise;
    auto ebits = maskData.map!"a[1]".bitwise;

    foreach (i; 0 .. 68)
    {
        assert (qbits[i] == (i == 70 || i == 75));
    }

    //4992
}
