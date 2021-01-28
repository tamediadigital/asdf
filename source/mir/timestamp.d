/++
Timestamp
+/
module mir.timestamp;

/++
Timestamp

Note: The component values in the binary encoding are always in UTC, while components in the text encoding are in the local time!
This means that transcoding requires a conversion between UTC and local time.

`Timestamp` precision is up to `10^-12` seconds;
+/
struct Timestamp
{
    ///
    enum Precision : ubyte
    {
        ///
        year,
        ///
        month,
        ///
        day,
        ///
        minute,
        ///
        second,
        ///
        fraction,
    }


    version(all)
    {
        short offset;
    }
    else
    /+
    If the time in UTC is known, but the offset to local time is unknown, this can be represented with an offset of “-00:00”.
    This differs semantically from an offset of “Z” or “+00:00”, which imply that UTC is the preferred reference point for the specified time.
    RFC2822 describes a similar convention for email.
    private short _offset;
    +/
    {

        /++
        Timezone offset in minutes
        +/
        short offset() const @safe pure nothrow @nogc @property
        {
            return _offset >> 1;
        }

        /++
        Returns: true if timezone has offset
        +/
        bool hasOffset() const @safe pure nothrow @nogc @property
        {
            return _offset & 1;
        }
    }

    /++
    Year
    +/
    ushort year;
    /++
    +/
    Precision precision;

    /++
    Month
    
    If the value equals to thero then this and all the following members are undefined.
    +/
    ubyte month;
    /++
    Day
    
    If the value equals to thero then this and all the following members are undefined.
    +/
    ubyte day;
    /++
    Hour
    +/
    ubyte hour;

    version(D_Ddoc)
    {
    
        /++
        Minute

        Note: the field is implemented as property.
        +/
        ubyte minute;
        /++
        Second

        Note: the field is implemented as property.
        +/
        ubyte second;
        /++
        Fraction

        The `fraction_exponent` and `fraction_coefficient` denote the fractional seconds of the timestamp as a decimal value
        The fractional seconds’ value is `coefficient * 10 ^ exponent`.
        It must be greater than or equal to zero and less than 1.
        A missing coefficient defaults to zero.
        Fractions whose coefficient is zero and exponent is greater than -1 are ignored.
        
        'fractionCoefficient' allowed values are [0 ... 10^12-1].
        'fractionExponent' allowed values are [-12 ... 0].

        Note: the fields are implemented as property.
        +/
        byte fractionExponent;
        /// ditto
        long fractionCoefficient;
    }
    else
    {
        import mir.bitmanip: bitfields;
        version (LittleEndian)
        {

            mixin(bitfields!(
                    ubyte, "minute", 8,
                    ubyte, "second", 8,
                    byte, "fractionExponent", 8,
                    long, "fractionCoefficient", 40,
            ));
        }
        else
        {
            mixin(bitfields!(
                    long, "fractionCoefficient", 40,
                    byte, "fractionExponent", 8,
                    ubyte, "second", 8,
                    ubyte, "minute", 8,
            ));
        }
    }

    ///
    @safe pure nothrow @nogc
    this(ushort year)
    {
        this.year = year;
        this.precision = Precision.year;
    }

    ///
    @safe pure nothrow @nogc
    this(ushort year, ubyte month)
    {
        this.year = year;
        this.month = month;
        this.precision = Precision.month;
    }

    ///
    @safe pure nothrow @nogc
    this(ushort year, ubyte month, ubyte day)
    {
        this.year = year;
        this.month = month;
        this.day = day;
        this.precision = Precision.day;
    }

    ///
    @safe pure nothrow @nogc
    this(ushort year, ubyte month, ubyte day, ubyte hour, ubyte minute)
    {
        this.year = year;
        this.month = month;
        this.day = day;
        this.hour = hour;
        this.minute = minute;
        this.precision = Precision.minute;
    }

    ///
    @safe pure nothrow @nogc
    this(ushort year, ubyte month, ubyte day, ubyte hour, ubyte minute, ubyte second)
    {
        this.year = year;
        this.month = month;
        this.day = day;
        this.hour = hour;
        this.day = day;
        this.minute = minute;
        this.second = second;
        this.precision = Precision.second;
    }

    ///
    @safe pure nothrow @nogc
    this(ushort year, ubyte month, ubyte day, ubyte hour, ubyte minute, ubyte second, byte fractionExponent, ulong fractionCoefficient)
    {
        this.year = year;
        this.month = month;
        this.day = day;
        this.hour = hour;
        this.day = day;
        this.minute = minute;
        this.second = second;
        assert(fractionExponent < 0);
        this.fractionExponent = fractionExponent;
        this.fractionCoefficient = fractionCoefficient;
        this.precision = Precision.fraction;
    }

    /++
    Attaches local offset, doesn't adjust other fields.
    Local-time offsets may be represented as either `hour*60+minute` offsets from UTC,
    or as the zero to denote a local time of UTC. They are required on timestamps with time and are not allowed on date values.
    +/
    @safe pure nothrow @nogc const
    Timestamp withOffset(short offset)
    {
        assert(-24 * 60 <= offset && offset <= 24 * 60, "Offset absolute value should be less or equal to 24 * 60");
        assert(precision >= Precision.minute, "Offsets are not allowed on date values.");
        Timestamp ret = this;
        ret.offset = offset;
        return ret;
    }

