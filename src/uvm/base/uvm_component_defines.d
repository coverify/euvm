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

module uvm.base.uvm_component_defines;

import uvm.base.uvm_object_defines;

string uvm_component_utils_string()() {
  return "mixin uvm_component_utils!(typeof(this));";
}

mixin template uvm_component_essentials(T=void)
{
  import uvm.base.uvm_root: uvm_root;
  import uvm.base.uvm_object_defines;
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  static if (! is (U: uvm_root)) { // do not register uvm_roots with factory
    import uvm.meta.meta;
    mixin uvm_component_registry_mixin!(U, qualifiedTypeName!U);
  }
  mixin m_uvm_get_type_name_func!(U);
  // mixin uvm_component_auto_build_mixin;
  // mixin uvm_component_auto_elab_mixin;

  // mixin m_uvm_object_auto_utils!(U);
  // version (UVM_NO_RAND) { }
  // else {
  //   import esdl.rand;
  //   mixin Randomization;
  // }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    this() {this("", null);}
  }
}

mixin template uvm_abstract_component_essentials(T=void)
{
  import uvm.base.uvm_root: uvm_root;
  import uvm.base.uvm_object_defines;
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  static if (! is (U: uvm_root)) { // do not register uvm_roots with factory
    import uvm.meta.meta;
    mixin uvm_abstract_component_registry_mixin!(U, qualifiedTypeName!U);
  }
  mixin m_uvm_get_type_name_func!(U);
  // mixin uvm_component_auto_build_mixin;
  // mixin uvm_component_auto_elab_mixin;

  // mixin m_uvm_object_auto_utils!(U);
  // version (UVM_NO_RAND) { }
  // else {
  //   import esdl.rand;
  //   mixin Randomization;
  // }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    this() {this("", null);}
  }
}

mixin template uvm_component_utils(T=void)
{
  import uvm.base.uvm_root: uvm_root;
  import uvm.base.uvm_object_defines;
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  static if (! is (U: uvm_root)) { // do not register uvm_roots with factory
    import uvm.meta.meta;
    mixin uvm_component_registry_mixin!(U, qualifiedTypeName!U);
  }
  mixin m_uvm_get_type_name_func!(U);

  mixin m_uvm_object_auto_utils!(U);
  mixin m_uvm_component_auto_utils!(U);

  version (UVM_NO_RAND) { }
  else {
    import esdl.rand;
    mixin Randomization;
  }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    this() {this("", null);}
  }
}

mixin template uvm_abstract_component_utils(T=void)
{
  import uvm.base.uvm_root: uvm_root;
  static if (is (T == void)) {
    alias U = typeof(this);
  }
  else {
    alias U = T;
  }
  static if (! is (U: uvm_root)) { // do not register uvm_roots with factory
    import uvm.meta.meta;
    mixin uvm_abstract_component_registry_mixin!(U, qualifiedTypeName!U);
  }
  mixin m_uvm_get_type_name_func!(U);

  mixin m_uvm_object_auto_utils!(U);
  mixin m_uvm_component_auto_utils!(U);

  // version (UVM_NO_RAND) { }
  // else {
  //   import esdl.rand;
  //   mixin Randomization;
  // }
  // `uvm_field_utils_begin(U)

  // Add a defaultConstructor for Object.factory to work
  static if (! HasDefaultConstructor!U) {
    this() {this("", null);}
  }
}

// mixin template uvm_component_param_utils(T=void)
// {
//   static if (is (T == void)) {
//     alias typeof(this) U;
//   }
//   else {
//     alias T U;
//   }
//   mixin m_uvm_component_registry_param!(U);
// }

// MACRO -- NODOCS -- `uvm_component_registry
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
  import esdl.base.factory: Factory;
  import uvm.base.uvm_factory: uvm_object_wrapper;
  import uvm.base.uvm_registry: uvm_component_registry;
  pragma(crt_constructor)
  extern(C) static void _esdl__registerWithFactory() {
    Factory!q{UVM}.register!(typeof(this))();
  }
  alias type_id = uvm_component_registry!(T,S);
  static type_id get_type() {
    return type_id.get();
  }
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}

mixin template uvm_abstract_component_registry_mixin(T, string S)
{
  import uvm.base.uvm_factory: uvm_object_wrapper;
  import uvm.base.uvm_registry: uvm_abstract_component_registry;
  alias type_id = uvm_abstract_component_registry!(T,S);
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

mixin template m_uvm_component_auto_utils(T)
{
  // for uvm_components -- parallelization and build
  override void m_uvm_component_automation(int what) {
    super.m_uvm_component_automation(what);
    _m_uvm_component_automation!0(this, what); // defined in uvm_object
  }  
}

template uvm_comp_auto_get_flags(alias t, size_t I)
{
  enum int uvm_comp_auto_get_flags =
    uvm_comp_auto_acc_flags!(__traits(getAttributes, t.tupleof[I]));
}

template uvm_comp_auto_acc_flags(A...)
{
  import uvm.base.uvm_object_globals: uvm_comp_auto_enum;
  static if (A.length is 0) {
    enum int uvm_comp_auto_acc_flags = 0;
  }
  else static if (is (typeof(A[0]) == uvm_comp_auto_enum)) {
    enum int uvm_comp_auto_acc_flags = A[0] |
      uvm_comp_auto_acc_flags!(A[1..$]);
  }
  else {
    enum int uvm_comp_auto_acc_flags = uvm_comp_auto_acc_flags!(A[1..$]);
  }
}
