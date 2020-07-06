module mir.ion.tests.internal.stage2;
import mir.ion.internal.stage2;

unittest
{
    align(64) ubyte[64][4] dataA;

    auto data = dataA.ptr.ptr[0 .. dataA.length * 64];

    foreach (i; 0 .. 256)
        data[i] = cast(ubyte)i;
    
    ulong[2][dataA.length] pairedMasks;

    stage2(pairedMasks.length, dataA.ptr, pairedMasks.ptr);

    import mir.ndslice;
    auto maskData = pairedMasks.sliced;
    auto obits = maskData.map!"a[0]".bitwise;
    auto wbits = maskData.map!"a[1]".bitwise;
    assert(obits.length == 256);
    assert(wbits.length == 256);

    foreach (i; 0 .. 256)
    {
        assert (obits[i] == (i == ',' || i == ':' || i == '[' || i == ']' || i == '{' || i == '}'));
        assert (wbits[i] == (i == ' ' || i == '\t' || i == '\r' || i == '\n'));
    }
}
