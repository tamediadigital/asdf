module mir.ion.draft;

// import mir.bitop;
import core.bitop: ctpop = popcnt;
import core.simd;
import core.stdc.string;
import ldc.attributes;
import ldc.llvmasm;
import ldc.simd;
import mir.checkedint;
import std.traits: Signed;
import mir.ion.internal.simd;

enum localBufferLength = 4096;
enum tinyStringSize = 127;
enum smallStringSize = localBufferLength * 2 - 2;
enum maxKeyLength = smallStringSize;
enum maxNumberLength = localBufferLength * 2;

// modes 1: extern memory
// modes 2: local buffer

/++
Buffers:
n - threads number

-------------------------------------------
| buffer -1 | buffer 0 |  ... | buffer n-1|
-------------------------------------------

First iteration:


            | part 0   | ...  | part n-1  |
-------------------------------------------
| buffer -1 | buffer 0 |  ... | buffer n-1|
-------------------------------------------

          _ part j   | ...  _ part j+n-1 |
-------------------------------------------
| buffer -1 | buffer 0 |  ... | buffer n-1|
-------------------------------------------

2 ^ 14 = 16*1024
reserve two bytes for small string,
reserve 

bool masks

First:

equality masks
" mask (stage 1)
\ mask (stage 1)
count " except \" cases (stage 1)

operator mask
whitespace mask (optional)
+/


void dun()()
{
    
}

// before begin:
// utf8 char
// \u \x and friends
// true, false, null (atoms)

// ///
// bool[] arrayOfQuotes;
///
bool[] arrayOfAllStars;
///
bool[] arrayOfBackSlashesAndQuotes;

enum JsonParserState
{
    error = -1,
    endOfStream,
    objectBegin = '{',
    objectEnd = '}',
    arrayBegin = '[',
    arrayEnd = ']',
    elementsSeparator = ',',
    keyValueSeparator = ':',
    string_ = '\"',
    stringPart_ = 'p', // always ands with the string's END
    stringEnd_ = 'q',
    number_ = 'e',
    true_ = 't',
    false_ = 'f',
    null_ = 'n',
}

//https://github.com/WojciechMula/simd-string/blob/master/memcmp.cpp

/++
+/
enum Endian
{
    little,
    big,
}

// All object/arrays except empty and null cases has length equal to 4/8

// MEMORY
// BINARY ION, [N bytes space for safety], [ current number buffer ... ] <- STACK

version(LittleEndian)
{
    /++

    +/
    enum MachineEndian = Endian.little;
}
else
{
    enum MachineEndian = Endian.big;
}

/++
Largest Decimal Radix for 32-bit unsigned
+/
enum UInt DecimalRadix(UInt : uint) = 1_000_000_000;

/++
Largest Decimal Radix for 64-bit unsigned
+/
enum UInt DecimalRadix(UInt : ulong) = 10_000_000_000_000_000_000;

/++
Base 10 pow of $(MREF DecimalRadix) for 32-bit unsigned
+/
enum uint DecimalRadixPow(UInt : uint) = 9;

/++
Base 10 pow of $(MREF DecimalRadix) for 64-bit unsigned
+/
enum uint DecimalRadixPow(UInt : ulong) = 19;

/++
+/
struct VarUIntView(UInt, Endian endian = Endian.big)
    if (isUnsigned!UInt)
{
    UInt[] coefficients;
}

/++
Arbitrary length unsigned integer view.
+/
struct BigUIntView(UInt, Endian endian = MachineEndian)
    if (isUnsigned!UInt)
{
    /++
    A group of coefficients for a radix `UInt.max + 1`.

    The order corresponds to endianness.
    +/
    UInt[] coefficients;

    /++
    Retrurns: signed integer view using the same data payload
    +/
    BigIntView!(Signed!UInt) signed() @safe pure nothrow @nogc @property
    {
        return typeof(return)(this);
    }
}

/++
Arbitrary length signed integer view.
+/
struct BigIntView(Int, Endian endian = MachineEndian)
    if (isSigned!Int)
{
    /++
    Self-assigned to unsigned integer view $(MREF BigUIntView).

    Sign is stored in the most significant bit.

    The number is encoded in two's-complement number system the same way
    as common fixed length signed intgers.
    +/
    BigUIntView!(Unsigned!Int) unsigned;
    /// ditto
    alias unsigned this;

    /++
    Extracts sign bit
    +/
    bool sign() @safe pure nothrow @nogc const @property
    {
        return unsigned.coefficients.length && sign_assumeNonEmpty;
    }

    /++
    Extracts sign bit

    Assumes that coefficients aren't empty.
    +/
    bool sign_assumeNonEmpty() @safe pure nothrow @nogc const @property
    {
        assert(coefficients.length);
        return cast(Int)coefficientsFromMostSignificant.front < 0;
    }
}

