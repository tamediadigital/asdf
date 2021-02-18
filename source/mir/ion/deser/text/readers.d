/++
    Helpers for reading values from a given Ion token.
+/
module mir.ion.deser.text.readers;
import mir.ion.deser.text.tokenizer;

void readContainer(T)(ref T t, T.inputType term) 
if (isInstanceOf!(IonTokenizer, T)) {

}