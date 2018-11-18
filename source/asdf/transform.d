/++
Mutable ASDF data structure.
The representation can be used to compute a difference between JSON object-trees.

Copyright: Tamedia Digital, 2016

Authors: Ilya Yaroshenko

License: BSL-1.0
+/
module asdf.transform;

import asdf.asdf;
import asdf.serialization;

/++
Object-tree structure for mutable Asdf representation.

`AsdfNode` can be used to construct and manipulate JSON objects.
Each `AsdfNode` can represent either a dynamic JSON object (associative array of `AsdfNode` nodes) or a ASDF JSON value.
JSON arrays can be represented only as JSON values.
+/
struct AsdfNode
{
	/++
	Children nodes.
	+/
	AsdfNode[const(char)[]] children;
	/++
	Leaf data.
	+/
	Asdf data;

pure:

	/++
	Returns `true` if the node is leaf.
	+/
	bool isLeaf() const @safe pure nothrow @nogc
	{
		return cast(bool) data.data.length;
	}

	/++
	Construct `AsdfNode` recursively.
	+/
	this(Asdf data)
	{
		if(data.kind == Asdf.Kind.object)
		{
			foreach(kv; data.byKeyValue)
			{
				children[kv.key] = AsdfNode(kv.value);
			}
		}
		else
		{
			this.data = data;
			assert(isLeaf);
		}
	}

	///
	ref AsdfNode opIndex(scope const(char)[][] keys...) scope return
	{
		if(keys.length == 0)
			return this;
		auto ret = this;
		for(;;)
		{
			auto ptr = keys[0] in ret.children;
			assert(ptr, "AsdfNode.opIndex: keys do not exist");
			keys = keys[1 .. $];
			if(keys.length == 0)
				return *ptr;
			ret = *ptr;
		}
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto root = AsdfNode(text.parseJson);
		assert(root["inner", "a"].data == `true`.parseJson);
	}

	///
	void opIndexAssign(AsdfNode value, scope const(char)[][] keys...)
	{
		auto root = &this;
		foreach(key; keys)
		{
			L:
			auto ptr = key in root.children;
			if(ptr)
			{
				assert(ptr, "AsdfNode.opIndex: keys do not exist");
				keys = keys[1 .. $];
				root = ptr;
			}
			else
			{
				root.children[keys[0]] = AsdfNode.init;
				goto L;
			}
		}
		*root = value;
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto root = AsdfNode(text.parseJson);
		auto value = AsdfNode(`true`.parseJson);
		root["inner", "g", "u"] = value;
		assert(root["inner", "g", "u"].data == true);
	}

	/++
	Params:
		value = default value
		keys = list of keys
	Returns: `[keys]` if any and `value` othervise.
	+/
	AsdfNode get(AsdfNode value, in char[][] keys...)
	{
		auto ret = this;
		foreach(key; keys)
			if(auto ptr = key in ret.children)
				ret = *ptr;
			else
			{
				ret = value;
				break;
			}
		return ret;
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto root = AsdfNode(text.parseJson);
		auto value = AsdfNode(`false`.parseJson);
		assert(root.get(value, "inner", "a").data == true);
		assert(root.get(value, "inner", "f").data == false);
	}

	/// Serialization primitive
	void serialize(ref AsdfSerializer serializer)
	{
		if(isLeaf)
		{
			assert(isLeaf, "AsdfNode.serialize: Asdf leaf is empty");
			serializer.app.put(cast(const(char)[])data.data);
			return;
		}
		auto state = serializer.objectBegin;
		foreach(key, ref value; children)
		{
			serializer.putKey(key);
			value.serialize(serializer);
		}
		serializer.objectEnd(state);
	}

	///
	Asdf opCast(T : Asdf)()
	{
		return serializeToAsdf(this);
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto root = AsdfNode(text.parseJson);
		import std.stdio;
		Asdf flat = cast(Asdf) root;
		assert(flat["inner", "a"] == true);
	}

	///
	bool opEquals(in AsdfNode rhs) const @safe pure nothrow @nogc
	{
		if(isLeaf)
			if(rhs.isLeaf)
				return data == rhs.data;
			else
				return false;
		else
			if(rhs.isLeaf)
				return false;
			else
				return children == rhs.children;
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto root1 = AsdfNode(text.parseJson);
		auto root2= AsdfNode(text.parseJson);
		assert(root1 == root2);
		assert(root1["inner"].children.remove("b"));
		assert(root1 != root2);
	}