    version(D_BetterC){} else
    private string toStringImpl(alias fun)() const @safe pure nothrow
    {
        import mir.appender: UnsafeArrayBuffer;
        char[64] buffer = void;
        auto w = UnsafeArrayBuffer!char(buffer);
        fun(w);
        return w.data.idup;
    }

    version(D_BetterC){} else
    /++
    Converts this $(LREF Date) to a string with the format `YYYY-MM-DD`.
    If `writer` is set, the resulting string will be written directly
    to it.

    Returns:
        A `string` when not using an output range; `void` otherwise.
      +/
    string toISOExtString() const @safe pure nothrow
    {
        return toStringImpl!toISOExtString;
    }

    ///ditto
    alias toString = toISOExtString;

    ///
    version (mir_test)
    @safe unittest
    {
        assert(Date.init.toISOExtString == "null");
        assert(Date(2010, 7, 4).toISOExtString == "2010-07-04");
        assert(Date(1998, 12, 25).toISOExtString == "1998-12-25");
        assert(Date(0, 1, 5).toISOExtString == "0000-01-05");
        assert(Date(-4, 1, 5).toISOExtString == "-0004-01-05");
    }

    version (mir_test)
    @safe pure unittest
    {
        import std.array : appender;

        auto w = appender!(char[])();
        Date(2010, 7, 4).toISOString(w);
        assert(w.data == "20100704");
        w.clear();
        Date(1998, 12, 25).toISOString(w);
        assert(w.data == "19981225");
    }

    version (mir_test)
    @safe unittest
    {
        // Test A.D.
        assert(Date(9, 12, 4).toISOExtString == "0009-12-04");
        assert(Date(99, 12, 4).toISOExtString == "0099-12-04");
        assert(Date(999, 12, 4).toISOExtString == "0999-12-04");
        assert(Date(9999, 7, 4).toISOExtString == "9999-07-04");
        assert(Date(10000, 10, 20).toISOExtString == "+10000-10-20");

        // Test B.C.
        assert(Date(0, 12, 4).toISOExtString == "0000-12-04");
        assert(Date(-9, 12, 4).toISOExtString == "-0009-12-04");
        assert(Date(-99, 12, 4).toISOExtString == "-0099-12-04");
        assert(Date(-999, 12, 4).toISOExtString == "-0999-12-04");
        assert(Date(-9999, 7, 4).toISOExtString == "-9999-07-04");
        assert(Date(-10000, 10, 20).toISOExtString == "-10000-10-20");

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.toISOExtString == "1999-07-06");
        assert(idate.toISOExtString == "1999-07-06");
    }

    /// ditto
    void toISOExtString(W)(scope ref W w) const scope
        // if (isOutputRange!(W, char))
    {
        import mir.format: printZeroPad;
        // YYYY-MM-DDThh:mm:ss±hh:mm
        Timestamp t = this;
        if (offset)
        {
            assert(-24 * 60 <= offset && offset <= 24 * 60, "Offset absolute value should be less or equal to 24 * 60");
            assert(precision >= Precision.minute, "Offsets are not allowed on date values.");
            auto totalMinutes = offset + t.hour * t.minute;
            int dayShift;
            if (totalMinutes < 0)
            {
                dayShift = -1;
            }
            else
            if (totalMinutes > 24 * 60)
            {
                dayShift = +1;
            }
            if (dayShift)
            {
                totalMinutes -= dayShift * 24 * 60;
                t.hour = cast(ubyte) (totalMinutes / 60);
                t.minute = cast(ubyte) (totalMinutes % 60);

                import mir.date: Date;
                auto ymd = (Date.trustedCreate(year, month, day) + dayShift).yearMonthDay;
                t.year = ymd.year;
                t.month = cast(ubyte)ymd.month;
                t.day = ymd.day;
            }
        }

        if (year >= 10_000)
            w.put('+');
        printZeroPad(w, t.year, t.year >= 0 ? t.year < 10_000 ? 4 : 5 : t.year > -10_000 ? 5 : 6);
        w.put(precision == Precision.year ? 'T' : '-');
        if (precision == Precision.year)
            return;

        printZeroPad(w, cast(uint)t.month, 2);
        w.put(precision == Precision.month ? 'T' : '-');
        if (precision == Precision.month)
            return;

        printZeroPad(w, t.day, 2);
        if (precision == Precision.day)
            return;
        w.put('T');

        printZeroPad(w, t.hour, 2);
        w.put(':');
        printZeroPad(w, t.minute, 2);

        if (precision >= Precision.second)
        {
            w.put(':');
            printZeroPad(w, t.second, 2);

            if (precision > Precision.second && (t.fractionExponent < 0 || t.fractionCoefficient))
            {
                w.put('.');
                printZeroPad(w, t.fractionCoefficient, -int(t.fractionExponent));
            }
        }

        if (t.offset == 0)
        {
            w.put('Z');
            return;
        }

        bool sign = t.offset < 0;
        uint absoluteOffset = !sign ? t.offset : -int(t.offset);
        uint offsetHour = absoluteOffset / 60u;
        uint offsetMinute = absoluteOffset % 60u;

        w.put(sign ? '+' : '-');
        printZeroPad(w, offsetHour, 2);
        w.put(':');
        printZeroPad(w, offsetMinute, 2);
    }
}
