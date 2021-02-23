//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2012 Aldec
// Copyright 2007-2012 Mentor Graphics Corporation
// Copyright 2018 Qualcomm, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2010-2013 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2012 AMD
// Copyright 2012-2018 NVIDIA Corporation
// Copyright 2012-2018 Cisco Systems, Inc.
// Copyright 2012 Accellera Systems Initiative
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

public import uvm.base.uvm_registry: uvm_object_registry,
  uvm_abstract_object_registry;

template HasDefaultConstructor(T) {
  enum HasDefaultConstructor =
    HasDefaultConstructor!(__traits(getOverloads, T, "__ctor"));
}

template HasDefaultConstructor(F...) {
  import std.traits: Parameters;
  static if (F.length == 0) {
    enum HasDefaultConstructor = false;
  }
  else static if ((Parameters!(F[0])).length == 0) {
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
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  mixin uvm_object_registry_mixin!(U, qualifiedTypeName!U);
  mixin m_uvm_object_create_func!(U);
  mixin m_uvm_get_type_name_func!(U);
  mixin m_uvm_object_auto_utils!(U);
  version (UVM_NO_RAND) {}
  else {
    import esdl.rand;
    mixin Randomization;
  }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    // static if (__traits(compiles, this(""))) {
    this() {this("");}
    // }
    // else {
    //   this() {}
    // }
  }
}

mixin template uvm_abstract_object_essentials(T=void)
{
  import uvm.meta.meta;
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  mixin uvm_abstract_object_registry_mixin!(U, qualifiedTypeName!U);
  // mixin m_uvm_object_create_func!(U);
  mixin m_uvm_get_type_name_func!(U);
  // mixin m_uvm_object_auto_utils!(U);
  // version (UVM_NO_RAND) {}
  // else {
  //   import esdl.rand;
  //   mixin Randomization;
  // }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    // static if (__traits(compiles, this(""))) {
    this() {this("");}
    // }
    // else {
    //   this() {}
    // }
  }
}

mixin template uvm_abstract_object_utils(T=void)
{
  import uvm.meta.meta;
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  mixin uvm_abstract_object_registry_mixin!(U, qualifiedTypeName!U);
  // mixin m_uvm_object_create_func!(U);
  mixin m_uvm_get_type_name_func!(U);
  mixin m_uvm_object_auto_utils!(U);
  // version (UVM_NO_RAND) {}
  // else {
  //   import esdl.rand;
  //   mixin Randomization;
  // }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    // static if (__traits(compiles, this(""))) {
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
  static if (is (T == void)) {
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
  static if (! HasDefaultConstructor!U) {
    this() {this("");}
  }
}


// mixin template uvm_object_param_utils(T=void)
// {
//   static if (is (T == void)) {
//     alias typeof(this) U;
//   }
//   else {
//     alias T U;
//   }
//   mixin m_uvm_object_registry_param!(U);
//   mixin m_uvm_object_create_func!(U);
//   // `uvm_field_utils_begin(U)
// }

mixin template uvm_object_registry_mixin(T, string S)
{
  import uvm.base.uvm_factory: uvm_object_wrapper;
  alias type_id = uvm_object_registry!(T,S);
  static type_id get_type() {
    return type_id.get();
  }
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}


mixin template uvm_abstract_object_registry_mixin(T, string S)
{
  import uvm.base.uvm_factory: uvm_object_wrapper;
  alias type_id = uvm_abstract_object_registry!(T,S);
  static type_id get_type() {
    return type_id.get();
  }
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
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
    if (name=="") tmp = new T();
    else tmp = new T(name);
    return tmp;
  }
}


// m_uvm_get_type_name_func
// ----------------------
mixin template m_uvm_get_type_name_func(T) {
  import uvm.meta.meta;
  static string type_name () {
    return qualifiedTypeName!T;
  }
  override string get_type_name () {
    return qualifiedTypeName!T;
  }
}


// Macro --NODOCS-- uvm_type_name_decl(TNAME_STRING)
// Potentially public macro for Mantis 5003.
//
// This macro creates a statically accessible
// ~type_name~, and implements the virtual
// <uvm_object::get_type_name> method.
//
mixin template uvm_type_name_decl(string TNAME_STRING="") {
  static if (TNAME_STRING == "") {
    static string type_name() {
      return qualifiedTypeName!(typeof(this));
    }
    override string get_type_name() {
      return qualifiedTypeName!(typeof(this));
    }
  }
  else {
    static string type_name() {
      return TNAME_STRING;
    }
    override string get_type_name() {
      return TNAME_STRING;
    }
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


mixin template m_uvm_object_auto_utils(T)
{
  import uvm.base.uvm_field_op: uvm_field_op;

  override void do_execute_op(uvm_field_op op) {
    m_uvm_execute_field_op(op);
  }

  override void m_uvm_execute_field_op(uvm_field_op op) {
    import uvm.base.uvm_copier: uvm_copier;
    import uvm.base.uvm_comparer: uvm_comparer;
    import uvm.base.uvm_printer: uvm_printer;
    import uvm.base.uvm_recorder: uvm_recorder;
    import uvm.base.uvm_packer: uvm_packer;
    import uvm.base.uvm_resource_base: uvm_resource_base;
    import uvm.base.uvm_object_globals: uvm_field_flag_t,
      uvm_field_auto_enum;
    
    super.m_uvm_execute_field_op(op);

    uvm_field_flag_t what = op.get_op_type();
    switch (what) {
    case uvm_field_auto_enum.UVM_COPY:
      T rhs = cast (T) op.get_rhs();
      if (rhs is null) return;
      if (op.get_policy() is null) assert (false);
      uvm_copier copier = cast (uvm_copier) op.get_policy();
      if (copier is null) assert (false);
      _m_uvm_execute_copy!0(this, rhs, copier);
      break;
    case uvm_field_auto_enum.UVM_COMPARE:
      T rhs = cast (T) op.get_rhs();
      if (rhs is null) return;
      if (op.get_policy() is null) assert (false);
      uvm_comparer comparer = cast (uvm_comparer) op.get_policy();
      if (comparer is null) assert (false);
      _m_uvm_execute_compare!0(this, rhs, comparer);
      break;
    case uvm_field_auto_enum.UVM_PRINT:
      if (op.get_policy() is null) assert (false);
      uvm_printer printer = cast (uvm_printer) op.get_policy();
      if (printer is null) assert (false);
      _m_uvm_execute_print!0(this, printer);
      break;
    case uvm_field_auto_enum.UVM_RECORD:
      uvm_recorder recorder = cast (uvm_recorder) op.get_policy();
      if (recorder !is null || recorder.is_open()) {
	_m_uvm_execute_record!0(this, recorder);
      }
      break;
    case uvm_field_auto_enum.UVM_PACK:
      if (op.get_policy() is null) assert (false);
      uvm_packer packer = cast (uvm_packer) op.get_policy();
      if (packer is null) assert (false);
      _m_uvm_execute_pack!0(this, packer);
      break;
    case uvm_field_auto_enum.UVM_UNPACK:
      if (op.get_policy() is null) assert (false);
      uvm_packer packer = cast (uvm_packer) op.get_policy();
      if (packer is null) assert (false);
      _m_uvm_execute_unpack!0(this, packer);
      break;
    case uvm_field_auto_enum.UVM_SET:
      uvm_resource_base rsrc = cast (uvm_resource_base) op.get_rhs();
      if (rsrc is null) return;
      _m_uvm_execute_set!0(this, rsrc);
      break;
    default: break;
    }
  }
}
