//
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2004-2014 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2014-2018 NVIDIA Corporation
// Copyright 2018 Cisco Systems, Inc.
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
module uvm.reg.uvm_mem_mam;

import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_vreg: uvm_vreg;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_model;

import uvm.seq.uvm_sequence_base: uvm_sequence_base;

import uvm.base.uvm_globals: uvm_report_error, uvm_error, uvm_info;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.base.uvm_root: uvm_root;
import uvm.meta.misc;

import esdl.data.bvec;
import esdl.rand;

import std.string: format;

//------------------------------------------------------------------------------
//
// Title -- NODOCS -- Memory Allocation Manager
//
// Manages the exclusive allocation of consecutive memory locations
// called ~regions~.
// The regions can subsequently be accessed like little memories of
// their own, without knowing in which memory or offset they are
// actually located.
//
// The memory allocation manager should be used by any
// application-level process
// that requires reserved space in the memory,
// such as DMA buffers.
//
// A region will remain reserved until it is explicitly released.
//
//------------------------------------------------------------------------------


// typedef class uvm_mem_mam_cfg;
// typedef class uvm_mem_region;
// typedef class uvm_mem_mam_policy;

// typedef class uvm_mem;


//------------------------------------------------------------------------------
// CLASS -- NODOCS -- uvm_mem_mam
//------------------------------------------------------------------------------
// Memory allocation manager
//
// Memory allocation management utility class similar to C's malloc()
// and free().
// A single instance of this class is used to manage a single,
// contiguous address space.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 18.12.1
class uvm_mem_mam
{

  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------

  // Type -- NODOCS -- alloc_mode_e
  //
  // Memory allocation mode
  //
  // Specifies how to allocate a memory region
  //
  // GREEDY   - Consume new, previously unallocated memory
  // THRIFTY  - Reused previously released memory as much as possible (not yet implemented)
  //
  enum alloc_mode_e: bool {GREEDY, THRIFTY};
  mixin(declareEnums!alloc_mode_e);

  // Type -- NODOCS -- locality_e
  //
  // Location of memory regions
  //
  // Specifies where to locate new memory regions
  //
  // BROAD    - Locate new regions randomly throughout the address space
  // NEARBY   - Locate new regions adjacent to existing regions

  enum locality_e: bool {BROAD, NEARBY};
  mixin(declareEnums!locality_e);

  mixin(uvm_sync_string);

  // Variable -- NODOCS -- default_alloc
  //
  // Region allocation policy
  //
  // This object is repeatedly randomized when allocating new regions.
  @uvm_private_sync @rand(false)
  private uvm_mem_mam_policy _default_alloc;
  
  @uvm_private_sync @rand(false)
  private uvm_mem _memory;

  @uvm_private_sync
  private uvm_mem_mam_cfg _cfg;

  private uvm_mem_region[] _in_use;

  @uvm_private_sync
  private int _for_each_idx = -1;

  @uvm_private_sync
  private string _fname;

  @uvm_private_sync
  private int _lineno;

  // Function -- NODOCS -- new
  //
  // Create a new manager instance
  //
  // Create an instance of a memory allocation manager
  // with the specified name and configuration.
  // This instance manages all memory region allocation within
  // the address range specified in the configuration descriptor.
  //
  // If a reference to a memory abstraction class is provided, the memory
  // locations within the regions can be accessed through the region
  // descriptor, using the <uvm_mem_region::read()> and
  // <uvm_mem_region::write()> methods.
  //
  public this(string name,
	      uvm_mem_mam_cfg cfg,
	      uvm_mem mem=null) {
    synchronized(this) {
      this._cfg           = cfg;
      this._memory        = mem;
      this._default_alloc = new uvm_mem_mam_policy;
    }
  }


