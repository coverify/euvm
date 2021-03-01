//
//--------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2004-2018 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2014-2018 NVIDIA Corporation
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

import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_model;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_verbosity,
  uvm_severity;
import uvm.base.uvm_object_defines;

import uvm.seq.uvm_sequence_base: uvm_sequence_base;
import uvm.seq.uvm_sequence_item: uvm_sequence_item;

import uvm.meta.misc;

import std.conv: to;
import std.string: format;

//------------------------------------------------------------------------------
// Title -- NODOCS -- Generic Register Operation Descriptors
//
// This section defines the abtract register transaction item. It also defines
// a descriptor for a physical bus operation that is used by <uvm_reg_adapter>
// subtypes to convert from a protocol-specific address/data/rw operation to
// a bus-independent, canonical r/w operation.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// CLASS -- NODOCS -- uvm_reg_item
//
// Defines an abstract register transaction item. No bus-specific information
// is present, although a handle to a <uvm_reg_map> is provided in case a user
// wishes to implement a custom address translation algorithm.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 19.1.1.1
class uvm_reg_item: uvm_sequence_item
{
  import esdl.rand;
  mixin uvm_object_utils;

  mixin (uvm_sync_string);

  // Variable -- NODOCS -- element_kind
  //
  // Kind of element being accessed: REG, MEM, or FIELD. See <uvm_elem_kind_e>.
  //
  @uvm_public_sync
  private uvm_elem_kind_e _element_kind;

  // Variable -- NODOCS -- element
  //
  // A handle to the RegModel model element associated with this transaction.
  // Use <element_kind> to determine the type to cast  to: <uvm_reg>,
  // <uvm_mem>, or <uvm_reg_field>.
  //
  @uvm_public_sync
  private uvm_object _element;

  // Variable -- NODOCS -- kind
  //
  // Kind of access: READ or WRITE.
  //
  @uvm_public_sync
  private @rand uvm_access_e _kind;


  // Variable -- NODOCS -- value
  //
  // The value to write to, or after completion, the value read from the DUT.
  // Burst operations use the <values> property.
  //
  @uvm_public_sync
  private @rand(1024) uvm_reg_data_t[] _value;

  void and_value(uvm_reg_data_t val, size_t idx) {
    synchronized(this) {
      _value[idx] &= val;
    }
  }
  

  // TODO -- NODOCS -- parameterize
  Constraint! q{
    _value.length > 0 && _value.length < 1000;
  } max_values;

  // Variable -- NODOCS -- offset
  //
  // For memory accesses, the offset address. For bursts,
  // the ~starting~ offset address.
  //
  @uvm_public_sync
  private @rand uvm_reg_addr_t _offset;

  // Variable -- NODOCS -- status
  //
  // The result of the transaction: IS_OK, HAS_X, or ERROR.
  // See <uvm_status_e>.
  //
  @uvm_public_sync
  private uvm_status_e _status;

  // Variable -- NODOCS -- local_map
  //
  // The local map used to obtain addresses. Users may customize
  // address-translation using this map. Access to the sequencer
  // and bus adapter can be obtained by getting this map's root map,
  // then calling <uvm_reg_map::get_sequencer> and
  // <uvm_reg_map::get_adapter>.
  //
  @uvm_public_sync
  private uvm_reg_map _local_map;

  // Variable -- NODOCS -- map
  //
  // The original map specified for the operation. The actual <map>
  // used may differ when a test or sequence written at the block
  // level is reused at the system level.
  //
  @uvm_public_sync
  private uvm_reg_map _map;

  // Variable -- NODOCS -- path
  //
  // The path being used -- NODOCS -- <UVM_FRONTDOOR> or <UVM_BACKDOOR>.
  //
  @uvm_public_sync
  private uvm_door_e _door;

  // Variable -- NODOCS -- parent
  //
  // The sequence from which the operation originated.
  //
  @uvm_public_sync
  private @rand uvm_sequence_base _parent;

  // Variable -- NODOCS -- prior
  //
  // The priority requested of this transfer, as defined by
  // <uvm_sequence_base::start_item>.
  //
  @uvm_public_sync
  private int _prior = -1;

  // Variable -- NODOCS -- extension
  //
  // Handle to optional user data, as conveyed in the call to
  // write(), read(), mirror(), or update() used to trigger the operation.
  //
  @uvm_public_sync
  private @rand uvm_object _extension;

  // Variable -- NODOCS -- bd_kind
  //
  // If path is UVM_BACKDOOR, this member specifies the abstraction
  // kind for the backdoor access, e.g. "RTL" or "GATES".
  //
  @uvm_public_sync
  private string _bd_kind;

  // Variable -- NODOCS -- fname
  //
  // The file name from where this transaction originated, if provided
  // at the call site.
  //
  @uvm_public_sync
  private string _fname;

  // Variable -- NODOCS -- lineno
  //
  // The file name from where this transaction originated, if provided
  // at the call site.
  //
  @uvm_public_sync
  private int _lineno;

  // @uvm-ieee 1800.2-2017 auto 19.1.1.3.1
  this(string name="") {
    synchronized(this) {
      super(name);
      _value.length = 1; //  = new[1];
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.3.2
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
	" path=" ~ _door.to!string;
      s ~= " status=" ~ _status.to!string;
      return s;
    }
  }

