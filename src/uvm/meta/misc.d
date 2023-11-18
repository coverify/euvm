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

import esdl.base.core: Event, Process, NamedComp, EntityIntf;
import esdl.data.queue: Queue;
// This file lists D routines required for coding UVM

import std.traits: isNumeric, BaseClassesTuple;
import std.typetuple: staticIndexOf;

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

  this(string name) {
    synchronized(this) {
      _event.initialize(name, EntityIntf.getContextParent);
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

  this(string name) {
    _event.initialize(name, EntityIntf.getContextParent);
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

  this(string name, T val, NamedComp parent=null) {
    synchronized(this) {
      if (parent is null) {
	parent = EntityIntf.getContextParent();
      }
      assert (parent !is null);
      _event.initialize(name, parent);
      _val = val;
    }
  }

  this(string name, NamedComp parent=null) {
    synchronized(this) {
      if (parent is null) {
	parent = EntityIntf.getContextParent();
      }
      assert(parent !is null);
      _event.initialize(name, parent);
    }
  }

  // void initialize() {
  //   _event.initialize(EntityIntf.getContextParent);
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
enum uvm_void_sync;		// no wrapper -- except for once wrapper
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
  else static if(is(A[I] == uvm_void_sync)) {
      enum string uvm_sync_access = "void";
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

template uvm_sync_access_sym(alias U, string M) {
  alias MEM = __traits(getMember, U, M);
  static if (__traits(getOverloads, U, M, true).length != 0) {
    enum string uvm_sync_access_sym =
      uvm_sync_access!(0, __traits(getAttributes, __traits(getOverloads, U, M, true)[0]));
  }
  else {
    enum string uvm_sync_access_sym =
      uvm_sync_access!(0, __traits(getAttributes, MEM));
  }
}

// template uvm_sync_access_sym(alias U) {
//   static if (__traits(isVirtualFunction, U) ||
// 	     __traits(isFinalFunction, U) ||
// 	     __traits(isStaticFunction, U)) {
//     enum string uvm_sync_access_sym = "";
//   }
//   else {
//     enum string uvm_sync_access_sym =
//       uvm_sync_access!(0, __traits(getAttributes, U));
//   }
// }

mixin template uvm_lock() {
  mixin(uvm_lock_string!(typeof(this)));
}

string uvm_lock_string() {
  return "mixin(uvm_lock_string!(typeof(this)));\n";
}

template uvm_lock_string(T, string U="this", size_t ITER=0) {
  // static if(ITER == 0) pragma(msg, "// " ~ T.stringof);
  static if(ITER == (T.tupleof).length) {
    enum string uvm_lock_string = "";
  }
  else {
    enum string mem = (T.tupleof[ITER].stringof);
    static if(mem == "this" || mem == "uvm_scope_inst" || mem == "_uvm_scope_inst") {
      // exclude "this" in nested classes
      enum string uvm_lock_string =
	uvm_lock_string!(T, U, ITER+1);
    }
    else static if (mem.length > 7 && mem[0..7] == "_esdl__") {
      enum string uvm_lock_string =
	uvm_lock_string!(T, U, ITER+1);
    }
    else {
      // pragma(msg, "// " ~ mem);
      enum string access = uvm_sync_access!(0, __traits(getAttributes, T.tupleof[ITER]));
      static if (access == "" || access == "none") {
	enum string uvm_lock_string =
	  uvm_lock_string!(T, U, ITER+1);
      }
      else {
	enum string mstr = uvm_sync_string_alt!(T, typeof(T.tupleof[ITER]), access,  mem, U);
	// pragma(msg, mstr);
	enum string uvm_lock_string = mstr ~ uvm_lock_string!(T, U, ITER+1);
      }
    }
  }
}

mixin template uvm_sync() {
  mixin(uvm_sync_string!(typeof(this)));
}

string uvm_sync_string() {
  return "mixin(uvm_sync_string!(typeof(this)));\n";
}

template uvm_sync_string(T, size_t ITER=0) {
  // static if (ITER == 0) pragma(msg, "// " ~ T.stringof);
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_sync_string = "";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "this" || mem == "uvm_scope_inst" || mem == "_uvm_scope_inst") {
      // exclude "this" in nested classes
      enum string uvm_sync_string = uvm_sync_string!(T, ITER+1);
    }
    else static if (mem.length > 7 && mem[0..7] == "_esdl__") {
      enum string uvm_sync_string = uvm_sync_string!(T, ITER+1);
    }
    else {
      enum string uvm_sync_string =
	"mixin(uvm_sync_string!(\"" ~ T.stringof ~ "\", uvm_sync_access_sym!(typeof(this), \""
	~ mem ~ "\"),  \"" ~ mem ~ "\", \"this\"));
        " ~
	uvm_sync_string!(T, ITER+1);
    }
  }
}

template uvm_sync_string(T, string U, size_t ITER=0) {
  // static if (ITER == 0) pragma(msg, "// " ~ T.stringof);
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_sync_string = "";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "this" || mem == "uvm_scope_inst" || mem == "_uvm_scope_inst") {
      // exclude "this" in nested classes
      enum string uvm_sync_string = uvm_sync_string!(T, U, ITER+1);
    }
    else static if (mem.length > 7 && mem[0..7] == "_esdl__") {
      enum string uvm_sync_string = uvm_sync_string!(T, U, ITER+1);
    }
    else {
      enum string uvm_sync_string =
	"mixin(uvm_sync_string!(\"" ~ T.stringof ~ "\", uvm_sync_access_sym!("
	~ U ~ ", \"" ~ mem ~ "\"),  \"" ~ mem ~ "\", \"" ~ U ~ "\"));
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
  static if(U == "_uvm_scope_inst" || U == "uvm_scope_inst") enum string SCOPE = "static";
  else enum string SCOPE = "";
  debug(UVM_SYNC_LIST) {
    enum string uvm_sync_check = uvm_check_sync!(C, A, M, U);
  }
  else {
    enum string uvm_sync_check = "";
  }
  static if(A == "" || A == "none" || A == "void") {
    enum string uvm_sync_string = uvm_sync_check;
  }
  else static if(A == "immutable") {
    static assert(M[0] is '_', "uvm_" ~ A ~ "_sync variable " ~ M ~
		  " does not have '_' prefix");
    enum string mstr = uvm_sync_check ~
      SCOPE ~ " final auto " ~ M[1..$] ~
      "()() {return " ~ U ~ "." ~ M ~ ";}\n" ~
      SCOPE ~ " final void " ~ M[1..$] ~
      // since the object is immutable, allow only assigns to the
      // encapsulated object -- like opAssign defined on the object
      // object being wrapped here -- note that the is expression is
      // negated with !
      "(T)(T val) if(! is(T: typeof(" ~ U ~ "." ~ M ~ "))) { " ~
      U ~ "." ~ M ~ " = val;}\n";
    // pragma(msg, mstr);
    // static if (U != "this") {
    //   enum string uvm_sync_string = mstr ~
    // 	SCOPE ~ " final auto " ~ M[1..$] ~
    //   "()(uvm_entity_base entity) {return " ~ U ~ "(entity)." ~ M ~ ";}\n";
    // }
    // else {
    enum string uvm_sync_string = mstr;
    // }
  }
  else {
    static assert(M[0] is '_', "uvm_" ~ A ~ "_sync variable " ~ M ~
		  " does not have '_' prefix");
    enum string mstr = uvm_sync_check ~ A ~ " " ~ SCOPE ~
      " final auto " ~ M[1..$] ~ "() {synchronized(" ~ U ~ ") return " ~
      U ~ "." ~ M ~ ";}\n" ~ A ~ " " ~ SCOPE ~ " final void " ~ M[1..$] ~
      "(typeof(" ~ U ~ "." ~ M ~ ") val) {synchronized(" ~ U ~ ") " ~
      U ~ "." ~ M ~ " = val;}\n";
    // static if (U != "this") {
    //   enum string uvm_sync_string = mstr ~ // "// " ~ A ~ " " ~ M[1..$] ~ '\n';
    // 	SCOPE ~ " final auto " ~ M[1..$] ~
    // 	"()(uvm_entity_base entity) {synchronized("~ U ~
    // 	"(entity)) return " ~ U ~ "(entity)." ~ M ~ ";}\n" ~
    // 	A ~ " " ~ SCOPE ~ " final void " ~ M[1..$] ~
    // 	"(uvm_entity_base entity, typeof(" ~ U ~ "." ~ M ~
    // 	") val) {synchronized(" ~ U ~ "(entity)) " ~
    // 	U ~ "(entity)." ~ M ~ " = val;}\n";
    // }
    // else {
    // pragma(msg, mstr);
    enum string uvm_sync_string = mstr;
    // }
  }
  // pragma(msg, uvm_sync_string);
}

template uvm_sync_string_alt(T, TM, string A, string M, string U) {
  enum TMSTR = TM.stringof;
  static if(U == "_uvm_scope_inst" || U == "uvm_scope_inst") enum string SCOPE = "static";
  else enum string SCOPE = "";
  debug(UVM_SYNC_LIST) {
    enum string uvm_sync_check = uvm_check_sync!(C, A, M, U);
  }
  else {
    enum string uvm_sync_check = "";
  }
  static if(A == "" || A == "none" || A == "void") {
    enum string uvm_sync_string_alt = uvm_sync_check;
  }
  else static if(A == "immutable") {
    static assert(M[0] is '_', "uvm_" ~ A ~ "_sync variable " ~ M ~
		  " does not have '_' prefix");
    enum string uvm_sync_string_alt = uvm_sync_check ~
      SCOPE ~ " final auto " ~ M[1..$] ~
      "()() {return " ~ U ~ "." ~ M ~ ";}\n" ~
      SCOPE ~ " final void " ~ M[1..$] ~
      // since the object is effectively immutable, allow only assigns
      // to the encapsulated object -- like opAssign defined on the
      // object being wrapped here -- note that the is expression is
      // negated with !
      "(T)(T val) if(! is(T: " ~ TMSTR ~ ")) { " ~
      U ~ "." ~ M ~ " = val;}\n";
  }
  else {
    static assert(M[0] is '_', "uvm_" ~ A ~ "_sync variable " ~ M ~
		  " does not have '_' prefix");
    enum string uvm_sync_string_alt = uvm_sync_check ~ A ~ " " ~ SCOPE ~
      " final auto " ~ M[1..$] ~ "() {synchronized(" ~ U ~ ") return " ~
      U ~ "." ~ M ~ ";}\n" ~ A ~ " " ~ SCOPE ~ " final void " ~ M[1..$] ~
      "(" ~ TMSTR ~ " val) {synchronized(" ~ U ~ ") " ~
      U ~ "." ~ M ~ " = val;}\n";
  }
}

mixin template uvm_scope_sync() {
  // pragma(msg, uvm_scope_sync_string!(uvm_scope, typeof(this)));
  mixin(uvm_scope_sync_string!(uvm_scope, typeof(this)));
}

string uvm_scope_sync_string() {
  return "mixin(uvm_scope_sync_string!(uvm_scope));\n";
}

// template uvm_scope_sync_string() {
//   enum string uvm_scope_sync_string =
//     "mixin(uvm_scope_sync_string!(uvm_scope, typeof(this)));\n";
// }

template uvm_scope_sync_string(T, size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_scope_sync_string = // "import uvm.base.uvm_entity: uvm_entity_base;\n" ~
      "static " ~ T.stringof ~ " _uvm_scope_inst() {\n" ~
      "  return " ~ T.stringof ~ ".get_instance!" ~ T.stringof ~ ";\n}\n" ~
      // "static " ~ T.stringof ~ " _uvm_scope_inst(uvm_entity_base entity) {\n" ~
      // "  return " ~ T.stringof ~ ".get_instance!" ~ T.stringof ~ "(entity);\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"_uvm_scope_inst\"));\n";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_scope_sync_string = uvm_scope_sync_string!(T, ITER+1);
    }
    else {
      enum string uvm_scope_sync_string =
	uvm_scope_sync_string!(T, ITER+1) ~
	"static if (uvm_sync_access_sym!("
	~ T.stringof ~ ", \"" ~ mem ~ "\") != \"none\") {\n" ~
	"  static private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"    return _uvm_scope_inst." ~ mem ~ ";\n  }\n}\n";
    }
  }
  // pragma(msg, uvm_scope_sync_string);
}