  // Function -- NODOCS -- reconfigure
  //
  // Reconfigure the manager
  //
  // Modify the maximum and minimum addresses of the address space managed by
  // the allocation manager, allocation mode, or locality.
  // The number of bytes per memory location cannot be modified
  // once an allocation manager has been constructed.
  // All currently allocated regions must fall within the new address space.
  //
  // Returns the previous configuration.
  //
  // if no new configuration is specified, simply returns the current
  // configuration.
  //
  public uvm_mem_mam_cfg reconfigure(uvm_mem_mam_cfg cfg = null) {
    synchronized(this) {
      if (cfg is null)
	return this._cfg;

      uvm_root top = uvm_root.get();

      // Cannot reconfigure n_bytes
      if (cfg._n_bytes != this._cfg._n_bytes) {
	top.uvm_report_error("uvm_mem_mam",
			     format("Cannot reconfigure Memory Allocation " ~
				    "Manager with a different number of " ~
				    "bytes (%0d !== %0d)",
				    cfg._n_bytes, this._cfg._n_bytes), uvm_verbosity.UVM_LOW);
	return this._cfg;
      }

      // All currently allocated regions must fall within the new space
      foreach (i, used; this._in_use) {
	if (used.get_start_offset() < cfg.start_offset ||
	    used.get_end_offset() > cfg.end_offset) {
	  top.uvm_report_error("uvm_mem_mam",
			       format("Cannot reconfigure Memory " ~
				      "Allocation Manager with a " ~
				      "currently allocated region " ~
				      "outside of the managed address " ~
				      "range ([%0d:%0d] outside of " ~
				      "[%0d:%0d])",
				      used.get_start_offset(),
				      used.get_end_offset(),
				      cfg.start_offset, cfg.end_offset),
			       uvm_verbosity.UVM_LOW);
	  return this._cfg;
	}
      }

      uvm_mem_mam_cfg retval = this._cfg;
      this._cfg = cfg;
      return retval;
    }
  }

  //-------------------------
  // Group -- NODOCS -- Memory Management
  //-------------------------

  // Function -- NODOCS -- reserve_region
  //
  // Reserve a specific memory region
  //
  // Reserve a memory region of the specified number of bytes
  // starting at the specified offset.
  // A descriptor of the reserved region is returned.
  // If the specified region cannot be reserved, null is returned.
  //
  // It may not be possible to reserve a region because
  // it overlaps with an already-allocated region or
  // it lies outside the address range managed
  // by the memory manager.
  //
  // Regions can be reserved to create "holes" in the managed address space.
  //
  public uvm_mem_region reserve_region(uvm_reg_addr_t      start_offset,
				       uint                n_bytes,
				       string              fname = "",
				       int                 lineno = 0) {
    synchronized(this) {
      uvm_mem_region retval;
      this.fname = fname;
      this.lineno = lineno;
      if (n_bytes == 0) {
	uvm_error("RegModel", "Cannot reserve 0 bytes");
	return null;
      }

      if (start_offset < this.cfg.start_offset) {
	uvm_error("RegModel", format("Cannot reserve before start " ~
				     "of memory space: 'h%h < 'h%h",
				     start_offset, this.cfg.start_offset));
	return null;
      }

      ulong end_offset = start_offset + ((n_bytes-1) / this.cfg.n_bytes);
      n_bytes = cast(uint) ((end_offset - start_offset + 1) * this.cfg.n_bytes);

      if (end_offset > this.cfg.end_offset) {
	uvm_error("RegModel", format("Cannot reserve past end of " ~
				     "memory space: 'h%h > 'h%h",
				     end_offset, this.cfg.end_offset));
	return null;
      }

      uvm_info("RegModel", format("Attempting to reserve ['h%h:'h%h]...",
				  start_offset, end_offset), uvm_verbosity.UVM_MEDIUM);

      foreach (i, used; this._in_use) {
	if (start_offset <= used.get_end_offset() &&
	    end_offset >= used.get_start_offset()) {
	  // Overlap!
	  uvm_error("RegModel", format("Cannot reserve ['h%h:'h%h] " ~
				       "because it overlaps with %s",
				       start_offset, end_offset,
				       used.convert2string()));
	  return null;
	}

	// Regions are stored in increasing start offset
	if (start_offset > used.get_start_offset()) {
	  retval = new uvm_mem_region(cast(ulong) start_offset, end_offset,
				      cast(uint) (end_offset - start_offset + 1),
				      cast(uint) n_bytes, this);
	  this._in_use = _in_use[0..i] ~ retval ~
	    _in_use[i..$];	// insert(i, retval);
	  return retval;
	}
      }

      retval = new uvm_mem_region(cast(ulong) start_offset, end_offset,
				  cast(uint) (end_offset - start_offset + 1),
				  cast(uint) n_bytes, this);
      this._in_use ~= retval;
      return retval;
    }
  } // reserve_region

