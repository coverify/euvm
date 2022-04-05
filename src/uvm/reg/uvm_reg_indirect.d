//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
// Copyright 2010-2012 Synopsys, Inc.
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

// typedef class uvm_reg_indirect_ftdr_seq;

//-----------------------------------------------------------------
// CLASS: uvm_reg_indirect_data
// Indirect data access abstraction class
//
// Models the behavior of a register used to indirectly access
// a register array, indexed by a second ~address~ register.
//
// This class should not be instantiated directly.
// A type-specific class extension should be used to
// provide a factory-enabled constructor and specify the
// ~n_bits~ and coverage models.
//-----------------------------------------------------------------

import uvm.meta.misc;

import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_file: uvm_reg_file;
import uvm.reg.uvm_reg_item: uvm_reg_item;

import uvm.reg.uvm_reg_sequence: uvm_reg_frontdoor;
import uvm.seq.uvm_sequence_base: uvm_sequence_base;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_globals: uvm_warning, uvm_error;
import uvm.base.uvm_resource_db: uvm_resource_db;

import uvm.meta.misc;

import std.string: format;

// @uvm-ieee 1800.2-2020 auto 18.7.1
class uvm_reg_indirect_data: uvm_reg
{
  mixin uvm_sync;
  
  @uvm_protected_sync
  protected uvm_reg   _m_idx;
  @uvm_protected_sync
  protected uvm_reg[] _m_tbl;

  // @uvm-ieee 1800.2-2020 auto 18.7.2.1
  this(string name, uint n_bits, int has_cover) {
    super(name, n_bits, has_cover);
  }

  void build() { }

  // @uvm-ieee 1800.2-2020 auto 18.7.2.2
  void configure (uvm_reg idx, uvm_reg[] reg_a,
		  uvm_reg_block blk_parent,
		  uvm_reg_file regfile_parent = null) {
    synchronized(this) {
      super.configure(blk_parent, regfile_parent, "");
      _m_idx = idx;
      _m_tbl = reg_a;

      // Not testable using pre-defined sequences
      uvm_resource_db!(bool).set("REG::" ~ get_full_name(),
				 "NO_REG_TESTS", true);

      // Add a frontdoor to each indirectly-accessed register
      // for every address map this register is in.
      foreach (map; get_maps()) {
	add_frontdoors(map);
      }
    }
  }
   
  override void add_map(uvm_reg_map map) {
    synchronized(this) {
      super.add_map(map);
      add_frontdoors(map);
    }
  }
   
  // local function void add_frontdoors(uvm_reg_map map);
  void add_frontdoors(uvm_reg_map map) {
    synchronized(this) {
      foreach (i, row; _m_tbl) {
	if (row is null) {
	  uvm_error(get_full_name(),
		    format("Indirect register #%0d is NULL", i));
	  continue;
	}
	uvm_reg_indirect_ftdr_seq fd =
	  new uvm_reg_indirect_ftdr_seq(_m_idx, cast(uint) i, this);
	if (row.is_in_map(map)) {
	  row.set_frontdoor(fd, map);
	}
	else {
	  map.add_reg(row, -1, "RW", true, fd);
	}
      }
    }
  }
   
  override void do_predict (uvm_reg_item      rw,
			    uvm_predict_e     kind = UVM_PREDICT_DIRECT,
			    uvm_reg_byte_en_t be = -1) {
    synchronized(this) {
      if (_m_idx.get() >= _m_tbl.length) {
	uvm_error(get_full_name(),
		  format("Address register %s has a value" ~
			 " (%0d) greater than the maximum" ~
			 " indirect register array size (%0d)",
			 _m_idx.get_full_name(), _m_idx.get(), _m_tbl.length));
	rw.set_status(UVM_NOT_OK);
	return;
      }

      //NOTE limit to 2**32 registers
      auto idx = _m_idx.get();
      _m_tbl[idx].do_predict(rw, kind, be);
    }
  }

  override uvm_reg_map get_local_map(uvm_reg_map map) {
    synchronized(this) {
      return  _m_idx.get_local_map(map);
    }
  }

  //
  // Just for good measure, to catch and short-circuit non-sensical uses
  //
  override void add_field  (uvm_reg_field field) {
    uvm_error(get_full_name(),
	      "Cannot add field to an indirect data access register");
  }

  override void set (uvm_reg_data_t  value,
		     string          fname = "",
		     int             lineno = 0) {
    uvm_error(get_full_name(), "Cannot set() an indirect data access register");
  }
   
  override uvm_reg_data_t  get(string  fname = "",
			       int     lineno = 0) {
    uvm_error(get_full_name(), "Cannot get() an indirect data access register");
    return uvm_reg_data_t(0);
  }
   
  uvm_reg get_indirect_reg(string  fname = "",
			   int     lineno = 0) {
    synchronized(this) {
      auto idx = _m_idx.get_mirrored_value();
      return(_m_tbl[idx]);
    }
  }

  override bool needs_update() {
    return false;
  }

