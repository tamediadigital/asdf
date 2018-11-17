/++
$(H3 ASDF and JSON Serialization)
+/
module asdf.serialization;

import asdf.jsonparser: assumePure;

///
pure unittest
{
	import std.bigint;
	import std.datetime;
	import std.conv;

	enum E
	{
		a,
		b, 
		c,
	}

	static class C
	{
		private double _foo;
	pure:
		this()
		{
			_foo = 4;
		}

		double foo() @property
		{
			return _foo + 10;
		}

		void foo(double d) @property
		{
			_foo = d - 10;
		}
	}

	static struct DateTimeProxy
	{
		DateTime datetime;
		alias datetime this;

		static DateTimeProxy deserialize(Asdf data) pure
		{
			string val;
			deserializeScopedString(data, val);
			return DateTimeProxy(DateTime.fromISOString(val));
		}

		void serialize(S)(ref S serializer) pure
		{
			serializer.putValue(datetime.toISOString);
		}
	}

	static struct S
	{
		@serializedAs!DateTimeProxy
		DateTime time;
		
		C object;

		string[E] map;

		@serializationKeys("bar_common", "bar")
		string bar;
	}

	enum json = `{"time":"20160304T000000","object":{"foo":14},"map":{"a":"A"},"bar_common":"escaped chars = '\\', '\"', '\t', '\r', '\n'"}`;
	auto value = S(
		DateTime(2016, 3, 4), 
		new C,
		[E.a : "A"],
		"escaped chars = '\\', '\"', '\t', '\r', '\n'");
	assert(serializeToJson(value) == json);
	assert(serializeToAsdf(value).to!string == json);
	assert(deserialize!S(json).serializeToJson == json);
}

/// `finalizeSerialization` method
unittest
{
	static struct S
	{
		string a;
		int b;

		void finalizeSerialization(Serializer)(ref Serializer serializer)
		{
			serializer.putKey("c");
			serializer.putValue(100);
		}
	}
	assert(S("bar", 3).serializeToJson == `{"a":"bar","b":3,"c":100}`);
}

/// `finalizeDeserialization` method
pure unittest
{
	static struct S
	{
		string a;
		int b;

		@serializationIgnoreIn
		double sum;

		void finalizeDeserialization(Asdf data) pure
		{
			auto r = data["c", "d"];
			auto a = r["e"].get(0.0);
			auto b = r["g"].get(0.0);
			sum = a + b;
		}
	}
	assert(`{"a":"bar","b":3,"c":{"d":{"e":6,"g":7}}}`.deserialize!S == S("bar", 3, 13));
}

/// A user may define setter and/or getter properties.
unittest
{
	static struct S
	{
		@serializationIgnore string str;
	pure:
		string a() @property
		{
			return str;
		}

		void b(int s) @property
		{
			str = s.to!string;
		}
	}

	assert(S("str").serializeToJson == `{"a":"str"}`);
	assert(`{"b":123}`.deserialize!S.str == "123");
}

/// Support for custom nullable types (types that has a bool property `isNull`,
/// non-void property `get` returning payload and void property `nullify` that
/// makes nullable type to null value)
unittest
{
	static struct MyNullable
	{
		long value;

		@property
		isNull() const
		{
			return value == 0;
		}

		@property
		get()
		{
			return value;
		}

		@property
		nullify()
		{
			value = 0;
		}

		auto opAssign(long value)
		{
			this.value = value;
		}
	}

	static struct Foo
	{
		MyNullable my_nullable;
		string field;

		bool opEquals()(auto ref const(typeof(this)) rhs)
		{
			if (my_nullable.isNull && rhs.my_nullable.isNull)
				return field == rhs.field;

			if (my_nullable.isNull != rhs.my_nullable.isNull)
				return false;

			return my_nullable == rhs.my_nullable && 
				         field == rhs.field;
		}
	}

	static assert(isNullable!MyNullable);

	Foo foo;
	foo.field = "it's a foo";

	assert (serializeToJson(foo) == `{"my_nullable":null,"field":"it's a foo"}`);

	foo.my_nullable = 200;

	assert (deserialize!Foo(`{"my_nullable":200,"field":"it's a foo"}`) == Foo(MyNullable(200), "it's a foo"));

	import std.typecons : Nullable;
	import std.stdio;

	static struct Bar
	{
		Nullable!long nullable;
		string field;

		bool opEquals()(auto ref const(typeof(this)) rhs)
		{
			if (nullable.isNull && rhs.nullable.isNull)
				return field == rhs.field;

			if (nullable.isNull != rhs.nullable.isNull)
				return false;

			return nullable == rhs.nullable && 
				         field == rhs.field;
		}
	}

	static assert(isNullable!(Nullable!(int)));

	Bar bar;
	bar.field = "it's a bar";

	assert (serializeToJson(bar) == `{"nullable":null,"field":"it's a bar"}`);

	bar.nullable = 777;
	assert (deserialize!Bar(`{"nullable":777,"field":"it's a bar"}`) == Bar(Nullable!long(777), "it's a bar"));
}

/// Support for floating point nan and (partial) infinity
unittest
{
	static struct Foo
	{
		float f;

		bool opEquals()(auto ref const(typeof(this)) rhs)
		{
			import std.math : isNaN, approxEqual;

			if (f.isNaN && rhs.f.isNaN)
				return true;

			return approxEqual(f, rhs.f);
		}
	}

	// test for Not a Number
	assert (serializeToJson(Foo()).to!string == `{"f":"nan"}`);
	assert (serializeToAsdf(Foo()).to!string == `{"f":"nan"}`);

	assert (deserialize!Foo(`{"f":null}`)  == Foo());
	assert (deserialize!Foo(`{"f":"nan"}`) == Foo());

	assert (serializeToJson(Foo(1f/0f)).to!string == `{"f":"inf"}`);
	assert (serializeToAsdf(Foo(1f/0f)).to!string == `{"f":"inf"}`);
	assert (deserialize!Foo(`{"f":"inf"}`)  == Foo( float.infinity));
	assert (deserialize!Foo(`{"f":"-inf"}`) == Foo(-float.infinity));

	assert (serializeToJson(Foo(-1f/0f)).to!string == `{"f":"-inf"}`);
	assert (serializeToAsdf(Foo(-1f/0f)).to!string == `{"f":"-inf"}`);
	assert (deserialize!Foo(`{"f":"-inf"}`) == Foo(-float.infinity));
}

import std.traits;
import std.meta;
import std.range.primitives;
import std.functional;
import std.conv;
import std.utf;
import std.format: FormatSpec, formatValue, singleSpec;
import std.bigint: BigInt;
import asdf.asdf;

///
class DeserializationException: AsdfException
{
	///
	ubyte kind;

	///
	string func;

	///
	this(
		ubyte kind,
		string msg = "Unexpected ASDF kind",
		string func = __PRETTY_FUNCTION__,
		string file = __FILE__,
		size_t line = __LINE__,
		Throwable next = null) pure nothrow @nogc @safe 
	{
		this.kind = kind;
		this.func = func;
		super(msg, file, line, next);
	}

	///
	this(
		ubyte kind,
		string msg,
		Throwable next,
		string func = __PRETTY_FUNCTION__,
		string file = __FILE__,
		size_t line = __LINE__,
		) pure nothrow @nogc @safe 
	{
		this(kind, msg, func, file, line, next);
	}

}

/// JSON serialization function.
string serializeToJson(V)(auto ref V value)
{
	return serializeToJsonPretty!""(value);
}

///
unittest
{
	struct S
	{
		string foo;
		uint bar;
	}

	assert(serializeToJson(S("str", 4)) == `{"foo":"str","bar":4}`);
}

/// JSON serialization function with pretty formatting.
string serializeToJsonPretty(string sep = "\t", V)(auto ref V value)
{
	import std.array;
	auto app = appender!(char[]);
	auto ser = jsonSerializer!sep(&app.put!(const(char)[]));
	ser.serializeValue(value);
	ser.flush;
	return cast(string) app.data;
}

///
unittest
{
	static struct S { int a; }
	assert(S(4).serializeToJsonPretty == "{\n\t\"a\": 4\n}");
}

/// ASDF serialization function
Asdf serializeToAsdf(V)(auto ref V value, size_t initialLength = 32)
{
	auto ser = asdfSerializer(initialLength);
	ser.serializeValue(value);
	ser.flush;
	return ser.app.result;
}

///
unittest
{
	struct S
	{
		string foo;
		uint bar;
	}

	assert(serializeToAsdf(S("str", 4)).to!string == `{"foo":"str","bar":4}`);
}

