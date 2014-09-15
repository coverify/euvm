//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
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

module uvm.base.uvm_object_defines;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_root: uvm_root;
import uvm.base.uvm_registry: uvm_component_registry;
import uvm.base.uvm_factory: uvm_object_wrapper;
import uvm.seq.uvm_sequence_item: uvm_sequence_item;
import uvm.seq.uvm_sequence_base: uvm_sequence_base;
import uvm.base.uvm_object_globals;

public string uvm_object_utils_string()() {
  return "mixin uvm_object_utils!(typeof(this));";
}

mixin template uvm_object_utils(T=void)
{
  static if(is(T == void)) {
    alias typeof(this) U;
  }
  else {
    alias T U;
  }
  mixin uvm_object_registry_mixin!(U, __MODULE__ ~ "." ~ U.stringof);
  mixin m_uvm_object_create_func!(U);
  mixin m_uvm_get_type_name_func!(U);
  mixin m_uvm_field_auto_utils!(U);
  mixin Randomization;
  // `uvm_field_utils_begin(U)
}


// mixin template uvm_object_param_utils(T=void)
// {
//   static if(is(T == void)) {
//     alias typeof(this) U;
//   }
//   else {
//     alias T U;
//   }
//   mixin m_uvm_object_registry_param!(U);
//   mixin m_uvm_object_create_func!(U);
//   // `uvm_field_utils_begin(U)
// }

string uvm_component_utils_string()() {
  return "mixin uvm_component_utils!(typeof(this));";
}

mixin template uvm_component_utils(T=void)
{
  static if(is(T == void)) {
    alias typeof(this) U;
  }
  else {
    alias T U;
  }
  static if(! is(U: uvm_root)) { // do not register uvm_roots with factory
    mixin uvm_component_registry_mixin!(U, U.stringof);
  }
  mixin m_uvm_get_type_name_func!(U);
  mixin uvm_component_auto_build_mixin;
}

mixin template uvm_component_auto_build_mixin()
{
  // overriding function that calls the generic function for automatic
  // object construction
  override void _uvm__auto_build() {
    debug(UVM_AUTO) {
      import std.stdio;
      writeln("Building .... : ", get_full_name);
    }
    ._uvm__auto_build!(0, typeof(this))(this);
  }
}

// mixin template uvm_component_param_utils(T=void)
// {
//   static if(is(T == void)) {
//     alias typeof(this) U;
//   }
//   else {
//     alias T U;
//   }
//   mixin m_uvm_component_registry_param!(U);
// }

// MACRO: `uvm_object_registry
//
// Register a uvm_object-based class with the factory
//
//| `uvm_object_registry(T,S)
//
// Registers a uvm_object-based class ~T~ and lookup
// string ~S~ with the factory. ~S~ typically is the
// name of the class in quotes. The <`uvm_object_utils>
// family of macros uses this macro.

mixin template uvm_object_registry_mixin(T, string S)
{
  alias uvm_object_registry!(T,S) type_id;
  static public type_id get_type() {
    return type_id.get();
  }
  override public uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}


// MACRO: `uvm_component_registry
//
// Registers a uvm_component-based class with the factory
//
//| `uvm_component_registry(T,S)
//
// Registers a uvm_component-based class ~T~ and lookup
// string ~S~ with the factory. ~S~ typically is the
// name of the class in quotes. The <`uvm_object_utils>
// family of macros uses this macro.

mixin template uvm_component_registry_mixin(T, string S)
{
  alias uvm_component_registry!(T,S) type_id;
  static public type_id get_type() {
    return type_id.get();
  }
  override public uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}

// uvm_new_func
// ------------

mixin template uvm_new_func()
{
  public this (string name, uvm_component parent) {
    super(name, parent);
  }
}

//-----------------------------------------------------------------------------
// INTERNAL MACROS - in support of *_utils macros -- do not use directly
//-----------------------------------------------------------------------------

// m_uvm_object_create_func
// ------------------------
mixin template m_uvm_object_create_func(T) {
  override public uvm_object create (string name="") {
    T tmp;
    version(UVM_OBJECT_MUST_HAVE_CONSTRUCTOR) {
      if (name=="") tmp = new T();
      else tmp = new T(name);
    }
    else {
      tmp = new T();
      if (name!="") tmp.set_name(name);
    }
    return tmp;
  }
}


// m_uvm_get_type_name_func
// ----------------------
mixin template m_uvm_get_type_name_func(T) {
  enum string type_name = T.stringof;
  override public string get_type_name () {
    return type_name;
  }
}


// // m_uvm_object_registry_internal
// // ------------------------------

// //This is needed due to an issue in of passing down strings
// //created by args to lower level macros.
// mixin template m_uvm_object_registry_internal(T, string S)
// {
//   alias uvm_object_registry!(T, S) type_id;
//   static public type_id get_type() {
//     return type_id.get();
//   }
//   // do not make static since we need to override this method
//   override public uvm_object_wrapper get_object_type() {
//     return type_id.get();
//   }
// }

// m_uvm_object_registry_param
// ---------------------------

