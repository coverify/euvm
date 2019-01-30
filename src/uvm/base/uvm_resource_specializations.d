//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2018 NVIDIA Corporation
// Copyright 2017 Verific
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
//----------------------------------------------------------------------

// macro - UVM_RESOURCE_GET_FCNS

// When specicializing resources the get_by_name and get_by_type
// functions must be redefined.  The reason is that the version of these
// functions in the base class (uvm_resource#(T)) returns an object of
// type uvm_resource#(T).  In the specializations we must return an
// object of the type of the specialization.  So, we call the base_class
// implementation of these functions and then downcast to the subtype.
//
// This macro is invokved once in each where a resource specialization
// is a class defined as:
//
//|  class <resource_specialization>: uvm_resource#(T)
//
// where <resource_specialization> is the name of the derived class.
// The argument to this macro is T, the type of the uvm_resource#(T)
// specialization.  The class in which the macro is defined must supply
// a typedef of the specialized class of the form:
//
//|  typedef <resource_specialization> this_subtype;
//
// where <resource_specialization> is the same as above.  The macro
// generates the get_by_name() and get_by_type() functions for the
// specialized resource (i.e. resource subtype).

module uvm.base.uvm_resource_specializations;
import uvm.base.uvm_resource: uvm_resource, uvm_resource_pool;
import uvm.base.uvm_resource_base: uvm_resource_base;
import uvm.base.uvm_object: uvm_object;
import std.string: format;

mixin template UVM_RESOURCE_GET_FCNS(base_type)
{
  static this_subtype get_by_name(string rscope, string name,
				  bool rpterr = true) {
    import uvm.base.uvm_globals;
    uvm_resource_base b =
      uvm_resource!base_type.get_by_name(rscope, name, rpterr);
    this_subtype t = cast (this_subtype) b;
    if (t is null) {
      uvm_fatal("BADCAST", "cannot cast resource to resource subtype");
    }
    return t;
  }

  static this_subtype get_by_type(string rscope = "",
				  uvm_resource_base type_handle = null) {
    import uvm.base.uvm_globals;
    uvm_resource_base b =
      uvm_resource!base_type.get_by_type(rscope, type_handle);
    this_subtype t = cast (this_subtype) b;
    if (t is null) {
      uvm_fatal("BADCAST", "cannot cast resource to resource subtype");
    }
    return t;
  }
}


//----------------------------------------------------------------------
// uvm_int_rsrc
//
// specialization of uvm_resource #(T) for T = int
//----------------------------------------------------------------------
class uvm_int_rsrc: uvm_resource!int
{
  alias this_subtype = uvm_int_rsrc;

  this(string name, string s = "*") {
    super(name);
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set_scope(this, s);
  }

  string to(T)() if (is (T == string)) {
    return format("%0d", read());
  }

  override string convert2string() {
    return this.to!string;
  }

}

//----------------------------------------------------------------------
// uvm_string_rsrc
//
// specialization of uvm_resource #(T) for T = string
//----------------------------------------------------------------------
class uvm_string_rsrc: uvm_resource!string
{
  alias uvm_string_rsrc this_subtype;

  this(string name, string s = "*") {
    super(name);
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set_scope(this, s);
  }

  string to(T)() if (is (T == string)) {
    return read();
  }

  override string convert2string() {
    return this.to!string;
  }

}

//----------------------------------------------------------------------
// uvm_obj_rsrc
//
// specialization of uvm_resource #(T) for T = uvm_object
//----------------------------------------------------------------------
class uvm_obj_rsrc: uvm_resource!uvm_object
{
  alias uvm_obj_rsrc this_subtype;

  this(string name, string s = "*") {
    super(name);
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set_scope(this, s);
  }

}

//----------------------------------------------------------------------
// uvm_bit_rsrc
//
// specialization of uvm_resource #(T) for T = vector of bits
//----------------------------------------------------------------------
class uvm_bit_rsrc(size_t N=1): uvm_resource!(UBit!N)
{
  alias uvm_bit_rsrc!N this_subtype;

  this(string name, string s = "*") {
    super(name);
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set_scope(this, s);
  }

  string to(T)() if (is (T == string)) {
    return format("%0b", read());
  }

  override string convert2string() {
    return this.to!string;
  }

}

// This class is not used anywhere else in UVM baseclasses.
// We can code this once we have multi-dimensional Bits working

// //----------------------------------------------------------------------
// // uvm_byte_rsrc
// //
// // specialization of uvm_resource #T() for T = vector of bytes
// //----------------------------------------------------------------------
// class uvm_byte_rsrc #(int unsigned N=1) extends uvm_resource #(bit[7:0][N-1:0]);

//   typedef uvm_byte_rsrc#(N) this_subtype;

//   function new(string name, string s = "*");
//     uvm_resource_pool rp;
//     super.new(name);
//     rp = uvm_resource_pool::get();
//     rp.set_scope(this, s);
//   endfunction

//   function string convert2string();
//     string s;
//     $sformat(s, "%0x", read());
//     return s;
//   endfunction


// endclass