/++
Arbitrary length signed binary floating-point view with `sign` member.

Note: this templated structure is represented by two templates with different payloads.
The other one templated structure has signed `significant` and no `sign` member.
+/
struct BigFloatView(UInt, Endian endian = MachineEndian)
    if (isUnsigned!UInt)
{
    /++
    Arbitrary length unsigned significant.
    +/
    BigUIntView!UInt significant;

    /++
    Base-2 exponent
    +/
    sizediff_t exponent;

    /++
    Sign
    +/
    bool sign;
}

/++
Arbitrary length signed binary floating-point view with signed `significant`.

Note: this templated structure is represented by two templates with different payloads.
The other one templated structure has unsigned `significant` and separate `sign` member.
+/
struct BigFloatView(Int, Endian endian = MachineEndian)
    if (isSigned!Int)
{
    /++
    Arbitrary length signed significant.
    +/
    BigIntView!Int significant;

    /++
    Base-2 exponent
    +/
    sizediff_t exponent;

    /++
    Extracts `significant` sign bit
    +/
    bool sign() @safe pure nothrow @nogc const @property
    {
        return significant.sign;
    }

    /++
    Extracts sign bit

    Assumes that coefficients aren't empty.
    +/
    bool sign_assumeNonEmpty() @safe pure nothrow @nogc const @property
    {
        assert(significant.coefficients.length);
        return significant.sign_assumeNonEmpty;
    }
}

/++
Arbitrary length decimal floating-point view with `sign` member.

Note: this templated structure is represented by two templates with different payloads.
The other one templated structure has signed `significant` and no `sign` member.
+/
struct BigDecimalView(UInt, Endian endian = MachineEndian)
    if (isUnsigned!UInt)
{
    /++
    Arbitrary length unsigned significant.
    +/
    BigUIntView!UInt significant;

    /++
    Base-10 exponent
    +/
    sizediff_t exponent;

    /++
    Sign
    +/
    bool sign;
}

/++
Arbitrary length decimal floating-point view with signed `significant`.

Note: this templated structure is represented by two templates with different payloads.
The other one templated structure has unsigned `significant` and separate `sign` member.
+/
struct BigDecimalView(Int, Endian endian = MachineEndian)
    if (isSigned!Int)
{
    /++
    Arbitrary length signed significant
    +/
    BigIntView!Int significant;

    /++
    Base-10 exponent
    +/
    sizediff_t exponent;

    /++
    Extracts `significant` sign bit
    +/
    bool sign() @safe pure nothrow @nogc const @property
    {
        return significant.sign;
    }

    /++
    Extracts sign bit

    Assumes that coefficients aren't empty.
    +/
    bool sign_assumeNonEmpty() @safe pure nothrow @nogc const @property
    {
        assert(significant.coefficients.length);
        return significant.sign_assumeNonEmpty;
    }
}

/++
An utility type to wrap a local buffer to accumulate unsigned numbers.
+/
struct BigUIntAccumulator(UInt, Endian endian = MachineEndian)
    if (isUnsigned!UInt)
{
    /++
    A group of coefficients for a $(MREF DecimalRadix)`!UInt`.

    The order corresponds to endianness.

    The unused part can be uninitialized.
    +/
    UInt[] coefficients;

    /++
    Current length of initialized coefficients.

    The initialization order corresponds to endianness.
    +/
    size_t length;

    /++
    Returns:
        Current unsigned integer view
    +/
    BigUIntView!UInt view() @safe pure nothrow @nogc @property
    {
        version (LittleEndian)
            return typeof(return)(coefficients[0 .. length]);
        else
            return typeof(return)(coefficients[$ - length .. $]);
    }

    /++
    Returns:
        True if the accumulator can accept next most significant coefficient 
    +/
    bool canPut()
    {
        return length < coeffecients.length;
    }

    /++
    Places coefficient to the next most significant position.
    +/
    void put(UInt coeffecient)
    in {
        assert(length < coeffecients.length);
    }
    do {
        version (LittleEndian)
            coefficients[length++] = coeffecient;
        else
            coefficients[$ - ++length] = coeffecient;
    }
}

/++
An utility type to wrap a local buffer to accumulate unsigned numbers.
+/
struct BigIntAccumulator(Int, Endian endian = MachineEndian)
    if (isSigned!Int)
{
    /++
    Self-assigned to unsigned integer accumulator $(MREF BigUIntAccumulator).

    Sign is stored in the most significant bit of the current mist significant coeffecient.

    The number is encoded in two's-complement number system the same way
    as common fixed length signed intgers.
    +/
    BigUIntView!(Unsigned!Int) unsigned;
    /// ditto
    alias unsigned this;

    /++
    Returns:
        Current signed integer view.
    +/
    BigIntView!Int view() @safe pure nothrow @nogc @property
    {
        return typeof(return)(unsigned.view);
    }
}