// mixin template m_uvm_object_registry_param(T)
// {
//   alias uvm_object_registry!T type_id;
//   static public type_id get_type() {
//     return type_id.get();
//   }
//   override public uvm_object_wrapper get_object_type() {
//     return type_id.get();
//   }
// }


// m_uvm_component_registry_internal
// ---------------------------------

//This is needed due to an issue in of passing down strings
//created by args to lower level macros.
mixin template m_uvm_component_registry_internal(T, string S)
{
  alias uvm_component_registry!(T,S) type_id;
  static public type_id get_type() {
    return type_id.get();
  }
  override public uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}

// versions of the uvm_component_registry macros to be used with
// parameterized classes

// m_uvm_component_registry_param
// ------------------------------

// mixin template m_uvm_component_registry_param(T)
// {
//   alias uvm_component_registry!T type_id;
//   static public type_id get_type() {
//     return type_id.get();
//   }
//   override public uvm_object_wrapper get_object_type() {
//     return type_id.get();
//   }
// }

mixin template m_uvm_field_auto_utils(T)
{
  void uvm_field_auto_all_fields(alias F, size_t I=0, T)(T lhs, T rhs) {
    static if(I < lhs.tupleof.length) {
      if(F!(I)(lhs, rhs)) {
	// shortcircuit useful for compare etc
	return;
      }
      uvm_field_auto_all_fields!(F, I+1)(lhs, rhs);
    }
    else static if(is(T B == super) // && B.length > 0
		   ) {
	alias BASE = B[0];
	static if(! (is(BASE == uvm_component) ||
		     is(BASE == uvm_object) ||
		     is(BASE == uvm_sequence_item) ||
		     is(BASE == uvm_sequence_base))) {
	  BASE lhs_ = lhs;
	  BASE rhs_ = rhs;
	  uvm_field_auto_all_fields!(F, 0)(lhs_, rhs_);
	}
      }
  }

  // Copy
  override void uvm_field_auto_copy(uvm_object rhs) {
    auto rhs_ = cast(T) rhs;
    if(rhs_ is null) {
      uvm_error("uvm_field_auto_copy", "cast failed, check type compatability");
    }
    uvm_field_auto_all_fields!uvm_field_auto_copy_field(this, rhs_);
  }

  // copy the Ith field
  bool uvm_field_auto_copy_field(size_t I=0, T)(T lhs, T rhs) {
    enum int flags = uvm_field_auto_get_flags!(lhs, I);
    if(flags & UVM_COPY &&
       !(flags & UVM_NOCOPY)) {
      lhs.tupleof[I] = rhs.tupleof[I];
    }
    return false;
  }

  // Comparison
  override void uvm_field_auto_compare(uvm_object rhs) {
    auto rhs_ = cast(T) rhs;
    if(rhs_ is null) {
      uvm_error("uvm_field_auto_compare", "cast failed, check type compatability");
    }
    uvm_field_auto_all_fields!uvm_field_auto_compare_field(this, rhs_);
  }

  // compare the Ith field
  bool uvm_field_auto_compare_field(size_t I=0, T)(T lhs, T rhs) {
    import std.traits: isIntegral;
    enum int flags = uvm_field_auto_get_flags!(lhs, I);
    static if(flags & UVM_COMPARE &&
	      !(flags & UVM_NOCOMPARE)) {
      auto comparer = m_uvm_status_container.comparer;
      alias typeof(lhs.tupleof[I]) U;
      static if(isBitVector!U) {
	if(! lhs.tupleof[I].isLogicEqual(rhs.tupleof[I])) {
	  comparer.compare_field(lhs.tupleof[I].stringof[4..$],
				 lhs.tupleof[I], rhs.tupleof[I]);
	}
      }
      else static if(isIntegral!U || isBoolean!U ) {
	  if(lhs.tupleof[I] != rhs.tupleof[I]) {
	    comparer.compare_field(lhs.tupleof[I].stringof[4..$],
				   lhs.tupleof[I], rhs.tupleof[I]);
	  }
	}
	else {
	  static assert(false, "compare not implemented yet for: " ~
			U.stringof);
	}
      if(comparer.result && (comparer.show_max <= comparer.result)) {
	// shortcircuit
	return true;
      }
    }
    return false;
  }
}


template uvm_field_auto_get_flags(alias t, size_t I) {
  alias typeof(t) T;
  enum int class_flags =
    uvm_field_auto_acc_flags!(__traits(getAttributes, T));
  enum int flags =
    uvm_field_auto_acc_flags!(__traits(getAttributes, t.tupleof[I]));
  enum int uvm_field_auto_get_flags = flags | class_flags;
}

template uvm_field_auto_acc_flags(A...)
{
  static if(A.length is 0) enum int uvm_field_auto_acc_flags = 0;
  else static if(is(typeof(A[0]) == uvm_recursion_policy_enum) ||
		 is(typeof(A[0]) == uvm_field_auto_enum)) {
      enum int uvm_field_auto_acc_flags = A[0] |
	uvm_field_auto_acc_flags!(A[1..$]);
    }
    else {
      enum int uvm_field_auto_acc_flags = uvm_field_auto_acc_flags!(A[1..$]);
    }
}