  // Function -- NODOCS -- request_region
  //
  // Request and reserve a memory region
  //
  // Request and reserve a memory region of the specified number
  // of bytes starting at a random location.
  // If an policy is specified, it is randomized to determine
  // the start offset of the region.
  // If no policy is specified, the policy found in
  // the <uvm_mem_mam::default_alloc> class property is randomized.
  //
  // A descriptor of the allocated region is returned.
  // If no region can be allocated, ~null~ is returned.
  //
  // It may not be possible to allocate a region because
  // there is no area in the memory with enough consecutive locations
  // to meet the size requirements or
  // because there is another contradiction when randomizing
  // the policy.
  //
  // If the memory allocation is configured to ~THRIFTY~ or ~NEARBY~,
  // a suitable region is first sought procedurally.
  //
  public uvm_mem_region request_region(uint                  n_bytes,
				       uvm_mem_mam_policy    alloc = null,
				       string            fname = "",
				       int               lineno = 0) {
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
      if (alloc is null) alloc = this._default_alloc;

      synchronized(alloc) {
	alloc._len        = (n_bytes-1) / this.cfg.n_bytes + 1;
	alloc._min_offset = this.cfg.start_offset;
	alloc._max_offset = this.cfg.end_offset;
	alloc._in_use     = this._in_use;
      }

      try {
	alloc.randomize();
      }
      catch(Throwable) {
	uvm_error("RegModel", "Unable to randomize policy");
	return null;
      }

      return reserve_region(cast(uvm_reg_addr_t) alloc.start_offset, n_bytes);
    }
  }

  // Function -- NODOCS -- release_region
  //
  // Release the specified region
  //
  // Release a previously allocated memory region.
  // An error is issued if the
  // specified region has not been previously allocated or
  // is no longer allocated.
  //
  public void release_region(uvm_mem_region region) {
    if (region is null) return;
    synchronized(this) {
      foreach (i, used; this._in_use) {
	if (used == region) {
	  this._in_use = _in_use[0..i] ~ _in_use[i+1..$]; // .remove(i);
	  return;
	}
      }
      uvm_error("RegModel", "Attempting to release unallocated region\n" ~
		region.convert2string());
    }
  }


  // Function -- NODOCS -- release_all_regions
  //
  // Forcibly release all allocated memory regions.
  //
  public void release_all_regions() {
    synchronized(this) {
      _in_use.length = 0;
    }
  }


  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  // Function -- NODOCS -- convert2string
  //
  // Image of the state of the manager
  //
  // Create a human-readable description of the state of
  // the memory manager and the currently allocated regions.
  //
  string convert2string() {
    synchronized(this) {
      string retval = "Allocated memory regions:\n";
      foreach (i, used; this._in_use) {
	retval ~= format("   %s\n",
			 used.convert2string());
      }
      return retval;
    }
  }

  // Function -- NODOCS -- for_each
  //
  // Iterate over all currently allocated regions
  //
  // If reset is ~TRUE~, reset the iterator
  // and return the first allocated region.
  // Returns ~null~ when there are no additional allocated
  // regions to iterate on.
  //
  uvm_mem_region for_each(bool reset = false) {
    synchronized(this) {
      if (reset) this._for_each_idx = -1;

      this._for_each_idx++;

      if (this._for_each_idx >= this._in_use.length) {
	return null;
      }

      return this._in_use[this._for_each_idx];
    }
  }

  // Function -- NODOCS -- get_memory
  //
  // Get the managed memory implementation
  //
  // Return the reference to the memory abstraction class
  // for the memory implementing
  // the locations managed by this instance of the allocation manager.
  // Returns ~null~ if no
  // memory abstraction class was specified at construction time.
  //
  public uvm_mem get_memory() {
    synchronized(this) {
      return this._memory;
    }
  }

};



