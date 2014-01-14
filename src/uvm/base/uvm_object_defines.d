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
import uvm.base.uvm_registry: uvm_component_registry;
import uvm.base.uvm_factory: uvm_object_wrapper;

mixin template uvm_object_utils(T)
{
  mixin uvm_object_registry_mixin!(T, __MODULE__ ~ "." ~ T.stringof);
  mixin m_uvm_object_create_func!(T);
  mixin m_uvm_get_type_name_func!(T);
  // `uvm_field_utils_begin(T)
}


mixin template uvm_object_param_utils(T)
{
  mixin m_uvm_object_registry_param!(T);
  mixin m_uvm_object_create_func!(T);
  // `uvm_field_utils_begin(T)
}

mixin template uvm_component_utils(T)
{
  mixin uvm_component_registry_mixin!(T, T.stringof);
  mixin m_uvm_get_type_name_func!(T);
}

mixin template uvm_component_param_utils(T)
{
  mixin m_uvm_component_registry_param!(T);
}

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

mixin template m_uvm_object_registry_param(T)
{
  alias uvm_object_registry!T type_id;
  static public type_id get_type() {
    return type_id.get();
  }
  override public uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}


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

mixin template m_uvm_component_registry_param(T)
{
  alias uvm_component_registry!T type_id;
  static public type_id get_type() {
    return type_id.get();
  }
  override public uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
}
