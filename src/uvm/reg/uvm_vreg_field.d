//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2004-2018 Synopsys, Inc.
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
// -------------------------------------------------------------
//

module uvm.reg.uvm_vreg_field;
import uvm.reg.uvm_vreg: uvm_vreg;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_defines;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_comparer: uvm_comparer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_globals: uvm_error,
  uvm_warning, uvm_info;
import uvm.base.uvm_callback: uvm_register_cb,
  uvm_callback, uvm_callbacks, uvm_callback_iter;

import uvm.base.uvm_object_defines;

import uvm.meta.misc;

import uvm.seq.uvm_sequence_base;

import esdl.rand;

import std.string: format;

//------------------------------------------------------------------------------
// Title -- NODOCS -- Virtual Register Field Classes
//
// This section defines the virtual field and callback classes.
//
// A virtual field is set of contiguous bits in one or more memory locations.
// The semantics and layout of virtual fields comes from
// an agreement between the software and the hardware,
// not any physical structures in the DUT.
//
//------------------------------------------------------------------------------

// typedef class uvm_vreg_field_cbs;


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_vreg_field
//
// Virtual field abstraction class
//
// A virtual field represents a set of adjacent bits that are
// logically implemented in consecutive memory locations.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 18.10.1
class uvm_vreg_field: uvm_object
{

  mixin uvm_object_utils;

  mixin uvm_sync;

  mixin uvm_register_cb!uvm_vreg_field_cbs;

  @uvm_private_sync
  private uvm_vreg _parent;
  @uvm_private_sync
  private uint _lsb;
  @uvm_private_sync
  private uint _size;
  @uvm_private_sync
  private string _fname;
  @uvm_private_sync
  private int _lineno;
  @uvm_private_sync
  private bool _read_in_progress;
  @uvm_private_sync
  private bool _write_in_progress;

  //
  // Group -- NODOCS -- initialization
  //

