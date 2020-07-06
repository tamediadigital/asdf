module mir.ion.tests.lob;
import mir.ion.lob;

@safe:
pure:

unittest
{
    import mir.ion.value : IonValue;
    // null.string
    assert(IonValue([0x9F]).describe.get!IonClob == null);
    // empty string
    assert(IonValue([0x90]).describe.get!IonClob != null);
    assert(IonValue([0x90]).describe.get!IonClob.data == "");

    assert(IonValue([0x95, 0x63, 0x6f, 0x76, 0x69, 0x64]).describe.get!IonClob.data == "covid");
}

unittest
{
    import  mir.ion.value;
    // null.string
    assert(IonValue([0xAF]).describe.get!IonBlob == null);
    // empty string
    assert(IonValue([0xA0]).describe.get!IonBlob != null);
    assert(IonValue([0xA0]).describe.get!IonBlob.data == "");

    assert(IonValue([0xA5, 0x63, 0x6f, 0x76, 0x69, 0x64]).describe.get!IonBlob.data == "covid");
}
