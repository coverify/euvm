//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010 Cadence Design Systems, Inc.
//    Copyright 2014 Coverify Systems Technology LLP
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

import uvm.reg.uvm_mem;
import uvm.reg.uvm_vreg;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;

import uvm.seq.uvm_sequence_base;

import uvm.base.uvm_globals;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import uvm.meta.misc;

import esdl.data.bvec;
import esdl.rand;

import std.string: format;

//------------------------------------------------------------------------------
//
// Title: Memory Allocation Manager
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
// CLASS: uvm_mem_mam
//------------------------------------------------------------------------------
// Memory allocation manager
//
// Memory allocation management utility class similar to C's malloc()
// and free().
// A single instance of this class is used to manage a single,
// contiguous address space.
//------------------------------------------------------------------------------

class uvm_mem_mam
{

  //----------------------
  // Group: Initialization
  //----------------------

  // Type: alloc_mode_e
  //
  // Memory allocation mode
  //
  // Specifies how to allocate a memory region
  //
  // GREEDY   - Consume new, previously unallocated memory
  // THRIFTY  - Reused previously released memory as much as possible (not yet implemented)
  //
  enum alloc_mode_e: bool {
    GREEDY,
    THRIFTY
  };
  mixin(declareEnums!alloc_mode_e);

  // Type: locality_e
  //
  // Location of memory regions
  //
  // Specifies where to locate new memory regions
  //
  // BROAD    - Locate new regions randomly throughout the address space
  // NEARBY   - Locate new regions adjacent to existing regions

  enum locality_e: bool {
    BROAD,
    NEARBY
  };
  mixin(declareEnums!locality_e);

  // Variable: default_alloc
  //
  // Region allocation policy
  //
  // This object is repeatedly randomized when allocating new regions.
  @uvm_private_sync
  uvm_mem_mam_policy _default_alloc;

  mixin(uvm_sync_string);
  
  @uvm_private_sync
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


  // Function: new
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
  // function new(string      name,
  //	       uvm_mem_mam_cfg cfg,
  //	       uvm_mem mem = null);

  public this(string name,
	      uvm_mem_mam_cfg cfg,
	      uvm_mem mem=null) {
    synchronized(this) {
      this._cfg           = cfg;
      this._memory        = mem;
      this._default_alloc = new uvm_mem_mam_policy;
    }
  }


  // Function: reconfigure
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
  // extern function uvm_mem_mam_cfg reconfigure(uvm_mem_mam_cfg cfg = null);

  public uvm_mem_mam_cfg reconfigure(uvm_mem_mam_cfg cfg = null) {
    synchronized(this) {
      uvm_root top;

      if (cfg is null) {
	return this._cfg;
      }

      top = uvm_root.get();

      // Cannot reconfigure n_bytes
      if (cfg._n_bytes != this._cfg._n_bytes) {
	top.uvm_report_error("uvm_mem_mam",
			     format("Cannot reconfigure Memory Allocation " ~
				    "Manager with a different number of " ~
				    "bytes (%0d !== %0d)",
				    cfg._n_bytes, this._cfg._n_bytes), UVM_LOW);
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
			       UVM_LOW);
	  return this._cfg;
	}
      }