/// Check if type T has static templated method allowing to 
/// deserialize instance of T from range R like
/// ```
///     R r;
///     ...
///     auto t = T.deserialize(r); // ok
/// ```
private template hasStaticTemplatedDeserialize(T, R)
{
	import std.traits : hasMember;

	static if (
		// T shall have the method `deserialize`
		hasMember!(T, "deserialize") &&
		// this method shall be templated
		__traits(isTemplate, T.deserialize))
	{
		// this method shall be templated by R type,
		// takes it as only argument and
		static assert(is(typeof(T.deserialize(R.init))), 
			"To be usable with Asdf library signature of `" ~ T.stringof ~ ".deserialize` shall be the following: `deserialize(" ~ R.stringof ~ ")(" ~ R.stringof ~ " arg)`. (* Now it has " ~ __traits(getMember, T, "deserialize").stringof ~ " *). If it exists check if it compiles.");
		// returns result of T type);
		static assert(is(typeof(T.deserialize(R.init)) == T), 
			"To be usable with Asdf library method `" ~ T.stringof ~ ".deserialize(" ~ R.stringof ~ ")(" ~ R.stringof ~ " arg)` shall have return type `" ~ T.stringof ~ "` instead of `" ~ typeof(T.deserialize(R.init)).stringof ~ "`");
		enum hasStaticTemplatedDeserialize = true;
	}
	else
	{
		enum hasStaticTemplatedDeserialize = false;
	}
}

/// Deserialization function
V deserialize(V)(Asdf data)
{
	static if (hasStaticTemplatedDeserialize!(V, Asdf))
	{
		return V.deserialize(data);
	}
	else
	{
		V value;
		deserializeValue(data, value);
		return value;
	}
}

/// Serializing struct Foo with disabled default ctor
unittest
{
	static struct Foo
	{
		int i;

		@disable
		this();

		this(int i)
		{
			this.i = i;
		}

		static auto deserialize(D)(auto ref D deserializer)
		{
			import asdf : deserialize;

			foreach(elem; deserializer.byKeyValue)
			{
				switch(elem.key)
				{
					case "i":
						int i = elem.value.to!int;
						return typeof(this)(i);
					default:
				}
			}

			return typeof(this).init;
		}
	}

	assert(deserialize!Foo(serializeToAsdf(Foo(6))) == Foo(6));
}

/// ditto
V deserialize(V)(in char[] str)
{
	import asdf.jsonparser: parseJson;
	import std.range: only;
	return str.parseJson.deserialize!V;
}

///
unittest
{
	struct S
	{
		string foo;
		uint bar;
	}

	assert(deserialize!S(`{"foo":"str","bar":4}`) == S("str", 4));
}


/++
Serialization proxy for structs, classes, and enums.

Example: Proxy for types.
----
@serializedAs!ProxyE
enum E
{
	none,
	bar,
}

// const(char)[] doesn't reallocate ASDF data.
@serializedAs!(const(char)[])
struct ProxyE
{
	E e;

	this(E e)
	{
		this.e = e;
	}

	this(in char[] str)
	{
		switch(str)
		{
			case "NONE":
			case "NA":
			case "N/A":
				e = E.none;
				break;
			case "BAR":
			case "BR":
				e = E.bar;
				break;
			default:
				throw new Exception("Unknown: " ~ cast(string)str);
		}
	}

	string toString()
	{
		if (e == E.none)
			return "NONE";
		else
			return "BAR";
	}

	E opCast(T : E)()
	{
		return e;
	}
}

unittest
{
	assert(serializeToJson(E.bar) == `"BAR"`);
	assert(`"N/A"`.deserialize!E == E.none);
	assert(`"NA"`.deserialize!E == E.none);
}
----
+/
struct serializedAs(T){}

/// Proxy for members
unittest
{
	struct S
	{
		// const(char)[] doesn't reallocate ASDF data.
		@serializedAs!(const(char)[])
		uint bar;
	}

	auto json = `{"bar":"4"}`;
	assert(serializeToJson(S(4)) == json);
	assert(deserialize!S(json) == S(4));
}

version(unittest) private
{
	@serializedAs!ProxyE
	enum E
	{
		none,
		bar,
	}

	// const(char)[] doesn't reallocate ASDF data.
	@serializedAs!(const(char)[])
	struct ProxyE
	{
		E e;

		this(E e)
		{
			this.e = e;
		}

		this(in char[] str)
		{
			switch(str)
			{
				case "NONE":
				case "NA":
				case "N/A":
					e = E.none;
					break;
				case "BAR":
				case "BR":
					e = E.bar;
					break;
				default:
					throw new Exception("Unknown: " ~ cast(string)str);
			}
		}

		string toString()
		{
			if (e == E.none)
				return "NONE";
			else
				return "BAR";
		}

		E opCast(T : E)()
		{
			return e;
		}
	}

	unittest
	{
		assert(serializeToJson(E.bar) == `"BAR"`);
		assert(`"N/A"`.deserialize!E == E.none);
		assert(`"NA"`.deserialize!E == E.none);
	}
}

/// Main serialization attribute type
struct Serialization
{
	/// string list
	string[] args;
}

/// Additional serialization attribute type
struct SerializationGroup
{
	/// 2D string list
	string[][] args;
}


/// Returns Serialization with the `args` list.
private Serialization serialization(string[] args...) pure @safe
{
	return Serialization(args.dup);
}

/++
Attribute for key overloading during Serialization and Deserialization.
The first argument overloads the key value during serialization unless `serializationKeyOut` is given.
+/
Serialization serializationKeys(string[] keys...) pure @safe
{
	assert(keys.length, "use @serializationIgnore or at least one key");
	return serialization("keys" ~ keys);
}

///
pure unittest
{
	static struct S
	{
		@serializationKeys("b", "a")
		string s;
	}
	assert(`{"a":"d"}`.deserialize!S.serializeToJson == `{"b":"d"}`);
}

/++
Attribute for key overloading during deserialization.
+/
Serialization serializationKeysIn(string[] keys...) pure @safe
{
	assert(keys.length, "use @serializationIgnoreIn or at least one key");
	return serialization("keys-in" ~ keys);
}

///
pure unittest
{
	static struct S
	{
		@serializationKeysIn("a")
		string s;
	}
	assert(`{"a":"d"}`.deserialize!S.serializeToJson == `{"s":"d"}`);
}

/++
Attribute that force deserialiser to throw an exception that the field was not found in the input.
+/
enum serializationRequired = serialization("required");

///
pure unittest
{
	import std.exception;
	struct S
	{
		@serializationRequired
		string field;
	}
	assert(`{"field":"val"}`.deserialize!S.field == "val");
	assertThrown(`{"other":"val"}`.deserialize!S);
}

/++
Attribute for key overloading during deserialization.

Attention: `serializationMultiKeysIn` is not optimized yet and may significantly slowdown deserialization.
+/
SerializationGroup serializationMultiKeysIn(string[][] keys...) pure @safe
{
	return SerializationGroup(keys.dup);
}

///
unittest
{
	static struct S
	{
		@serializationMultiKeysIn(["a", "b", "c"])
		string s;
	}
	assert(`{"a":{"b":{"c":"d"}}}`.deserialize!S.s == "d");
}

/++
Attribute for key overloading during serialization.
+/
Serialization serializationKeyOut(string key) pure @safe
{
	return serialization("key-out", key);
}

///
unittest
{
	static struct S
	{
		@serializationKeyOut("a")
		string s;
	}
	assert(`{"s":"d"}`.deserialize!S.serializeToJson == `{"a":"d"}`);
}

/++
Attribute to ignore fields.
+/
enum Serialization serializationIgnore = serialization("ignore");

///
unittest
{
	static struct S
	{
		@serializationIgnore
		string s;
	}
	assert(`{"s":"d"}`.deserialize!S.s == null);
	assert(S("d").serializeToJson == `{}`);
}

/++
Attribute to ignore field during deserialization.
+/
enum Serialization serializationIgnoreIn = serialization("ignore-in");

///
unittest
{
	static struct S
	{
		@serializationIgnoreIn
		string s;
	}
	assert(`{"s":"d"}`.deserialize!S.s == null);
	assert(S("d").serializeToJson == `{"s":"d"}`);
}

/++
Attribute to ignore field during serialization.
+/
enum Serialization serializationIgnoreOut = serialization("ignore-out");

///
unittest
{
	static struct S
	{
		@serializationIgnoreOut
		string s;
	}
	assert(`{"s":"d"}`.deserialize!S.s == "d");
	assert(S("d").serializeToJson == `{}`);
}

/++
Can be applied only to strings fields.
Does not allocate new data when deserializeing. Raw ASDF data is used for strings instead of new memory allocation.
Use this attributes only for strings that would not be used after ASDF deallocation.
+/
enum Serialization serializationScoped = serialization("scoped");

///
unittest
{
	import std.uuid;

	static struct S
	{
		@serializationScoped
		@serializedAs!string
		UUID id;
	}
	assert(`{"id":"8AB3060E-2cba-4f23-b74c-b52db3bdfb46"}`.deserialize!S.id
				== UUID("8AB3060E-2cba-4f23-b74c-b52db3bdfb46"));
}

/++
Allows to use flexible deserialization rules the same way like `Asdf.opCast` does.

See_also: $(DUBREF asdf, .Asdf.opCast).
+/
enum Serialization serializationFlexible = serialization("flexible");

///
unittest
{
	import std.uuid;

	static struct S
	{
		@serializationFlexible
		uint a;
	}

	assert(`{"a":"100"}`.deserialize!S.a == 100);
	assert(`{"a":true}`.deserialize!S.a == 1);
	assert(`{"a":null}`.deserialize!S.a == 0);
}