template uvm_scope_sync_string(T, U, size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_scope_sync_string = // "import uvm.base.uvm_entity: uvm_entity_base;\n" ~
      "static uvm_scope _uvm_scope_inst() {\n" ~
      "  import uvm.base.uvm_entity: uvm_entity_base;\n" ~
      "  uvm_entity_base entity = uvm_entity_base.get();\n" ~
      "  return entity.root_scope._" ~ U.stringof ~ "_scope;\n}\n" ~
      // "static uvm_scope _uvm_scope_inst(uvm_entity_base entity) {\n" ~
      // "  return entity.root_scope._" ~ U.stringof ~ "_scope;\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"_uvm_scope_inst\"));\n";
  }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_scope_sync_string = uvm_scope_sync_string!(T, U, ITER+1);
    }
    else {
      enum string uvm_scope_sync_string =
	uvm_scope_sync_string!(T, U, ITER+1) ~
	"static if (uvm_sync_access_sym!("
	~ T.stringof ~ ", \"" ~ mem ~ "\") != \"none\") {\n" ~
	"  static private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"    return _uvm_scope_inst." ~ mem ~ ";\n    }\n  }\n";
    }
  }
}

template uvm_scope_sync_string(T, string _inst, size_t ITER=0) {
  static if(ITER == (__traits(derivedMembers, T).length)) {
    enum string uvm_scope_sync_string =
      "import uvm.base.uvm_entity: uvm_entity_base;\n" ~
      T.stringof ~ " " ~ _inst ~ "_uvm_scope() {\n" ~
      "  return " ~ T.stringof ~ ".get_instance!" ~ T.stringof ~ ";\n}\n" ~
      // T.stringof ~ " " ~ _inst ~ "_uvm_scope(uvm_entity_base entity) {\n" ~
      // "  return " ~ T.stringof ~ ".get_instance!" ~ T.stringof ~ "(entity);\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"" ~ _inst ~ "_uvm_scope\"));\n";
      }
  else {
    enum string mem = __traits(derivedMembers, T)[ITER];
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_scope_sync_string = uvm_scope_sync_string!(T, _inst, ITER+1);
    }
    else {
      enum string uvm_scope_sync_string = uvm_scope_sync_string!(T, _inst, ITER+1) ~
	"private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"  return " ~ _inst ~ "_uvm_scope." ~ mem ~ ";\n  }\n";
    }
  }
}