  // Function -- NODOCS -- do_copy
  //
  // Copy the ~rhs~ object into this object. The ~rhs~ object must
  // derive from <uvm_reg_item>.
  //
  override void do_copy(uvm_object rhs) {
    if (rhs is null) {
      uvm_fatal("REG/NULL","do_copy: rhs argument is null");
    }

    uvm_reg_item rhs_ = cast(uvm_reg_item) rhs;
    if (rhs_ is null) {
      uvm_error("WRONG_TYPE","Provided rhs is not of type uvm_reg_item");
      return;
    }

    synchronized(this) {
      synchronized(rhs_) {
	super.do_copy(rhs_);
	set_element_kind(rhs_.get_element_kind());
	set_element(rhs_.get_element());
	set_kind(rhs_.get_kind());
	set_value(rhs_.get_value());
	set_offset(rhs_.get_offset());
	set_status(rhs_.get_status());
	set_local_map(rhs_.get_local_map());
	set_map(rhs_.get_map());
	set_door(rhs_.get_door());
	set_extension(rhs_.get_extension());
	set_bd_kind(rhs_.get_bd_kind());
	set_parent_sequence(rhs_.get_parent_sequence());
	set_priority(rhs_.get_priority());
	set_fname(rhs_.get_fname());
	set_line(rhs_.get_line());
      }
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.1
  void set_element_kind(uvm_elem_kind_e element_kind) {
    synchronized(this) {
      this._element_kind = element_kind;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.1
  uvm_elem_kind_e get_element_kind() {
    synchronized(this) {
      return _element_kind;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.2
  void set_element(uvm_object element) {
    synchronized(this) {
      this._element = element;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.2
  uvm_object get_element() {
    synchronized(this) {
      return _element;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.3
  void set_kind(uvm_access_e kind) {
    synchronized(this) {
      this._kind = kind;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.3
  uvm_access_e get_kind() {
    synchronized(this) {
      return _kind;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.4
  void get_value_array(ref uvm_reg_data_t[] value) {
    synchronized(this) {
      value = _value.dup;
    }
  }
  uvm_reg_data_t[] get_value() {
    synchronized(this) {
      return _value.dup;
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.4
  uvm_reg_data_t get_value(size_t idx) {
    synchronized(this) {
      return _value[idx];
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.4
  void set_value_array(uvm_reg_data_t[] value) {
    synchronized(this) {
      this._value = value.dup;
    }
  }

  void set_value(uvm_reg_data_t[] val) {
    synchronized(this) {
      _value = val.dup;
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.4
  void set_value(uvm_reg_data_t val, size_t idx) {
    synchronized(this) {
      _value[idx] = val;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.4
  void set_value_size(size_t sz) {
    synchronized(this) {
      this._value.length = sz;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.4
  size_t get_value_size() {
    synchronized(this) {
      return this._value.length;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.5
  void set_offset(uvm_reg_addr_t offset) {
    synchronized(this) {
      this._offset = offset;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.5
  uvm_reg_addr_t get_offset() {
    synchronized(this) {
      return _offset;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.6
  void set_status(uvm_status_e status) {
    synchronized(this) {
      this._status = status;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.6
  uvm_status_e get_status() {
    synchronized(this) {
      return _status;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.7
  void set_local_map(uvm_reg_map map) {
    synchronized(this) {
      this._local_map = local_map;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.7
  uvm_reg_map get_local_map() {
    synchronized(this) {
      return _local_map;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.8
  void set_map(uvm_reg_map map) {
    synchronized(this) {
      this._map = map;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.8
  uvm_reg_map get_map() {
    synchronized(this) {
      return _map;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.9
  void set_door(uvm_door_e door) {
    synchronized(this) {
      this._door = door;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.9
  uvm_door_e get_door() {
    synchronized(this) {
      return _door;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.10
  override void set_parent_sequence(uvm_sequence_base parent) {
    synchronized(this) {
      this._parent = parent;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.10
  override uvm_sequence_base get_parent_sequence() {
    synchronized(this) {
      return _parent;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.11
  void set_priority(int value) {
    synchronized(this) {
      this._prior = value;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.11
  int get_priority() {
    synchronized(this) {
      return _prior;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.12
  void set_extension(uvm_object extension) {
    synchronized(this) {
      this._extension = extension;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.12
  uvm_object get_extension() {
    synchronized(this) {
      return _extension;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.13
  void set_bd_kind(string bd_kind) {
    synchronized(this) {
      this._bd_kind = bd_kind;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.13
  string get_bd_kind() {
    synchronized(this) {
      return _bd_kind;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.14
  void set_fname(string fname) {
    synchronized(this) {
      this._fname = fname;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.14
  string get_fname() {
    synchronized(this) {
      return _fname;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.15
  void set_line(int line) {
    synchronized(this) {
      this._lineno = line;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 19.1.1.2.15
  int get_line() {
    synchronized(this) {
      return _lineno;
    }
  }

  
}



//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_reg_bus_op
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

  uvm_access_e kind;


  uvm_reg_addr_t addr;


  uvm_reg_data_t data;


  int n_bits;

  /*
    constraint valid_n_bits {
    n_bits > 0;
    n_bits <= `UVM_REG_DATA_WIDTH;
    }
  */


  uvm_reg_byte_en_t byte_en;


  uvm_status_e status;

}
