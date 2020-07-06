module mir.ion.tests.exception;
import mir.ion.exception;

///
unittest
{
    static assert(!IonErrorCode.none);
    static assert(IonErrorCode.none == IonErrorCode.init);
    static assert(IonErrorCode.nop > 0);
}

///
@safe pure nothrow @nogc
unittest
{
    static assert(IonErrorCode.nop.ionErrorMsg == "unexpected NOP Padding", IonErrorCode.nop.ionErrorMsg);
    static assert(IonErrorCode.none.ionErrorMsg is null);
}

version (D_Exceptions) {
    @safe pure nothrow @nogc
    unittest
    {
        static assert(IonErrorCode.nop.ionException.msg == "MirIonException: unexpected NOP Padding", IonErrorCode.nop.ionException.msg);
        static assert(IonErrorCode.none.ionException is null);
    }
}