string uvm_scope_lock_string() {
  return "mixin(uvm_scope_lock_string!(uvm_scope));\n";
}

template uvm_scope_lock_string(T, size_t ITER=0) {
  static if(ITER == (T.tupleof).length) {
    enum string uvm_scope_lock_string = "static uvm_scope _uvm_scope_inst() {\n" ~
      "  return uvm_scope.get_instance!uvm_scope;\n}\n" ~
      "static uvm_scope _uvm_scope_inst(uvm_entity_base entity) {\n" ~
      "  return uvm_scope.get_instance!uvm_scope;\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"_uvm_scope_inst\"));\n";
  }
  else {
    enum string mem = (T.tupleof[ITER]).stringof;
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_scope_lock_string = uvm_scope_lock_string!(T, ITER+1);
    }
    else {
      enum string uvm_scope_lock_string =
	uvm_scope_lock_string!(T, ITER+1) ~
	"static if(uvm_sync_access!(0, __traits(getAttributes, " ~
	T.stringof ~ "." ~ mem ~ ")) != \"none\") {\n" ~
	"  static private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"    return _uvm_scope_inst." ~ mem ~ ";\n    }\n  }\n";
    }
  }
}

template uvm_scope_lock_string(T, U, size_t ITER=0) {
  static if(ITER == T.tupleof.length) {
    enum string uvm_scope_lock_string = "static uvm_scope _uvm_scope_inst() {\n" ~
      // "  import uvm.base.uvm_root;\n" ~
      "  uvm_entity_base entity = uvm_entity_base.get();\n" ~
      "  return entity.root_scope._" ~ U.stringof ~ "_scope;\n}\n" ~
      "static uvm_scope _uvm_scope_inst(uvm_entity_base entity) {\n" ~
      // "  import uvm.base.uvm_root;\n" ~
      "  return entity.root_scope._" ~ U.stringof ~ "_scope;\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"_uvm_scope_inst\"));\n";
  }
  else {
    enum string mem = (T.tupleof[ITER]).stringof;
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_scope_lock_string = uvm_scope_lock_string!(T, U, ITER+1);
    }
    else {
      enum string uvm_scope_lock_string =
	uvm_scope_lock_string!(T, U, ITER+1) ~
	"static if(uvm_sync_access!(0, __traits(getAttributes, " ~
	T.stringof ~ "." ~ mem ~ ")) != \"none\") {\n" ~
	"  static private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"    return _uvm_scope_inst." ~ mem ~ ";\n    }\n  }\n";
    }
  }
}