///
unittest
{
	static struct Vector
	{
		@serializationFlexible int x;
		@serializationFlexible int y;
	}

	auto json = `[{"x":"1","y":2},{"x":null, "y": null},{"x":1, "y":2}]`;
	auto decoded = json.deserialize!(Vector[]);
	import std.conv;
	assert(decoded == [Vector(1, 2), Vector(0, 0), Vector(1, 2)], decoded.text);
}

/++
Allows serialize / deserialize fields like arrays.

A range or a container should be iterable for serialization.
Following code should compile:
------
foreach(ref value; yourRangeOrContainer)
{
	...
}
------

`put(value)` method is used for deserialization. 

See_also: $(MREF serializationIgnoreOut), $(MREF serializationIgnoreIn)
+/
enum Serialization serializationLikeArray = serialization("like-array");

///
unittest
{
	import std.range;
	import std.uuid;

	static struct S
	{
		private int count;
		@serializationLikeArray
		auto numbers() @property // uses `foreach`
		{
			return iota(count);
		}

		@serializationLikeArray
		@serializedAs!string // input element type of
		@serializationIgnoreOut
		Appender!(string[]) strings; //`put` method is used
	}

	assert(S(5).serializeToJson == `{"numbers":[0,1,2,3,4]}`);
	assert(`{"strings":["a","b"]}`.deserialize!S.strings.data == ["a","b"]);
}

/++
Allows serialize / deserialize fields like objects.

Object should have `opApply` method to allow serialization.
Following code should compile:
------
foreach(key, value; yourObject)
{
	...
}
------
Object should have only one `opApply` method with 2 argument to allow automatic value type deduction.

`opIndexAssign` or `opIndex` is used for deserialization to support required syntax:
-----
yourObject["key"] = value;
-----
Multiple value types is supported for deserialization.

See_also: $(MREF serializationIgnoreOut), $(MREF serializationIgnoreIn), $(DUBREF asdf, .Asdf.opCast)
+/
enum Serialization serializationLikeObject = serialization("like-object");

///
unittest
{
	static struct M
	{
		private int sum;

		// opApply is used for serialization
		int opApply(int delegate(in char[] key, int val) pure dg) pure
		{
			if(auto r = dg("a", 1)) return r;
			if(auto r = dg("b", 2)) return r;
			if(auto r = dg("c", 3)) return r;
			return 0;
		}

		// opIndexAssign for deserialization
		void opIndexAssign(int val, string key) pure
		{
			sum += val;
		}
	}

	static struct S
	{
		@serializationLikeObject
		@serializedAs!int
		M obj;
	}

	assert(S.init.serializeToJson == `{"obj":{"a":1,"b":2,"c":3}}`);
	assert(`{"obj":{"a":1,"b":2,"c":9}}`.deserialize!S.obj.sum == 12);
}

/++
Attributes for in and out transformations.
Return type of in transformation must be implicitly convertable to the type of the field.
Return type of out transformation may be differ from the type of the field.
In transformation would be applied after serialization proxy if any.
Out transformation would be applied before serialization proxy if any.
+/
struct serializationTransformIn(alias fun)
{
	alias transform = fun;
}

/// ditto
struct serializationTransformOut(alias fun)
{
	alias transform = fun;
}

///
unittest
{
	// global unary function
	static int fin(int i)
	{
		return i + 2;
	}

	static struct S
	{
		@serializationTransformIn!fin
		@serializationTransformOut!`"str".repeat.take(a).joiner("_").to!string`
		int a;
	}

	auto s = deserialize!S(`{"a":3}`);
	assert(s.a == 5);
	assert(serializeToJson(s) == `{"a":"str_str_str_str_str"}`);
}

/// JSON serialization back-end
struct JsonSerializer(string sep, Dg)
{
	import asdf.jsonbuffer;

	static if(sep.length)
	{
		private size_t deep;

		private void putSpace()
		{
			for(auto k = deep; k; k--)
			{
				static if(sep.length == 1)
				{
					sink.put(sep[0]);
				}
				else
				{
					sink.put!sep;
				}
			}
		}
	}


	/// JSON string buffer
	JsonBuffer!Dg sink;

	///
	this(Dg sink)
	{
		this.sink = JsonBuffer!Dg(sink);
	}

	private uint state;

	private void pushState(uint state)
	{
		this.state = state;
	}

	private uint popState()
	{
		auto ret = state;
		state = 0;
		return ret;
	}

	private void incState()
	{
		if(state++)
		{
			static if(sep.length)
			{
				sink.put!",\n";
			}
			else
			{
				sink.put(',');
			}
		}
	}

	/// Serialization primitives
	uint objectBegin()
	{
		static if(sep.length)
		{
			deep++;
			sink.put!"{\n";
		}
		else
		{
			sink.put('{');
		}
		return popState;
	}

	///ditto
	void objectEnd(uint state)
	{
		static if(sep.length)
		{
			deep--;
			sink.put('\n');
			putSpace;
		}
		sink.put('}');
		pushState(state);
	}

	///ditto
	uint arrayBegin()
	{
		static if(sep.length)
		{
			deep++;
			sink.put!"[\n";
		}
		else
		{
			sink.put('[');
		}
		return popState;
	}

	///ditto
	void arrayEnd(uint state)
	{
		static if(sep.length)
		{
			deep--;
			sink.put('\n');
			putSpace;
		}
		sink.put(']');
		pushState(state);
	}

	///ditto
	void putEscapedKey(in char[] key)
	{
		incState;
		static if(sep.length)
		{
			putSpace;
		}
		sink.put('\"');
		sink.putSmallEscaped(key);
		static if(sep.length)
		{
			sink.put!"\": ";
		}
		else
		{
			sink.put!"\":";
		}
	}

	///ditto
	void putKey(in char[] key)
	{
		incState;
		static if(sep.length)
		{
			putSpace;
		}
		sink.put('\"');
		sink.put(key);
		static if(sep.length)
		{
			sink.put!"\": ";
		}
		else
		{
			sink.put!"\":";
		}
	}

	///ditto
	void putNumberValue(Num)(Num num, FormatSpec!char fmt = FormatSpec!char.init)
	{
		auto f = &sink.putSmallEscaped;
		assumePure((typeof(f) fun) => formatValue(fun, num, fmt))(f);
	}

	///ditto
	void putValue(typeof(null))
	{
		sink.put!"null";
	}

	///ditto
	void putValue(bool b)
	{
		if(b)
			sink.put!"true";
		else
			sink.put!"false";
	}

	///ditto
	void putValue(in char[] str)
	{
		sink.put('\"');
		sink.put(str);
		sink.put('\"');
	}

	///ditto
	void putValue(Num)(Num num)
		if (isNumeric!Num && !is(Num == enum))
	{
		putNumberValue(num);
	}

	///ditto
	void elemBegin()
	{
		incState;
		static if(sep.length)
		{
			putSpace;
		}
	}

	///ditto
	void flush()
	{
		sink.flush;
	}
}

/++
Creates JSON serialization back-end.
Use `sep` equal to `"\t"` or `"    "` for pretty formatting.
+/
auto jsonSerializer(string sep = "", Dg)(scope Dg sink)
{
	return JsonSerializer!(sep, Dg)(sink);
}

///
unittest
{
	import std.array;
	import std.bigint;

	auto app = appender!string;
	auto ser = jsonSerializer(&app.put!(const(char)[]));
	auto state0 = ser.objectBegin;

		ser.putEscapedKey("null");
		ser.putValue(null);
	
		ser.putEscapedKey("array");
		auto state1 = ser.arrayBegin();
			ser.elemBegin; ser.putValue(null);
			ser.elemBegin; ser.putValue(123);
			ser.elemBegin; ser.putNumberValue(12300000.123, singleSpec("%.10e"));
			ser.elemBegin; ser.putValue("\t");
			ser.elemBegin; ser.putValue("\r");
			ser.elemBegin; ser.putValue("\n");
			ser.elemBegin; ser.putNumberValue(BigInt("1234567890"));
		ser.arrayEnd(state1);
	
	ser.objectEnd(state0);
	ser.flush;

	assert(app.data == `{"null":null,"array":[null,123,1.2300000123e+07,"\t","\r","\n",1234567890]}`);
}

unittest
{
	import std.array;
	import std.bigint;

	auto app = appender!string;
	auto ser = jsonSerializer!"\t"(&app.put!(const(char)[]));
	auto state0 = ser.objectBegin;

		ser.putEscapedKey("null");
		ser.putValue(null);
	
		ser.putEscapedKey("array");
		auto state1 = ser.arrayBegin();
			ser.elemBegin; ser.putValue(null);
			ser.elemBegin; ser.putValue(123);
			ser.elemBegin; ser.putNumberValue(12300000.123, singleSpec("%.10e"));
			ser.elemBegin; ser.putValue("\t");
			ser.elemBegin; ser.putValue("\r");
			ser.elemBegin; ser.putValue("\n");
			ser.elemBegin; ser.putNumberValue(BigInt("1234567890"));
		ser.arrayEnd(state1);
	
	ser.objectEnd(state0);
	ser.flush;
	
	assert(app.data == 
`{
	"null": null,
	"array": [
		null,
		123,
		1.2300000123e+07,
		"\t",
		"\r",
		"\n",
		1234567890
	]
}`);
}

