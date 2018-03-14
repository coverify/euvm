//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010-2011 Cadence Design Systems, Inc.
//    Copyright 2014      Coverify Systems Technology
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

import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_callback;
import uvm.base.uvm_comparer;
import uvm.base.uvm_globals;
import uvm.base.uvm_packer;
import uvm.base.uvm_printer;
import uvm.base.uvm_resource_db;
import uvm.meta.misc;
import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_adapter;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_cbs;
import uvm.reg.uvm_reg_defines;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.seq.uvm_sequence_base;

import esdl.rand;
import std.uni: toUpper;
import std.conv: to;

//-----------------------------------------------------------------
// CLASS: uvm_reg_field
// Field abstraction class
//
// A field represents a set of bits that behave consistently
// as a single entity.
//
// A field is contained within a single register, but may
// have different access policies depending on the adddress map
// use the access the register (thus the field).
//-----------------------------------------------------------------
class uvm_reg_field: uvm_object
{
  mixin(uvm_sync_string);
  // Variable: value
  // Mirrored field value.
  // This value can be sampled in a functional coverage model
  // or constrained when randomized.
  @rand  uvm_reg_data_t  _value; // Mirrored after randomize()

  private uvm_reg_data_t          _m_mirrored; // What we think is in the HW
  private uvm_reg_data_t          _m_desired;  // Mirrored after set()
  private string                  _m_access;
  @uvm_private_sync
  private uvm_reg                 _m_parent;
  private uint                    _m_lsb;
  private uint                    _m_size;
  private bool                    _m_volatile;
  private uvm_reg_data_t[string]  _m_reset;
  private bool                    _m_written;
  private bool                    _m_read_in_progress;
  @uvm_private_sync
  private bool                    _m_write_in_progress;
  private string                  _m_fname;
  private int                     _m_lineno;
  private int                     _m_cover_on;
  private bool                    _m_individually_accessible;
  private uvm_check_e             _m_check;

  private static int              _m_max_size;
  private static bool[string]     _m_policy_names;

  static this() {
    m_predefine_policies();
  }
  
  Constraint!q{
    if (UVM_REG_DATA_WIDTH > _m_size) {
      // _value < (UVM_REG_DATA_WIDTH'h1 << _m_size);
      _value < (1 << _m_size);
    }
  } uvm_reg_field_valid;

  mixin uvm_object_utils; // (uvm_reg_field)

  //----------------------
  // Group: Initialization
  //----------------------

  // Function: new
  //
  // Create a new field instance
  //
  // This method should not be used directly.
  // The uvm_reg_field::type_id::create() factory method
  // should be used instead.
  //

  // extern function new(string name = "uvm_reg_field");
  // new

  this(string name = "uvm_reg_field") {
    super(name);
  }



  // Function: configure
  //
  // Instance-specific configuration
  //
  // Specify the ~parent~ register of this field, its
  // ~size~ in bits, the position of its least-significant bit
  // within the register relative to the least-significant bit
  // of the register, its ~access~ policy, volatility,
  // "HARD" ~reset~ value, 
  // whether the field value is actually reset
  // (the ~reset~ value is ignored if ~FALSE~),
  // whether the field value may be randomized and
  // whether the field is the only one to occupy a byte lane in the register.
  //
  // See <set_access> for a specification of the pre-defined
  // field access policies.
  //
  // If the field access policy is a pre-defined policy and NOT one of
  // "RW", "WRC", "WRS", "WO", "W1", or "WO1",
  // the value of ~is_rand~ is ignored and the rand_mode() for the
  // field instance is turned off since it cannot be written.
  //

  // extern function void configure(uvm_reg        parent,
  //                                 uint           size,
  //                                 uint           lsb_pos,
  //                                 string         access,
  //                                 bool           volatile,
  //                                 uvm_reg_data_t reset,
  //                                 bool           has_reset,
  //                                 bool           is_rand,
  //                                 bool           individually_accessible); 

  // configure

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
      else
	uvm_resource_db!bool.set("REG."~ get_full_name(),
				 "NO_REG_HW_RESET_TEST", 1);

      _m_parent.add_field(this);

      if (_m_access !in _m_policy_names) {
	uvm_error("RegModel", "Access policy '" ~ access ~
		  "' for field '" ~ get_full_name() ~
		  "' is not defined. Setting to RW");
	_m_access = "RW";
      }

      if (size > _m_max_size) _m_max_size = size;
   
      // Ignore is_rand if the field is known not to be writeable
      // i.e. not "RW", "WRC", "WRS", "WO", "W1", "WO1"
      switch(access) {
      case "RO", "RC", "RS", "WC", "WS",
	"W1C", "W1S", "W1T", "W0C", "W0S", "W0T",
	"W1SRC", "W1CRS", "W0SRC", "W0CRS", "WSRC", "WCRS",
	"WOC", "WOS": is_rand = 0; break;
      default: break;		// do nothing
      }