//------------------------------------------------------------------------------
// CLASS -- NODOCS -- uvm_mem_region
//------------------------------------------------------------------------------
// Allocated memory region descriptor
//
// Each instance of this class describes an allocated memory region.
// Instances of this class are created only by
// the memory manager, and returned by the
// <uvm_mem_mam::reserve_region()> and <uvm_mem_mam::request_region()>
// methods.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 18.12.7.1
class uvm_mem_region
{

  mixin(uvm_sync_string);
  @uvm_private_sync
  private ulong _Xstart_offsetX;  // Can't be local since function
  @uvm_private_sync
  private ulong _Xend_offsetX;    // calls not supported in constraints
  @uvm_private_sync
  private uint         _len;
  @uvm_private_sync
  private uint         _n_bytes;
  @uvm_private_sync
  private uvm_mem_mam  _parent;
  @uvm_private_sync
  private string       _fname;
  @uvm_private_sync
  private int          _lineno;
  @uvm_private_sync
  /*local*/ private uvm_vreg _XvregX;

  public this (ulong start_offset,
	       ulong end_offset,
	       uint len,
	       uint n_bytes,
	       uvm_mem_mam parent) {
    synchronized(this) {
      this._Xstart_offsetX = start_offset;
      this._Xend_offsetX   = end_offset;
      this._len            = len;
      this._n_bytes        = n_bytes;
      this._parent         = parent;
      this._XvregX         = null;
    }
  }


  // Function -- NODOCS -- get_start_offset
  //
  // Get the start offset of the region
  //
  // Return the address offset, within the memory,
  // where this memory region starts.
  //
  public ulong get_start_offset() {
    synchronized(this) {
      return this._Xstart_offsetX;
    }
  }

  // Function -- NODOCS -- get_end_offset
  //
  // Get the end offset of the region
  //
  // Return the address offset, within the memory,
  // where this memory region ends.
  //
  public ulong get_end_offset() {
    synchronized(this) {
      return this._Xend_offsetX;
    }
  }

  // Function -- NODOCS -- get_len
  //
  // Size of the memory region
  //
  // Return the number of consecutive memory locations
  // (not necessarily bytes) in the allocated region.
  //
  public uint get_len() {
    synchronized(this) {
      return this._len;
    }
  }