      auto reconfigure_ = this._cfg;
      this._cfg = cfg;
      return reconfigure_;
    }
  } // reconfigure

  //-------------------------
  // Group: Memory Management
  //-------------------------

  // Function: reserve_region
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
  // extern function uvm_mem_region reserve_region(bit [63:0]   start_offset,
  //						int unsigned n_bytes,
  //						string       fname = "",
  //						int          lineno = 0);


  public uvm_mem_region reserve_region(uvm_reg_addr_t      start_offset,
				       uint                n_bytes,
				       string              fname = "",
				       int                 lineno = 0) {
    synchronized(this) {
      uvm_mem_region reserve_region_;
      this.fname = fname;
      this.lineno = lineno;
      if (n_bytes == 0) {
	uvm_report_error("RegModel", "Cannot reserve 0 bytes");
	return null;
      }

      if (start_offset < this.cfg.start_offset) {
	uvm_report_error("RegModel", format("Cannot reserve before start " ~
					    "of memory space: 'h%h < 'h%h",
					    start_offset, this.cfg.start_offset));
	return null;
      }

      ulong end_offset = start_offset + ((n_bytes-1) / this.cfg.n_bytes);
      n_bytes = cast(uint) ((end_offset - start_offset + 1) * this.cfg.n_bytes);

      if (end_offset > this.cfg.end_offset) {
	uvm_report_error("RegModel", format("Cannot reserve past end of " ~
					    "memory space: 'h%h > 'h%h",
					    end_offset, this.cfg.end_offset));
	return null;
      }

      uvm_report_info("RegModel", format("Attempting to reserve ['h%h:'h%h]...",
					 start_offset, end_offset), UVM_MEDIUM);

      foreach (i, used; this._in_use) {
	if (start_offset <= used.get_end_offset() &&
	    end_offset >= used.get_start_offset()) {
	  // Overlap!
	  uvm_report_error("RegModel", format("Cannot reserve ['h%h:'h%h] " ~
					      "because it overlaps with %s",
					      start_offset, end_offset,
					      used.convert2string()));
	  return null;
	}

	// Regions are stored in increasing start offset
	if (start_offset > used.get_start_offset()) {
	  reserve_region_ = new uvm_mem_region(cast(ulong) start_offset, end_offset,
					       cast(uint) (end_offset - start_offset + 1),
					       cast(uint) n_bytes, this);
	  this._in_use = _in_use[0..i] ~ reserve_region_ ~
	    _in_use[i..$];	// insert(i, reserve_region_);
	  return reserve_region_;
	}
      }

      reserve_region_ = new uvm_mem_region(cast(ulong) start_offset, end_offset,
					   cast(uint) (end_offset - start_offset + 1),
					   cast(uint) n_bytes, this);
      this._in_use ~= reserve_region_;
      return reserve_region_;
    }
  } // reserve_region

  // Function: request_region
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
  // extern function uvm_mem_region request_region(int unsigned   n_bytes,
  //						uvm_mem_mam_policy alloc = null,
  //						string         fname = "",
  //						int            lineno = 0);

  public uvm_mem_region request_region(uint                  n_bytes,
				       uvm_mem_mam_policy    alloc = null,
				       string            fname = "",
				       int               lineno = 0) {
    synchronized(this) {
      this.fname = fname;
      this.lineno = lineno;
      if (alloc is null) alloc = this.default_alloc;

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
	uvm_report_error("RegModel", "Unable to randomize policy");
	return null;
      }

      return reserve_region(cast(uvm_reg_addr_t) alloc.start_offset, n_bytes);
    }
  } // request_region

  // Function: release_region
  //
  // Release the specified region
  //
  // Release a previously allocated memory region.
  // An error is issued if the
  // specified region has not been previously allocated or
  // is no longer allocated.
  //
  // extern function void release_region(uvm_mem_region region);

  public void release_region(uvm_mem_region region) {
    synchronized(this) {
      if (region is null) return;

      foreach (i, used; this._in_use) {
	if (used is region) {
	  this._in_use = _in_use[0..i] ~ _in_use[i+1..$]; // .remove(i);
	  return;
	}
      }
      uvm_report_error("RegModel", "Attempting to release unallocated region\n" ~
		       region.convert2string());
    }
  } // release_region


  // Function: release_all_regions
  //
  // Forcibly release all allocated memory regions.
  //
  // extern function void release_all_regions();

  public void release_all_regions() {
    synchronized(this) {
      _in_use.length = 0;
    }
  } // release_all_regions


  //---------------------
  // Group: Introspection
  //---------------------

  // Function: convert2string
  //
  // Image of the state of the manager
  //
  // Create a human-readable description of the state of
  // the memory manager and the currently allocated regions.
  //
  // extern function string convert2string();

  string convert2string() {
    synchronized(this) {
      string _convert2string = "Allocated memory regions:\n";
      foreach (i, used; this._in_use) {
	_convert2string ~= format("   %s\n",
				  used.convert2string());
      }
      return _convert2string;
    }
  } // convert2string

  // Function: for_each
  //
  // Iterate over all currently allocated regions
  //
  // If reset is ~TRUE~, reset the iterator
  // and return the first allocated region.
  // Returns ~null~ when there are no additional allocated
  // regions to iterate on.
  //
  // extern function uvm_mem_region for_each(bit reset = 0);

  uvm_mem_region for_each(bool reset = false) {
    synchronized(this) {
      if (reset) this._for_each_idx = -1;

      this._for_each_idx++;

      if (this._for_each_idx >= this._in_use.length) {
	return null;
      }

      return this._in_use[this._for_each_idx];
    }
  } // for_each



  // Function: get_memory
  //
  // Get the managed memory implementation
  //
  // Return the reference to the memory abstraction class
  // for the memory implementing
  // the locations managed by this instance of the allocation manager.
  // Returns ~null~ if no
  // memory abstraction class was specified at construction time.
  //
  // extern function uvm_mem get_memory();
  public uvm_mem get_memory() {
    synchronized(this) {
      return this._memory;
    }
  } // get_memory

}; // uvm_mem_mam