      if (!is_rand) {
	uvm_info("RANDMODE", "TBD -- implement rand_mode", UVM_NONE);
	// _value.rand_mode(0);
      }
    }
  }

  //---------------------
  // Group: Introspection
  //---------------------

  // Function: get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this field
  //


  // Function: get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this field
  // The base of the hierarchical name is the root block.
  //

  // extern virtual function string get_full_name();
  // get_full_name

  override string get_full_name() {
    synchronized(this) {
      return _m_parent.get_full_name() ~ "." ~ get_name();
    }
  }

  // Function: get_parent
  //
  // Get the parent register
  //

  // extern virtual function uvm_reg get_parent();
  // get_parent

  uvm_reg get_parent() {
    synchronized(this) {
      return _m_parent;
    }
  }

  // extern virtual function uvm_reg get_register();
  // get_register

  uvm_reg get_register() {
    synchronized(this) {
      return _m_parent;
    }
  }

  // Function: get_lsb_pos
  //
  // Return the position of the field
  //
  // Returns the index of the least significant bit of the field
  // in the register that instantiates it.
  // An offset of 0 indicates a field that is aligned with the
  // least-significant bit of the register. 
  //

  // extern virtual function uint         get_lsb_pos();
  // get_lsb_pos

  uint         get_lsb_pos() {
    synchronized(this) {
      return _m_lsb;
    }
  }


  // Function: get_n_bits
  //
  // Returns the width, in number of bits, of the field. 
  //

  // extern virtual function uint         get_n_bits();
  // get_n_bits

  uint         get_n_bits() {
    synchronized(this) {
      return _m_size;
    }
  }

  //
  // FUNCTION: get_max_size
  // Returns the width, in number of bits, of the largest field. 
  //

  // extern static function uint         get_max_size();
  // get_max_size

  static uint         get_max_size() {
    //    synchronized
    return _m_max_size;
  }

  // Function: set_access
  //
  // Modify the access policy of the field
  //
  // Modify the access policy of the field to the specified one and
  // return the previous access policy.
  //
  // The pre-defined access policies are as follows.
  // The effect of a read operation are applied after the current
  // value of the field is sampled.
  // The read operation will return the current value,
  // not the value affected by the read operation (if any).
  //
  // "RO"    - W: no effect, R: no effect
  // "RW"    - W: as-is, R: no effect
  // "RC"    - W: no effect, R: clears all bits
  // "RS"    - W: no effect, R: sets all bits
  // "WRC"   - W: as-is, R: clears all bits
  // "WRS"   - W: as-is, R: sets all bits
  // "WC"    - W: clears all bits, R: no effect
  // "WS"    - W: sets all bits, R: no effect
  // "WSRC"  - W: sets all bits, R: clears all bits
  // "WCRS"  - W: clears all bits, R: sets all bits
  // "W1C"   - W: 1/0 clears/no effect on matching bit, R: no effect
  // "W1S"   - W: 1/0 sets/no effect on matching bit, R: no effect
  // "W1T"   - W: 1/0 toggles/no effect on matching bit, R: no effect
  // "W0C"   - W: 1/0 no effect on/clears matching bit, R: no effect
  // "W0S"   - W: 1/0 no effect on/sets matching bit, R: no effect
  // "W0T"   - W: 1/0 no effect on/toggles matching bit, R: no effect
  // "W1SRC" - W: 1/0 sets/no effect on matching bit, R: clears all bits
  // "W1CRS" - W: 1/0 clears/no effect on matching bit, R: sets all bits
  // "W0SRC" - W: 1/0 no effect on/sets matching bit, R: clears all bits
  // "W0CRS" - W: 1/0 no effect on/clears matching bit, R: sets all bits
  // "WO"    - W: as-is, R: error
  // "WOC"   - W: clears all bits, R: error
  // "WOS"   - W: sets all bits, R: error
  // "W1"    - W: first one after ~HARD~ reset is as-is, other W have no effects, R: no effect
  // "WO1"   - W: first one after ~HARD~ reset is as-is, other W have no effects, R: error
  //
  // It is important to remember that modifying the access of a field
  // will make the register model diverge from the specification
  // that was used to create it.
  //
  // extern virtual function string set_access(string mode);

  // set_access

  string set_access(string mode) {
    synchronized(this) {
      string set_access_ = _m_access;
      _m_access = mode.toUpper();
      if (_m_access !in _m_policy_names) {
	uvm_error("RegModel", "Access policy '" ~ _m_access ~
		  "' is not a defined field access policy");
	_m_access = set_access_;
      }
      return set_access_;
    }
  }

  // Function: define_access
  //
  // Define a new access policy value
  //
  // Because field access policies are specified using string values,
  // there is no way for SystemVerilog to verify if a spceific access
  // value is valid or not.
  // To help catch typing errors, user-defined access values
  // must be defined using this method to avoid beign reported as an
  // invalid access policy.
  //
  // The name of field access policies are always converted to all uppercase.
  //
  // Returns TRUE if the new access policy was not previously
  // defined.
  // Returns FALSE otherwise but does not issue an error message.
  //
  // extern static function bool define_access(string name);
  // define_access

  static bool define_access(string name) {
    if (!_m_predefined) _m_predefined = m_predefine_policies();

    name = name.toUpper();

    if (name in _m_policy_names) return false;

    _m_policy_names[name] = 1;
    return true;
  }

  private static bool _m_predefined; //  = _m_predefine_policies();
  
  // extern local static function bool m_predefine_policies();
  // _m_predefined_policies

  static bool m_predefine_policies() {
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


  // Function: get_access
  //
  // Get the access policy of the field
  //
  // Returns the current access policy of the field
  // when written and read through the specified address ~map~.
  // If the register containing the field is mapped in multiple
  // address map, an address map must be specified.
  // The access policy of a field from a specific
  // address map may be restricted by the register's access policy in that
  // address map.
  // For example, a RW field may only be writable through one of
  // the address maps and read-only through all of the other maps.
  //
  // extern virtual function string get_access(uvm_reg_map map = null);

  // get_access

  string get_access(uvm_reg_map map = null) {
    synchronized(this) {
      string get_access_ = _m_access;

      if (map == uvm_reg_map.backdoor()) {
	return get_access_;
      }

      // Is the register restricted in this map?
      switch(_m_parent.get_rights(map)) {
      case "RW":
	// No restrictions
	return get_access_;

      case "RO":
	switch(get_access_) {
	case "RW", "RO", "WC", "WS", "W1C", "W1S",
	  "W1T", "W0C", "W0S", "W0T", "W1":
	  get_access_ = "RO";
	  break;
        
	case "RC", "WRC", "W1SRC", "W0SRC", "WSRC":
	  get_access_ = "RC";
	  break;
        
	case "RS", "WRS", "W1CRS", "W0CRS", "WCRS":
	  get_access_ = "RS";
	  break;
        
	case "WO", "WOC", "WOS", "WO1":
	  uvm_error("RegModel",
		    format("%s field \"%s\" restricted to RO in map \"%s\"",
			   get_access(), get_name(), map.get_full_name()));
	  break;
	  // No change for the other modes
	default: assert(false);
	}
	break;

      case "WO":
	switch (get_access_) {
	case "RW", "WO":
	  get_access_ = "WO";
	  break;
	default:
	  uvm_error("RegModel", get_access_ ~ " field '" ~ get_full_name() ~ 
		    "' restricted to WO in map '" ~ map.get_full_name() ~ "'");
	  break;
	  // No change for the other modes
	}
	break;
      default:
	uvm_error("RegModel", "Register '" ~ _m_parent.get_full_name() ~ 
		  "' containing field '" ~ get_name() ~ "' is mapped in map '" ~ 
		  map.get_full_name() ~ "' with unknown access right '" ~  _m_parent.get_rights(map) ~  "'");
	break;
      }
      return get_access_;
    }
  }



  // Function: is_known_access
  //
  // Check if access policy is a built-in one.
  //
  // Returns TRUE if the current access policy of the field,
  // when written and read through the specified address ~map~,
  // is a built-in access policy.
  //
  // extern virtual function bool is_known_access(uvm_reg_map map = null);
  // is_known_access

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

  //
  // Function: set_volatility
  // Modify the volatility of the field to the specified one.
  //
  // It is important to remember that modifying the volatility of a field
  // will make the register model diverge from the specification
  // that was used to create it.
  //
  // extern virtual function void set_volatility(bool volatile);
  // set_volatility

  void set_volatility(bool is_volatile) {
    synchronized(this) {
      _m_volatile = is_volatile;
    }
  }

  //
  // Function: is_volatile
  // Indicates if the field value is volatile
  //
  // UVM uses the IEEE 1685-2009 IP-XACT definition of "volatility".
  // If TRUE, the value of the register is not predictable because it
  // may change between consecutive accesses.
  // This typically indicates a field whose value is updated by the DUT.
  // The nature or cause of the change is not specified.
  // If FALSE, the value of the register is not modified between
  // consecutive accesses.
  //
  // extern virtual function bool is_volatile();
  // is_volatile

  bool is_volatile() {
    synchronized(this) {
      return _m_volatile;
    }
  }

  //--------------
  // Group: Access
  //--------------


  // Function: set
  //
  // Set the desired value for this field
  //
  // It sets the desired value of the field to the specified ~value~
  // modified by the field access policy.
  // It does not actually set the value of the field in the design,
  // only the desired value in the abstraction class.
  // Use the <uvm_reg::update()> method to update the actual register
  // with the desired value or the <uvm_reg_field::write()> method
  // to actually write the field and update its mirrored value.
  //
  // The final desired value in the mirror is a function of the field access
  // policy and the set value, just like a normal physical write operation
  // to the corresponding bits in the hardware.
  // As such, this method (when eventually followed by a call to
  // <uvm_reg::update()>)
  // is a zero-time functional replacement for the <uvm_reg_field::write()>
  // method.
  // For example, the desired value of a read-only field is not modified
  // by this method and the desired value of a write-once field can only
  // be set if the field has not yet been
  // written to using a physical (for example, front-door) write operation.
  //
  // Use the <uvm_reg_field::predict()> to modify the mirrored value of
  // the field.
  //
  // extern virtual function void set(uvm_reg_data_t  value,
  // 				   string          fname = "",
  // 				   int             lineno = 0);

  // set

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
		    format("Specified value (0x%h) greater than field \"%s\" size (%0d bits)",
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

 
  
  // Function: get
  //
  // Return the desired value of the field
  //
  // It does not actually read the value
  // of the field in the design, only the desired value
  // in the abstraction class. Unless set to a different value
  // using the <uvm_reg_field::set()>, the desired value
  // and the mirrored value are identical.
  //
  // Use the <uvm_reg_field::read()> or <uvm_reg_field::peek()>
  // method to get the actual field value. 
  //
  // If the field is write-only, the desired/mirrored
  // value is the value last written and assumed
  // to reside in the bits implementing it.
  // Although a physical read operation would something different,
  // the returned value is the actual content.
  //
  // extern virtual function uvm_reg_data_t get(string fname = "",
  //                                            int    lineno = 0);


  // get

  uvm_reg_data_t  get(string  fname = "",
		      int     lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      return _m_desired;
    }
  }
 
  // Function: get_mirrored_value
  //
  // Return the mirrored value of the field
  //
  // It does not actually read the value of the field in the design, only the mirrored value
  // in the abstraction class. 
  //
  // If the field is write-only, the desired/mirrored
  // value is the value last written and assumed
  // to reside in the bits implementing it.
  // Although a physical read operation would something different,
  // the returned value is the actual content.
  //
  // extern virtual function uvm_reg_data_t get_mirrored_value(string fname = "",
  //                                            int    lineno = 0);
  // get_mirrored_value

  uvm_reg_data_t  get_mirrored_value(string  fname = "",
				     int     lineno = 0) {
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      return _m_mirrored;
    }
  }

  // Function: reset
  //
  // Reset the desired/mirrored value for this field.
  //
  // It sets the desired and mirror value of the field
  // to the reset event specified by ~kind~.
  // If the field does not have a reset value specified for the
  // specified reset ~kind~ the field is unchanged.
  //
  // It does not actually reset the value of the field in the design,
  // only the value mirrored in the field abstraction class.
  //
  // Write-once fields can be modified after
  // a "HARD" reset operation.
  //
  // extern virtual function void reset(string kind = "HARD");

  // reset

  void reset(string kind = "HARD") {
    synchronized(this) {
      if (kind !in _m_reset) return;
   
      _m_mirrored = _m_reset[kind];
      _m_desired  = _m_mirrored;
      _value      = _m_mirrored;

      if (kind == "HARD") _m_written  = 0;
    }
  }

  // Function: get_reset
  //
  // Get the specified reset value for this field
  //
  // Return the reset value for this field
  // for the specified reset ~kind~.
  // Returns the current field value is no reset value has been
  // specified for the specified reset event.
  //
  // extern virtual function uvm_reg_data_t get_reset(string kind = "HARD");

  // get_reset

  uvm_reg_data_t get_reset(string kind = "HARD") {
    synchronized(this) {
      if (kind !in _m_reset) return _m_desired;
      return _m_reset[kind];
    }
  }




  // Function: has_reset
  //
  // Check if the field has a reset value specified
  //
  // Return TRUE if this field has a reset value specified
  // for the specified reset ~kind~.
  // If ~delete~ is TRUE, removes the reset value, if any.
  //
  // extern virtual function bool has_reset(string kind = "HARD",
  //                                       bool   delete = 0);

  // has_reset

  bool has_reset(string kind = "HARD",
		 bool   remove = false) {
    synchronized(this) {
      if (kind !in _m_reset) return false;

      if (remove) _m_reset.remove(kind);

      return true;
    }
  }

  // Function: set_reset
  //
  // Specify or modify the reset value for this field
  //
  // Specify or modify the reset value for this field corresponding
  // to the cause specified by ~kind~.
  //
  // extern virtual function void set_reset(uvm_reg_data_t value,
  // 					 string kind = "HARD");

  // set_reset

  void set_reset(uvm_reg_data_t value,
		 string kind = "HARD") {
    synchronized(this) {
      _m_reset[kind] = value & ((1L << _m_size) - 1);
    }
  }

  // Function: needs_update
  //
  // Check if the abstract model contains different desired and mirrored values.
  //
  // If a desired field value has been modified in the abstraction class
  // without actually updating the field in the DUT,
  // the state of the DUT (more specifically what the abstraction class
  // ~thinks~ the state of the DUT is) is outdated.
  // This method returns TRUE
  // if the state of the field in the DUT needs to be updated 
  // to match the desired value.
  // The mirror values or actual content of DUT field are not modified.
  // Use the <uvm_reg::update()> to actually update the DUT field.
  //
  // extern virtual function bool needs_update();

  // needs_update

  bool needs_update() {
    synchronized(this) {
      return (_m_mirrored != _m_desired);
    }
  }


  // Task: write
  //
  // Write the specified value in this field
  //
  // Write ~value~ in the DUT field that corresponds to this
  // abstraction class instance using the specified access
  // ~path~. 
  // If the register containing this field is mapped in more
  //  than one address map, 
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  // If a back-door access path is used, the effect of writing
  // the field through a physical access is mimicked. For
  // example, read-only bits in the field will not be written.
  //
  // The mirrored value will be updated using the <uvm_reg_field::predict()>
  // method.
  //
  // If a front-door access is used, and
  // if the field is the only field in a byte lane and
  // if the physical interface corresponding to the address map used
  // to access the field support byte-enabling,
  // then only the field is written.
  // Otherwise, the entire register containing the field is written,
  // and the mirrored values of the other fields in the same register
  // are used in a best-effort not to modify their value.
  //
  // If a backdoor access is used, a peek-modify-poke process is used.
  // in a best-effort not to modify the value of the other fields in the
  // register.
  //
  // extern virtual task write (output uvm_status_e       status,
  // 			     input  uvm_reg_data_t     value,
  // 			     input  uvm_path_e         path = UVM_DEFAULT_PATH,
  // 			     input  uvm_reg_map        map = null,
  // 			     input  uvm_sequence_base  parent = null,
  // 			     input  int                prior = -1,
  // 			     input  uvm_object         extension = null,
  // 			     input  string             fname = "",
  // 			     input  int                lineno = 0);

  // write
  // task
  void write(T)(out uvm_status_e   status,
		T                  value,
		uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
		uvm_reg_map        map = null,
		uvm_sequence_base  parent = null,
		int                prior = -1,
		uvm_object         extension = null,
		string             fname = "",
		int                lineno = 0) {
    uvm_reg_data_t value_ = value;
    write(status, value_, path, map, parent, prior, extension,
	  fname, lineno);
  }

  void write(out uvm_status_e   status,
	     uvm_reg_data_t     value,
	     uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
	     uvm_reg_map        map = null,
	     uvm_sequence_base  parent = null,
	     int                prior = -1,
	     uvm_object         extension = null,
	     string             fname = "",
	     int                lineno = 0) {

    uvm_reg_item rw;
    rw = uvm_reg_item.type_id.create("field_write_item", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_FIELD;
      rw.kind         = UVM_WRITE;
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

    do_write(rw);

    synchronized(rw) {
      status = rw.status;
    }
  }


  // Task: read
  //
  // Read the current value from this field
  //
  // Read and return ~value~ from the DUT field that corresponds to this
  // abstraction class instance using the specified access
  // ~path~. 
  // If the register containing this field is mapped in more
  // than one address map, an address ~map~ must be
  // specified if a physical access is used (front-door access).
  // If a back-door access path is used, the effect of reading
  // the field through a physical access is mimicked. For
  // example, clear-on-read bits in the filed will be set to zero.
  //
  // The mirrored value will be updated using the <uvm_reg_field::predict()>
  // method.
  //
  // If a front-door access is used, and
  // if the field is the only field in a byte lane and
  // if the physical interface corresponding to the address map used
  // to access the field support byte-enabling,
  // then only the field is read.
  // Otherwise, the entire register containing the field is read,
  // and the mirrored values of the other fields in the same register
  // are updated.
  //
  // If a backdoor access is used, the entire containing register is peeked
  // and the mirrored value of the other fields in the register is updated.
  //
  // extern virtual task read  (output uvm_status_e       status,
  // 			     output uvm_reg_data_t     value,
  // 			     input  uvm_path_e         path = UVM_DEFAULT_PATH,
  // 			     input  uvm_reg_map        map = null,
  // 			     input  uvm_sequence_base  parent = null,
  // 			     input  int                prior = -1,
  // 			     input  uvm_object         extension = null,
  // 			     input  string             fname = "",
  // 			     input  int                lineno = 0);
               
  // read

  // task
  void read(out uvm_status_e   status,
	    out uvm_reg_data_t value,
	    uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
	    uvm_reg_map        map = null,
	    uvm_sequence_base  parent = null,
	    int                prior = -1,
	    uvm_object         extension = null,
	    string             fname = "",
	    int                lineno = 0) {

    uvm_reg_item rw;
    rw = uvm_reg_item.type_id.create("field_read_item", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_FIELD;
      rw.kind         = UVM_READ;
      // rw.value[0]     = 0;
      rw.set_value(0, 0);
      rw.path         = path;
      rw.map          = map;
      rw.parent       = parent;
      rw.prior        = prior;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }
    do_read(rw);

    synchronized(rw) {
      // value = rw.value[0];
      value = rw.get_value(0);
      status = rw.status;
    }
  }

  // Task: poke
  //
  // Deposit the specified value in this field
  //
  // Deposit the value in the DUT field corresponding to this
  // abstraction class instance, as-is, using a back-door access.
  // A peek-modify-poke process is used
  // in a best-effort not to modify the value of the other fields in the
  // register.
  //
  // The mirrored value will be updated using the <uvm_reg_field::predict()>
  // method.
  //
  // extern virtual task poke  (output uvm_status_e       status,
  //                            input  uvm_reg_data_t     value,
  //                            input  string             kind = "",
  //                            input  uvm_sequence_base  parent = null,
  //                            input  uvm_object         extension = null,
  //                            input  string             fname = "",
  //                            input  int                lineno = 0);

  // poke

  // task
  void poke(out uvm_status_e  status,
	    uvm_reg_data_t    value,
	    string            kind = "",
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {
    uvm_reg_data_t  tmp;
    uvm_reg m_parent_;
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;

      if (value >> _m_size) {
	uvm_warning("RegModel",
		    "poke(): Value exceeds size of field '" ~
		    get_name() ~ "'");
	value &= value & ((1<<_m_size)-1);
      }
      m_parent_ = _m_parent;
    }
    m_parent_.XatomicX(1);
    m_parent_.m_is_locked_by_field = true;

    tmp = 0;

    // What is the current values of the other fields???
    m_parent_.peek(status, tmp, kind, parent, extension, fname, lineno);

    if (status == UVM_NOT_OK) {
      uvm_error("RegModel", "poke(): Peek of register '" ~ 
		m_parent_.get_full_name() ~ "' returned status " ~
		status.to!string);
      m_parent_.XatomicX(0);
      m_parent_.m_is_locked_by_field = false;
      return;
    }
      

    // Force the value for this field then poke the resulting value
    tmp &= ~(((1<<_m_size)-1) << _m_lsb);
    tmp |= value << _m_lsb;
    m_parent_.poke(status, tmp, kind, parent, extension, fname, lineno);

    m_parent_.XatomicX(0);
    m_parent_.m_is_locked_by_field = false;
  }

  // Task: peek
  //
  // Read the current value from this field
  //
  // Sample the value in the DUT field corresponding to this
  // absraction class instance using a back-door access.
  // The field value is sampled, not modified.
  //
  // Uses the HDL path for the design abstraction specified by ~kind~.
  //
  // The entire containing register is peeked
  // and the mirrored value of the other fields in the register
  // are updated using the <uvm_reg_field::predict()> method.
  //
  //
  // extern virtual task peek  (output uvm_status_e       status,
  // 			     output uvm_reg_data_t     value,
  // 			     input  string             kind = "",
  // 			     input  uvm_sequence_base  parent = null,
  // 			     input  uvm_object         extension = null,
  // 			     input  string             fname = "",
  // 			     input  int                lineno = 0);
               
  // peek

  // task
  void peek(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    string                kind = "",
	    uvm_sequence_base     parent = null,
	    uvm_object            extension = null,
	    string                fname = "",
	    int                   lineno = 0) {
    uvm_reg_data_t  reg_value;
    uvm_reg m_parent_;
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      m_parent_ = _m_parent;
    }

    m_parent_.peek(status, reg_value, kind, parent, extension, fname, lineno);
    value = (reg_value >> _m_lsb) & ((1L << _m_size))-1;
  }
               


  // Task: mirror
  //
  // Read the field and update/check its mirror value
  //
  // Read the field and optionally compared the readback value
  // with the current mirrored value if ~check~ is <UVM_CHECK>.
  // The mirrored value will be updated using the <predict()>
  // method based on the readback value.
  //
  // The ~path~ argument specifies whether to mirror using 
  // the  <UVM_FRONTDOOR> (<read>) or
  // or <UVM_BACKDOOR> (<peek()>).
  //
  // If ~check~ is specified as <UVM_CHECK>,
  // an error message is issued if the current mirrored value
  // does not match the readback value, unless <set_compare> was used
  // disable the check.
  //
  // If the containing register is mapped in multiple address maps and physical
  // access is used (front-door access), an address ~map~ must be specified.
  // For write-only fields, their content is mirrored and optionally
  // checked only if a UVM_BACKDOOR
  // access path is used to read the field. 
  //
  // extern virtual task mirror(output uvm_status_e      status,
  //                            input  uvm_check_e       check = UVM_NO_CHECK,
  //                            input  uvm_path_e        path = UVM_DEFAULT_PATH,
  //                            input  uvm_reg_map       map = null,
  //                            input  uvm_sequence_base parent = null,
  //                            input  int               prior = -1,
  //                            input  uvm_object        extension = null,
  //                            input  string            fname = "",
  //                            input  int               lineno = 0);


  // mirror

  // task
  void mirror(out uvm_status_e  status,
	      uvm_check_e       check = uvm_check_e.UVM_NO_CHECK,
	      uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
	      uvm_reg_map       map = null,
	      uvm_sequence_base parent = null,
	      int               prior = -1,
	      uvm_object        extension = null,
	      string            fname = "",
	      int               lineno = 0) {
    uvm_reg m_parent_;
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;
      m_parent_ = _m_parent;
    }
    
    m_parent_.mirror(status, check, path, map, parent, prior, extension,
		     fname, lineno);
  }

  // Function: set_compare
  //
  // Sets the compare policy during a mirror update. 
  // The field value is checked against its mirror only when both the
  // ~check~ argument in <uvm_reg_block::mirror>, <uvm_reg::mirror>,
  // or <uvm_reg_field::mirror> and the compare policy for the
  // field is <UVM_CHECK>.
  //
  // extern function void set_compare(uvm_check_e check=UVM_CHECK);

  // set_compare

  void set_compare(uvm_check_e check = uvm_check_e.UVM_CHECK) {
    synchronized(this) {
      _m_check = check;
    }
  }

  // Function: get_compare
  //
  // Returns the compare policy for this field.
  //
  // extern function uvm_check_e get_compare();

  // get_compare

  uvm_check_e get_compare() {
    synchronized(this) {
      return _m_check;
    }
  }
   
  // Function: is_indv_accessible
  //
  // Check if this field can be written individually, i.e. without
  // affecting other fields in the containing register.
  //
  // extern function bool is_indv_accessible (uvm_path_e  path,
  //                                         uvm_reg_map local_map);

  // is_indv_accessible

  final bool is_indv_accessible(uvm_path_e  path,
				uvm_reg_map local_map) {
    synchronized(this) {
      if(path == UVM_BACKDOOR) {
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
      if (adapter.supports_byte_enable)	return true;

      size_t fld_idx;
      int bus_width = local_map.get_n_bytes();
      uvm_reg_field[] fields;
      bool sole_field;

      _m_parent.get_fields(fields);

      if (fields.length == 1) {
	sole_field = 1;
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


  // Function: predict
  //
  // Update the mirrored value for this field.
  //
  // Predict the mirror value of the field based on the specified
  // observed ~value~ on a bus using the specified address ~map~.
  //
  // If ~kind~ is specified as <UVM_PREDICT_READ>, the value
  // was observed in a read transaction on the specified address ~map~ or
  // backdoor (if ~path~ is <UVM_BACKDOOR>).
  // If ~kind~ is specified as <UVM_PREDICT_WRITE>, the value
  // was observed in a write transaction on the specified address ~map~ or
  // backdoor (if ~path~ is <UVM_BACKDOOR>).
  // If ~kind~ is specified as <UVM_PREDICT_DIRECT>, the value
  // was computed and is updated as-is, without regard to any access policy.
  // For example, the mirrored value of a read-only field is modified
  // by this method if ~kind~ is specified as <UVM_PREDICT_DIRECT>.
  //
  // This method does not allow an update of the mirror
  // when the register containing this field is busy executing
  // a transaction because the results are unpredictable and
  // indicative of a race condition in the testbench.
  //
  // Returns TRUE if the prediction was succesful.
  //
  // extern function bool predict (uvm_reg_data_t    value,
  //                               uvm_reg_byte_en_t be = -1,
  //                               uvm_predict_e     kind = UVM_PREDICT_DIRECT,
  //                               uvm_path_e        path = UVM_FRONTDOOR,
  //                               uvm_reg_map       map = null,
  //                               string            fname = "",
  //                               int               lineno = 0);

  // predict

  bool predict (uvm_reg_data_t    value,
		uvm_reg_byte_en_t be = -1,
		uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		uvm_path_e        path = uvm_path_e.UVM_FRONTDOOR,
		uvm_reg_map       map = null,
		string            fname = "",
		int               lineno = 0) {
    uvm_reg_item rw = new uvm_reg_item();
    synchronized(rw) {
      // rw.value[0] = value;
      rw.set_value(0, value);
      rw.path = path;
      rw.map = map;
      rw.fname = fname;
      rw.lineno = lineno;
      do_predict(rw, kind, be);
      return (rw.status == UVM_NOT_OK) ? false : true;
    }
  }

  /*local*/
  // extern virtual function uvm_reg_data_t XpredictX (uvm_reg_data_t cur_val,
  // 						    uvm_reg_data_t wr_val,
  // 						    uvm_reg_map    map);

  // XpredictX

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
      case "WC":    return uvm_reg_data_t(0);
      case "WS":    return mask;
      case "WRC":   return wr_val;
      case "WRS":   return wr_val;
      case "WSRC":  return mask;
      case "WCRS":  return uvm_reg_data_t(0);
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
      case "WOC":   return uvm_reg_data_t(0);
      case "WOS":   return mask;
      case "W1":    return (_m_written) ? cur_val : wr_val;
      case "WO1":   return (_m_written) ? cur_val : wr_val;
      default:      return wr_val;
      }
      // this statement is not even reachable, but there in the SV version
      // uvm_fatal("RegModel", "XpredictX(): Internal error");
      // return uvm_reg_data_t(0);
    }
  }

  /*local*/
  // extern virtual function uvm_reg_data_t XupdateX();
  
  // XupdateX

  uvm_reg_data_t  XupdateX() {
    // Figure out which value must be written to get the desired value
    // given what we think is the current value in the hardware
    uvm_reg_data_t XupdateX_ = 0;

    switch (_m_access) {
    case "RO":    XupdateX_ = _m_desired; break;
    case "RW":    XupdateX_ = _m_desired; break;
    case "RC":    XupdateX_ = _m_desired; break;
    case "RS":    XupdateX_ = _m_desired; break;
    case "WRC":   XupdateX_ = _m_desired; break;
    case "WRS":   XupdateX_ = _m_desired; break;
    case "WC":    XupdateX_ = _m_desired; break;  // Warn if != 0
    case "WS":    XupdateX_ = _m_desired; break;  // Warn if != 1
    case "WSRC":  XupdateX_ = _m_desired; break;  // Warn if != 1
    case "WCRS":  XupdateX_ = _m_desired; break;  // Warn if != 0
    case "W1C":   XupdateX_ = ~_m_desired; break;
    case "W1S":   XupdateX_ = _m_desired; break;
    case "W1T":   XupdateX_ = _m_desired ^ _m_mirrored; break;
    case "W0C":   XupdateX_ = _m_desired; break;
    case "W0S":   XupdateX_ = ~_m_desired; break;
    case "W0T":   XupdateX_ = ~(_m_desired ^ _m_mirrored); break;
    case "W1SRC": XupdateX_ = _m_desired; break;
    case "W1CRS": XupdateX_ = ~_m_desired; break;
    case "W0SRC": XupdateX_ = ~_m_desired; break;
    case "W0CRS": XupdateX_ = _m_desired; break;
    case "WO":    XupdateX_ = _m_desired; break;
    case "WOC":   XupdateX_ = _m_desired; break;  // Warn if != 0
    case "WOS":   XupdateX_ = _m_desired; break;  // Warn if != 1
    case "W1":    XupdateX_ = _m_desired; break;
    case "WO1":   XupdateX_ = _m_desired; break;
    default: XupdateX_ = _m_desired; break;
    }
    XupdateX_ &= (1L << _m_size) - 1;
    return XupdateX_;
  }

  /*local*/
  // extern  bool Xcheck_accessX (input uvm_reg_item rw,
  //                                      output uvm_reg_map_info map_info,
  //                                      input string caller);
  // Xcheck_accessX

  bool Xcheck_accessX(uvm_reg_item rw,
		      out uvm_reg_map_info map_info,
		      string caller) {
    synchronized(this) {
                        
      if (rw.path == UVM_DEFAULT_PATH) {
	uvm_reg_block blk = _m_parent.get_block();
	rw.path = blk.get_default_path();
      }

      if (rw.path == UVM_BACKDOOR) {
	if (_m_parent.get_backdoor() is null && !_m_parent.has_hdl_path()) {
	  uvm_warning("RegModel",
		      "No backdoor access available for field '" ~ get_full_name() ~ 
		      "' . Using frontdoor instead.");
	  rw.path = UVM_FRONTDOOR;
	}
	else
	  rw.map = uvm_reg_map.backdoor();
      }

      if (rw.path != UVM_BACKDOOR) {

	rw.local_map = _m_parent.get_local_map(rw.map,caller);

	if (rw.local_map is null) {
	  uvm_error(get_type_name(), 
		    "No transactor available to physically access memory from map '" ~ 
		    rw.map.get_full_name() ~ "'");
	  rw.status = UVM_NOT_OK;
	  return false;
	}

	map_info = rw.local_map.get_reg_map_info(_m_parent);

	if (map_info.frontdoor is null && map_info.unmapped) {
	  uvm_error("RegModel", "Field '" ~ get_full_name() ~ 
		    "' in register that is unmapped in map '" ~ 
		    rw.map.get_full_name() ~ 
		    "' and does not have a user-defined frontdoor");
	  rw.status = UVM_NOT_OK;
	  return false;
	}

	if (rw.map is null) {
	  rw.map = rw.local_map;
	}
      }

      return true;
    }
  }



  // extern virtual task do_write(uvm_reg_item rw);

  // do_write

  // task
  void do_write(uvm_reg_item rw) {

    uvm_reg_data_t   value_adjust;
    uvm_reg_map_info map_info;
    uvm_reg_field[]  fields;
    bool             bad_side_effect;

    uvm_reg          m_parent_;

    synchronized(this) {
      m_parent_ = _m_parent;
    }

    m_parent_.XatomicX(1);
    synchronized(this) {
      _m_fname  = rw.fname;
      _m_lineno = rw.lineno;

      if (!Xcheck_accessX(rw,map_info,"write()")) return;

      _m_write_in_progress = 1;

      // if (rw.value[0] >> _m_size) {
      if (rw.get_value(0) >> _m_size) {
	uvm_warning("RegModel", "write(): Value greater than field '" ~ 
		    get_full_name() ~ "'");
	// rw.value[0] &= ((1L << _m_size)-1);
	rw.and_value(0, ((1L << _m_size)-1));
      }

      // Get values to write to the other fields in register
      m_parent_.get_fields(fields);
      foreach (i, field; fields) {

	if (field == this) {
	  // value_adjust |= rw.value[0] << _m_lsb;
	  value_adjust |= rw.get_value(0) << _m_lsb;
	  continue;
	}

	// It depends on what kind of bits they are made of...
	switch (field.get_access(rw.local_map)) {
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
	rw.element_kind = UVM_REG;
	rw.element = m_parent_;
	rw.value[0] = value_adjust;
      }
      m_parent_.do_write(rw);
    }
    else {

      if (!is_indv_accessible(rw.path, rw.local_map)) {
	synchronized(this) {
	  rw.element_kind = UVM_REG;
	  rw.element = m_parent_;
	  // rw.value[0] = value_adjust;
	  rw.set_value(0, value_adjust);
	}
	m_parent_.do_write(rw);

	if (bad_side_effect) {
	  uvm_warning("RegModel", format("Writing field \"%s\" will cause unintended" ~
					 " side effects in adjoining Write-to-Clear" ~
					 " or Write-to-Set fields in the same register",
					 this.get_full_name()));
	}
      }
      else {

	uvm_reg_map system_map = rw.local_map.get_root_map();
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter(this);

	m_parent_.Xset_busyX(1);

	rw.status = UVM_IS_OK;
      
	pre_write(rw);
	for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
	  cb.pre_write(rw);

	if (rw.status != UVM_IS_OK) {
	  m_write_in_progress = 0;
	  m_parent_.Xset_busyX(0);
	  m_parent_.XatomicX(0);
        
	  return;
	}
            
	rw.local_map.do_write(rw);

	if (system_map.get_auto_predict())
	  // ToDo: Call parent.XsampleX();
	  do_predict(rw, UVM_PREDICT_WRITE);

	post_write(rw);
	for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
	  cb.post_write(rw);

	m_parent_.Xset_busyX(0);
      
      }
    }

    m_write_in_progress = 0;
    m_parent_.XatomicX(0);
  }

  // extern virtual task do_read(uvm_reg_item rw);
  // do_read

  // task
  void do_read(uvm_reg_item rw) {

    uvm_reg_map_info map_info;
    bool bad_side_effect;

    _m_parent.XatomicX(1);
    _m_fname  = rw.fname;
    _m_lineno = rw.lineno;
    _m_read_in_progress = 1;
  
    if (!Xcheck_accessX(rw,map_info,"read()"))
      return;

    version(UVM_REG_NO_INDIVIDUAL_FIELD_ACCESS) {
      rw.element_kind = UVM_REG;
      rw.element = _m_parent;
      _m_parent.do_read(rw);
      rw.value[0] = (rw.value[0] >> _m_lsb) & ((1<<_m_size))-1;
      bad_side_effect = 1;
    }
    else {

      if (!is_indv_accessible(rw.path,rw.local_map)) {
	rw.element_kind = UVM_REG;
	rw.element = _m_parent;
	bad_side_effect = 1;
	_m_parent.do_read(rw);
	// rw.value[0] = (rw.value[0] >> _m_lsb) & ((1<<_m_size))-1;
	rw.set_value(0, (rw.get_value(0) >> _m_lsb) & ((1<<_m_size))-1);
      }
      else {

	uvm_reg_map system_map = rw.local_map.get_root_map();
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter(this);

	_m_parent.Xset_busyX(1);

	rw.status = UVM_IS_OK;
      
	pre_read(rw);
	for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
	  cb.pre_read(rw);
	}

	if (rw.status != UVM_IS_OK) {
	  _m_read_in_progress = 0;
	  _m_parent.Xset_busyX(0);
	  _m_parent.XatomicX(0);

	  return;
	}
            
	rw.local_map.do_read(rw);


	if (system_map.get_auto_predict())
	  // ToDo: Call parent.XsampleX();
	  do_predict(rw, UVM_PREDICT_READ);

	post_read(rw);
	for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
	  cb.post_read(rw);

	_m_parent.Xset_busyX(0);
      
      }
    }

    _m_read_in_progress = 0;
    _m_parent.XatomicX(0);

    if (bad_side_effect) {
      uvm_reg_field[] fields;
      _m_parent.get_fields(fields);
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

  // extern virtual function void do_predict 
  //                                (uvm_reg_item rw,
  //                                 uvm_predict_e kind=UVM_PREDICT_DIRECT,
  //                                 uvm_reg_byte_en_t be = -1);

  // do_predict

  void do_predict(uvm_reg_item      rw,
		  uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		  uvm_reg_byte_en_t be = -1) {
    synchronized(this) {
      // uvm_reg_data_t field_val = rw.value[0] & ((1 << _m_size)-1);
      uvm_reg_data_t field_val = rw.get_value(0) & ((1 << _m_size)-1);

      if (rw.status != UVM_NOT_OK)
	rw.status = UVM_IS_OK;

      // Assume that the entire field is enabled
      if (!be[0]) return;

      _m_fname = rw.fname;
      _m_lineno = rw.lineno;

      switch (kind) {

      case UVM_PREDICT_WRITE:
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter (this);

	if (rw.path == UVM_FRONTDOOR || rw.path == UVM_PREDICT)
	  field_val = XpredictX(_m_mirrored, field_val, rw.map);

	_m_written = 1;

	for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
	  cb.post_predict(this, _m_mirrored, field_val, 
			  UVM_PREDICT_WRITE, rw.path, rw.map);

	field_val &= (1L << _m_size)-1;
	break;

      case UVM_PREDICT_READ:
	uvm_reg_field_cb_iter cbs = new uvm_reg_field_cb_iter(this);

	if (rw.path == UVM_FRONTDOOR || rw.path == UVM_PREDICT) {

	  string acc = get_access(rw.map);

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
		   acc == "WO1")
	    return;
	}

	for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next()) {
	  cb.post_predict(this, _m_mirrored, field_val,
			  UVM_PREDICT_READ, rw.path, rw.map);
	}
	field_val &= (1L << _m_size)-1;
	break;

      case UVM_PREDICT_DIRECT:
	if (_m_parent.is_busy()) {
	  uvm_warning("RegModel", "Trying to predict value of field '" ~
		      get_name() ~ "' while register '" ~
		      _m_parent.get_full_name() ~ "' is being accessed");
	  rw.status = UVM_NOT_OK;
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

               


  // extern function void pre_randomize();
  // pre_randomize

  void pre_randomize() {
    // Update the only publicly known property with the current
    // desired value so it can be used as a state variable should
    // the rand_mode of the field be turned off.
    synchronized(this) {
      _value = _m_desired;
    }
  }

  // extern function void post_randomize();
  // post_randomize

  void post_randomize() {
    synchronized(this) {
      _m_desired = _value;
    }
  }



  //-----------------
  // Group: Callbacks
  //-----------------

  mixin uvm_register_cb!(uvm_reg_cbs);


  // Task: pre_write
  //
  // Called before field write.
  //
  // If the specified data value, access ~path~ or address ~map~ are modified,
  // the updated data value, access path or address map will be used
  // to perform the register operation.
  // If the ~status~ is modified to anything other than <UVM_IS_OK>,
  // the operation is aborted.
  //
  // The field callback methods are invoked after the callback methods
  // on the containing register.
  // The registered callback methods are invoked after the invocation
  // of this method.
  //
  // virtual task pre_write  (uvm_reg_item rw);

  // task
  void pre_write(uvm_reg_item rw) { }

  // Task: post_write
  //
  // Called after field write.
  //
  // If the specified ~status~ is modified,
  // the updated status will be
  // returned by the register operation.
  //
  // The field callback methods are invoked after the callback methods
  // on the containing register.
  // The registered callback methods are invoked before the invocation
  // of this method.
  //
  // virtual task post_write (uvm_reg_item rw);

  // task
  void post_write(uvm_reg_item rw) {}


  // Task: pre_read
  //
  // Called before field read.
  //
  // If the access ~path~ or address ~map~ in the ~rw~ argument are modified,
  // the updated access path or address map will be used to perform
  // the register operation.
  // If the ~status~ is modified to anything other than <UVM_IS_OK>,
  // the operation is aborted.
  //
  // The field callback methods are invoked after the callback methods
  // on the containing register.
  // The registered callback methods are invoked after the invocation
  // of this method.
  //
  // virtual task pre_read (uvm_reg_item rw);

  // task
  void pre_read (uvm_reg_item rw) {}


  // Task: post_read
  //
  // Called after field read.
  //
  // If the specified readback data or~status~ in the ~rw~ argument is
  // modified, the updated readback data or status will be
  // returned by the register operation.
  //
  // The field callback methods are invoked after the callback methods
  // on the containing register.
  // The registered callback methods are invoked before the invocation
  // of this method.
  //
  // virtual task post_read  (uvm_reg_item rw);

  // task
  void post_read  (uvm_reg_item rw) {}


  // extern virtual function void do_print (uvm_printer printer);
  // do_print

  override void do_print (uvm_printer printer) {
    printer.print_generic(get_name(), get_type_name(), -1, convert2string());
  }

  // extern virtual function string convert2string;

  // convert2string

  override string convert2string() {
    synchronized(this) {
      string convert2string_;
      string res_str;
      string t_str;
      bool with_debug_info;
      string prefix;
      uvm_reg reg_=get_register();

      string fmt = format("%0d'h%%%0dh", get_n_bits(),
			  (get_n_bits()-1)/4 + 1);
      convert2string_ = format("%s %s %s[%0d:%0d]=" ~ fmt ~ "%s", prefix,
			       get_access(),
			       reg_.get_name(),
			       get_lsb_pos() + get_n_bits() - 1,
			       get_lsb_pos(), _m_desired,
			       (_m_desired != _m_mirrored) ? format(" (Mirror: " ~ fmt ~ ")",
								    _m_mirrored) : "");

      if (_m_read_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format(" from %s:%0d",_m_fname, _m_lineno);
	convert2string_ = convert2string_ ~  "\n" ~  "currently being read" ~  res_str; 
      }
      if (_m_write_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format(" from %s:%0d",_m_fname, _m_lineno);
	convert2string_ = convert2string_ ~  "\n" ~  res_str ~  "currently being written"; 
      }
      return convert2string_;
    }
  }

  T to(T)() if(is(T == string)){
    return convert2string();
  }
  
  // extern virtual function uvm_object clone();
  // clone

  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel field cannot be cloned");
    return null;
  }

  // extern virtual function void do_copy   (uvm_object rhs);
  // do_copy

  override void do_copy(uvm_object rhs) {
    uvm_warning("RegModel","RegModel field copy not yet implemented");
    // just a set(rhs.get()) ?
  }


  // extern virtual function bool do_compare (uvm_object  rhs,
  //                                           uvm_comparer comparer);
  // do_compare

  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel field compare not yet implemented");
    // just a return (get() == rhs.get()) ?
    return false;
  }


  // extern virtual function void do_pack (uvm_packer packer);
  // do_pack

  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel field cannot be packed");
  }

  // extern virtual function void do_unpack (uvm_packer packer);
  // do_unpack

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel field cannot be unpacked");
  }

}


//------------------------------------------------------------------------------
// IMPLEMENTATION
//------------------------------------------------------------------------------





