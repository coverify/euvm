//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010-2011 Cadence Design Systems, Inc.
//    Copyright 2014 Coverify Systems Technology
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


//------------------------------------------------------------------------------
// CLASS: uvm_mem
//------------------------------------------------------------------------------
// Memory abstraction base class
//
// A memory is a collection of contiguous locations.
// A memory may be accessible via more than one address map.
//
// Unlike registers, memories are not mirrored because of the potentially
// large data space: tests that walk the entire memory space would negate
// any benefit from sparse memory modelling techniques.
// Rather than relying on a mirror, it is recommended that
// backdoor access be used instead.
//
//------------------------------------------------------------------------------

module uvm.reg.uvm_mem;

import uvm.base.uvm_callback;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_printer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_packer;
import uvm.base.uvm_globals;

import uvm.seq.uvm_sequence_base;

import uvm.meta.misc;

import uvm.dpi.uvm_hdl;

import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_backdoor;
import uvm.reg.uvm_reg_cbs;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_sequence;
import uvm.reg.uvm_vreg;
import uvm.reg.uvm_vreg_field;
import uvm.reg.uvm_mem_mam;

import std.string: format, toUpper;

class uvm_mem: uvm_object
{

  // init_e is not used anywhere 
  // enum init_e: byte {UNKNOWNS, ZEROES, ONES, ADDRESS, VALUE, INCR, DECR}

