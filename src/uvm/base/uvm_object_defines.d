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

template HasDefaultConstructor(T) {
  enum HasDefaultConstructor =
    HasDefaultConstructor!(__traits(getOverloads, T, "__ctor"));
}

template HasDefaultConstructor(F...) {
  import std.traits: Parameters;
  static if(F.length == 0) {
    enum HasDefaultConstructor = false;
  }
  else static if((Parameters!(F[0])).length == 0) {
    enum HasDefaultConstructor = true;
  }
  else {
    enum HasDefaultConstructor = HasDefaultConstructor!(F[1..$]);
  }
}
    
string uvm_object_utils_string()() {
  return "mixin uvm_object_utils!(typeof(this));";
}

mixin template uvm_object_utils(T=void)
{
  import uvm.meta.meta;
  static if(is(T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  mixin uvm_object_registry_mixin!(U, qualifiedTypeName!U);
  mixin m_uvm_object_create_func!(U);
  mixin m_uvm_get_type_name_func!(U);
  mixin m_uvm_field_auto_utils!(U);
  version(UVM_NORANDOM) {}
  else {
    mixin Randomization;
  }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if(! HasDefaultConstructor!U) {
    // static if(__traits(compiles, this(""))) {
    this() {this("");}
    // }
    // else {
    //   this() {}
    // }
  }
}

mixin template uvm_object_utils_norand(T=void)
{
  import uvm.meta.meta;
  static if(is(T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  mixin uvm_object_registry_mixin!(U, qualifiedTypeName!U);
  mixin m_uvm_object_create_func!(U);
  mixin m_uvm_get_type_name_func!(U);
  mixin m_uvm_field_auto_utils!(U);
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if(! HasDefaultConstructor!U) {
    this() {this("");}
  }
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

import uvm.base.uvm_root: uvm_root;

mixin template uvm_component_utils(T=void)
{
  import uvm.base.uvm_root;
  static if(is(T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  static if(! is(U: uvm_root)) { // do not register uvm_roots with factory
    import uvm.meta.meta;
    mixin uvm_component_registry_mixin!(U, qualifiedTypeName!U);
  }
  mixin m_uvm_get_type_name_func!(U);
  mixin uvm_component_auto_build_mixin;
  mixin uvm_component_auto_elab_mixin;

  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if(! HasDefaultConstructor!U) {
    this() {this("", null);}
  }
}

mixin template uvm_component_auto_build_mixin()
{
  // overriding function that calls the generic function for automatic
  // object construction
  override void uvm__auto_build() {
    debug(UVM_AUTO) {
      import std.stdio;
      writeln("Building .... : ", get_full_name);
    }
    .uvm__auto_build!(0, typeof(this))(this);
  }
}

mixin template uvm_component_auto_elab_mixin()
{
  // overriding function that calls the generic function for automatic
  // object construction
  override void uvm__auto_elab() {
    debug(UVM_AUTO) {
      import std.stdio;
      writeln("Elaborating .... : ", get_full_name);
    }
    .uvm__auto_elab!(0, typeof(this))(this);
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
  import uvm.base.uvm_factory: uvm_object_wrapper;
  import uvm.base.uvm_registry: uvm_object_registry;
  alias type_id = uvm_object_registry!(T,S);
  static type_id get_type() {
    return type_id.get();
  }
  override uvm_object_wrapper get_object_type() {
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
  import uvm.base.uvm_factory: uvm_object_wrapper;
  import uvm.base.uvm_registry: uvm_component_registry;
  alias type_id = uvm_component_registry!(T,S);
  static type_id get_type() {
    return type_id.get();
  }
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}

// uvm_new_func
// ------------

mixin template uvm_new_func()
{
  this (string name, uvm_component parent) {
    super(name, parent);
  }
}

//-----------------------------------------------------------------------------
// INTERNAL MACROS - in support of *_utils macros -- do not use directly
//-----------------------------------------------------------------------------

// m_uvm_object_create_func
// ------------------------
mixin template m_uvm_object_create_func(T) {
  import uvm.base.uvm_object: uvm_object;
  override uvm_object create (string name="") {
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
  import uvm.meta.meta;
  enum string type_name =  qualifiedTypeName!T;
  override string get_type_name () {
    return type_name;
  }
}


// // m_uvm_object_registry_internal
// // ------------------------------

// //This is needed due to an issue in of passing down strings
// //created by args to lower level macros.
// mixin template m_uvm_object_registry_internal(T, string S)
// {
//   import uvm.base.uvm_factory: uvm_object_wrapper;
//   alias uvm_object_registry!(T, S) type_id;
//   static type_id get_type() {
//     return type_id.get();
//   }
//   // do not make static since we need to override this method
//   override uvm_object_wrapper get_object_type() {
//     return type_id.get();
//   }
// }

// m_uvm_object_registry_param
// ---------------------------

// mixin template m_uvm_object_registry_param(T)
// {
//   import uvm.base.uvm_factory: uvm_object_wrapper;
//   alias uvm_object_registry!T type_id;
//   static type_id get_type() {
//     return type_id.get();
//   }
//   override uvm_object_wrapper get_object_type() {
//     return type_id.get();
//   }
// }


// m_uvm_component_registry_internal
// ---------------------------------

//This is needed due to an issue in of passing down strings
//created by args to lower level macros.
mixin template m_uvm_component_registry_internal(T, string S)
{
  import uvm.base.uvm_factory: uvm_object_wrapper;
  import uvm.base.uvm_registry: uvm_component_registry;
  alias type_id = uvm_component_registry!(T,S);
  static type_id get_type() {
    return type_id.get();
  }
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}

// versions of the uvm_component_registry macros to be used with
// parameterized classes

// m_uvm_component_registry_param
// ------------------------------

// mixin template m_uvm_component_registry_param(T)
// {
//   import uvm.base.uvm_factory: uvm_object_wrapper;
//   alias uvm_component_registry!T type_id;
//   static type_id get_type() {
//     return type_id.get();
//   }
//   override uvm_object_wrapper get_object_type() {
//     return type_id.get();
//   }
// }

mixin template m_uvm_field_auto_utils(T)
{
  import uvm.base.uvm_object_globals: uvm_bitstream_t;
  import uvm.base.uvm_globals;
  import uvm.base.uvm_object;
  import uvm.base.uvm_component;
  import uvm.seq.uvm_sequence_item;
  import uvm.seq.uvm_sequence_base;
  import uvm.base.uvm_object_globals;
  void uvm_field_auto_all_fields(alias F, size_t I=0, T)(T lhs, T rhs) {
    version(UVM_NORANDOM) {}
    else {
      import esdl.data.rand;
    }
    static if(I < lhs.tupleof.length) {
      alias U=typeof(T.tupleof[I]);
      version(UVM_NORANDOM) {
	if(F!(I)(lhs, rhs)) {
	  // shortcircuit useful for compare etc
	  return;
	}
      }
      else {
	static if(! is(U: _esdl__ConstraintBase)) {
	  if(F!(I)(lhs, rhs)) {
	    // shortcircuit useful for compare etc
	    return;
	  }
	}
      }
      uvm_field_auto_all_fields!(F, I+1)(lhs, rhs);
    }
    else static if(is(T B == super) // && B.length > 0
		   ) {
      import uvm.seq.uvm_sequence_item: uvm_sequence_item;
      import uvm.seq.uvm_sequence_base: uvm_sequence_base;
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

  void uvm_field_auto_all_fields(alias F, size_t I=0, T)(T t) {
    version(UVM_NORANDOM) {}
    else {
      import esdl.data.rand;
    }
    static if(I < t.tupleof.length) {
      alias U=typeof(t.tupleof[I]);
      version(UVM_NORANDOM) {
	F!(I)(t);
      }
      else {
	static if(! is(U: _esdl__ConstraintBase)) {
	  F!(I)(t);
	}
      }
      uvm_field_auto_all_fields!(F, I+1)(t);
    }
    else static if(is(T B == super) // && B.length > 0
		   ) {
      import uvm.seq.uvm_sequence_item: uvm_sequence_item;
      import uvm.seq.uvm_sequence_base: uvm_sequence_base;
      alias BASE = B[0];
      static if(! (is(BASE == uvm_component) ||
		   is(BASE == uvm_object) ||
		   is(BASE == uvm_sequence_item) ||
		   is(BASE == uvm_sequence_base))) {
	BASE t_ = t;
	uvm_field_auto_all_fields!(F, 0)(t_);
      }
    }
  }

  override void uvm_field_auto_setint(string field_name,
				      uvm_bitstream_t value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }

  override void uvm_field_auto_setint(string field_name,
				      uvm_integral_t value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }

  override void uvm_field_auto_setint(string field_name,
				      ulong value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }
  
  override void uvm_field_auto_setint(string field_name,
				      uint value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }
  
  override void uvm_field_auto_setint(string field_name,
				      ushort value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }
  
  override void uvm_field_auto_setint(string field_name,
				      ubyte value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }
  
  override void uvm_field_auto_setint(string field_name,
				      bool value) {
    uvm_error("uvm_field_auto_setint", "not yet implemented");
  }
  
  // return true if a match occured
  void uvm_set_local(size_t I=0, T, U)(T t, U value, string regx,
				       string prefix="",
				       ref bool status = false) {
    static if(I < t.tupleof.length) {
      enum int FLAGS = uvm_field_auto_get_flags!(t, I);
      alias E = typeof(t.tupleof[I]);
      string name = prefix ~ __traits(identifier, T.tupleof[I]);
      static if(FLAGS & UVM_READONLY) {
	if(uvm_is_match(regx, name)) {
	  uvm_report_warning("RDONLY",
			     format("Readonly argument match %s is ignored",
				    name),
			     UVM_NONE);
	}
      }
      else {
	if(uvm_is_match(regx, name)) {
	  uvm_report_info("STRMTC", "set_object()" ~ ": Matched string " ~
			  regx ~ " to field " ~ name,
			  UVM_LOW);
	  static if(is(U: E)) {
	    t.tupleof[I] = value;
	    status = true;
	  }
	  else static if(is(E: U) && is(U: Object)) {
	    if(t.tupleof[i] == cast(E) value) {
	      status = true;
	    }
	  }
	  else {
	    t.tupleof[I] = cast(E) value;
	    status = true;
	  }
	}
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
    enum int FLAGS = uvm_field_auto_get_flags!(lhs, I);
    if(FLAGS & UVM_COPY &&
       !(FLAGS & UVM_NOCOPY)) {
      debug(UVM_UTILS) {
	pragma(msg, "Copying : " ~ lhs.tupleof[I].stringof);
      }
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
    enum int FLAGS = uvm_field_auto_get_flags!(lhs, I);
    static if(FLAGS & UVM_COMPARE &&
	      !(FLAGS & UVM_NOCOMPARE)) {
      auto comparer = m_uvm_status_container.comparer;
      alias typeof(lhs.tupleof[I]) U;
      static if(isBitVector!U) {
	if(lhs.tupleof[I] !is rhs.tupleof[I]) {
	  comparer.compare(__traits(identifier, T.tupleof[I]),
			   lhs.tupleof[I], rhs.tupleof[I]);
	}
      }
      else // static if(isIntegral!U || isBoolean!U )
	{
	  if(lhs.tupleof[I] != rhs.tupleof[I]) {
	    comparer.compare(__traits(identifier, T.tupleof[I]),
			     lhs.tupleof[I], rhs.tupleof[I]);
	  }
	}
      // else {
      // 	static assert(false, "compare not implemented yet for: " ~
      // 		      qualifiedTypeName!U);
      // }
      if(comparer.result && (comparer.show_max <= comparer.result)) {
	// shortcircuit
	return true;
      }
    }
    return false;
  }

  // print
  override void uvm_field_auto_sprint() {
    uvm_field_auto_all_fields!uvm_field_auto_sprint_field(this);
  }

  // print the Ith field
  void uvm_field_auto_sprint_field(size_t I=0, T)(T t) {
    import std.traits: isIntegral, isFloatingPoint;
    enum int FLAGS = uvm_field_auto_get_flags!(t, I);
    static if(FLAGS & UVM_PRINT &&
	      !(FLAGS & UVM_NOPRINT)) {
      debug(UVM_UTILS) {
	pragma(msg, "Printing : " ~ t.tupleof[I].stringof);
      }
      enum string name = __traits(identifier, T.tupleof[I]);
      auto value = t.tupleof[I];
      auto printer = m_uvm_status_container.printer;
      alias U=typeof(t.tupleof[I]);
      // do not use isIntegral -- we keep that for enums
      static if(is(U == SimTime)) {
	printer.print(name, value);
      }
      else static if(isBitVector!U  ||
		is(U == byte)  || is(U == ubyte)  ||
		is(U == short) || is(U == ushort) ||
		is(U == int)   || is(U == uint) ||
		is(U == long)  || is(U == ulong)) {
	printer.print(name, value,
		      cast(uvm_radix_enum) (FLAGS & UVM_RADIX));
      }
      else static if(isIntegral!U) { // to cover enums
	printer.print(name, value, UVM_ENUM);
      }
      else static if(is(U: uvm_object)) {
	if((FLAGS & UVM_REFERENCE) != 0) {
	  printer.print_object_header(name, value);
	}
	else {
	  printer.print(name, value);
	}
      }
      else static if(is(U == string) || is(U == char[])) {
	printer.print(name, value);
      }
      // enum should be already handled as part of integral
      else static if(isFloatingPoint!U) {
	printer.print(name, value);
      }
      else static if(is(U: EventObj)) {
	printer.print_generic(name, "event", -2, "");
      }
      else // static if(isIntegral!U || isBoolean!U )
	{
	  import std.conv;
	  printer.print_generic(name, U.stringof, -2, value.to!string);
	}
    }
  }
}


template uvm_field_auto_get_flags(alias t, size_t I) {
  alias typeof(t) T;
  enum int class_flags =
    uvm_field_auto_acc_flags!(__traits(getAttributes, T));
  enum int FLAGS =
    uvm_field_auto_acc_flags!(__traits(getAttributes, t.tupleof[I]));
  enum int uvm_field_auto_get_flags = FLAGS | class_flags;
}

template uvm_field_auto_acc_flags(A...)
{
  import uvm.base.uvm_object_globals: uvm_recursion_policy_enum,
                                      uvm_field_auto_enum;
  static if(A.length is 0) {
    enum int uvm_field_auto_acc_flags = 0;
  }
  else static if(is(typeof(A[0]) == uvm_recursion_policy_enum) ||
		 is(typeof(A[0]) == uvm_field_auto_enum)) {
      enum int uvm_field_auto_acc_flags = A[0] |
	uvm_field_auto_acc_flags!(A[1..$]);
    }
    else {
      enum int uvm_field_auto_acc_flags = uvm_field_auto_acc_flags!(A[1..$]);
    }
}
