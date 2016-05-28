// This file lists D routines required for coding UVM
//
//------------------------------------------------------------------------------
// Copyright 2012-2014 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------------------------
module uvm.meta.misc;

import esdl.base.core: Event, Process, NamedComp;
import esdl.data.queue: Queue;
// This file lists D routines required for coding UVM

import std.traits: isNumeric;

static string declareEnums (alias E)()
{
  import std.traits;
  import std.conv;
  string res;

  foreach(e; __traits(allMembers, E))
    {
      res ~= "enum " ~ E.stringof ~ " " ~ e ~ " = " ~
	E.stringof ~ "." ~ e ~ ";\n";
    }
  return res;
}

// These two functions are useful for packer functionality
// these functions are required for conversion between float/double to
// byte array and vice versa
auto toBytes(T) (T t)
{
  union U {
    T _t;
    ubyte[T.sizeof] _b;
  }

  U u;
  u._t = t;
  return u._b;
}

T bytesTo(T, size_t C) (ubyte[C] b)
{
  union U {
    T _t;
    ubyte[T.sizeof] _b;
  }
  static assert(C == T.sizeof);
  U u;
  u._b = b;
  return u._t;
}

class QueueWithEvent(T)
{
  import esdl.data.queue;
  import esdl.base.core;

  Queue!T _queue;
  alias _queue this;
  Event _event;

  void pushFront(T...)(T values) {
    synchronized(this) {
      _queue.pushFront(values);
      _event.notify();
    }
  }
  void pushBack(T...)(T values) {
    synchronized(this) {
      _queue.pushBack(values);
      _event.notify();
    }
  }

  void removeFront(const size_t numToPop = 1) {
    synchronized(this) {
      _queue.removeFront(numToPop);
      _event.notify();
    }
  }
  void removeBack(const size_t numToPop = 1) {
    synchronized(this) {
      _queue.removeBack(numToPop);
      _event.notify();
    }
  }
  T opIndexAssign(T val, size_t key) {
    synchronized(this) {
      _queue[key] = val;
      _event.notify();
      return val;
    }
  }
  // FIXME
  // insert and remove not covered

  void wait() {
    _event.wait();
  }

  this() {
    synchronized(this) {
      _event.init("_event", Process.self);
    }
  }

}

class AssocWithEvent(K, V)
{
  import esdl.base.core;
  // trigger the event whenever a call is made to add, modify or
  // remove an element

  // We require to overload opIndexAssign and remove and assign operators

  V[K] _assoc;
  Event _event;

  alias _assoc this;

  V opIndexAssign(V val, K key) {
    synchronized(this) {
      _assoc[key] = val;
      _event.notify();
      return val;
    }
  }

  void remove(K key) {
    synchronized(this) {
      _assoc.remove(key);
      _event.notify();
    }
  }

  void wait() {
    _event.wait();
  }

  this() {
    _event.init("_event", Process.self);
  }
}

unittest {
  import esdl.base.core;
  QueueWithEvent!int q = new QueueWithEvent!int;
  AssocWithEvent!(int,int) a = new AssocWithEvent!(int,int);
}

class WithEvent(T) {
  T _val;
  Event _event;

  this(T val, NamedComp parent=null) {
    synchronized(this) {
      if(parent is null) {
	parent = Process.self;
      }
      assert(parent !is null);
      _event.init("_event", parent);
      _val = val;
    }
  }

  this(NamedComp parent=null) {
    synchronized(this) {
      if(parent is null) {
	parent = Process.self;
      }
      assert(parent !is null);
      _event.init("_event", parent);
    }
  }

  // void init() {
  //   _event.init(Process.self);
  // }

  T get() {
    synchronized(this) {
      return _val;
    }
  }

  alias get this;

  T opAssign(T val) {
    synchronized(this) {
      _val = val;
      _event.notify();
      return val;
    }
  }

  T set(T val) {
    synchronized(this) {
      _val = val;
      _event.notify();
      return val;
    }
  }

  void opOpAssign(string op)(T val) {
    synchronized(this) {
      _val.opOpAssign!op(val);
      _event.notify();
    }
  }

  int opCmp(T)(T other) {
    synchronized(this) {
      static if(is(T == class)) {
	return _val.opCmp(other);
      }
      else {
	if(_val < other) return -1;
	else if(_val > other) return 1;
	else return 0;
      }
    }
  }

  int opEquals(T)(T other) {
    synchronized(this) {
      return _val == other;
    }
  }

