//
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2012 Accellera Systems Initiative
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2018 Intel Corporation
// Copyright 2020 Marvell International Ltd.
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2011-2020 Semifore
// Copyright 2004-2018 Synopsys, Inc.
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
//

module uvm.reg.uvm_reg;

import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg_map: uvm_reg_map, uvm_reg_map_info;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_reg_file: uvm_reg_file;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_sequence: uvm_reg_frontdoor;
import uvm.reg.uvm_reg_backdoor: uvm_reg_backdoor;
import uvm.reg.uvm_reg_cbs: uvm_reg_cbs, uvm_reg_cb_iter, uvm_reg_field_cb_iter;

import uvm.base.uvm_callback: uvm_register_cb;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_comparer: uvm_comparer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_verbosity, uvm_severity;
import uvm.base.uvm_globals: uvm_fatal, uvm_error, uvm_warning, uvm_info,
  uvm_report_enabled, uvm_report_info;
import uvm.base.uvm_pool: uvm_object_string_pool;
import uvm.base.uvm_queue: uvm_queue;
import uvm.base.uvm_entity: uvm_entity_base;

import uvm.seq.uvm_sequence_base: uvm_sequence_base;
import uvm.reg.uvm_reg_defines: UVM_REG_DATA_1;

import uvm.dpi.uvm_hdl;

import uvm.meta.misc;
import uvm.base.uvm_scope: uvm_scope_base;

import esdl.base.core: Process;
import esdl.data.bvec;
import esdl.base.comm: SemaphoreObj;
import esdl.rand;

import std.string: format;

// Class: uvm_reg
// This is an implementation of uvm_reg as described in 1800.2 with
// the addition of API described below.

// @uvm-ieee 1800.2-2020 auto 18.4.1
class uvm_reg: uvm_object, rand.barrier
{
  mixin uvm_sync;

  private bool              _m_locked;
  @uvm_private_sync
  private uvm_reg_block     _m_parent;
  private uvm_reg_file      _m_regfile_parent;
  @uvm_private_sync
  private uint              _m_n_bits;
  private uint              _m_n_used_bits;
  private bool[uvm_reg_map] _m_maps;
  private uvm_reg_field[]   _m_fields;   // Fields in LSB to MSB order
  private int               _m_has_cover;
  private int               _m_cover_on;
  @uvm_immutable_sync
  private SemaphoreObj      _m_atomic;

  @uvm_private_sync
  private Process           _m_process;

  private string            _m_fname;
  private int               _m_lineno;
  @uvm_private_sync
  private bool              _m_read_in_progress;
  @uvm_private_sync
  private bool              _m_write_in_progress; 
  @uvm_protected_sync
  protected bool            _m_update_in_progress;
  @uvm_private_sync
  private bool              _m_is_busy;
  @uvm_public_sync
  private bool              _m_is_locked_by_field;

  private uvm_reg_backdoor  _m_backdoor;