/// ASDF serialization back-end
struct AsdfSerializer
{
	/// Output buffer
	OutputArray app;

	import asdf.outputarray;
	import asdf.asdf;
	private uint state;

pure:

	/// Serialization primitives
	size_t objectBegin()
	{
		app.put1(Asdf.Kind.object);
		return app.skip(4);
	}

	///ditto
	void objectEnd(size_t state)
	{
		app.put4(cast(uint)(app.shift - state - 4), state);
	}

	///ditto
	size_t arrayBegin()
	{
		app.put1(Asdf.Kind.array);
		return app.skip(4);
	}

	///ditto
	void arrayEnd(size_t state)
	{
		app.put4(cast(uint)(app.shift - state - 4), state);
	}

	///ditto
	alias putEscapedKey = putKey;

	///ditto
	void putKey(in char[] key)
	{
		auto sh = app.skip(1);
		app.put(key);
		app.put1(cast(ubyte)(app.shift - sh - 1), sh);
	}

	///ditto
	void putNumberValue(Num)(Num num, FormatSpec!char fmt = FormatSpec!char.init) pure
	{
		app.put1(Asdf.Kind.number);
		auto sh = app.skip(1);
		assumePure((ref OutputArray app) => formatValue(app, num, fmt))(app);
		app.put1(cast(ubyte)(app.shift - sh - 1), sh);
	}

	///ditto
	void putValue(typeof(null))
	{
		with(Asdf.Kind) app.put1(null_);
	}

	///ditto
	void putValue(bool b)
	{
		with(Asdf.Kind) app.put1(b ? true_ : false_);
	}

	///ditto
	void putValue(in char[] str)
	{
		app.put1(Asdf.Kind.string);
		auto sh = app.skip(4);
		app.put(str);
		app.put4(cast(uint)(app.shift - sh - 4), sh);
	}

	///ditto
	void putValue(Num)(Num num)
		if (isNumeric!Num && !is(Num == enum))
	{
		putNumberValue(num);
	}

	///ditto
	static void elemBegin()
	{
	}

	///ditto
	static void flush()
	{
	}
}

/// Create ASDF serialization back-end
auto asdfSerializer(size_t initialLength = 32)
{
	import asdf.outputarray;
	return AsdfSerializer(OutputArray(initialLength));
}

///
unittest
{
	import std.bigint;

	auto ser = asdfSerializer();
	auto state0 = ser.objectBegin;

		ser.putEscapedKey("null");
		ser.putValue(null);
	
		ser.putKey("array");
		auto state1 = ser.arrayBegin();
			ser.elemBegin; ser.putValue(null);
			ser.elemBegin; ser.putValue(123);
			ser.elemBegin; ser.putNumberValue(12300000.123, singleSpec("%.10e"));
			ser.elemBegin; ser.putValue("\t");
			ser.elemBegin; ser.putValue("\r");
			ser.elemBegin; ser.putValue("\n");
			ser.elemBegin; ser.putNumberValue(BigInt("1234567890"));
		ser.arrayEnd(state1);
	
	ser.objectEnd(state0);

	assert(ser.app.result.to!string == `{"null":null,"array":[null,123,1.2300000123e+07,"\t","\r","\n",1234567890]}`);
}

/// `null` value serialization
void serializeValue(S)(ref S serializer, typeof(null))
{
	serializer.putValue(null);
}

///
unittest
{
	assert(serializeToJson(null) == `null`);
}

/// Number serialization
void serializeValue(S, V)(ref S serializer, in V value, FormatSpec!char fmt = FormatSpec!char.init)
	if((isNumeric!V && !is(V == enum)) || is(V == BigInt))
{
	static if (isFloatingPoint!V)
	{
		import std.math : isNaN, isFinite, signbit;
		
		if (isFinite(value))
			serializer.putNumberValue(value, fmt);
		else if (value.isNaN)
			serializer.putValue(signbit(value) ? "-nan" : "nan");
		else if (value == V.infinity)
			serializer.putValue("inf");
		else if (value == -V.infinity)
			serializer.putValue("-inf");
	}
	else
		serializer.putNumberValue(value, fmt);
}

///
unittest
{
	assert(serializeToJson(BigInt(123)) == `123`);
	assert(serializeToJson(2.40f) == `2.4`);
	assert(serializeToJson(float.nan) == `"nan"`);
	assert(serializeToJson(float.infinity) == `"inf"`);
	assert(serializeToJson(-float.infinity) == `"-inf"`);
}

/// Boolean serialization
void serializeValue(S)(ref S serializer, bool value)
{
	serializer.putValue(value);
}

/// Char serialization
void serializeValue(S)(ref S serializer, char value)
{
	serializer.putValue([value]);
}

///
unittest
{
	assert(serializeToJson(true) == `true`);
}

/// Enum serialization
void serializeValue(S, V)(ref S serializer, in V value)
	if(is(V == enum))
{
	static if (hasSerializedAs!V)
	{
		alias Proxy = getSerializedAs!V;
		serializer.serializeValue(value.to!Proxy);
	}
	else
		serializer.putValue(value.to!string);
}
///
unittest
{
	enum Key { foo }
	assert(serializeToJson(Key.foo) == `"foo"`);
}

/// String serialization
void serializeValue(S)(ref S serializer, in char[] value)
{
	if(value is null)
	{
		serializer.putValue(null);
		return;
	}
	serializer.putValue(value);
}

///
unittest
{
	assert(serializeToJson("\t \" \\") == `"\t \" \\"`);
}

/// Array serialization
void serializeValue(S, T)(ref S serializer, T[] value)
	if(!isSomeChar!T)
{
	if(value is null)
	{
		serializer.putValue(null);
		return;
	}
	auto state = serializer.arrayBegin();
	foreach (ref elem; value)
	{
		serializer.elemBegin;
		serializer.serializeValue(elem);
	}
	serializer.arrayEnd(state);
}

/// Input range serialization
void serializeValue(S, R)(ref S serializer, R value) 
	if ((isInputRange!R) && 
		!isSomeChar!(ElementType!R) && 
		!isDynamicArray!R &&
		!isNullable!R)
{
	auto state = serializer.arrayBegin();
	foreach (ref elem; value)
	{
		serializer.elemBegin;
		serializer.serializeValue(elem);
	}
	serializer.arrayEnd(state);
}

/// input range serialization
unittest
{
	import std.algorithm : filter;

	struct Foo
	{
		int i;
	}

	auto ar = [Foo(1), Foo(3), Foo(4), Foo(17)];
	
	auto filtered1 = ar.filter!"a.i & 1";
	auto filtered2 = ar.filter!"!(a.i & 1)";

	assert(serializeToJson(filtered1) == `[{"i":1},{"i":3},{"i":17}]`);
	assert(serializeToJson(filtered2) == `[{"i":4}]`);
}

///
unittest
{
	uint[2] ar = [1, 2];
	assert(serializeToJson(ar) == `[1,2]`);
	assert(serializeToJson(ar[]) == `[1,2]`);
	assert(serializeToJson(ar[0 .. 0]) == `[]`);
	assert(serializeToJson((uint[]).init) == `null`);
}

/// String-value associative array serialization
void serializeValue(S, T)(ref S serializer, auto ref T[string] value)
{
	if(value is null)
	{
		serializer.putValue(null);
		return;
	}
	auto state = serializer.objectBegin();
	foreach (key, ref val; value)
	{
		serializer.putKey(key);
		serializer.serializeValue(val);
	}
	serializer.objectEnd(state);
}

///
unittest
{
	uint[string] ar = ["a" : 1];
	assert(serializeToJson(ar) == `{"a":1}`);
	ar.remove("a");
	assert(serializeToJson(ar) == `{}`);
	assert(serializeToJson((uint[string]).init) == `null`);
}

/// Enumeration-value associative array serialization
void serializeValue(S, T, K)(ref S serializer, auto ref T[K] value)
	if(is(K == enum))
{
	if(value is null)
	{
		serializer.putValue(null);
		return;
	}
	auto state = serializer.objectBegin();
	foreach (key, ref val; value)
	{
		serializer.putEscapedKey(key.to!string);
		serializer.putValue(val);
	}
	serializer.objectEnd(state);
}

///
unittest
{
	enum E { a, b }
	uint[E] ar = [E.a : 1];
	assert(serializeToJson(ar) == `{"a":1}`);
	ar.remove(E.a);
	assert(serializeToJson(ar) == `{}`);
	assert(serializeToJson((uint[string]).init) == `null`);
}

/// integral typed value associative array serialization
void serializeValue(S, T, K)(ref S serializer, auto ref T[K] value)
	if((isIntegral!K) && !is(K == enum))
{
	if(value is null)
	{
		serializer.putValue(null);
		return;
	}
	char[40] buffer = void;
	auto state = serializer.objectBegin();
	foreach (key, ref val; value)
	{
		import std.format : sformat;
		auto str = sformat(buffer[], "%d", key);
		serializer.putEscapedKey(str);
		.serializeValue(serializer, val);
	}
	serializer.objectEnd(state);
}

