#!/usr/bin/env python3
# python3 etc/dec2flt_table.py > source/mir/internal/dec2flt_table.d
"""
Generate powers of ten using William Clinger's ``AlgorithmM`` for use in
decimal to floating point conversions.

Specifically, computes and outputs (as Rust code) a table of 10^e for some
range of exponents e. The output is one array of 64 bit significands and
another array of corresponding base two exponents. The approximations are
normalized and rounded perfectly, i.e., within 0.5 ULP of the true value.

The representation ([u64], [i16]) instead of the more natural [(u64, i16)]
is used because (u64, i16) has a ton of padding which would make the table
even larger, and it's already uncomfortably large (6 KiB).
"""
from __future__ import print_function
from math import ceil, log
from fractions import Fraction
from collections import namedtuple


N = 128  # Size of the significand field in bits
MIN_SIG = 2 ** (N - 1)
MAX_SIG = (2 ** N) - 1

# Hand-rolled fp representation without arithmetic or any other operations.
# The significand is normalized and always N bit, but the exponent is
# unrestricted in range.
Fp = namedtuple('Fp', 'sig exp')


def algorithm_m(f, e):
    assert f > 0
    if e < 0:
        u = f
        v = 10 ** abs(e)
    else:
        u = f * 10 ** e
        v = 1
    k = 0
    while True:
        x = u // v
        if x < MIN_SIG:
            u <<= 1
            k -= 1
        elif x >= MAX_SIG:
            v <<= 1
            k += 1
        else:
            break
    return ratio_to_float(u, v, k)


def ratio_to_float(u, v, k):
    q, r = divmod(u, v)
    v_r = v - r
    z = Fp(q, k)
    if r < v_r:
        return z
    elif r > v_r:
        return next_float(z)
    elif q % 2 == 0:
        return z
    else:
        return next_float(z)


def next_float(z):
    if z.sig == MAX_SIG:
        return Fp(MIN_SIG, z.exp + 1)
    else:
        return Fp(z.sig + 1, z.exp)


def error(f, e, z):
    decimal = f * Fraction(10) ** e
    binary = z.sig * Fraction(2) ** z.exp
    abs_err = abs(decimal - binary)
    # The unit in the last place has value z.exp
    ulp_err = abs_err / Fraction(2) ** z.exp
    return float(ulp_err)


HEADER = """
/++
Tables of approximations of powers of ten.
DO NOT MODIFY: Generated by `etc/dec2flt_table.py`
+/
module mir.internal.dec2flt_table;
"""


def main():
    print(HEADER.strip())
    print()
    print_proper_powers()
    # print()
    # print_short_powers(64, 53)
    # print_short_powers(32, 24)
    # print()


def print_proper_powers():
    MIN_E = -512
    MAX_E = 512
    e_range = range(MIN_E, MAX_E+1)
    powers = []
    for e in e_range:
        z = algorithm_m(1, e)
        err = error(1, e, z)
        assert err < 0.5
        powers.append(z)
    print("enum min_p10_e = {};".format(MIN_E))
    print("enum max_p10_e = {};".format(MAX_E))
    print()
    print("// ")
    typ = "align(16) ulong[2][{0}]".format(len(powers))
    print("static immutable ", typ, " p10_coefficients = [", sep='')
    for z in powers:
        M = N >> 3
        strH = "{:X}".format((z.sig >> (N // 2)) + ((z.sig >> (N // 2 - 1)) & 1))
        strL = "{:X}".format(z.sig)[M:]
        print("    [0x" + strH + ", 0x" + strL + "],")
    print("];")
    print()
    print("// ")
    typ = "short[{0}]".format(len(powers))
    print("static immutable ", typ, " p10_exponents = [", sep='')
    for z in powers:
        print("    {},".format(z.exp + (N // 2)))
    print("];")


def print_short_powers(num_bits, significand_size):
    max_sig = 2**significand_size - 1
    # The fast path bails out for exponents >= ceil(log5(max_sig))
    max_e = int(ceil(log(max_sig, 5)))
    e_range = range(max_e)
    typ = "double[{}]".format(len(e_range))
    print("// ")
    print("static immutable ", typ, " p10_short = [", sep='')
    for e in e_range:
        print("    1e{},".format(e))
    print("];")


if __name__ == '__main__':
    main()