// Reading should be performed starting from the most significant digit.

/++
Performs logical negation on each bit.
Params:
    number = unsigned number view with non-empty coefficients
+/
void applyBitwiseNot_assumeNonEmpty(UInt)(BigUIntView!UInt number)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
}
do {
    auto ns = number.coefficientsFromLeastSignificant;
    do
    {
        ns.front = ~ns.front;
        ns.popFront;
    }
    while (ns.length);
}

/++
Performs `big+=scalar` operatrion.
Params:
    number = unsigned number view (accumulator) with non-empty (current) coefficients
Returns:
    true in case of unsigned overflow
+/
bool applyUnsignedAdd_assumeNonEmpty(UInt)(BigUIntView!UInt number, UInt additive)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
}
do {
    auto ns = number.coefficientsFromLeastSignificant;
    do
    {
        ns.front = addu(ns.front, additive, overflow);
        if (!overflow)
            return false;
        additive = 1;
        ns.popFront;
    }
    while (ns.length);
    return true; // number is zero
}

/// ditto
bool applyUnsignedAdd_assumeNonEmpty(UInt)(BigUIntAccumulator!UInt number, UInt additive)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
    assert(number.length);
}
do {
    if (_expect(applyUnsignedAdd_assumeNonEmpty(number.view, additive), false))
    {
        if (_expect(!number.canPut, false))
            return true;
        number.put(1);
    }
    return false;
}

/++
Performs `big-=scalar` operatrion.
Params:
    number = unsigned number view with non-empty coefficients
Returns:
    true in case of unsigned underflow
+/
bool applyUnsignedSub_assumeNonEmpty(UInt)(BigUIntView!UInt number, UInt additive)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
}
do {
    auto ns = number.coefficientsFromLeastSignificant;
    do
    {
        ns.front = subu(ns.front, additive, overflow);
        if (!overflow)
            return false;
        additive = 1;
        ns.popFront;
    }
    while (ns.length);
    return true; // number is zero
}

/++
Performs `number=-number` operatrion.
Params:
    number = (un)signed number view with non-empty coefficients
Returns:
    true if 'number=-number=0' and false otherwise
+/
bool applyNegative_assumeNonEmpty(UInt)(BigUIntView!UInt number)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
}
do {
    applyBitwiseNot_assumeNonEmpty(number);
    return applyUnsignedAdd_assumeNonEmpty(number, 1);
}

/++
Performs `(ret, number) := number * multiplier + additive` for unsigned view.

Params:
    number = unsigned integer number view (accumlator) with non-empty (current) coefficients
    multiplier = multiplier
    additive = additive

Returns:
    Operation overflow value

If the overflow value
equals zero then the `number` contains the exact result.
Otherwise coefficients can be extended with the overflow
value placed into most significant position.
+/
UInt applyUnsignedMullAdd_assumeNonEmpty(UInt)(BigUIntView!UInt number, UInt multiplier, UInt additive = 0)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
}
do {
    auto ns = number.coefficientsFromLeastSignificant;
    do
    {
        auto extended = ns.front.extMul(multiplier);
        bool overflow;
        ns.front = extended.low.addu(additive, overflow);
        additive = ext.high + overflow;
        ns.popFront;
    }
    while (ns.length);
}

/// ditto
UInt applyUnsignedMullAdd_assumeNonEmpty(UInt)(BigUIntAccumulator!UInt number, UInt multiplier, UInt additive = 0)
    if (is(UInt == uint) || is(UInt == ulong))
in {
    assert(number.coeffeicients.length);
    assert(number.length);
}
do {
    auto overflow = applyUnsignedMullAdd_assumeNonEmpty(number.view, additive);
    if (overflow != 0)
    {
        if (_expect(!number.canPut, false))
            return overflow;
        number.put(overflow);
    }
    return 0;
}

/++
Performs `(ret, number) := number * multiplier + additive` for signed view.

Params:
    number = unsigned big number view with non-empty coefficients
    multiplier = multiplier
    additive = additive

Returns:
    Operation overflow/underflow value

If the overflow/underflow value plus resulted `number.sign`
equals zero then the `number` contains the exact result.
Otherwise coefficients can be extended with the overflow/underflow
value placed into most significant position.
+/
UInt applySignedMullAdd_assumeNonEmpty(UInt)(BigUIntView!UInt number, UInt multiplier, UInt additive = 0)
    if (is(Int == int) || is(Int == long))
in {
    assert(number.coeffeicients.length);
}
do {
    bool sign = multiplier < 0;
    if (sign)
    {
        multiplier = -multiplier;
    }
    if (number.sign_assumeNonEmpty)
    {
        sign = !sign;
        number.unsigned.applyNegative_assumeNonEmpty;
    }
    additive = applyUnsignedMullAdd_assumeNonEmpty(number.unsigned, multiplier, additive);
    if (sign)
    {
        additive = ~additive;
        additive += number.unsigned.applyNegative_assumeNonEmpty;
    }
    return additive;
}