  // task
  override void write(out uvm_status_e  status,
		      uvm_reg_data_t    value,
		      uvm_door_e        door = uvm_door_e.UVM_DEFAULT_DOOR,
		      uvm_reg_map       map = null,
		      uvm_sequence_base parent = null,
		      int               prior = -1,
		      uvm_object        extension = null,
		      string            fname = "",
		      int               lineno = 0) {
    if (door == UVM_DEFAULT_DOOR) {
      uvm_reg_block blk = get_parent();
      door = blk.get_default_door();
    }
      
    if (door == UVM_BACKDOOR) {
      uvm_warning(get_full_name(),
		  "Cannot backdoor-write an indirect data access" ~
		  " register. Switching to frontdoor.");
      door = UVM_FRONTDOOR;
    }

    // Can't simply call super.write() because it'll call set()
    uvm_reg_item rw;

    XatomicX(1);

    rw = uvm_reg_item.type_id.create("write_item", null, get_full_name());

    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_REG);
      rw.set_kind(UVM_WRITE);
      rw.set_value(value, 0);
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

    XatomicX(0);
  }

  
  // task
  override void read(out uvm_status_e      status,
		     out uvm_reg_data_t    value,
		     uvm_door_e        door = UVM_DEFAULT_DOOR,
		     uvm_reg_map       map = null,
		     uvm_sequence_base parent = null,
		     int               prior = -1,
		     uvm_object        extension = null,
		     string            fname = "",
		     int               lineno = 0) {

    if (door == UVM_DEFAULT_DOOR) {
      uvm_reg_block blk = get_parent();
      door = blk.get_default_door();
    }
      
    if (door == UVM_BACKDOOR) {
      uvm_warning(get_full_name(),
		  "Cannot backdoor-read an indirect data access" ~
		  " register. Switching to frontdoor.");
      door = UVM_FRONTDOOR;
    }
      
    super.read(status, value, door, map, parent, prior, extension, fname, lineno);
  }

  // task
  override void poke(out uvm_status_e      status,
		     uvm_reg_data_t    value,
		     string            kind = "",
		     uvm_sequence_base parent = null,
		     uvm_object        extension = null,
		     string            fname = "",
		     int               lineno = 0) {
    uvm_error(get_full_name(), "Cannot poke() an indirect data access register");
    status = UVM_NOT_OK;
  }

  // task
  override void peek(out uvm_status_e      status,
		     out uvm_reg_data_t    value,
		     string            kind = "",
		     uvm_sequence_base parent = null,
		     uvm_object        extension = null,
		     string            fname = "",
		     int               lineno = 0) {
    uvm_error(get_full_name(), "Cannot peek() an indirect data access register");
    status = UVM_NOT_OK;
  }

  // task
  override void update(out uvm_status_e      status,
		       uvm_door_e        door = UVM_DEFAULT_DOOR,
		       uvm_reg_map       map = null,
		       uvm_sequence_base parent = null,
		       int               prior = -1,
		       uvm_object        extension = null,
		       string            fname = "",
		       int               lineno = 0) {
    status = UVM_IS_OK;
  }
   
  // task
  override void mirror(out uvm_status_e      status,
		       uvm_check_e        check  = UVM_NO_CHECK,
		       uvm_door_e         door = UVM_DEFAULT_DOOR,
		       uvm_reg_map        map = null,
		       uvm_sequence_base  parent = null,
		       int                prior = -1,
		       uvm_object        extension = null,
		       string             fname = "",
		       int                lineno = 0) {
    status = UVM_IS_OK;
  }
   
}

class uvm_reg_indirect_ftdr_seq: uvm_reg_frontdoor
{
  mixin uvm_sync;
  
  @uvm_immutable_sync
  private uvm_reg _m_addr_reg;
  @uvm_immutable_sync
  private uvm_reg _m_data_reg;
  @uvm_immutable_sync
  private int     _m_idx;
   
  this(uvm_reg addr_reg, int idx, uvm_reg data_reg) {
    synchronized(this) {
      super("uvm_reg_indirect_ftdr_seq");
      _m_addr_reg = addr_reg;
      _m_idx      = idx;
      _m_data_reg = data_reg;
    }
  }

  // task
  override void body() {

    // $cast(rw,rw_info.clone());
    uvm_reg_item rw = cast(uvm_reg_item) rw_info.clone;
      
    synchronized(rw) {
      rw.set_element(_m_addr_reg);
      rw.set_kind(UVM_WRITE);
      rw.set_value(cast(uvm_reg_data_t) _m_idx, 0);
    }

    m_addr_reg.XatomicX(1);
    m_data_reg.XatomicX(1);
      
    m_addr_reg.do_write(rw);

    if (rw.get_status() == UVM_NOT_OK) {
      return;
    }

    // $cast(rw,rw_info.clone());
    rw = cast(uvm_reg_item) rw_info.clone;

    rw.set_element(_m_data_reg);

    if (rw_info.get_kind() == UVM_WRITE) {
      m_data_reg.do_write(rw);
    }
    else {
      m_data_reg.do_read(rw);
      rw_info.set_value(rw.get_value[0], 0);
    }

    m_addr_reg.XatomicX(0);
    m_data_reg.XatomicX(0);
      
    rw_info.set_status(rw.get_status());
  }
}
