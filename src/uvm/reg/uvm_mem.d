//
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2018 Intel Corporation
// Copyright 2004-2018 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2012 Accellera Systems Initiative
// Copyright 2020 Verific
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
// CLASS -- NODOCS -- uvm_mem
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

import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_backdoor: uvm_reg_backdoor;
import uvm.reg.uvm_reg_cbs: uvm_reg_cbs, uvm_mem_cb_iter;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg_map: uvm_reg_map, uvm_reg_map_info;
import uvm.reg.uvm_reg_sequence: uvm_reg_frontdoor;
import uvm.reg.uvm_vreg: uvm_vreg;
import uvm.reg.uvm_vreg_field: uvm_vreg_field;
import uvm.reg.uvm_mem_mam: uvm_mem_mam, uvm_mem_mam_cfg;
import uvm.reg.uvm_reg_model;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_comparer: uvm_comparer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_pool: uvm_object_string_pool;
import uvm.base.uvm_queue: uvm_queue;
import uvm.base.uvm_callback: uvm_register_cb;
import uvm.base.uvm_globals: uvm_fatal, uvm_error, uvm_warning,
  uvm_info, uvm_report_enabled;
import uvm.base.uvm_object_globals: uvm_verbosity, uvm_severity;
import uvm.base.uvm_scope: uvm_scope_base;

import uvm.seq.uvm_sequence_base: uvm_sequence_base;

import uvm.meta.misc;

import uvm.dpi.uvm_hdl;
import esdl.rand;

import std.string: format, toUpper;

// @uvm-ieee 1800.2-2017 auto 18.6.1
@rand(false)
class uvm_mem: uvm_object
{
  // See Mantis 6040. I did NOT make this class virtual because it 
  // seems to break a lot of existing tests and code. 
  // Sought LRM clarification

  // init_e is not used anywhere 
  // enum init_e: byte {UNKNOWNS, ZEROES, ONES, ADDRESS, VALUE, INCR, DECR}

  mixin uvm_sync;
  
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

