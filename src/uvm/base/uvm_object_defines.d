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
  mixin m_uvm_object_auto_utils!(U);
  version(UVM_NO_RAND) {}
  else {
    import esdl.rand;
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

mixin template uvm_object_essentials(T=void)
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
  // mixin m_uvm_object_auto_utils!(U);
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

mixin template uvm_component_essentials(T=void)
{
  import uvm.base.uvm_root: uvm_root;
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
  // mixin uvm_component_auto_build_mixin;
  // mixin uvm_component_auto_elab_mixin;

  // mixin m_uvm_object_auto_utils!(U);
  // version(UVM_NO_RAND) { }
  // else {
  //   import esdl.rand;
  //   mixin Randomization;
  // }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if(! HasDefaultConstructor!U) {
    this() {this("", null);}
  }
}

// There is a class by name uvm_utils in uvm_misc module
// mixin template uvm_utils(T=void)
// {
//   static if (is(T == void)) {
//     alias U = typeof(this);
//   }
//   else {
//     alias U = T;
//   }
//   static if (is(U: uvm_component)) {
//     mixin uvm_component_utils!U;
//   }
//   else static if (is(U: uvm_object)) {
//     mixin uvm_object_utils!U;
//   }
//   else {
//     static assert (false, "uvm_utils can be mixed-in into only " ~
// 		   "uvm_object or uvm_component derivatives");
//   }
// }