  // @uvm-ieee 1800.2-2020 auto 18.10.2.1
  this(string name="uvm_vreg_field") {
    synchronized(this) {
      super(name);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.2.2
  void configure(uvm_vreg  parent,
		 uint  size,
		 uint  lsb_pos) {
    synchronized(this) {
      this._parent = parent;
      if (size == 0) {
	uvm_error("RegModel", format("Virtual field \"%s\" cannot have" ~
				     " 0 bits", this.get_full_name()));
	size = 1;
      }
      if (size > UVM_REG_DATA_WIDTH) {
	uvm_error("RegModel", format("Virtual field \"%s\" cannot have more" ~
				     " than %0d bits", this.get_full_name(),
				     UVM_REG_DATA_WIDTH));
	size = UVM_REG_DATA_WIDTH;
      }

      this._size   = size;
      this._lsb    = lsb_pos;

      this._parent.add_field(this);
    }
  }

  //
  // Group -- NODOCS -- Introspection
  //

  //
  // Function -- NODOCS -- get_name
  // Get the simple name
  //
  // Return the simple object name of this virtual field
  //

  //
  // Function -- NODOCS -- get_full_name
  // Get the hierarchical name
  //
  // Return the hierarchal name of this virtual field
  // The base of the hierarchical name is the root block.
  //
  override string get_full_name() {
    synchronized(this) {
      return this._parent.get_full_name() ~ "." ~ this.get_name();
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.3.1
  uvm_vreg get_parent() {
    synchronized(this) {
      return this._parent;
    }
  }

  uvm_vreg get_register() {
    synchronized(this) {
      return this._parent;
    }
  }

  //
  // FUNCTION -- NODOCS -- get_lsb_pos_in_register
  // Return the position of the virtual field
  ///
  // Returns the index of the least significant bit of the virtual field
  // in the virtual register that instantiates it.
  // An offset of 0 indicates a field that is aligned with the
  // least-significant bit of the register.
  //
  uint get_lsb_pos_in_register() {
    synchronized(this) {
      return this._lsb;
    }
  }


  //
  // FUNCTION -- NODOCS -- get_n_bits
  // Returns the width, in bits, of the virtual field.
  //

  uint get_n_bits() {
    synchronized(this) {
      return this._size;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.3.4
  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      if (this._parent.get_memory() is null) {
	uvm_error("RegModel",
		  format("Cannot call uvm_vreg_field::get_rights() on" ~
			 " unimplemented virtual field \"%s\"",
			 this.get_full_name()));
	return "RW";
      }

      return this._parent.get_access(map);
    }
  }


  //
  // Group -- NODOCS -- HDL Access
  //

  // @uvm-ieee 1800.2-2020 auto 18.10.4.1
  // task
  void write(ulong               idx,
	     out uvm_status_e    status,
	     uvm_reg_data_t      value,
	     uvm_door_e          path = uvm_door_e.UVM_DEFAULT_DOOR,
	     uvm_reg_map         map = null,
	     uvm_sequence_base   parent = null,
	     uvm_object          extension = null,
	     string              fname = "",
	     int                 lineno = 0) {

    uvm_vreg_field_cb_iter cbs = new uvm_vreg_field_cb_iter(this);

    this.fname = fname;
    this.lineno = lineno;

    write_in_progress = true;
    uvm_mem mem = this.parent.get_memory();

    if (mem is null) {
      uvm_error("RegModel", format("Cannot call uvm_vreg_field::write() on" ~
				   " unimplemented virtual register \"%s\"",
				   this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    if (path == UVM_DEFAULT_DOOR) {
      uvm_reg_block blk = this.parent.get_block();
      path = blk.get_default_door();
    }

    status = UVM_IS_OK;

    this.parent.XatomicX(1);

    if (value >> this.size) {
      uvm_warning("RegModel", format("Writing value 0x%x that is greater" ~
				     " than field \"%s\" size (%0d bits)",
				     value, this.get_full_name(),
				     this.get_n_bits()));
      value &= ((UVM_REG_DATA_1 << this.size) - 1);
    }
    uvm_reg_data_t  tmp = 0;

    this.pre_write(idx, value, path, map);
    for (uvm_vreg_field_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.pre_write(this, idx, value, path, map);
    }

    int segsiz = mem.get_n_bytes() * 8;
    int flsb    = this.get_lsb_pos_in_register();
    uvm_reg_addr_t  segoff = cast(uvm_reg_addr_t)
      (this.parent.get_offset_in_memory(idx) + (flsb / segsiz));

    // Favor backdoor read to frontdoor read for the RMW operation
    uvm_door_e rm_path = uvm_door_e.UVM_DEFAULT_DOOR;
    if (mem.get_backdoor() !is null) rm_path = UVM_BACKDOOR;

    // Any bits on the LSB side we need to RMW?
    int rmwbits = flsb % segsiz;

    // Total number of memory segment in this field
    int segn = (rmwbits + this.get_n_bits() - 1) / segsiz + 1;

    uvm_status_e st;
    if (rmwbits > 0) {
      // uvm_reg_addr_t  segn;

      mem.read(st, segoff, tmp, rm_path, map, parent, -1,
	       extension, fname, lineno);
      if (st != UVM_IS_OK && st != UVM_HAS_X) {
	uvm_error("RegModel",
		  format("Unable to read LSB bits in %s[%0d] to for RMW" ~
			 " cycle on virtual field %s.",
			 mem.get_full_name(), segoff, this.get_full_name()));
	status = UVM_NOT_OK;
	this.parent.XatomicX(0);
	return;
      }

      value = (value << rmwbits) | (tmp & ((UVM_REG_DATA_1 << rmwbits) - 1));
    }

    // Any bits on the MSB side we need to RMW?
    int fmsb = rmwbits + this.get_n_bits() - 1;
    rmwbits = (fmsb+1) % segsiz;
    if (rmwbits > 0) {
      if (segn > 0) {
	mem.read(st, cast(uvm_reg_addr_t) (segoff + segn - 1), tmp,
		 rm_path, map, parent, -1, extension, fname, lineno);
	if (st != UVM_IS_OK && st != UVM_HAS_X) {
	  uvm_error("RegModel",
		    format("Unable to read MSB bits in %s[%0d] to for RMW" ~
			   " cycle on virtual field %s.",
			   mem.get_full_name(), segoff+segn-1,
			   this.get_full_name()));
	  status = UVM_NOT_OK;
	  this.parent.XatomicX(0);
	  return;
	}
      }
      value |= (tmp & ~((UVM_REG_DATA_1 << rmwbits) - 1)) << ((segn-1)*segsiz);
    }

    // Now write each of the segments
    tmp = value;
    for (size_t i=0; i!=segn; ++i) {
      mem.write(st, segoff, tmp, path, map, parent, -1,
		extension, fname, lineno);
      if (st != UVM_IS_OK && st != UVM_HAS_X) status = UVM_NOT_OK;

      segoff++;
      tmp = tmp >> segsiz;
    }

    this.post_write(idx, value, path, map, status);
    for (uvm_vreg_field_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.post_write(this, idx, value, path, map, status);
    }

    this.parent.XatomicX(0);


    uvm_info("RegModel", format("Wrote virtual field \"%s\"[%0d] via %s" ~
				" with: 0x%x", this.get_full_name(), idx,
				(path == UVM_FRONTDOOR) ? "frontdoor" : "backdoor",
				value),uvm_verbosity.UVM_MEDIUM);

    write_in_progress = false;
    this.fname = "";
    this.lineno = 0;
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.4.2
  // task
  void read(ulong               idx,
	    out uvm_status_e    status,
	    out uvm_reg_data_t  value,
	    uvm_door_e          path = uvm_door_e.UVM_DEFAULT_DOOR,
	    uvm_reg_map         map = null,
	    uvm_sequence_base   parent = null,
	    uvm_object          extension = null,
	    string              fname = "",
	    int                 lineno = 0) {

    uvm_vreg_field_cb_iter cbs = new uvm_vreg_field_cb_iter(this);

    this.fname = fname;
    this.lineno = lineno;

    read_in_progress = true;

    uvm_mem mem = this.parent.get_memory();

    synchronized(this) {
      if (mem is null) {
	uvm_error("RegModel",
		  format("Cannot call uvm_vreg_field::read() on " ~
			 "unimplemented virtual register \"%s\"",
			 this.get_full_name()));
	status = UVM_NOT_OK;
	return;
      }

      if (path == UVM_DEFAULT_DOOR) {
	uvm_reg_block blk = this.parent.get_block();
	path = blk.get_default_door();
      }

      status = UVM_IS_OK;

      this.parent.XatomicX(1);

      value = 0;
    }
    
    this.pre_read(idx, path, map);

    for (uvm_vreg_field_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.pre_read(this, idx, path, map);
    }

    int segsiz = mem.get_n_bytes() * 8;
    int flsb = this.get_lsb_pos_in_register();
    uvm_reg_addr_t  segoff = cast(uvm_reg_addr_t)
      (this.parent.get_offset_in_memory(idx) + (flsb / segsiz));
    int lsb = flsb % segsiz;

    // Total number of memory segment in this field
    int segn = (lsb + this.get_n_bits() - 1) / segsiz + 1;

    // Read each of the segments, MSB first
    segoff += segn - 1;
    uvm_reg_data_t  tmp;
    uvm_status_e st;
    for (size_t i=0; i!=segn; ++i) {
      value = value << segsiz;

      mem.read(st, segoff, tmp, path, map, parent, -1, extension, fname, lineno);
      if (st != UVM_IS_OK && st != UVM_HAS_X) status = UVM_NOT_OK;

      segoff--;
      value |= tmp;
    }

    // Any bits on the LSB side we need to get rid of?
    value = value >> lsb;

    // Any bits on the MSB side we need to get rid of?
    value &= (UVM_REG_DATA_1 << this.get_n_bits()) - 1;

    this.post_read(idx, value, path, map, status);
    for (uvm_vreg_field_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      synchronized(this) {
	cb.fname = this.fname;
	cb.lineno = this.lineno;
      }
      cb.post_read(this, idx, value, path, map, status);
    }

    this.parent.XatomicX(0);

    uvm_info("RegModel", format("Read virtual field \"%s\"[%0d] via %s: 0x%x",
				this.get_full_name(), idx,
				(path == UVM_FRONTDOOR) ? "frontdoor" : "backdoor",
				value),uvm_verbosity.UVM_MEDIUM);


    read_in_progress = false;
    this.fname = "";
    this.lineno = 0;
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.4.3
  // task
  void poke(ulong             idx,
	    out uvm_status_e      status,
	    uvm_reg_data_t    value,
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {

    this.fname = fname;
    this.lineno = lineno;

    uvm_mem mem = this.parent.get_memory();
    if (mem is null) {
      uvm_error("RegModel",
		format("Cannot call uvm_vreg_field::poke() " ~
		       "on unimplemented virtual register \"%s\"",
		       this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    status = UVM_IS_OK;

    this.parent.XatomicX(1);

    if (value >> this.size) {
      uvm_warning("RegModel", format("Writing value 0x%x that is greater " ~
				     "than field \"%s\" size (%0d bits)",
				     value, this.get_full_name(),
				     this.get_n_bits()));
      value &= value & ((UVM_REG_DATA_1 << this.size) - 1);
    }
    uvm_reg_data_t  tmp = 0;

    int segsiz = mem.get_n_bytes() * 8;
    int flsb = this.get_lsb_pos_in_register();
    uvm_reg_addr_t  segoff = cast(uvm_reg_addr_t)
      (this.parent.get_offset_in_memory(idx) + (flsb / segsiz));

    // Any bits on the LSB side we need to RMW?
    int rmwbits = flsb % segsiz;

    // Total number of memory segment in this field
    int segn = (rmwbits + this.get_n_bits() - 1) / segsiz + 1;

    uvm_status_e st;
    if (rmwbits > 0) {
      // uvm_reg_addr_t  segn;

      mem.peek(st, segoff, tmp, "", parent, extension, fname, lineno);
      if (st != UVM_IS_OK && st != UVM_HAS_X) {
	uvm_error("RegModel",
		  format("Unable to read LSB bits in %s[%0d] to " ~
			 "for RMW cycle on virtual field %s.",
			 mem.get_full_name(), segoff,
			 this.get_full_name()));
	status = UVM_NOT_OK;
	this.parent.XatomicX(0);
	return;
      }

      value = (value << rmwbits) | (tmp & ((UVM_REG_DATA_1 << rmwbits) - 1));
    }

    // Any bits on the MSB side we need to RMW?
    int fmsb = rmwbits + this.get_n_bits() - 1;
    rmwbits = (fmsb+1) % segsiz;
    if (rmwbits > 0) {
      if (segn > 0) {
	mem.peek(st, cast(uvm_reg_addr_t) (segoff + segn - 1), tmp,
		 "", parent, extension, fname, lineno);
	if (st != UVM_IS_OK && st != UVM_HAS_X) {
	  uvm_error("RegModel",
		    format("Unable to read MSB bits in %s[%0d] to " ~
			   "for RMW cycle on virtual field %s.",
			   mem.get_full_name(), segoff+segn-1,
			   this.get_full_name()));
	  status = UVM_NOT_OK;
	  this.parent.XatomicX(0);
	  return;
	}
      }
      value |= (tmp & ~((UVM_REG_DATA_1 << rmwbits) - 1)) << ((segn-1)*segsiz);
    }

    // Now write each of the segments
    tmp = value;
    for (size_t i=0; i!=segn; ++i) {
      mem.poke(st, segoff, tmp, "", parent, extension, fname, lineno);
      if (st != UVM_IS_OK && st != UVM_HAS_X) status = UVM_NOT_OK;

      segoff++;
      tmp = tmp >> segsiz;
    }

    this.parent.XatomicX(0);

    uvm_info("RegModel", format("Wrote virtual field \"%s\"[%0d] with: 0x%x",
				this.get_full_name(), idx, value),uvm_verbosity.UVM_MEDIUM);

    this.fname = "";
    this.lineno = 0;
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.4.4
  // task
  void peek(ulong             idx,
	    out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {

    this.fname = fname;
    this.lineno = lineno;

    uvm_mem mem = this.parent.get_memory();
    if (mem is null) {
      uvm_error("RegModel",
		format("Cannot call uvm_vreg_field::peek() " ~
		       "on unimplemented virtual register \"%s\"",
		       this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    status = UVM_IS_OK;

    this.parent.XatomicX(1);

    value = 0;

    int segsiz = mem.get_n_bytes() * 8;
    int flsb    = this.get_lsb_pos_in_register();
    uvm_reg_addr_t  segoff = cast(uvm_reg_addr_t)
      (this.parent.get_offset_in_memory(idx) + (flsb / segsiz));
    int lsb = flsb % segsiz;

    // Total number of memory segment in this field
    int segn = (lsb + this.get_n_bits() - 1) / segsiz + 1;

    // Read each of the segments, MSB first
    segoff += segn - 1;
    uvm_reg_data_t  tmp;
    uvm_status_e st;
    for (size_t i=0; i!=segn; ++i) {
      value = value << segsiz;

      mem.peek(st, segoff, tmp, "", parent, extension, fname, lineno);

      if (st != UVM_IS_OK && st != UVM_HAS_X) status = UVM_NOT_OK;

      segoff--;
      value |= tmp;
    }

    // Any bits on the LSB side we need to get rid of?
    value = value >> lsb;

    // Any bits on the MSB side we need to get rid of?
    value &= (UVM_REG_DATA_1 << this.get_n_bits()) - 1;

    this.parent.XatomicX(0);

    uvm_info("RegModel",
	     format("Peeked virtual field \"%s\"[%0d]: 0x%x",
		    this.get_full_name(), idx, value),uvm_verbosity.UVM_MEDIUM);

    this.fname = "";
    this.lineno = 0;
  }

  //
  // Group -- NODOCS -- Callbacks
  //

  // @uvm-ieee 1800.2-2020 auto 18.10.5.1
  // task
  void pre_write(ulong              idx,
		 ref uvm_reg_data_t wdat,
		 ref uvm_door_e     path,
		 ref uvm_reg_map    map) { }

  // @uvm-ieee 1800.2-2020 auto 18.10.5.2
  // task
  void post_write(ulong             idx,
		  uvm_reg_data_t    wdat,
		  uvm_door_e        path,
		  uvm_reg_map       map,
		  ref uvm_status_e  status) { }

  // @uvm-ieee 1800.2-2020 auto 18.10.5.3
  // task
  void pre_read(ulong              idx,
		ref uvm_door_e     path,
		ref uvm_reg_map    map) { }

  // @uvm-ieee 1800.2-2020 auto 18.10.5.4
  // task
  void post_read(ulong              idx,
		 ref uvm_reg_data_t rdat,
		 uvm_door_e         path,
		 uvm_reg_map        map,
		 ref uvm_status_e   status) { }


  override void do_print (uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      printer.print_generic("initiator", _parent.get_type_name(),
			    -1, convert2string());
    }
  }

  override string convert2string() {
    synchronized(this) {
      string retval =
	format("%s[%0d-%0d]", this.get_name(),
	       this.get_lsb_pos_in_register() + this.get_n_bits() - 1,
	       this.get_lsb_pos_in_register());
      if (_read_in_progress == true) {
	retval ~= "\n";
	if (_fname != "" && _lineno != 0) {
	  retval ~= format("%s:%0d ", _fname, _lineno);
	}
	retval ~= "currently executing read method";
      }
      if ( _write_in_progress == true) {
	retval ~= "\n";
	if (_fname != "" && _lineno != 0) {
	  retval ~= format("%s:%0d ", _fname, _lineno);
	}
	retval ~= "currently executing write method";
      }
      return retval;
    }
  }

  override uvm_object clone() {
    return null;
  }

  override void do_copy   (uvm_object rhs) { }

  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    return false;
  }

  override void do_pack (uvm_packer packer) { }

  override void do_unpack (uvm_packer packer) { }
}

//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_vreg_field_cbs
//
// Pre/post read/write callback facade class
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 18.10.6.1
abstract class uvm_vreg_field_cbs: uvm_callback
{

  mixin uvm_abstract_object_utils;
  
  mixin uvm_sync;

  @uvm_public_sync
  private string _fname;
  @uvm_public_sync
  private int    _lineno;


  this(string name = "uvm_vreg_field_cbs") {
    synchronized(this) {
      super(name);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.10.6.2.1
  // task
  void pre_write(uvm_vreg_field     field,
		 ulong              idx,
		 ref uvm_reg_data_t wdat,
		 ref uvm_door_e     path,
		 ref uvm_reg_map    map) { }

  // @uvm-ieee 1800.2-2020 auto 18.10.6.2.2
  //task
  void post_write(uvm_vreg_field   field,
		  ulong            idx,
		  uvm_reg_data_t   wdat,
		  uvm_door_e       path,
		  uvm_reg_map      map,
		  ref uvm_status_e status) { }

  // @uvm-ieee 1800.2-2020 auto 18.10.6.2.3
  // task
  void pre_read(uvm_vreg_field    field,
		ulong             idx,
		ref uvm_door_e    path,
		ref uvm_reg_map   map) { }

  // @uvm-ieee 1800.2-2020 auto 18.10.6.2.4
  // task
  void post_read(uvm_vreg_field     field,
		 ulong              idx,
		 ref uvm_reg_data_t rdat,
		 uvm_door_e         path,
		 uvm_reg_map        map,
		 ref uvm_status_e   status) { }
}

//
// Type -- NODOCS -- uvm_vreg_field_cb
// Convenience callback type declaration
//
// Use this declaration to register virtual field callbacks rather than
// the more verbose parameterized class
//
alias uvm_vreg_field_cb = uvm_callbacks!(uvm_vreg_field, uvm_vreg_field_cbs);  /* @uvm-ieee 1800.2-2020 auto D.4.5.11*/

//
// Type -- NODOCS -- uvm_vreg_field_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered virtual field callbacks
// rather than the more verbose parameterized class
//
alias uvm_vreg_field_cb_iter = uvm_callback_iter!(uvm_vreg_field, uvm_vreg_field_cbs);  /* @uvm-ieee 1800.2-2020 auto D.4.5.12*/
