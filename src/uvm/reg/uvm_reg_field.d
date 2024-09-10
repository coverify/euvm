//
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2012 Accellera Systems Initiative
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2020 Intel Corporation
// Copyright 2020 Marvell International Ltd.
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2018 Qualcomm, Inc.
// Copyright 2012-2014 Semifore
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
module uvm.reg.uvm_reg_field;

import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_adapter: uvm_reg_adapter;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_cbs: uvm_reg_cbs, uvm_reg_field_cb_iter;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg_map: uvm_reg_map, uvm_reg_map_info;

import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_defines;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_comparer: uvm_comparer;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_callback: uvm_register_cb;
import uvm.base.uvm_globals: uvm_fatal, uvm_error, uvm_warning,
  uvm_info;
import uvm.base.uvm_object_globals: uvm_verbosity;


import uvm.seq.uvm_sequence_base: uvm_sequence_base;

import uvm.base.uvm_scope;
import uvm.meta.misc;

import esdl.rand;
import std.uni: toUpper;
import std.conv: to;

import std.string: format;

// Class: uvm_reg_field
// This is an implementation of uvm_reg_field as described in 1800.2 with
// the addition of API described below.

// @uvm-ieee 1800.2-2020 auto 18.5.1
class uvm_reg_field: uvm_object
{
  mixin uvm_sync;
  mixin (uvm_scope_sync_string);
  // Variable -- NODOCS -- value
  // Mirrored field value.
  // This value can be sampled in a functional coverage model
  // or constrained when randomized.
  @uvm_public_sync
  @rand  uvm_reg_data_t  _value; // Mirrored after randomize()

  uvm_reg_data_t get_value() {
    synchronized(this) {
      return _value;
    }
  }

  @uvm_private_sync
  private uvm_reg_data_t          _m_mirrored; // What we think is in the HW
  @uvm_private_sync
  private uvm_reg_data_t          _m_desired;  // Mirrored after set()
  @uvm_private_sync
  private string                  _m_access;
  @uvm_private_sync
  private uvm_reg                 _m_parent;
  // uvm_sync_private _m_parent uvm_reg
  @uvm_private_sync
  private uint                    _m_lsb;
  @uvm_private_sync
  private uint                    _m_size;
  @uvm_private_sync
  private bool                    _m_volatile;
  @uvm_private_sync
  private uvm_reg_data_t[string]  _m_reset;
  @uvm_private_sync
  private bool                    _m_written;
  @uvm_private_sync
  private bool                    _m_read_in_progress;
  @uvm_private_sync
  private bool                    _m_write_in_progress;

  @uvm_private_sync
  private string                  _m_fname;
  @uvm_private_sync
  private int                     _m_lineno;
  @uvm_private_sync
  private int                     _m_cover_on;
  @uvm_private_sync
  private bool                    _m_individually_accessible;
  @uvm_private_sync
  private uvm_check_e             _m_check;

  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private int              _m_max_size;
    @uvm_private_sync
    private bool[string]     _m_policy_names;
    @uvm_private_sync
    private bool             _m_predefined;

    @uvm_none_sync
    bool define_access(string name) {
      synchronized(this) {
	if (!_m_predefined) _m_predefined = m_predefine_policies();
	name = name.toUpper();

	if (name in _m_policy_names) return false;
	
	_m_policy_names[name] = true;
	return true;
      }
    }

    @uvm_none_sync
    bool m_predefine_policies() {
      synchronized(this) {
	if (_m_predefined) return true;

	_m_predefined = true;
   
	define_access("RO");
	define_access("RW");
	define_access("RC");
	define_access("RS");
	define_access("WRC");
	define_access("WRS");
	define_access("WC");
	define_access("WS");
	define_access("WSRC");
	define_access("WCRS");
	define_access("W1C");
	define_access("W1S");
	define_access("W1T");
	define_access("W0C");
	define_access("W0S");
	define_access("W0T");
	define_access("W1SRC");
	define_access("W1CRS");
	define_access("W0SRC");
	define_access("W0CRS");
	define_access("WO");
	define_access("WOC");
	define_access("WOS");
	define_access("W1");
	define_access("WO1");
	return true;
      }
    }

