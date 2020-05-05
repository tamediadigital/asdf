module mir.ion.internal.stage1;

import ldc.attributes;
import mir.bitop;
import mir.ion.internal.simd;

version (ARM)
    version = ARM_Any;

version (AArch64)
    version = ARM_Any;

version (X86)
    version = X86_Any;

version (X86_64)
    version = X86_Any;

// @trusted pure nothrow @nogc
size_t stage1 (
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask,
    ref bool backwardEscapeBit,
    )
{
    alias AliasSeq(T...) = T;
    alias params = AliasSeq!(n, vector, pairedMask, backwardEscapeBit);
    version(LDC)
    {
        version (X86_Any)
        {
            static if (!__traits(targetHasFeature, "avx512bw"))
            {
                import cpuid.x86_any;
                if (avx512bw)
                    return stage1_impl_impl!"skylake-avx512"(params);
                static if (!__traits(targetHasFeature, "avx2"))
                {
                    if (avx2)
                        return stage1_impl_impl!"broadwell"(params);
                    static if (!__traits(targetHasFeature, "avx"))
                    {
                        if (avx)
                            return stage1_impl_impl!"sandybridge"(params);
                        static if (!__traits(targetHasFeature, "sse4.2"))
                        {
                            if (sse42) // && popcnt
                                return stage1_impl_impl!"westmere"(params);
                            return stage1_impl_impl!""(params);
                        }
                    }
                }
            }
            else
            {
                return stage1_impl_impl!""(params);
            }
        }
        else
        {
            return stage1_impl_impl!""(params);
        }
    }
    else
    {
        return stage1_impl_impl!""(params);
    }
}

private template stage1_impl_impl(string arch)
{
    version(LDC)
    {
        enum Target = target("arch=" ~ arch);
    }
    else
    {
        enum Target;
    }

    @Target
    size_t stage1_impl_impl(
        size_t n,
        scope const(ubyte[64])* vector,
        scope ulong[2]* pairedMask,
        ref bool backwardEscapeBit,
        )
    {
        version(LDC) pragma(inline, false);
        enum ubyte quote = '"';
        enum ubyte escape = '\\';

        version (ARM_Any)
        {
            const ubyte16 quoteMask = quote;
            const ubyte16 escapeMask = escape;
            const ubyte16[2] stringMasks = [quoteMask, escapeMask];
            const ubyte16 mask = [
                0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
            ];
        }
        else
        version (LDC)
        {
            alias __vector(ubyte[64]) ubyte64;
            ubyte64 quoteMask = quote;
            ubyte64 escapeMask = escape;
        }

        size_t count;
        assert(n);
        size_t i;
        int beb = backwardEscapeBit;
        while(i < n)
        {
            version (ARM_Any)
            {
                auto v = *cast(ubyte16[4]*)vector;
                vector++;
                ubyte16[4][2] d;
                static foreach (i; 0 .. 2)
                static foreach (j; 0 .. 4)
                    d[i][j] = cast(ubyte16) __builtin_vceqq_u8(v[j], stringMasks[i]);
                static foreach (i; 0 .. 2)
                static foreach (j; 0 .. 4)
                    d[i][j] &= mask;
                version (AArch64)
                {
                    static foreach (_; 0 .. 3)
                    static foreach (i; 0 .. 2)
                    static foreach (j; 0 .. 4)
                        d[i][j] = __builtin_vpadd_u32(d[i][j], d[i][j]);

                    ushort8 result;
                    static foreach (i; 0 .. 2)
                    static foreach (j; 0 .. 4)
                        result[i * 4 + j] = extractelement!(ushort8, i * 4 + j)(cast(ushort8) d[i][j]);
                }
                else
                {
                    align(8) ubyte[16] result;
                    static foreach (i; 0 .. 2)
                    static foreach (j; 0 .. 4)
                    {
                        d[i][j] = d[i][j]
                            .__builtin_vpaddlq_u8
                            .__builtin_vpaddlq_u16
                            .__builtin_vpaddlq_u32;
                        result[i * 8 + j * 2 + 0] = extractelement!(ubyte16, 0)(d[i][j]);
                        result[i * 8 + j * 2 + 1] = extractelement!(ubyte16, 8)(d[i][j]);
                    }
                }
                ulong[2] maskPair = cast(ulong[2]) result;
            }
            else
            version (LDC) // works well for all X86 and x86_64 targets
            {
                auto v = (cast(ubyte64*)vector)[i];
                ulong[2] maskPair = [
                    equalMaskB!ubyte64(v, quoteMask),
                    equalMaskB!ubyte64(v, escapeMask),
                ];
            }
            else
            {
                ulong[2] maskPair;
                foreach_reverse (b; vector[i])
                {
                    maskPair[0] <<= 1;
                    maskPair[1] <<= 1;
                    maskPair[0] |= b == quote;
                    maskPair[1] |= b == escape;
                }
            }
            pairedMask[i] = maskPair;
            ++i;
            if (maskPair[1] == ulong.max) //need this
                continue; // preserve backwardEscapeBit 
            auto fe = (maskPair[1] << 1) | beb;
            count += cast(size_t) ctpop(maskPair[0]);
            auto rc = ctlz(maskPair[1]);
            auto m = maskPair[0] & fe;
            beb = rc & 1; // even escape count
            if (m == 0)
                continue;
            auto le = 64;
            fe = ~fe;
            do
            {
                auto c = ctlz(m);
                auto d = c + 1;
                fe <<= d;
                le -= d;
                auto gf = ctlz(fe);
                m <<= d;
                if (gf & 1) // reset the bit
                {
                    auto b = 1UL << le;
                    assert(maskPair[0] & b);
                    maskPair[0] ^= 1UL << le;
                }
            }
            while(m);
            pairedMask[i - 1][0] = maskPair[0];
        }
        backwardEscapeBit = beb & 1;
        return count;
    }
}

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
        assert (ebits[i] == (i == '\\'));
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
}