///
unittest
{
	uint[short] ar = [256 : 1];
	assert(serializeToJson(ar) == `{"256":1}`);
	ar.remove(256);
	assert(serializeToJson(ar) == `{}`);
	assert(serializeToJson((uint[string]).init) == `null`);
	assert(deserialize!(uint[short])(`{"256":1}`) == cast(uint[short]) [256 : 1]);
}

/// Nullable type serialization
void serializeValue(S, N)(ref S serializer, auto ref N value)
	if (isNullable!N)
{
	if(value.isNull)
	{
		serializer.putValue(null);
		return;
	}
	serializer.serializeValue(value.get);
}

///
unittest
{
	import std.typecons;

	struct Nested
	{
		float f;
	}

	struct T
	{
		string str;
		Nullable!Nested nested;
	}

	T t;
	assert(t.serializeToJson == `{"str":null,"nested":null}`);
	t.str = "txt";
	t.nested = Nested(123);
	assert(t.serializeToJson == `{"str":"txt","nested":{"f":123}}`);
}

/// Struct and class type serialization
void serializeValue(S, V)(ref S serializer, auto ref V value)
	if(!isNullable!V && isAggregateType!V && !is(V : BigInt) && !isInputRange!V)
{
	static if(is(V == class) || is(V == interface))
	{
		if(value is null)
		{
			serializer.putValue(null);
			return;
		}
	}

	static if (hasSerializedAs!V)
	{{
		alias Proxy = getSerializedAs!V;
		serializer.serializeValue(value.to!Proxy);
		return;
	}}
	else
	static if(__traits(hasMember, V, "serialize"))
	{
		value.serialize(serializer);
	}
	else
	{
		auto state = serializer.objectBegin();
		foreach(member; SerializableMembers!value)
		{
			enum udas = [getUDAs!(__traits(getMember, value, member), Serialization)];
			static if(!ignoreOut(udas))
			{
				static if(hasTransformOut!(__traits(getMember, value, member)))
				{
					alias f = unaryFun!(getTransformOut!(__traits(getMember, value, member)));
					auto val = f(__traits(getMember, value, member));
				}
				else
				{
					auto val = __traits(getMember, value, member);
				}

				enum key = keyOut(S.stringof, member, udas);
				serializer.putEscapedKey(key);

				static if(isLikeArray(V.stringof, member, udas))
				{
					alias V = typeof(val);
					static if(is(V == interface) || is(V == class) || is(V : E[], E))
					{
						if(val is null)
						{
							serializer.putValue(null);
							continue;
						}
					}
					auto valState = serializer.arrayBegin();
					foreach (ref elem; val)
					{
						serializer.elemBegin;
						serializer.serializeValue(elem);
					}
					serializer.arrayEnd(valState);
				}
				else
				static if(isLikeObject(V.stringof, member, udas))
				{
					static if(is(V == interface) || is(V == class) || is(V : E[T], E, T))
					{
						if(val is null)
						{
							serializer.putValue(null);
							continue;
						}
					}
					auto valState = serializer.objectBegin();
					foreach (key, elem; val)
					{
						serializer.putKey(key);
						serializer.serializeValue(elem);
					}
					serializer.objectEnd(valState);
				}
				else
				static if(hasSerializedAs!(__traits(getMember, value, member)))
				{
					alias Proxy = getSerializedAs!(__traits(getMember, value, member));
					serializer.serializeValue(val.to!Proxy);
				}
				else
				{
					serializer.serializeValue(val);
				}
			}
		}
		static if(__traits(hasMember, V, "finalizeSerialization"))
		{
			value.finalizeSerialization(serializer);
		}
		serializer.objectEnd(state);
	}
}

unittest
{
	struct S
	{
		void serialize(S)(ref S serializer)
		{
			auto state = serializer.objectBegin;
			serializer.putEscapedKey("foo");
			serializer.putValue("bar");
			serializer.objectEnd(state);
		}
	}
	enum json = `{"foo":"bar"}`;
	assert(serializeToJson(S()) == json);
	assert(serializeToAsdf(S()).to!string == json);
}


/// Deserialize `null` value
void deserializeValue(Asdf data, typeof(null))
{
	auto kind = data.kind;
	if(kind != Asdf.Kind.null_)
		throw new DeserializationException(kind);
}

///
unittest
{
	deserializeValue(serializeToAsdf(null), null);
}

/// Deserialize boolean value
void deserializeValue(Asdf data, ref bool value) pure @safe
{
	auto kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		case false_:
			value = false;
			return;
		case true_:
			value = true;
			return;
		default:
			throw new DeserializationException(kind); 
	}
}

///
pure unittest
{
	assert(deserialize!bool(serializeToAsdf(true)));
	assert(deserialize!bool(serializeToJson(true)));
}

/// Deserialize numeric value
void deserializeValue(V)(Asdf data, ref V value)
	if((isNumeric!V && !is(V == enum)) || is(V == BigInt))
{
	auto kind = data.kind;

	static if (isFloatingPoint!V)
	{
		if (kind == Asdf.Kind.null_)
		{
			value = V.nan;
			return;
		}
		if (kind == Asdf.Kind.string)
		{
			string v;
			.deserializeValue(data, v);
			switch (v)
			{
				case "nan":
					value = V.nan;
					return;
				case "inf":
					value = V.infinity;
					return;
				case "-inf":
					value = -V.infinity;
					return;
				default:
					import std.conv : to;
					value = data.to!V;
			}
			return;
		}
	}

	if(kind != Asdf.Kind.number)
		throw new DeserializationException(kind);
	value = (cast(string) data.data[2 .. $]).to!V;
}

///
unittest
{
	assert(deserialize!ulong (serializeToAsdf(20)) == ulong (20));
	assert(deserialize!ulong (serializeToJson(20)) == ulong (20));
	assert(deserialize!double(serializeToAsdf(20)) == double(20));
	assert(deserialize!double(serializeToJson(20)) == double(20));
	assert(deserialize!BigInt(serializeToAsdf(20)) == BigInt(20));
	assert(deserialize!BigInt(serializeToJson(20)) == BigInt(20));

	assert(deserialize!float (serializeToJson ("2.40")) == float (2.40));
	assert(deserialize!double(serializeToJson ("2.40")) == double(2.40));
	assert(deserialize!double(serializeToAsdf("-2.40")) == double(-2.40));
	
	import std.math : isNaN, isInfinity;
	assert(deserialize!float (serializeToJson  ("nan")).isNaN);
	assert(deserialize!float (serializeToJson  ("inf")).isInfinity);
	assert(deserialize!float (serializeToJson ("-inf")).isInfinity);
}

/// Deserialize enum value
void deserializeValue(V)(Asdf data, ref V value)
	if(is(V == enum))
{
	static if (hasSerializedAs!V)
	{
		alias Proxy = getSerializedAs!V;
		enum udas = [getUDAs!(V, Serialization)];
		Proxy proxy;
		enum F = isFlexible(V.stringof, "this", udas);
		enum S = isScoped(V.stringof, "this", udas) && __traits(compiles, .deserializeScopedString(data, proxy));
		alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
		Fun(data, proxy);
		value = proxy.to!V;
	}
	else
	{
		string s;
		data.deserializeValue(s);
		value = s.to!V;
	}
}

///
unittest
{
	enum Key { foo }
	assert(deserialize!Key(`"foo"`) == Key.foo);
	assert(deserialize!Key(serializeToAsdf("foo")) == Key.foo);
}

/++
Deserializes scoped string value.
This function does not allocate a new string and just make a raw cast of ASDF data.
+/
void deserializeScopedString(V : const(char)[])(Asdf data, ref V value)
{
	auto kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		case string:
			value = cast(V) data.data[5 .. $];
			return;
		case null_:
			value = null;
			return;
		default:
			throw new DeserializationException(kind);
	}
}

/++
Deserializes string value.
This function allocates new string.
+/
void deserializeValue(V)(Asdf data, ref V value)
	if(is(V : const(char)[]) && !is(V == enum))
{
	auto kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		case string:
			value = (() @trusted => cast(V) (data.data[5 .. $]).dup)();
			return;
		case null_:
			value = null;
			return;
		default:
			throw new DeserializationException(kind);
	}
}

/// issue #94/#95
unittest
{
	enum SimpleEnum : string
	{
		se1 = "se1value",
		se2 = "se1value"
	}

	struct Simple
	{
		SimpleEnum en;
	}

	Simple simple = `{"en":"se1"}`.deserialize!(Simple);
}

/// Deserialize single char
void deserializeValue(Asdf data, char value)
{
	auto v = cast(char[1])[value];
	deserializeValue(data, v);
}

///
unittest
{
	assert(deserialize!string(serializeToJson(null)) is null);
	assert(deserialize!string(serializeToAsdf(null)) is null);
	assert(deserialize!string(serializeToJson("\tbar")) == "\tbar");
	assert(deserialize!string(serializeToAsdf("\"bar")) == "\"bar");
}