template uvm_scope_lock_string(T, string _inst, size_t ITER=0) {
  static if(ITER == T.tupleof.length) {
    enum string uvm_scope_lock_string = T.stringof ~ " " ~
      _inst ~ "_uvm_scope() {\n" ~
      "  return " ~ T.stringof ~ ".get_instance!" ~ T.stringof ~ ";\n}\n" ~
      "mixin(uvm_sync_string!(" ~ T.stringof ~ ", \"" ~ _inst ~ "_uvm_scope\"));\n";
      }
  else {
    enum string mem = (T.tupleof[ITER]).stringof;
    static if(mem == "__ctor" || mem == "__dtor") {
      enum string uvm_scope_lock_string = uvm_scope_lock_string!(T, _inst, ITER+1);
    }
    else {
      enum string uvm_scope_lock_string = uvm_scope_lock_string!(T, _inst, ITER+1) ~
	"private ref " ~ " auto " ~ " " ~ mem ~ "() {\n" ~
	"  return " ~ _inst ~ "_uvm_scope." ~ mem ~ ";\n  }\n";
    }
  }
}

template BitCount(V)
{
  static if (isBoolean!V) enum ulong BitCount = 1;
  static if (isIntegral!V) enum ulong BitCount = cast(uint) V.sizeof * 8;
  static if (isBitVector!V) enum ulong BitCount = cast(uint) V.SIZE;
  else static assert (false,
		      "BitCount is defined for Integral and BitVector types only");
}