  Event getEvent() {
    synchronized(this) {
      return _event;
    }
  }

  Event defaultEvent() {
    synchronized(this) {
      return _event;
    }
  }

  void wait() {
    _event.wait();
  }

  void notify() {
    _event.notify();
  }

  auto opBinary(string op, V)(V other) {
    static if(is(V: WithEvent!U, U)) {
      return mixin("get() " ~ op ~ " other.get()");
    }
    else {
      return mixin("get() " ~ op ~ " other");
    }
  }
  
  auto opBinaryRight(string op, V)(V other) {
    static if(is(V: WithEvent!U, U)) {
      return mixin("other.get() " ~ op ~ " get()");
    }
    else {
      return mixin("other " ~ op ~ " get()");
    }
  }
  
  static if(isNumeric!T) {
    T opUnary(string S)() if(S == "++") {
      synchronized(this) {
	_event.notify();
	return ++_val;
      }
    }
    T opUnary(string S)() if(S == "--") {
      synchronized(this) {
	_event.notify();
	return --_val;
      }
    }
  }

}

class uvm_wrap_obj(T) {
  T _wrapped_obj;
  alias _wrapped_obj this;
  final bool isNull() {
    static if(is(T unused: Object)) {
      if(_wrapped_obj is null) return true;
      else return false;
    }
    else return false;
  }
}

enum uvm_none_sync;		// no wrapper
enum uvm_private_sync;
enum uvm_public_sync;
enum uvm_protected_sync;
enum uvm_immutable_sync;
enum uvm_package_sync;



// This one is used to mark the variables that need synchronization
template uvm_sync_access(size_t I=0, A...) {
  static if(I == A.length) {
    enum string uvm_sync_access = "";
  }
  else static if(is(A[I] == uvm_none_sync)) {
      enum string uvm_sync_access = "none";
    }
  else static if(is(A[I] == uvm_private_sync)) {
      enum string uvm_sync_access = "private";
    }
  else static if(is(A[I] == uvm_package_sync)) {
      enum string uvm_sync_access = "package";
    }
  else static if(is(A[I] == uvm_protected_sync)) {
      enum string uvm_sync_access = "protected";
    }
  else static if(is(A[I] == uvm_immutable_sync)) {
      enum string uvm_sync_access = "immutable";
    }
  else static if(is(A[I] == uvm_public_sync)) {
      enum string uvm_sync_access = "public";
    }
    else {
      enum string uvm_sync_access = uvm_sync_access!(I+1, A);
    }
} 

mixin template uvm_sync() {
  mixin(uvm_sync_string!(typeof(this)));
}

string uvm_sync_string() {
  return "mixin(uvm_sync_string!(typeof(this)));\n";
}

template uvm_sync_string(T, string U="this", size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_sync_string = "";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "this" || mem == "once" || mem == "_once") {
      // exclude "this" in nested classes
      enum string uvm_sync_string =
	uvm_sync_string!(T, U, ITER+1);
    }
    else {
      enum string uvm_sync_string =
	"mixin(uvm_sync_string!(\"" ~ T.stringof ~ "\", uvm_sync_access!(0, __traits(getAttributes, "
	~ U ~ "." ~ mem ~ ")),  \"" ~ mem ~ "\", \"" ~ U ~ "\"));
        " ~
	uvm_sync_string!(T, U, ITER+1);
    }
  }
}

template uvm_check_sync(string C, string A, string M, string U) {
  enum string F = U ~ "." ~ M;
  static if(M == "__ctor" || (M.length > 6 && M[0..6] == "_esdl_")) {
    enum string uvm_check_sync = "";
  }
  else {
    static if(M[0] is '_') {
      enum string uvm_check_sync =
	"pragma(msg, \"" ~ C ~ "\" ~ \"::\" ~ typeid(typeof(" ~ F ~
	")).stringof[7..$-1] ~ \"-> \" ~ \"" ~ A ~ ":  " ~ U ~ "." ~
	M ~ "\");\n";
    }
    else {
      enum string uvm_check_sync =
	"static if(__traits(compiles, " ~ F ~
	".offsetof)) { pragma(msg, typeid(typeof(this)).stringof ~ " ~
	"\"-> \" ~ \"" ~ A ~ "\" ~ \":  " ~ U ~ "." ~ M ~ "\"); }\n";
    }
  }
}