/// Deserialize array
void deserializeValue(V : T[], T)(Asdf data, ref V value)
	if(!isSomeChar!T && !isStaticArray!V)
{
	const kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		case array:
			import std.algorithm.searching: count;
			auto elems = data.byElement;
			// create array of properly initialized (by means of ctor) elements
			static if (hasStaticTemplatedDeserialize!(T, Asdf))
			{
				// create array of uninitialized elements
				// and initialize them using static `deserialize`

				import std.array : uninitializedArray;
				value = (()@trusted => uninitializedArray!(T[])(elems.save.count))();
				foreach(ref e; value)
				{
					import std.conv: emplace;
					cast(void)(()@trusted => emplace(&e, T.deserialize(elems.front)))();
					if (0) //break safety if deserialize is not not safe
						T.deserialize(elems.front);
					elems.popFront;
				}
			}
			else
			static if (__traits(compiles, {value = new T[elems.save.count];}))
			{
				value = new T[elems.save.count];
				foreach(ref e; value)
				{
					.deserializeValue(elems.front, e);
					elems.popFront;
				}
			}
			else 
				static assert(0, "Type `" ~ T.stringof ~ "` should have either default ctor or static `T.deserialize(R)(R r)` method!");
			assert(elems.empty);
			return;
		case null_:
			value = null;
			return;
		default:
			throw new DeserializationException(kind);
	}
}

///
unittest
{
	assert(deserialize!(int[])(serializeToJson(null)) is null);
	assert(deserialize!(int[])(serializeToAsdf(null)) is null);
	assert(deserialize!(int[])(serializeToJson([1, 3, 4])) == [1, 3, 4]);
	assert(deserialize!(int[])(serializeToAsdf([1, 3, 4])) == [1, 3, 4]);
}

///
unittest
{
	static struct Foo
	{
		int i;

		@disable
		this();

		this(int i)
		{
			this.i = i;
		}

		static auto deserialize(D)(auto ref D deserializer)
		{
			import asdf : deserialize;

			foreach(elem; deserializer.byKeyValue)
			{
				switch(elem.key)
				{
					case "i":
						int i = elem.value.to!int;
						return typeof(this)(i);
					default:
				}
			}

			return typeof(this).init;
		}
	}

	assert(deserialize!(Foo[])(serializeToJson(null)) is null);
	assert(deserialize!(Foo[])(serializeToAsdf(null)) is null);
	assert(deserialize!(Foo[])(serializeToJson([Foo(1), Foo(3), Foo(4)])) == [Foo(1), Foo(3), Foo(4)]);
	assert(deserialize!(Foo[])(serializeToAsdf([Foo(1), Foo(3), Foo(4)])) == [Foo(1), Foo(3), Foo(4)]);
}

/// Deserialize static array
void deserializeValue(V : T[N], T, size_t N)(Asdf data, ref V value)
{
	auto kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		static if(is(T == char))
		{
		case string:
			auto str = cast(immutable(char)[]) data;
			// if source is shorter than destination fill the rest by zeros
			// if source is longer copy only needed part of it
			if (str.length > value.length)
				str = str[0..value.length];
			else
				value[] = '\0';

			import std.algorithm : copy;
			copy(str, value[]);
			return;
		}
		case array:
			auto elems = data.byElement;
			foreach(ref e; value)
			{
				if(elems.empty)
					return;
				.deserializeValue(elems.front, e);
				elems.popFront;
			}
			return;
		case null_:
			return;
		default:
			throw new DeserializationException(kind);
	}
}

///
unittest
{
	assert(deserialize!(int[4])(serializeToJson(null)) == [0, 0, 0, 0]);
	assert(deserialize!(int[4])(serializeToAsdf(null)) == [0, 0, 0, 0]);
	assert(deserialize!(int[4])(serializeToJson([1, 3, 4])) == [1, 3, 4, 0]);
	assert(deserialize!(int[4])(serializeToAsdf([1, 3, 4])) == [1, 3, 4, 0]);
	assert(deserialize!(int[2])(serializeToJson([1, 3, 4])) == [1, 3]);
	assert(deserialize!(int[2])(serializeToAsdf([1, 3, 4])) == [1, 3]);

	assert(deserialize!(char[2])(serializeToAsdf(['a','b'])) == ['a','b']);
	assert(deserialize!(char[2])(serializeToAsdf(['a','\0'])) == ['a','\0']);
	assert(deserialize!(char[2])(serializeToAsdf(['a','\255'])) == ['a','\255']);
	assert(deserialize!(char[2])(serializeToAsdf(['\255'])) == ['\255','\0']);
	assert(deserialize!(char[2])(serializeToAsdf(['\255', '\255', '\255'])) == ['\255','\255']);
}

/// AA with value of aggregate type
unittest
{
	struct Foo
	{
		
	}

	assert (deserialize!(Foo[int])(serializeToJson([1: Foo()])) == [1:Foo()]);
}

/// Deserialize string-value associative array
void deserializeValue(V : T[string], T)(Asdf data, ref V value)
{
	auto kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		case object:
			foreach(elem; data.byKeyValue)
			{
				T v;
				.deserializeValue(elem.value, v);
				value[elem.key.idup] = v;
			}
			return;
		case null_:
			value = null;
			return;
		default:
			throw new DeserializationException(kind);
	}
}

///
unittest
{
	assert(deserialize!(int[string])(serializeToJson(null)) is null);
	assert(deserialize!(int[string])(serializeToAsdf(null)) is null);
	assert(deserialize!(int[string])(serializeToJson(["a" : 1, "b" : 2])) == ["a" : 1, "b" : 2]);
	assert(deserialize!(int[string])(serializeToAsdf(["a" : 1, "b" : 2])) == ["a" : 1, "b" : 2]);
}

unittest
{
	int[string] r = ["a" : 1];
	serializeToAsdf(null).deserializeValue(r);
	assert(r is null);
}

/// Deserialize enumeration-value associative array
void deserializeValue(V : T[E], T, E)(Asdf data, ref V value)
	if(is(E == enum))
{
	auto kind = data.kind;
	with(Asdf.Kind) switch(kind)
	{
		case object:
			foreach(elem; data.byKeyValue)
			{
				T v;
				.deserializeValue(elem.value, v);
				value[elem.key.to!E] = v;
			}
			return;
		case null_:
			value = null;
			return;
		default:
			throw new DeserializationException(kind);
	}
}

///
unittest
{
	enum E {a, b}
	assert(deserialize!(int[E])(serializeToJson(null)) is null);
	assert(deserialize!(int[E])(serializeToAsdf(null)) is null);
	assert(deserialize!(int[E])(serializeToJson([E.a : 1, E.b : 2])) == [E.a : 1, E.b : 2]);
	assert(deserialize!(int[E])(serializeToAsdf([E.a : 1, E.b : 2])) == [E.a : 1, E.b : 2]);
}

unittest
{
	enum E {a, b}
	int[E] r = [E.a : 1];
	serializeToAsdf(null).deserializeValue(r);
	assert(r is null);
}

/// Deserialize associative array with integral type key
void deserializeValue(V : T[K], T, K)(Asdf data, ref V value)
    if((isIntegral!K) && !is(K == enum))
{
    auto kind = data.kind;
    with(Asdf.Kind) switch(kind)
    {
        case object:
            foreach(elem; data.byKeyValue)
            {
                T v;
                .deserializeValue(elem.value, v);
                value[elem.key.to!K] = v;
            }
            return;
        case null_:
            value = null;
            return;
        default:
            throw new DeserializationException(kind);
    }
}

///
unittest
{
	assert(deserialize!(int[int])(serializeToJson(null)) is null);
	assert(deserialize!(int[int])(serializeToAsdf(null)) is null);
	assert(deserialize!(int[int])(serializeToJson([2 : 1, 40 : 2])) == [2 : 1, 40 : 2]);
	assert(deserialize!(int[int])(serializeToAsdf([2 : 1, 40 : 2])) == [2 : 1, 40 : 2]);
}

unittest
{
	int[int] r = [3 : 1];
	serializeToAsdf(null).deserializeValue(r);
	assert(r is null);
}

/// Deserialize Nullable value
void deserializeValue(V)(Asdf data, ref V value)
	if(isNullable!V)
{
	if (data.kind == Asdf.Kind.null_)
	{
		value.nullify;
		return;
	}

	typeof(value.get) payload;
	.deserializeValue(data, payload);
	value = payload;
}

///
unittest
{
	import std.typecons;

	struct Nested
	{
		float f;
	}

	struct T
	{
		string str;
		Nullable!Nested nested;
	}

	T t;
	assert(deserialize!T(`{"str":null,"nested":null}`) == t);
	t.str = "txt";
	t.nested = Nested(123);
	assert(deserialize!T(`{"str":"txt","nested":{"f":123}}`) == t);
}

private static void Flex(V)(Asdf a, ref V v) { v = a.to!V; }