mixin template uvm_component_utils(T=void)
{
  import uvm.base.uvm_root: uvm_root;
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

  mixin m_uvm_object_auto_utils!(U);
  mixin m_uvm_component_auto_utils!(U);

  version(UVM_NO_RAND) { }
  else {
    import esdl.rand;
    mixin Randomization;
  }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if(! HasDefaultConstructor!U) {
    this() {this("", null);}
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
  import uvm.base.uvm_component: uvm_component;
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

mixin template m_uvm_object_auto_utils(T)
{

  override void m_uvm_object_automation(uvm_object rhs,  
					int        what, 
					string     str) {
    import uvm.base.uvm_object_globals: uvm_field_xtra_enum,
      uvm_field_auto_enum;
    import uvm.base.uvm_globals;
    uvm_object[] current_scopes;
    if (what == uvm_field_xtra_enum.UVM_SETINT ||
	what == uvm_field_xtra_enum.UVM_SETSTR ||
	what == uvm_field_xtra_enum.UVM_SETOBJ) {
      if (m_uvm_status_container.m_do_cycle_check(this)) {
	return;
      }
      current_scopes = m_uvm_status_container.m_uvm_cycle_scopes;
    }

    super.m_uvm_object_automation(rhs, what, str);
    /* Type is verified by uvm_object::compare() */
    T rhs_;
    if (what == uvm_field_auto_enum.UVM_COMPARE ||
	what == uvm_field_auto_enum.UVM_COPY) { // rhs is required
      if (rhs is null) {
      }
      else {
	rhs_ = cast(T) rhs;
	if (rhs_ is null) return;
      }
    }
    // if (tmp_data__ != null)
    /* Allow objects in same hierarchy to be copied/compared */
    // if(!$cast(local_data__, tmp_data__)) return;

    _m_uvm_object_automation!0(this, rhs_, what, str); // defined in uvm_object
    if (what == uvm_field_xtra_enum.UVM_SETINT ||
	what == uvm_field_xtra_enum.UVM_SETSTR ||
	what == uvm_field_xtra_enum.UVM_SETOBJ) {
      // remove all scopes recorded (through super and other objects
      // visited before)
      m_uvm_status_container.m_uvm_cycle_scopes = current_scopes[0..$-1];
    }
  }

  // override bool uvm_field_utils_defined() {
  //   return true;
  // }
  
  // void uvm_object_auto_all_fields(alias F, size_t I=0, T)(T lhs, T rhs) {
  //   static if(I < lhs.tupleof.length) {
  //     alias U=typeof(T.tupleof[I]);
  //     version(UVM_NO_RAND) {
  // 	if(F!(I)(lhs, rhs)) {
  // 	  // shortcircuit useful for compare etc
  // 	  return;
  // 	}
  //     }
  //     else {
  // 	import esdl.rand;
  // 	static if(! is(U: _esdl__ConstraintBase)) {
  // 	  if(F!(I)(lhs, rhs)) {
  // 	    // shortcircuit useful for compare etc
  // 	    return;
  // 	  }
  // 	}
  //     }
  //     uvm_object_auto_all_fields!(F, I+1)(lhs, rhs);
  //   }
  //   else static if(is(T B == super) // && B.length > 0
  // 		   ) {
  //     import uvm.seq.uvm_sequence_item: uvm_sequence_item;
  //     import uvm.seq.uvm_sequence_base: uvm_sequence_base;
  //     alias BASE = B[0];
  //     static if(! (is(BASE == uvm_component) ||
  // 		   is(BASE == uvm_object) ||
  // 		   is(BASE == uvm_sequence_item) ||
  // 		   is(BASE == uvm_sequence_base))) {
  // 	BASE lhs_ = lhs;
  // 	BASE rhs_ = rhs;
  // 	uvm_object_auto_all_fields!(F, 0)(lhs_, rhs_);
  //     }
  //   }
  // }

  // void uvm_object_auto_all_fields(alias F, size_t I=0, T)(T t) {
  //   static if(I < t.tupleof.length) {
  //     alias U=typeof(t.tupleof[I]);
  //     version(UVM_NO_RAND) {
  // 	F!(I)(t);
  //     }
  //     else {
  // 	import esdl.rand;
  // 	static if(! is(U: _esdl__ConstraintBase)) {
  // 	  F!(I)(t);
  // 	}
  //     }
  //     uvm_object_auto_all_fields!(F, I+1)(t);
  //   }
  //   else static if(is(T B == super) // && B.length > 0
  // 		   ) {
  //     import uvm.seq.uvm_sequence_item: uvm_sequence_item;
  //     import uvm.seq.uvm_sequence_base: uvm_sequence_base;
  //     alias BASE = B[0];
  //     static if(! (is(BASE == uvm_component) ||
  // 		   is(BASE == uvm_object) ||
  // 		   is(BASE == uvm_sequence_item) ||
  // 		   is(BASE == uvm_sequence_base))) {
  // 	BASE t_ = t;
  // 	uvm_object_auto_all_fields!(F, 0)(t_);
  //     }
  //   }
  // }

  // override void uvm_object_auto_set(string field_name, uvm_bitstream_t value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }

  // override void uvm_object_auto_set(string field_name, uvm_integral_t value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }

  // override void uvm_object_auto_set(string field_name, ulong value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  
  // override void uvm_object_auto_set(string field_name, uint value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  
  // override void uvm_object_auto_set(string field_name, ushort value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  
  // override void uvm_object_auto_set(string field_name, ubyte value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  
  // override void uvm_object_auto_set(string field_name, bool value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  
  // override void uvm_object_auto_set(string field_name, string value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  
  // override void uvm_object_auto_set(string field_name, uvm_object value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_object_auto_set(field_name, value, matched, prefix, hier);
  //   uvm_set_local(this, field_name, value, matched, prefix, hier);
  // }
  


  // Copy
  // override void uvm_object_auto_copy(uvm_object rhs) {
  //   auto rhs_ = cast(T) rhs;
  //   if(rhs_ is null) {
  //     uvm_error("UVMUTLS", "cast failed, check type compatability");
  //   }
  //   super.uvm_object_auto_copy(rhs);
  //   uvm_object_auto_copy_field(this, rhs_);
  // }

  // // copy the Ith field
  // void uvm_object_auto_copy_field(size_t I=0, T)(T lhs, T rhs) {
  //   import std.traits;
  //   static if (I < lhs.tupleof.length) {
  //     // pragma(msg, T.tupleof[I].stringof);
  //     alias U=typeof(lhs.tupleof[I]);
  //     enum int FLAGS = uvm_object_auto_get_flags!(lhs, I);
  //     static if(FLAGS & UVM_COPY &&
  // 		!(FLAGS & UVM_NOCOPY)) {
  // 	// version(UVM_NO_RAND) { }
  // 	// else {
  // 	//   import esdl.rand;
  // 	//   static if (is(U: _esdl__ConstraintBase)) {
  // 	//     uvm_object_auto_copy_field!(I+1)(lhs, rhs);
  // 	//   }
  // 	// }
  // 	// debug(UVM_UTILS) {
  // 	//   pragma(msg, "Copying : " ~ lhs.tupleof[I].stringof);
  // 	// }
  // 	static if (is(U: uvm_object)) {
  // 	  static if((FLAGS & UVM_REFERENCE) != 0) {
  // 	    lhs.tupleof[I] = rhs.tupleof[I];
  // 	  }
  // 	  else {
  // 	    lhs.tupleof[I] = cast(U) rhs.tupleof[I].clone;
  // 	  }
  // 	}
  // 	else static if (isIntegral!U || isBitVector!U ||
  // 			is(U == string) || is(U == bool)) {
  // 	  lhs.tupleof[I] = rhs.tupleof[I];
  // 	}
  // 	else static if (isArray!U) {
  // 	  static if (isDynamicArray!U) {
  // 	    lhs.tupleof[I].length = rhs.tupleof[I].length;
  // 	  }
  // 	  uvm_object_auto_copy_field!FLAGS(lhs.tupleof[I], rhs.tupleof[I], 0);
  // 	}
  // 	else {
  // 	  static assert (false, "Do not know how to copy :" ~ U.stringof);
  // 	}
  //     }
  //   }
  //   static if (I < lhs.tupleof.length) {
  //     uvm_object_auto_copy_field!(I+1)(lhs, rhs);
  //   }
  // }

  // // handle arrays
  // void uvm_object_auto_copy_field(int FLAGS, E)(ref E lhs, ref E rhs, int index) {
  //   import std.traits;
  //   if (index < rhs.length) {
  //     alias U=typeof(lhs[index]);
  //     static if (is(U: uvm_object)) {
  // 	static if((FLAGS & UVM_REFERENCE) != 0) {
  // 	  lhs[index] = rhs[index];
  // 	}
  // 	else {
  // 	  lhs[index] = cast(U) rhs[index].clone;
  // 	}
  //     }
  //     else static if (isIntegral!U || isBitVector!U ||
  // 		      is(U == string) || is(U == bool)) {
  // 	lhs[index] = rhs[index];
  //     }
  //     else static if (isArray!U) {
  // 	static if (isDynamicArray!U) {
  // 	  lhs[index].length = rhs[index].length;
  // 	}
  // 	uvm_object_auto_copy_field!FLAGS(lhs[index], rhs[index], 0);
  //     }
  //     else {
  // 	uvm_error("UVMUTLS", "Do not know how to copy :" ~ U.stringof);
  //     }
  //     uvm_object_auto_copy_field!FLAGS(lhs, rhs, index+1);
  //   }
  // }

  // Comparison
  // override void uvm_object_auto_compare(uvm_object rhs) {
  //   auto rhs_ = cast(T) rhs;
  //   if(rhs_ is null) {
  //     uvm_error("UVMUTLS", "cast failed, check type compatability");
  //   }
  //   uvm_object_auto_all_fields!uvm_object_auto_compare_field(this, rhs_);
  // }

  // // compare the Ith field
  // bool uvm_object_auto_compare_field(size_t I=0, T)(T lhs, T rhs) {
  //   import std.traits: isIntegral;
  //   enum int FLAGS = uvm_object_auto_get_flags!(lhs, I);
  //   static if(FLAGS & UVM_COMPARE &&
  // 	      !(FLAGS & UVM_NOCOMPARE)) {
  //     auto comparer = m_uvm_status_container.comparer;
  //     alias typeof(lhs.tupleof[I]) U;
  //     static if(isBitVector!U) {
  // 	if(lhs.tupleof[I] !is rhs.tupleof[I]) {
  // 	  comparer.compare(__traits(identifier, T.tupleof[I]),
  // 			   lhs.tupleof[I], rhs.tupleof[I]);
  // 	}
  //     }
  //     else // static if(isIntegral!U || isBoolean!U )
  // 	{
  // 	  if(lhs.tupleof[I] != rhs.tupleof[I]) {
  // 	    comparer.compare(__traits(identifier, T.tupleof[I]),
  // 			     lhs.tupleof[I], rhs.tupleof[I]);
  // 	  }
  // 	}
  //     // else {
  //     // 	static assert(false, "compare not implemented yet for: " ~
  //     // 		      qualifiedTypeName!U);
  //     // }
  //     if(comparer.result && (comparer.show_max <= comparer.result)) {
  // 	// shortcircuit
  // 	return true;
  //     }
  //   }
  //   return false;
  // }

  // record
  // override void uvm_object_auto_record(uvm_recorder recorder) {
  //   super.uvm_object_auto_record(recorder);
  //   uvm_object_auto_record_field(this, recorder);
  // }

  // print
  // override void uvm_object_auto_sprint(uvm_printer printer) {
  //   super.uvm_object_auto_sprint(printer);
  //   uvm_object_auto_sprint_field(this, printer);
  //   do_print(printer);
  // }


}

mixin template m_uvm_component_auto_utils(T)
{
  // for uvm_components -- parallelization and build
  override void m_uvm_component_automation(int what) {
    super.m_uvm_component_automation(what);
    _m_uvm_component_automation!0(this, what); // defined in uvm_object
  }  
}
