/++
$(H2 ASDF Package)

Publicly imports $(SUBMODULE _asdf), $(SUBMODULE jsonparser), and $(SUBMODULE serialization).

Copyright: Tamedia Digital, 2016

Authors: Ilya Yaroshenko

License: MIT

Macros:
SUBMODULE = $(LINK2 asdf_$1.html, _asdf.$1)
SUBREF = $(LINK2 asdf_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
+/
module mir.ion;

///
unittest
{
    import std.stdio;
    import std.algorithm;
    import mir.ion;

    size_t femalesCount()
    {
        auto val = Asdf("Female");
        return
            File("data.jsonl")
            // Use at least a size of file system block, which is usually equals to 4096 bytes.
            .byChunk(4096)
            // Use approximate size of an object.
            // Size of the internal buffer would be extended automatically
            .parseJsonByLine
            .filter!(object => object["gender"] == val)
            .count;
    }
}

public import mir.ion.asdf;
public import mir.ion.jsonparser;
public import mir.ion.serialization;
public import mir.ion.transform;