  // Function -- NODOCS -- get_n_bytes
  //
  // Number of bytes in the region
  //
  // Return the number of consecutive bytes in the allocated region.
  // If the managed memory contains more than one byte per address,
  // the number of bytes in an allocated region may
  // be greater than the number of requested or reserved bytes.
  //
  public uint get_n_bytes() {
    synchronized(this) {
      return this._n_bytes;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.5
  public void release_region() {
    this.parent.release_region(this);
  }


  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.6
  public uvm_mem get_memory() {
    return this.parent.get_memory();
  }

  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.7
  public uvm_vreg get_virtual_registers() {
    synchronized(this) {
      return this._XvregX;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.8
  // task
  public void write(out uvm_status_e   status,
		    uvm_reg_addr_t     offset,
		    uvm_reg_data_t     value,
		    uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
		    uvm_reg_map        map    = null,
		    uvm_sequence_base  parent = null,
		    int                prior = -1,
		    uvm_object         extension = null,
		    string             fname = "",
		    int                lineno = 0) {

    uvm_mem mem = this.parent.get_memory();
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    if (mem is null) {
      uvm_error("RegModel", "Cannot use uvm_mem_region::write() on" ~
		" a region that was allocated by a Memory Allocation" ~
		" Manager that was not associated with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_error("RegModel",
		format("Attempting to write to an offset outside"
		       ~ " of the allocated region (%0d > %0d)",
		       offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.write(status, offset + this.get_start_offset(), value,
	      path, map, parent, prior, extension);
  }


  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.9
  // task
  public void read(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   out uvm_reg_data_t value,
		   uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
		   uvm_reg_map        map    = null,
		   uvm_sequence_base  parent = null,
		   int                prior = -1,
		   uvm_object         extension = null,
		   string             fname = "",
		   int                lineno = 0) {
    uvm_mem mem = this.parent.get_memory();
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    if (mem is null) {
      uvm_error("RegModel", "Cannot use uvm_mem_region::read()" ~
		" on a region that was allocated by a Memory" ~
		" Allocation Manager that was not associated with" ~
		" a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_error("RegModel",
		format("Attempting to read from an offset outside" ~
		       " of the allocated region (%0d > %0d)",
		       offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.read(status, offset + this.get_start_offset(), value,
	     path, map, parent, prior, extension);
  }

  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.10
  // task
  public void burst_write(out uvm_status_e   status,
			  uvm_reg_addr_t     offset,
			  uvm_reg_data_t[]   value,
			  uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
			  uvm_reg_map        map    = null,
			  uvm_sequence_base  parent = null,
			  int                prior = -1,
			  uvm_object         extension = null,
			  string             fname = "",
			  int                lineno = 0) {
    uvm_mem mem = this.parent.get_memory();
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    if (mem is null) {
      uvm_error("RegModel", "Cannot use uvm_mem_region::burst_write()" ~
		" on a region that was allocated by a Memory" ~
		" Allocation Manager that was not associated with" ~
		" a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset + value.length > this.len) {
      uvm_error("RegModel",
		format("Attempting to burst-write to an offset" ~
		       " outside of the allocated region (burst" ~
		       " to [%0d:%0d] > mem_size %0d)",
		       offset,offset+value.length, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.burst_write(status, offset + get_start_offset(), value,
		    path, map, parent, prior, extension);

  }

  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.11
  // task
  public void burst_read(out uvm_status_e       status,
			 uvm_reg_addr_t         offset,
			 out uvm_reg_data_t[]   value,
			 uvm_door_e             path      = uvm_door_e.UVM_DEFAULT_DOOR,
			 uvm_reg_map            map       = null,
			 uvm_sequence_base      parent    = null,
			 int                    prior     = -1,
			 uvm_object             extension = null,
			 string                 fname     = "",
			 int                    lineno    = 0) {
    uvm_mem mem = this.parent.get_memory();
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    if (mem is null) {
      uvm_error("RegModel", "Cannot use uvm_mem_region::burst_read()" ~
		" on a region that was allocated by a Memory Allocation" ~
		" Manager that was not associated with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset + value.length > this.len) {
      uvm_error("RegModel",
		format("Attempting to burst-read to an offset" ~
		       " outside of the allocated region (burst" ~
		       " to [%0d:%0d] > mem_size %0d)",
		       offset,offset+value.length, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.burst_read(status, offset + get_start_offset(), value,
		   path, map, parent, prior, extension);

  }

  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.12
  // task
  public void poke(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   uvm_reg_data_t     value,
		   uvm_sequence_base  parent = null,
		   uvm_object         extension = null,
		   string             fname = "",
		   int                lineno = 0) {
    uvm_mem mem = this.parent.get_memory();
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    if (mem is null) {
      uvm_error("RegModel", "Cannot use uvm_mem_region::poke()" ~
		" on a region that was allocated by a Memory" ~
		" Allocation Manager that was not associated" ~
		" with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_error("RegModel",
		format("Attempting to poke to an offset outside" ~
		       " of the allocated region (%0d > %0d)",
		       offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.poke(status, offset + this.get_start_offset(), value, "",
	     parent, extension);
  }


  // @uvm-ieee 1800.2-2017 auto 18.12.7.2.13
  // task
  public void peek(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   out uvm_reg_data_t value,
		   uvm_sequence_base  parent = null,
		   uvm_object         extension = null,
		   string             fname = "",
		   int                lineno = 0) {
    uvm_mem mem = this.parent.get_memory();
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    if (mem is null) {
      uvm_error("RegModel", "Cannot use uvm_mem_region::peek()" ~
		" on a region that was allocated by a Memory" ~
		" Allocation Manager that was not associated" ~
		" with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_error("RegModel",
		format("Attempting to peek from an offset outside" ~
		       " of the allocated region (%0d > %0d)",
		       offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.peek(status, offset + this.get_start_offset(), value, "",
	     parent, extension);
  }


  public string convert2string() {
    synchronized(this) {
      return format("['h%h:'h%h]",
		    this._Xstart_offsetX, this._Xend_offsetX);
    }
  } // convert2string
};



//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_mem_mam_policy
//------------------------------------------------------------------------------
//
// An instance of this class is randomized to determine
// the starting offset of a randomly allocated memory region.
// This class can be extended to provide additional constraints
// on the starting offset, such as word alignment or
// location of the region within a memory page.
// If a procedural region allocation policy is required,
// it can be implemented in the pre/post_randomize() method.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 18.12.8.1
class uvm_mem_mam_policy
{
  mixin(uvm_sync_string);
  mixin Randomization;

  // variable -- NODOCS -- len
  // Number of addresses required
  @uvm_private_sync
  private uint _len;

  // variable -- NODOCS -- start_offset
  // The starting offset of the region
  @uvm_private_sync
  @rand private ulong _start_offset;

  // variable -- NODOCS -- min_offset
  // Minimum address offset in the managed address space
  @uvm_private_sync
  private ulong _min_offset;

  // variable -- NODOCS -- max_offset
  // Maximum address offset in the managed address space
  @uvm_private_sync
  private ulong _max_offset;

  // variable -- NODOCS -- in_use
  // Regions already allocated in the managed address space
  @uvm_private_sync
  private uvm_mem_region[] _in_use;

  Constraint!q{
    _start_offset >= _min_offset;
    _start_offset <= _max_offset - _len + 1;
  } uvm_mem_mam_policy_valid;

  Constraint!q{
    foreach (iu; _in_use) {
      _start_offset > iu._Xend_offsetX ||
	_start_offset + _len - 1 < iu._Xstart_offsetX;
    }
  } uvm_mem_mam_policy_no_overlap;

};



// @uvm-ieee 1800.2-2017 auto 18.12.9.1
class uvm_mem_mam_cfg
{
  mixin(uvm_sync_string);

  // variable -- NODOCS -- n_bytes
  // Number of bytes in each memory location

  @uvm_public_sync
  @rand private uint _n_bytes;

  // Mantis 6601 calls for these two offset fields to be type longint unsigned
  // variable -- NODOCS -- start_offset
  // Lowest address of managed space
  @uvm_public_sync
  @rand private ulong _start_offset;

  // variable -- NODOCS -- end_offset
  // Last address of managed space
  @uvm_public_sync
  @rand private ulong _end_offset;

  // variable -- NODOCS -- mode
  // Region allocation mode
  @uvm_public_sync
  @rand private uvm_mem_mam.alloc_mode_e _mode;

  // variable -- NODOCS -- locality
  // Region location mode
  @uvm_public_sync
  @rand private uvm_mem_mam.locality_e _locality;

  Constraint!q{
    _end_offset > _start_offset;
    _n_bytes < 64;
  } uvm_mem_mam_cfg_valid;
}