uint bitCount(V)(V v) {
  return BitCount!V;
}

bool inside(T)(T t, T[] args ...) {
  foreach (arg; args) if (t == arg) return true;
  return false;
}

extern (C) Object _d_newclass(TypeInfo_Class ci);

T staticCast(T, F)(const F from)
  // if (is (F == class) && is (T == class)
  //    // make sure that F is indeed amongst the base classes of T
  //    && staticIndexOf!(F, BaseClassesTuple!T) != -1
  //    )
     in {
       // assert statement will not be compiled for production release
       assert((from is null) || cast(T)from !is null);
     }
do {
  return cast(T) cast(void*) from;
 }


// Object dup(Object obj) {
//   if (obj is null) return null;
//   ClassInfo ci = obj.classinfo;
//   Object clone = _d_newclass(ci);
//   size_t start = Object.classinfo.init.length;
//   size_t end   = ci.init.length;
//   (cast(void*) clone)[start..end] = (cast(void*) obj)[start..end];
//   return clone;
// }

T shallowCopy(T)(T obj) if (is (T == class)) {
  if (obj is null) return null;
  ClassInfo ci = obj.classinfo;
  Object clone = _d_newclass(ci);
  size_t start = Object.classinfo.m_init.length;
  size_t end   = ci.m_init.length;
  (cast(void*) clone)[start..end] = (cast(void*) obj)[start..end];
  return staticCast!T(clone);
}

T shallowCopy(T, Allocator)(T obj, auto ref Allocator alloc)
if (is (T == class)) {
  import std.algorithm: max;
  // import std.experimental.allocator.common: stateSize;
  import std.format: format;
  if (obj is null) return null;
  ClassInfo ci = obj.classinfo;
  auto init = ci.initializer;
  // auto m = alloc.allocate(max(stateSize!T, 1)); // as in std.allocator.make
  auto m = alloc.allocate(init.length); // as in _d_newclass
  if (!m.ptr) return null;
  assert (m.length == init.length, format("m.length(%s) != init.length(%s)",
					  m.length, init.length));
  m[0 .. $] = init[];
  Object clone = cast(Object) m.ptr;
  size_t start = Object.classinfo.m_init.length;
  size_t end   = ci.m_init.length;
  (cast(void*) clone)[0..end] = (cast(void*) obj)[0..end];
  return staticCast!T(clone);
 }