  mixin (uvm_scope_sync_string);
  
  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    uint _m_max_size;
  }

  
  private uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))
    _m_hdl_paths_pool;

  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------


  // @uvm-ieee 1800.2-2020 auto 18.4.2.1
  this(string name, uint n_bits, int has_coverage) {
    synchronized(this) {
      super(name);
      if (n_bits == 0) {
	uvm_error("RegModel", format("Register \"%s\" cannot have 0 bits", get_name()));
	n_bits = 1;
      }
      _m_n_bits      = n_bits;
      _m_has_cover   = has_coverage;
      _m_atomic      = new SemaphoreObj(1, uvm_entity_base.get());
      _m_n_used_bits = 0;
      _m_locked      = false;
      _m_is_busy     = false;
      _m_is_locked_by_field = false;
      _m_hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))("hdl_paths");

      synchronized(_uvm_scope_inst) {
	if (n_bits > _m_max_size)
	  _m_max_size = n_bits;
      }
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.2.2
  final void configure (uvm_reg_block blk_parent,
			uvm_reg_file regfile_parent=null,
			string hdl_path = "") {
    if (blk_parent is null) {
      uvm_error("UVM/REG/CFG/NOBLK", "uvm_reg::configure() called without" ~
		" a parent block for instance \"" ~ get_name() ~
		"\" of register type \"" ~ get_type_name() ~ "\".");
	return;
    }

    synchronized(this) {
      _m_parent = blk_parent;
      _m_parent.add_reg(this);
      _m_regfile_parent = regfile_parent;
      if (hdl_path != "") {
	add_hdl_path_slice(hdl_path, -1, -1);
      }
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.2.3
  void set_offset (uvm_reg_map    map,
		   uvm_reg_addr_t offset,
		   bool unmapped = false) {
    synchronized(this) {

      uvm_reg_map orig_map = map;

      if (_m_maps.length > 1 && map is null) {
	uvm_error("RegModel",
		  "set_offset requires a non-null map when register '" ~
		  get_full_name() ~ "' belongs to more than one map.");
	return;
      }

      map = get_local_map(map);

      if (map is null) {
	return;
      }
   
      map.m_set_reg_offset(this, offset, unmapped);
    }
  }


  void set_parent(uvm_reg_block blk_parent,
		  uvm_reg_file regfile_parent) {
    synchronized(this) {
      if (_m_parent !is null) {
	// ToDo: remove register from previous parent
      }
      _m_parent = blk_parent;
      _m_regfile_parent = regfile_parent;
    }
  }

  void add_field(uvm_reg_field field) {
    synchronized(this) {
   
      if (_m_locked) {
	uvm_error("RegModel", "Cannot add field to locked register model");
	return;
      }

      if (field is null) uvm_fatal("RegModel", "Attempting to register NULL field");

      // Store fields in LSB to MSB order
      int offset = field.get_lsb_pos();

      ptrdiff_t idx = -1;
      foreach (j, f; _m_fields) {
	if (offset < f.get_lsb_pos()) {
	  _m_fields = _m_fields[0..j] ~ field ~ _m_fields[j..$];
	  // _m_fields.insert(j, field);
	  idx = j;
	  break;
	}
      }
      if (idx < 0) {
	_m_fields ~= field;
	idx = _m_fields.length-1;
	_m_n_used_bits = offset + field.get_n_bits();
      }

      // Check if there are too many fields in the register
      if (_m_n_used_bits > _m_n_bits) {
	uvm_error("RegModel",
		  format("Fields use more bits (%0d) than available in register \"%s\" (%0d)",
			 _m_n_used_bits, get_name(), _m_n_bits));
      }

      // Check if there are overlapping fields
      if (idx > 0) {
	if (_m_fields[idx-1].get_lsb_pos() +
	    _m_fields[idx-1].get_n_bits() > offset) {
	  uvm_error("RegModel", format("Field %s overlaps field %s in register \"%s\"",
				       _m_fields[idx-1].get_name(),
				       field.get_name(), get_name()));
	}
      }
      if (idx < _m_fields.length-1) {
	if (offset + field.get_n_bits() >
	    _m_fields[idx+1].get_lsb_pos()) {
	  uvm_error("RegModel", format("Field %s overlaps field %s in register \"%s\"",
				       field.get_name(),
				       _m_fields[idx+1].get_name(),
				       get_name()));
	}
      }
    }
  }


  void add_map(uvm_reg_map map) {
    synchronized(this) {
      _m_maps[map] = true;
    }
  }



  void Xlock_modelX() {
    synchronized(this) {
      if (_m_locked)
	return;
      _m_locked = true;
    }
  }

  // remove the knowledge that the register resides in the map from the register instance
  // @uvm-ieee 1800.2-2020 auto 18.4.2.5
  void unregister(uvm_reg_map map) {
    synchronized(this) {
      _m_maps.remove(map);
    }
  }

  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  // Function -- NODOCS -- get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this register.
  //

  // Function -- NODOCS -- get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this register.
  // The base of the hierarchical name is the root block.
  //
  override string get_full_name() {
    synchronized(this) {
      if (_m_regfile_parent !is null)
	return _m_regfile_parent.get_full_name() ~ "." ~ get_name();

      if (_m_parent !is null)
	return _m_parent.get_full_name() ~ "." ~ get_name();
   
      return get_name();
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.1
  uvm_reg_block get_parent() {
    return get_block();
  }

  uvm_reg_block get_block() {
    synchronized(this) {
      return _m_parent;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.2
  uvm_reg_file get_regfile() {
    synchronized(this) {
      return _m_regfile_parent;

    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.3
  int get_n_maps() {
    synchronized(this) {
      return cast(int) _m_maps.length;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.4
  bool is_in_map(uvm_reg_map map) {
    synchronized(this) {
      if (map in _m_maps) {
	return true;
      }
      foreach (l, unused; _m_maps) {
	uvm_reg_map local_map = l;
	uvm_reg_map parent_map = local_map.get_parent_map();

	while (parent_map !is null) {
	  if (parent_map == map)
	    return 1;
	  parent_map = parent_map.get_parent_map();
	}
      }
      return false;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.5
  void get_maps(ref uvm_reg_map[] maps) {
    synchronized(this) {
      foreach (map, unused; _m_maps) {
	maps ~= map;
      }
    }
  }

  uvm_reg_map[] get_maps() {
    synchronized(this) {
      uvm_reg_map[] maps;
      foreach (map, unused; _m_maps) maps ~= map;
      return maps;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.6
  uvm_reg_map get_local_map(uvm_reg_map map) {
    synchronized(this) {
      if (map is null) {
	return get_default_map();
      }
      if (map in _m_maps) {
	return map;
      }
      foreach (l, unused; _m_maps) {
	uvm_reg_map local_map = l;
	uvm_reg_map parent_map = local_map.get_parent_map();

	while (parent_map !is null) {
	  if (parent_map == map)
	    return local_map;
	  parent_map = parent_map.get_parent_map();
	}
      }
      uvm_warning("RegModel", 
		  "Register '" ~ get_full_name() ~
		  "' is not contained within map '" ~
		  map.get_full_name() ~ "'");
      return null;
    }
  }

  // Function: get_default_map
  //
  // Returns default map for the register as follows:
  //
  // If the register is not associated with any map - returns null
  // Else If the register is associated with only one map - return a handle to that map
  // Else try to find the first default map in its parent blocks and return its handle
  // If there are no default maps in the registers parent blocks return a handle to the first map in its map array 
  //  
  uvm_reg_map get_default_map() {
    synchronized(this) {
      // if reg is not associated with any map, return null
      if (_m_maps.length == 0) {
	uvm_warning("RegModel",
		    "Register '" ~ get_full_name() ~
		    "' is not registered with any map");
	return null;
      }

      // if only one map, choose that
      if (_m_maps.length == 1) {
	uvm_reg_map map = _m_maps.keys()[0];
	return map;
      }

      // try to choose one based on default_map in parent blocks.
      foreach (map, unused; _m_maps) {
	uvm_reg_block blk = map.get_parent();
	uvm_reg_map default_map = blk.get_default_map();
	if (default_map !is null) {
	  uvm_reg_map local_map = get_local_map(default_map);
	  if (local_map !is null)
	    return local_map;
	}
      }

      // if that fails, choose the first in this reg's maps

      uvm_reg_map map = _m_maps.keys()[0];
      return map;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.7
  string get_rights(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info info;

      map = get_local_map(map);

      if (map is null)
	return "RW";

      info = map.get_reg_map_info(this);
      return info.rights;

    }
  }

  // Function -- NODOCS -- get_n_bits
  //
  // Returns the width, in bits, of this register.
  //
  uint get_n_bits() {
    synchronized(this) {
      return _m_n_bits;
    }
  }

  // Function -- NODOCS -- get_n_bytes
  //
  // Returns the width, in bytes, of this register. Rounds up to
  // next whole byte if register is not a multiple of 8.
  //
  uint get_n_bytes() {
    synchronized(this) {
      return ((_m_n_bits-1) / 8) + 1;
    }
  }

  // Function -- NODOCS -- get_max_size
  //
  // Returns the maximum width, in bits, of all registers. 
  //
  static uint get_max_size() {
    synchronized(_uvm_scope_inst) {
      return _m_max_size;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.3.11
  void get_fields(ref uvm_reg_field[] fields) {
    synchronized(this) {
      foreach (field; _m_fields) {
	fields ~= field;
      }
    }
  }

  uvm_reg_field[] get_fields() {
    synchronized(this) {
      return _m_fields.dup;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.12
  uvm_reg_field get_field_by_name(string name) {
    synchronized(this) {
      foreach (field; _m_fields) {
	if (field.get_name() == name)
	  return field;
      }
      uvm_warning("RegModel", "Unable to locate field '" ~ name ~
		  "' in register '" ~ get_name() ~ "'");
      return null;
    }
  }

  string Xget_fields_accessX(uvm_reg_map map) {
    synchronized(this) {
      bool is_R;
      bool is_W;
   
      foreach (i, field; _m_fields) {
	switch (field.get_access(map)) {
	case "RO", "RC", "RS":
	  is_R = true; break;
       
	case "WO", "WOC", "WOS", "WO1":
	  is_W = true; break;
       
	default:
	  return "RW";
	}

	if (is_R && is_W) return "RW";
      }

      if (!is_R && is_W) return "WO";
      if (!is_W && is_R) return "RO";

      return "RW";
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.13
  uvm_reg_addr_t get_offset(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map orig_map = map;

      map = get_local_map(map);

      if (map is null)
	return -1;
   
      map_info = map.get_reg_map_info(this);
   
      if (map_info.unmapped) {
	uvm_warning("RegModel", "Register '" ~ get_name() ~ 
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() :
		     orig_map.get_full_name()) ~ "'");
	return -1;
      }
         
      return map_info.offset;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.14
  uvm_reg_addr_t get_address(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_addr_t[]  addr;
      get_addresses(map,addr);
      return addr[0];
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.3.15
  int get_addresses(uvm_reg_map map, ref uvm_reg_addr_t[] addr) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map orig_map = map;

      map = get_local_map(map);

      if (map is null) {
	return -1;
      }

      map_info = map.get_reg_map_info(this);

      if (map_info.unmapped) {
	uvm_warning("RegModel", "Register '" ~ get_name() ~
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() :
		     orig_map.get_full_name()) ~ "'");
	return -1;
      }
 
      addr = map_info.addr;
      return map.get_n_bytes();
    }
  }


  //--------------
  // Group -- NODOCS -- Access
  //--------------

  // @uvm-ieee 1800.2-2020 auto 18.4.4.2
  void set(uvm_reg_data_t  value,
	   string          fname = "",
	   int             lineno = 0) {
    synchronized(this) {
      // Split the value into the individual fields
      _m_fname = fname;
      _m_lineno = lineno;

      foreach (field; _m_fields) {
	field.set((value >> field.get_lsb_pos()) &
		  ((UVM_REG_DATA_1 << field.get_n_bits()) - 1));
      }
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.1
  uvm_reg_data_t  get(string  fname = "",
		      int     lineno = 0) {
    synchronized(this) {
      // Concatenate the value of the individual fields
      // to form the register value
      _m_fname = fname;
      _m_lineno = lineno;

      uvm_reg_data_t retval = 0;
   
      foreach (i, field; _m_fields) {
	retval |= field.get() << field.get_lsb_pos();
      }
      return retval;
      
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.3
  uvm_reg_data_t  get_mirrored_value(string  fname = "",
				     int     lineno = 0) {
    synchronized(this) {
      // Concatenate the value of the individual fields
      // to form the register value
      _m_fname = fname;
      _m_lineno = lineno;

      uvm_reg_data_t retval = 0;
   
      foreach (field; _m_fields)
	retval |= field.get_mirrored_value() << field.get_lsb_pos();
      return retval;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.4
  bool needs_update() {
    synchronized(this) {
      foreach (i, field; _m_fields) {
	if (field.needs_update()) {
	  return true;
	}
      }
      return false;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.5
  void reset(string kind = "HARD") {
    synchronized(this) {
      foreach (field; _m_fields) {
	field.reset(kind);
      }
      // Put back a key in the semaphore if it is checked out
      // in case a thread was killed during an operation
      _m_atomic.tryWait();
      _m_atomic.post();
      _m_process = null;
    }
  }

  // Function -- NODOCS -- get_reset
  //
  // Get the specified reset value for this register
  //
  // Return the reset value for this register
  // for the specified reset ~kind~.
  //
  // @uvm-ieee 1800.2-2020 auto 18.4.4.6
  uvm_reg_data_t get_reset(string kind = "HARD") {
    synchronized(this) {
      // Concatenate the value of the individual fields
      // to form the register value
      uvm_reg_data_t retval = 0;
   
      foreach (field; _m_fields) {
	retval |= field.get_reset(kind) << field.get_lsb_pos();
      }
      return retval;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.4.7
  bool has_reset(string kind = "HARD",
		 bool remove = false) {
    synchronized(this) {
      bool retval = false;
      foreach (field; _m_fields) {
	retval |= field.has_reset(kind, remove);
	if (!remove && retval)
	  return true;
      }
      return retval;
    }
  }

  // Function -- NODOCS -- set_reset
  //
  // Specify or modify the reset value for this register
  //
  // Specify or modify the reset value for all the fields in the register
  // corresponding to the cause specified by ~kind~.
  //

  // @uvm-ieee 1800.2-2020 auto 18.4.4.8
  void set_reset(uvm_reg_data_t value,
		 string         kind = "HARD") {
    synchronized(this) {
      foreach (field; _m_fields) {
	field.set_reset(value >> field.get_lsb_pos(), kind);
      }
    }
  }

  void write(T)(out uvm_status_e  status,
		T                 value_,
		uvm_door_e        door = uvm_door_e.UVM_DEFAULT_DOOR,
		uvm_reg_map       map = null,
		uvm_sequence_base parent = null,
		int               prior = -1,
		uvm_object        extension = null,
		string            fname = "",
		int               lineno = 0) {
    uvm_reg_data_t value = value_;
    write(status, value, door, map, parent, prior, extension, fname, lineno);
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.9
  // @uvm-ieee 1800.2-2020 auto 18.8.5.3
  // task
  void write(out uvm_status_e  status,
	     uvm_reg_data_t    value,
	     uvm_door_e        door = uvm_door_e.UVM_DEFAULT_DOOR,
	     uvm_reg_map       map = null,
	     uvm_sequence_base parent = null,
	     int               prior = -1,
	     uvm_object        extension = null,
	     string            fname = "",
	     int               lineno = 0) {
    // create an abstract transaction for this operation

    XatomicX(true);

    set(value);

    uvm_reg_item rw = uvm_reg_item.type_id.create("write_item", null,
						  get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_REG);
      rw.set_kind(UVM_WRITE);
      rw.set_value(value, 0); // rw.value[0]    = value;
      rw.set_door(door);
      rw.set_map(map);
      rw.set_parent_sequence(parent);
      rw.set_priority(prior);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }
      
    do_write(rw);

    status = rw.get_status();

    XatomicX(false);

  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.10
  // @uvm-ieee 1800.2-2020 auto 18.8.5.4
  // task
  void read(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    uvm_door_e            door = uvm_door_e.UVM_DEFAULT_DOOR,
	    uvm_reg_map           map = null,
	    uvm_sequence_base     parent = null,
	    int                   prior = -1,
	    uvm_object            extension = null,
	    string                fname = "",
	    int                   lineno = 0) {
    XatomicX(true);
    XreadX(status, value, door, map, parent, prior, extension, fname, lineno);
    XatomicX(false);
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.4.11
  // task
  void poke(out uvm_status_e  status,
	    uvm_reg_data_t    value,
	    string            kind = "",
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {

    uvm_reg_backdoor bkdr = get_backdoor();

    _m_fname = fname;
    _m_lineno = lineno;


    if (bkdr is null && !has_hdl_path(kind)) {
      uvm_error("RegModel",
		"No backdoor access available to poke register '" ~
		get_full_name() ~ "'");
      status = UVM_NOT_OK;
      return;
    }

    if (! m_is_locked_by_field)
      XatomicX(true);

    // create an abstract transaction for this operation
    uvm_reg_item rw =
      uvm_reg_item.type_id.create("reg_poke_item", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_door(UVM_BACKDOOR);
      rw.set_element_kind(UVM_REG);
      rw.set_kind(UVM_WRITE);
      rw.set_bd_kind(kind);
      rw.set_value(value & ((UVM_REG_DATA_1 << _m_n_bits) - 1), 0);
      rw.set_parent_sequence(parent);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }
    
    if (bkdr !is null)
      bkdr.write(rw);
    else
      backdoor_write(rw);

    synchronized(rw) {
      status = rw.get_status();
    }

    uvm_info("RegModel", format("Poked register \"%s\": 0x%x",
				get_full_name(), value),uvm_verbosity.UVM_HIGH);

    do_predict(rw, UVM_PREDICT_WRITE);

    if (! m_is_locked_by_field)
      XatomicX(false);
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.4.12
  // task
  void peek(out uvm_status_e      status,
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
    }

    if (bkdr is null && !has_hdl_path(kind)) {
      uvm_error("RegModel", format("No backdoor access available to peek register \"%s\"",
				   get_full_name()));
      status = UVM_NOT_OK;
      return;
    }

    if (! m_is_locked_by_field) {
      XatomicX(true);
    }

    // create an abstract transaction for this operation
    uvm_reg_item rw = uvm_reg_item.type_id.create("mem_peek_item", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_door(UVM_BACKDOOR);
      rw.set_element_kind(UVM_REG);
      rw.set_kind(UVM_READ);
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

    status = rw.get_status();
    value = rw.get_value(0);
    
    uvm_info("RegModel", format("Peeked register \"%s\": 0x%x",
				get_full_name(), value),uvm_verbosity.UVM_HIGH);

    do_predict(rw, UVM_PREDICT_READ);

    if (! m_is_locked_by_field) {
      XatomicX(false);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.13
  // task
  void update(out uvm_status_e      status,
	      uvm_door_e            door = uvm_door_e.UVM_DEFAULT_DOOR,
	      uvm_reg_map           map = null,
	      uvm_sequence_base     parent = null,
	      int                   prior = -1,
	      uvm_object            extension = null,
	      string                fname = "",
	      int                   lineno = 0) {

    status = UVM_IS_OK;

    if (! needs_update()) return;

    // Concatenate the write-to-update values from each field
    // Fields are stored in LSB or MSB order
    uvm_reg_data_t upd = 0;
    synchronized(this) {
      foreach (field; _m_fields) {
	upd |= field.XupdateX() << field.get_lsb_pos();
      }
    }
    
    write(status, upd, door, map, parent, prior, extension, fname, lineno);
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.4.14
  // @uvm-ieee 1800.2-2020 auto 18.8.5.6
  // task
  void mirror(out uvm_status_e   status,
	      uvm_check_e        check = uvm_check_e.UVM_NO_CHECK,
	      uvm_door_e         door = uvm_door_e.UVM_DEFAULT_DOOR,
	      uvm_reg_map        map = null,
	      uvm_sequence_base  parent = null,
	      int                prior = -1,
	      uvm_object         extension = null,
	      string             fname = "",
	      int                lineno = 0) {
    uvm_reg_data_t  exp;
    uvm_reg_backdoor bkdr = get_backdoor();

    XatomicX(true);
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      if (door == UVM_DEFAULT_DOOR)
	door = _m_parent.get_default_door();

      if (door == UVM_BACKDOOR && (bkdr !is null || has_hdl_path())) {
	map = get_default_map();
	if (map is null) 
	  map = uvm_reg_map.backdoor();
      }
      else
	map = get_local_map(map);

      if (map is null) {
	XatomicX(false);		// SV version does not have this
	return;
      }
   
      // Remember what we think the value is before it gets updated
      if (check == UVM_CHECK)
	exp = get_mirrored_value();
    }

    uvm_reg_data_t v;
    XreadX(status, v, door, map, parent, prior, extension, fname, lineno);

    if (status == UVM_NOT_OK) {
      XatomicX(false);
      return;
    }

    if (check == UVM_CHECK) do_check(exp, v, map);

    XatomicX(false);
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.15
  // @uvm-ieee 1800.2-2020 auto 18.8.5.7
  bool predict (uvm_reg_data_t    value,
		uvm_reg_byte_en_t be =  -1,
		uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		uvm_door_e        door = uvm_door_e.UVM_FRONTDOOR,
		uvm_reg_map       map = null,
		string            fname = "",
		int               lineno = 0) {
    uvm_reg_item rw = new uvm_reg_item();
    synchronized(rw) {
      // rw.value[0] = value;
      rw.set_value(value, 0);
      rw.set_door(door);
      rw.set_map(map);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }
    do_predict(rw, kind, be);
    if (rw.get_status() == UVM_NOT_OK) return false;
    else return true;
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.4.16
  final bool is_busy() {
    synchronized(this) {
      return _m_is_busy;
    }
  }


  final void Xset_busyX(bool busy) {
    synchronized(this) {
      _m_is_busy = busy;
    }
  }

  // task
  void XreadX(out uvm_status_e      status,
	      out uvm_reg_data_t    value,
	      uvm_door_e            door,
	      uvm_reg_map           map,
	      uvm_sequence_base     parent = null,
	      int                   prior = -1,
	      uvm_object            extension = null,
	      string                fname = "",
	      int                   lineno = 0) {
   
    // create an abstract transaction for this operation
    uvm_reg_item rw;
    rw = uvm_reg_item.type_id.create("read_item", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_REG);
      rw.set_kind(UVM_READ);
      rw.set_value(uvm_reg_data_t(0), 0);
      rw.set_door(door);
      rw.set_map(map);
      rw.set_parent_sequence(parent);
      rw.set_priority(prior);
      rw.set_extension(extension);
      rw.set_fname(fname);
      rw.set_line(lineno);
    }
    do_read(rw);

      status = rw.get_status();
      value = rw.get_value(0);
  }

  // task
  void XatomicX(bool on) {
    Process m_reg_process = Process.self;

    if (on) {
      if (m_reg_process is m_process)
	return;
      m_atomic.wait();
      m_process = m_reg_process; 
    }
    else {
      // Maybe a key was put back in by a spurious call to reset()
      m_atomic.tryWait();
      m_atomic.post();
      m_process = null;
    }
  }

  bool Xcheck_accessX (uvm_reg_item rw,
		       out uvm_reg_map_info map_info) {
    synchronized(this) {

      if (rw.get_door() == UVM_DEFAULT_DOOR)
	rw.set_door(_m_parent.get_default_door());

      if (rw.get_door() == UVM_BACKDOOR) {
	if (get_backdoor() is null && !has_hdl_path()) {
	  uvm_warning("RegModel",
		      "No backdoor access available for register '" ~
		      get_full_name() ~ "' . Using frontdoor instead.");
	  rw.set_door(UVM_FRONTDOOR);
	}
	else if (rw.get_map() is null) {
	  uvm_reg_map  bkdr_map = get_default_map();
	  if (bkdr_map !is null)
	    rw.set_map(bkdr_map);
	  else
	    rw.set_map(uvm_reg_map.backdoor());
	}
      }

      uvm_reg_map tmp_map;
      if (rw.get_door() != UVM_BACKDOOR) {
	tmp_map = rw.get_map();
	rw.set_local_map(get_local_map(tmp_map));

	if (rw.get_local_map() is null) {
	  if (tmp_map is null)
	    uvm_error(get_type_name(), "Unable to physically access register with null map");
	  else
	    uvm_error(get_type_name(), 
		      "No transactor available to physically access register on map '" ~
		      tmp_map.get_full_name() ~ "'");
	  rw.set_status(UVM_NOT_OK);
	  return false;
	}

	uvm_reg_map tmp_local_map = rw.get_local_map();
	map_info = tmp_local_map.get_reg_map_info(this);

	if (map_info.frontdoor is null && map_info.unmapped) {
	  uvm_error("RegModel", "Register '" ~ get_full_name() ~
		    "' unmapped in map '" ~
		    (rw.get_map() is null)? tmp_local_map.get_full_name() :
		    tmp_map.get_full_name() ~
		    "' and does not have a user-defined frontdoor");
          rw.set_status(UVM_NOT_OK);
          return false;
	}

	if (tmp_map is null)
	  rw.set_map(tmp_local_map);
      }
      return true;
    }
  }

  bool Xis_locked_by_fieldX() {
    synchronized(this) {
      return _m_is_locked_by_field;
    }
  }
    
  // FIXME -- look for === and !==
  bool do_check(uvm_reg_data_t expected,
		uvm_reg_data_t actual,
		uvm_reg_map    map) {
    synchronized(this) {
      uvm_reg_data_t valid_bits_mask = 0; // elements 1 indicating bit we care about

      foreach(field; _m_fields) {
	string acc = field.get_access(map);
	acc = acc[0..2];
	if (! (field.get_compare() == UVM_NO_CHECK || acc == "WO")) {
	  valid_bits_mask |=
	    ((UVM_REG_DATA_1 << field.get_n_bits()) - 1) << field.get_lsb_pos();
	}
      }

      if ((actual & valid_bits_mask) is (expected & valid_bits_mask))
	return true;
   
      uvm_error("RegModel",
		format("Register \"%s\" value read from DUT (0x%x)" ~
		       " does not match mirrored value (0x%x) " ~
		       "(valid bit mask = 0x%x)",
		       get_full_name(), actual,
		       expected, valid_bits_mask));
                                     
      foreach(field; _m_fields) {
	string acc = field.get_access(map);
	acc = acc[0..2];
	if (!(field.get_compare() == UVM_NO_CHECK ||
	      acc == "WO")) {
	  uvm_reg_data_t mask  = ((UVM_REG_DATA_1 << field.get_n_bits())-1);
	  uvm_reg_data_t val   = actual   >> field.get_lsb_pos() & mask;
	  uvm_reg_data_t exp   = expected >> field.get_lsb_pos() & mask;

	  if (val !is exp) {
	    uvm_info("RegModel",
		     format("Field %s (%s[%0d:%0d]) mismatch read=(%0d)%0x mirrored=%(0d)%0x ",
			    field.get_name(), get_full_name(),
			    field.get_lsb_pos() + field.get_n_bits() - 1,
			    field.get_lsb_pos(),
			    field.get_n_bits(), val,
			    field.get_n_bits(), exp),
		     uvm_verbosity.UVM_NONE);
	  }
	}
      }
      return false;
    }
  }
       

  // task
  void do_write (uvm_reg_item rw) {

    uvm_reg_cb_iter  cbs = new uvm_reg_cb_iter(this);
    uvm_reg_map_info map_info;
    uvm_reg_data_t   value; 
    uvm_reg_map      tmp_local_map;

    synchronized(this) {
      _m_fname  = rw.get_fname();
      _m_lineno = rw.get_line();
    }
    
    if (! Xcheck_accessX(rw, map_info))
      return;

    XatomicX(true);

    m_write_in_progress = true;
 
    value = rw.get_value(0);
    value &= ((UVM_REG_DATA_1 << m_n_bits) - 1);
    rw.set_value(value, 0);

    rw.set_status(UVM_IS_OK);

    // PRE-WRITE CBS - FIELDS
    // begin : pre_write_callbacks
    uvm_reg_data_t  msk;

    foreach (field; get_fields()) {
      uvm_reg_field_cb_iter lcbs = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;
      int lsb = f.get_lsb_pos();
      msk = ((UVM_REG_DATA_1 << f.get_n_bits()) - 1) << lsb;
      // rw.value[0] = (value & msk) >> lsb;
      rw.set_value((value & msk) >> lsb, 0);
      f.pre_write(rw);
      for (uvm_reg_cbs cb=lcbs.first(); cb !is null; cb=lcbs.next()) {
	rw.set_element(f);
	rw.set_element_kind(UVM_FIELD);
	cb.pre_write(rw);
      }
      value = (value & ~msk) | (rw.get_value(0) << lsb);
    }

    rw.set_element(this);
    rw.set_element_kind(UVM_REG);
    // rw.value[0] = value;
    rw.set_value(value, 0);

    // PRE-WRITE CBS - REG
    pre_write(rw);
    for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
      cb.pre_write(rw);

    if (rw.get_status() != UVM_IS_OK) {
      m_write_in_progress = false;

      XatomicX(false);
         
      return;
    }
         
    // EXECUTE WRITE...
    switch(rw.get_door()) {
      
      // ...VIA USER BACKDOOR
    case UVM_BACKDOOR:
      {
	uvm_reg_data_t final_val;
	uvm_reg_backdoor bkdr = get_backdoor();

	if (rw.get_map() !is null)
	  rw.set_local_map(rw.map);
	else 
	  rw.set_local_map(get_default_map());

	value = rw.get_value(0);

	// Mimick the final value after a physical read
	rw.set_kind(UVM_READ);
	if (bkdr !is null)
	  bkdr.read(rw);
	else
	  backdoor_read(rw);

	if (rw.get_status() == UVM_NOT_OK) {
	  m_write_in_progress = false;
	  return;
	}

	foreach (i, field; get_fields()) {
	  uvm_reg_data_t field_val;
	  int lsb = field.get_lsb_pos();
	  int sz  = field.get_n_bits();
	  field_val = field.XpredictX((rw.get_value(0) >> lsb) & ((UVM_REG_DATA_1 << sz) - 1),
				      (value >> lsb) & ((UVM_REG_DATA_1 << sz) - 1),
				      rw.get_local_map);
	  final_val |= field_val << lsb;
	}
	rw.set_kind(UVM_WRITE);
	rw.set_value(final_val, 0);
	string rights = get_rights(rw.get_local_map());
        if (rights == "RW" || rights == "WO") {
          if (bkdr !is null)
	    bkdr.write(rw);
          else
	    backdoor_write(rw);

          do_predict(rw, UVM_PREDICT_WRITE);
	}
	else {
	  rw.set_status(UVM_NOT_OK);
	}
      }
      break;
    case UVM_FRONTDOOR:
      {

	tmp_local_map = rw.get_local_map();
	uvm_reg_map system_map = tmp_local_map.get_root_map();

	m_is_busy = true;

	// ...VIA USER FRONTDOOR
	if (map_info.frontdoor !is null) {
	  uvm_reg_frontdoor fd = map_info.frontdoor;
	  fd.rw_info = rw;
	  if (fd.sequencer is null)
	    fd.sequencer = system_map.get_sequencer();
	  fd.start(fd.sequencer, rw.get_parent_sequence());
	}

	// ...VIA BUILT-IN FRONTDOOR
	else {
	  tmp_local_map.do_write(rw);
	}

	m_is_busy = false;

	if (system_map.get_auto_predict()) {
	  uvm_status_e status;
	  if (rw.get_status() != UVM_NOT_OK) {
	    sample(value, uvm_reg_data_t(-1), false, rw.get_map());
	    m_parent.XsampleX(map_info.offset, false, rw.get_map());
	  }

	  status = rw.get_status(); // do_predict will override rw.status, so we save it here
	  do_predict(rw, UVM_PREDICT_WRITE);
	  rw.set_status(status);
	}
      }
      break;
    default: break;
    }

    value = rw.get_value(0);

    // POST-WRITE CBS - REG
    for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
      cb.post_write(rw);
    post_write(rw);

    // POST-WRITE CBS - FIELDS
    foreach (field; get_fields()) {
      uvm_reg_field_cb_iter lcbs = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;
      
      rw.set_element(f);
      rw.set_element_kind(UVM_FIELD);
      rw.set_value((value >> f.get_lsb_pos()) & ((UVM_REG_DATA_1 << f.get_n_bits()) - 1), 0);
      
      for (uvm_reg_cbs cb=lcbs.first(); cb !is null; cb=lcbs.next())
	cb.post_write(rw);
      f.post_write(rw);
    }
   
    rw.set_value(value, 0);
    rw.set_element(this);
    rw.set_element_kind(UVM_REG);

    // REPORT
    if (uvm_report_enabled(uvm_verbosity.UVM_HIGH, uvm_severity.UVM_INFO, "RegModel")) {
      string path_s;
      if (rw.get_door() == UVM_FRONTDOOR) {
	uvm_reg_map tmp_map = rw.get_map();
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ tmp_map.get_full_name();
      }
      else
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";
      string value_s = format("=0x%0x",rw.get_value(0));

      uvm_report_info("RegModel", "Wrote register via " ~ path_s ~ ": " ~
		      get_full_name() ~ value_s, uvm_verbosity.UVM_HIGH);
    }

    m_write_in_progress = false;

    XatomicX(false);

  }

  // task
  void do_read(uvm_reg_item rw) {

    uvm_reg_cb_iter  cbs = new uvm_reg_cb_iter(this);
    uvm_reg_map_info map_info;
    uvm_reg_data_t   value;
    uvm_reg_data_t   exp;

    synchronized(this) {
      _m_fname   = rw.get_fname();
      _m_lineno  = rw.get_line();
    
      if (!Xcheck_accessX(rw,map_info))
	return;

      _m_read_in_progress = true;

    }

    rw.set_status(UVM_IS_OK);

    // PRE-READ CBS - FIELDS
    foreach (field; get_fields()) {
      uvm_reg_field_cb_iter cbsi = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;
      rw.set_element(f);
      rw.set_element_kind(UVM_FIELD);
      field.pre_read(rw);
      for (uvm_reg_cbs cb=cbsi.first(); cb !is null; cb=cbsi.next())
	cb.pre_read(rw);
    }

    rw.set_element(this);
    rw.set_element_kind(UVM_REG);

    // PRE-READ CBS - REG
    pre_read(rw);
    for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
      cb.pre_read(rw);

    if (rw.get_status() != UVM_IS_OK) {
      m_read_in_progress = false;
      return;
    }
         
    // EXECUTE READ...
    switch(rw.get_door()) {
      // ...VIA USER BACKDOOR
    case UVM_BACKDOOR: {
      uvm_reg_backdoor bkdr = get_backdoor();

      if (rw.get_map() !is null)
	rw.set_local_map(rw.map);
      else
	rw.set_local_map(get_default_map());  
         
      uvm_reg_map map = rw.get_local_map();
          
      if (map.get_check_on_read()) exp = get_mirrored_value();
      string rights = get_rights(rw.get_local_map());
      if (rights == "RW" || rights == "RO") {
	if (bkdr !is null)
	  bkdr.read(rw);
	else
	  backdoor_read(rw);
      }
      else {
	rw.set_status(UVM_NOT_OK);
      }
         
      value = rw.get_value(0);

      // Need to clear RC fields, set RS fields and mask WO fields
      if (rw.get_status() != UVM_NOT_OK) {
	uvm_reg_data_t wo_mask;

	foreach (i, field; get_fields()) {
	  // string acc = field.get_access(uvm_reg_map.backdoor());
	  string acc = field.get_access(rw.get_local_map());
	  if (acc == "RC" ||
	      acc == "WRC" ||
	      acc == "WSRC" ||
	      acc == "W1SRC" ||
	      acc == "W0SRC") {
	    value &= ~(((UVM_REG_DATA_1 << field.get_n_bits()) - 1)
		       << field.get_lsb_pos());
	  }
	  else if (acc == "RS" ||
		   acc == "WRS" ||
		   acc == "WCRS" ||
		   acc == "W1CRS" ||
		   acc == "W0CRS") {
	    value |= (((UVM_REG_DATA_1 << field.get_n_bits()) - 1)
		      << field.get_lsb_pos());
	  }
	  else if (acc == "WO" ||
		   acc == "WOC" ||
		   acc == "WOS" ||
		   acc == "WO1") {
	    wo_mask |= ((UVM_REG_DATA_1 << field.get_n_bits()) - 1)
	      << field.get_lsb_pos();
	  }
	}
	string rights_ = get_rights(rw.get_local_map());
	if (rights_ == "RW" || rights_ == "RO") {
	  if (value != rw.get_value(0)) {
	      
	    uvm_reg_data_t saved = rw.get_value(0);
	    rw.set_value(value, 0);
	    if (bkdr !is null)
	      bkdr.write(rw);
	    else
	      backdoor_write(rw);
	    rw.set_value(uvm_reg_data_t(0), saved);
	  }

	  uvm_reg_data_t saved = rw.get_value(0);
	  saved &= ~wo_mask;
	  rw.set_value(saved, 0);

	  if (map.get_check_on_read() &&
	      rw.get_status() != UVM_NOT_OK) {
	    do_check(exp, rw.get_value(0), map);
	  }
       
	  do_predict(rw, UVM_PREDICT_READ);
	}
	else {
	  rw.set_status(UVM_NOT_OK);
	}
      }
    }
      break;

    case UVM_FRONTDOOR: {
      uvm_reg_map local_map = rw.get_local_map();
      uvm_reg_map system_map = local_map.get_root_map();
      m_is_busy = true;
      if (rw.local_map.get_check_on_read()) exp = get_mirrored_value();
   
      // ...VIA USER FRONTDOOR
      if (map_info.frontdoor !is null) {
	uvm_reg_frontdoor fd = map_info.frontdoor;
	fd.rw_info = rw;
	if (fd.sequencer is null)
	  fd.sequencer = system_map.get_sequencer();
	fd.start(fd.sequencer, rw.get_parent_sequence());
      }

      // ...VIA BUILT-IN FRONTDOOR
      else {
	local_map.do_read(rw);
      }

      m_is_busy = false;

      if (system_map.get_auto_predict()) {
	if (rw.local_map.get_check_on_read() &&
	    rw.get_status() != UVM_NOT_OK) {
	  do_check(exp, rw.get_value(0), system_map);
	}

	if (rw.get_status() != UVM_NOT_OK) {
	  sample(rw.get_value(0), uvm_reg_data_t(-1), true, rw.get_map());
	  m_parent.XsampleX(map_info.offset, 1, rw.get_map());
	}

	uvm_status_e status = rw.get_status(); // do_predict will override rw.status, so we save it here
	do_predict(rw, UVM_PREDICT_READ);
	rw.set_status(status);
      }
    }
      break;
    default: break;
    }

    // POST-READ CBS - REG
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
      cb.post_read(rw);

    post_read(rw);

    value = rw.get_value(0); // preserve 

    // POST-READ CBS - FIELDS
    foreach (field; get_fields()) {
      uvm_reg_field_cb_iter cbsi = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;

      rw.set_element(f);
      rw.set_element_kind(UVM_FIELD);
      rw.set_value((value >> f.get_lsb_pos()) & ((UVM_REG_DATA_1 << f.get_n_bits()) - 1), 0);

      int top = (f.get_n_bits()+f.get_lsb_pos());      
      
      // Filter to remove field from value before ORing result of field CB/post_read back in
      uvm_reg_data_t value_field_filter = -1;     
      for (int i = f.get_lsb_pos(); i < top; i++) {
         value_field_filter[i] = 0;
      }
   
      for (uvm_reg_cbs cb=cbsi.first(); cb !is null; cb=cbsi.next())
	cb.post_read(rw);
      f.post_read(rw);

      
      // Recreate value based on field value and field filtered version of value
      value = (value & value_field_filter) |
	(~value_field_filter & (rw.get_value(0) << f.get_lsb_pos()));
      
    }

    rw.set_value(value, 0);
   
    rw.set_element(this);
    rw.set_element_kind(UVM_REG);

    // REPORT
    if (uvm_report_enabled(uvm_verbosity.UVM_HIGH, uvm_severity.UVM_INFO, "RegModel"))  {
      string path_s,value_s;
      if (rw.get_door() == UVM_FRONTDOOR) {
	uvm_reg_map map = rw.get_map();
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ map.get_full_name();
      }
      else
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";

      value_s = format("=0x%0x", rw.get_value(0));

      uvm_report_info("RegModel", "Read  register via " ~ path_s ~ ": " ~
		      get_full_name() ~ value_s, uvm_verbosity.UVM_HIGH);
    }
    m_read_in_progress = false;
  }

  void do_predict(uvm_reg_item      rw,
		  uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		  uvm_reg_byte_en_t be =  -1) {
    synchronized(this) {

      uvm_reg_data_t reg_value = rw.get_value(0);
      _m_fname = rw.get_fname();
      _m_lineno = rw.get_line();

      if (rw.get_status() == UVM_IS_OK)

	if (_m_is_busy && kind == UVM_PREDICT_DIRECT) {
	  uvm_warning("RegModel", "Trying to predict value of register '" ~
		      get_full_name() ~ "' while it is being accessed");
	  rw.set_status(UVM_NOT_OK);
	  return;
	}
   
      foreach (field; _m_fields) {
	rw.set_value((reg_value >> field.get_lsb_pos()) &
		     ((UVM_REG_DATA_1 << field.get_n_bits()) - 1), 0);
	field.do_predict(rw, kind, be >> (field.get_lsb_pos() / 8));
      }

      rw.set_value(reg_value, 0);
    }
  }


  //-----------------
  // Group -- NODOCS -- Frontdoor
  //-----------------


  // @uvm-ieee 1800.2-2020 auto 18.4.5.2
  void set_frontdoor(uvm_reg_frontdoor ftdr,
		     uvm_reg_map       map = null,
		     string            fname = "",
		     int               lineno = 0) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      ftdr.fname = _m_fname;
      ftdr.lineno = _m_lineno;
      map = get_local_map(map);
      if (map is null)
	return;
      map_info = map.get_reg_map_info(this);
      if (map_info is null)
	map.add_reg(this, -1, "RW", 1, ftdr);
      else {
	map_info.frontdoor = ftdr;
      }
    }
  }
    

  // @uvm-ieee 1800.2-2020 auto 18.4.5.1
  uvm_reg_frontdoor get_frontdoor(uvm_reg_map map = null) {
    synchronized(this) {
      map = get_local_map(map);
      if (map is null)
	return null;
      uvm_reg_map_info map_info = map.get_reg_map_info(this);
      return map_info.frontdoor;
    }
  }


  //----------------
  // Group -- NODOCS -- Backdoor
  //----------------


  // @uvm-ieee 1800.2-2020 auto 18.4.6.2
  void set_backdoor(uvm_reg_backdoor bkdr,
		    string           fname = "",
		    int              lineno = 0) {
    synchronized(this) {
      bkdr.fname = fname;
      bkdr.lineno = lineno;
      if (_m_backdoor !is null &&
	  _m_backdoor.has_update_threads()) {
	uvm_warning("RegModel", "Previous register backdoor still has update threads running. Backdoors with active mirroring should only be set before simulation starts.");
      }
      _m_backdoor = bkdr;
    }
  }
   

  // @uvm-ieee 1800.2-2020 auto 18.4.6.1
  uvm_reg_backdoor get_backdoor(bool inherited = true) {
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


  // @uvm-ieee 1800.2-2020 auto 18.4.6.3
  void clear_hdl_path(string kind = "RTL") {
    synchronized(this) {
      if (kind == "ALL") {
	_m_hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))("hdl_paths");
	return;
      }

      if (kind == "") {
	if (_m_regfile_parent !is null)
	  kind = _m_regfile_parent.get_default_hdl_path();
	else
	  kind = _m_parent.get_default_hdl_path();
      }
      if (!_m_hdl_paths_pool.exists(kind)) {
	uvm_warning("RegModel", "Unknown HDL Abstraction '" ~ kind ~ "'");
	return;
      }

      _m_hdl_paths_pool.remove(kind);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.6.4
  void add_hdl_path(uvm_hdl_path_slice[] slices,
		    string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) doors = _m_hdl_paths_pool.get(kind);
      uvm_hdl_path_concat concat = new uvm_hdl_path_concat();

      concat.set(slices);
      doors.push_back(concat);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.6.5
  void add_hdl_path_slice(string name,
			  int offset,
			  int size,
			  bool first = false,
			  string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) doors = _m_hdl_paths_pool.get(kind);
      uvm_hdl_path_concat concat;
    
      if (first || doors.size() == 0) {
	concat = new uvm_hdl_path_concat();
	doors.push_back(concat);
      }
      else
	concat = doors.get(doors.length-1);

      concat.add_path(name, offset, size);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.6.6
  bool  has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "") {
	if (_m_regfile_parent !is null)
	  kind = _m_regfile_parent.get_default_hdl_path();
	else
	  kind = _m_parent.get_default_hdl_path();
      }

      if (kind in _m_hdl_paths_pool) return true;
      else return false;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.6.7
  void get_hdl_path(ref uvm_hdl_path_concat[] doors,
		    string kind = "") {
    synchronized(this) {

      if (kind == "") {
	if (_m_regfile_parent !is null)
	  kind = _m_regfile_parent.get_default_hdl_path();
	else
	  kind = _m_parent.get_default_hdl_path();
      }

      if (! has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Register does not have hdl path defined for abstraction '" ~
		  kind ~ "'");
	return;
      }

      uvm_queue!(uvm_hdl_path_concat) hdl_paths = _m_hdl_paths_pool.get(kind);

      for (int i=0; i<hdl_paths.length; i++) {
	doors ~= hdl_paths.get(i);
      }
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.6.8
  void get_hdl_path_kinds (out string[] kinds) {
    synchronized(this) {
      foreach (kind, unused; _m_hdl_paths_pool) {
	kinds ~= kind;
      }
      return;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.6.9
  void get_full_hdl_path(ref uvm_hdl_path_concat[] doors,
			 string kind = "",
			 string separator = ".") {
    synchronized(this) {
      if (kind == "") {
	if (_m_regfile_parent !is null)
	  kind = _m_regfile_parent.get_default_hdl_path();
	else
	  kind = _m_parent.get_default_hdl_path();
      }
   
      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Register " ~ get_full_name() ~
		  " does not have hdl path defined for abstraction '" ~ kind ~ "'");
	return;
      }

      uvm_queue!(uvm_hdl_path_concat) hdl_paths = _m_hdl_paths_pool.get(kind);
      string[] parent_paths;

      if (_m_regfile_parent !is null)
	_m_regfile_parent.get_full_hdl_path(parent_paths, kind, separator);
      else
	_m_parent.get_full_hdl_path(parent_paths, kind, separator);

      for (int i=0; i<hdl_paths.length; i++) {
	uvm_hdl_path_concat hdl_concat = hdl_paths.get(i);

	foreach (j, parent_path; parent_paths) {
	  uvm_hdl_path_concat t = new uvm_hdl_path_concat;

	  foreach (hdl_slice; hdl_concat.slices) {
	    if (hdl_slice.path == "")
	      t.add_path(parent_path);
	    else
	      t.add_path(parent_path ~ separator ~ hdl_slice.path,
			 hdl_slice.offset, hdl_slice.size);
	  }
	  doors ~= t;
	}
      }
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.6.10
  // task
  void backdoor_read (uvm_reg_item rw) {
    rw.set_status(backdoor_read_func(rw));
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.6.11
  // task
  void backdoor_write(uvm_reg_item rw) {
    uvm_hdl_path_concat[] doors;
    bool ok = true;
    get_full_hdl_path(doors, rw.get_bd_kind());
    foreach (door; doors) {
      uvm_hdl_path_concat hdl_concat = door;
      foreach (hdl_slice; hdl_concat.slices) {
	uvm_info("RegMem", format("backdoor_write to %s", hdl_slice.path),
		 uvm_verbosity.UVM_DEBUG);

	if (hdl_slice.offset < 0) {
	  ok &= uvm_hdl_deposit(hdl_slice.path, rw.get_value(0));
	  continue;
	}
	uvm_reg_data_t slice = rw.get_value(0) >> hdl_slice.offset;
	slice &= (UVM_REG_DATA_1 << hdl_slice.size) - 1;
	ok &= uvm_hdl_deposit(hdl_slice.path, slice);
      }
    }
    rw.set_status(ok ? UVM_IS_OK : UVM_NOT_OK);
  }


  uvm_status_e backdoor_read_func(uvm_reg_item rw) {
    synchronized(this) {
      uvm_hdl_path_concat[] doors;
      bool ok = true;
      get_full_hdl_path(doors, rw.get_bd_kind());
      foreach (i, door; doors) {
	uvm_hdl_path_concat hdl_concat = door;
	uvm_reg_data_t val = 0;
	foreach (hdl_slice; hdl_concat.slices) {
	  uvm_info("RegMem", format("backdoor_read from %s", hdl_slice.path),
		   uvm_verbosity.UVM_DEBUG);

	  if (hdl_slice.offset < 0) {
	    ok &= uvm_hdl_read(hdl_slice.path,val);
	    continue;
	  }
	  uvm_reg_data_t slice;
	  int k = hdl_slice.offset;
           
	  ok &= uvm_hdl_read(hdl_slice.path, slice);
      
	  // for(size_t idx=0; idx != hdl_slice.size; ++idx) {
	  //   val[k++] = slice[0];
	  //   slice >>= 1;
	  // }
	  uvm_reg_data_t mask = 1;
	  mask <<= hdl_slice.size;
	  mask -= 1;
	  mask <<= hdl_slice.offset;

	  val &= ~mask;

	  val |= (slice << hdl_slice.offset) & mask;
	}

	val &= (UVM_REG_DATA_1 << _m_n_bits) - 1;

	if (i == 0)
	  rw.set_value(val, 0);
	
	if (val !is rw.get_value(0)) {
	  uvm_error("RegModel",
		    format("Backdoor read of register %s with " ~
			   "multiple HDL copies: values are not" ~
			   " the same: %0x at path '%s', and %0x" ~
			   " at path '%s'. Returning first value.",
			   get_full_name(),
			   rw.get_value(0), uvm_hdl_concat2string(doors[0]),
			   val, uvm_hdl_concat2string(doors[i]))); 
	  return UVM_NOT_OK;
	}
	
	uvm_info("RegMem", 
		 format("returned backdoor value 0x%0x", rw.get_value(0)),
		 uvm_verbosity.UVM_DEBUG);
      
      }

      rw.set_status(ok ? UVM_IS_OK : UVM_NOT_OK);
      return rw.get_status();
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.6.12
  // task
  void backdoor_watch() { }

  //----------------
  // Group -- NODOCS -- Coverage
  //----------------


  // @uvm-ieee 1800.2-2020 auto 18.4.7.1
  void include_coverage(string reg_scope,
			uvm_reg_cvr_t models,
			uvm_object accessor = null) {
    synchronized(this) {
      uvm_reg_cvr_rsrc_db.set("uvm_reg." ~ reg_scope,
			      "include_coverage",
			      models, accessor);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.7.2
  uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      uvm_reg_cvr_t retval = uvm_coverage_model_e.UVM_NO_COVERAGE;
      uvm_reg_cvr_rsrc_db.read_by_name("uvm_reg." ~ get_full_name(),
				       "include_coverage",
				       retval, this);
      return retval & models;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.7.3
  void add_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      _m_has_cover |= models;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.7.4
  bool has_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      return ((_m_has_cover & models) == models);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.7.6
  uvm_reg_cvr_t set_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      if (is_on == cast(uvm_reg_cvr_t) uvm_coverage_model_e.UVM_NO_COVERAGE) {
	_m_cover_on = is_on;
	return uvm_reg_cvr_t(_m_cover_on);
      }

      _m_cover_on = _m_has_cover & is_on;

      return uvm_reg_cvr_t(_m_cover_on);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.4.7.5
  bool get_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      if (has_coverage(is_on) == 0)
	return false;
      return ((_m_cover_on & is_on) == is_on);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.4.7.7
  protected void sample(uvm_reg_data_t  data,
			uvm_reg_data_t  byte_en,
			bool             is_read,
			uvm_reg_map     map) { }


  // @uvm-ieee 1800.2-2020 auto 18.4.7.8
  void sample_values() { }

  void XsampleX(uvm_reg_data_t  data,
		uvm_reg_data_t  byte_en,
		bool            is_read,
		uvm_reg_map     map) {
    synchronized(this) {
      sample(data, byte_en, is_read, map);
    }
  }


  //-----------------
  // Group -- NODOCS -- Callbacks
  //-----------------
  mixin uvm_register_cb!uvm_reg_cbs;
   

  // @uvm-ieee 1800.2-2020 auto 18.4.8.1
  // task
  void pre_write(uvm_reg_item rw) {}


  // @uvm-ieee 1800.2-2020 auto 18.4.8.2
  // task
  void post_write(uvm_reg_item rw) {}


  // @uvm-ieee 1800.2-2020 auto 18.4.8.3
  // task
  void pre_read(uvm_reg_item rw) {}


  // @uvm-ieee 1800.2-2020 auto 18.4.8.4
  // task
  void post_read(uvm_reg_item rw) {}


  override void do_print (uvm_printer printer) {
    synchronized(this) {
      uvm_reg_field[] fields;
      super.do_print(printer);
      get_fields(fields);
      foreach(field; fields) {
	printer.print_generic(field.get_name(), field.get_type_name(), -2, field.convert2string());
      }
    }
  }


  override string convert2string() {
    synchronized(this) {
      string res_str;

      string prefix;

      string retval = format("Register %s -- %0d bytes, mirror value:0x%x",
			     get_full_name(), get_n_bytes(),get());

      if (_m_maps.length == 0)
	retval ~= "  (unmapped)\n";
      else
	retval ~= "\n";

      foreach (map, unused; _m_maps) {
	uvm_reg_map parent_map = map;
	while (parent_map !is null) {
	  uvm_reg_map this_map = parent_map;
	  parent_map = this_map.get_parent_map();
	  uint offset = cast(int) (parent_map is null ?
			      this_map.get_base_addr(UVM_NO_HIER) :
			      parent_map.get_submap_offset(this_map));
	  prefix ~= "  ";
	  uvm_endianness_e e = this_map.get_endian();
	  retval ~= format("%sMapped in '%s' -- %d bytes, %s," ~
			   " offset 0x%0x\n", prefix,
			   this_map.get_full_name(),
			   this_map.get_n_bytes(), e, offset);
	}
      }
      prefix = "  ";
      foreach (field; _m_fields) {
	retval ~= "\n" ~ field.convert2string();
      }

      if (_m_read_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format("%s:%0d ",_m_fname, _m_lineno);
	retval ~= "\n" ~ res_str ~ "currently executing read method"; 
      }
      if ( _m_write_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format("%s:%0d ",_m_fname, _m_lineno);
	retval ~= "\n" ~ res_str ~ "currently executing write method"; 
      }
      return retval;
    }
  }

  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel registers cannot be cloned");
    return null;
  }

  override void do_copy(uvm_object rhs) {
    uvm_fatal("RegModel","RegModel registers cannot be copied");
  }

  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel registers cannot be compared");
    return 0;
  }

  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel registers cannot be packed");
  }

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel registers cannot be unpacked");
  }

}