/// Deserialize aggregate value
void deserializeValue(V)(Asdf data, ref V value)
	if(!isNullable!V && isAggregateType!V && !is(V : BigInt))
{
	static if (hasSerializedAs!V)
	{{
		alias Proxy = getSerializedAs!V;
		enum udas = [getUDAs!(V, Serialization)];
		Proxy proxy;
		enum F = isFlexible(V.stringof, "this", udas);
		enum S = isScoped(V.stringof, "this", udas) && __traits(compiles, .deserializeScopedString(data, proxy));
		alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
		Fun(data, proxy);
		value = proxy.to!V;
		return;
	}}
	else
	static if (__traits(hasMember, V, "deserialize"))
	{
		value = V.deserialize(data);
	}
	else try
	{
		auto kind = data.kind;
		if(kind != Asdf.Kind.object)
		{
			throw new DeserializationException(kind);
		}

		static if(is(V == class) || is(V == interface))
		{
			if(value is null)
			{
				static if(__traits(compiles, value = new V))
				{
					value = new V;
				}
				else
				{
					throw new DeserializationException(data.kind, "Object / interface must not be null");
				}
			}
		}

		struct RequiredFlags
		{
			static foreach(member; DeserializableMembers!value)
				static if (hasRequired([getUDAs!(__traits(getMember, value, member), Serialization)]))
					mixin ("bool " ~ member ~ ";");
		}

		RequiredFlags requiredFlags;
		foreach(elem; data.byKeyValue)
		{
			switch(elem.key)
			{
				foreach(member; DeserializableMembers!value)
				{
						enum udas = [getUDAs!(__traits(getMember, value, member), Serialization)];
						enum F = isFlexible(V.stringof, member, udas);
						static if(!ignoreIn(udas))
						{
							enum keys = keysIn(V.stringof, member, udas);
							foreach (key; aliasSeqOf!keys)
							{
				case key:

							}
							static if (hasRequired(udas))
								__traits(getMember, requiredFlags, member) = true;

							static if(!isReadableAndWritable!(value, member))
							{
								alias Type = Unqual!(Parameters!(__traits(getMember, value, member)));
							}
							else
							{
								alias Type = typeof(__traits(getMember, value, member));
							}

							static if(isLikeArray(V.stringof, member, udas))
							{
								static assert(hasSerializedAs!(__traits(getMember, value, member)), V.stringof ~ "." ~ member ~ " should have a Proxy type for deserialization");
								alias Proxy = getSerializedAs!(__traits(getMember, value, member));
								Proxy proxy;
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, proxy));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
								foreach(v; elem.value.byElement)
								{
									proxy = proxy.init;
									Fun(v, proxy);
									__traits(getMember, value, member).put(proxy);
								}
							}
							else
							static if(isLikeObject(V.stringof, member, udas))
							{
								static assert(hasSerializedAs!(__traits(getMember, value, member)), V.stringof ~ "." ~ member ~ " should have a Proxy type for deserialization");
								alias Proxy = getSerializedAs!(__traits(getMember, value, member));
								Proxy proxy;
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, proxy));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
								foreach(v; elem.value.byKeyValue)
								{
									proxy = proxy.init;
									Fun(v.value, proxy);
									__traits(getMember, value, member)[elem.key.idup] = proxy;
								}
							}
							else
							static if(hasSerializedAs!(__traits(getMember, value, member)))
							{
								alias Proxy = getSerializedAs!(__traits(getMember, value, member));
								Proxy proxy;
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, proxy));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));

								Fun(elem.value, proxy);
								__traits(getMember, value, member) = proxy.to!Type;
							}
							else
							static if(isReadableAndWritable!(value, member) && __traits(compiles, {auto ptr = &__traits(getMember, value, member); }))
							{
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, __traits(getMember, value, member)));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));

								Fun(elem.value, __traits(getMember, value, member));
							}
							else
							{
								Type val;

								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, val));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));

								Fun(elem.value, val);
								__traits(getMember, value, member) = val;
							}

							static if(hasTransformIn!(__traits(getMember, value, member)))
							{
								alias f = unaryFun!(getTransformIn!(__traits(getMember, value, member)));
								__traits(getMember, value, member) = f(__traits(getMember, value, member));
							}

					break;

						}
				}
				default:
			}
		}
		foreach(member; DeserializableMembers!value)
		try {
			enum udas = [getUDAs!(__traits(getMember, value, member), Serialization)];
			enum F = isFlexible(V.stringof, member, udas);
			static if(!ignoreIn(udas))
			{
				enum target = [getUDAs!(__traits(getMember, value, member), SerializationGroup)];
				static if(target.length)
				{
					static assert(target.length == 1, member ~ ": only one @serializationKeysIn(string[][]...) is allowed.");
					foreach(ser; target[0].args)
					{
						auto d = data[ser];
						if(d.data.length)
						{
							static if (hasRequired(udas))
								__traits(getMember, requiredFlags, member) = true;
							static if(!isReadableAndWritable!(value, member))
							{
								alias Type = Parameters!(__traits(getMember, value, member));
							}
							else
							{
								alias Type = typeof(__traits(getMember, value, member));
							}
							static if(isLikeArray(V.stringof, member, udas))
							{
								static assert(hasSerializedAs!(__traits(getMember, value, member)), V.stringof ~ "." ~ member ~ " should have a Proxy type for deserialization");
								alias Proxy = getSerializedAs!(__traits(getMember, value, member));
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, proxy));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
								foreach(v; elem.value.byElement)
								{
									Proxy proxy;
									Fun(v, proxy);
									__traits(getMember, value, member).put(proxy);
								}
							}
							else
							static if(isLikeObject(V.stringof, member, udas))
							{
								static assert(hasSerializedAs!(__traits(getMember, value, member)), V.stringof ~ "." ~ member ~ " should have a Proxy type for deserialization");
								alias Proxy = getSerializedAs!(__traits(getMember, value, member));
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(elem.value, proxy));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
								foreach(v; elem.value.byKeyValue)
								{
									Proxy proxy;
									Fun(v.value, proxy);
									__traits(getMember, value, member)[elem.key.idup] = proxy;
								}
							}
							else
							static if(hasSerializedAs!(__traits(getMember, value, member)))
							{
								alias Proxy = getSerializedAs!(__traits(getMember, value, member));
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(d, proxy));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));
						
								Proxy proxy;
								Fun(d, proxy);
								__traits(getMember, value, member) = proxy.to!Type;
							}
							else
							static if(isReadableAndWritable!(value, member) && __traits(compiles, {auto ptr = &__traits(getMember, value, member); }))
							{
								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(d, __traits(getMember, value, member)));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));

								Fun(d, __traits(getMember, value, member));
							}
							else
							{
								Type val;

								enum S = isScoped(V.stringof, member, udas) && __traits(compiles, .deserializeScopedString(d, val));
								alias Fun = Select!(F, Flex, Select!(S, .deserializeScopedString, .deserializeValue));

								Fun(elem.value, val);
								__traits(getMember, value, member) = val;
							}

							static if(hasTransformIn!(__traits(getMember, value, member)))
							{
								alias f = unaryFun!(getTransformIn!(__traits(getMember, value, member)));
								__traits(getMember, value, member) = f(__traits(getMember, value, member));
							}
						}
					}
				}
			}
		}
		catch (AsdfException e)
		{
			throw new DeserializationException(Asdf.Kind.object, "Failed to deserialise member" ~ member, e);
		}

		foreach(member; __traits(allMembers, RequiredFlags))
		{
			if (!__traits(getMember, requiredFlags, member))
				throw () { 
					static immutable exc = new AsdfException(
				"ASDF deserialisation: Required member '" ~ member ~ "' in " ~ V.stringof ~ " is missing.");
					return exc;
				} ();
		}

		static if(__traits(hasMember, V, "finalizeDeserialization"))
		{
			value.finalizeDeserialization(data);
		}
	}
	catch (AsdfException e)
	{
		throw new DeserializationException(Asdf.Kind.object, "Failed to deserialise type " ~ V.stringof, e);
	}
}

private enum bool isSerializedAs(A) = is(A : serializedAs!T, T);
private enum bool isSerializedAs(alias a) = false;

unittest
{
	static assert(isSerializedAs!(serializedAs!string));
	static assert(!isSerializedAs!(string));
}

private enum bool isTransformIn(A) = is(A : serializationTransformIn!fun, alias fun);
private enum bool isTransformIn(alias a) = false;

unittest
{
	static assert(isTransformIn!(serializationTransformIn!"a * 2"));
	static assert(!isTransformIn!(string));
}

private enum bool isTransformOut(A) = is(A : serializationTransformOut!fun, alias fun);
private enum bool isTransformOut(alias a) = false;

unittest
{
	static assert(isTransformOut!(serializationTransformOut!"a * 2"));
	static assert(!isTransformIn!(string));
}

private alias ProxyList(alias value) = staticMap!(getSerializedAs, Filter!(isSerializedAs, __traits(getAttributes, value)));
private alias TransformInList(alias value) = staticMap!(getTransformIn, Filter!(isTransformIn, __traits(getAttributes, value)));
private alias TransformOutList(alias value) = staticMap!(getTransformOut, Filter!(isTransformOut, __traits(getAttributes, value)));

alias aliasThis(alias value) = value;

