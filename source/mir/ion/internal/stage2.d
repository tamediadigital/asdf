module mir.ion.internal.stage2;

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

void stage2(
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask,
    )
{
    version (X86_64)
    {
        import cpuid.x86_any;
        if (avx512bw)
            return stage2_impl_skylake_avx512(n, vector, pairedMask);
        if (avx2)
            return stage2_impl_broadwell(n, vector, pairedMask);
        if (avx)
            return stage2_impl_sandybridge(n, vector, pairedMask);
        if (sse42)
            return stage2_impl_westmere(n, vector, pairedMask);
        assert(0);
    }
    else
        static assert(0);
}

@target("arch=westmere")
private void stage2_impl_westmere(
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask,
    )
{
    pragma(inline, false);
    __vector(ubyte[16]) whiteSpaceMask = [
        ' ', 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, '\t', '\n', 0x80, 0x80, '\r', 0x80, 0x80
    ];
    // , 2C : 3A [ 5B ] 5D { 7B } 7D
    __vector(ubyte[16]) operatorMask = [
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, ':', '{', ',', '}', 0x80, 0x80
    ];

    alias equal = equalMaskB!(__vector(ubyte[16]));

    do
    {
        auto v =  cast(__vector(ubyte[16])[4])*vector++;
        align(8) ushort[4][2] result;
        static foreach (i; 0 .. v.length)
        {{
            auto a = __builtin_ia32_pshufb(operatorMask, v[i]);
            auto b = __builtin_ia32_pshufb(whiteSpaceMask, v[i]);
            result[0][i] = equal(v[i] | ubyte(0x20), a);
            result[1][i] = equal(v[i], b);
        }}
        *pairedMask++ = cast(ulong[2]) result;
    } while(--n);
}

@target("arch=sandybridge")
private void stage2_impl_sandybridge(
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask,
    )
{
    pragma(inline, false);
    __vector(ubyte[16]) whiteSpaceMask = [
        ' ', 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, '\t', '\n', 0x80, 0x80, '\r', 0x80, 0x80
    ];
    // , 2C : 3A [ 5B ] 5D { 7B } 7D
    __vector(ubyte[16]) operatorMask = [
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, ':', '{', ',', '}', 0x80, 0x80
    ];

    alias equal = equalMaskB!(__vector(ubyte[16]));

    do
    {
        auto v =  cast(__vector(ubyte[16])[4])*vector++;
        align(8) ushort[4][2] result;
        static foreach (i; 0 .. v.length)
        {{
            auto a = __builtin_ia32_pshufb(operatorMask, v[i]);
            auto b = __builtin_ia32_pshufb(whiteSpaceMask, v[i]);
            result[0][i] = equal(v[i] | ubyte(0x20), a);
            result[1][i] = equal(v[i], b);
        }}
        *pairedMask++ = cast(ulong[2]) result;
    } while(--n);
}

@target("arch=broadwell")
private void stage2_impl_broadwell(
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask,
    )
{
    pragma(inline, false);
    __vector(ubyte[32]) whiteSpaceMask = [
        ' ', 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, '\t', '\n', 0x80, 0x80, '\r', 0x80, 0x80,
        ' ', 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, '\t', '\n', 0x80, 0x80, '\r', 0x80, 0x80,
    ];
    __vector(ubyte[32]) operatorMask = [
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, ':', '{', ',', '}', 0x80, 0x80,
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, ':', '{', ',', '}', 0x80, 0x80,
    ];

    alias equal = equalMaskB!(__vector(ubyte[32]));

    do
    {
        auto v =  cast(__vector(ubyte[32])[2])*vector++;
        align(8) uint[v.length][2] result;
        static foreach (i; 0 .. v.length)
        {{
            auto a = __builtin_ia32_pshufb256(operatorMask, v[i]);
            auto b = __builtin_ia32_pshufb256(whiteSpaceMask, v[i]);
            result[0][i] = equal(v[i] | ubyte(0x20), a);
            result[1][i] = equal(v[i], b);
        }}
        *pairedMask++ = cast(ulong[2]) result;
    } while(--n);
}

@target("arch=skylake-avx512")
private void stage2_impl_skylake_avx512(
    size_t n,
    scope const(ubyte[64])* vector,
    scope ulong[2]* pairedMask,
    )
{
    pragma(inline, false);
    __vector(ubyte[64]) whiteSpaceMask = [
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, '\t', '\n', 0x80, 0x80, '\r', 0x80, 0x80,
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        ' ', 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
    ];
    // , 2C : 3A [ 5B ] 5D { 7B } 7D
    __vector(ubyte[64]) operatorMask = [
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, '[', 0x80, ']', 0x80, 0x80,
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, ',', 0x80, 0x80, 0x80,
        0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, ':', '{', 0x80, '}', 0x80, 0x80,
    ];

    alias equal = equalMaskB!(__vector(ubyte[64]));

    do
    {
        auto v =  cast(__vector(ubyte[64]))*vector++;
        auto a = __builtin_ia32_pshufb512(operatorMask, v);
        auto b = __builtin_ia32_pshufb512(whiteSpaceMask, v);
        pairedMask[0][0] = equal(v, a);
        pairedMask[0][1] = equal(v, b);
        pairedMask++;
    } while(--n);
}
