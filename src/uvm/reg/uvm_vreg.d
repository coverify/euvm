//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2014 Semifore
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
module uvm.reg.uvm_vreg;

import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_defines;

import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_vreg_field: uvm_vreg_field, uvm_vreg_field_cb_iter,
  uvm_vreg_field_cbs;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_mem_mam: uvm_mem_mam, uvm_mem_region, uvm_mem_mam_policy;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_severity, uvm_verbosity;
import uvm.base.uvm_callback: uvm_callback, uvm_callbacks, uvm_callback_iter,
  uvm_register_cb;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_comparer: uvm_comparer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_globals: uvm_error, uvm_fatal, uvm_warning, uvm_info;
import uvm.base.uvm_entity: uvm_entity_base;

import uvm.seq.uvm_sequence_base: uvm_sequence_base;

import uvm.meta.misc;

import esdl.data.bvec;
import esdl.base.comm: SemaphoreObj;
import esdl.rand;

import std.string: format;

//------------------------------------------------------------------------------
// Title -- NODOCS -- Virtual Registers
//------------------------------------------------------------------------------
//
// A virtual register is a collection of fields,
// overlaid on top of a memory, usually in an array.
// The semantics and layout of virtual registers comes from
// an agreement between the software and the hardware,
// not any physical structures in the DUT.
//
//------------------------------------------------------------------------------

// typedef class uvm_mem_region;
// typedef class uvm_mem_mam;

// typedef class uvm_vreg_cbs;


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_vreg
//
// Virtual register abstraction base class
//
// A virtual register represents a set of fields that are
// logically implemented in consecutive memory locations.
//
// All virtual register accesses eventually turn into memory accesses.
//
// A virtual register array may be implemented on top of
// any memory abstraction class and possibly dynamically
// resized and/or relocated.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 18.9.1
class uvm_vreg: uvm_object, rand.barrier
{
  mixin uvm_sync;

  mixin uvm_register_cb!uvm_vreg_cbs;
  
  @uvm_private_sync
  private bool _locked;
  @uvm_private_sync
  private uvm_reg_block _parent;
  @uvm_private_sync
  private uint _n_bits;
  @uvm_private_sync
  private uint  _n_used_bits;

  @uvm_private_sync
  private uvm_vreg_field[] _fields; // Fields in LSB to MSB order

  @uvm_private_sync
  private uvm_mem          _mem;	   // Where is it implemented?
  @uvm_private_sync
  private uvm_reg_addr_t   _offset; // Start of vreg[0]
  @uvm_private_sync
  private uint     _incr;    // From start to start of next
  @uvm_private_sync
  private uint     _size;	    //number of vregs
  @uvm_private_sync
  private bool              _is_static;

  @uvm_private_sync
  private uvm_mem_region   _region; // Not NULL if implemented via MAM

  @uvm_private_sync
  private SemaphoreObj _atomic;	// Field RMW operations must be atomic
  @uvm_private_sync
  private string _fname;
  @uvm_private_sync
  private int _lineno;
  @uvm_private_sync
  private bool _read_in_progress;
  @uvm_private_sync
  private bool _write_in_progress;

  //
  // Group -- NODOCS -- Initialization
  //