private template hasSerializedAs(alias value)
{
	private enum _listLength = ProxyList!(value).length;
	static assert(_listLength <= 1, `Only single serialization proxy is allowed`);
	enum bool hasSerializedAs = _listLength == 1;
}

private template hasTransformIn(alias value)
{
	private enum _listLength = TransformInList!(value).length;
	static assert(_listLength <= 1, `Only single input transformation is allowed`);
	enum bool hasTransformIn = _listLength == 1;
}

private template hasTransformOut(alias value)
{
	private enum _listLength = TransformOutList!(value).length;
	static assert(_listLength <= 1, `Only single output transformation is allowed`);
	enum bool hasTransformOut = _listLength == 1;
}

unittest
{
	@serializedAs!string uint bar;
	uint foo;
	static assert(hasSerializedAs!bar);
	static assert(!hasSerializedAs!foo);
}

private alias getSerializedAs(T : serializedAs!Proxy, Proxy) = Proxy;
private alias getTransformIn(T) = T.transform;
private alias getTransformOut(T) = T.transform;

private template getSerializedAs(alias value)
{
	private alias _list = ProxyList!value;
	static assert(_list.length <= 1, `Only single serialization proxy is allowed`);
	alias getSerializedAs = _list[0];
}

private template getTransformIn(alias value)
{
	private alias _list = TransformInList!value;
	static assert(_list.length <= 1, `Only single input transformation is allowed`);
	alias getTransformIn = _list[0];
}

private template getTransformOut(alias value)
{
	private alias _list = TransformOutList!value;
	static assert(_list.length <= 1, `Only single output transformation is allowed`);
	alias getTransformOut = _list[0];
}

private bool isFlexible(string type, string member, Serialization[] attrs)
{
	import std.algorithm.searching: canFind, find, startsWith, count;
	alias pred = unaryFun!(a => a.args[0] == "flexible");
	auto c = attrs.count!pred;
	if(c == 0)
		return false;
	if(c == 1)
		return true;
	throw new Exception(type ~ "." ~ member ~
		` : Only single declaration of "flexible" serialization attribute is allowed`);
}

private bool isLikeArray(string type, string member, Serialization[] attrs)
{
	import std.algorithm.searching: canFind, find, startsWith, count;
	alias pred = unaryFun!(a => a.args[0] == "like-array");
	auto c = attrs.count!pred;
	if(c == 0)
		return false;
	if(c == 1)
		return true;
	throw new Exception(type ~ "." ~ member ~
		` : Only single declaration of "like-array" serialization attribute is allowed`);
}

private bool isLikeObject(string type, string member, Serialization[] attrs)
{
	import std.algorithm.searching: canFind, find, startsWith, count;
	alias pred = unaryFun!(a => a.args[0] == "like-object");
	auto c = attrs.count!pred;
	if(c == 0)
		return false;
	if(c == 1)
		return true;
	throw new Exception(type ~ "." ~ member ~
		` : Only single declaration of "like-object" serialization attribute is allowed`);
}


private bool isScoped(string type, string member, Serialization[] attrs)
{
	import std.algorithm.searching: canFind, find, startsWith, count;
	alias pred = unaryFun!(a => a.args[0] == "scoped");
	auto c = attrs.count!pred;
	if(c == 0)
		return false;
	if(c == 1)
		return true;
	throw new Exception(type ~ "." ~ member ~
		` : Only single declaration of "scoped" / "scoped-in" serialization attribute is allowed`);
}

private string keyOut(string type, string member, Serialization[] attrs)
{
	import std.algorithm.searching: canFind, find, startsWith, count;
	alias pred = unaryFun!(a =>
			a.args[0] == "keys"
			||
			a.args[0] == "key-out"
			);
	auto c = attrs.count!pred;
	if(c == 0)
		return member;
	if(c == 1)
		return attrs.find!pred.front.args[1];
	throw new Exception(type ~ "." ~ member ~
		` : Only single declaration of "keys" / "key-out" serialization attribute is allowed`);
}

private string[] keysIn(string type, string member, Serialization[] attrs)
{
	import std.algorithm.searching: canFind, find, startsWith, count;
	alias pred = unaryFun!(a =>
			a.args[0] == "keys"
			||
			a.args[0] == "keys-in"
			);
	auto c = attrs.count!pred;
	if(c == 0)
		return [member];
	if(c == 1)
		return attrs.find!pred.front.args[1 .. $];
	throw new Exception(type ~ "." ~ member ~
		` : Only single declaration of "keys" / "keys-in" serialization attribute is allowed`);
}

private bool ignoreOut()(Serialization[] attrs)
{
	import std.algorithm.searching: canFind;
	return attrs.canFind!(a => 
			a.args == ["ignore"]
			||
			a.args == ["ignore-out"]
			);
}

private bool ignoreIn()(Serialization[] attrs)
{
	import std.algorithm.searching: canFind;
	return attrs.canFind!(a => 
			a.args == ["ignore"]
			||
			a.args == ["ignore-in"]
			);
}

private bool hasRequired()(Serialization[] attrs)
{
	import std.algorithm.searching: canFind;
	return attrs.canFind!(a => a.args == ["required"]);
}

private bool privateOrPackage()(string protection)
{
	return protection == "private" || protection == "package";
}

/**
 * Converts an input range $(D range) to an alias sequence.
 */
private template aliasSeqOf(alias range)
{
	import std.traits : isArray, isNarrowString;

	alias ArrT = typeof(range);
	static if (isArray!ArrT && !isNarrowString!ArrT)
	{
		static if (range.length == 0)
		{
			alias aliasSeqOf = AliasSeq!();
		}
		else static if (range.length == 1)
		{
			alias aliasSeqOf = AliasSeq!(range[0]);
		}
		else
		{
			alias aliasSeqOf = AliasSeq!(aliasSeqOf!(range[0 .. $/2]), aliasSeqOf!(range[$/2 .. $]));
		}
	}
	else
	{
		import std.range.primitives : isInputRange;
		static if (isInputRange!ArrT)
		{
			import std.array : array;
			alias aliasSeqOf = aliasSeqOf!(array(range));
		}
		else
		{
			static assert(false, "Cannot transform range of type " ~ ArrT.stringof ~ " into a AliasSeq.");
		}
	}
}

private template isNullable(T)
{
	import std.traits : hasMember;

	static if (
		hasMember!(T, "isNull") &&
		is(typeof(__traits(getMember, T, "isNull")) == bool) &&
		hasMember!(T, "get") &&
		!is(typeof(__traits(getMember, T, "get")) == void) &&
		hasMember!(T, "nullify") &&
		is(typeof(__traits(getMember, T, "nullify")) == void)
	)
	{
		enum isNullable = true;
	}
	else
	{
		enum isNullable = false;
	}
}

// check if the member is readable/writeble?
private enum isReadableAndWritable(alias aggregate, string member) = __traits(compiles, __traits(getMember, aggregate, member) = __traits(getMember, aggregate, member));
private enum isPublic(alias aggregate, string member) = !__traits(getProtection, __traits(getMember, aggregate, member)).privateOrPackage;

// check if the member is property
private template isProperty(alias aggregate, string member)
{
	static if(isSomeFunction!(__traits(getMember, aggregate, member)))
		enum isProperty = (functionAttributes!(__traits(getMember, aggregate, member)) & FunctionAttribute.property);
	else
		enum isProperty = false;
}
// check if the member is readable
private enum isReadable(alias aggregate, string member) = __traits(compiles, { auto _val = __traits(getMember, aggregate, member); });

// This trait defines what members should be serialized -
// public members that are either readable and writable or getter properties
private template Serializable(alias value, string member)
{
	static if (!isPublic!(value, member))
		enum Serializable = false;
	else
	static if (isReadableAndWritable!(value, member))
		enum Serializable = true;
	else
	static if (isReadable!(value, member))
		enum Serializable = isProperty!(value, member); // a readable property is getter
	else
		enum Serializable = false;
}

/// returns alias sequence, members of which are members of value
/// that should be processed
private template SerializableMembers(alias value)
{
	import std.meta : ApplyLeft, Filter;
	alias AllMembers = AliasSeq!(__traits(allMembers, typeof(value)));
	alias isProper = ApplyLeft!(Serializable, value);
	alias SerializableMembers = Filter!(isProper, AllMembers);
}

// This trait defines what members should be serialized -
// public members that are either readable and writable or setter properties
private template Deserializable(alias value, string member)
{
	static if (!isPublic!(value, member))
		enum Deserializable = false;
	else
	static if (isReadableAndWritable!(value, member))
		enum Deserializable = true;
	else
	static if (isProperty!(value, member))
		// property that has one argument is setter(?)
		enum Deserializable = Parameters!(__traits(getMember, value, member)).length == 1;
	else
		enum Deserializable = false;
}

private template DeserializableMembers(alias value)
{
	import std.meta : ApplyLeft, Filter;
	alias AllMembers = AliasSeq!(__traits(allMembers, typeof(value)));
	alias isProper = ApplyLeft!(Deserializable, value);
	alias DeserializableMembers = Filter!(isProper, AllMembers);
}
