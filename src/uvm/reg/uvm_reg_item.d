//
//--------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010 Mentor Graphics Corporation
//    Copyright 2015 Coverify Systems Technology
//    All Rights Reserved Worldwide
//
//    Licensed under the Apache License, Version 2.0 (the
//    "License"); you may not use this file except in
//    compliance with the License.  You may obtain a copy of
//    the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in
//    writing, software distributed under the License is
//    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//    CONDITIONS OF ANY KIND, either express or implied.  See
//    the License for the specific language governing
//    permissions and limitations under the License.
//--------------------------------------------------------------
//

module uvm.reg.uvm_reg_item;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_object_defines;

import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequence_item;

import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_mem;
import uvm.reg.uvm_reg_file;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_field;
import uvm.reg.uvm_reg_sequence;
import uvm.reg.uvm_reg_backdoor;

import uvm.meta.misc;

import std.conv: to;
import std.string: format;

//------------------------------------------------------------------------------
// Title: Generic Register Operation Descriptors
//
// This section defines the abtract register transaction item. It also defines
// a descriptor for a physical bus operation that is used by <uvm_reg_adapter>
// subtypes to convert from a protocol-specific address/data/rw operation to
// a bus-independent, canonical r/w operation.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// CLASS: uvm_reg_item
//
// Defines an abstract register transaction item. No bus-specific information
// is present, although a handle to a <uvm_reg_map> is provided in case a user
// wishes to implement a custom address translation algorithm.
//------------------------------------------------------------------------------

class uvm_reg_item: uvm_sequence_item
{
  import esdl.rand;
  mixin uvm_object_utils;

  mixin(uvm_sync_string);

  // Variable: element_kind
  //
  // Kind of element being accessed: REG, MEM, or FIELD. See <uvm_elem_kind_e>.
  //
  @uvm_public_sync
  uvm_elem_kind_e _element_kind;


  // Variable: element
  //
  // A handle to the RegModel model element associated with this transaction.
  // Use <element_kind> to determine the type to cast  to: <uvm_reg>,
  // <uvm_mem>, or <uvm_reg_field>.
  //
  @uvm_public_sync
  uvm_object _element;


  // Variable: kind
  //
  // Kind of access: READ or WRITE.
  //
  @uvm_public_sync
  @rand uvm_access_e _kind;


  // Variable: value
  //
  // The value to write to, or after completion, the value read from the DUT.
  // Burst operations use the <values> property.
  //
  @rand!1024 uvm_reg_data_t[] _value;

  uvm_reg_data_t[] get_value() {
    synchronized(this) {
      return _value.dup;
    }
  }
  
  uvm_reg_data_t get_value(size_t index) {
    synchronized(this) {
      return _value[index];
    }
  }
  
  void set_value(uvm_reg_data_t[] val) {
    synchronized(this) {
      _value = val;
    }
  }
  
  void set_value(T)(size_t index, T val) {
    synchronized(this) {
      _value[index] = val;
    }
  }
  
  void and_value(T)(size_t index, T val) {
    synchronized(this) {
      _value[index] &= val;
    }
  }
  
  size_t num_values() {
    synchronized(this) {
      return _value.length;
    }
  }
  


  // TODO: parameterize
  Constraint! q{
    _value.length > 0 && _value.length < 1000;
  } max_values;

    // Variable: offset
    //
    // For memory accesses, the offset address. For bursts,
    // the ~starting~ offset address.
    //
  @uvm_public_sync
  @rand uvm_reg_addr_t _offset;


  // Variable: status
  //
  // The result of the transaction: IS_OK, HAS_X, or ERROR.
  // See <uvm_status_e>.
  //
  @uvm_public_sync
  uvm_status_e _status;


  // Variable: local_map
  //
  // The local map used to obtain addresses. Users may customize
  // address-translation using this map. Access to the sequencer
  // and bus adapter can be obtained by getting this map's root map,
  // then calling <uvm_reg_map::get_sequencer> and
  // <uvm_reg_map::get_adapter>.
  //
  @uvm_public_sync
  uvm_reg_map _local_map;


  // Variable: map
  //
  // The original map specified for the operation. The actual <map>
  // used may differ when a test or sequence written at the block
  // level is reused at the system level.
  //
  @uvm_public_sync
  uvm_reg_map _map;


  // Variable: path
  //
  // The path being used: <UVM_FRONTDOOR> or <UVM_BACKDOOR>.
  //
  @uvm_public_sync
  uvm_path_e _path;


  // Variable: parent
  //
  // The sequence from which the operation originated.
  //
  @uvm_public_sync
  @rand uvm_sequence_base _parent;


  // Variable: prior
  //
  // The priority requested of this transfer, as defined by
  // <uvm_sequence_base::start_item>.
  //
  @uvm_public_sync
  int _prior = -1;


  // Variable: extension
  //
  // Handle to optional user data, as conveyed in the call to
  // write(), read(), mirror(), or update() used to trigger the operation.
  //
  @uvm_public_sync
  @rand uvm_object _extension;


