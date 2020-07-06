module mir.ion.tests.internal.simd;
import mir.ion.internal.simd;

version(LDC) unittest {
    __vector(ubyte[8]) vec;
    __vector(ubyte[8]) vec23 = 23;
    vec.array[4] = 23;
    auto b = equalMaskB!(__vector(ubyte[8]))(vec, vec23);
    assert(b == 16);
}