  mixin(uvm_sync_string);
  @uvm_private_sync
  private bool               _m_locked;
  @uvm_private_sync
  private bool               _m_read_in_progress;
  @uvm_private_sync
  private bool               _m_write_in_progress;
  @uvm_private_sync
  private string             _m_access;
  @uvm_private_sync
  private ulong              _m_size;
  @uvm_private_sync
  private uvm_reg_block      _m_parent;
  @uvm_private_sync
  private bool[uvm_reg_map]  _m_maps;
  @uvm_private_sync
  private uint               _m_n_bits;
  @uvm_private_sync
  private uvm_reg_backdoor   _m_backdoor;
  @uvm_private_sync
  private bool               _m_is_powered_down;
  @uvm_private_sync
  private int                _m_has_cover;
  @uvm_private_sync
  private int                _m_cover_on;
  @uvm_private_sync
  private string             _m_fname;
  @uvm_private_sync
  private int                _m_lineno;
  @uvm_private_sync
  private bool[uvm_vreg]     _m_vregs;
  @uvm_private_sync
  private uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat)) _m_hdl_paths_pool;

  // FIXME -- my assumption is that the next field is required only
  //  for the reason that SV does not have full blown generic programming

  // need to see if there is a need to make this variable shared at
  // all. There is only one fork in the whole uvm_reg package and that
  // too in the backdoor module. For now we will assume that the whole
  // uvm_reg package works on a single thread. We will revisit this
  // later. There only a handfull of static variables anyway in the
  // whole uvm_reg package.
  private static uint  _m_max_size;

  //----------------------
  // Group: Initialization
  //----------------------

  // Function: new
  //
  // Create a new instance and type-specific configuration
  //
  // Creates an instance of a memory abstraction class with the specified
  // name.
  //
  // ~size~ specifies the total number of memory locations.
  // ~n_bits~ specifies the total number of bits in each memory location.
  // ~access~ specifies the access policy of this memory and may be
  // one of "RW for RAMs and "RO" for ROMs.
  //
  // ~has_coverage~ specifies which functional coverage models are present in
  // the extension of the register abstraction class.
  // Multiple functional coverage models may be specified by adding their
  // symbolic names, as defined by the <uvm_coverage_model_e> type.
  //

  // extern function new (string           name,
  // 		       longint unsigned size,
  // 		       int unsigned     n_bits,
  // 		       string           access = "RW",
  // 		       int              has_coverage = UVM_NO_COVERAGE);

  this(string name,
       ulong size,
       uint n_bits,
       string access = "RW",
       int has_coverage = uvm_coverage_model_e.UVM_NO_COVERAGE) {
    synchronized(this) {
      super(name);
      _m_locked = 0;
      if(n_bits is 0) {
	uvm_error("RegModel", "Memory '" ~ get_full_name() ~ "' cannot have 0 bits");
	n_bits = 1;
      }
      _m_size      = size;
      _m_n_bits    = n_bits;
      _m_backdoor  = null;
      _m_access    = access.toUpper();
      _m_has_cover = has_coverage;
      _m_hdl_paths_pool =
	new uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))("hdl_paths");

      if (n_bits > _m_max_size) {
	_m_max_size = n_bits;
      }

      //-----------------
      // Group: Callbacks
      //-----------------
      // uvm_register_cb(uvm_mem, uvm_reg_cbs)

      mixin uvm_register_cb!(uvm_reg_cbs);
    }
  }

   
  // Function: configure
  //
  // Instance-specific configuration
  //
  // Specify the parent block of this memory.
  //
  // If this memory is implemented in a single HDL variable,
  // it's name is specified as the ~hdl_path~.
  // Otherwise, if the memory is implemented as a concatenation
  // of variables (usually one per bank), then the HDL path
  // must be specified using the <add_hdl_path()> or
  // <add_hdl_path_slice()> method.
  //
   
  // extern function void configure (uvm_reg_block parent,
  //                                 string        hdl_path = "");

  // configure
  final void configure(uvm_reg_block  parent,
			      string         hdl_path="") {

    synchronized(this) {
      if (parent is null)
	uvm_fatal("REG/NULL_PARENT", "configure: parent argument is null");

      _m_parent = parent;

      if (_m_access != "RW" && _m_access != "RO") {
	uvm_error("RegModel", "Memory '" ~ get_full_name() ~ "' can only be RW or RO");
	_m_access = "RW";
      }

      uvm_mem_mam_cfg cfg = new uvm_mem_mam_cfg;

      cfg.n_bytes      = ((_m_n_bits-1) / 8) + 1;
      cfg.start_offset = 0;
      cfg.end_offset   = _m_size-1;

      cfg.mode     = uvm_mem_mam.GREEDY;
      cfg.locality = uvm_mem_mam.BROAD;

      _mam = new uvm_mem_mam(get_full_name(), cfg, this);

      _m_parent.add_mem(this);

      if (hdl_path != "") add_hdl_path_slice(hdl_path, -1, -1);
    }
  }

  // Function: set_offset
  //
  // Modify the offset of the memory
  //
  // The offset of a memory within an address map is set using the
  // <uvm_reg_map::add_mem()> method.
  // This method is used to modify that offset dynamically.
  //
  // Note: Modifying the offset of a memory will make the abstract model
  // diverge from the specification that was used to create it.
  //

  // extern virtual function void set_offset (uvm_reg_map    map,
  //                                          uvm_reg_addr_t offset,
  //                                          bit            unmapped = 0);

  // set_offset

  final void set_offset (uvm_reg_map    map,
				uvm_reg_addr_t offset,
				bool unmapped = false) {
    synchronized(this) {
      uvm_reg_map orig_map = map;

      if (_m_maps.length > 1 && map is null) {
	uvm_error("RegModel", "set_offset requires a non-null map when memory '" ~
		  get_full_name() ~ "' belongs to more than one map.");
	return;
      }

      map = get_local_map(map,"set_offset()");

      if (map is null) {
	return;
      }
   
      map.m_set_mem_offset(this, offset, unmapped);
    }
  }


  // /*local*/ extern virtual function void set_parent(uvm_reg_block parent);

  // set_parent
  final void set_parent(uvm_reg_block parent) {
    synchronized(this) {
      _m_parent = parent;
    }
  }

  // /*local*/ extern function void add_map(uvm_reg_map map);
  // add_map
  final void add_map(uvm_reg_map map) {
    synchronized(this) {
      _m_maps[map] = 1;
    }
  }

  // /*local*/ extern function void Xlock_modelX();
  // Xlock_modelX
  final void Xlock_modelX() {
    synchronized(this) {
      _m_locked = 1;
    }
  }

  // /*local*/ extern function void Xadd_vregX(uvm_vreg vreg);
  // Xadd_vregX
  final void Xadd_vregX(uvm_vreg vreg) {
    synchronized(this) {
      _m_vregs[vreg] = 1;
    }
  }


  // /*local*/ extern function void Xdelete_vregX(uvm_vreg vreg);
  // Xdelete_vregX
  final void Xdelete_vregX(uvm_vreg vreg) {
    synchronized(this) {
      if (vreg in _m_vregs) {
	_m_vregs.remove(vreg);
      }
    }
  }


  // variable: mam
  //
  // Memory allocation manager
  //
  // Memory allocation manager for the memory corresponding to this
  // abstraction class instance.
  // Can be used to allocate regions of consecutive addresses of
  // specific sizes, such as DMA buffers,
  // or to locate virtual register array.
  //
  @uvm_public_sync
  uvm_mem_mam _mam;


  //---------------------
  // Group: Introspection
  //---------------------

  // Function: get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this memory.
  //

  // Function: get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this memory.
  // The base of the hierarchical name is the root block.
  //

  // extern virtual function string get_full_name();
  // get_full_name
  override string get_full_name() {
    synchronized(this) {
      if (_m_parent is null)
	return get_name();
   
      return _m_parent.get_full_name() ~ "." ~ get_name();
    }
  }


  // Function: get_parent
  //
  // Get the parent block
  //

  // extern virtual function uvm_reg_block get_parent ();

  // get_parent

  uvm_reg_block get_parent() {
    return get_block();
  }


  // extern virtual function uvm_reg_block get_block  ();
  // get_block

  uvm_reg_block get_block() {
    synchronized(this) {
      return _m_parent;
    }
  }


  // Function: get_n_maps
  //
  // Returns the number of address maps this memory is mapped in
  //

  // extern virtual function int get_n_maps ();
  // get_n_maps

  int get_n_maps() {
    synchronized(this) {
      return cast(int) _m_maps.length;
    }
  }

  // Function: is_in_map
  //
  // Return TRUE if this memory is in the specified address ~map~
  //

  // extern function bit is_in_map (uvm_reg_map map);
  // is_in_map

  final bool is_in_map(uvm_reg_map map) {
    synchronized(this) {
      if (map in _m_maps) {
	return true;
	foreach (l, m; _m_maps) {
	  uvm_reg_map local_map = l;
	  uvm_reg_map parent_map = local_map.get_parent_map();

	  while (parent_map !is null) {
	    if (parent_map is map) {
	      return true;
	    }
	    parent_map = parent_map.get_parent_map();
	  }
	}
      }
      return false;
    }
  }


  // Function: get_maps
  //
  // Returns all of the address ~maps~ where this memory is mapped
  //

  // extern virtual function void get_maps (ref uvm_reg_map maps[$]);
  // get_maps
  // maps is a queue in SV version
  void get_maps(ref uvm_reg_map[] maps) {
    synchronized(this) {
      foreach (map, unused; _m_maps) {
	maps ~= map;
      }
    }
  }

  // /*local*/ extern function uvm_reg_map get_local_map   (uvm_reg_map map,
  final uvm_reg_map get_local_map(uvm_reg_map map, string caller="") {
    synchronized(this) {
      if (map is null) {
	return get_default_map();
      }
      if (map in _m_maps) {
	return map;
      }
      foreach(l, unused; _m_maps) {
	uvm_reg_map local_map = l;
	uvm_reg_map parent_map = local_map.get_parent_map();

	while (parent_map !is null) {
	  if (parent_map is map) {
	    return local_map;
	  }
	  parent_map = parent_map.get_parent_map();
	}
      }
      uvm_warning("RegModel", 
		  "Memory '" ~ get_full_name() ~ "' is not contained within map '" ~ map.get_full_name() ~ "'" ~
		  (caller == "" ? "": " (called from " ~ caller ~ ")"));
      return null;
    }
  }


  // /*private*/ extern function uvm_reg_map get_default_map (string caller = "");

  // get_default_map

  final uvm_reg_map get_default_map(string caller="") {
    synchronized(this) {
      // if mem is not associated with any may, return null
      if (_m_maps.length is 0) {
	uvm_warning("RegModel", 
		    "Memory '" ~ get_full_name() ~ "' is not registered with any map" ~
		    (caller == "" ? "": " (called from " ~ caller ~ ")"));
	return null;
      }

      // 
      // if only one map, choose that
      if (_m_maps.length is 1) {
	return _m_maps.keys[0];
	// SV version is wrong here
	// retval = _m_maps.values[0];
      }

      // try to choose one based on default_map in parent blocks.
      foreach(l, unused; _m_maps) {
	uvm_reg_map map = l;
	uvm_reg_block blk = map.get_parent();
	uvm_reg_map default_map = blk.get_default_map();
	if (default_map !is null) {
	  uvm_reg_map local_map = get_local_map(default_map);
	  if (local_map !is null)
	    return local_map;
	}
      }
      // if that fails, choose the first in this mem's maps
      return _m_maps.keys[0];
    }
  }

  // Function: get_rights
  //
  // Returns the access rights of this memory.
  //
  // Returns "RW", "RO" or "WO".
  // The access rights of a memory is always "RW",
  // unless it is a shared memory
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

  // extern virtual function string get_rights (uvm_reg_map map = null);
  // get_rights

  string get_rights(uvm_reg_map map = null) {
    synchronized(this) {

      // No right restrictions if not shared
      if (_m_maps.length <= 1) {
	return "RW";
      }

      map = get_local_map(map,"get_rights()");

      if (map is null) {
	return "RW";
      }

      uvm_reg_map_info info = map.get_mem_map_info(this);
      return info.rights;
    }
  }

  // Function: get_access
  //
  // Returns the access policy of the memory when written and read
  // via an address map.
  //
  // If the memory is mapped in more than one address map,
  // an address ~map~ must be specified.
  // If access restrictions are present when accessing a memory
  // through the specified address map, the access mode returned
  // takes the access restrictions into account.
  // For example, a read-write memory accessed
  // through a domain with read-only restrictions would return "RO". 
  //

  // extern virtual function string get_access(uvm_reg_map map = null);
  // get_access

  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      string retval = _m_access;
      if (get_n_maps() is 1) return retval;

      map = get_local_map(map, "get_access()");
      if(map is null) return retval;

      // Is the memory restricted in this map?
      switch(get_rights(map)) {
      case "RW":
	// No restrictions
	return retval;
      case "RO":
	switch(retval) {
	case "RW", "RO": retval = "RO"; break;
	case "WO": uvm_error("RegModel", "WO memory '" ~ get_full_name() ~
			     "' restricted to RO in map '" ~ map.get_full_name() ~ "'");
	  break;
	default: uvm_error("RegModel", "Memory '" ~ get_full_name() ~
			   "' has invalid access mode, '" ~ retval ~ "'");
	}
	break;
      case "WO":
	switch(retval) {
	case "RW", "WO": retval = "WO"; break;
	case "RO":    uvm_error("RegModel", "RO memory '" ~ get_full_name() ~
				"' restricted to WO in map '" ~
				map.get_full_name() ~ "'"); break;
	default: uvm_error("RegModel", "Memory '" ~ get_full_name() ~
			   "' has invalid access mode, '" ~ retval ~ "'");
	}
	break;
      default: uvm_error("RegModel", "Shared memory '" ~ get_full_name() ~
			 "' is not shared in map '" ~ map.get_full_name() ~ "'");
      }
      return retval;
    }
  }

  // Function: get_size
  //
  // Returns the number of unique memory locations in this memory. 
  //

  // extern function longint unsigned get_size();
  // get_size

  final ulong get_size() {
    synchronized(this) {
      return _m_size;
    }
  }

  // Function: get_n_bytes
  //
  // Return the width, in number of bytes, of each memory location
  //

  // extern function int unsigned get_n_bytes();
  // get_n_bytes

  final uint get_n_bytes() {
    synchronized(this) {
      return(_m_n_bits - 1) / 8 + 1;
    }
  }

  // Function: get_n_bits
  //
  // Returns the width, in number of bits, of each memory location
  //

  // extern function int unsigned get_n_bits();

  // get_n_bits

  final uint get_n_bits() {
    synchronized(this) {
      return _m_n_bits;
    }
  }

  // Function: get_max_size
  //
  // Returns the maximum width, in number of bits, of all memories
  //
  // extern static function int unsigned    get_max_size();

  // extern static function int unsigned    get_max_size();
  // get_max_size

  static uint get_max_size() {
      return _m_max_size;
  }

  // Function: get_virtual_registers
  //
  // Return the virtual registers in this memory
  //
  // Fills the specified array with the abstraction class
  // for all of the virtual registers implemented in this memory.
  // The order in which the virtual registers are located in the array
  // is not specified. 
  //
  // extern virtual function void get_virtual_registers(ref uvm_vreg regs[$]);
  // get_virtual_registers

  // extern virtual function void get_virtual_registers(ref uvm_vreg regs[$]);
  // SV version uses queue here
  void get_virtual_registers(ref uvm_vreg[] regs) {
    synchronized(this) {
      foreach (vreg, unused; _m_vregs) {
	regs ~= vreg;
      }
    }
  }

  // Function: get_virtual_fields
  //
  // Return  the virtual fields in the memory
  //
  // Fills the specified dynamic array with the abstraction class
  // for all of the virtual fields implemented in this memory.
  // The order in which the virtual fields are located in the array is
  // not specified. 
  //
  // extern virtual function void get_virtual_fields(ref uvm_vreg_field fields[$]);
  // get_virtual_fields

  // extern virtual function void get_virtual_fields(ref uvm_vreg_field fields[$]);
  // SV version uses queue here
  void get_virtual_fields(ref uvm_vreg_field[] fields) {
    synchronized(this) {
      foreach (vreg, unused; _m_vregs) {
	vreg.get_fields(fields);
      }
    }
  }

  // Function: get_vreg_by_name
  //
  // Find the named virtual register
  //
  // Finds a virtual register with the specified name
  // implemented in this memory and returns
  // its abstraction class instance.
  // If no virtual register with the specified name is found, returns ~null~. 
  //
  // extern virtual function uvm_vreg get_vreg_by_name(string name);
  // get_vreg_by_name

  uvm_vreg get_vreg_by_name(string name) {
    synchronized(this) {
      foreach(vreg, unused;  _m_vregs) {
	if(vreg.get_name() == name) {
	  return vreg;
	}
      }
      uvm_warning("RegModel", "Unable to find virtual register '" ~ name ~
		  "' in memory '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  // Function: get_vfield_by_name
  //
  // Find the named virtual field
  //
  // Finds a virtual field with the specified name
  // implemented in this memory and returns
  // its abstraction class instance.
  // If no virtual field with the specified name is found, returns ~null~. 
  //
  // extern virtual function uvm_vreg_field  get_vfield_by_name(string name);
  // get_vfield_by_name

  uvm_vreg_field get_vfield_by_name(string name) {
    synchronized(this) {
      // Return first occurrence of vfield matching name
      uvm_vreg_field[] vfields;
      get_virtual_fields(vfields);

      foreach (i, vfield; vfields) {
	if (vfield.get_name() == name) {
	  return vfield;
	}
      }

      uvm_warning("RegModel", "Unable to find virtual field '" ~ name ~
		  "' in memory '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  // Function: get_vreg_by_offset
  //
  // Find the virtual register implemented at the specified offset
  //
  // Finds the virtual register implemented in this memory
  // at the specified ~offset~ in the specified address ~map~
  // and returns its abstraction class instance.
  // If no virtual register at the offset is found, returns ~null~. 
  //
  // extern virtual function uvm_vreg get_vreg_by_offset(uvm_reg_addr_t offset,
  // 						      uvm_reg_map    map = null);
  // get_vreg_by_offset

  uvm_vreg get_vreg_by_offset(uvm_reg_addr_t offset,
				     uvm_reg_map map = null) {
    uvm_error("RegModel", "uvm_mem::get_vreg_by_offset() not yet implemented");
    return null;
  }
   
  // Function: get_offset
  //
  // Returns the base offset of a memory location
  //
  // Returns the base offset of the specified location in this memory
  // in an address ~map~.
  //
  // If no address map is specified and the memory is mapped in only one
  // address map, that address map is used. If the memory is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the memory is not mapped in the specified
  // address map, an error message is issued.
  //
  // extern virtual function uvm_reg_addr_t  get_offset (uvm_reg_addr_t offset = 0,
  // 						      uvm_reg_map    map = null);
  // get_offset

  uvm_reg_addr_t get_offset(uvm_reg_addr_t offset = 0,
				   uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map orig_map = map;

      map = get_local_map(map,"get_offset()");

      if (map is null) {
	return uvm_reg_addr_t(-1);
      }
   
      map_info = map.get_mem_map_info(this);
   
      if (map_info.unmapped) {
	uvm_warning("RegModel", "Memory '" ~ get_name() ~
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() : orig_map.get_full_name()) ~ "'");
	return uvm_reg_addr_t(-1);
      }
      return map_info.offset;
    }
  }

  // Function: get_address
  //
  // Returns the base external physical address of a memory location
  //
  // Returns the base external physical address of the specified location
  // in this memory if accessed through the specified address ~map~.
  //
  // If no address map is specified and the memory is mapped in only one
  // address map, that address map is used. If the memory is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the memory is not mapped in the specified
  // address map, an error message is issued.
  //
  // extern virtual function uvm_reg_addr_t  get_address(uvm_reg_addr_t  offset = 0,
  // 						      uvm_reg_map   map = null);

  // get_address

  uvm_reg_addr_t get_address(T)(T offset = 0,
			     uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_addr_t[]  addr;
      get_addresses(offset, map, addr);
      return addr[0];
    }
  }

  // Function: get_addresses
  //
  // Identifies the external physical address(es) of a memory location
  //
  // Computes all of the external physical addresses that must be accessed
  // to completely read or write the specified location in this memory.
  // The addressed are specified in little endian order.
  // Returns the number of bytes transfered on each access.
  //
  // If no address map is specified and the memory is mapped in only one
  // address map, that address map is used. If the memory is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the memory is not mapped in the specified
  // address map, an error message is issued.
  //
  // extern virtual function int get_addresses(uvm_reg_addr_t     offset = 0,
  // 					    uvm_reg_map        map=null,
  // 					    ref uvm_reg_addr_t addr[]);

  // get_addresses

  int get_addresses(T)(T offset,
		    uvm_reg_map map,
		    ref uvm_reg_addr_t[] addr) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map system_map;
      uvm_reg_map orig_map = map;

      map = get_local_map(map,"get_addresses()");

      if (map is null) {
	return 0;
      }

      map_info = map.get_mem_map_info(this);

      if (map_info.unmapped) {
	uvm_warning("RegModel", "Memory '" ~ get_name() ~
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() : orig_map.get_full_name()) ~ "'");
	return 0;
      }

      addr = map_info.addr;

      foreach(i, ref a; addr) {
	a = a + map_info.mem_range.stride * offset;
      }

      return map.get_n_bytes();
    }
  }


  //------------------
  // Group: HDL Access
  //------------------

  // Task: write
  //
  // Write the specified value in a memory location
  //
  // Write ~value~ in the memory location that corresponds to this
  // abstraction class instance at the specified ~offset~
  // using the specified access ~path~. 
  // If the memory is mapped in more than one address map, 
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  // If a back-door access path is used, the effect of writing
  // the register through a physical access is mimicked. For
  // example, a read-only memory will not be written.
  //
  // extern virtual task write(output uvm_status_e       status,
  // 			    input  uvm_reg_addr_t     offset,
  // 			    input  uvm_reg_data_t     value,
  // 			    input  uvm_path_e         path   = UVM_DEFAULT_PATH,
  // 			    input  uvm_reg_map        map = null,
  // 			    input  uvm_sequence_base  parent = null,
  // 			    input  int                prior = -1,
  // 			    input  uvm_object         extension = null,
  // 			    input  string             fname = "",
  // 			    input  int                lineno = 0);

  // write
  //------
  // task
  void write(out uvm_status_e  status,
	     uvm_reg_addr_t    offset,
	     uvm_reg_data_t    value,
	     uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
	     uvm_reg_map       map = null,
	     uvm_sequence_base parent = null,
	     int               prior = -1,
	     uvm_object        extension = null,
	     string            fname = "",
	     int               lineno = 0) {

    // create an abstract transaction for this operation
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_write", null, get_full_name());

    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_MEM;
      rw.kind         = UVM_WRITE;
      rw.offset       = offset;
      // rw.value[0]     = value;
      rw.set_value(0, value);
      rw.path         = path;
      rw.map          = map;
      rw.parent       = parent;
      rw.prior        = prior;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }

    // task
    do_write(rw);

    synchronized(rw) {
      status = rw.status;
    }
  }

  // Task: read
  //
  // Read the current value from a memory location
  //
  // Read and return ~value~ from the memory location that corresponds to this
  // abstraction class instance at the specified ~offset~
  // using the specified access ~path~. 
  // If the register is mapped in more than one address map, 
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  //
  // extern virtual task read(output uvm_status_e        status,
  // 			   input  uvm_reg_addr_t      offset,
  // 			   output uvm_reg_data_t      value,
  // 			   input  uvm_path_e          path   = UVM_DEFAULT_PATH,
  // 			   input  uvm_reg_map         map = null,
  // 			   input  uvm_sequence_base   parent = null,
  // 			   input  int                 prior = -1,
  // 			   input  uvm_object          extension = null,
  // 			   input  string              fname = "",
  // 			   input  int                 lineno = 0);

  // read

  // task
  void read(out uvm_status_e  status,
	    uvm_reg_addr_t     offset,
	    out uvm_reg_data_t value,
	    uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
	    uvm_reg_map        map = null,
	    uvm_sequence_base  parent = null,
	    int                prior = -1,
	    uvm_object         extension = null,
	    string             fname = "",
	    int                lineno = 0) {
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_read", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_MEM;
      rw.kind         = UVM_READ;
      // rw.value[0]     = 0;
      rw.set_value(0, 0);
      rw.offset       = offset;
      rw.path         = path;
      rw.map          = map;
      rw.parent       = parent;
      rw.prior        = prior;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }

    // task
    do_read(rw);

    synchronized(rw) {
      status = rw.status;
      // value = rw.value[0];
      value = rw.get_value(0);
    }
  }

  // Task: burst_write
  //
  // Write the specified values in memory locations
  //
  // Burst-write the specified ~values~ in the memory locations
  // beginning at the specified ~offset~.
  // If the memory is mapped in more than one address map, 
  // an address ~map~ must be specified if not using the backdoor.
  // If a back-door access path is used, the effect of writing
  // the register through a physical access is mimicked. For
  // example, a read-only memory will not be written.
  //
  // extern virtual task burst_write(output uvm_status_e      status,
  // 				  input  uvm_reg_addr_t    offset,
  // 				  input  uvm_reg_data_t    value[],
  // 				  input  uvm_path_e        path = UVM_DEFAULT_PATH,
  // 				  input  uvm_reg_map       map = null,
  // 				  input  uvm_sequence_base parent = null,
  // 				  input  int               prior = -1,
  // 				  input  uvm_object        extension = null,
  // 				  input  string            fname = "",
  // 				  input  int               lineno = 0);
  // burst_write

  // task
  void burst_write(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   uvm_reg_data_t[]   value,
		   uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
		   uvm_reg_map        map = null,
		   uvm_sequence_base  parent = null,
		   int                prior = -1,
		   uvm_object         extension = null,
		   string             fname = "",
		   int                lineno = 0) {
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_burst_write", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_MEM;
      rw.kind         = UVM_BURST_WRITE;
      rw.offset       = offset;
      // rw.value        = value;
      rw.set_value(value);
      rw.path         = path;
      rw.map          = map;
      rw.parent       = parent;
      rw.prior        = prior;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }

    // task
    do_write(rw);

    synchronized(rw) {
      status = rw.status;
    }
  }

  // Task: burst_read
  //
  // Read values from memory locations
  //
  // Burst-read into ~values~ the data the memory locations
  // beginning at the specified ~offset~.
  // If the memory is mapped in more than one address map, 
  // an address ~map~ must be specified if not using the backdoor.
  // If a back-door access path is used, the effect of writing
  // the register through a physical access is mimicked. For
  // example, a read-only memory will not be written.
  //
  // extern virtual task burst_read(output uvm_status_e      status,
  // 				 input  uvm_reg_addr_t    offset,
  // 				 ref    uvm_reg_data_t    value[],
  // 				 input  uvm_path_e        path = UVM_DEFAULT_PATH,
  // 				 input  uvm_reg_map       map = null,
  // 				 input  uvm_sequence_base parent = null,
  // 				 input  int               prior = -1,
  // 				 input  uvm_object        extension = null,
  // 				 input  string            fname = "",
  // 				 input  int               lineno = 0);

  // burst_read

  // task
  void burst_read(out uvm_status_e     status,
		  uvm_reg_addr_t       offset,
		  ref uvm_reg_data_t[] value,
		  uvm_path_e           path = uvm_path_e.UVM_DEFAULT_PATH,
		  uvm_reg_map          map = null,
		  uvm_sequence_base    parent = null,
		  int                  prior = -1,
		  uvm_object           extension = null,
		  string               fname = "",
		  int                  lineno = 0) {

    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_burst_read", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_MEM;
      rw.kind         = UVM_BURST_READ;
      rw.offset       = offset;
      // rw.value        = value;
      rw.set_value(value);
      rw.path         = path;
      rw.map          = map;
      rw.parent       = parent;
      rw.prior        = prior;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }

    // task
    do_read(rw);

    synchronized(rw) {
      status = rw.status;
      // value  = rw.value;
      value  = rw.get_value();
    }
  }

  // Task: poke
  //
  // Deposit the specified value in a memory location
  //
  // Deposit the value in the DUT memory location corresponding to this
  // abstraction class instance at the secified ~offset~, as-is,
  // using a back-door access.
  //
  // Uses the HDL path for the design abstraction specified by ~kind~.
  //
  // extern virtual task poke(output uvm_status_e       status,
  // 			   input  uvm_reg_addr_t     offset,
  // 			   input  uvm_reg_data_t     value,
  // 			   input  string             kind = "",
  // 			   input  uvm_sequence_base  parent = null,
  // 			   input  uvm_object         extension = null,
  // 			   input  string             fname = "",
  // 			   input  int                lineno = 0);

  // poke

  // task
  void poke(out uvm_status_e  status,
	    uvm_reg_addr_t    offset,
	    uvm_reg_data_t    value,
	    string            kind = "",
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {

    uvm_reg_backdoor bkdr = get_backdoor();

    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      if (bkdr is null && !has_hdl_path(kind)) {
	uvm_error("RegModel", "No backdoor access available in memory '" ~
		  get_full_name() ~ "'");
	status = UVM_NOT_OK;
	return;
      }
    }

    // create an abstract transaction for this operation
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_poke_item", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.path         = UVM_BACKDOOR;
      rw.element_kind = UVM_MEM;
      rw.kind         = UVM_WRITE;
      rw.offset       = offset;
      // rw.value[0]     = value & ((1 << _m_n_bits)-1);
      rw.set_value(0, value & ((1 << _m_n_bits)-1));
      rw.bd_kind      = kind;
      rw.parent       = parent;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }

    if(bkdr !is null) {
      bkdr.write(rw);
    }
    else {
      backdoor_write(rw);
    }

    synchronized(rw) {
      status = rw.status;
    }

    uvm_info("RegModel", format("Poked memory '%s[%0d]' with value 'h%h",
				get_full_name(), offset, value), UVM_HIGH);
  }




  // Task: peek
  //
  // Read the current value from a memory location
  //
  // Sample the value in the DUT memory location corresponding to this
  // absraction class instance at the specified ~offset~
  // using a back-door access.
  // The memory location value is sampled, not modified.
  //
  // Uses the HDL path for the design abstraction specified by ~kind~.
  //
  // extern virtual task peek(output uvm_status_e       status,
  // 			   input  uvm_reg_addr_t     offset,
  // 			   output uvm_reg_data_t     value,
  // 			   input  string             kind = "",
  // 			   input  uvm_sequence_base  parent = null,
  // 			   input  uvm_object         extension = null,
  // 			   input  string             fname = "",
  // 			   input  int                lineno = 0);

  // peek

  // task
  void peek(out uvm_status_e      status,
	    uvm_reg_addr_t        offset,
	    out uvm_reg_data_t    value,
	    string                kind = "",
	    uvm_sequence_base     parent = null,
	    uvm_object            extension = null,
	    string                fname = "",
	    int                   lineno = 0) {
    uvm_reg_backdoor bkdr = get_backdoor();
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      if (bkdr is null && !has_hdl_path(kind)) {
	uvm_error("RegModel", "No backdoor access available in memory '" ~
		  get_full_name() ~ "'");
	status = UVM_NOT_OK;
	return;
      }
    }
    
    // create an abstract transaction for this operation
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_peek_item", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.path         = UVM_BACKDOOR;
      rw.element_kind = UVM_MEM;
      rw.kind         = UVM_READ;
      rw.offset       = offset;
      rw.bd_kind      = kind;
      rw.parent       = parent;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }

    if (bkdr !is null) {
      bkdr.read(rw);
    }
    else {
      backdoor_read(rw);
    }

    synchronized(rw) {
      status = rw.status;
      // value  = rw.value[0];
      value  = rw.get_value(0);
    }

    uvm_info("RegModel", format("Peeked memory '%s[%0d]' has value 'h%h",
				get_full_name(), offset, value), UVM_HIGH);
  }




  // extern protected function bool Xcheck_accessX (input uvm_reg_item rw,
  //                                                output uvm_reg_map_info map_info,
  //                                                input string caller);
   
  // Xcheck_accessX

  protected final bool Xcheck_accessX(uvm_reg_item rw,
				      out uvm_reg_map_info map_info,
				      string caller) {
    ulong size;
    synchronized(this) {
      size = _m_size;
    }

    synchronized(rw) {
      if (rw.offset >= size) {
	uvm_error(get_type_name(), 
		  format("Offset 'h%0h exceeds size of memory, 'h%0h",
			 rw.offset, size));
	rw.status = UVM_NOT_OK;
	return false;
      }

      if (rw.path is UVM_DEFAULT_PATH) {
	rw.path = _m_parent.get_default_path();
      }

      if (rw.path is UVM_BACKDOOR) {
	if (get_backdoor() is null && !has_hdl_path()) {
	  uvm_warning("RegModel",
		      "No backdoor access available for memory '" ~ get_full_name() ~
		      "' . Using frontdoor instead.");
	  rw.path = UVM_FRONTDOOR;
	}
	else {
	  rw.map = uvm_reg_map.backdoor();
	}
      }

      if (rw.path !is UVM_BACKDOOR) {
	rw.local_map = get_local_map(rw.map, caller);

	if (rw.local_map is null) {
	  uvm_error(get_type_name(), 
		    "No transactor available to physically access memory from map '" ~
		    rw.map.get_full_name() ~ "'");
	  rw.status = UVM_NOT_OK;
	  return false;
	}

	map_info = rw.local_map.get_mem_map_info(this);

	if (map_info.frontdoor is null) {
	  if (map_info.unmapped) {
	    uvm_error("RegModel", "Memory '" ~ get_full_name() ~
		      "' unmapped in map '" ~ rw.map.get_full_name() ~
		      "' and does not have a user-defined frontdoor");
	    rw.status = UVM_NOT_OK;
	    return false;
	  }

	  // if ((rw.value.length > 1)) {
	  if ((rw.num_values > 1)) {
	    if (get_n_bits() > rw.local_map.get_n_bytes()*8) {
	      uvm_error("RegModel",
			format("Cannot burst a %0d-bit memory through a narrower data path (%0d bytes)",
			       get_n_bits(), rw.local_map.get_n_bytes()*8));
	      rw.status = UVM_NOT_OK;
	      return false;
	    }
	    // if (rw.offset + rw.value.length > size) {
	    if (rw.offset + rw.num_values > size) {
	      uvm_error("RegModel",
			format("Burst of size 'd%0d starting at offset 'd%0d exceeds size of memory, 'd%0d",
			       rw.num_values, rw.offset, size));
	      return false;
	    }
	  }
	}

	if (rw.map is null) {
	  rw.map = rw.local_map;
	}
      }
      return true;
    }
  }


  // extern virtual task do_write (uvm_reg_item rw);
  // do_write

  // task
  void do_write(uvm_reg_item rw) {

    uvm_mem_cb_iter cbs = new uvm_mem_cb_iter(this);
    uvm_reg_map_info map_info;
   
    m_fname  = rw.fname;
    m_lineno = rw.lineno;

    if(!Xcheck_accessX(rw, map_info, "burst_write()")) {
      return;
    }

    m_write_in_progress = true;

    rw.status = UVM_IS_OK;
   
    // PRE-WRITE CBS
    pre_write(rw);
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
      cb.pre_write(rw);
    }

    if (rw.status !is UVM_IS_OK) {
      m_write_in_progress = false;
      return;
    }

    rw.status = UVM_NOT_OK;

    // FRONTDOOR
    if (rw.path is UVM_FRONTDOOR) {

      uvm_reg_map system_map = rw.local_map.get_root_map();
      
      if (map_info.frontdoor !is null) {
	uvm_reg_frontdoor fd = map_info.frontdoor;
	fd.rw_info = rw;
	if (fd.sequencer is null)
	  fd.sequencer = system_map.get_sequencer();
	fd.start(fd.sequencer, rw.parent);
      }
      else {
	rw.local_map.do_write(rw);
      }

      if (rw.status !is UVM_NOT_OK) {
	for (uvm_reg_addr_t idx = rw.offset;
	     // idx <= rw.offset + rw.value.length;
	     idx <= rw.offset + rw.num_values;
	     idx++) {
	  XsampleX(cast(uvm_reg_addr_t)(map_info.mem_range.stride * idx),
		   false, rw.map);
	  m_parent.XsampleX(map_info.offset +
			    (map_info.mem_range.stride * idx),
			    0, rw.map);
	}
      }
    }
      
    // BACKDOOR     
    else {
      // Mimick front door access, i.e. do not write read-only memories
      if (get_access(rw.map) == "RW") {
	uvm_reg_backdoor bkdr = get_backdoor();
	if (bkdr !is null) {
	  bkdr.write(rw);
	}
	else {
	  backdoor_write(rw);
	}
      }
      else {
	rw.status = UVM_IS_OK;
      }
    }

    // POST-WRITE CBS
    post_write(rw);
    for(uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
      cb.post_write(rw);
    }

    // REPORT
    if(uvm_report_enabled(UVM_HIGH, UVM_INFO, "RegModel")) {
      string path_s, value_s, pre_s, range_s;
      if (rw.path is UVM_FRONTDOOR) {
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ rw.map.get_full_name();
      }
      else {
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";
      }
      // if (rw.value.length > 1) {
      if (rw.num_values > 1) {
	value_s = "='{";
	pre_s = "Burst ";
	// foreach (i, val; rw.value) {
	foreach (i, val; rw.get_value()) {
	  value_s = value_s ~ format("%0h,", val);
	}
	value_s = value_s[0..$-1] ~ '}';
	// range_s = format("[%0d:%0d]", rw.offset, rw.offset+rw.value.length);
	range_s = format("[%0d:%0d]", rw.offset, rw.offset+rw.num_values);
      }
      else {
	// value_s = format("=%0h", rw.value[0]);
	value_s = format("=%0h", rw.get_value(0));
	range_s = format("[%0d]", rw.offset);
      }

      uvm_report_info("RegModel", pre_s ~ "Wrote memory via " ~ path_s ~ ": " ~
		      get_full_name() ~ range_s ~ value_s, UVM_HIGH);
    }

    m_write_in_progress = false;
  }


  // extern virtual task do_read  (uvm_reg_item rw);
  // do_read

  // task
  void do_read(uvm_reg_item rw) {

    uvm_mem_cb_iter cbs = new uvm_mem_cb_iter(this);
    uvm_reg_map_info map_info;
   
    m_fname = rw.fname;
    m_lineno = rw.lineno;

    if (!Xcheck_accessX(rw, map_info, "burst_read()")) {
      return;
    }

    m_read_in_progress = true;

    rw.status = UVM_IS_OK;
   
    // PRE-READ CBS
    pre_read(rw);
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
      cb.pre_read(rw);
    }

    if (rw.status !is UVM_IS_OK) {
      m_read_in_progress = false;

      return;
    }

    rw.status = UVM_NOT_OK;

    // FRONTDOOR
    if (rw.path is UVM_FRONTDOOR) {
      
      uvm_reg_map system_map = rw.local_map.get_root_map();
         
      if (map_info.frontdoor !is null) {
	uvm_reg_frontdoor fd = map_info.frontdoor;
	fd.rw_info = rw;
	if (fd.sequencer is null)
	  fd.sequencer = system_map.get_sequencer();
	fd.start(fd.sequencer, rw.parent);
      }
      else {
	rw.local_map.do_read(rw);
      }

      if (rw.status !is UVM_NOT_OK)
	for (uvm_reg_addr_t idx = rw.offset;
	     // idx <= rw.offset + rw.value.length;
	     idx <= rw.offset + rw.num_values;
	     idx++) {
	  XsampleX(cast(uvm_reg_addr_t)(map_info.mem_range.stride * idx),
			true, rw.map);
	  m_parent.XsampleX(map_info.offset +
			    (map_info.mem_range.stride * idx),
			    1, rw.map);
	}
    }

    // BACKDOOR
    else {
      uvm_reg_backdoor bkdr = get_backdoor();
      if (bkdr !is null) {
	bkdr.read(rw);
      }
      else {
	backdoor_read(rw);
      }
    }

    // POST-READ CBS
    post_read(rw);
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
      cb.post_read(rw);
    }

    // REPORT
    if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "RegModel")) {
      string path_s, value_s, pre_s, range_s;
      if(rw.path is UVM_FRONTDOOR) {
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ rw.map.get_full_name();
      }
      else {
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";
      }
      // if (rw.value.length > 1) {
      if (rw.num_values > 1) {
	value_s = "='{";
	pre_s = "Burst ";
	// foreach (i, v; rw.value) {
	foreach (i, v; rw.get_value()) {
	  value_s = value_s ~ format("%0h,", v);
	}
	value_s = value_s[0..$-1] ~ '}';
	// range_s = format("[%0d:%0d]", rw.offset, (rw.offset + rw.value.length));
	range_s = format("[%0d:%0d]", rw.offset, (rw.offset + rw.num_values));
      }
      else {
	// value_s = format("=%0h", rw.value[0]);
	value_s = format("=%0h", rw.get_value(0));
	range_s = format("[%0d]", rw.offset);
      }

      uvm_report_info("RegModel", pre_s ~ "Read memory via " ~ path_s ~ ": " ~
		      get_full_name() ~ range_s ~ value_s, UVM_HIGH);
    }

    m_read_in_progress = false;
  }



  //-----------------
  // Group: Frontdoor
  //-----------------

  // Function: set_frontdoor
  //
  // Set a user-defined frontdoor for this memory
  //
  // By default, memorys are mapped linearly into the address space
  // of the address maps that instantiate them.
  // If memorys are accessed using a different mechanism,
  // a user-defined access
  // mechanism must be defined and associated with
  // the corresponding memory abstraction class
  //
  // If the memory is mapped in multiple address maps, an address ~map~
  // must be specified.
  //
  // extern function void set_frontdoor(uvm_reg_frontdoor ftdr,
  // 				     uvm_reg_map map = null,
  // 				     string fname = "",
  // 				     int lineno = 0);
   

  // set_frontdoor

  final void set_frontdoor(uvm_reg_frontdoor ftdr,
			   uvm_reg_map       map = null,
			   string            fname = "",
			   int               lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      map = get_local_map(map, "set_frontdoor()");

      if (map is null) {
	uvm_error("RegModel", "Memory '" ~ get_full_name() ~
		  "' not found in map '" ~ map.get_full_name() ~ "'");
	return;
      }

      uvm_reg_map_info map_info = map.get_mem_map_info(this);
      map_info.frontdoor = ftdr;
    }
  }


  // Function: get_frontdoor
  //
  // Returns the user-defined frontdoor for this memory
  //
  // If null, no user-defined frontdoor has been defined.
  // A user-defined frontdoor is defined
  // by using the <uvm_mem::set_frontdoor()> method. 
  //
  // If the memory is mapped in multiple address maps, an address ~map~
  // must be specified.
  //
  // extern function uvm_reg_frontdoor get_frontdoor(uvm_reg_map map = null);

  // get_frontdoor

  final uvm_reg_frontdoor get_frontdoor(uvm_reg_map map = null) {
    synchronized(this) {
      map = get_local_map(map, "set_frontdoor()");

      if (map is null) {
	uvm_error("RegModel", "Memory '" ~ get_full_name() ~
		  "' not found in map '" ~ map.get_full_name() ~ "'");
	return null;
      }

      uvm_reg_map_info map_info = map.get_mem_map_info(this);
      return map_info.frontdoor;
    }
  }

  //----------------
  // Group: Backdoor
  //----------------

  // Function: set_backdoor
  //
  // Set a user-defined backdoor for this memory
  //
  // By default, memories are accessed via the built-in string-based
  // DPI routines if an HDL path has been specified using the
  // <uvm_mem::configure()> or <uvm_mem::add_hdl_path()> method.
  // If this default mechanism is not suitable (e.g. because
  // the memory is not implemented in pure SystemVerilog)
  // a user-defined access
  // mechanism must be defined and associated with
  // the corresponding memory abstraction class
  //
  // extern function void set_backdoor (uvm_reg_backdoor bkdr,
  // 				     string fname = "",
  // 				     int lineno = 0);


  // set_backdoor

  final void set_backdoor(uvm_reg_backdoor bkdr,
				 string fname = "",
				 int lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      _m_backdoor = bkdr;
    }
  }


  // Function: get_backdoor
  //
  // Returns the user-defined backdoor for this memory
  //
  // If null, no user-defined backdoor has been defined.
  // A user-defined backdoor is defined
  // by using the <uvm_reg::set_backdoor()> method. 
  //
  // If ~inherit~ is TRUE, returns the backdoor of the parent block
  // if none have been specified for this memory.
  //
  // extern function uvm_reg_backdoor get_backdoor(bool inherited = 1);

  // get_backdoor

  final uvm_reg_backdoor get_backdoor(bool inherited = true) {
    synchronized(this) {
      if (_m_backdoor is null && inherited) {
	uvm_reg_block blk = get_parent();
	uvm_reg_backdoor bkdr;
	while (blk !is null) {
	  bkdr = blk.get_backdoor();
	  if (bkdr !is null) {
	    _m_backdoor = bkdr;
	    break;
	  }
	  blk = blk.get_parent();
	}
      }
      return _m_backdoor;
    }
  }

  // Function: clear_hdl_path
  //
  // Delete HDL paths
  //
  // Remove any previously specified HDL path to the memory instance
  // for the specified design abstraction.
  //
  // extern function void clear_hdl_path (string kind = "RTL");

  // clear_hdl_path

  final void clear_hdl_path(string kind = "RTL") {
    synchronized(this) {
      if (kind == "ALL") {
	_m_hdl_paths_pool =
	  new uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))("hdl_paths");
	return;
      }

      if(kind == "") {
	kind = _m_parent.get_default_hdl_path();
      }

      if(kind !in _m_hdl_paths_pool) {
	uvm_warning("RegModel", "Unknown HDL Abstraction '" ~ kind ~ "'");
	return;
      }

      _m_hdl_paths_pool.remove(kind);
    }
  }



   
  // Function: add_hdl_path
  //
  // Add an HDL path
  //
  // Add the specified HDL path to the memory instance for the specified
  // design abstraction. This method may be called more than once for the
  // same design abstraction if the memory is physically duplicated
  // in the design abstraction
  //
  // extern function void add_hdl_path (uvm_hdl_path_slice slices[],
  // 				     string kind = "RTL");
   
  // add_hdl_path

  final void add_hdl_path(uvm_hdl_path_slice[] slices, string kind = "RTL") {
    uvm_queue!(uvm_hdl_path_concat) paths = _m_hdl_paths_pool.get(kind);
    uvm_hdl_path_concat concat = new uvm_hdl_path_concat();

    concat.set(slices);
    paths.push_back(concat);
  }

  // Function: add_hdl_path_slice
  //
  // Add the specified HDL slice to the HDL path for the specified
  // design abstraction.
  // If ~first~ is TRUE, starts the specification of a duplicate
  // HDL implementation of the memory.
  //
  // extern function void add_hdl_path_slice(string name,
  // 					  int offset,
  // 					  int size,
  // 					  bool first = 0,
  // 					  string kind = "RTL");

  // add_hdl_path_slice

  final void add_hdl_path_slice(string name,
				int offset,
				int size,
				bool first = false,
				string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) paths=_m_hdl_paths_pool.get(kind);
      uvm_hdl_path_concat concat;

      if (first || paths.length is 0) {
	concat = new uvm_hdl_path_concat();
	paths.push_back(concat);
      }
      else {
	concat = paths.get(paths.length-1);
      }
      concat.add_path(name, offset, size);
    }
  }

  // Function: has_hdl_path
  //
  // Check if a HDL path is specified
  //
  // Returns TRUE if the memory instance has a HDL path defined for the
  // specified design abstraction. If no design abstraction is specified,
  // uses the default design abstraction specified for the parent block.
  //
  // extern function bool  has_hdl_path (string kind = "");

  // has_hdl_path

  bool has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "")
	kind = _m_parent.get_default_hdl_path();
  
      if(kind in _m_hdl_paths_pool) {
	return true;
      }
      else {
	return false;
      }
    }
  }


  // Function: get_hdl_path
  //
  // Get the incremental HDL path(s)
  //
  // Returns the HDL path(s) defined for the specified design abstraction
  // in the memory instance.
  // Returns only the component of the HDL paths that corresponds to
  // the memory, not a full hierarchical path
  //
  // If no design asbtraction is specified, the default design abstraction
  // for the parent block is used.
  //
  // extern function void get_hdl_path (ref uvm_hdl_path_concat paths[$],
  // 				     input string kind = "");

  // get_hdl_path

  final void get_hdl_path(ref uvm_hdl_path_concat[] paths,
			  string kind = "") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) hdl_paths;

      if (kind == "") {
	kind = _m_parent.get_default_hdl_path();
      }

      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Memory does not have hdl path defined for abstraction '" ~ kind ~ "'");
	return;
      }

      hdl_paths = _m_hdl_paths_pool.get(kind);

      for (int i = 0; i < hdl_paths.length; i++) {
	uvm_hdl_path_concat t = hdl_paths.get(i);
	paths ~= t;
      }
    }
  }


  // Function: get_full_hdl_path
  //
  // Get the full hierarchical HDL path(s)
  //
  // Returns the full hierarchical HDL path(s) defined for the specified
  // design abstraction in the memory instance.
  // There may be more than one path returned even
  // if only one path was defined for the memory instance, if any of the
  // parent components have more than one path defined for the same design
  // abstraction
  //
  // If no design asbtraction is specified, the default design abstraction
  // for each ancestor block is used to get each incremental path.
  //
  // extern function void get_full_hdl_path (ref uvm_hdl_path_concat paths[$],
  // 					  input string kind = "",
  // 					  input string separator = ".");

  // get_full_hdl_path

  final void get_full_hdl_path(ref uvm_hdl_path_concat[] paths, // queue in SV
			       string kind = "",
			       string separator = ".") {
    synchronized(this) {
      if (kind == "") {
	kind = _m_parent.get_default_hdl_path();
      }
   
      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Memory does not have hdl path defined for abstraction '" ~ kind ~ "'");
	return;
      }

      uvm_queue!(uvm_hdl_path_concat) hdl_paths = _m_hdl_paths_pool.get(kind);
      string[] parent_paths;	// queue in SV

      _m_parent.get_full_hdl_path(parent_paths, kind, separator);

      for (int i = 0; i < hdl_paths.length ;i++) {
	uvm_hdl_path_concat hdl_concat = hdl_paths.get(i);

	foreach (path; parent_paths)  {
	  uvm_hdl_path_concat t = new uvm_hdl_path_concat;

	  foreach (slice; hdl_concat.slices) {
	    if (slice.path == "") {
	      t.add_path(path);
	    }
	    else {
	      t.add_path(path ~ separator ~ slice.path,
			 slice.offset,
			 slice.size);
	    }
	    paths ~= t;
	  }
	}
      }
    }
  }


  // Function: get_hdl_path_kinds
  //
  // Get design abstractions for which HDL paths have been defined
  //
  // extern function void get_hdl_path_kinds (ref string kinds[$]);

  // get_hdl_path_kinds

  void get_hdl_path_kinds (out string[] kinds) { // queue in SV
    synchronized(this) {
      foreach(kind, unused; _m_hdl_paths_pool) {
	kinds ~= kind;
      }
    }
  }

  // Function: backdoor_read
  //
  // User-define backdoor read access
  //
  // Override the default string-based DPI backdoor access read
  // for this memory type.
  // By default calls <uvm_mem::backdoor_read_func()>.
  //
  // extern virtual protected task backdoor_read(uvm_reg_item rw);

  // backdoor_read

  // task
  protected void backdoor_read(uvm_reg_item rw) {
    rw.status = backdoor_read_func(rw);
  }


  // Function: backdoor_write
  //
  // User-defined backdoor read access
  //
  // Override the default string-based DPI backdoor access write
  // for this memory type.
  //
  // extern virtual task backdoor_write(uvm_reg_item rw);

  // backdoor_write

  // task
  protected void backdoor_write(uvm_reg_item rw) { // public in SV version
    
    uvm_hdl_path_concat[] paths;
    bool ok = true;

   
    get_full_hdl_path(paths, rw.bd_kind);
   
    // foreach (mem_idx, v; rw.value) {
    foreach (mem_idx, v; rw.get_value()) {
      import std.conv: to;
      string idx = (rw.offset + mem_idx).to!string;
      foreach (i, path; paths) {
	uvm_hdl_path_concat hdl_concat = path;
	foreach(j, sl; hdl_concat.slices) {
	  uvm_info("RegModel", format("backdoor_write to %s ", sl.path), UVM_DEBUG);
	  if (sl.offset < 0) {
	    ok &= uvm_hdl_deposit(sl.path ~ "[" ~ idx ~ "]", v);
	    continue;
	  }
	  uvm_reg_data_t slice = v >> sl.offset;
	  slice &= (1 << sl.size)-1;
	  ok &= uvm_hdl_deposit(sl.path ~ "[" ~ idx ~ "]", slice);
	}
      }
    }
    rw.status = (ok ? UVM_IS_OK : UVM_NOT_OK);
  }





   
  // Function: backdoor_read_func
  //
  // User-defined backdoor read access
  //
  // Override the default string-based DPI backdoor access read
  // for this memory type.
  //
  // extern virtual function uvm_status_e backdoor_read_func(uvm_reg_item rw);
  // backdoor_read_func

  uvm_status_e backdoor_read_func(uvm_reg_item rw) {
    synchronized(this) {
      uvm_hdl_path_concat[] paths;
      uvm_reg_data_t val;
      bool ok = true;

      get_full_hdl_path(paths, rw.bd_kind);

      // foreach (mem_idx, ref v; rw.value) {
      foreach (mem_idx, ref v; rw.get_value) {
	import std.conv: to;
	string idx = (rw.offset + mem_idx).to!string;
	foreach (i, path; paths) {
	  uvm_hdl_path_concat hdl_concat = path;
	  val = 0;
	  foreach (j, sl; hdl_concat.slices) {
	    string hdl_path = sl.path ~ "[" ~ idx ~ "]";
	    
	    uvm_info("RegModel", "backdoor_read from " ~ hdl_path, UVM_DEBUG);
 
	    if(sl.offset < 0) {
	      ok &= uvm_hdl_read(hdl_path, val);
	      continue;
	    }
	    uvm_reg_data_t slice;
	    int k = sl.offset;
	    ok &= uvm_hdl_read(hdl_path, slice);
	    for(size_t n; n != sl.size; ++n) {
	      val[k++] = slice[0];
	      slice >>= 1;
	    }
	  }
  

	  val &= (1 << _m_n_bits)-1;

	  if (i is 0)
	    v = val;

	  if (val != v) {
	    uvm_error("RegModel", format("Backdoor read of register %s with" ~
					 " multiple HDL copies: values are not" ~
					 " the same: %0h at path '%s', and %0h" ~
					 " at path '%s'. Returning first value.",
					 // get_full_name(), rw.value[mem_idx],
					 get_full_name(), rw.get_value(mem_idx),
					 uvm_hdl_concat2string(paths[0]),
					 val, uvm_hdl_concat2string(path))); 
	    return UVM_NOT_OK;
	  }
	}
      }

      rw.status = (ok) ? UVM_IS_OK : UVM_NOT_OK;

      return rw.status;
    }
  }




  // Task: pre_write
  //
  // Called before memory write.
  //
  // If the ~offset~, ~value~, access ~path~,
  // or address ~map~ are modified, the updated offset, data value,
  // access path or address map will be used to perform the memory operation.
  // If the ~status~ is modified to anything other than <UVM_IS_OK>,
  // the operation is aborted.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  //

  // virtual task pre_write(uvm_reg_item rw); endtask

  // task
  void pre_write(uvm_reg_item rw) { }


  // Task: post_write
  //
  // Called after memory write.
  //
  // If the ~status~ is modified, the updated status will be
  // returned by the memory operation.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  //

  // virtual task post_write(uvm_reg_item rw); endtask

  void post_write(uvm_reg_item rw) { }


  // Task: pre_read
  //
  // Called before memory read.
  //
  // If the ~offset~, access ~path~ or address ~map~ are modified,
  // the updated offset, access path or address map will be used to perform
  // the memory operation.
  // If the ~status~ is modified to anything other than <UVM_IS_OK>,
  // the operation is aborted.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  //

  // virtual task pre_read(uvm_reg_item rw); endtask
  
  void pre_read(uvm_reg_item rw) { }

  // Task: post_read
  //
  // Called after memory read.
  //
  // If the readback data or ~status~ is modified,
  // the updated readback //data or status will be
  // returned by the memory operation.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  //

  // virtual task post_read(uvm_reg_item rw); endtask

  // task
  void post_read(uvm_reg_item rw) { }


  //----------------
  // Group: Coverage
  //----------------

  // Function: build_coverage
  //
  // Check if all of the specified coverage model must be built.
  //
  // Check which of the specified coverage model must be built
  // in this instance of the memory abstraction class,
  // as specified by calls to <uvm_reg::include_coverage()>.
  //
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  // Returns the sum of all coverage models to be built in the
  // memory model.
  //

  // extern protected function uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models);

  final uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models) {
    uvm_reg_cvr_t retval = uvm_coverage_model_e.UVM_NO_COVERAGE;
    uvm_reg_cvr_rsrc_db.read_by_name("uvm_reg::" ~ get_full_name(),
				     "include_coverage",
				     retval, this);
    return retval & models;
  }

  // Function: add_coverage
  //
  // Specify that additional coverage models are available.
  //
  // Add the specified coverage model to the coverage models
  // available in this class.
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  //
  // This method shall be called only in the constructor of
  // subsequently derived classes.
  //

  // extern virtual protected function void add_coverage(uvm_reg_cvr_t models);

  // add_coverage

  protected void add_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      _m_has_cover |= models;
    }
  }

  // Function: has_coverage
  //
  // Check if memory has coverage model(s)
  //
  // Returns TRUE if the memory abstraction class contains a coverage model
  // for all of the models specified.
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  //

  // extern virtual function bool has_coverage(uvm_reg_cvr_t models);

  // has_coverage

  bool has_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      return ((_m_has_cover & models) == models);
    }
  }


  // Function: set_coverage
  //
  // Turns on coverage measurement.
  //
  // Turns the collection of functional coverage measurements on or off
  // for this memory.
  // The functional coverage measurement is turned on for every
  // coverage model specified using <uvm_coverage_model_e> symbolic
  // identifers.
  // Multiple functional coverage models can be specified by adding
  // the functional coverage model identifiers.
  // All other functional coverage models are turned off.
  // Returns the sum of all functional
  // coverage models whose measurements were previously on.
  //
  // This method can only control the measurement of functional
  // coverage models that are present in the memory abstraction classes,
  // then enabled during construction.
  // See the <uvm_mem::has_coverage()> method to identify
  // the available functional coverage models.
  //

  // extern virtual function uvm_reg_cvr_t set_coverage(uvm_reg_cvr_t is_on);

  // set_coverage

  uvm_reg_cvr_t set_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      if (is_on == cast(uvm_reg_cvr_t) (uvm_coverage_model_e.UVM_NO_COVERAGE)) {
	_m_cover_on = is_on;
	return uvm_reg_cvr_t(_m_cover_on);
      }

      _m_cover_on = _m_has_cover & is_on;

      return uvm_reg_cvr_t(_m_cover_on);
    }
  }

  // Function: get_coverage
  //
  // Check if coverage measurement is on.
  //
  // Returns TRUE if measurement for all of the specified functional
  // coverage models are currently on.
  // Multiple functional coverage models can be specified by adding the
  // functional coverage model identifiers.
  //
  // See <uvm_mem::set_coverage()> for more details. 
  //
  // extern virtual function bool get_coverage(uvm_reg_cvr_t is_on);

  // get_coverage

  bool get_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      if (has_coverage(is_on) == 0) return 0;
      return ((_m_cover_on & is_on) == is_on);
    }
  }

  // Function: sample
  //
  // Functional coverage measurement method
  //
  // This method is invoked by the memory abstraction class
  // whenever an address within one of its address map
  // is succesfully read or written.
  // The specified offset is the offset within the memory,
  // not an absolute address.
  //
  // Empty by default, this method may be extended by the
  // abstraction class generator to perform the required sampling
  // in any provided functional coverage model.
  //

  // protected virtual function void  sample(uvm_reg_addr_t offset,
  // 					  bool            is_read,
  // 					  uvm_reg_map    map);

  protected void sample(uvm_reg_addr_t offset,
			bool            is_read,
			uvm_reg_map    map) {
  }
  
  // /*private*/ function void XsampleX(uvm_reg_addr_t addr,
  // 				     bool            is_read,
  // 				     uvm_reg_map    map);

  private final void XsampleX(uvm_reg_addr_t addr,
			      bool            is_read,
			      uvm_reg_map    map) {
    sample(addr, is_read, map);
  }

  // Core ovm_object operations

  // extern virtual function void do_print (uvm_printer printer);
  // do_print

  override void do_print (uvm_printer printer) {
    super.do_print(printer);
    //printer.print_generic(" ", " ", -1, convert2string());
    printer.print_int("n_bits", get_n_bits(), 32, UVM_UNSIGNED);
    printer.print_int("size", get_size(), 32, UVM_UNSIGNED);
  }


  // extern virtual function string convert2string();

  // convert2string

  override string convert2string() {
    synchronized(this) {
      string convert2string_;

      string res_str;
      string prefix;

      convert2string_ = format("%sMemory %s -- %0dx%0d bits", prefix,
		      get_full_name(), get_size(), get_n_bits());

      if (_m_maps.length == 0) {
	convert2string_ ~= "  (unmapped)\n";
      }
      else {
	convert2string_ ~= "\n";
      }
      foreach (map, unused; _m_maps) {
	uvm_reg_map parent_map = map;
	while (parent_map !is null) {
	  uvm_reg_map this_map = parent_map;
	  uvm_endianness_e endian_name;
	  parent_map = this_map.get_parent_map();
	  endian_name=this_map.get_endian();
       
	  auto offset = parent_map is null ? this_map.get_base_addr(UVM_NO_HIER) :
	    parent_map.get_submap_offset(this_map);
	  prefix ~= "  ";
	  convert2string_ = format("%sMapped in '%s' -- buswidth %0d bytes, %s, " ~
			  "offset 'h%0h, size 'h%0h, %s\n", prefix,
			  this_map.get_full_name(), this_map.get_n_bytes(),
			  endian_name, offset, get_size(),
			  get_access(this_map));
	}
      }
      prefix = "  ";
      if (_m_read_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format("%s:%0d ", _m_fname, _m_lineno);
	convert2string_ ~= "  " ~ res_str ~ "currently executing read method"; 
      }
      if ( _m_write_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0) {
	  format(res_str, "%s:%0d ",_m_fname, _m_lineno);
	}
	convert2string_ ~= "  " ~ res_str ~ "currently executing write method"; 
      }
      return convert2string_;
    }
  }


  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel memories cannot be cloned");
    return null;
  }

  // extern virtual function void do_copy   (uvm_object rhs);
  // do_copy

  override void do_copy(uvm_object rhs) {
    uvm_fatal("RegModel","RegModel memories cannot be copied");
  }


  // extern virtual function bool do_compare (uvm_object  rhs,
  // 					   uvm_comparer comparer);
  // do_compare

  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel memories cannot be compared");
    return false;
  }

  // extern virtual function void do_pack (uvm_packer packer);
  // do_pack

  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel memories cannot be packed");
  }

  // extern virtual function void do_unpack (uvm_packer packer);
  // do_unpack

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel memories cannot be unpacked");
  }

}