template uvm_sync_string(string C, string A, string M, string U) {
  static if(U == "_once" || U == "once") enum string SCOPE = "static";
  else enum string SCOPE = "";
  debug(UVM_SYNC_LIST) {
    enum string uvm_sync_check = uvm_check_sync!(C, A, M, U);
  }
  else {
    enum string uvm_sync_check = "";
  }
  static if(A == "" || A == "none") {
    enum string uvm_sync_string = uvm_sync_check;
  }
  else static if(A == "immutable") {
      static assert(M[0] is '_', "uvm_" ~ A ~ "_sync variable " ~ M ~
		    " does not have '_' prefix");
      enum string uvm_sync_string = uvm_sync_check ~
	SCOPE ~ " final auto " ~ M[1..$] ~
	"()() {return " ~ U ~ "." ~ M ~ ";}\n" ~
	SCOPE ~ " final void " ~ M[1..$] ~
	// since the object is immutable, allow only assigns to the
	// encapsulated object -- like opAssign defined on the object
	// object being wrapped here -- note that the is expression is
	// negated with !
	"(T)(T val) if(! is(T: typeof(" ~ U ~ "." ~ M ~ "))) { " ~
	U ~ "." ~ M ~ " = val;}\n";
    }
    else {
      static assert(M[0] is '_', "uvm_" ~ A ~ "_sync variable " ~ M ~
		    " does not have '_' prefix");
      enum string uvm_sync_string = uvm_sync_check ~ A ~ " " ~ SCOPE ~
	" final auto " ~ M[1..$] ~ "() {synchronized(" ~ U ~ ") return " ~
	U ~ "." ~ M ~ ";}\n" ~ A ~ " " ~ SCOPE ~ " final void " ~ M[1..$] ~
	"(typeof(" ~ U ~ "." ~ M ~ ") val) {synchronized(" ~ U ~ ") " ~
	U ~ "." ~ M ~ " = val;}\n";
    }
}

mixin template uvm_once_sync() {
  // pragma(msg, uvm_once_sync_string!(uvm_once, typeof(this)));
  mixin(uvm_once_sync_string!(uvm_once, typeof(this)));
}

string uvm_once_sync_string() {
  return "mixin(uvm_once_sync_string!(uvm_once));\n";
}

// template uvm_once_sync_string() {
//   enum string uvm_once_sync_string =
//     "mixin(uvm_once_sync_string!(uvm_once, typeof(this)));\n";
// }

template uvm_once_sync_string(T, size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_once_sync_string = "static uvm_once once() {\n" ~
      "  return uvm_once.get_instance!uvm_once;\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"once\"));\n";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_once_sync_string = uvm_once_sync_string!(T, ITER+1);
    }
    else {
      enum string uvm_once_sync_string =
	uvm_once_sync_string!(T, ITER+1) ~
	"static if(uvm_sync_access!(0, __traits(getAttributes, " ~
	T.stringof ~ "." ~ mem ~ ")) != \"none\") {\n" ~
	"  static private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"    return once." ~ mem ~ ";\n    }\n  }\n";
    }
  }
}

template uvm_once_sync_string(T, U, size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_once_sync_string = "static uvm_once once() {\n" ~
      "  import uvm.base.uvm_root;\n" ~
      "  auto root = uvm_entity_base.get();\n" ~
      "  return root.root_once._" ~ U.stringof ~ "_once;\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"once\"));\n";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_once_sync_string = uvm_once_sync_string!(T, U, ITER+1);
    }
    else {
      enum string uvm_once_sync_string =
	uvm_once_sync_string!(T, U, ITER+1) ~
	"static if(uvm_sync_access!(0, __traits(getAttributes, " ~
	T.stringof ~ "." ~ mem ~ ")) != \"none\") {\n" ~
	"  static private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"    return once." ~ mem ~ ";\n    }\n  }\n";
    }
  }
}

template uvm_once_sync_string(T, string _inst, size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_once_sync_string = T.stringof ~ " " ~
      _inst ~ "_uvm_once() {\n" ~
      "  return " ~ T.stringof ~ ".get_instance!" ~ T.stringof ~ ";\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"" ~ _inst ~ "_uvm_once\"));\n";
      }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_once_sync_string = uvm_once_sync_string!(T, _inst, ITER+1);
    }
    else {
      enum string uvm_once_sync_string = uvm_once_sync_string!(T, _inst, ITER+1) ~
	"private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"  return " ~ _inst ~ "_uvm_once." ~ mem ~ ";\n  }\n";
    }
  }
}