  // @uvm-ieee 1800.2-2020 auto 18.9.1.1.1
  this(string name, uint n_bits) {
    synchronized(this) {
      super(name);

      if (n_bits == 0) {
	uvm_error("RegModel",
		  format(q{Virtual register "%s" cannot have 0 bits},
			 this.get_full_name()));
	n_bits = 1;
      }
      if (n_bits > UVM_REG_DATA_WIDTH) {
	uvm_error("RegModel",
		  format(q{Virtual register "%s" cannot have more} ~
			 " than %0d bits (%0d)", this.get_full_name(),
			 UVM_REG_DATA_WIDTH, n_bits));
	n_bits = UVM_REG_DATA_WIDTH;
      }
      this._n_bits = n_bits;

      this._locked = false;

    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.1.2
  public void configure(uvm_reg_block      parent,
			uvm_mem            mem = null,
			uint               size = 0,
			uvm_reg_addr_t     offset = 0,
			uint               incr = 0) {
    synchronized(this) {
      this._parent = parent;

      this._n_used_bits = 0;

      if (mem !is null) {
	this.implement(size, mem, offset, incr);
	this._is_static = true;
      }
      else {
	this._mem = null;
	this._is_static = false;
      }
      this._parent.add_vreg(this);

      this._atomic = new SemaphoreObj(1, uvm_entity_base.get());
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.1.3
  bool implement(uint           n,
		 uvm_mem        mem = null,
		 uvm_reg_addr_t offset = 0,
		 uint           incr = 0) {
    synchronized(this) {
      uvm_mem_region region;

      if(n < 1) {
	uvm_error("RegModel", format("Attempting to implement virtual" ~
				     " register \"%s\" with a subscript" ~
				     " less than one doesn't make sense",
				     this.get_full_name()));
	return false;
      }

      if (mem is null) {
	uvm_error("RegModel", format("Attempting to implement virtual" ~
				     " register \"%s\" using a NULL uvm_mem" ~
				     " reference",
				     this.get_full_name()));
	return false;
      }

      if (this._is_static) {
	uvm_error("RegModel", format("Virtual register \"%s\" is static" ~
				     " and cannot be dynamically implemented",
				     this.get_full_name()));
	return false;
      }

      if (mem.get_block() !is this._parent) {
	uvm_error("RegModel", format("Attempting to implement virtual" ~
				     " register \"%s\" on memory \"%s\"" ~
				     " in a different block",
				     this.get_full_name(),
				     mem.get_full_name()));
	return false;
      }

      int min_incr = (this.get_n_bytes()-1) / mem.get_n_bytes() + 1;
      if (incr == 0) incr = min_incr;
      if (min_incr > incr) {
	uvm_error("RegModel", format("Virtual register \"%s\" increment" ~
				     " is too small (%0d): Each virtual" ~
				     " register requires at least %0d" ~
				     " locations in memory \"%s\".",
				     this.get_full_name(), incr,
				     min_incr, mem.get_full_name()));
	return false;
      }

      // Is the memory big enough for ya?
      if (offset + (n * incr) > mem.get_size()) {
	uvm_error("RegModel", format("Given Offset for Virtual register" ~
				     " \"%s[%0d]\" is too big for memory" ~
				     " %s@'h%0h",
				     this.get_full_name(), n,
				     mem.get_full_name(), offset));
	return false;
      }

      region = mem.mam.reserve_region(offset, n*incr*mem.get_n_bytes());

      if (region is null) {
	uvm_error("RegModel", format("Could not allocate a memory region" ~
				     " for virtual register \"%s\"",
				     this.get_full_name()));
	return false;
      }

      if (this._mem !is null) {
	uvm_info("RegModel", format("Virtual register \"%s\" is being moved" ~
				    " re-implemented from %s@'h%0h to %s@'h%0h",
				    this.get_full_name(),
				    this._mem.get_full_name(),
				    this._offset,
				    mem.get_full_name(), offset),uvm_verbosity.UVM_MEDIUM);
	this.release_region();
      }

      this._region = region;
      this._mem    = mem;
      this._size   = n;
      this._offset = offset;
      this._incr   = incr;
      this._mem.Xadd_vregX(this);

      return true;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.1.4
  uvm_mem_region allocate(uint n, uvm_mem_mam mam,
			  uvm_mem_mam_policy alloc=null) {
    synchronized(this) {
      uvm_mem_region retval;
      uvm_mem mem;

      if(n < 1) {

	uvm_error("RegModel", format("Attempting to implement virtual" ~
				     " register \"%s\" with a subscript" ~
				     " less than one doesn't make sense",
				     this.get_full_name()));
	return null;
      }

      if (mam is null) {
	uvm_error("RegModel", format("Attempting to implement virtual" ~
				     " register \"%s\" using a NULL" ~
				     " uvm_mem_mam reference",
				     this.get_full_name()));
	return null;
      }

      if (this._is_static) {
	uvm_error("RegModel", format("Virtual register \"%s\" is static" ~
				     " and cannot be dynamically allocated",
				     this.get_full_name()));
	return null;
      }

      mem = mam.get_memory();
      if (mem.get_block() !is this._parent) {
	uvm_error("RegModel", format("Attempting to allocate virtual" ~
				     " register \"%s\" on memory \"%s\"" ~
				     " in a different block",
				     this.get_full_name(),
				     mem.get_full_name()));
	return null;
      }

      int min_incr = (this.get_n_bytes()-1) / mem.get_n_bytes() + 1;
      if (incr == 0) incr = min_incr;
      if (min_incr < incr) {
	uvm_error("RegModel", format("Virtual register \"%s\" increment" ~
				     " is too small (%0d): Each virtual" ~
				     " register requires at least %0d" ~
				     " locations in memory \"%s\".",
				     this.get_full_name(), incr,
				     min_incr, mem.get_full_name()));
	return null;
      }

      // Need memory at least of size num_vregs*sizeof(vreg) in bytes.
      retval = mam.request_region(n*incr*mem.get_n_bytes());
      if (retval is null) {
	uvm_error("RegModel", format("Could not allocate a memory region" ~
				     " for virtual register \"%s\"",
				     this.get_full_name()));
	return null;
      }

      if (this._mem !is null) {
	uvm_info("RegModel", format("Virtual register \"%s\" is being moved" ~
				    " re-allocated from %s@'h%0h to %s@'h%0h",
				    this.get_full_name(),
				    this._mem.get_full_name(),
				    this._offset,
				    mem.get_full_name(),
				    retval.get_start_offset()),uvm_verbosity.UVM_MEDIUM);

	this.release_region();
      }

      this._region = retval;

      this._mem    = mam.get_memory();
      this._offset = retval.get_start_offset();
      this._size   = n;
      this._incr   = incr;

      this._mem.Xadd_vregX(this);
      return retval;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.1.5
  uvm_mem_region get_region() {
    synchronized(this) {
      return this._region;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.1.6
  void release_region() {
    synchronized(this) {
      if (this._is_static) {
	uvm_error("RegModel", format("Virtual register \"%s\" is static" ~
				     " and cannot be dynamically released",
				     this.get_full_name()));
	return;
      }

      if (this._mem !is null) {
	this._mem.Xdelete_vregX(this);
      }

      if (this._region !is null) {
	this._region.release_region();
      }

      this._region = null;
      this._mem    = null;
      this._size   = 0;
      this._offset = 0;

      this.reset();
    }
  }


  void set_parent(uvm_reg_block parent) {
    synchronized(this) {
      this._parent = parent;
    }
  }

  void Xlock_modelX() {
    synchronized(this) {
      if (this._locked) return;

      this._locked = true;
    }
  }


  void add_field(uvm_vreg_field field) {
    synchronized(this) {
      if (this._locked) {
	uvm_error("RegModel", "Cannot add virtual field to locked virtual" ~
		  " register model");
	return;
      }

      if (field is null) {
	uvm_fatal("RegModel", "Attempting to register NULL" ~
		  " virtual field");
      }

      // Store fields in LSB to MSB order
      int offset = field.get_lsb_pos_in_register();
      ptrdiff_t idx = -1;
      foreach (i, fd; this._fields) {
	if (offset < fd.get_lsb_pos_in_register()) {
	  // insert field at ith position
	  this._fields.length += 1;
	  this._fields[i+1..$] = this._fields[i..$-1];
	  this._fields[i] = field;
	  idx = i;
	  break;
	}
      }
      if (idx < 0) {
	this._fields ~= field;
	idx = this._fields.length-1;
      }

      this._n_used_bits += field.get_n_bits();

      // Check if there are too many fields in the register
      if (this._n_used_bits > this._n_bits) {
	uvm_error("RegModel", format("Virtual fields use more bits (%0d)" ~
				     " than available in virtual register" ~
				     " \"%s\" (%0d)",
				     this._n_used_bits, this.get_full_name(),
				     this._n_bits));
      }

      // Check if there are overlapping fields
      if (idx > 0) {
	if (this._fields[idx-1].get_lsb_pos_in_register() +
	    this._fields[idx-1].get_n_bits() > offset) {
	  uvm_error("RegModel", format("Field %s overlaps field %s in virtual" ~
				       " register \"%s\"",
				       this._fields[idx-1].get_name(),
				       field.get_name(),
				       this.get_full_name()));
	}
      }

      if (idx < this._fields.length-1) {
	if (offset + field.get_n_bits() >
	    this._fields[idx+1].get_lsb_pos_in_register()) {
	  uvm_error("RegModel", format("Field %s overlaps field %s in virtual" ~
				       " register \"%s\"",
				       field.get_name(),
				       this._fields[idx+1].get_name(),
				       this.get_full_name()));
	}
      }
    }
  }

  // task
  void XatomicX(bool on) {
    if (on) this.atomic.wait();
    else {
      // Maybe a key was put back in by a spurious call to reset()
      this.atomic.tryWait();
      this.atomic.post();
    }
  }

  //
  // Group -- NODOCS -- Introspection
  //

  //
  // Function -- NODOCS -- get_name
  // Get the simple name
  //
  // Return the simple object name of this register.
  //

  //
  // Function -- NODOCS -- get_full_name
  // Get the hierarchical name
  //
  // Return the hierarchal name of this register.
  // The base of the hierarchical name is the root block.
  //
  override string get_full_name() {
    synchronized(this) {
      uvm_reg_block blk;
      string retval;

      retval = this.get_name();

      // Do not include top-level name in full name
      blk = this.get_block();
      if (blk is null) return retval;
      if (blk.get_parent() is null) return retval;

      retval = this._parent.get_full_name() ~ "." ~ get_full_name;
      return retval;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.1
  uvm_reg_block get_parent() {
    synchronized(this) {
      return this._parent;
    }
  }

  uvm_reg_block get_block() {
    synchronized(this) {
      return this._parent;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.2
  uvm_mem get_memory() {
    synchronized(this) {
      return this._mem;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.3
  int get_n_maps() {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call get_n_maps() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }
      return this._mem.get_n_maps();
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.4
  bool is_in_map(uvm_reg_map map) {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call is_in_map() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return false;
      }

      return this._mem.is_in_map(map);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.5
  void get_maps(ref uvm_reg_map[] maps) {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call get_maps() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return;
      }
      this._mem.get_maps(maps);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.6
  string get_rights(uvm_reg_map map = null) {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call get_rights() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return "RW";
      }

      return this._mem.get_rights(map);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.7
  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call get_access() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return "RW";
      }

      return this._mem.get_access(map);
    }
  }

  //
  // FUNCTION -- NODOCS -- get_size
  // Returns the size of the virtual register array.
  //
  uint get_size() {
    synchronized(this) {
      if (this._size == 0) {
	uvm_error("RegModel", format("Cannot call get_size() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return this._size;
    }
  }


  //
  // FUNCTION -- NODOCS -- get_n_bytes
  // Returns the width, in bytes, of a virtual register.
  //
  // The width of a virtual register is always a multiple of the width
  // of the memory locations used to implement it.
  // For example, a virtual register containing two 1-byte fields
  // implemented in a memory with 4-bytes memory locations is 4-byte wide.
  //
  uint get_n_bytes() {
    synchronized(this) {
      return ((this._n_bits-1) / 8) + 1;
    }
  }

  //
  // FUNCTION -- NODOCS -- get_n_memlocs
  // Returns the number of memory locations used
  // by a single virtual register.
  //
  uint get_n_memlocs() {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call get_n_memlocs() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return (this.get_n_bytes()-1) / this._mem.get_n_bytes() + 1;
    }
  }

  //
  // FUNCTION -- NODOCS -- get_incr
  // Returns the number of memory locations
  // between two individual virtual registers in the same array.
  //
  uint get_incr() {
    synchronized(this) {
      if (this._incr == 0) {
	uvm_error("RegModel", format("Cannot call get_incr() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return this._incr;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.12
  void get_fields(ref uvm_vreg_field[] fields) {
    synchronized(this) {
      foreach(field; this._fields) {
	fields ~= field;
      }
    }
  }

  uvm_vreg_field[] get_fields() {
    synchronized(this) {
      return this._fields.dup;
      // uvm_vreg_field[] fields;
      // foreach(field; this._fields) {
      // 	fields ~= field;
      // }
      // return fields;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.13
  uvm_vreg_field get_field_by_name(string name) {
    synchronized(this) {
      foreach(field; this._fields) {
	if (field.get_name() == name) {
	  return field;
	}
      }
      uvm_warning("RegModel", format("Unable to locate field \"%s\" in" ~
				     " virtual register \"%s\".",
				     name, this.get_full_name()));
      return null;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.14
  uvm_reg_addr_t get_offset_in_memory(ulong idx) {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot call get_offset_in_memory() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return this._offset + idx * this._incr;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.2.15
  uvm_reg_addr_t get_address(ulong idx,
			     uvm_reg_map map = null) {
    synchronized(this) {
      if (this._mem is null) {
	uvm_error("RegModel", format("Cannot get address of of unimplemented" ~
				     " virtual register \"%s\".",
				     this.get_full_name()));
	return 0;
      }

      return this._mem.get_address(this.get_offset_in_memory(idx), map);
    }
  }

  //
  // Group -- NODOCS -- HDL Access
  //

  // @uvm-ieee 1800.2-2020 auto 18.9.1.3.1
  // task
  void write(ulong              idx,
	     out uvm_status_e   status,
	     uvm_reg_data_t     value,
	     uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
	     uvm_reg_map        map = null,
	     uvm_sequence_base  parent = null,
	     uvm_object         extension = null,
	     string             fname = "",
	     int                lineno = 0) {

    uvm_vreg_cb_iter cbs = new uvm_vreg_cb_iter(this);

    uvm_reg_addr_t  addr;
    uvm_reg_data_t  tmp;
    uvm_reg_data_t  msk;
    int lsb;

    synchronized(this) {
      this.write_in_progress = true;
      this.fname = fname;
      this.lineno = lineno;
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot write to unimplemented virtual" ~
				     " register \"%s\".", this.get_full_name()));
	status = UVM_NOT_OK;
	return;
      }

      if (path == UVM_DEFAULT_DOOR) {
	path = this._parent.get_default_door();
      }
    }

    foreach (field; fields) {
      uvm_vreg_field_cb_iter fcbs = new uvm_vreg_field_cb_iter(field);
      uvm_vreg_field f = field;

      lsb = f.get_lsb_pos_in_register();
      msk = ((1<<f.get_n_bits())-1) << lsb;
      tmp = (value & msk) >> lsb;

      f.pre_write(idx, tmp, path, map);
      for (uvm_vreg_field_cbs cb = fcbs.first(); cb !is null;
	   cb = fcbs.next()) {
	cb.fname = this.fname;
	cb.lineno = this.lineno;
	cb.pre_write(f, idx, tmp, path, map);
      }

      value = (value & ~msk) | (tmp << lsb);
    }
    this.pre_write(idx, value, path, map);
    for (uvm_vreg_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.pre_write(this, idx, value, path, map);
    }

    addr = this.offset + (idx * this.incr);

    lsb = 0;
    status = UVM_IS_OK;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      msk = ((1<<(this.mem.get_n_bytes()*8))-1) << lsb;
      tmp = (value & msk) >> lsb;
      this.mem.write(s, (addr + i), tmp, path,
		     map, parent, -1, extension, fname, lineno);
      if (s != UVM_IS_OK && s != UVM_HAS_X) status = s;
      lsb += this.mem.get_n_bytes() * 8;
    }

    for (uvm_vreg_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.post_write(this, idx, value, path, map, status);
    }
    this.post_write(idx, value, path, map, status);
    foreach (field; fields) {
      uvm_vreg_field_cb_iter fcbs = new uvm_vreg_field_cb_iter(field);
      uvm_vreg_field f = field;

      lsb = f.get_lsb_pos_in_register();
      msk = ((1<<f.get_n_bits())-1) << lsb;
      tmp = (value & msk) >> lsb;

      for (uvm_vreg_field_cbs cb = fcbs.first(); cb !is null;
	   cb = fcbs.next()) {
	cb.fname = this.fname;
	cb.lineno = this.lineno;
	cb.post_write(f, idx, tmp, path, map, status);
      }
      f.post_write(idx, tmp, path, map, status);

      value = (value & ~msk) | (tmp << lsb);
    }

    uvm_info("RegModel", format("Wrote virtual register \"%s\"[%0d] via" ~
				" %s with: 'h%h",
				this.get_full_name(), idx,
				(path == UVM_FRONTDOOR) ? "frontdoor" : "backdoor",
				value),uvm_verbosity.UVM_MEDIUM);
    synchronized(this) {
      this.write_in_progress = false;
      this.fname = "";
      this.lineno = 0;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.3.2
  // task
  void read(ulong              idx,
	    out uvm_status_e   status,
	    out uvm_reg_data_t value,
	    uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
	    uvm_reg_map        map = null,
	    uvm_sequence_base  parent = null,
	    uvm_object         extension = null,
	    string             fname = "",
	    int                lineno = 0) {
    uvm_vreg_cb_iter cbs = new uvm_vreg_cb_iter(this);

    uvm_reg_addr_t  addr;
    uvm_reg_data_t  tmp;
    uvm_reg_data_t  msk;
    int lsb;
    synchronized(this) {
      this.read_in_progress = true;
      this.fname = fname;
      this.lineno = lineno;

      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot read from unimplemented virtual" ~
				     " register \"%s\".", this.get_full_name()));
	status = UVM_NOT_OK;
	return;
      }

      if (path == UVM_DEFAULT_DOOR) {
	path = this._parent.get_default_door();
      }
    }
    foreach (field; fields) {
      uvm_vreg_field_cb_iter fcbs = new uvm_vreg_field_cb_iter(field);
      uvm_vreg_field f = field;

      f.pre_read(idx, path, map);
      for (uvm_vreg_field_cbs cb = fcbs.first(); cb !is null;
	   cb = fcbs.next()) {
	cb.fname = this.fname;
	cb.lineno = this.lineno;
	cb.pre_read(f, idx, path, map);
      }
    }
    this.pre_read(idx, path, map);
    for (uvm_vreg_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.pre_read(this, idx, path, map);
    }

    addr = this.offset + (idx * this.incr);

    lsb = 0;
    value = 0;
    status = UVM_IS_OK;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      this.mem.read(s, addr + i, tmp, path,
		    map, parent, -1, extension, fname, lineno);
      if (s != UVM_IS_OK && s != UVM_HAS_X) status = s;

      value |= tmp << lsb;
      lsb += this.mem.get_n_bytes() * 8;
    }

    for (uvm_vreg_cbs cb = cbs.first(); cb !is null;
	 cb = cbs.next()) {
      cb.fname = this.fname;
      cb.lineno = this.lineno;
      cb.post_read(this, idx, value, path, map, status);
    }
    this.post_read(idx, value, path, map, status);
    foreach (field; fields) {
      uvm_vreg_field_cb_iter fcbs = new uvm_vreg_field_cb_iter(field);
      uvm_vreg_field f = field;

      lsb = f.get_lsb_pos_in_register();

      msk = ((1<<f.get_n_bits())-1) << lsb;
      tmp = (value & msk) >> lsb;

      for (uvm_vreg_field_cbs cb = fcbs.first(); cb !is null;
	   cb = fcbs.next()) {
	cb.fname = this.fname;
	cb.lineno = this.lineno;
	cb.post_read(f, idx, tmp, path, map, status);
      }
      f.post_read(idx, tmp, path, map, status);

      value = (value & ~msk) | (tmp << lsb);
    }

    uvm_info("RegModel",
	     format("Read virtual register \"%s\"[%0d] via %s:" ~
		    " 'h%h", this.get_full_name(), idx,
		    (path == UVM_FRONTDOOR) ? "frontdoor" : "backdoor",
		    value),uvm_verbosity.UVM_MEDIUM);
    synchronized(this) {
      this.read_in_progress = false;
      this.fname = "";
      this.lineno = 0;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.3.3
  // task
  void poke(ulong             idx,
	    out uvm_status_e  status,
	    uvm_reg_data_t    value,
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {
    this.fname = fname;
    this.lineno = lineno;

    if (this.mem is null) {
      uvm_error("RegModel", format("Cannot poke in unimplemented virtual" ~
				   " register \"%s\".", this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    uvm_reg_addr_t  addr = this.offset + (idx * this.incr);

    int lsb = 0;
    status = UVM_IS_OK;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      uvm_reg_data_t  msk = ((1<<(this.mem.get_n_bytes() * 8))-1) << lsb;
      uvm_reg_data_t  tmp = (value & msk) >> lsb;

      this.mem.poke(status, addr + i, tmp,
		    "", parent, extension, fname, lineno);
      if (s != UVM_IS_OK && s != UVM_HAS_X) status = s;

      lsb += this.mem.get_n_bytes() * 8;
    }

    uvm_info("RegModel", format("Poked virtual register \"%s\"[%0d] with: 'h%h",
				this.get_full_name(), idx, value),uvm_verbosity.UVM_MEDIUM);
    this.fname = "";
    this.lineno = 0;

  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.3.4
  // task
  void peek(ulong              idx,
	    out uvm_status_e   status,
	    out uvm_reg_data_t value,
	    uvm_sequence_base  parent = null,
	    uvm_object         extension = null,
	    string             fname = "",
	    int                lineno = 0) {
    this.fname = fname;
    this.lineno = lineno;

    if (this.mem is null) {
      uvm_error("RegModel", format("Cannot peek in from unimplemented" ~
				   " virtual register \"%s\".",
				   this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    uvm_reg_addr_t  addr = this.offset + (idx * this.incr);

    int lsb = 0;
    value = 0;
    status = UVM_IS_OK;
    uvm_reg_data_t  tmp;
    uvm_reg_data_t  msk;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      this.mem.peek(status, addr + i, tmp,
		    "", parent, extension, fname, lineno);
      if (s != UVM_IS_OK && s != UVM_HAS_X) status = s;

      value |= tmp << lsb;
      lsb += this.mem.get_n_bytes() * 8;
    }

    uvm_info("RegModel", format("Peeked virtual register \"%s\"[%0d]: 'h%h",
				this.get_full_name(), idx, value),uvm_verbosity.UVM_MEDIUM);

    this.fname = "";
    this.lineno = 0;

  }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.3.5
  void reset(string kind = "HARD") {
    synchronized(this) {
      // Put back a key in the semaphore if it is checked out
      // in case a thread was killed during an operation
      this._atomic.tryWait();
      this._atomic.post();
    }
  }



  //
  // Group -- NODOCS -- Callbacks
  //

  // @uvm-ieee 1800.2-2020 auto 18.9.1.4.1
  // task
  void pre_write(ulong     idx,
		 ref uvm_reg_data_t   wdat,
		 ref uvm_door_e  path,
		 ref uvm_reg_map      map) { }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.4.2
  // task
  void post_write(ulong       idx,
		  uvm_reg_data_t         wdat,
		  uvm_door_e        path,
		  uvm_reg_map            map,
		  ref uvm_status_e  status) { }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.4.3
  // task
  void pre_read(ulong     idx,
		ref uvm_door_e  path,
		ref uvm_reg_map      map) { }

  // @uvm-ieee 1800.2-2020 auto 18.9.1.4.4
  //task
  void post_read(ulong              idx,
		 ref uvm_reg_data_t rdat,
		 uvm_door_e         path,
		 uvm_reg_map        map,
		 ref uvm_status_e   status) { }

  override void do_print (uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      printer.print_generic("initiator", parent.get_type_name(),
			    -1, convert2string());
    }
  }

  override string convert2string() {
    synchronized(this) {
      string retval = format("Virtual register %s -- ",
			     this.get_full_name());

      if (this._size == 0) {
	retval ~= format("unimplemented");
      }
      else {
	uvm_reg_map[] maps;
	mem.get_maps(maps);

	retval ~= format("[%0d] in %0s['h%0h+'h%0h]\n",
			 this._size, this._mem.get_full_name(),
			 this._offset, this._incr);
	foreach (map; maps) {
	  uvm_reg_addr_t  addr0 = this.get_address(0, map);

	  retval ~= format("  Address in map '%s' -- @'h%0h+%0h",
			   map.get_full_name(), addr0,
			   this.get_address(1, map) - addr0);
	}
      }
      foreach(field; this._fields) {
	retval ~= format("\n%s", field.convert2string());
      }
      return retval;
    }
  }

  override uvm_object clone() {
    return null;
  }

  override void do_copy   (uvm_object rhs) {}

  override bool do_compare (uvm_object  rhs, uvm_comparer comparer) {
    return false;
  }

  override void do_pack (uvm_packer packer) {}

  override void do_unpack (uvm_packer packer) {}

}



//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_vreg_cbs
//
// Pre/post read/write callback facade class
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 18.9.2.1
abstract class uvm_vreg_cbs: uvm_callback
{

  mixin uvm_abstract_object_utils;

  mixin (uvm_sync_string);
  
  @uvm_public_sync
  private string _fname;
  @uvm_public_sync
  private int    _lineno;

  this(string name = "uvm_reg_cbs") {
    synchronized(this) {
      super(name);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.9.2.2.1
  // task
  void pre_write(uvm_vreg           rg,
		 ulong              idx,
		 ref uvm_reg_data_t wdat,
		 ref uvm_door_e     path,
		 ref uvm_reg_map    map) { }

  // @uvm-ieee 1800.2-2020 auto 18.9.2.2.2
  void post_write(uvm_vreg           rg,
		  ulong              idx,
		  uvm_reg_data_t     wdat,
		  uvm_door_e         path,
		  uvm_reg_map        map,
		  ref uvm_status_e   status) { }

  // @uvm-ieee 1800.2-2020 auto 18.9.2.2.3
  // task
  void pre_read(uvm_vreg         rg,
		ulong            idx,
		ref uvm_door_e   path,
		ref uvm_reg_map  map) { }

  // @uvm-ieee 1800.2-2020 auto 18.9.2.2.4
  // task
  void post_read(uvm_vreg           rg,
		 ulong              idx,
		 ref uvm_reg_data_t rdat,
		 uvm_door_e         path,
		 uvm_reg_map        map,
		 ref uvm_status_e   status) { }
}


//
// Type -- NODOCS -- uvm_vreg_cb
// Convenience callback type declaration
//
// Use this declaration to register virtual register callbacks rather than
// the more verbose parameterized class
//
alias uvm_vreg_cb = uvm_callbacks!(uvm_vreg, uvm_vreg_cbs);  /* @uvm-ieee 1800.2-2020 auto D.4.5.9*/

//
// Type -- NODOCS -- uvm_vreg_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered virtual register callbacks
// rather than the more verbose parameterized class
//
alias uvm_vreg_cb_iter = uvm_callback_iter!(uvm_vreg, uvm_vreg_cbs); /* @uvm-ieee 1800.2-2020 auto D.4.5.10*/