  // Variable: bd_kind
  //
  // If path is UVM_BACKDOOR, this member specifies the abstraction
  // kind for the backdoor access, e.g. "RTL" or "GATES".
  //
  @uvm_public_sync
  string _bd_kind;


  // Variable: fname
  //
  // The file name from where this transaction originated, if provided
  // at the call site.
  //
  @uvm_public_sync
  string _fname;


  // Variable: lineno
  //
  // The file name from where this transaction originated, if provided
  // at the call site.
  //
  @uvm_public_sync
  int _lineno;


  // Function: new
  //
  // Create a new instance of this type, giving it the optional ~name~.
  //
  this(string name="") {
    synchronized(this) {
      super(name);
      _value.length = 1; //  = new[1];
    }
  }


  // Function: convert2string
  //
  // Returns a string showing the contents of this transaction.
  //
  override string convert2string() {
    synchronized(this) {
      string s = "kind=" ~ kind.to!string ~
	" ele_kind=" ~ element_kind.to!string ~
	" ele_name=" ~ (element is null? "null" : element.get_full_name());

      char[] value_s;
      if (_value.length > 1 &&
	  uvm_report_enabled(uvm_verbosity.UVM_HIGH, uvm_severity.UVM_INFO, "RegModel")) {
	value_s = cast(char[]) "'{";
	foreach (v; _value) {
	  value_s ~= cast(char[]) format("%0h,", v);
	}
	value_s[$-1] = '}';
      }
      else {
	value_s = cast(char[]) format("%0h", _value[0]);
      }
      s ~= " value=" ~ value_s;

      if (_element_kind == UVM_MEM) {
	s ~= format(" offset=%0h", _offset);
      }
      s ~= " map=" ~ (_map is null ? "null" : _map.get_full_name()) ~
	" path=" ~ _path.to!string;
      s ~= " status=" ~ _status.to!string;
      return s;
    }
  }

  // Function: do_copy
  //
  // Copy the ~rhs~ object into this object. The ~rhs~ object must
  // derive from <uvm_reg_item>.
  //
  override void do_copy(uvm_object rhs) {
    if (rhs is null) {
      uvm_fatal("REG/NULL","do_copy: rhs argument is null");
    }

    uvm_reg_item rhs_ = cast(uvm_reg_item) rhs;
    if (rhs is null) {
      uvm_error("WRONG_TYPE","Provided rhs is not of type uvm_reg_item");
      return;
    }

    synchronized(this) {
      synchronized(rhs) {
	super.copy(rhs);
	_element_kind = rhs_.element_kind;
	_element = rhs_.element;
	_kind = rhs_.kind;
	_value = rhs_.get_value();
	_offset = rhs_.offset;
	_status = rhs_.status;
	_local_map = rhs_.local_map;
	_map = rhs_.map;
	_path = rhs_.path;
	_extension = rhs_.extension;
	_bd_kind = rhs_.bd_kind;
	_parent = rhs_.parent;
	_prior = rhs_.prior;
	_fname = rhs_.fname;
	_lineno = rhs_.lineno;
      }
    }
  }
}



//------------------------------------------------------------------------------
//
// CLASS: uvm_reg_bus_op
//
// Struct that defines a generic bus transaction for register and memory accesses, having
// ~kind~ (read or write), ~address~, ~data~, and ~byte enable~ information.
// If the bus is narrower than the register or memory location being accessed,
// there will be multiple of these bus operations for every abstract
// <uvm_reg_item> transaction. In this case, ~data~ represents the portion
// of <uvm_reg_item::value> being transferred during this bus cycle.
// If the bus is wide enough to perform the register or memory operation in
// a single cycle, ~data~ will be the same as <uvm_reg_item::value>.
//------------------------------------------------------------------------------

struct uvm_reg_bus_op {

  // Variable: kind
  //
  // Kind of access: READ or WRITE.
  //
  uvm_access_e kind;


  // Variable: addr
  //
  // The bus address.
  //
  uvm_reg_addr_t addr;


  // Variable: data
  //
  // The data to write. If the bus width is smaller than the register or
  // memory width, ~data~ represents only the portion of ~value~ that is
  // being transferred this bus cycle.
  //
  uvm_reg_data_t data;


  // Variable: n_bits
  //
  // The number of bits of <uvm_reg_item::value> being transferred by
  // this transaction.

  int n_bits;

  /*
    constraint valid_n_bits {
    n_bits > 0;
    n_bits <= `UVM_REG_DATA_WIDTH;
    }
  */


  // Variable: byte_en
  //
  // Enables for the byte lanes on the bus. Meaningful only when the
  // bus supports byte enables and the operation originates from a field
  // write/read.
  //
  uvm_reg_byte_en_t byte_en;


  // Variable: status
  //
  // The result of the transaction: UVM_IS_OK, UVM_HAS_X, UVM_NOT_OK.
  // See <uvm_status_e>.
  //
  uvm_status_e status;

}
