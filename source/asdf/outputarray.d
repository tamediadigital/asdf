module asdf.outputarray;

import asdf.asdf;

version(X86_64)
    version = X86_Any;
else
version(X86)
    version = X86_Any;

package struct OutputArray
{
	import core.memory;

	ubyte[] data;
	size_t shift;

pure:

	auto result()
	{
		return Asdf(data[0 .. shift]);
	}

	this(size_t initialLength)
	{
		assert(initialLength >= 32);
		const len = initialLength % 16 ? (initialLength + 16) / 16 * 16 : initialLength;
		data = cast(ubyte[]) GC.malloc(len)[0 .. len];
	}

	size_t skip(size_t len)
	{
		auto ret = shift;
		shift += len;
		if(shift > data.length)
			extend;
		return ret;
	}

	void put(in char[] str)
	{
		size_t newShift = shift + str.length;
		if(newShift > data.length)
			extend(str.length);
		data[shift .. newShift] = cast(ubyte[])str;
		//assert(newShift > shift);
		shift = newShift;
	}

	void put1(ubyte b)
	{
		put1(b, shift);
		shift += 1;
	}

	void put(char b)
	{
		put1(cast(ubyte)b);
	}

	void put4(uint b)
	{
		put4(b, shift);
		shift += 4;
	}

	void put1(ubyte b, size_t sh)
	{
		assert(sh <= data.length);
		if(sh == data.length)
			extend;
		data[sh] = b;
	}

	void put4(uint b, size_t sh)
	{
		immutable newShift = sh + 4;
		if(newShift > data.length)
			extend;
		version (X86_Any)
			*cast(uint*) (data.ptr + sh) = b;
		else
			*cast(ubyte[4]*) (data.ptr + sh) = cast(ubyte[4]) cast(uint[1]) [b];
	}

	void extend(size_t len)
	{
		size_t length = (data.length) * 2 + len;
		void[] t = data;
		t = GC.realloc(t.ptr, length)[0 .. length];
		data = cast(ubyte[])t;
	}

	void extend()
	{
		size_t length = (data.length) * 2;
		void[] t = data;
		t = GC.realloc(t.ptr, length)[0 .. length];
		data = cast(ubyte[])t;
	}
}