//------------------------------------------------------------------------------
// CLASS: uvm_mem_region
//------------------------------------------------------------------------------
// Allocated memory region descriptor
//
// Each instance of this class describes an allocated memory region.
// Instances of this class are created only by
// the memory manager, and returned by the
// <uvm_mem_mam::reserve_region()> and <uvm_mem_mam::request_region()>
// methods.
//------------------------------------------------------------------------------

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


  // extern /*local*/ function new(bit [63:0]   start_offset,
  //				bit [63:0]   end_offset,
  //				int unsigned len,
  //				int unsigned n_bytes,
  //				uvm_mem_mam      parent);


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
  } // new


    // Function: get_start_offset
    //
    // Get the start offset of the region
    //
    // Return the address offset, within the memory,
    // where this memory region starts.
    //
    // extern function bit [63:0] get_start_offset();

  public ulong get_start_offset() {
    synchronized(this) {
      return this._Xstart_offsetX;
    }
  } // get_start_offset



    // Function: get_end_offset
    //
    // Get the end offset of the region
    //
    // Return the address offset, within the memory,
    // where this memory region ends.
    //
    // extern function bit [63:0] get_end_offset();

  public ulong get_end_offset() {
    synchronized(this) {
      return this._Xend_offsetX;
    }
  } // get_end_offset



    // Function: get_len
    //
    // Size of the memory region
    //
    // Return the number of consecutive memory locations
    // (not necessarily bytes) in the allocated region.
    //
    // extern function int unsigned get_len();

  public uint get_len() {
    synchronized(this) {
      return this._len;
    }
  } // get_len



    // Function: get_n_bytes
    //
    // Number of bytes in the region
    //
    // Return the number of consecutive bytes in the allocated region.
    // If the managed memory contains more than one byte per address,
    // the number of bytes in an allocated region may
    // be greater than the number of requested or reserved bytes.
    //
    // extern function int unsigned get_n_bytes();

  public uint get_n_bytes() {
    synchronized(this) {
      return this._n_bytes;
    }
  } // get_n_bytes


    // Function: release_region
    //
    // Release this region
    //
    // extern function void release_region();

  public void release_region() {
    this.parent.release_region(this);
  }


  // Function: get_memory
  //
  // Get the memory where the region resides
  //
  // Return a reference to the memory abstraction class
  // for the memory implementing this allocated memory region.
  // Returns ~null~ if no memory abstraction class was specified
  // for the allocation manager that allocated this region.
  //
  // extern function uvm_mem get_memory();

  public uvm_mem get_memory() {
    return this.parent.get_memory();
  } // get_memory



    // Function: get_virtual_registers
    //
    // Get the virtual register array in this region
    //
    // Return a reference to the virtual register array abstraction class
    // implemented in this region.
    // Returns ~null~ if the memory region is
    // not known to implement virtual registers.
    //
    // extern function uvm_vreg get_virtual_registers();

  public uvm_vreg get_virtual_registers() {
    synchronized(this) {
      return this._XvregX;
    }
  } // get_virtual_registers


    // Task: write
    //
    // Write to a memory location in the region.
    //
    // Write to the memory location that corresponds to the
    // specified ~offset~ within this region.
    // Requires that the memory abstraction class be associated with
    // the memory allocation manager that allocated this region.
    //
    // See <uvm_mem::write()> for more details.
    //
    // extern task write(output uvm_status_e       status,
    //		    input  uvm_reg_addr_t     offset,
    //		    input  uvm_reg_data_t     value,
    //		    input  uvm_path_e         path   = UVM_DEFAULT_PATH,
    //		    input  uvm_reg_map        map    = null,
    //		    input  uvm_sequence_base  parent = null,
    //		    input  int                prior = -1,
    //		    input  uvm_object         extension = null,
    //		    input  string             fname = "",
    //		    input  int                lineno = 0);

    // task
  public void write(out uvm_status_e   status,
		    uvm_reg_addr_t     offset,
		    uvm_reg_data_t     value,
		    uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
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
      uvm_report_error("RegModel", "Cannot use uvm_mem_region::write() on" ~
		       " a region that was allocated by a Memory Allocation" ~
		       " Manager that was not associated with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_report_error("RegModel",
		       format("Attempting to write to an offset outside"
			      ~ " of the allocated region (%0d > %0d)",
			      offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.write(status, offset + this.get_start_offset(), value,
	      path, map, parent, prior, extension);
  } // write

    // Task: read
    //
    // Read from a memory location in the region.
    //
    // Read from the memory location that corresponds to the
    // specified ~offset~ within this region.
    // Requires that the memory abstraction class be associated with
    // the memory allocation manager that allocated this region.
    //
    // See <uvm_mem::read()> for more details.
    //
    // extern task read(output uvm_status_e       status,
    //		   input  uvm_reg_addr_t     offset,
    //		   output uvm_reg_data_t     value,
    //		   input  uvm_path_e         path   = UVM_DEFAULT_PATH,
    //		   input  uvm_reg_map        map    = null,
    //		   input  uvm_sequence_base  parent = null,
    //		   input  int                prior = -1,
    //		   input  uvm_object         extension = null,
    //		   input  string             fname = "",
    //		   input  int                lineno = 0);

    // task
  public void read(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   out uvm_reg_data_t value,
		   uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
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
      uvm_report_error("RegModel", "Cannot use uvm_mem_region::read()" ~
		       " on a region that was allocated by a Memory" ~
		       " Allocation Manager that was not associated with" ~
		       " a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_report_error("RegModel",
		       format("Attempting to read from an offset outside" ~
			      " of the allocated region (%0d > %0d)",
			      offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.read(status, offset + this.get_start_offset(), value,
	     path, map, parent, prior, extension);
  } // read

    // Task: burst_write
    //
    // Write to a set of memory location in the region.
    //
    // Write to the memory locations that corresponds to the
    // specified ~burst~ within this region.
    // Requires that the memory abstraction class be associated with
    // the memory allocation manager that allocated this region.
    //
    // See <uvm_mem::burst_write()> for more details.
    //
    // extern task burst_write(output uvm_status_e       status,
    //			  input  uvm_reg_addr_t     offset,
    //			  input  uvm_reg_data_t     value[],
    //			  input  uvm_path_e         path   = UVM_DEFAULT_PATH,
    //			  input  uvm_reg_map        map    = null,
    //			  input  uvm_sequence_base  parent = null,
    //			  input  int                prior  = -1,
    //			  input  uvm_object         extension = null,
    //			  input  string             fname  = "",
    //			  input  int                lineno = 0);

    // task
  public void burst_write(out uvm_status_e   status,
			  uvm_reg_addr_t     offset,
			  uvm_reg_data_t[]   value,
			  uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
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
      uvm_report_error("RegModel", "Cannot use uvm_mem_region::burst_write()" ~
		       " on a region that was allocated by a Memory" ~
		       " Allocation Manager that was not associated with" ~
		       " a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset + value.length > this.len) {
      uvm_report_error("RegModel",
		       format("Attempting to burst-write to an offset" ~
			      " outside of the allocated region (burst" ~
			      " to [%0d:%0d] > mem_size %0d)",
			      offset,offset+value.length, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.burst_write(status, offset + get_start_offset(), value,
		    path, map, parent, prior, extension);

  } // burst_write



    // Task: burst_read
    //
    // Read from a set of memory location in the region.
    //
    // Read from the memory locations that corresponds to the
    // specified ~burst~ within this region.
    // Requires that the memory abstraction class be associated with
    // the memory allocation manager that allocated this region.
    //
    // See <uvm_mem::burst_read()> for more details.
    //
    // extern task burst_read(output uvm_status_e       status,
    //			 input  uvm_reg_addr_t     offset,
    //			 output uvm_reg_data_t     value[],
    //			 input  uvm_path_e         path   = UVM_DEFAULT_PATH,
    //			 input  uvm_reg_map        map    = null,
    //			 input  uvm_sequence_base  parent = null,
    //			 input  int                prior  = -1,
    //			 input  uvm_object         extension = null,
    //			 input  string             fname  = "",
    //			 input  int                lineno = 0);

    // task
  public void burst_read(out uvm_status_e       status,
			 uvm_reg_addr_t         offset,
			 out uvm_reg_data_t[]   value,
			 uvm_path_e             path      = uvm_path_e.UVM_DEFAULT_PATH,
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
      uvm_report_error("RegModel", "Cannot use uvm_mem_region::burst_read()" ~
		       " on a region that was allocated by a Memory Allocation" ~
		       " Manager that was not associated with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset + value.length > this.len) {
      uvm_report_error("RegModel",
		       format("Attempting to burst-read to an offset" ~
			      " outside of the allocated region (burst" ~
			      " to [%0d:%0d] > mem_size %0d)",
			      offset,offset+value.length, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.burst_read(status, offset + get_start_offset(), value,
		   path, map, parent, prior, extension);

  } // burst_read


    // Task: poke
    //
    // Deposit in a memory location in the region.
    //
    // Deposit the specified value in the memory location
    // that corresponds to the
    // specified ~offset~ within this region.
    // Requires that the memory abstraction class be associated with
    // the memory allocation manager that allocated this region.
    //
    // See <uvm_mem::poke()> for more details.
    //
    // extern task poke(output uvm_status_e       status,
    //		   input  uvm_reg_addr_t     offset,
    //		   input  uvm_reg_data_t     value,
    //		   input  uvm_sequence_base  parent = null,
    //		   input  uvm_object         extension = null,
    //		   input  string             fname = "",
    //		   input  int                lineno = 0);

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
      uvm_report_error("RegModel", "Cannot use uvm_mem_region::poke()" ~
		       " on a region that was allocated by a Memory" ~
		       " Allocation Manager that was not associated" ~
		       " with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_report_error("RegModel",
		       format("Attempting to poke to an offset outside" ~
			      " of the allocated region (%0d > %0d)",
			      offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.poke(status, offset + this.get_start_offset(), value, "",
	     parent, extension);
  } // poke



    // Task: peek
    //
    // Sample a memory location in the region.
    //
    // Sample the memory location that corresponds to the
    // specified ~offset~ within this region.
    // Requires that the memory abstraction class be associated with
    // the memory allocation manager that allocated this region.
    //
    // See <uvm_mem::peek()> for more details.
    //
    // extern task peek(output uvm_status_e       status,
    //		   input  uvm_reg_addr_t     offset,
    //		   output uvm_reg_data_t     value,
    //		   input  uvm_sequence_base  parent = null,
    //		   input  uvm_object         extension = null,
    //		   input  string             fname = "",
    //		   input  int                lineno = 0);

    // task
  public void peek(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   out uvm_reg_data_t value,
		   uvm_sequence_base  parent = null,
		   uvm_object         extension = null,
		   string             fname = "",
		   int                lineno = 0) {
    uvm_mem mem = this.parent.get_memory();
    this.fname = fname;
    this.lineno = lineno;

    if (mem is null) {
      uvm_report_error("RegModel", "Cannot use uvm_mem_region::peek()" ~
		       " on a region that was allocated by a Memory" ~
		       " Allocation Manager that was not associated" ~
		       " with a uvm_mem instance");
      status = UVM_NOT_OK;
      return;
    }

    if (offset > this.len) {
      uvm_report_error("RegModel",
		       format("Attempting to peek from an offset outside" ~
			      " of the allocated region (%0d > %0d)",
			      offset, this.len));
      status = UVM_NOT_OK;
      return;
    }

    mem.peek(status, offset + this.get_start_offset(), value, "",
	     parent, extension);
  } // peek


    // extern function string convert2string();
  public string convert2string() {
    synchronized(this) {
      return format("['h%h:'h%h]",
		    this._Xstart_offsetX, this._Xend_offsetX);
    }
  } // convert2string
};



//------------------------------------------------------------------------------
// Class: uvm_mem_mam_policy
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

class uvm_mem_mam_policy
{
  mixin(uvm_sync_string);
  mixin Randomization;
  // variable: len
  // Number of addresses required
  @uvm_private_sync
  private uint _len;

  // variable: start_offset
  // The starting offset of the region
  @uvm_private_sync
  @rand private ulong _start_offset;

  // variable: min_offset
  // Minimum address offset in the managed address space
  @uvm_private_sync
  private ulong _min_offset;

  // variable: max_offset
  // Maximum address offset in the managed address space
  @uvm_private_sync
  private ulong _max_offset;

  // variable: in_use
  // Regions already allocated in the managed address space
  @uvm_private_sync
  private uvm_mem_region[] _in_use;

  Constraint!q{
    _start_offset >= _min_offset;
    _start_offset <= _max_offset - _len + 1;
  } uvm_mem_mam_policy_valid;

  // For now, Vlang does not know how to handle an array of
  // objects in constraints -- not difficult to implement though
      
  // Constraint!q{
  // 	foreach (iu; _in_use) {
  // 	  _start_offset > iu.Xend_offsetX ||
  // 	    _start_offset + _len - 1 < iu.Xstart_offsetX;
  // 	}
  // } uvm_mem_mam_policy_no_overlap;

};



//
// CLASS: uvm_mem_mam_cfg
// Specifies the memory managed by an instance of a <uvm_mem_mam> memory
// allocation manager class.
//
class uvm_mem_mam_cfg
{
  mixin(uvm_sync_string);
  // variable: n_bytes
  // Number of bytes in each memory location

  @uvm_public_sync
  @rand private uint _n_bytes;

  // FIXME start_offset and end_offset should be "longint unsigned" to match the memory addr types
  // variable: start_offset
  // Lowest address of managed space
  @uvm_public_sync
  @rand private ulong _start_offset;

  // variable: end_offset
  // Last address of managed space
  @uvm_public_sync
  @rand private ulong _end_offset;

  // variable: mode
  // Region allocation mode
  @uvm_public_sync
  @rand private uvm_mem_mam.alloc_mode_e _mode;

  // variable: locality
  // Region location mode
  @uvm_public_sync
  @rand private uvm_mem_mam.locality_e _locality;

  Constraint!q{
    _end_offset > _start_offset;
    _n_bytes < 64;
  } uvm_mem_mam_cfg_valid;
}
