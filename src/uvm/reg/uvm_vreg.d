//
// -------------------------------------------------------------
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
// -------------------------------------------------------------
//
module uvm.reg.uvm_vreg;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_defines;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_vreg_field;
import uvm.reg.uvm_mem;
import uvm.reg.uvm_mem_mam;

import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_callback;
import uvm.base.uvm_printer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_packer;
import uvm.base.uvm_globals;
import uvm.base.uvm_root: uvm_entity_base;

import uvm.seq.uvm_sequence_base;

import esdl.data.bvec;
import esdl.base.comm: SemaphoreObj;

import std.string: format;

//------------------------------------------------------------------------------
// Title: Virtual Registers
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
// Class: uvm_vreg
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

class uvm_vreg: uvm_object
{

  // moved to constructor
  // `uvm_register_cb(uvm_vreg, uvm_vreg_cbs)

  private bool locked;
  private uvm_reg_block parent;
  private uint  n_bits;
  private uint  n_used_bits;

  private uvm_vreg_field[] fields; // Fields in LSB to MSB order

  private uvm_mem          mem;	   // Where is it implemented?
  private uvm_reg_addr_t   offset; // Start of vreg[0]
  private uint     incr;    // From start to start of next
  private uint     size;	    //number of vregs
  private bool              is_static;

  private uvm_mem_region   region; // Not NULL if implemented via MAM

  private SemaphoreObj atomic;	// Field RMW operations must be atomic
  private string fname;
  private int lineno;
  private bool read_in_progress;
  private bool write_in_progress;

  //
  // Group: Initialization
  //

  //
  // FUNCTION: new
  // Create a new instance and type-specific configuration
  //
  // Creates an instance of a virtual register abstraction class
  // with the specified name.
  //
  // ~n_bits~ specifies the total number of bits in a virtual register.
  // Not all bits need to be mapped to a virtual field.
  // This value is usually a multiple of 8.
  //

  // extern function new(string       name,
  //                     uint n_bits);

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
      this.n_bits = n_bits;

      this.locked    = false;