    this() {
      m_predefine_policies();
    }
    
  }
  

  constraint!q{
    if (UVM_REG_DATA_WIDTH > _m_size) {
      // _value < (UVM_REG_DATA_WIDTH'h1 << _m_size);
      _value < (1L << _m_size);
    }
  } uvm_reg_field_valid;

  mixin uvm_object_utils; // (uvm_reg_field)

  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------


  // @uvm-ieee 1800.2-2020 auto 18.5.3.1
  this(string name = "uvm_reg_field") {
    super(name);
  }



  void configure(T)(uvm_reg        parent,
		    uint           size,
		    uint           lsb_pos,
		    string         access,
		    bool           is_volatile,
		    T              reset,
		    bool           has_reset,
		    bool           is_rand,
		    bool           individually_accessible) {
    uvm_reg_data_t reset_ = reset;
    configure(parent, size, lsb_pos, access, is_volatile, reset_,
	      has_reset, is_rand, individually_accessible);
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.3.2
  void configure(uvm_reg        parent,
		 uint           size,
		 uint           lsb_pos,
		 string         access,
		 bool           is_volatile,
		 uvm_reg_data_t reset,
		 bool           has_reset,
		 bool           is_rand,
		 bool           individually_accessible) {
    synchronized(this) {
      _m_parent = parent;
      if (size == 0) {
	uvm_error("RegModel",
		  format("Field \"%s\" cannot have 0 bits", get_full_name()));
	size = 1;
      }

      _m_size      = size;
      _m_volatile  = is_volatile;
      _m_access    = access.toUpper();
      _m_lsb       = lsb_pos;
      _m_cover_on  = uvm_coverage_model_e.UVM_NO_COVERAGE;
      _m_written   = 0;
      _m_check     = is_volatile ? UVM_NO_CHECK : UVM_CHECK;
      _m_individually_accessible = individually_accessible;

      if (has_reset)
	set_reset(reset);

      _m_parent.add_field(this);

      synchronized(_uvm_scope_inst) {
	if (_m_access !in _m_policy_names) {
	  uvm_error("RegModel", "Access policy '" ~ access ~
		    "' for field '" ~ get_full_name() ~
		    "' is not defined. Setting to RW");
	  _m_access = "RW";
	}
      }
      
      synchronized(_uvm_scope_inst) {
	if (size > m_max_size) m_max_size = size;
      }
   
      // Ignore is_rand if the field is known not to be writeable
      // i.e. not "RW", "WRC", "WRS", "WO", "W1", "WO1"
      switch(access) {
      case "RO", "RC", "RS", "WC", "WS",
	"W1C", "W1S", "W1T", "W0C", "W0S", "W0T",
	"W1SRC", "W1CRS", "W0SRC", "W0CRS", "WSRC", "WCRS",
	"WOC", "WOS": is_rand = 0; break;
      default: break;		// do nothing
      }

      if (! is_rand) {
	set_rand_mode(false);
      }
    }
  }

  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  // Function -- NODOCS -- get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this field
  //


  // Function -- NODOCS -- get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this field
  // The base of the hierarchical name is the root block.
  //

  override string get_full_name() {
    synchronized(this) {
      return _m_parent.get_full_name() ~ "." ~ get_name();
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.4.1
  uvm_reg get_parent() {
    synchronized(this) {
      return _m_parent;
    }
  }

  uvm_reg get_register() {
    synchronized(this) {
      return _m_parent;
    }
  }

  // Function -- NODOCS -- get_lsb_pos
  //
  // Return the position of the field
  //
  // Returns the index of the least significant bit of the field
  // in the register that instantiates it.
  // An offset of 0 indicates a field that is aligned with the
  // least-significant bit of the register. 
  //

  uint         get_lsb_pos() {
    synchronized(this) {
      return _m_lsb;
    }
  }


  // Function -- NODOCS -- get_n_bits
  //
  // Returns the width, in number of bits, of the field. 
  //

  uint         get_n_bits() {
    synchronized(this) {
      return _m_size;
    }
  }

  //
  // FUNCTION: get_max_size
  // Returns the width, in number of bits, of the largest field. 
  //

  static uint         get_max_size() {
    synchronized(_uvm_scope_inst) {
      return _m_max_size;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.4.6
  string set_access(string mode) {
    synchronized(this) {
      string retval = _m_access;
      _m_access = mode.toUpper();
      synchronized(_uvm_scope_inst) {
	if (_m_access !in _m_policy_names) {
	  uvm_error("RegModel", "Access policy '" ~ _m_access ~
		    "' is not a defined field access policy");
	  _m_access = retval;
	}
      }
      return retval;
    }
  }

  // Function: set_rand_mode
  // Modifies the ~rand_mode~ for the field instance to the specified one
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  void set_rand_mode(bool mode) {
    rand_mode!q{_value}(mode);
  }

  // Function: get_rand_mode
  // Returns the rand_mode of the field instance
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  bool get_rand_mode() {
    return rand_mode!q{_value}();
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.4.7
  static bool define_access(string name) {
    return _uvm_scope_inst.define_access(name);
  }

  static bool m_predefine_policies() {
    return _uvm_scope_inst.m_predefine_policies();
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.4.5
  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      string field_access = _m_access;

      if (map == uvm_reg_map.backdoor())
	return field_access;

      // Is the register restricted in this map?
      switch(_m_parent.get_rights(map)) {
      case "RW":
	// No restrictions
	return field_access;

      case "RO":
	switch(field_access) {
	case "RW", "RO", "WC", "WS", "W1C", "W1S",
	  "W1T", "W0C", "W0S", "W0T", "W1":
	  field_access = "RO";
	  break;
        
	case "RC", "WRC", "W1SRC", "W0SRC", "WSRC":
	  field_access = "RC";
	  break;
        
	case "RS", "WRS", "W1CRS", "W0CRS", "WCRS":
	  field_access = "RS";
	  break;
        
	case "WO", "WOC", "WOS", "WO1":
	  field_access = "NOACCESS";
	  break;

	  // No change for the other modes
	default: assert(false);
	}
	break;

      case "WO":
	switch (field_access) {
	case "RW","WRC","WRS" : field_access = "WO"; break;
	case "W1SRC" : field_access = "W1S"; break;
	case "W0SRC": field_access = "W0S"; break;
	case "W1CRS": field_access = "W1C"; break;
	case "W0CRS": field_access = "W0C"; break;
	case "WCRS": field_access = "WC"; break;
	case "W1" : field_access = "W1"; break;
	case "WO1" : field_access = "WO1"; break;
	case "WSRC" : field_access = "WS"; break;
	case "RO","RC","RS": field_access = "NOACCESS"; break;
	  // No change for the other modes
	default: break;
	}
	break;
      default:
	field_access = "NOACCESS";
	uvm_error("RegModel", "Register '" ~ _m_parent.get_full_name() ~ 
		  "' containing field '" ~ get_name() ~ "' is mapped in map '" ~ 
		  map.get_full_name() ~ "' with unknown access right '" ~  _m_parent.get_rights(map) ~  "'");
	break;
      }
      return field_access;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.4.8
  bool is_known_access(uvm_reg_map map = null) {
    synchronized(this) {
      string acc = get_access(map);
      switch(acc) {
      case "RO", "RW", "RC", "RS", "WC", "WS",
	"W1C", "W1S", "W1T", "W0C", "W0S", "W0T",
	"WRC", "WRS", "W1SRC", "W1CRS", "W0SRC", "W0CRS", "WSRC", "WCRS",
	"WO", "WOC", "WOS", "W1", "WO1" : return true;
      default: return false;
      }
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.4.9
  void set_volatility(bool is_volatile) {
    synchronized(this) {
      _m_volatile = is_volatile;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.4.10
  bool is_volatile() {
    synchronized(this) {
      return _m_volatile;
    }
  }

  //--------------
  // Group -- NODOCS -- Access
  //--------------


  // @uvm-ieee 1800.2-2020 auto 18.5.5.2
  void set(uvm_reg_data_t  value,
	   string          fname = "",
	   int             lineno = 0) {
    synchronized(this) {
      // uvm_reg_data_t mask = ('b1 << _m_size)-1;
      uvm_reg_data_t mask = 1;
      mask = (mask << _m_size) - 1;

      _m_fname = fname;
      _m_lineno = lineno;
      if (value >> _m_size) {
	uvm_warning("RegModel",
		    format("Specified value (0x%x) greater than field \"%s\" size (%0d bits)",
			   value, get_name(), _m_size));
	value &= mask;
      }

      if (_m_parent.is_busy()) {
	uvm_warning("UVM/FLD/SET/BSY",
		    format("Setting the value of field \"%s\" while containing register \"%s\"" ~
			   " is being accessed may result in loss of desired field value. A" ~
			   " race condition between threads concurrently accessing the register" ~
			   " model is the likely cause of the problem.", get_name(),
			   _m_parent.get_full_name()));
      }

      switch(_m_access) {
      case "RO":    _m_desired = _m_desired; break;
      case "RW":    _m_desired = value; break;
      case "RC":    _m_desired = _m_desired; break;
      case "RS":    _m_desired = _m_desired; break;
      case "WC":    _m_desired = 0; break;
      case "WS":    _m_desired = mask; break;
      case "WRC":   _m_desired = value; break;
      case "WRS":   _m_desired = value; break;
      case "WSRC":  _m_desired = mask; break;
      case "WCRS":  _m_desired = 0; break;
      case "W1C":   _m_desired = _m_desired & (~value); break;
      case "W1S":   _m_desired = _m_desired | value; break;
      case "W1T":   _m_desired = _m_desired ^ value; break;
      case "W0C":   _m_desired = _m_desired & value; break;
      case "W0S":   _m_desired = _m_desired | (~value & mask); break;
      case "W0T":   _m_desired = _m_desired ^ (~value & mask); break;
      case "W1SRC": _m_desired = _m_desired | value; break;
      case "W1CRS": _m_desired = _m_desired & (~value); break;
      case "W0SRC": _m_desired = _m_desired | (~value & mask); break;
      case "W0CRS": _m_desired = _m_desired & value; break;
      case "WO":    _m_desired = value; break;
      case "WOC":   _m_desired = 0; break;
      case "WOS":   _m_desired = mask; break;
      case "W1":    _m_desired = (_m_written) ? _m_desired : value; break;
      case "WO1":   _m_desired = (_m_written) ? _m_desired : value; break;
      default: _m_desired = value;
      }
      this._value = _m_desired;
    }
  }

 
  // @uvm-ieee 1800.2-2020 auto 18.5.5.1
  uvm_reg_data_t  get(string  fname = "",
		      int     lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      return _m_desired;
    }
  }
 

  // @uvm-ieee 1800.2-2020 auto 18.5.5.3
  uvm_reg_data_t  get_mirrored_value(string  fname = "",
				     int     lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      return _m_mirrored;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.4
  void reset(string kind = "HARD") {
    synchronized(this) {
      if (kind !in _m_reset) return;
   
      _m_mirrored = _m_reset[kind];
      _m_desired  = _m_mirrored;
      _value      = _m_mirrored;

      if (kind == "HARD") _m_written  = 0;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.6
  uvm_reg_data_t get_reset(string kind = "HARD") {
    synchronized(this) {
      if (kind !in _m_reset) return _m_desired;
      return _m_reset[kind];
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.5
  bool has_reset(string kind = "HARD",
		 bool   remove = false) {
    synchronized(this) {
      if (kind !in _m_reset) return false;

      if (remove) _m_reset.remove(kind);

      return true;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.5.7
  void set_reset(uvm_reg_data_t value,
		 string kind = "HARD") {
    synchronized(this) {
      _m_reset[kind] = value & ((1L << _m_size) - 1);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.5.5.8
  bool needs_update() {
    synchronized(this) {
      return (_m_mirrored != _m_desired) | _m_volatile;
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

  // @uvm-ieee 1800.2-2020 auto 18.5.5.9
  // task
  void write(out uvm_status_e   status,
	     uvm_reg_data_t     value,
	     uvm_door_e         door = uvm_door_e.UVM_DEFAULT_DOOR,
	     uvm_reg_map        map = null,
	     uvm_sequence_base  parent = null,
	     int                prior = -1,
	     uvm_object         extension = null,
	     string             fname = "",
	     int                lineno = 0) {

    uvm_reg_item rw;
    rw = uvm_reg_item.type_id.create("field_write_item", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_FIELD);
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

    synchronized(rw) {
      status = rw.get_status();
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.10
  // task
  void read(out uvm_status_e   status,
	    out uvm_reg_data_t value,
	    uvm_door_e         door = uvm_door_e.UVM_DEFAULT_DOOR,
	    uvm_reg_map        map = null,
	    uvm_sequence_base  parent = null,
	    int                prior = -1,
	    uvm_object         extension = null,
	    string             fname = "",
	    int                lineno = 0) {

    uvm_reg_item rw;
    rw = uvm_reg_item.type_id.create("field_read_item", null, get_full_name());
    synchronized(rw) {
      rw.set_element(this);
      rw.set_element_kind(UVM_FIELD);
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

    synchronized(rw) {
      // value = rw.value[0];
      value = rw.get_value(0);
      status = rw.get_status();
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.11
  // task
  void poke(out uvm_status_e  status,
	    uvm_reg_data_t    value,
	    string            kind = "",
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      if (value >> _m_size) {
	uvm_warning("RegModel",
		    "poke(): Value exceeds size of field '" ~
		    get_name() ~ "'");
	value &= value & ((1<<_m_size)-1);
      }
    }
    m_parent.XatomicX(1);
    m_parent.m_is_locked_by_field = true;

    uvm_reg_data_t  tmp = 0;

    // What is the current values of the other fields???
    m_parent.peek(status, tmp, kind, parent, extension, fname, lineno);

    if (status == UVM_NOT_OK) {
      uvm_error("RegModel", "poke(): Peek of register '" ~ 
		m_parent.get_full_name() ~ "' returned status " ~
		status.to!string);
      m_parent.XatomicX(0);
      m_parent.m_is_locked_by_field = false;
      return;
    }
      

    // Force the value for this field then poke the resulting value
    tmp &= ~(((1<<m_size)-1) << m_lsb);
    tmp |= value << m_lsb;
    m_parent.poke(status, tmp, kind, parent, extension, fname, lineno);

    m_parent.XatomicX(0);
    m_parent.m_is_locked_by_field = false;
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.12
  // task
  void peek(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    string                kind = "",
	    uvm_sequence_base     parent = null,
	    uvm_object            extension = null,
	    string                fname = "",
	    int                   lineno = 0) {
    uvm_reg_data_t  reg_value;
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
    }

    m_parent.peek(status, reg_value, kind, parent, extension, fname, lineno);
    value = (reg_value >> m_lsb) & ((1L << m_size))-1;
  }
               

  // @uvm-ieee 1800.2-2020 auto 18.5.5.13
  // task
  void mirror(out uvm_status_e  status,
	      uvm_check_e       check = uvm_check_e.UVM_NO_CHECK,
	      uvm_door_e        door = uvm_door_e.UVM_DEFAULT_DOOR,
	      uvm_reg_map       map = null,
	      uvm_sequence_base parent = null,
	      int               prior = -1,
	      uvm_object        extension = null,
	      string            fname = "",
	      int               lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
    }
    
    m_parent.mirror(status, check, door, map, parent, prior, extension,
		     fname, lineno);
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.15
  void set_compare(uvm_check_e check = uvm_check_e.UVM_CHECK) {
    synchronized(this) {
      _m_check = check;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.14
  uvm_check_e get_compare() {
    synchronized(this) {
      return _m_check;
    }
  }
   

  // @uvm-ieee 1800.2-2020 auto 18.5.5.16
  final bool is_indv_accessible(uvm_door_e  door,
				uvm_reg_map local_map) {
    synchronized(this) {
      if(door == UVM_BACKDOOR) {
	uvm_warning("RegModel",
		    "Individual BACKDOOR field access not available for field '" ~ 
		    get_full_name() ~  "'. Accessing complete register instead.");
	return false;
      }

      if(! _m_individually_accessible) {
	uvm_warning("RegModel",
		    "Individual field access not available for field '" ~ 
		    get_full_name() ~  "'. Accessing complete register instead.");
	return false;
      }

      // Cannot access individual fields if the container register
      // has a user-defined front-door
      if(_m_parent.get_frontdoor(local_map) !is null) {
	uvm_warning("RegModel",
		    "Individual field access not available for field '" ~ 
		    get_name() ~  "' because register '" ~  _m_parent.get_full_name() ~  "' has a user-defined front-door. Accessing complete register instead.");
	return false;
      }
   
      uvm_reg_map system_map = local_map.get_root_map();
      uvm_reg_adapter adapter = system_map.get_adapter();
      if (adapter.supports_byte_enable)
	return true;

      size_t fld_idx;
      int bus_width = local_map.get_n_bytes();
      uvm_reg_field[] fields;
      bool sole_field; 		// why is it there?

      _m_parent.get_fields(fields);

      if (fields.length == 1) {
	sole_field = true;
      }
      else {
	int prev_lsb,this_lsb,next_lsb; 
	int prev_sz,this_sz,next_sz; 
	int bus_sz = bus_width*8;

	foreach (i, field; fields) {
	  if (field == this) {
	    fld_idx = i;
	    break;
	  }
	}

	this_lsb = fields[fld_idx].get_lsb_pos();
	this_sz  = fields[fld_idx].get_n_bits();

	if (fld_idx > 0) {
	  prev_lsb = fields[fld_idx-1].get_lsb_pos();
	  prev_sz  = fields[fld_idx-1].get_n_bits();
	}

	if (fld_idx < fields.length-1) {
	  next_lsb = fields[fld_idx+1].get_lsb_pos();
	  next_sz  = fields[fld_idx+1].get_n_bits();
	}

	// if first field in register
	if (fld_idx == 0 &&
	    ((next_lsb % bus_sz) == 0 ||
	     (next_lsb - this_sz) > (next_lsb % bus_sz)))
	  return true;

	// if last field in register
	else if (fld_idx == (fields.length-1) &&
		 ((this_lsb % bus_sz) == 0 ||
		  (this_lsb - (prev_lsb + prev_sz)) >= (this_lsb % bus_sz)))
	  return true;

	// if somewhere in between
	else {
	  if ((this_lsb % bus_sz) == 0) {
	    if ((next_lsb % bus_sz) == 0 ||
		(next_lsb - (this_lsb + this_sz)) >= (next_lsb % bus_sz))
	      return true;
	  } 
	  else {
	    if ( (next_lsb - (this_lsb + this_sz)) >= (next_lsb % bus_sz) &&
		 ((this_lsb - (prev_lsb + prev_sz)) >= (this_lsb % bus_sz)) )
	      return true;
	  }
	}
      }
   
      uvm_warning("RegModel", 
		  "Target bus does not support byte enabling ~  and the field '" ~ 
		  get_full_name() ~ "' is not the only field within the entire bus width. " ~ 
		  "Individual field access will not be available. " ~ 
		  "Accessing complete register instead.");

      return false;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.5.5.17
  bool predict (uvm_reg_data_t    value,
		uvm_reg_byte_en_t be =  -1,
		uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		uvm_door_e        door = uvm_door_e.UVM_FRONTDOOR,
		uvm_reg_map       map = null,
		string            fname = "",
		int               lineno = 0) {
    uvm_reg_item rw = new uvm_reg_item();
    synchronized(rw) {
      rw.set_value(value, 0);
      rw.set_door(door);
      rw.set_map(map);
      rw.set_fname(fname);
      rw.set_line(lineno);
      do_predict(rw, kind, be);
      return (rw.get_status() == UVM_NOT_OK) ? false : true;
    }
  }

  uvm_reg_data_t XpredictX (uvm_reg_data_t cur_val,
			    uvm_reg_data_t wr_val,
			    uvm_reg_map    map) {
    synchronized(this) {
      uvm_reg_data_t mask = (1L << _m_size)-1;
   
      switch (get_access(map)) {
      case "RO":    return cur_val;
      case "RW":    return wr_val;
      case "RC":    return cur_val;
      case "RS":    return cur_val;
      case "WC":    return cast(uvm_reg_data_t) 0;
      case "WS":    return mask;
      case "WRC":   return wr_val;
      case "WRS":   return wr_val;
      case "WSRC":  return mask;
      case "WCRS":  return cast(uvm_reg_data_t) 0;
      case "W1C":   return cur_val & (~wr_val);
      case "W1S":   return cur_val | wr_val;
      case "W1T":   return cur_val ^ wr_val;
      case "W0C":   return cur_val & wr_val;
      case "W0S":   return cur_val | (~wr_val & mask);
      case "W0T":   return cur_val ^ (~wr_val & mask);
      case "W1SRC": return cur_val | wr_val;
      case "W1CRS": return cur_val & (~wr_val);
      case "W0SRC": return cur_val | (~wr_val & mask);
      case "W0CRS": return cur_val & wr_val;
      case "WO":    return wr_val;
      case "WOC":   return cast(uvm_reg_data_t) 0;
      case "WOS":   return mask;
      case "W1":    return (_m_written) ? cur_val : wr_val;
      case "WO1":   return (_m_written) ? cur_val : wr_val;
      case "NOACCESS": return cur_val;
      default:      return wr_val;
      }
      // this statement is not even reachable, but there in the SV version
      // uvm_fatal("RegModel", "XpredictX(): Internal error");
      // return uvm_reg_data_t(0);
    }
  }

  uvm_reg_data_t  XupdateX() {
    // Figure out which value must be written to get the desired value
    // given what we think is the current value in the hardware
    synchronized(this) {
      uvm_reg_data_t retval = 0;

      switch (_m_access) {
      case "RO":    retval = _m_desired; break;
      case "RW":    retval = _m_desired; break;
      case "RC":    retval = _m_desired; break;
      case "RS":    retval = _m_desired; break;
      case "WRC":   retval = _m_desired; break;
      case "WRS":   retval = _m_desired; break;
      case "WC":    retval = _m_desired; break;  // Warn if != 0
      case "WS":    retval = _m_desired; break;  // Warn if != 1
      case "WSRC":  retval = _m_desired; break;  // Warn if != 1
      case "WCRS":  retval = _m_desired; break;  // Warn if != 0
      case "W1C":   retval = ~_m_desired; break;
      case "W1S":   retval = _m_desired; break;
      case "W1T":   retval = _m_desired ^ _m_mirrored; break;
      case "W0C":   retval = _m_desired; break;
      case "W0S":   retval = ~_m_desired; break;
      case "W0T":   retval = ~(_m_desired ^ _m_mirrored); break;
      case "W1SRC": retval = _m_desired; break;
      case "W1CRS": retval = ~_m_desired; break;
      case "W0SRC": retval = ~_m_desired; break;
      case "W0CRS": retval = _m_desired; break;
      case "WO":    retval = _m_desired; break;
      case "WOC":   retval = _m_desired; break;  // Warn if != 0
      case "WOS":   retval = _m_desired; break;  // Warn if != 1
      case "W1":    retval = _m_desired; break;
      case "WO1":   retval = _m_desired; break;
      default: retval = _m_desired; break;
      }
      retval &= (1L << _m_size) - 1;
      return retval;
    }
  }

  bool Xcheck_accessX(uvm_reg_item rw,
		      out uvm_reg_map_info map_info) {
    synchronized(this) {
                        
      if (rw.get_door() == UVM_DEFAULT_DOOR) {
	uvm_reg_block blk = _m_parent.get_block();
	rw.set_door(blk.get_default_door());
      }

      if (rw.get_door() == UVM_BACKDOOR) {
	if (_m_parent.get_backdoor() is null && !_m_parent.has_hdl_path()) {
	  uvm_warning("RegModel",
		      "No backdoor access available for field '" ~ get_full_name() ~ 
		      "' . Using frontdoor instead.");
	  rw.set_door(UVM_FRONTDOOR);
	}
	else
	  rw.set_map(uvm_reg_map.backdoor());
      }

      if (rw.get_door() != UVM_BACKDOOR) {

	rw.set_local_map(_m_parent.get_local_map(rw.get_map()));

	if (rw.get_local_map() is null) {
	  uvm_reg_map local_tmp_map = rw.get_map();
	  uvm_error(get_type_name(), 
		    "No transactor available to physically access memory from map '" ~ 
		    local_tmp_map.get_full_name() ~ "'");
	  rw.set_status(UVM_NOT_OK);
	  return false;
	}

	uvm_reg_map local_tmp_map = rw.get_map();
	map_info = local_tmp_map.get_reg_map_info(_m_parent);

	if (map_info.frontdoor is null && map_info.unmapped) {
	  uvm_error("RegModel", "Field '" ~ get_full_name() ~ 
		    "' in register that is unmapped in map '" ~ 
		    local_tmp_map.get_full_name() ~ 
		    "' and does not have a user-defined frontdoor");
	  rw.set_status(UVM_NOT_OK);
	  return false;
	}

	if (rw.get_map() is null) {
	  rw.set_map(rw.local_map);
	}
      }

      return true;
    }
  }

  // task
  void do_write(uvm_reg_item rw) {

    uvm_reg_data_t   value_adjust;
    uvm_reg_map_info map_info;
    uvm_reg_field[]  fields;
    bool             bad_side_effect;

    m_parent.XatomicX(1);
    synchronized(this) {
      _m_fname  = rw.get_fname();
      _m_lineno = rw.get_line();

      if (!Xcheck_accessX(rw, map_info))
	return;

      _m_write_in_progress = true;

      if (rw.get_value(0) >> _m_size) {
	uvm_warning("RegModel", "write(): Value greater than field '" ~ 
		    get_full_name() ~ "'");
	uvm_reg_data_t tmp_value = rw.get_value(0);
	tmp_value &= ((1<<m_size)-1);
	rw.set_value(tmp_value, 0);
      }

      // Get values to write to the other fields in register
      m_parent.get_fields(fields);
      foreach (i, field; fields) {

	if (field == this) {
	  // value_adjust |= rw.value[0] << _m_lsb;
	  value_adjust |= rw.get_value(0) << _m_lsb;
	  continue;
	}

	// It depends on what kind of bits they are made of...
	switch (field.get_access(rw.get_local_map())) {
	  // These...
	case "RO", "RC", "RS", "W1C", "W1S", "W1T", "W1SRC", "W1CRC":
	  // Use all 0's
	  value_adjust |= 0;
	  break;

	  // These...
	case "W0C", "W0S", "W0T", "W0SRC", "W0CRS":
	  // Use all 1's
	  value_adjust |= ((1<<fields[i].get_n_bits())-1) << fields[i].get_lsb_pos();
	  break;

	  // These might have side effects! Bad!
	case "WC", "WS", "WCRS", "WSRC", "WOC", "WOS":
	  bad_side_effect = 1;
	  break;

	default:
	  value_adjust |= fields[i]._m_mirrored << fields[i].get_lsb_pos();
	  break;
	}
      }
    }
    version(UVM_REG_NO_INDIVIDUAL_FIELD_ACCESS) {
      synchronized(rw) {
	rw.set_element_kind(UVM_REG);
	rw.set_element(m_parent);
	rw.set_value(value_adjust, 0);
      }
      m_parent.do_write(rw);
    }
    else {

      if (!is_indv_accessible(rw.get_door(), rw.get_local_map())) {
	synchronized(this) {
	  rw.set_element_kind(UVM_REG);
	  rw.set_element(m_parent);
	  rw.set_value(value_adjust, 0);
	}
	m_parent.do_write(rw);

	if (bad_side_effect) {
	  uvm_warning("RegModel", format("Writing field \"%s\" will cause unintended" ~
					 " side effects in adjoining Write-to-Clear" ~
					 " or Write-to-Set fields in the same register",
					 this.get_full_name()));
	}
      }
      else {
	uvm_reg_map item_map = rw.get_local_map();
	uvm_reg_map system_map = item_map.get_root_map();
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter(this);

	m_parent.Xset_busyX(1);

	rw.set_status(UVM_IS_OK);
      
	pre_write(rw);
	for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
	  cb.pre_write(rw);

	if (rw.get_status() != UVM_IS_OK) {
	  m_write_in_progress = 0;
	  m_parent.Xset_busyX(0);
	  m_parent.XatomicX(0);
        
	  return;
	}
            
	item_map.do_write(rw);

	if (system_map.get_auto_predict())
	  // ToDo: Call parent.XsampleX();
	  do_predict(rw, UVM_PREDICT_WRITE);

	post_write(rw);
	for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
	  cb.post_write(rw);

	m_parent.Xset_busyX(0);
      
      }
    }

    m_write_in_progress = false;
    m_parent.XatomicX(0);
  }

  // task
  void do_read(uvm_reg_item rw) {

    uvm_reg_map_info map_info;
    bool bad_side_effect;

    m_parent.XatomicX(1);
    m_fname  = rw.get_fname();
    m_lineno = rw.get_line();
    m_read_in_progress = true;
  
    if (!Xcheck_accessX(rw, map_info))
      return;

    uvm_reg_map rw_local_map = rw.get_local_map();
    
    version(UVM_REG_NO_INDIVIDUAL_FIELD_ACCESS) {
      rw.set_element_kind(UVM_REG);
      rw.set_element(_m_parent);
      m_parent.do_read(rw);
      rw.set_value((rw.get_value(0) >> m_lsb) & ((1<<m_size))-1, 0);
      bad_side_effect = true;
    }
    else {

      if (!is_indv_accessible(rw.get_door(), rw_local_map)) {
	rw.set_element_kind(UVM_REG);
	rw.set_element(_m_parent);
	bad_side_effect = true;
	m_parent.do_read(rw);
	uvm_reg_data_t value = rw.get_value(0);
	rw.set_value((value >> m_lsb) & ((1L << m_size))-1, 0);
      }
      else {

	uvm_reg_map system_map = rw_local_map.get_root_map();
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter(this);

	m_parent.Xset_busyX(1);

	rw.set_status(UVM_IS_OK);
      
	pre_read(rw);
	for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
	  cb.pre_read(rw);
	}

	if (rw.get_status() != UVM_IS_OK) {
	  m_read_in_progress = 0;
	  m_parent.Xset_busyX(0);
	  m_parent.XatomicX(0);

	  return;
	}
            
	rw_local_map.do_read(rw);


	if (system_map.get_auto_predict())
	  // ToDo: Call parent.XsampleX();
	  do_predict(rw, UVM_PREDICT_READ);

	post_read(rw);
	for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
	  cb.post_read(rw);

	m_parent.Xset_busyX(0);
      
      }
    }

    m_read_in_progress = false;
    m_parent.XatomicX(0);

    if (bad_side_effect) {
      uvm_reg_field[] fields;
      m_parent.get_fields(fields);
      foreach (i, field; fields) {
	string mode;
	if (field == this) continue;
	mode = field.get_access();
	if (mode == "RC" ||
	    mode == "RS" ||
	    mode == "WRC" ||
	    mode == "WRS" ||
	    mode == "WSRC" ||
	    mode == "WCRS" ||
	    mode == "W1SRC" ||
	    mode == "W1CRS" ||
	    mode == "W0SRC" ||
	    mode == "W0CRS") {
	  uvm_warning("RegModel", "Reading field '" ~ get_full_name() ~ 
		      "' will cause unintended side effects in adjoining " ~ 
		      "Read-to-Clear or Read-to-Set fields in the same register");
	}
      }
    }
  }

  void do_predict(uvm_reg_item      rw,
		  uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		  uvm_reg_byte_en_t be =  -1) {
    synchronized(this) {
      // uvm_reg_data_t field_val = rw.value[0] & ((1 << _m_size)-1);
      uvm_reg_data_t field_val = rw.get_value(0) & ((1L << _m_size)-1);

      if (rw.get_status() != UVM_NOT_OK)
	rw.set_status(UVM_IS_OK);

      // Assume that the entire field is enabled
      if (!be[0])
	return;

      _m_fname = rw.get_fname();
      _m_lineno = rw.get_line();

      switch (kind) {

      case UVM_PREDICT_WRITE:
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter (this);

	if (rw.get_door() == UVM_FRONTDOOR || rw.get_door() == UVM_PREDICT)
	  field_val = XpredictX(_m_mirrored, field_val, rw.get_map());

	_m_written = 1;

	for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
	  cb.post_predict(this, _m_mirrored, field_val, 
			  UVM_PREDICT_WRITE, rw.get_door(), rw.get_map());

	field_val &= (1L << _m_size)-1;
	break;

      case UVM_PREDICT_READ:
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter(this);

	if (rw.get_door() == UVM_FRONTDOOR || rw.get_door() == UVM_PREDICT) {

	  string acc = get_access(rw.get_map());

	  if (acc == "RC" ||
	      acc == "WRC" ||
	      acc == "WSRC" ||
	      acc == "W1SRC" ||
	      acc == "W0SRC")
	    field_val = 0;  // (clear)

	  else if (acc == "RS" ||
		   acc == "WRS" ||
		   acc == "WCRS" ||
		   acc == "W1CRS" ||
		   acc == "W0CRS")
	    field_val = (1L << _m_size)-1; // all 1's (set)

	  else if (acc == "WO" ||
		   acc == "WOC" ||
		   acc == "WOS" ||
		   acc == "WO1" ||
		   acc == "NOACCESS")
	    return;
	}

	for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
	  cb.post_predict(this, _m_mirrored, field_val,
			  UVM_PREDICT_READ, rw.get_door(), rw.get_map());
	}
	field_val &= (1L << _m_size)-1;
	break;

      case UVM_PREDICT_DIRECT:
	if (_m_parent.is_busy()) {
	  uvm_warning("RegModel", "Trying to predict value of field '" ~
		      get_name() ~ "' while register '" ~
		      _m_parent.get_full_name() ~ "' is being accessed");
	  rw.set_status(UVM_NOT_OK);
	}
	break;
      default: assert(0);
      }
      // update the mirror with predicted value
      _m_mirrored = field_val;
      _m_desired  = field_val;
      this._value = field_val;
    }
  }
               
  void pre_randomize() {
    // Update the only publicly known property with the current
    // desired value so it can be used as a state variable should
    // the rand_mode of the field be turned off.
    synchronized(this) {
      _value = _m_desired;
    }
  }

  void post_randomize() {
    synchronized(this) {
      _m_desired = _value;
    }
  }



  //-----------------
  // Group -- NODOCS -- Callbacks
  //-----------------

  mixin uvm_register_cb!(uvm_reg_cbs);


  // @uvm-ieee 1800.2-2020 auto 18.5.6.1
  // task
  void pre_write(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 18.5.6.2
  // task
  void post_write(uvm_reg_item rw) {}

  // @uvm-ieee 1800.2-2020 auto 18.5.6.3
  // task
  void pre_read (uvm_reg_item rw) {}

  // @uvm-ieee 1800.2-2020 auto 18.5.6.4
  // task
  void post_read  (uvm_reg_item rw) {}


  override void do_print (uvm_printer printer) {
    printer.print_generic(get_name(), get_type_name(), -1, convert2string());
  }

  override string convert2string() {
    synchronized(this) {
      string retval;
      string res_str;
      string t_str;
      bool with_debug_info;
      string prefix;
      uvm_reg reg_=get_register();

      // string fmt = format("%0d'h%%%0dh", get_n_bits(),
      // 			  (get_n_bits()-1)/4 + 1);
      string fmt = format("0x%%%0dx", // get_n_bits(),
			  (get_n_bits()-1)/4 + 1);
      retval = format("%s %s %s[%0d:%0d]=" ~ fmt ~ "%s", prefix,
			       get_access(),
			       reg_.get_name(),
			       get_lsb_pos() + get_n_bits() - 1,
			       get_lsb_pos(), _m_desired,
			       (_m_desired != _m_mirrored) ? format(" (Mirror: " ~ fmt ~ ")",
								    _m_mirrored) : "");

      if (_m_read_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format(" from %s:%0d",_m_fname, _m_lineno);
	retval = retval ~  "\n" ~  "currently being read" ~  res_str; 
      }
      if (_m_write_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format(" from %s:%0d",_m_fname, _m_lineno);
	retval = retval ~  "\n" ~  res_str ~  "currently being written"; 
      }
      return retval;
    }
  }

  T to(T)() if(is(T == string)){
    return convert2string();
  }
  
  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel field cannot be cloned");
    return null;
  }

  override void do_copy(uvm_object rhs) {
    uvm_warning("RegModel","RegModel field copy not yet implemented");
    // just a set(rhs.get()) ?
  }


  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel field compare not yet implemented");
    // just a return (get() == rhs.get()) ?
    return false;
  }


  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel field cannot be packed");
  }

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel field cannot be unpacked");
  }

}