	/// Adds data to the object-tree recursively.
	void add(Asdf data)
	{
		if(data.kind == Asdf.Kind.object)
		{
			this.data = Asdf.init;
			foreach(kv; data.byKeyValue)
			{
				if(auto nodePtr = kv.key in children)
				{
					nodePtr.add(kv.value);
				}
				else
				{
					children[kv.key] = AsdfNode(kv.value);
				}
			}
		}
		else
		{
			this.data = data;
			children = null;
		}
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto addition = `{"do":"re","inner":{"a":false,"u":2}}`;
		auto root = AsdfNode(text.parseJson);
		root.add(addition.parseJson);
		auto result = `{"do":"re","foo":"bar","inner":{"a":false,"u":2,"b":false,"c":"32323","d":null,"e":{}}}`;
		assert(root == AsdfNode(result.parseJson));
	}

	/// Removes keys from the object-tree recursively.
	void remove(Asdf data)
	{
		import std.exception: enforce;
		enforce(children, "AsdfNode.remove: asdf data must be a sub-tree");
		foreach(kv; data.byKeyValue)
		{
			if(kv.value.kind == Asdf.Kind.object)
			{
				if(auto nodePtr = kv.key in children)
				{
					nodePtr.remove(kv.value);
				}
			}
			else
			{
				children.remove(kv.key);
			}
		}
	}

	///
	unittest
	{
		import asdf;
		auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto rem = `{"do":null,"foo":null,"inner":{"c":null,"e":null}}`;
		auto root = AsdfNode(text.parseJson);
		root.remove(rem.parseJson);
		auto result = `{"inner":{"a":true,"b":false,"d":null}}`;
		assert(root == AsdfNode(result.parseJson));
	}

	private void removedImpl(ref AsdfSerializer serializer, AsdfNode node)
	{
		import std.exception : enforce;
		enforce(!isLeaf);
		enforce(!node.isLeaf);
		auto state = serializer.objectBegin;
		foreach(key, ref value; children)
		{
			auto nodePtr = key in node.children;
			if(nodePtr && *nodePtr == value)
				continue;
			serializer.putKey(key);
			if(nodePtr && !nodePtr.isLeaf && !value.isLeaf)
				value.removedImpl(serializer, *nodePtr);
			else
				serializer.putValue(null);
 		}
		serializer.objectEnd(state);
	}

	/++
	Returns the subset of the object-tree which is not represented in `node`.
	If a leaf is represented but has a different value then it will be included
	in the return value.
	Returned value has ASDF format and its leaves are set to `null`.
	+/
	Asdf removed(AsdfNode node)
	{
		auto serializer = asdfSerializer();
		removedImpl(serializer, node);
		serializer.flush;
		return serializer.app.result;
	}

	///
	unittest
	{
		import asdf;
		auto text1 = `{"inner":{"a":true,"b":false,"d":null}}`;
		auto text2 = `{"foo":"bar","inner":{"a":false,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto node1 = AsdfNode(text1.parseJson);
		auto node2 = AsdfNode(text2.parseJson);
		auto diff = AsdfNode(node2.removed(node1));
		assert(diff == AsdfNode(`{"foo":null,"inner":{"a":null,"c":null,"e":null}}`.parseJson));
	}

	void addedImpl(ref AsdfSerializer serializer, AsdfNode node)
	{
		import std.exception : enforce;
		enforce(!isLeaf);
		enforce(!node.isLeaf);
		auto state = serializer.objectBegin;
		foreach(key, ref value; node.children)
		{
			auto nodePtr = key in children;
			if(nodePtr && *nodePtr == value)
				continue;
			serializer.putKey(key);
			if(nodePtr && !nodePtr.isLeaf && !value.isLeaf)
				nodePtr.addedImpl(serializer, value);
			else
				value.serialize(serializer);
 		}
		serializer.objectEnd(state);
	}

	/++
	Returns the subset of the node which is not represented in the object-tree.
	If a leaf is represented but has a different value then it will be included
	in the return value.
	Returned value has ASDF format.
	+/
	Asdf added(AsdfNode node)
	{
		auto serializer = asdfSerializer();
		addedImpl(serializer, node);
		serializer.flush;
		return serializer.app.result;
	}

	///
	unittest
	{
		import asdf;
		auto text1 = `{"foo":"bar","inner":{"a":false,"b":false,"c":"32323","d":null,"e":{}}}`;
		auto text2 = `{"inner":{"a":true,"b":false,"d":null}}`;
		auto node1 = AsdfNode(text1.parseJson);
		auto node2 = AsdfNode(text2.parseJson);
		auto diff = AsdfNode(node2.added(node1));
		assert(diff == AsdfNode(`{"foo":"bar","inner":{"a":false,"c":"32323","e":{}}}`.parseJson));
	}
}