      // `uvm_register_cb(uvm_vreg, uvm_vreg_cbs)
      /* uvm_callbacks!(uvm_vreg, */
      /* 		     uvm_vreg_cbs).m_register_pair(); */
    }
  }


  //
  // Function: configure
  // Instance-specific configuration
  //
  // Specify the ~parent~ block of this virtual register array.
  // If one of the other parameters are specified, the virtual register
  // is assumed to be dynamic and can be later (re-)implemented using
  // the <implement()> method.
  //
  // If ~mem~ is specified, then the virtual register array is assumed
  // to be statically implemented in the memory corresponding to the specified
  // memory abstraction class and ~size~, ~offset~ and ~incr~
  // must also be specified.
  // Static virtual register arrays cannot be re-implemented.
  //

  // extern function void configure(uvm_reg_block     parent,
  //                                uvm_mem       mem    = null,
  //                                ulong  size   = 0,
  //                                uvm_reg_addr_t    offset = 0,
  //                                uint      incr   = 0);

  public void configure(uvm_reg_block      parent,
			uvm_mem            mem = null,
			uint               size = 0,
			uvm_reg_addr_t     offset = 0,
			uint               incr = 0) {
    synchronized(this) {
      this.parent = parent;

      this.n_used_bits = 0;

      if (mem !is null) {
	this.implement(size, mem, offset, incr);
	this.is_static = true;
      }
      else {
	this.mem = null;
	this.is_static = false;
      }
      this.parent.add_vreg(this);

      this.atomic = new SemaphoreObj(1, uvm_entity_base.get());
    }
  }

  //
  // FUNCTION: implement
  // Dynamically implement, resize or relocate a virtual register array
  //
  // Implement an array of virtual registers of the specified
  // ~size~, in the specified memory and ~offset~.
  // If an offset increment is specified, each
  // virtual register is implemented at the specified offset increment
  // from the previous one.
  // If an offset increment of 0 is specified,
  // virtual registers are packed as closely as possible
  // in the memory.
  //
  // If no memory is specified, the virtual register array is
  // in the same memory, at the same base offset using the same
  // offset increment as originally implemented.
  // Only the number of virtual registers in the virtual register array
  // is modified.
  //
  // The initial value of the newly-implemented or
  // relocated set of virtual registers is whatever values
  // are currently stored in the memory now implementing them.
  //
  // Returns TRUE if the memory
  // can implement the number of virtual registers
  // at the specified base offset and offset increment.
  // Returns FALSE otherwise.
  //
  // The memory region used to implement a virtual register array
  // is reserved in the memory allocation manager associated with
  // the memory to prevent it from being allocated for another purpose.
  //

  // extern virtual function bit implement(ulong  n,
  //                                       uvm_mem       mem    = null,
  //                                       uvm_reg_addr_t    offset = 0,
  //                                       uint      incr   = 0);

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

      if (this.is_static) {
	uvm_error("RegModel", format("Virtual register \"%s\" is static" ~
				     " and cannot be dynamically implemented",
				     this.get_full_name()));
	return false;
      }

      if (mem.get_block() !is this.parent) {
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

      if (this.mem !is null) {
	uvm_info("RegModel", format("Virtual register \"%s\" is being moved" ~
				    " re-implemented from %s@'h%0h to %s@'h%0h",
				    this.get_full_name(),
				    this.mem.get_full_name(),
				    this.offset,
				    mem.get_full_name(), offset),uvm_verbosity.UVM_MEDIUM);
	this.release_region();
      }

      this.region = region;
      this.mem    = mem;
      this.size   = n;
      this.offset = offset;
      this.incr   = incr;
      this.mem.Xadd_vregX(this);

      return true;
    }
  }

  //
  // FUNCTION: allocate
  // Randomly implement, resize or relocate a virtual register array
  //
  // Implement a virtual register array of the specified
  // size in a randomly allocated region of the appropriate size
  // in the address space managed by the specified memory allocation manager.
  //
  // The initial value of the newly-implemented
  // or relocated set of virtual registers is whatever values are
  // currently stored in the
  // memory region now implementing them.
  //
  // Returns a reference to a <uvm_mem_region> memory region descriptor
  // if the memory allocation manager was able to allocate a region
  // that can implement the virtual register array.
  // Returns ~null~ otherwise.
  //
  // A region implementing a virtual register array
  // must not be released using the <uvm_mem_mam::release_region()> method.
  // It must be released using the <release_region()> method.
  //

  // extern virtual function uvm_mem_region allocate(ulong n,
  //						  uvm_mem_mam          mam);

  uvm_mem_region allocate(uint n, uvm_mem_mam mam) {
    synchronized(this) {
      uvm_mem_region allocate_;
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

      if (this.is_static) {
	uvm_error("RegModel", format("Virtual register \"%s\" is static" ~
				     " and cannot be dynamically allocated",
				     this.get_full_name()));
	return null;
      }

      mem = mam.get_memory();
      if (mem.get_block() !is this.parent) {
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
      allocate_ = mam.request_region(n*incr*mem.get_n_bytes());
      if (allocate_ is null) {
	uvm_error("RegModel", format("Could not allocate a memory region" ~
				     " for virtual register \"%s\"",
				     this.get_full_name()));
	return null;
      }

      if (this.mem !is null) {
	uvm_info("RegModel", format("Virtual register \"%s\" is being moved" ~
				    " re-allocated from %s@'h%0h to %s@'h%0h",
				    this.get_full_name(),
				    this.mem.get_full_name(),
				    this.offset,
				    mem.get_full_name(),
				    allocate_.get_start_offset()),uvm_verbosity.UVM_MEDIUM);

	this.release_region();
      }

      this.region = allocate_;

      this.mem    = mam.get_memory();
      this.offset = allocate_.get_start_offset();
      this.size   = n;
      this.incr   = incr;

      this.mem.Xadd_vregX(this);
      return allocate_;
    }
  }

  //
  // FUNCTION: get_region
  // Get the region where the virtual register array is implemented
  //
  // Returns a reference to the <uvm_mem_region> memory region descriptor
  // that implements the virtual register array.
  //
  // Returns ~null~ if the virtual registers array
  // is not currently implemented.
  // A region implementing a virtual register array
  // must not be released using the <uvm_mem_mam::release_region()> method.
  // It must be released using the <release_region()> method.
  //

  // extern virtual function uvm_mem_region get_region();

  uvm_mem_region get_region() {
    synchronized(this) {
      return this.region;
    }
  }

  //
  // FUNCTION: release_region
  // Dynamically un-implement a virtual register array
  //
  // Release the memory region used to implement a virtual register array
  // and return it to the pool of available memory
  // that can be allocated by the memory's default allocation manager.
  // The virtual register array is subsequently considered as unimplemented
  // and can no longer be accessed.
  //
  // Statically-implemented virtual registers cannot be released.
  //

  // extern virtual function void release_region();

  void release_region() {
    synchronized(this) {
      if (this.is_static) {
	uvm_error("RegModel", format("Virtual register \"%s\" is static" ~
				     " and cannot be dynamically released",
				     this.get_full_name()));
	return;
      }

      if (this.mem !is null) {
	this.mem.Xdelete_vregX(this);
      }

      if (this.region !is null) {
	this.region.release_region();
      }

      this.region = null;
      this.mem    = null;
      this.size   = 0;
      this.offset = 0;

      this.reset();
    }
  }


  // /*local*/ extern virtual function void set_parent(uvm_reg_block parent);

  void set_parent(uvm_reg_block parent) {
    synchronized(this) {
      this.parent = parent;
    }
  }

  // /*local*/ extern function void Xlock_modelX();

  void Xlock_modelX() {
    synchronized(this) {
      if (this.locked) return;

      this.locked = true;
    }
  }


  // /*local*/ extern function void add_field(uvm_vreg_field field);
  void add_field(uvm_vreg_field field) {
    synchronized(this) {
      if (this.locked) {
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
      foreach (i, fd; this.fields) {
	if (offset < fd.get_lsb_pos_in_register()) {
	  // insert field at ith position
	  this.fields.length += 1;
	  this.fields[i+1..$] = this.fields[i..$-1];
	  this.fields[i] = field;
	  idx = i;
	  break;
	}
      }
      if (idx < 0) {
	this.fields ~= field;
	idx = this.fields.length-1;
      }

      this.n_used_bits += field.get_n_bits();

      // Check if there are too many fields in the register
      if (this.n_used_bits > this.n_bits) {
	uvm_error("RegModel", format("Virtual fields use more bits (%0d)" ~
				     " than available in virtual register" ~
				     " \"%s\" (%0d)",
				     this.n_used_bits, this.get_full_name(),
				     this.n_bits));
      }

      // Check if there are overlapping fields
      if (idx > 0) {
	if (this.fields[idx-1].get_lsb_pos_in_register() +
	    this.fields[idx-1].get_n_bits() > offset) {
	  uvm_error("RegModel", format("Field %s overlaps field %s in virtual" ~
				       " register \"%s\"",
				       this.fields[idx-1].get_name(),
				       field.get_name(),
				       this.get_full_name()));
	}
      }

      if (idx < this.fields.length-1) {
	if (offset + field.get_n_bits() >
	    this.fields[idx+1].get_lsb_pos_in_register()) {
	  uvm_error("RegModel", format("Field %s overlaps field %s in virtual" ~
				       " register \"%s\"",
				       field.get_name(),
				       this.fields[idx+1].get_name(),
				       this.get_full_name()));
	}
      }
    }
  }

  // /*local*/ extern task XatomicX(bit on);

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
  // Group: Introspection
  //

  //
  // Function: get_name
  // Get the simple name
  //
  // Return the simple object name of this register.
  //

  //
  // Function: get_full_name
  // Get the hierarchical name
  //
  // Return the hierarchal name of this register.
  // The base of the hierarchical name is the root block.
  //
  // extern virtual function string get_full_name();

  override string get_full_name() {
    synchronized(this) {
      uvm_reg_block blk;
      string get_full_name_;

      get_full_name_ = this.get_name();

      // Do not include top-level name in full name
      blk = this.get_block();
      if (blk is null) return get_full_name_;
      if (blk.get_parent() is null) return get_full_name_;

      get_full_name_ = this.parent.get_full_name() ~ "." ~ get_full_name;
      return get_full_name_;
    }
  }

  //
  // FUNCTION: get_parent
  // Get the parent block
  //
  // extern virtual function uvm_reg_block get_parent();

  uvm_reg_block get_parent() {
    synchronized(this) {
      return this.parent;
    }
  }

  // extern virtual function uvm_reg_block get_block();
  uvm_reg_block get_block() {
    synchronized(this) {
      return this.parent;
    }
  }


  //
  // FUNCTION: get_memory
  // Get the memory where the virtual regoster array is implemented
  //
  // extern virtual function uvm_mem get_memory();
  uvm_mem get_memory() {
    synchronized(this) {
      return this.mem;
    }
  }


  //
  // Function: get_n_maps
  // Returns the number of address maps this virtual register array is mapped in
  //
  // extern virtual function int             get_n_maps      ();

  int get_n_maps() {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call get_n_maps() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }
      return this.mem.get_n_maps();
    }
  }

  //
  // Function: is_in_map
  // Return TRUE if this virtual register array is in the specified address ~map~
  //
  // extern function         bit             is_in_map       (uvm_reg_map map);

  bool is_in_map(uvm_reg_map map) {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call is_in_map() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return false;
      }

      return this.mem.is_in_map(map);
    }
  }

  //
  // Function: get_maps
  // Returns all of the address ~maps~ where this virtual register array is mapped
  //
  // extern virtual function void            get_maps        (ref uvm_reg_map maps[$]);

  void get_maps(ref uvm_reg_map[] maps) {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call get_maps() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return;
      }
      this.mem.get_maps(maps);
    }
  }

  //
  // FUNCTION: get_rights
  // Returns the access rights of this virtual reigster array
  //
  // Returns "RW", "RO" or "WO".
  // The access rights of a virtual register array is always "RW",
  // unless it is implemented in a shared memory
  // with access restriction in a particular address map.
  //
  // If no address map is specified and the memory is mapped in only one
  // address map, that address map is used. If the memory is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the memory is not mapped in the specified
  // address map, an error message is issued
  // and "RW" is returned.
  //
  // extern virtual function string get_rights(uvm_reg_map map = null);

  string get_rights(uvm_reg_map map = null) {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call get_rights() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return "RW";
      }

      return this.mem.get_rights(map);
    }
  }

  //
  // FUNCTION: get_access
  // Returns the access policy of the virtual register array
  // when written and read via an address map.
  //
  // If the memory implementing the virtual register array
  // is mapped in more than one address map,
  // an address ~map~ must be specified.
  // If access restrictions are present when accessing a memory
  // through the specified address map, the access mode returned
  // takes the access restrictions into account.
  // For example, a read-write memory accessed
  // through an address map with read-only restrictions would return "RO".
  //
  // extern virtual function string get_access(uvm_reg_map map = null);

  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call get_rights() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return "RW";
      }

      return this.mem.get_access(map);
    }
  }

  //
  // FUNCTION: get_size
  // Returns the size of the virtual register array.
  //
  // extern virtual function uint get_size();
  uint get_size() {
    synchronized(this) {
      if (this.size == 0) {
	uvm_error("RegModel", format("Cannot call get_size() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return this.size;
    }
  }


  //
  // FUNCTION: get_n_bytes
  // Returns the width, in bytes, of a virtual register.
  //
  // The width of a virtual register is always a multiple of the width
  // of the memory locations used to implement it.
  // For example, a virtual register containing two 1-byte fields
  // implemented in a memory with 4-bytes memory locations is 4-byte wide.
  //
  // extern virtual function uint get_n_bytes();

  uint get_n_bytes() {
    synchronized(this) {
      return ((this.n_bits-1) / 8) + 1;
    }
  }

  //
  // FUNCTION: get_n_memlocs
  // Returns the number of memory locations used
  // by a single virtual register.
  //
  // extern virtual function uint get_n_memlocs();

  uint get_n_memlocs() {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call get_n_memlocs() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return (this.get_n_bytes()-1) / this.mem.get_n_bytes() + 1;
    }
  }

  //
  // FUNCTION: get_incr
  // Returns the number of memory locations
  // between two individual virtual registers in the same array.
  //
  // extern virtual function uint get_incr();

  uint get_incr() {
    synchronized(this) {
      if (this.incr == 0) {
	uvm_error("RegModel", format("Cannot call get_incr() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return 0;
      }

      return this.incr;
    }
  }


  //
  // FUNCTION: get_fields
  // Return the virtual fields in this virtual register
  //
  // Fills the specified array with the abstraction class
  // for all of the virtual fields contained in this virtual register.
  // Fields are ordered from least-significant position to most-significant
  // position within the register.
  //
  // extern virtual function void get_fields(ref uvm_vreg_field fields[$]);

  void get_fields(ref uvm_vreg_field[] fields) {
    synchronized(this) {
      foreach(field; this.fields) {
	fields ~= field;
      }
    }
  }

  //
  // FUNCTION: get_field_by_name
  // Return the named virtual field in this virtual register
  //
  // Finds a virtual field with the specified name in this virtual register
  // and returns its abstraction class.
  // If no fields are found, returns null.
  //
  // extern virtual function uvm_vreg_field get_field_by_name(string name);

  uvm_vreg_field get_field_by_name(string name) {
    synchronized(this) {
      foreach(field; this.fields) {
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

  //
  // FUNCTION: get_offset_in_memory
  // Returns the offset of a virtual register
  //
  // Returns the base offset of the specified virtual register,
  // in the overall address space of the memory
  // that implements the virtual register array.
  //
  // extern virtual function uvm_reg_addr_t  get_offset_in_memory(ulong idx);

  uvm_reg_addr_t get_offset_in_memory(ulong idx) {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot call get_offset_in_memory() on" ~
				     " unimplemented virtual register \"%s\"",
				     this.get_full_name()));
	return UBit!64(0);
      }

      return cast(uvm_reg_addr_t) (this.offset + idx * this.incr);
    }
  }

  //
  // FUNCTION: get_address
  // Returns the base external physical address of a virtual register
  //
  // Returns the base external physical address of the specified
  // virtual reigster if accessed through the specified address ~map~.
  //
  // If no address map is specified and the memory implementing
  // the virtual register array is mapped in only one
  // address map, that address map is used. If the memory is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the memory is not mapped in the specified
  // address map, an error message is issued.
  //
  // extern virtual function uvm_reg_addr_t  get_address(ulong idx,
  //						      uvm_reg_map map = null);

  uvm_reg_addr_t get_address(ulong idx,
			     uvm_reg_map map = null) {
    synchronized(this) {
      if (this.mem is null) {
	uvm_error("RegModel", format("Cannot get address of of unimplemented" ~
				     " virtual register \"%s\".",
				     this.get_full_name()));
	return UBit!64(0);
      }

      return this.mem.get_address(this.get_offset_in_memory(idx), map);
    }
  }

  //
  // Group: HDL Access
  //

  //
  // TASK: write
  // Write the specified value in a virtual register
  //
  // Write ~value~ in the DUT memory location(s) that implements
  // the virtual register array that corresponds to this
  // abstraction class instance using the specified access
  // ~path~.
  //
  // If the memory implementing the virtual register array
  // is mapped in more than one address map,
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  //
  // The operation is eventually mapped into set of
  // memory-write operations at the location where the virtual register
  // specified by ~idx~ in the virtual register array is implemented.
  //
  // extern virtual task write(input  ulong   idx,
  //			    output uvm_status_e  status,
  //			    input  uvm_reg_data_t     value,
  //			    input  uvm_path_e    path = UVM_DEFAULT_PATH,
  //			    input  uvm_reg_map     map = null,
  //			    input  uvm_sequence_base  parent = null,
  //			    input  uvm_object         extension = null,
  //			    input  string             fname = "",
  //			    input  int                lineno = 0);

  // task
  void write(ulong              idx,
	     out uvm_status_e   status,
	     uvm_reg_data_t     value,
	     uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
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

    this.write_in_progress = true;
    this.fname = fname;
    this.lineno = lineno;
    if (this.mem is null) {
      uvm_error("RegModel", format("Cannot write to unimplemented virtual" ~
				   " register \"%s\".", this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    if (path == UVM_DEFAULT_PATH) {
      path = this.parent.get_default_path();
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

    addr = cast(uvm_reg_addr_t) (this.offset + (idx * this.incr));

    lsb = 0;
    status = UVM_IS_OK;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      msk = ((1<<(this.mem.get_n_bytes()*8))-1) << lsb;
      tmp = (value & msk) >> lsb;
      this.mem.write(s, cast(uvm_reg_addr_t) (addr + i), tmp, path,
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

    this.write_in_progress = false;
    this.fname = "";
    this.lineno = 0;
  }

  //
  // TASK: read
  // Read the current value from a virtual register
  //
  // Read from the DUT memory location(s) that implements
  // the virtual register array that corresponds to this
  // abstraction class instance using the specified access
  // ~path~ and return the readback ~value~.
  //
  // If the memory implementing the virtual register array
  // is mapped in more than one address map,
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  //
  // The operation is eventually mapped into set of
  // memory-read operations at the location where the virtual register
  // specified by ~idx~ in the virtual register array is implemented.
  //
  // extern virtual task read(input  ulong    idx,
  //			   output uvm_status_e   status,
  //			   output uvm_reg_data_t      value,
  //			   input  uvm_path_e     path = UVM_DEFAULT_PATH,
  //			   input  uvm_reg_map      map = null,
  //			   input  uvm_sequence_base   parent = null,
  //			   input  uvm_object          extension = null,
  //			   input  string              fname = "",
  //			   input  int                 lineno = 0);

  // task
  void read(ulong              idx,
	    out uvm_status_e   status,
	    out uvm_reg_data_t value,
	    uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
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
    this.read_in_progress = true;
    this.fname = fname;
    this.lineno = lineno;

    if (this.mem is null) {
      uvm_error("RegModel", format("Cannot read from unimplemented virtual" ~
				   " register \"%s\".", this.get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    if (path == UVM_DEFAULT_PATH) {
      path = this.parent.get_default_path();
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

    addr = cast(uvm_reg_addr_t) (this.offset + (idx * this.incr));

    lsb = 0;
    value = 0;
    status = UVM_IS_OK;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      this.mem.read(s, cast(uvm_reg_addr_t) (addr + i), tmp, path,
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

    this.read_in_progress = false;
    this.fname = "";
    this.lineno = 0;
  }

  //
  // TASK: poke
  // Deposit the specified value in a virtual register
  //
  // Deposit ~value~ in the DUT memory location(s) that implements
  // the virtual register array that corresponds to this
  // abstraction class instance using the memory backdoor access.
  //
  // The operation is eventually mapped into set of
  // memory-poke operations at the location where the virtual register
  // specified by ~idx~ in the virtual register array is implemented.
  //
  // extern virtual task poke(input  ulong    idx,
  //			   output uvm_status_e   status,
  //			   input  uvm_reg_data_t      value,
  //			   input  uvm_sequence_base   parent = null,
  //			   input  uvm_object          extension = null,
  //			   input  string              fname = "",
  //			   input  int                 lineno = 0);

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

    uvm_reg_addr_t  addr = cast(uvm_reg_addr_t)
      (this.offset + (idx * this.incr));

    int lsb = 0;
    status = UVM_IS_OK;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      uvm_reg_data_t  msk = ((1<<(this.mem.get_n_bytes() * 8))-1) << lsb;
      uvm_reg_data_t  tmp = (value & msk) >> lsb;

      this.mem.poke(status, cast(uvm_reg_addr_t) (addr + i), tmp,
		    "", parent, extension, fname, lineno);
      if (s != UVM_IS_OK && s != UVM_HAS_X) status = s;

      lsb += this.mem.get_n_bytes() * 8;
    }

    uvm_info("RegModel", format("Poked virtual register \"%s\"[%0d] with: 'h%h",
				this.get_full_name(), idx, value),uvm_verbosity.UVM_MEDIUM);
    this.fname = "";
    this.lineno = 0;

  }

  //
  // TASK: peek
  // Sample the current value in a virtual register
  //
  // Sample the DUT memory location(s) that implements
  // the virtual register array that corresponds to this
  // abstraction class instance using the memory backdoor access,
  // and return the sampled ~value~.
  //
  // The operation is eventually mapped into set of
  // memory-peek operations at the location where the virtual register
  // specified by ~idx~ in the virtual register array is implemented.
  //
  // extern virtual task peek(input  ulong    idx,
  //			   output uvm_status_e   status,
  //			   output uvm_reg_data_t      value,
  //			   input  uvm_sequence_base   parent = null,
  //			   input  uvm_object          extension = null,
  //			   input  string              fname = "",
  //			   input  int                 lineno = 0);

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

    uvm_reg_addr_t  addr = cast(uvm_reg_addr_t)
      (this.offset + (idx * this.incr));

    int lsb = 0;
    value = 0;
    status = UVM_IS_OK;
    uvm_reg_data_t  tmp;
    uvm_reg_data_t  msk;
    for (int i = 0; i < this.get_n_memlocs(); i++) {
      uvm_status_e s;

      this.mem.peek(status, cast(uvm_reg_data_t) (addr + i), tmp,
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

  //
  // Function: reset
  // Reset the access semaphore
  //
  // Reset the semaphore that prevents concurrent access
  // to the virtual register.
  // This semaphore must be explicitly reset if a thread accessing
  // this virtual register array was killed in before the access
  // was completed
  //
  // extern function void reset(string kind = "HARD");

  void reset(string kind = "HARD") {
    synchronized(this) {
      // Put back a key in the semaphore if it is checked out
      // in case a thread was killed during an operation
      this.atomic.tryWait();
      this.atomic.post();
    }
  }



  //
  // Group: Callbacks
  //

  //
  // TASK: pre_write
  // Called before virtual register write.
  //
  // If the specified data value, access ~path~ or address ~map~ are modified,
  // the updated data value, access path or address map will be used
  // to perform the virtual register operation.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  // All register callbacks are executed after the corresponding
  // field callbacks
  // The pre-write virtual register and field callbacks are executed
  // before the corresponding pre-write memory callbacks
  //
  // virtual task pre_write(ulong     idx,
  //			 ref uvm_reg_data_t   wdat,
  //			 ref uvm_path_e  path,
  //			 ref uvm_reg_map      map);
  // task
  void pre_write(ulong     idx,
		 ref uvm_reg_data_t   wdat,
		 ref uvm_path_e  path,
		 ref uvm_reg_map      map) {
  }

  //
  // TASK: post_write
  // Called after virtual register write.
  //
  // If the specified ~status~ is modified,
  // the updated status will be
  // returned by the virtual register operation.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  // All register callbacks are executed before the corresponding
  // field callbacks
  // The post-write virtual register and field callbacks are executed
  // after the corresponding post-write memory callbacks
  //
  // virtual task post_write(ulong       idx,
  //			uvm_reg_data_t         wdat,
  //			uvm_path_e        path,
  //			uvm_reg_map            map,
  //			ref uvm_status_e  status);
  // task
  void post_write(ulong       idx,
		  uvm_reg_data_t         wdat,
		  uvm_path_e        path,
		  uvm_reg_map            map,
		  ref uvm_status_e  status) {
  }

  //
  // TASK: pre_read
  // Called before virtual register read.
  //
  // If the specified access ~path~ or address ~map~ are modified,
  // the updated access path or address map will be used to perform
  // the register operation.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  // All register callbacks are executed after the corresponding
  // field callbacks
  // The pre-read virtual register and field callbacks are executed
  // before the corresponding pre-read memory callbacks
  //
  // virtual task pre_read(ulong     idx,
  //			ref uvm_path_e  path,
  //			ref uvm_reg_map      map);
  // task
  void pre_read(ulong     idx,
		ref uvm_path_e  path,
		ref uvm_reg_map      map) {
  }

  //
  // TASK: post_read
  // Called after virtual register read.
  //
  // If the specified readback data or ~status~ is modified,
  // the updated readback data or status will be
  // returned by the register operation.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  // All register callbacks are executed before the corresponding
  // field callbacks
  // The post-read virtual register and field callbacks are executed
  // after the corresponding post-read memory callbacks
  //
  // virtual task post_read(ulong       idx,
  //			 ref uvm_reg_data_t     rdat,
  //			 input uvm_path_e  path,
  //			 input uvm_reg_map      map,
  //			 ref uvm_status_e  status);
  //task
  void post_read(ulong              idx,
		 ref uvm_reg_data_t rdat,
		 uvm_path_e         path,
		 uvm_reg_map        map,
		 ref uvm_status_e   status) {
  }

  // extern virtual function void do_print (uvm_printer printer);
  override void do_print (uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      printer.print_generic("initiator", parent.get_type_name(),
			    -1, convert2string());
    }
  }

  // extern virtual function string convert2string;
  override string convert2string() {
    synchronized(this) {
      string res_str;
      string t_str;
      bool with_debug_info;
      string retval = format("Virtual register %s -- ",
			     this.get_full_name());

      if (this.size == 0) {
	retval ~= format("unimplemented");
      }
      else {
	uvm_reg_map[] maps;
	mem.get_maps(maps);

	retval ~= format("[%0d] in %0s['h%0h+'h%0h]\n",
			 this.size, this.mem.get_full_name(),
			 this.offset, this.incr);
	foreach (map; maps) {
	  uvm_reg_addr_t  addr0 = this.get_address(0, map);

	  retval ~= format("  Address in map '%s' -- @'h%0h+%0h",
			   map.get_full_name(), addr0,
			   this.get_address(1, map) - addr0);
	}
      }
      foreach(field; this.fields) {
	retval ~= format("\n%s", field.convert2string());
      }
      return retval;
    }
  }

  // extern virtual function uvm_object clone();

  //TODO - add fatal messages
  override uvm_object clone() {
    return null;
  }

  // extern virtual function void do_copy   (uvm_object rhs);
  override void do_copy   (uvm_object rhs) {}

  // extern virtual function bit do_compare (uvm_object  rhs,
  //                                         uvm_comparer comparer);
  override bool do_compare (uvm_object  rhs, uvm_comparer comparer) {
    return false;
  }

  // extern virtual function void do_pack (uvm_packer packer);
  override void do_pack (uvm_packer packer) {}

  // extern virtual function void do_unpack (uvm_packer packer);
  override void do_unpack (uvm_packer packer) {}

}



//------------------------------------------------------------------------------
// Class: uvm_vreg_cbs
//
// Pre/post read/write callback facade class
//
//------------------------------------------------------------------------------

class uvm_vreg_cbs: uvm_callback
{

  string fname;
  int    lineno;

  this(string name = "uvm_reg_cbs") {
    synchronized(this) {
      super(name);
    }
  }


  //
  // Task: pre_write
  // Callback called before a write operation.
  //
  // The registered callback methods are invoked after the invocation
  // of the <pre_write()> method.
  // All virtual register callbacks are executed after the corresponding
  // virtual field callbacks
  // The pre-write virtual register and field callbacks are executed
  // before the corresponding pre-write memory callbacks
  //
  // The written value ~wdat~, access ~path~ and address ~map~,
  // if modified, modifies the actual value, access path or address map
  // used in the virtual register operation.
  //
  // virtual task pre_write(uvm_vreg         rg,
  //			 ulong     idx,
  //			 ref uvm_reg_data_t   wdat,
  //			 ref uvm_path_e  path,
  //			 ref uvm_reg_map   map);
  // task
  void pre_write(uvm_vreg           rg,
		 ulong              idx,
		 ref uvm_reg_data_t wdat,
		 ref uvm_path_e     path,
		 ref uvm_reg_map    map) {
  }


  //
  // TASK: post_write
  // Called after register write.
  //
  // The registered callback methods are invoked before the invocation
  // of the <uvm_reg::post_write()> method.
  // All register callbacks are executed before the corresponding
  // virtual field callbacks
  // The post-write virtual register and field callbacks are executed
  // after the corresponding post-write memory callbacks
  //
  // The ~status~ of the operation,
  // if modified, modifies the actual returned status.
  //
  // virtual task post_write(uvm_vreg           rg,
  //			  ulong       idx,
  //			  uvm_reg_data_t         wdat,
  //			  uvm_path_e        path,
  //			  uvm_reg_map         map,
  //			  ref uvm_status_e  status);
  void post_write(uvm_vreg           rg,
		  ulong              idx,
		  uvm_reg_data_t     wdat,
		  uvm_path_e         path,
		  uvm_reg_map        map,
		  ref uvm_status_e   status) {
  }


  //
  // TASK: pre_read
  // Called before register read.
  //
  // The registered callback methods are invoked after the invocation
  // of the <uvm_reg::pre_read()> method.
  // All register callbacks are executed after the corresponding
  // virtual field callbacks
  // The pre-read virtual register and field callbacks are executed
  // before the corresponding pre-read memory callbacks
  //
  // The access ~path~ and address ~map~,
  // if modified, modifies the actual access path or address map
  // used in the register operation.
  //
  // virtual task pre_read(uvm_vreg         rg,
  //			ulong     idx,
  //			ref uvm_path_e  path,
  //			ref uvm_reg_map   map);
  // task
  void pre_read(uvm_vreg         rg,
		ulong            idx,
		ref uvm_path_e   path,
		ref uvm_reg_map  map) {
  }


  //
  // TASK: post_read
  // Called after register read.
  //
  // The registered callback methods are invoked before the invocation
  // of the <uvm_reg::post_read()> method.
  // All register callbacks are executed before the corresponding
  // virtual field callbacks
  // The post-read virtual register and field callbacks are executed
  // after the corresponding post-read memory callbacks
  //
  // The readback value ~rdat~ and the ~status~ of the operation,
  // if modified, modifies the actual returned readback value and status.
  //
  // virtual task post_read(uvm_vreg           rg,
  //			 ulong       idx,
  //			 ref uvm_reg_data_t     rdat,
  //			 input uvm_path_e  path,
  //			 input uvm_reg_map   map,
  //			 ref uvm_status_e  status);
  // task
  void post_read(uvm_vreg           rg,
		 ulong              idx,
		 ref uvm_reg_data_t rdat,
		 uvm_path_e         path,
		 uvm_reg_map        map,
		 ref uvm_status_e   status) {
  }
}


//
// Type: uvm_vreg_cb
// Convenience callback type declaration
//
// Use this declaration to register virtual register callbacks rather than
// the more verbose parameterized class
//
alias uvm_vreg_cb = uvm_callbacks!(uvm_vreg, uvm_vreg_cbs);

//
// Type: uvm_vreg_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered virtual register callbacks
// rather than the more verbose parameterized class
//
alias uvm_vreg_cb_iter = uvm_callback_iter!(uvm_vreg, uvm_vreg_cbs);