/++
Accumulates a digit into `current` and `accumulator` pair.

If current is less then $(MREF DecimalRadix)`!UInt / 10`,
then function sets  `current` to `current * 10 + digit`.

Otherwise sets `accumulator` coeffeicient at its $(MREF DecimalReaderFellow.currentIndex)
and sets `current` to `digit`, moves `currentIndex` to the next position.

Accumulation should be performed starting from the most significant digit.

The function is disigned to be used in pair with $(MREF ).

Returns:
    False if `currentIndex` has been moved out of the bounds and true otherwise.
+/
@safe pure nothrow @nogc
bool accumulateDecimalDigit(UInt)(ref UInt current, UInt digit, ref BigUIntAccumulator!UInt accumulator)
in {
    assert(digit < 10);
    assert(current < DecimalRadix!UInt);
}
do {
    version(LDC) pragma(inline, true);

    enum UInt maxBase10Div10 = DecimalRadix!UInt / 10;

    if (accumulator.length == 0)
    {
        if (_expect(current < maxBase10Div10, true))
        {
            current = current * 10u + digit;
        }
        else
        {
        }
    }
    else
    {
        accumulator[currentIndex] = current;
        current = digit;
        version (LittleEndian)
        {
            if (_expect(--currentIndex < 0, false))
                return false;
        }
        else
        {
            if (_expect(++currentIndex == coefficients.length, false))
                return false;
        }

    }


    return true;
}

version(none):

/++
Put final current.

The function is disigned to be used in pair with $(MREF accumulateDecimalDigit).
+/
@safe pure nothrow @nogc
bool setLastCoefficient(UInt)(UInt last, DecimalReaderFellow!UInt accumulator)
in {
    assert(digit < 10);
    assert(last < DecimalRadix!UInt);
}
do {
    enum UInt maxBase10Div10 = DecimalRadix!UInt / 10;

    {
        accumulator[currentIndex] = current;
        current = digit;
        version (LittleEndian)
        {
            if (_expect(--current < 0, false))
                return false;
        }
        else
        {
            if (_expect(++current == coefficients.length, false))
                return false;
        }
    }
    return true;
}

/++

+/
@safe pure nothrow @nogc
BigDecimalUIntView!UInt toBigDecimalUIntView(UInt)(DecimalReaderFellow!UInt num)
    if (is(UInt == uint) || is(UInt == ulong))
{
    version (LittleEndian)
        return BigDecimalUIntView!UInt(num.coefficients[num.current .. $]);
    else
        return BigDecimalUIntView!UInt(num.coefficients[0 .. num.current + 1]);
}

@safe pure nothrow @nogc
auto coefficientsFromLeastSignificant(T)(T num)
    // if (is(UInt == uint) || is(UInt == ulong))
{
    import mir.ndslice.slice: sliced;
    version (LittleEndian)
    {
        return num.coefficients.sliced;
    }
    else
    {
        import mir.ndslice.topology: retro;
        return num.coefficients.sliced.retro;
    }
}

@safe pure nothrow @nogc
auto coefficientsFromLeastSignificant(T)(T num)
    // if (is(UInt == uint) || is(UInt == ulong))
{
    import mir.ndslice.slice: sliced;
    version (LittleEndian)
    {
        import mir.ndslice.topology: retro;
        return num.coefficients.sliced;
    }
    else
    {
        return num.coefficients.sliced;
    }
}

@safe pure nothrow @nogc
BigUIntView!UInt toBigUIntView(UInt)(BigDecimalUIntView!UInt num)
    if (is(UInt == uint) || is(UInt == ulong))
{
    if (_expect(num.coefficients.length <= 1, true))
        return BigUIntView!UInt(num.coefficients);
    version (LittleEndian)
        auto ret = BigUIntView!UInt(num.coefficients[0 .. 1]);
    else
        auto ret = BigUIntView!UInt(num.coefficients[$ - 1 .. $]);
    auto ns = num.coefficientsFromMostSignificant;
    ns.popFront;
    do
    {
        if (auto overflow = ret.unsignedMullAdd(DecimalRadix!UInt, ns.front))
        {
            auto retLength = ret.num.coefficients.length;
            version (LittleEndian)
            {
                num.coefficients[retLength++] = overflow;
                ret = BigUIntView!UInt(num.coefficients[0 .. retLength]);
            }
            else
            {
                num.coefficients[$ - ++retLength] = overflow;
                ret = BigUIntView!UInt(num.coefficients[$ - retLength .. $]);
            }
        }
        ns.popFront;
    }
    while(ns.length);
}
