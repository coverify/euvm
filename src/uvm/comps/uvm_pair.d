//
//-----------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2011 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2015-2018 NVIDIA Corporation
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
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Title -- NODOCS -- uvm_pair classes
//-----------------------------------------------------------------------------
// This section defines container classes for handling value pairs.
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// Class -- NODOCS -- uvm_class_pair #(T1,T2)
//
// Container holding handles to two objects whose types are specified by the
// type parameters, T1 and T2.
//-----------------------------------------------------------------------------

module uvm.comps.uvm_pair;

import uvm.base;
import uvm.meta.meta;

import std.string: format;

class uvm_class_pair(T1=uvm_object, T2=T1): uvm_object
{
  alias uvm_class_pair!(T1, T2) this_type;

  mixin uvm_object_essentials;
  mixin uvm_type_name_decl;
  
  // Variable -- NODOCS -- T1 first
  //
  // The handle to the first object in the pair

  T1 first;

  // Variable -- NODOCS -- T2 second
  //
  // The handle to the second object in the pair

  T2 second;

  // Function -- NODOCS -- new
  //
  // Creates an instance that holds a handle to two objects.
  // The optional name argument gives a name to the new pair object.

  this(string name="", T1 f=null, T2 s=null) {
    synchronized(this) {
      super(name);

      if (f is null) first = new T1;
      else first = f;

      if (s is null) second = new T2;
      else second = s;
    }
  }

  string convert2string() {
    string s = format("pair : %s, %s",
		      first.convert2string(), second.convert2string());
    return s;
  }

  bool do_compare(uvm_object rhs, uvm_comparer comparer) {
    this_type rhs_ = cast(this_type) rhs;
    if(rhs is null) {
      uvm_error("WRONG_TYPE",
		"do_compare: rhs argument is not of type '" ~
		get_type_name() ~ "'");
      return false;
    }
    return first.compare(rhs_.first) && second.compare(rhs_.second);
  }

  void do_copy(uvm_object rhs) {
    this_type rhs_ = cast(this_type) rhs;
    if(rhs is null) {
      uvm_fatal("WRONG_TYPE",
		"do_compare: rhs argument is not of type '" ~
		get_type_name() ~ "'");
    }
    first.copy(rhs_.first);
    second.copy(rhs_.second);
  }

};

//-----------------------------------------------------------------------------
// CLASS -- NODOCS -- uvm_built_in_pair #(T1,T2)
//
// Container holding two variables of built-in types (int, string, etc.). The
// types are specified by the type parameters, T1 and T2.
//-----------------------------------------------------------------------------

class uvm_built_in_pair (T1=int, T2=T1): uvm_object
{
  alias this_type = uvm_built_in_pair!(T1,T2);

  mixin uvm_object_essentials;
  mixin uvm_type_name_decl;

  // Variable -- NODOCS -- T1 first
  //
  // The first value in the pair

  T1 first;

  // Variable -- NODOCS -- T2 second
  //
  // The second value in the pair

  T2 second;

  // Function -- NODOCS -- new
  //
  // Creates an instance that holds two built-in type values.
  // The optional name argument gives a name to the new pair object.

  this(string name="") {
    super(name);
  }

  override string convert2string() {
    string s = format("built-in pair: %s, %s", first, second);
    // `ifdef UVM_USE_P_FORMAT
    //   $sformat(s, "built-in pair : %p, %p", first, second);
    // `else
    //   $swrite( s, "built-in pair : ", first, ", ", second);
    // `endif
    return s;
  }

  override bool do_compare(uvm_object rhs, uvm_comparer comparer) {
    this_type rhs_ = cast(this_type) rhs;
    if(rhs is null) {
      uvm_error("WRONG_TYPE",
		"do_compare: rhs argument is not of type '" ~
		get_type_name() ~ "'");
      return false;
    }
    return first == rhs_.first && second == rhs_.second;
  }

  override void do_copy (uvm_object rhs) {
    this_type rhs_ = cast(this_type) rhs;
    if(rhs is null) {
      uvm_fatal("WRONG_TYPE",
		"do_compare: rhs argument is not of type '" ~
		get_type_name() ~ "'");
    }
    first = rhs_.first;
    second = rhs_.second;
  }
}