  mixin(uvm_scope_sync_string);
  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uint   _m_max_size;
  }

  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------


  // @uvm-ieee 1800.2-2017 auto 18.6.3.1
  this(string name,
       ulong size,
       uint n_bits,
       string access = "RW",
       int has_coverage = uvm_coverage_model_e.UVM_NO_COVERAGE) {
    synchronized(this) {
      super(name);
      _m_locked = false;
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
	synchronized (_uvm_scope_inst) {
	  _m_max_size = n_bits;
	}
      }

    }
  }

   
  // @uvm-ieee 1800.2-2017 auto 18.6.3.2
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


  // @uvm-ieee 1800.2-2017 auto 18.6.3.3
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

      map = get_local_map(map);

      if (map is null) {
	return;
      }
   
      map.m_set_mem_offset(this, offset, unmapped);
    }
  }


  final void set_parent(uvm_reg_block parent) {
    synchronized(this) {
      _m_parent = parent;
    }
  }

  final void add_map(uvm_reg_map map) {
    synchronized(this) {
      _m_maps[map] = true;
    }
  }

  final void Xlock_modelX() {
    synchronized(this) {
      _m_locked = true;
    }
  }

  final void Xadd_vregX(uvm_vreg vreg) {
    synchronized(this) {
      _m_vregs[vreg] = true;
    }
  }

  final void Xdelete_vregX(uvm_vreg vreg) {
    synchronized(this) {
      if (vreg in _m_vregs) {
	_m_vregs.remove(vreg);
      }
    }
  }


  // variable -- NODOCS -- mam
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
  private uvm_mem_mam _mam;

  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  // Function -- NODOCS -- get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this memory.
  //

  // Function -- NODOCS -- get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this memory.
  // The base of the hierarchical name is the root block.
  //

  override string get_full_name() {
    synchronized(this) {
      if (_m_parent is null)
	return get_name();
   
      return _m_parent.get_full_name() ~ "." ~ get_name();
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.4.1
  uvm_reg_block get_parent() {
    return get_block();
  }

  uvm_reg_block get_block() {
    synchronized(this) {
      return _m_parent;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.4.2
  int get_n_maps() {
    synchronized(this) {
      return cast(int) _m_maps.length;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.4.3
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


  // @uvm-ieee 1800.2-2017 auto 18.6.4.4
  void get_maps(ref uvm_reg_map[] maps) {
    synchronized(this) {
      foreach (map, unused; _m_maps) {
	maps ~= map;
      }
    }
  }

  final uvm_reg_map get_local_map(uvm_reg_map map) {
    synchronized(this) {
      if (map is null)
	return get_default_map();
      if (map in _m_maps)
	return map;
      foreach(l, unused; _m_maps) {
	uvm_reg_map local_map = l;
	uvm_reg_map parent_map = local_map.get_parent_map();

	while (parent_map !is null) {
	  if (parent_map is map)
	    return local_map;
	  parent_map = parent_map.get_parent_map();
	}
      }
      uvm_warning("RegModel", 
		  "Memory '" ~ get_full_name() ~
		  "' is not contained within map '" ~
		  map.get_full_name() ~ "'");
      return null;
    }
  }


  final uvm_reg_map get_default_map() {
    synchronized(this) {
      // if mem is not associated with any may, return null
      if (_m_maps.length is 0) {
	uvm_warning("RegModel", 
		    "Memory '" ~ get_full_name() ~ "' is not registered with any map");
	return null;
      }

      // if only one map, choose that
      if (_m_maps.length == 1) {
	// void'(m_maps.first(get_default_map)); // SV
	// return get_default_map // SV
	return _m_maps.keys[0];
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

  // @uvm-ieee 1800.2-2017 auto 18.6.4.5
  string get_rights(uvm_reg_map map = null) {
    synchronized(this) {

      // No right restrictions if not shared
      if (_m_maps.length <= 1) {
	return "RW";
      }

      map = get_local_map(map);

      if (map is null)
	return "RW";

      uvm_reg_map_info info = map.get_mem_map_info(this);
      return info.rights;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.4.6
  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      string retval = _m_access;
      if (get_n_maps() is 1) return retval;

      map = get_local_map(map);
      if (map is null) return retval;

      // Is the memory restricted in this map?
      switch (get_rights(map)) {
      case "RW":
	// No restrictions
	return retval;
      case "RO":
	switch (retval) {
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

  // Function -- NODOCS -- get_size
  //
  // Returns the number of unique memory locations in this memory. 
  // this is in units of the memory declaration: full memory is get_size()*get_n_bits() (bits)
  final ulong get_size() {
    synchronized(this) {
      return _m_size;
    }
  }

  // Function -- NODOCS -- get_n_bytes
  //
  // Return the width, in number of bytes, of each memory location
  //
  final uint get_n_bytes() {
    synchronized(this) {
      return(_m_n_bits - 1) / 8 + 1;
    }
  }

  // Function -- NODOCS -- get_n_bits
  //
  // Returns the width, in number of bits, of each memory location
  //
  final uint get_n_bits() {
    synchronized(this) {
      return _m_n_bits;
    }
  }

  // Function -- NODOCS -- get_max_size
  //
  // Returns the maximum width, in number of bits, of all memories
  //
  static uint get_max_size() {
    synchronized (_uvm_scope_inst) {
      return _m_max_size;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.4.11
  void get_virtual_registers(ref uvm_vreg[] regs) {
    synchronized(this) {
      foreach (vreg, unused; _m_vregs) {
	regs ~= vreg;
      }
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.4.12
  void get_virtual_fields(ref uvm_vreg_field[] fields) {
    synchronized(this) {
      foreach (vreg, unused; _m_vregs) {
	vreg.get_fields(fields);
      }
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.4.13
  uvm_vreg get_vreg_by_name(string name) {
    synchronized(this) {
      foreach (vreg, unused;  _m_vregs) {
	if (vreg.get_name() == name) {
	  return vreg;
	}
      }
      uvm_warning("RegModel", "Unable to find virtual register '" ~ name ~
		  "' in memory '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.4.14
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

  // Function -- NODOCS -- get_vreg_by_offset
  //
  // Find the virtual register implemented at the specified offset
  //
  // Finds the virtual register implemented in this memory
  // at the specified ~offset~ in the specified address ~map~
  // and returns its abstraction class instance.
  // If no virtual register at the offset is found, returns ~null~. 
  //
  uvm_vreg get_vreg_by_offset(uvm_reg_addr_t offset,
				     uvm_reg_map map = null) {
    uvm_error("RegModel", "uvm_mem::get_vreg_by_offset() not yet implemented");
    return null;
  }
   

  // @uvm-ieee 1800.2-2017 auto 18.6.4.15
  uvm_reg_addr_t get_offset(uvm_reg_addr_t offset = 0,
				   uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map orig_map = map;

      map = get_local_map(map);

      if (map is null)
	return -1;
   
      map_info = map.get_mem_map_info(this);
   
      if (map_info.unmapped) {
	uvm_warning("RegModel", "Memory '" ~ get_name() ~
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() : orig_map.get_full_name()) ~ "'");
	return -1;
      }
      return map_info.offset;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.4.16
  uvm_reg_addr_t get_address(uvm_reg_addr_t offset = 0,
			     uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_addr_t[]  addr;
      get_addresses(offset, map, addr);
      return addr[0];
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.4.17
  int get_addresses(uvm_reg_addr_t offset,
		    uvm_reg_map map,
		    ref uvm_reg_addr_t[] addr) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map system_map;
      uvm_reg_map orig_map = map;

      map = get_local_map(map);

      if (map is null)
	return 0;

      map_info = map.get_mem_map_info(this);

      if (map_info.unmapped) {
	uvm_warning("RegModel", "Memory '" ~ get_name() ~
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() : orig_map.get_full_name()) ~ "'");
	return 0;
      }

      addr = map_info.addr;

      foreach (i, ref a; addr)
	a = a + map_info.mem_range.stride * offset;

      return map.get_n_bytes();
    }
  }


  //------------------
  // Group -- NODOCS -- HDL Access
  //------------------

  // @uvm-ieee 1800.2-2017 auto 18.6.5.1
  // task
  void write(out uvm_status_e  status,
	     uvm_reg_addr_t    offset,
	     uvm_reg_data_t    value,
	     uvm_door_e        path = uvm_door_e.UVM_DEFAULT_DOOR,
	     uvm_reg_map       map = null,
	     uvm_sequence_base parent = null,
	     int               prior = -1,
	     uvm_object        extension = null,
	     string            fname = "",
	     int               lineno = 0) {

    // create an abstract transaction for this operation
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_write", null, get_full_name());

    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_MEM);
      rw.set_kind(UVM_WRITE);
      rw.set_value(value, 0);
      rw.set_offset(offset);
      rw.set_door(path);
      rw.set_map(map);
      rw.set_parent_sequence(parent);
      rw.set_priority(prior);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }

    // task
    do_write(rw);

    synchronized(rw) {
      status = rw.get_status();
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.5.2
  // task
  void read(out uvm_status_e  status,
	    uvm_reg_addr_t     offset,
	    out uvm_reg_data_t value,
	    uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
	    uvm_reg_map        map = null,
	    uvm_sequence_base  parent = null,
	    int                prior = -1,
	    uvm_object         extension = null,
	    string             fname = "",
	    int                lineno = 0) {
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_read", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_MEM);
      rw.set_kind(UVM_READ);
      rw.set_value(uvm_reg_data_t(0), 0);
      rw.set_offset(offset);
      rw.set_door(path);
      rw.set_map(map);
      rw.set_parent_sequence(parent);
      rw.set_priority(prior);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }

    // task
    do_read(rw);

    synchronized(rw) {
      status = rw.get_status();
      value = rw.get_value(0);
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.5.3
  // task
  void burst_write(out uvm_status_e   status,
		   uvm_reg_addr_t     offset,
		   uvm_reg_data_t[]   value,
		   uvm_door_e         path = uvm_door_e.UVM_DEFAULT_DOOR,
		   uvm_reg_map        map = null,
		   uvm_sequence_base  parent = null,
		   int                prior = -1,
		   uvm_object         extension = null,
		   string             fname = "",
		   int                lineno = 0) {
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_burst_write", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_MEM);
      rw.set_kind(UVM_BURST_WRITE);
      rw.set_offset(offset);
      rw.set_value(value);
      rw.set_door(path);
      rw.set_map(map);
      rw.set_parent_sequence(parent);
      rw.set_priority(prior);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }

    // task
    do_write(rw);

    synchronized(rw) {
      status = rw.get_status();
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.5.4
  // task
  void burst_read(out uvm_status_e     status,
		  uvm_reg_addr_t       offset,
		  ref uvm_reg_data_t[] value,
		  uvm_door_e           path = uvm_door_e.UVM_DEFAULT_DOOR,
		  uvm_reg_map          map = null,
		  uvm_sequence_base    parent = null,
		  int                  prior = -1,
		  uvm_object           extension = null,
		  string               fname = "",
		  int                  lineno = 0) {

    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_burst_read", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_MEM);
      rw.set_kind(UVM_BURST_READ);
      rw.set_offset(offset);
      rw.set_value(value);
      rw.set_door(path);
      rw.set_map(map);
      rw.set_parent_sequence(parent);
      rw.set_priority(prior);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }

    // task
    do_read(rw);

    synchronized(rw) {
      status = rw.get_status();
      value  = rw.get_value();
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.5.5
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
      rw.set_element(this);
      rw.set_door(UVM_BACKDOOR);
      rw.set_element_kind(UVM_MEM);
      rw.set_kind(UVM_WRITE);
      rw.set_offset(offset);
      rw.set_value(value & ((1 << _m_n_bits)-1), 0);
      rw.set_bd_kind(kind);
      rw.set_parent_sequence(parent);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }

    if(bkdr !is null) {
      bkdr.write(rw);
    }
    else {
      backdoor_write(rw);
    }

    synchronized(rw) {
      status = rw.get_status();
    }

    uvm_info("RegModel", format("Poked memory '%s[%0d]' with value 'h%h",
				get_full_name(), offset, value), uvm_verbosity.UVM_HIGH);
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.5.6
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
      rw.set_element(this);
      rw.set_door(UVM_BACKDOOR);
      rw.set_element_kind(UVM_MEM);
      rw.set_kind(UVM_READ);
      rw.set_offset(offset);
      rw.set_bd_kind(kind);
      rw.set_parent_sequence(parent);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }

    if (bkdr !is null)
      bkdr.read(rw);
    else
      backdoor_read(rw);

    synchronized(rw) {
      status = rw.get_status;
      value  = rw.get_value(0);
    }

    uvm_info("RegModel", format("Peeked memory '%s[%0d]' has value 'h%h",
				get_full_name(), offset, value), uvm_verbosity.UVM_HIGH);
  }


  protected final bool Xcheck_accessX(uvm_reg_item rw,
				      out uvm_reg_map_info map_info) {
    synchronized(rw) {
      if (rw.get_offset() >= _m_size) {
	uvm_error(get_type_name(), 
		  format("Offset 'h%0h exceeds size of memory, 'h%0h",
			 rw.get_offset(), _m_size));
	rw.set_status(UVM_NOT_OK);
	return false;
      }

      if (rw.get_door() == UVM_DEFAULT_DOOR)
	rw.set_door(m_parent.get_default_door());

      if (rw.get_door() == UVM_BACKDOOR) {
	if (get_backdoor() is null && !has_hdl_path()) {
	  uvm_warning("RegModel",
		      "No backdoor access available for memory '" ~ get_full_name() ~
		      "' . Using frontdoor instead.");
	  rw.set_door(UVM_FRONTDOOR);
	}
	else if (rw.get_map() is null) {
	  if (get_default_map() !is null)
            rw.set_map(get_default_map());
	  else
	    rw.set_map(uvm_reg_map.backdoor());
	}
	//otherwise use the map specified in user's call to memory read/write
      }

      if (rw.get_door() != UVM_BACKDOOR) {
	uvm_reg_map rw_map = rw.get_map();
	
	rw.set_local_map(get_local_map(rw_map));

	if (rw.get_local_map() is null) {
	  uvm_error(get_type_name(), 
		    "No transactor available to physically access memory from map '" ~
		    rw_map.get_full_name() ~ "'");
	  rw.set_status(UVM_NOT_OK);
	  return false;
	}

	uvm_reg_map rw_local_map = rw.get_local_map();
	map_info = rw_local_map.get_mem_map_info(this);

	if (map_info.frontdoor is null) {
	  if (map_info.unmapped) {
	    uvm_error("RegModel", "Memory '" ~ get_full_name() ~
		      "' unmapped in map '" ~ rw_map.get_full_name() ~
		      "' and does not have a user-defined frontdoor");
	    rw.set_status(UVM_NOT_OK);
	    return false;
	  }

	  // if ((rw.value.length > 1)) {
	  if ((rw.get_value_size() > 1)) {
	    if (get_n_bits() > rw_local_map.get_n_bytes()*8) {
	      uvm_error("RegModel",
			format("Cannot burst a %0d-bit memory through a narrower data path (%0d bytes)",
			       get_n_bits(), rw_local_map.get_n_bytes()*8));
	      rw.set_status(UVM_NOT_OK);
	      return false;
	    }
	    if (rw.get_offset() + rw.get_value_size() > _m_size) {
	      uvm_error("RegModel",
			format("Burst of size 'd%0d starting at offset 'd%0d exceeds size of memory, 'd%0d",
			       rw.get_value_size(), rw.get_offset(), _m_size));
	      return false;
	    }
	  }
	}

	if (rw.get_map() is null) {
	  rw.set_map(rw.get_local_map());
	}
      }
      return true;
    }
  }


  // task
  void do_write(uvm_reg_item rw) {

    uvm_mem_cb_iter cbs = new uvm_mem_cb_iter(this);
    uvm_reg_map_info map_info;
   
    m_fname  = rw.get_fname();
    m_lineno = rw.get_line();

    if(!Xcheck_accessX(rw, map_info)) {
      return;
    }

    m_write_in_progress = true;

    rw.set_status(UVM_IS_OK);
   
    // PRE-WRITE CBS
    pre_write(rw);
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
      cb.pre_write(rw);

    if (rw.get_status() == UVM_IS_OK) {
      m_write_in_progress = false;
      return;
    }

    rw.set_status(UVM_NOT_OK);

    // FRONTDOOR
    if (rw.get_door() == UVM_FRONTDOOR) {
      uvm_reg_map rw_local_map = rw.get_local_map();
      uvm_reg_map system_map = rw_local_map.get_root_map();
      
      if (map_info.frontdoor !is null) {
	uvm_reg_frontdoor fd = map_info.frontdoor;
	fd.rw_info = rw;
	if (fd.sequencer is null)
	  fd.sequencer = system_map.get_sequencer();
	fd.start(fd.sequencer, rw.get_parent_sequence());
      }
      else {
	rw_local_map.do_write(rw);
      }

      if (rw.get_status() != UVM_NOT_OK) {
	for (uvm_reg_addr_t idx = rw.get_offset();
	     idx <= rw.get_offset() + rw.get_value_size();
	     idx++) {
	  XsampleX(cast(uvm_reg_addr_t)(map_info.mem_range.stride * idx),
		   false, rw.get_map());
	  m_parent.XsampleX(map_info.offset +
			    (map_info.mem_range.stride * idx),
			    0, rw.get_map());
	}
      }
    }
      
    // BACKDOOR     
    else {
      // Mimick front door access, i.e. do not write read-only memories
      string access = get_access(rw.get_map());
      if (access == "RW" || access == "WO") {
	uvm_reg_backdoor bkdr = get_backdoor();
	if (bkdr !is null)
	  bkdr.write(rw);
	else
	  backdoor_write(rw);
      }
      else
	rw.set_status(UVM_NOT_OK);
    }

    // POST-WRITE CBS
    post_write(rw);
    for(uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
      cb.post_write(rw);
    }

    // REPORT
    if(uvm_report_enabled(uvm_verbosity.UVM_HIGH, uvm_severity.UVM_INFO, "RegModel")) {
      string path_s, value_s, pre_s, range_s;
      uvm_reg_map rw_map = rw.get_map();
      if (rw.get_door() == UVM_FRONTDOOR)
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ rw_map.get_full_name();
      else
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";

      if (rw.get_value_size() > 1) {
	auto rw_value_size = rw.get_value_size();
	value_s = "='{";
	pre_s = "Burst ";
	foreach (i, val; rw.get_value())
	  value_s = value_s ~ format("%0h,", val);
	value_s = value_s[0..$-1] ~ '}';
	range_s = format("[%0d:%0d]", rw.get_offset(), rw.get_offset()+rw.get_value_size());
      }
      else {
	value_s = format("=%0h", rw.get_value(0));
	range_s = format("[%0d]", rw.get_offset());
      }

      uvm_info("RegModel", pre_s ~ "Wrote memory via " ~ path_s ~ ": " ~
	       get_full_name() ~ range_s ~ value_s, uvm_verbosity.UVM_HIGH);
    }

    m_write_in_progress = false;
  }


  // task
  void do_read(uvm_reg_item rw) {

    uvm_mem_cb_iter cbs = new uvm_mem_cb_iter(this);
    uvm_reg_map_info map_info;
   
    m_fname = rw.get_fname();
    m_lineno = rw.get_line();

    if (!Xcheck_accessX(rw, map_info))
      return;

    m_read_in_progress = true;

    rw.set_status(UVM_IS_OK);
   
    // PRE-READ CBS
    pre_read(rw);
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
      cb.pre_read(rw);

    if (rw.get_status() != UVM_IS_OK) {
      m_read_in_progress = false;

      return;
    }

    rw.set_status(UVM_NOT_OK);

    // FRONTDOOR
    if (rw.get_door() == UVM_FRONTDOOR) {
      uvm_reg_map rw_local_map = rw.get_local_map();
      uvm_reg_map system_map = rw_local_map.get_root_map();
         
      if (map_info.frontdoor !is null) {
	uvm_reg_frontdoor fd = map_info.frontdoor;
	fd.rw_info = rw;
	if (fd.sequencer is null)
	  fd.sequencer = system_map.get_sequencer();
	fd.start(fd.sequencer, rw.get_parent_sequence());
      }
      else {
	rw_local_map.do_read(rw);
      }

      if (rw.get_status() != UVM_NOT_OK)
	for (uvm_reg_addr_t idx = rw.get_offset();
	     idx <= rw.get_offset() + rw.get_value_size();
	     idx++) {
	  XsampleX(cast(uvm_reg_addr_t)(map_info.mem_range.stride * idx), true, rw.get_map());
	  m_parent.XsampleX(map_info.offset +
			    (map_info.mem_range.stride * idx),
			    true, rw.get_map());
	}
    }

    // BACKDOOR
    else {
      // Mimick front door access, i.e. do not read write-only memories
      string access = get_access(rw.get_map());
      if (access == "RW" || access == "RO") {
	uvm_reg_backdoor bkdr = get_backdoor();
	if (bkdr !is null)
            bkdr.read(rw);
         else
            backdoor_read(rw);
      }
      else
	rw.set_status(UVM_NOT_OK);
    }

    // POST-READ CBS
    post_read(rw);
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
      cb.post_read(rw);

    // REPORT
    if (uvm_report_enabled(uvm_verbosity.UVM_HIGH, uvm_severity.UVM_INFO, "RegModel")) {
      uvm_reg_map rw_map = rw.get_map();
      string path_s, value_s, pre_s, range_s;
      if (rw.get_door() == UVM_FRONTDOOR)
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ rw_map.get_full_name();
      else
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";

      if (rw.get_value_size() > 1) {
	auto rw_value_size = rw.get_value_size();
	value_s = "='{";
	pre_s = "Burst ";
	foreach (i, v; rw.get_value())
	  value_s = value_s ~ format("%0h,", v);
	value_s = value_s[0..$-1] ~ '}';
	range_s = format("[%0d:%0d]", rw.get_offset(), (rw.get_offset() + rw_value_size));
      }
      else {
	value_s = format("=%0h", rw.get_value(0));
	range_s = format("[%0d]", rw.get_offset());
      }

      uvm_info("RegModel", pre_s ~ "Read memory via " ~ path_s ~ ": " ~
	       get_full_name() ~ range_s ~ value_s, uvm_verbosity.UVM_HIGH);
    }

    m_read_in_progress = false;
  }



  //-----------------
  // Group -- NODOCS -- Frontdoor
  //-----------------


  // @uvm-ieee 1800.2-2017 auto 18.6.6.2
  final void set_frontdoor(uvm_reg_frontdoor ftdr,
			   uvm_reg_map       map = null,
			   string            fname = "",
			   int               lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      map = get_local_map(map);

      if (map is null) {
	uvm_error("RegModel", "Memory '" ~ get_full_name() ~
		  "' not found in map '" ~ map.get_full_name() ~ "'");
	return;
      }

      uvm_reg_map_info map_info = map.get_mem_map_info(this);
      map_info.frontdoor = ftdr;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.6.1
  final uvm_reg_frontdoor get_frontdoor(uvm_reg_map map = null) {
    synchronized(this) {
      map = get_local_map(map);

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
  // Group -- NODOCS -- Backdoor
  //----------------


  // @uvm-ieee 1800.2-2017 auto 18.6.7.2
  final void set_backdoor(uvm_reg_backdoor bkdr,
				 string fname = "",
				 int lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      _m_backdoor = bkdr;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.7.1
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

  // @uvm-ieee 1800.2-2017 auto 18.6.7.3
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

  // @uvm-ieee 1800.2-2017 auto 18.6.7.4
  final void add_hdl_path(uvm_hdl_path_slice[] slices, string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) paths = _m_hdl_paths_pool.get(kind);
      uvm_hdl_path_concat concat = new uvm_hdl_path_concat();

      concat.set(slices);
      paths.push_back(concat);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.7.5
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


  // @uvm-ieee 1800.2-2017 auto 18.6.7.6
  bool has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "")
	kind = _m_parent.get_default_hdl_path();
  
      if (kind in _m_hdl_paths_pool) return true;
      else return false;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.7.7
  final void get_hdl_path(ref uvm_hdl_path_concat[] paths,
			  string kind = "") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) hdl_paths;

      if (kind == "")
	kind = _m_parent.get_default_hdl_path();

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


  // @uvm-ieee 1800.2-2017 auto 18.6.7.9
  final void get_full_hdl_path(ref uvm_hdl_path_concat[] paths, // queue in SV
			       string kind = "",
			       string separator = ".") {
    synchronized(this) {
      if (kind == "")
	kind = _m_parent.get_default_hdl_path();
   
      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Memory does not have hdl path defined for abstraction '" ~ kind ~ "'");
	return;
      }

      uvm_queue!(uvm_hdl_path_concat) hdl_paths = _m_hdl_paths_pool.get(kind);
      string[] parent_paths;

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


  // @uvm-ieee 1800.2-2017 auto 18.6.7.8
  void get_hdl_path_kinds (out string[] kinds) { // queue in SV
    synchronized(this) {
      foreach (kind, unused; _m_hdl_paths_pool) {
	kinds ~= kind;
      }
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.7.10
  // task
  protected void backdoor_read(uvm_reg_item rw) {
    rw.set_status(backdoor_read_func(rw));
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.7.11
  // task
  protected void backdoor_write(uvm_reg_item rw) { // public in SV version
    
    uvm_hdl_path_concat[] paths;
    bool ok = true;
   
    get_full_hdl_path(paths, rw.get_bd_kind());
   
    // foreach (mem_idx, v; rw.value) {
    foreach (mem_idx, v; rw.get_value()) {
      import std.conv: to;
      string idx = (rw.get_offset() + mem_idx).to!string;
      foreach (i, path; paths) {
	uvm_hdl_path_concat hdl_concat = path;
	foreach(j, sl; hdl_concat.slices) {
	  uvm_info("RegModel", format("backdoor_write to %s ", sl.path), uvm_verbosity.UVM_DEBUG);
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
    rw.set_status(ok ? UVM_IS_OK : UVM_NOT_OK);
  }

  uvm_status_e backdoor_read_func(uvm_reg_item rw) {
    synchronized(this) {
      uvm_hdl_path_concat[] paths;
      uvm_reg_data_t val;
      bool ok = true;

      get_full_hdl_path(paths, rw.get_bd_kind());

      foreach (mem_idx, ref v; rw.get_value()) {
	import std.conv: to;
	string idx = (rw.get_offset() + mem_idx).to!string;
	foreach (i, path; paths) {
	  uvm_hdl_path_concat hdl_concat = path;
	  val = 0;
	  foreach (j, sl; hdl_concat.slices) {
	    string hdl_path = sl.path ~ "[" ~ idx ~ "]";
	    
	    uvm_info("RegModel", "backdoor_read from " ~ hdl_path, uvm_verbosity.UVM_DEBUG);
 
	    if(sl.offset < 0) {
	      ok &= uvm_hdl_read(hdl_path, val);
	      continue;
	    }
	    uvm_reg_data_t slice;
	    int k = sl.offset;
	    ok &= uvm_hdl_read(hdl_path, slice);

	    // for(size_t n; n != sl.size; ++n) {
	    //   val[k++] = slice[0];
	    //   slice >>= 1;
	    // }
	    uvm_reg_data_t mask = 1;
	    mask <<= sl.size;
	    mask -= 1;
	    mask <<= sl.offset;

	    val &= ~mask;

	    val |= (slice << sl.offset) & mask;
	    
	  }
  

	  val &= (1 << _m_n_bits)-1;

	  if (i == 0)
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

      rw.set_status(ok ? UVM_IS_OK : UVM_NOT_OK);

      return rw.get_status();
    }
  }

  //-----------------
  // Group -- NODOCS -- Callbacks
  //-----------------
  // uvm_register_cb(uvm_mem, uvm_reg_cbs)
  mixin uvm_register_cb!(uvm_reg_cbs);


  // @uvm-ieee 1800.2-2017 auto 18.6.9.1
  // task
  void pre_write(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2017 auto 18.6.9.2
  // task
  void post_write(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2017 auto 18.6.9.3
  // task
  void pre_read(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2017 auto 18.6.9.4
  // task
  void post_read(uvm_reg_item rw) { }


  //----------------
  // Group -- NODOCS -- Coverage
  //----------------

  // @uvm-ieee 1800.2-2017 auto 18.6.8.1
  final uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models) {
    uvm_reg_cvr_t retval = uvm_coverage_model_e.UVM_NO_COVERAGE;
    uvm_reg_cvr_rsrc_db.read_by_name("uvm_reg::" ~ get_full_name(),
				     "include_coverage",
				     retval, this);
    return retval & models;
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.8.2
  protected void add_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      _m_has_cover |= models;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.8.3
  bool has_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      return ((_m_has_cover & models) == models);
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.6.8.5
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

  // @uvm-ieee 1800.2-2017 auto 18.6.8.4
  bool get_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      if (has_coverage(is_on) == 0) return 0;
      return ((_m_cover_on & is_on) == is_on);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.6.8.6
  protected void sample(uvm_reg_addr_t offset,
			bool            is_read,
			uvm_reg_map    map) { }
  
  private final void XsampleX(uvm_reg_addr_t addr,
			      bool            is_read,
			      uvm_reg_map    map) {
    sample(addr, is_read, map);
  }

  // Core ovm_object operations

  override void do_print (uvm_printer printer) {
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      super.do_print(printer);
      //printer.print_generic(" ", " ", -1, convert2string());
      printer.print_field("n_bits", get_n_bits(), 32, uvm_radix_enum.UVM_UNSIGNED);
      printer.print_field("size", get_size(), 32, uvm_radix_enum.UVM_UNSIGNED);
    }
  }


  override string convert2string() {
    synchronized(this) {
      string retval;

      string res_str;
      string prefix;

      retval = format("%sMemory %s -- %0dx%0d bits", prefix,
		      get_full_name(), get_size(), get_n_bits());

      if (_m_maps.length == 0)
	retval ~= "  (unmapped)\n";
      else
	retval ~= "\n";
      foreach (map, unused; _m_maps) {
	uvm_reg_map parent_map = map;
	while (parent_map !is null) {
	  uvm_reg_map this_map = parent_map;
	  uvm_endianness_e endian_name;
	  parent_map = this_map.get_parent_map();
	  endian_name = this_map.get_endian();
       
	  auto offset = parent_map is null ? this_map.get_base_addr(UVM_NO_HIER) :
	    parent_map.get_submap_offset(this_map);
	  prefix ~= "  ";
	  retval = format("%sMapped in '%s' -- buswidth %0d bytes, %s, " ~
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
	retval ~= "  " ~ res_str ~ "currently executing read method"; 
      }
      if ( _m_write_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0) {
	  res_str = format("%s:%0d ",_m_fname, _m_lineno);
	}
	retval ~= "  " ~ res_str ~ "currently executing write method"; 
      }
      return retval;
    }
  }


  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel memories cannot be cloned");
    return null;
  }

  override void do_copy(uvm_object rhs) {
    uvm_fatal("RegModel","RegModel memories cannot be copied");
  }


  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel memories cannot be compared");
    return false;
  }

  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel memories cannot be packed");
  }

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel memories cannot be unpacked");
  }

}
