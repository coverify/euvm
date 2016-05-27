//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010-2011 Cadence Design Systems, Inc.
//    Copyright 2014-     Coverify Systems Technology
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

import uvm.seq.uvm_sequence_base;

import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_mem;
import uvm.reg.uvm_reg_file;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_field;
import uvm.reg.uvm_reg_sequence;
import uvm.reg.uvm_reg_backdoor;
import uvm.reg.uvm_reg_cbs;

import uvm.base.uvm_callback;
import uvm.base.uvm_printer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_packer;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_root: uvm_entity_base;

import uvm.dpi.uvm_hdl;

import uvm.meta.misc;

import esdl.base.core: Process;
import esdl.data.bvec;
import esdl.base.comm: SemaphoreObj;

import std.string: format;

// typedef class uvm_reg_cbs;
// typedef class uvm_reg_frontdoor;

//-----------------------------------------------------------------
// CLASS: uvm_reg
// Register abstraction base class
//
// A register represents a set of fields that are accessible
// as a single entity.
//
// A register may be mapped to one or more address maps,
// each with different access rights and policy.
//-----------------------------------------------------------------
abstract class uvm_reg: uvm_object
{
  mixin(uvm_sync_string);
  private bool              _m_locked;
  private uvm_reg_block     _m_parent;
  private uvm_reg_file      _m_regfile_parent;
  private uint              _m_n_bits;
  private uint              _m_n_used_bits;
  protected bool[uvm_reg_map]            _m_maps;
  protected uvm_reg_field[] _m_fields;   // Fields in LSB to MSB order
  private int               _m_has_cover;
  private int               _m_cover_on;
  @uvm_immutable_sync
  private SemaphoreObj      _m_atomic;
  @uvm_public_sync
  private Process           _m_process;
  private string            _m_fname;
  private int               _m_lineno;
  private bool              _m_read_in_progress;
  private bool              _m_write_in_progress; 
  protected bool            _m_update_in_progress;
  /*private*/
  @uvm_public_sync
  bool                      _m_is_busy;
  /*private*/
  @uvm_public_sync
  bool                      _m_is_locked_by_field;
  private uvm_reg_backdoor  _m_backdoor;

  private static uint       _m_max_size;

  private uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))
  _m_hdl_paths_pool;

  //----------------------
  // Group: Initialization
  //----------------------

  // Function: new
  //
  // Create a new instance and type-specific configuration
  //
  // Creates an instance of a register abstraction class with the specified
  // name.
  //
  // ~n_bits~ specifies the total number of bits in the register.
  // Not all bits need to be implemented.
  // This value is usually a multiple of 8.
  //
  // ~has_coverage~ specifies which functional coverage models are present in
  // the extension of the register abstraction class.
  // Multiple functional coverage models may be specified by adding their
  // symbolic names, as defined by the <uvm_coverage_model_e> type.
  //

  // extern function new(string name="",
  // 		       uint n_bits,
  // 		       int has_coverage);

  // new

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
      _m_locked      = 0;
      _m_is_busy     = 0;
      _m_is_locked_by_field = false;
      _m_hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))("hdl_paths");

      if (n_bits > _m_max_size) {
	_m_max_size = n_bits;
      }
    }
  }


  // Function: configure
  //
  // Instance-specific configuration
  //
  // Specify the parent block of this register.
  // May also set a parent register file for this register,
  //
  // If the register is implemented in a single HDL variable,
  // it's name is specified as the ~hdl_path~.
  // Otherwise, if the register is implemented as a concatenation
  // of variables (usually one per field), then the HDL path
  // must be specified using the <add_hdl_path()> or
  // <add_hdl_path_slice> method.
  //

  // extern function void configure (uvm_reg_block blk_parent,
  //                                 uvm_reg_file regfile_parent = null,
  //                                 string hdl_path = "");

  // configure

  final void configure (uvm_reg_block blk_parent,
			uvm_reg_file regfile_parent=null,
			string hdl_path = "") {
    synchronized(this) {
      _m_parent = blk_parent;
      _m_parent.add_reg(this);
      _m_regfile_parent = regfile_parent;
      if (hdl_path != "") {
	add_hdl_path_slice(hdl_path, -1, -1);
      }
    }
  }


  // Function: set_offset
  //
  // Modify the offset of the register
  //
  // The offset of a register within an address map is set using the
  // <uvm_reg_map::add_reg()> method.
  // This method is used to modify that offset dynamically.
  //  
  // Modifying the offset of a register will make the register model
  // diverge from the specification that was used to create it.
  //

  // extern virtual function void set_offset (uvm_reg_map    map,
  // 					   uvm_reg_addr_t offset,
  // 					   bool            unmapped = 0);

  // set_offset

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

      map = get_local_map(map,"set_offset()");

      if (map is null) {
	return;
      }
   
      map.m_set_reg_offset(this, offset, unmapped);
    }
  }


  // /*local*/ extern virtual function void set_parent (uvm_reg_block blk_parent,
  //                                                    uvm_reg_file regfile_parent);
  // set_parent

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

  // /*local*/ extern virtual function void add_field  (uvm_reg_field field);
  // add_field

  void add_field(uvm_reg_field field) {
    synchronized(this) {
      int offset;
      ptrdiff_t idx;
   
      if (_m_locked) {
	uvm_error("RegModel", "Cannot add field to locked register model");
	return;
      }

      if (field is null)
	uvm_fatal("RegModel", "Attempting to register NULL field");

      // Store fields in LSB to MSB order
      offset = field.get_lsb_pos();

      idx = -1;
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
      }

      _m_n_used_bits += field.get_n_bits();
   
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


  // /*local*/ extern virtual function void add_map    (uvm_reg_map map);
  // add_map

  void add_map(uvm_reg_map map) {
    synchronized(this) {
      _m_maps[map] = 1;
    }
  }



  // /*local*/ extern function void   Xlock_modelX;
  // Xlock_modelX

  void Xlock_modelX() {
    synchronized(this) {
      if (_m_locked) {
	return;
      }
      _m_locked = 1;
    }
  }


  //---------------------
  // Group: Introspection
  //---------------------

  // Function: get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this register.
  //

  // Function: get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this register.
  // The base of the hierarchical name is the root block.
  //
  // extern virtual function string get_full_name();
  // get_full_name

  override string get_full_name() {
    synchronized(this) {
      if (_m_regfile_parent !is null)
	return _m_regfile_parent.get_full_name() ~ "." ~ get_name();

      if (_m_parent !is null)
	return _m_parent.get_full_name() ~ "." ~ get_name();
   
      return get_name();
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

  // Function: get_regfile
  //
  // Get the parent register file
  //
  // Returns ~null~ if this register is instantiated in a block.
  //

  // extern virtual function uvm_reg_file get_regfile ();
  // get_regfile

  uvm_reg_file get_regfile() {
    synchronized(this) {
      return _m_regfile_parent;

    }
  }

  // Function: get_n_maps
  //
  // Returns the number of address maps this register is mapped in
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
  // Returns 1 if this register is in the specified address ~map~
  //

  // extern function bool is_in_map (uvm_reg_map map);
  // is_in_map

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

  // Function: get_maps
  //
  // Returns all of the address ~maps~ where this register is mapped
  //
  // extern virtual function void get_maps (ref uvm_reg_map maps[$]);
  // get_maps

  void get_maps(out uvm_reg_map[] maps) {
    synchronized(this) {
      foreach (map, unused; _m_maps) {
	maps ~= map;
      }
    }
  }


  // /*local*/ extern virtual function uvm_reg_map get_local_map   (uvm_reg_map map,
  //                                                                string caller = "");
  // get_local_map

  uvm_reg_map get_local_map(uvm_reg_map map, string caller="") {
    synchronized(this) {
      if (map is null) {
	return get_default_map();
      }
      if (map in _m_maps) {
	return map;
      }
      foreach (l, unused; _m_maps) {
	uvm_reg_map local_map=l;
	uvm_reg_map parent_map = local_map.get_parent_map();

	while (parent_map !is null) {
	  if (parent_map is map)
	    return local_map;
	  parent_map = parent_map.get_parent_map();
	}
      }
      uvm_warning("RegModel", 
		  "Register '" ~ get_full_name() ~
		  "' is not contained within map '" ~
		  map.get_full_name() ~ "'" ~
		  (caller == "" ? "": " (called from " ~ caller ~ ")"));
      return null;
    }
  }

  // /*local*/ extern virtual function uvm_reg_map get_default_map (string caller = "");
  // get_default_map

  uvm_reg_map get_default_map(string caller="") {
    synchronized(this) {
      // if reg is not associated with any map, return null
      if (_m_maps.length == 0) {
	uvm_warning("RegModel",
		    "Register '" ~ get_full_name() ~
		    "' is not registered with any map" ~
		    (caller == "" ? "": " (called from " ~ caller ~ ")"));
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
	  uvm_reg_map local_map = get_local_map(default_map,"get_default_map()");
	  if (local_map !is null)
	    return local_map;
	}
      }

      // if that fails, choose the first in this reg's maps

      uvm_reg_map map = _m_maps.keys()[0];
      return map;
    }
  }

  // Function: get_rights
  //
  // Returns the accessibility ("RW, "RO", or "WO") of this register in the given ~map~.
  //
  // If no address map is specified and the register is mapped in only one
  // address map, that address map is used. If the register is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // Whether a register field can be read or written depends on both the field's
  // configured access policy (see <uvm_reg_field::configure>) and the register's
  // accessibility rights in the map being used to access the field. 
  //
  // If an address map is specified and
  // the register is not mapped in the specified
  // address map, an error message is issued
  // and "RW" is returned. 
  //
  // extern virtual function string get_rights (uvm_reg_map map = null);

  // get_rights

  string get_rights(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info info;

      map = get_local_map(map,"get_rights()");

      if (map is null) {
	return "RW";
      }

      info = map.get_reg_map_info(this);
      return info.rights;

    }
  }



  // Function: get_n_bits
  //
  // Returns the width, in bits, of this register.
  //
  // extern virtual function uint get_n_bits ();
  // get_n_bits

  uint get_n_bits() {
    synchronized(this) {
      return _m_n_bits;
    }
  }

  // Function: get_n_bytes
  //
  // Returns the width, in bytes, of this register. Rounds up to
  // next whole byte if register is not a multiple of 8.
  //
  // extern virtual function uint get_n_bytes();
  // get_n_bytes

  uint get_n_bytes() {
    synchronized(this) {
      return ((_m_n_bits-1) / 8) + 1;
    }
  }

  // Function: get_max_size
  //
  // Returns the maximum width, in bits, of all registers. 
  //
  // extern static function uint get_max_size();
  // get_max_size

  static uint get_max_size() {
    return _m_max_size;		// static no synchronized lock
  }

  // Function: get_fields
  //
  // Return the fields in this register
  //
  // Fills the specified array with the abstraction class
  // for all of the fields contained in this register.
  // Fields are ordered from least-significant position to most-significant
  // position within the register. 
  //
  // extern virtual function void get_fields (ref uvm_reg_field fields[$]);
  // get_fields

  void get_fields(out uvm_reg_field[] fields) {
    synchronized(this) {
      foreach(i, field; _m_fields) {
	fields ~= field;
      }
    }
  }


  // Function: get_field_by_name
  //
  // Return the named field in this register
  //
  // Finds a field with the specified name in this register
  // and returns its abstraction class.
  // If no fields are found, returns null. 
  //
  // extern virtual function uvm_reg_field get_field_by_name(string name);
  // get_field_by_name

  uvm_reg_field get_field_by_name(string name) {
    synchronized(this) {
      foreach (i, field; _m_fields) {
	if (field.get_name() == name)
	  return field;
      }
      uvm_warning("RegModel", "Unable to locate field '" ~ name ~
		  "' in register '" ~ get_name() ~ "'");
      return null;
    }
  }

  // /*local*/ extern function string Xget_fields_accessX(uvm_reg_map map);
  // Xget_field_accessX
  //
  // Returns "WO" if all of the fields in the registers are write-only
  // Returns "RO" if all of the fields in the registers are read-only
  // Returns "RW" otherwise.

  string Xget_fields_accessX(uvm_reg_map map) {
    synchronized(this) {
      bool is_R;
      bool is_W;
   
      foreach(i, field; _m_fields) {
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

      if(!is_R && is_W) return "WO";
      if(!is_W && is_R) return "RO";

      return "RW";
    }
  }

  // Function: get_offset
  //
  // Returns the offset of this register
  //
  // Returns the offset of this register in an address ~map~.
  //
  // If no address map is specified and the register is mapped in only one
  // address map, that address map is used. If the register is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the register is not mapped in the specified
  // address map, an error message is issued.
  //

  // extern virtual function uvm_reg_addr_t get_offset (uvm_reg_map map = null);
  // get_offset

  uvm_reg_addr_t get_offset(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map orig_map = map;

      map = get_local_map(map,"get_offset()");

      if (map is null)
	return uvm_reg_addr_t(-1);
   
      map_info = map.get_reg_map_info(this);
   
      if (map_info.unmapped) {
	uvm_warning("RegModel", "Register '" ~ get_name() ~ 
		    "' is unmapped in map '" ~
		    ((orig_map is null) ? map.get_full_name() :
		     orig_map.get_full_name()) ~ "'");
	return uvm_reg_addr_t(-1);
      }
         
      return map_info.offset;
    }
  }

  // Function: get_address
  //
  // Returns the base external physical address of this register
  //
  // Returns the base external physical address of this register
  // if accessed through the specified address ~map~.
  //
  // If no address map is specified and the register is mapped in only one
  // address map, that address map is used. If the register is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the register is not mapped in the specified
  // address map, an error message is issued.
  //

  // extern virtual function uvm_reg_addr_t get_address (uvm_reg_map map = null);
  // get_address

  uvm_reg_addr_t get_address(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_addr_t[]  addr;
      get_addresses(map,addr);
      return addr[0];
    }
  }


  // Function: get_addresses
  //
  // Identifies the external physical address(es) of this register
  //
  // Computes all of the external physical addresses that must be accessed
  // to completely read or write this register. The addressed are specified in
  // little endian order.
  // Returns the number of bytes transfered on each access.
  //
  // If no address map is specified and the register is mapped in only one
  // address map, that address map is used. If the register is mapped
  // in more than one address map, the default address map of the
  // parent block is used.
  //
  // If an address map is specified and
  // the register is not mapped in the specified
  // address map, an error message is issued.
  //

  // extern virtual function int get_addresses (uvm_reg_map map = null,
  //                                            ref uvm_reg_addr_t addr[]);
  // get_addresses

  int get_addresses(uvm_reg_map map, ref uvm_reg_addr_t[] addr) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      uvm_reg_map system_map;
      uvm_reg_map orig_map = map;

      map = get_local_map(map,"get_addresses()");

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
      system_map = map.get_root_map();
      return map.get_n_bytes();
    }
  }


  //--------------
  // Group: Access
  //--------------


  // Function: set
  //
  // Set the desired value for this register
  //
  // Sets the desired value of the fields in the register
  // to the specified value. Does not actually
  // set the value of the register in the design,
  // only the desired value in its corresponding
  // abstraction class in the RegModel model.
  // Use the <uvm_reg::update()> method to update the
  // actual register with the mirrored value or
  // the <uvm_reg::write()> method to set
  // the actual register and its mirrored value.
  //
  // Unless this method is used, the desired value is equal to
  // the mirrored value.
  //
  // Refer <uvm_reg_field::set()> for more details on the effect
  // of setting mirror values on fields with different
  // access policies.
  //
  // To modify the mirrored field values to a specific value,
  // and thus use the mirrored as a scoreboard for the register values
  // in the DUT, use the <uvm_reg::predict()> method. 
  //

  // extern virtual function void set (uvm_reg_data_t  value,
  //                                   string          fname = "",
  //                                   int             lineno = 0);
  // set

  void set(uvm_reg_data_t  value,
	   string          fname = "",
	   int             lineno = 0) {
    synchronized(this) {
      // Split the value into the individual fields
      _m_fname = fname;
      _m_lineno = lineno;

      foreach (i, field; _m_fields) {
	field.set((value >> field.get_lsb_pos()) &
		  ((1 << field.get_n_bits()) - 1));
      }
    }
  }

  // Function: get
  //
  // Return the desired value of the fields in the register.
  //
  // Does not actually read the value
  // of the register in the design, only the desired value
  // in the abstraction class. Unless set to a different value
  // using the <uvm_reg::set()>, the desired value
  // and the mirrored value are identical.
  //
  // Use the <uvm_reg::read()> or <uvm_reg::peek()>
  // method to get the actual register value. 
  //
  // If the register contains write-only fields, the desired/mirrored
  // value for those fields are the value last written and assumed
  // to reside in the bits implementing these fields.
  // Although a physical read operation would something different
  // for these fields,
  // the returned value is the actual content.
  //

  // extern virtual function uvm_reg_data_t  get(string  fname = "",
  //                                             int     lineno = 0);

  // Function: get_mirrored_value
  //
  // Return the mirrored value of the fields in the register.
  //
  // Does not actually read the value
  // of the register in the design
  //
  // If the register contains write-only fields, the desired/mirrored
  // value for those fields are the value last written and assumed
  // to reside in the bits implementing these fields.
  // Although a physical read operation would something different
  // for these fields, the returned value is the actual content.
  //
  // extern virtual function uvm_reg_data_t  get_mirrored_value(string  fname = "",
  //                                             int     lineno = 0);

  // get_mirrored_value

  uvm_reg_data_t  get_mirrored_value(string  fname = "",
				     int     lineno = 0) {
    synchronized(this) {
      // Concatenate the value of the individual fields
      // to form the register value
      _m_fname = fname;
      _m_lineno = lineno;

      uvm_reg_data_t get_mirrored_value_ = 0;
   
      foreach (field; _m_fields) {
	get_mirrored_value_ |= field.get_mirrored_value() << field.get_lsb_pos();
      }
      return get_mirrored_value_;
    }
  }


  // get

  uvm_reg_data_t  get(string  fname = "",
		      int     lineno = 0) {
    synchronized(this) {
      // Concatenate the value of the individual fields
      // to form the register value
      _m_fname = fname;
      _m_lineno = lineno;

      uvm_reg_data_t get_ = uvm_reg_data_t(0);
   
      foreach (i, field; _m_fields) {
	get_ |= field.get() << field.get_lsb_pos();
      }
      return get_;
      
    }
  }


  // Function: needs_update
  //
  // Returns 1 if any of the fields need updating
  //
  // See <uvm_reg_field::needs_update()> for details.
  // Use the <uvm_reg::update()> to actually update the DUT register.
  //
  // extern virtual function bool needs_update(); 

  // needs_update

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


  // Function: reset
  //
  // Reset the desired/mirrored value for this register.
  //
  // Sets the desired and mirror value of the fields in this register
  // to the reset value for the specified reset ~kind~.
  // See <uvm_reg_field.reset()> for more details.
  //
  // Also resets the semaphore that prevents concurrent access
  // to the register.
  // This semaphore must be explicitly reset if a thread accessing
  // this register array was killed in before the access
  // was completed
  //
  // extern virtual function void reset(string kind = "HARD");

  // reset

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

  // Function: get_reset
  //
  // Get the specified reset value for this register
  //
  // Return the reset value for this register
  // for the specified reset ~kind~.
  //

  // extern virtual function uvm_reg_data_t
  //                            get_reset(string kind = "HARD");
  
  // get_reset

  uvm_reg_data_t get_reset(string kind = "HARD") {
    synchronized(this) {
      // Concatenate the value of the individual fields
      // to form the register value
      uvm_reg_data_t get_reset_ = uvm_reg_data_t(0);
   
      foreach (i, field; _m_fields) {
	get_reset_ |= field.get_reset(kind) << field.get_lsb_pos();
      }
      return get_reset_;
    }
  }

  // Function: has_reset
  //
  // Check if any field in the register has a reset value specified
  // for the specified reset ~kind~.
  // If ~delete~ is TRUE, removes the reset value, if any.
  //

  // extern virtual function bool has_reset(string kind = "HARD",
  //                                        bool    delete = 0);

  // has_reset

  bool has_reset(string kind = "HARD",
		 bool remove = false) {
    synchronized(this) {
      bool has_reset_ = false;
      foreach (i, field; _m_fields) {
	has_reset_ |= field.has_reset(kind, remove);
	if (!remove && has_reset_) {
	  return true;
	}
      }
      return has_reset_;
    }
  }


  // Function: set_reset
  //
  // Specify or modify the reset value for this register
  //
  // Specify or modify the reset value for all the fields in the register
  // corresponding to the cause specified by ~kind~.
  //
  // extern virtual function void
  //                     set_reset(uvm_reg_data_t value,
  //                               string         kind = "HARD");

  // set_reset

  void set_reset(uvm_reg_data_t value,
		 string         kind = "HARD") {
    synchronized(this) {
      foreach (i, field; _m_fields) {
	field.set_reset(value >> field.get_lsb_pos(), kind);
      }
    }
  }

  // Task: write
  //
  // Write the specified value in this register
  //
  // Write ~value~ in the DUT register that corresponds to this
  // abstraction class instance using the specified access
  // ~path~. 
  // If the register is mapped in more than one address map, 
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  // If a back-door access path is used, the effect of writing
  // the register through a physical access is mimicked. For
  // example, read-only bits in the registers will not be written.
  //
  // The mirrored value will be updated using the <uvm_reg::predict()>
  // method.
  //
  // extern virtual task write(output uvm_status_e      status,
  //                           input  uvm_reg_data_t    value,
  //                           input  uvm_path_e        path = UVM_DEFAULT_PATH,
  //                           input  uvm_reg_map       map = null,
  //                           input  uvm_sequence_base parent = null,
  //                           input  int               prior = -1,
  //                           input  uvm_object        extension = null,
  //                           input  string            fname = "",
  //                           input  int               lineno = 0);

  // write

  // task
  void write(out uvm_status_e  status,
	     uvm_reg_data_t    value,
	     uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
	     uvm_reg_map       map = null,
	     uvm_sequence_base parent = null,
	     int               prior = -1,
	     uvm_object        extension = null,
	     string            fname = "",
	     int               lineno = 0) {
    // create an abstract transaction for this operation
    uvm_reg_item rw;

    XatomicX(1);

    set(value);

    rw = uvm_reg_item.type_id.create("write_item", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.element_kind = UVM_REG;
      rw.kind         = UVM_WRITE;
      rw.set_value(0, value); // rw.value[0]    = value;
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

    XatomicX(0);

  }

  void write(T)(out uvm_status_e  status,
		T                 value,
		uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
		uvm_reg_map       map = null,
		uvm_sequence_base parent = null,
		int               prior = -1,
		uvm_object        extension = null,
		string            fname = "",
		int               lineno = 0) {
    uvm_reg_data_t data = value;
    this.write(status, data, path, map, parent, prior, extension,
	       fname, lineno);
  }
  

  // Task: read
  //
  // Read the current value from this register
  //
  // Read and return ~value~ from the DUT register that corresponds to this
  // abstraction class instance using the specified access
  // ~path~. 
  // If the register is mapped in more than one address map, 
  // an address ~map~ must be
  // specified if a physical access is used (front-door access).
  // If a back-door access path is used, the effect of reading
  // the register through a physical access is mimicked. For
  // example, clear-on-read bits in the registers will be set to zero.
  //
  // The mirrored value will be updated using the <uvm_reg::predict()>
  // method.
  //
  // extern virtual task read(output uvm_status_e      status,
  //                          output uvm_reg_data_t    value,
  //                          input  uvm_path_e        path = UVM_DEFAULT_PATH,
  //                          input  uvm_reg_map       map = null,
  //                          input  uvm_sequence_base parent = null,
  //                          input  int               prior = -1,
  //                          input  uvm_object        extension = null,
  //                          input  string            fname = "",
  //                          input  int               lineno = 0);

  // read

  // task
  void read(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    uvm_path_e            path = uvm_path_e.UVM_DEFAULT_PATH,
	    uvm_reg_map           map = null,
	    uvm_sequence_base     parent = null,
	    int                   prior = -1,
	    uvm_object            extension = null,
	    string                fname = "",
	    int                   lineno = 0) {
    XatomicX(1);
    XreadX(status, value, path, map, parent, prior, extension, fname, lineno);
    XatomicX(0);
  }


  // Task: poke
  //
  // Deposit the specified value in this register
  //
  // Deposit the value in the DUT register corresponding to this
  // abstraction class instance, as-is, using a back-door access.
  //
  // Uses the HDL path for the design abstraction specified by ~kind~.
  //
  // The mirrored value will be updated using the <uvm_reg::predict()>
  // method.
  //
  // extern virtual task poke(output uvm_status_e      status,
  //                          input  uvm_reg_data_t    value,
  //                          input  string            kind = "",
  //                          input  uvm_sequence_base parent = null,
  //                          input  uvm_object        extension = null,
  //                          input  string            fname = "",
  //                          input  int               lineno = 0);

  // poke

  // task
  void poke(out uvm_status_e  status,
	    uvm_reg_data_t    value,
	    string            kind = "",
	    uvm_sequence_base parent = null,
	    uvm_object        extension = null,
	    string            fname = "",
	    int               lineno = 0) {

    uvm_reg_backdoor bkdr = get_backdoor();
    uvm_reg_item rw;

    _m_fname = fname;
    _m_lineno = lineno;


    if (bkdr is null && !has_hdl_path(kind)) {
      uvm_error("RegModel",
		"No backdoor access available to poke register '" ~
		get_full_name() ~ "'");
      status = UVM_NOT_OK;
      return;
    }

    if (!_m_is_locked_by_field) {
      XatomicX(1);
    }

    // create an abstract transaction for this operation
    rw = uvm_reg_item.type_id.create("reg_poke_item", null, get_full_name());
    synchronized(rw) {
      rw.element      = this;
      rw.path         = UVM_BACKDOOR;
      rw.element_kind = UVM_REG;
      rw.kind         = UVM_WRITE;
      rw.bd_kind      = kind;
      // rw.value[0]     = value & ((1 << _m_n_bits)-1);
      rw.set_value(0, value & ((1 << _m_n_bits)-1));
      rw.parent       = parent;
      rw.extension    = extension;
      rw.fname        = fname;
      rw.lineno       = lineno;
    }
    
    if (bkdr !is null) {
      bkdr.write(rw);
    }
    else {
      backdoor_write(rw);
    }

    synchronized(rw) {
      status = rw.status;
    }

    uvm_info("RegModel", format("Poked register \"%s\": 'h%h",
				get_full_name(), value),UVM_HIGH);

    do_predict(rw, UVM_PREDICT_WRITE);

    if (!_m_is_locked_by_field) {
      XatomicX(0);
    }
  }


  // Task: peek
  //
  // Read the current value from this register
  //
  // Sample the value in the DUT register corresponding to this
  // absraction class instance using a back-door access.
  // The register value is sampled, not modified.
  //
  // Uses the HDL path for the design abstraction specified by ~kind~.
  //
  // The mirrored value will be updated using the <uvm_reg::predict()>
  // method.
  //
  // extern virtual task peek(output uvm_status_e      status,
  //                          output uvm_reg_data_t    value,
  //                          input  string            kind = "",
  //                          input  uvm_sequence_base parent = null,
  //                          input  uvm_object        extension = null,
  //                          input  string            fname = "",
  //                          input  int               lineno = 0);

  // peek

  // task
  void peek(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    string                kind = "",
	    uvm_sequence_base     parent = null,
	    uvm_object            extension = null,
	    string                fname = "",
	    int                   lineno = 0) {

    uvm_reg_backdoor bkdr = get_backdoor();
    uvm_reg_item rw;

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

    if(!_m_is_locked_by_field) {
      XatomicX(1);
    }

    synchronized(rw) {
      // create an abstract transaction for this operation
      rw = uvm_reg_item.type_id.create("mem_peek_item", null, get_full_name());
      rw.element      = this;
      rw.path         = UVM_BACKDOOR;
      rw.element_kind = UVM_REG;
      rw.kind         = UVM_READ;
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
      // value = rw.value[0];
      value = rw.get_value(0);
    }
    
    uvm_info("RegModel", format("Peeked register \"%s\": 'h%h",
				get_full_name(), value),UVM_HIGH);

    do_predict(rw, UVM_PREDICT_READ);

    if (!_m_is_locked_by_field) {
      XatomicX(0);
    }
  }



  // Task: update
  //
  // Updates the content of the register in the design to match the
  // desired value
  //
  // This method performs the reverse
  // operation of <uvm_reg::mirror()>.
  // Write this register if the DUT register is out-of-date with the
  // desired/mirrored value in the abstraction class, as determined by
  // the <uvm_reg::needs_update()> method.
  //
  // The update can be performed using the using the physical interfaces
  // (frontdoor) or <uvm_reg::poke()> (backdoor) access.
  // If the register is mapped in multiple address maps and physical access
  // is used (front-door), an address ~map~ must be specified.
  //
  // extern virtual task update(output uvm_status_e      status,
  // 			     input  uvm_path_e        path = UVM_DEFAULT_PATH,
  // 			     input  uvm_reg_map       map = null,
  // 			     input  uvm_sequence_base parent = null,
  // 			     input  int               prior = -1,
  // 			     input  uvm_object        extension = null,
  // 			     input  string            fname = "",
  // 			     input  int               lineno = 0);

  // update

  // task
  void update(out uvm_status_e      status,
	      uvm_path_e            path = uvm_path_e.UVM_DEFAULT_PATH,
	      uvm_reg_map           map = null,
	      uvm_sequence_base     parent = null,
	      int                   prior = -1,
	      uvm_object            extension = null,
	      string                fname = "",
	      int                   lineno = 0) {

    status = UVM_IS_OK;

    if (!needs_update()) return;

    // Concatenate the write-to-update values from each field
    // Fields are stored in LSB or MSB order
    uvm_reg_data_t upd = 0;
    synchronized(this) {
      foreach (i, field; _m_fields) {
	upd |= field.XupdateX() << field.get_lsb_pos();
      }
    }
    
    write(status, upd, path, map, parent, prior, extension, fname, lineno);
  }


  // Task: mirror
  //
  // Read the register and update/check its mirror value
  //
  // Read the register and optionally compared the readback value
  // with the current mirrored value if ~check~ is <UVM_CHECK>.
  // The mirrored value will be updated using the <uvm_reg::predict()>
  // method based on the readback value.
  //
  // The mirroring can be performed using the physical interfaces (frontdoor)
  // or <uvm_reg::peek()> (backdoor).
  //
  // If ~check~ is specified as UVM_CHECK,
  // an error message is issued if the current mirrored value
  // does not match the readback value. Any field whose check has been
  // disabled with <uvm_reg_field::set_compare()> will not be considered
  // in the comparison. 
  //
  // If the register is mapped in multiple address maps and physical
  // access is used (front-door access), an address ~map~ must be specified.
  // If the register contains
  // write-only fields, their content is mirrored and optionally
  // checked only if a UVM_BACKDOOR
  // access path is used to read the register. 
  //
  // extern virtual task mirror(output uvm_status_e      status,
  // 			     input uvm_check_e        check  = UVM_NO_CHECK,
  // 			     input uvm_path_e         path = UVM_DEFAULT_PATH,
  // 			     input uvm_reg_map        map = null,
  // 			     input uvm_sequence_base  parent = null,
  // 			     input int                prior = -1,
  // 			     input  uvm_object        extension = null,
  // 			     input string             fname = "",
  // 			     input int                lineno = 0);

  // mirror

  // task
  void mirror(out uvm_status_e   status,
	      uvm_check_e        check = uvm_check_e.UVM_NO_CHECK,
	      uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
	      uvm_reg_map        map = null,
	      uvm_sequence_base  parent = null,
	      int                prior = -1,
	      uvm_object         extension = null,
	      string             fname = "",
	      int                lineno = 0) {
    uvm_reg_data_t  v;
    uvm_reg_data_t  exp;
    uvm_reg_backdoor bkdr = get_backdoor();

    XatomicX(1);
    synchronized(this) {
      _m_fname = fname;
      _m_lineno = lineno;


      if (path == UVM_DEFAULT_PATH)
	path = _m_parent.get_default_path();

      if (path == UVM_BACKDOOR && (bkdr !is null || has_hdl_path())) {
	map = uvm_reg_map.backdoor();
      }
      else {
	map = get_local_map(map, "read()");
      }

      if (map is null) {
	XatomicX(0);		// SV version does not have this
	return;
      }
   
      // Remember what we think the value is before it gets updated
      if (check == UVM_CHECK)
	exp = get_mirrored_value();
    }

    XreadX(status, v, path, map, parent, prior, extension, fname, lineno);

    if (status == UVM_NOT_OK) {
      XatomicX(0);
      return;
    }

    if (check == UVM_CHECK) do_check(exp, v, map);

    XatomicX(0);
  }

  // Function: predict
  //
  // Update the mirrored value for this register.
  //
  // Predict the mirror value of the fields in the register
  // based on the specified observed ~value~ on a specified adress ~map~,
  // or based on a calculated value.
  // See <uvm_reg_field::predict()> for more details.
  //
  // Returns TRUE if the prediction was succesful for each field in the
  // register.
  //

  // extern virtual function bool predict (uvm_reg_data_t    value,
  //                                       uvm_reg_byte_en_t be = -1,
  //                                       uvm_predict_e     kind = UVM_PREDICT_DIRECT,
  //                                       uvm_path_e        path = UVM_FRONTDOOR,
  //                                       uvm_reg_map       map = null,
  //                                       string            fname = "",
  //                                       int               lineno = 0);

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
    }
    do_predict(rw, kind, be);
    if(rw.status == UVM_NOT_OK) return false;
    else return true;
  }


  // Function: is_busy
  //
  // Returns 1 if register is currently being read or written.
  //
  // extern function bool is_busy();
  // is_busy

  final bool is_busy() {
    synchronized(this) {
      return _m_is_busy;
    }
  }


  // /*local*/ extern function void Xset_busyX(bool busy);

  // Xset_busyX

  final void Xset_busyX(bool busy) {
    synchronized(this) {
      _m_is_busy = busy;
    }
  }

  // /*local*/ extern task XreadX (output uvm_status_e      status,
  // output uvm_reg_data_t    value,
  // input  uvm_path_e        path,
  // input  uvm_reg_map       map,
  // input  uvm_sequence_base parent = null,
  // input  int               prior = -1,
  // input  uvm_object        extension = null,
  // input  string            fname = "",
  // input  int               lineno = 0);
   
  // XreadX

  // task
  void XreadX(out uvm_status_e      status,
	      out uvm_reg_data_t    value,
	      uvm_path_e            path,
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
      rw.element      = this;
      rw.element_kind = UVM_REG;
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
      status = rw.status;
      // value = rw.value[0];
      value = rw.get_value(0);
    }
  }

  // /*local*/ extern task XatomicX(bool on);
  // XatomicX

  // task
  void XatomicX(bool on) {
    Process m_reg_process = Process.self;

    if (on) {
      if (m_reg_process is m_process) {
	return;
      }
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


  // /*local*/ extern virtual function bool Xcheck_accessX
  //                              (input uvm_reg_item rw,
  //                               output uvm_reg_map_info map_info,
  //                               input string caller);

  // Xcheck_accessX

  bool Xcheck_accessX (uvm_reg_item rw,
		       out uvm_reg_map_info map_info,
		       string caller) {
    synchronized(this) {

      if (rw.path == UVM_DEFAULT_PATH) {
	rw.path = _m_parent.get_default_path();
      }

      if (rw.path == UVM_BACKDOOR) {
	if (get_backdoor() is null && !has_hdl_path()) {
	  uvm_warning("RegModel",
		      "No backdoor access available for register '" ~
		      get_full_name() ~ "' . Using frontdoor instead.");
	  rw.path = UVM_FRONTDOOR;
	}
	else {
	  rw.map = uvm_reg_map.backdoor();
	}
      }


      if (rw.path != UVM_BACKDOOR) {

	rw.local_map = get_local_map(rw.map,caller);

	if (rw.local_map is null) {
	  uvm_error(get_type_name(), 
		    "No transactor available to physically access register on map '" ~
		    rw.map.get_full_name() ~ "'");
	  rw.status = UVM_NOT_OK;
	  return false;
	}

	map_info = rw.local_map.get_reg_map_info(this);

	if (map_info.frontdoor is null && map_info.unmapped) {
	  uvm_error("RegModel", "Register '" ~ get_full_name() ~
		    "' unmapped in map '" ~
		    (rw.map is null)? rw.local_map.get_full_name() :
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

  // /*local*/ extern function bool Xis_locked_by_fieldX();
  // Xis_loacked_by_fieldX

  bool Xis_locked_by_fieldX() {
    synchronized(this) {
      return _m_is_locked_by_field;
    }
  }
    
  // extern virtual function bool do_check(uvm_reg_data_t expected,
  //                                       uvm_reg_data_t actual,
  //                                       uvm_reg_map    map);
  // do_check

  // FIXME -- look for === and !==
  bool do_check(uvm_reg_data_t expected,
		uvm_reg_data_t actual,
		uvm_reg_map    map) {
    synchronized(this) {
      uvm_reg_data_t  dc = 0;

      foreach(field; _m_fields) {
	string acc = field.get_access(map);
	acc = acc[0..2];
	if (field.get_compare() == UVM_NO_CHECK ||
	    acc == "WO") {
	  dc |= ((1 << field.get_n_bits())-1)
	    << field.get_lsb_pos();
	}
      }

      if ((actual|dc) is (expected|dc)) return true;
   
      uvm_error("RegModel",
		format("Register \"%s\" value read from DUT (0x%h)" ~
		       " does not match mirrored value (0x%h)",
		       get_full_name(), actual,
		       (expected ^ (LOGIC_X & dc))));
                                     
      foreach(field; _m_fields) {
	string acc = field.get_access(map);
	acc = acc[0..2];
	if (!(field.get_compare() == UVM_NO_CHECK ||
	      acc == "WO")) {
	  uvm_reg_data_t mask  = ((1 << field.get_n_bits())-1);
	  uvm_reg_data_t val   = actual   >> field.get_lsb_pos() & mask;
	  uvm_reg_data_t exp   = expected >> field.get_lsb_pos() & mask;

	  if (val !is exp) {
	    uvm_info("RegModel",
		     format("Field %s (%s[%0d:%0d]) mismatch read=%0d'h%0h mirrored=%0d'h%0h ",
			    field.get_name(), get_full_name(),
			    field.get_lsb_pos() + field.get_n_bits() - 1,
			    field.get_lsb_pos(),
			    field.get_n_bits(), val,
			    field.get_n_bits(), exp),
		     UVM_NONE);
	  }
	}
      }
    }
    return false;
  }
       

  // extern virtual task do_write(uvm_reg_item rw);

  // do_write

  // task
  void do_write (uvm_reg_item rw) {

    uvm_reg_cb_iter  cbs = new uvm_reg_cb_iter(this);
    uvm_reg_map_info map_info;
    uvm_reg_data_t   value; 

    synchronized(this) {
      _m_fname  = rw.fname;
      _m_lineno = rw.lineno;
    }
    
    if (!Xcheck_accessX(rw,map_info,"write()"))
      return;

    XatomicX(1);

    synchronized(this) {
      _m_write_in_progress = true;
      // rw.value[0] &= ((1 << _m_n_bits)-1);
      rw.and_value(0, ((1 << _m_n_bits)-1));
    }
    // value = rw.value[0];
    value = rw.get_value(0);
    rw.status = UVM_IS_OK;

    // PRE-WRITE CBS - FIELDS
    // begin : pre_write_callbacks
    uvm_reg_data_t  msk;

    foreach (field; _m_fields) {
      uvm_reg_field_cb_iter lcbs = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;
      int lsb = f.get_lsb_pos();
      msk = ((1 << f.get_n_bits())-1) << lsb;
      // rw.value[0] = (value & msk) >> lsb;
      rw.set_value(0, (value & msk) >> lsb);
      f.pre_write(rw);
      for (uvm_reg_cbs cb=lcbs.first(); cb !is null; cb=lcbs.next()) {
	rw.element = f;
	rw.element_kind = UVM_FIELD;
	cb.pre_write(rw);
      }
      // value = (value & ~msk) | (rw.value[0] << lsb);
      value = (value & ~msk) | (rw.get_value(0) << lsb);
    }

    rw.element = this;
    rw.element_kind = UVM_REG;
    // rw.value[0] = value;
    rw.set_value(0, value);

    // PRE-WRITE CBS - REG
    pre_write(rw);
    for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next())
      cb.pre_write(rw);

    if (rw.status != UVM_IS_OK) {
      _m_write_in_progress = false;

      XatomicX(0);
         
      return;
    }
         
    // EXECUTE WRITE...
    switch(rw.path) {
      
      // ...VIA USER BACKDOOR
    case UVM_BACKDOOR:
      {
	uvm_reg_data_t final_val;
	uvm_reg_backdoor bkdr = get_backdoor();

	// value = rw.value[0];
	value = rw.get_value(0);
	// Mimick the final value after a physical read
	rw.kind = UVM_READ;
	if (bkdr !is null) {
	  bkdr.read(rw);
	}
	else {
	  backdoor_read(rw);
	}

	if (rw.status == UVM_NOT_OK) {
	  _m_write_in_progress = false;
	  return;
	}

	foreach (i, field; _m_fields) {
	  uvm_reg_data_t field_val;
	  int lsb = field.get_lsb_pos();
	  int sz  = field.get_n_bits();
	  // field_val = field.XpredictX((rw.value[0] >> lsb) & ((1<<sz)-1),
	  // 			      (value >> lsb) & ((1<<sz)-1),
	  // 			      rw.local_map);
	  field_val = field.XpredictX((rw.get_value(0) >> lsb) & ((1<<sz)-1),
				      (value >> lsb) & ((1<<sz)-1),
				      rw.local_map);
	  final_val |= field_val << lsb;
	}
	rw.kind = UVM_WRITE;
	// rw.value[0] = final_val;
	rw.set_value(0, final_val);

	if (bkdr !is null) {
	  bkdr.write(rw);
	}
	else {
	  backdoor_write(rw);
	}
	do_predict(rw, UVM_PREDICT_WRITE);
      }
      break;
    case UVM_FRONTDOOR:
      {

	uvm_reg_map system_map = rw.local_map.get_root_map();

	_m_is_busy = 1;

	// ...VIA USER FRONTDOOR
	if (map_info.frontdoor !is null) {
	  uvm_reg_frontdoor fd = map_info.frontdoor;
	  fd.rw_info = rw;
	  if (fd.sequencer is null) {
	    fd.sequencer = system_map.get_sequencer();
	  }
	  fd.start(fd.sequencer, rw.parent);
	}

	// ...VIA BUILT-IN FRONTDOOR
	else {
	  rw.local_map.do_write(rw);
	}

	_m_is_busy = 0;

	if (system_map.get_auto_predict()) {
	  uvm_status_e status;
	  if (rw.status != UVM_NOT_OK) {
	    sample(value, uvm_reg_addr_t(-1), false, rw.map);
	    _m_parent.XsampleX(map_info.offset, 0, rw.map);
	  }

	  status = rw.status; // do_predict will override rw.status, so we save it here
	  do_predict(rw, UVM_PREDICT_WRITE);
	  rw.status = status;
	}
      }
      break;
    default: assert(0);
    }

    // value = rw.value[0];
    value = rw.get_value(0);

    // POST-WRITE CBS - REG
    for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next()) {
      cb.post_write(rw);
    }
    post_write(rw);

    // POST-WRITE CBS - FIELDS
    foreach (field; _m_fields) {
      uvm_reg_field_cb_iter lcbs = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;
      
      rw.element = f;
      rw.element_kind = UVM_FIELD;
      // rw.value[0] = (value >> f.get_lsb_pos()) & ((1<<f.get_n_bits())-1);
      rw.set_value(0, (value >> f.get_lsb_pos()) & ((1<<f.get_n_bits())-1));
      
      for (uvm_reg_cbs cb=lcbs.first(); cb !is null; cb=lcbs.next()) {
	cb.post_write(rw);
      }
      f.post_write(rw);
    }
   
    // rw.value[0] = value;
    rw.set_value(0, value);
    rw.element = this;
    rw.element_kind = UVM_REG;

    // REPORT
    if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "RegModel")) {
      string path_s,value_s;
      if (rw.path == UVM_FRONTDOOR) {
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ rw.map.get_full_name();
      }
      else {
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";
      }
      // value_s = format("=0x%0h",rw.value[0]);
      value_s = format("=0x%0h",rw.get_value(0));

      uvm_report_info("RegModel", "Wrote register via " ~ path_s ~ ": " ~
		      get_full_name() ~ value_s, UVM_HIGH);
    }

    _m_write_in_progress = false;

    XatomicX(0);

  }

  // extern virtual task do_read(uvm_reg_item rw);
  // do_read

  // task
  void do_read(uvm_reg_item rw) {

    uvm_reg_cb_iter  cbs = new uvm_reg_cb_iter(this);
    uvm_reg_map_info map_info;
    uvm_reg_data_t   value;
    uvm_reg_data_t   exp;

    synchronized(this) {
      _m_fname   = rw.fname;
      _m_lineno  = rw.lineno;
    
      if (!Xcheck_accessX(rw,map_info,"read()")) {
	return;
      }

      _m_read_in_progress = true;

    }

    synchronized(rw) {
      rw.status = UVM_IS_OK;
    }

    // PRE-READ CBS - FIELDS
    foreach (field; _m_fields) {
      uvm_reg_field_cb_iter cbsi = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;
      rw.element = f;
      rw.element_kind = UVM_FIELD;
      field.pre_read(rw);
      for (uvm_reg_cbs cb=cbsi.first(); cb !is null; cb=cbsi.next())
	cb.pre_read(rw);
    }

    synchronized(rw) {
      rw.element = this;
      rw.element_kind = UVM_REG;
    }

    // PRE-READ CBS - REG
    pre_read(rw);
    for (uvm_reg_cbs cb=cbs.first(); cb !is null; cb=cbs.next()) {
      cb.pre_read(rw);
    }

    if (rw.status != UVM_IS_OK) {
      _m_read_in_progress = false;
      return;
    }
         
    // EXECUTE READ...
    switch(rw.path) {
      // ...VIA USER BACKDOOR
    case UVM_BACKDOOR:
      {
	uvm_reg_backdoor bkdr = get_backdoor();

	uvm_reg_map map = uvm_reg_map.backdoor();
	if (map.get_check_on_read()) exp = get();
   
	if (bkdr !is null) {
	  bkdr.read(rw);
	}
	else {
	  backdoor_read(rw);
	}

	// value = rw.value[0];
	value = rw.get_value(0);

	// Need to clear RC fields, set RS fields and mask WO fields
	if (rw.status != UVM_NOT_OK) {
	  uvm_reg_data_t wo_mask;

	  foreach (field; _m_fields) {
	    string acc = field.get_access(uvm_reg_map.backdoor());
	    if (acc == "RC" ||
		acc == "WRC" ||
		acc == "WSRC" ||
		acc == "W1SRC" ||
		acc == "W0SRC") {
	      value &= ~(((1<<field.get_n_bits())-1)
			 << field.get_lsb_pos());
	    }
	    else if (acc == "RS" ||
		     acc == "WRS" ||
		     acc == "WCRS" ||
		     acc == "W1CRS" ||
		     acc == "W0CRS") {
	      value |= (((1<<field.get_n_bits())-1)
			<< field.get_lsb_pos());
	    }
	    else if (acc == "WO" ||
		     acc == "WOC" ||
		     acc == "WOS" ||
		     acc == "WO1") {
	      wo_mask |= ((1<<field.get_n_bits())-1)
		<< field.get_lsb_pos();
	    }
	  }

	  // if (value != rw.value[0]) {
	  if (value != rw.get_value(0)) {
	    uvm_reg_data_t saved;
	    // saved = rw.value[0];
	    saved = rw.get_value(0);
	    // rw.value[0] = value;
	    rw.set_value(0, value);
	    if (bkdr !is null) {
	      bkdr.write(rw);
	    }
	    else {
	      backdoor_write(rw);
	    }
	    // rw.value[0] = saved;
	    rw.set_value(0, saved);
	  }

	  // rw.value[0] &= ~wo_mask;
	  rw.and_value(0, ~wo_mask);

	  if (map.get_check_on_read() &&
	      rw.status != UVM_NOT_OK) {
	    // do_check(exp, rw.value[0], map);
	    do_check(exp, rw.get_value(0), map);
	  }
       
	  do_predict(rw, UVM_PREDICT_READ);
	}
      }
      break;

    case UVM_FRONTDOOR:
      {
	uvm_reg_map system_map = rw.local_map.get_root_map();
	_m_is_busy = 1;
	if (rw.local_map.get_check_on_read()) exp = get();
   
	// ...VIA USER FRONTDOOR
	if (map_info.frontdoor !is null) {
	  uvm_reg_frontdoor fd = map_info.frontdoor;
	  fd.rw_info = rw;
	  if (fd.sequencer is null)
	    fd.sequencer = system_map.get_sequencer();
	  fd.start(fd.sequencer, rw.parent);
	}

	// ...VIA BUILT-IN FRONTDOOR
	else {
	  rw.local_map.do_read(rw);
	}

	_m_is_busy = 0;

	if (system_map.get_auto_predict()) {
	  uvm_status_e status;
	  if (rw.local_map.get_check_on_read() &&
	      rw.status != UVM_NOT_OK) {
	    // do_check(exp, rw.value[0], system_map);
	    do_check(exp, rw.get_value(0), system_map);
	  }

	  if (rw.status != UVM_NOT_OK) {
	    // sample(rw.value[0], uvm_reg_addr_t(-1), true, rw.map);
	    sample(rw.get_value(0), uvm_reg_addr_t(-1), true, rw.map);
	    _m_parent.XsampleX(map_info.offset, 1, rw.map);
	  }

	  status = rw.status; // do_predict will override rw.status, so we save it here
	  do_predict(rw, UVM_PREDICT_READ);
	  rw.status = status;
	}
      }
      break;
    default: assert(0);
    }

    // value = rw.value[0]; // preserve 
    value = rw.get_value(0); // preserve 

    // POST-READ CBS - REG
    for (uvm_reg_cbs cb = cbs.first(); cb !is null; cb = cbs.next())
      cb.post_read(rw);

    post_read(rw);

    // POST-READ CBS - FIELDS
    foreach (field; _m_fields) {
      uvm_reg_field_cb_iter cbsi = new uvm_reg_field_cb_iter(field);
      uvm_reg_field f = field;

      rw.element = f;
      rw.element_kind = UVM_FIELD;
      // rw.value[0] = (value >> f.get_lsb_pos()) & ((1<<f.get_n_bits())-1);
      rw.set_value(0, (value >> f.get_lsb_pos()) & ((1<<f.get_n_bits())-1));

      for (uvm_reg_cbs cb=cbsi.first(); cb !is null; cb=cbsi.next())
	cb.post_read(rw);
      f.post_read(rw);
    }

    // rw.value[0] = value; // restore
    rw.set_value(0, value); // restore
    rw.element = this;
    rw.element_kind = UVM_REG;

    // REPORT
    if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "RegModel"))  {
      string path_s,value_s;
      if (rw.path == UVM_FRONTDOOR)
	path_s = (map_info.frontdoor !is null) ? "user frontdoor" :
	  "map " ~ rw.map.get_full_name();
      else
	path_s = (get_backdoor() !is null) ? "user backdoor" : "DPI backdoor";

      // value_s = format("=%0h", rw.value[0]);
      value_s = format("=%0h", rw.get_value(0));

      uvm_report_info("RegModel", "Read  register via " ~ path_s ~ ": " ~
		      get_full_name() ~ value_s, UVM_HIGH);
    }
    _m_read_in_progress = false;
  }

  // extern virtual function void do_predict
  //                               (uvm_reg_item      rw,
  //                                uvm_predict_e     kind = UVM_PREDICT_DIRECT,
  //                                uvm_reg_byte_en_t be = -1);
  // do_predict

  void do_predict(uvm_reg_item      rw,
		  uvm_predict_e     kind = uvm_predict_e.UVM_PREDICT_DIRECT,
		  uvm_reg_byte_en_t be = -1) {
    synchronized(this) {

      // uvm_reg_data_t reg_value = rw.value[0];
      uvm_reg_data_t reg_value = rw.get_value(0);
      _m_fname = rw.fname;
      _m_lineno = rw.lineno;

      rw.status = UVM_IS_OK;

      if (_m_is_busy && kind is UVM_PREDICT_DIRECT) {
	uvm_warning("RegModel", "Trying to predict value of register '" ~
		    get_full_name() ~ "' while it is being accessed");
	rw.status = UVM_NOT_OK;
	return;
      }
   
      foreach (field; _m_fields) {
	// rw.value[0] = (reg_value >> field.get_lsb_pos()) &
	//   ((1 << field.get_n_bits())-1);
	rw.set_value(0, (reg_value >> field.get_lsb_pos()) &
		     ((1 << field.get_n_bits())-1));
	field.do_predict(rw, kind, be>>(field.get_lsb_pos()/8));
      }

      // rw.value[0] = reg_value;
      rw.set_value(0, reg_value);
    }
  }


  //-----------------
  // Group: Frontdoor
  //-----------------

  // Function: set_frontdoor
  //
  // Set a user-defined frontdoor for this register
  //
  // By default, registers are mapped linearly into the address space
  // of the address maps that instantiate them.
  // If registers are accessed using a different mechanism,
  // a user-defined access
  // mechanism must be defined and associated with
  // the corresponding register abstraction class
  //
  // If the register is mapped in multiple address maps, an address ~map~
  // must be specified.
  //
  // extern function void set_frontdoor(uvm_reg_frontdoor ftdr,
  // 				     uvm_reg_map       map = null,
  // 				     string            fname = "",
  // 				     int               lineno = 0);

  // set_frontdoor

  void set_frontdoor(uvm_reg_frontdoor ftdr,
		     uvm_reg_map       map = null,
		     string            fname = "",
		     int               lineno = 0) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      ftdr.fname = _m_fname;
      ftdr.lineno = _m_lineno;
      map = get_local_map(map, "set_frontdoor()");
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
    
  // Function: get_frontdoor
  //
  // Returns the user-defined frontdoor for this register
  //
  // If null, no user-defined frontdoor has been defined.
  // A user-defined frontdoor is defined
  // by using the <uvm_reg::set_frontdoor()> method. 
  //
  // If the register is mapped in multiple address maps, an address ~map~
  // must be specified.
  //
  // extern function uvm_reg_frontdoor get_frontdoor(uvm_reg_map map = null);
  // get_frontdoor

  uvm_reg_frontdoor get_frontdoor(uvm_reg_map map = null) {
    synchronized(this) {
      uvm_reg_map_info map_info;
      map = get_local_map(map, "get_frontdoor()");
      if (map is null)
	return null;
      map_info = map.get_reg_map_info(this);
      return map_info.frontdoor;
    }
  }


  //----------------
  // Group: Backdoor
  //----------------


  // Function: set_backdoor
  //
  // Set a user-defined backdoor for this register
  //
  // By default, registers are accessed via the built-in string-based
  // DPI routines if an HDL path has been specified using the
  // <uvm_reg::configure()> or <uvm_reg::add_hdl_path()> method.
  //
  // If this default mechanism is not suitable (e.g. because
  // the register is not implemented in pure SystemVerilog)
  // a user-defined access
  // mechanism must be defined and associated with
  // the corresponding register abstraction class
  //
  // A user-defined backdoor is required if active update of the
  // mirror of this register abstraction class, based on observed
  // changes of the corresponding DUT register, is used.
  //
  // extern function void set_backdoor(uvm_reg_backdoor bkdr,
  // 				    string          fname = "",
  // 				    int             lineno = 0);
  // set_backdoor

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
   
   
  // Function: get_backdoor
  //
  // Returns the user-defined backdoor for this register
  //
  // If null, no user-defined backdoor has been defined.
  // A user-defined backdoor is defined
  // by using the <uvm_reg::set_backdoor()> method. 
  //
  // If ~inherited~ is TRUE, returns the backdoor of the parent block
  // if none have been specified for this register.
  //

  // extern function uvm_reg_backdoor get_backdoor(bool inherited = 1);
  // get_backdoor

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


  // Function: clear_hdl_path
  //
  // Delete HDL paths
  //
  // Remove any previously specified HDL path to the register instance
  // for the specified design abstraction.
  //
  // extern function void clear_hdl_path (string kind = "RTL");

  // clear_hdl_path

  void clear_hdl_path(string kind = "RTL") {
    synchronized(this) {
      if (kind == "ALL") {
	_m_hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!(uvm_hdl_path_concat))("hdl_paths");
	return;
      }

      if (kind == "") {
	if (_m_regfile_parent !is null) {
	  kind = _m_regfile_parent.get_default_hdl_path();
	}
	else {
	  kind = _m_parent.get_default_hdl_path();
	}
      }
      if (!_m_hdl_paths_pool.exists(kind)) {
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
  // Add the specified HDL path to the register instance for the specified
  // design abstraction. This method may be called more than once for the
  // same design abstraction if the register is physically duplicated
  // in the design abstraction
  //
  // For example, the following register
  //
  //|        1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0
  //| Bits:  5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
  //|       +-+---+-------------+---+-------+
  //|       |A|xxx|      B      |xxx|   C   |
  //|       +-+---+-------------+---+-------+
  //
  // would be specified using the following literal value:
  //
  //| add_hdl_path('{ '{"A_reg", 15, 1},
  //|                 '{"B_reg",  6, 7},
  //|                 '{'C_reg",  0, 4} } );
  //
  // If the register is implementd using a single HDL variable,
  // The array should specify a single slice with its ~offset~ and ~size~
  // specified as -1. For example:
  //
  //| r1.add_hdl_path('{ '{"r1", -1, -1} });
  //
  // extern function void add_hdl_path (uvm_hdl_path_slice slices[],
  // 				     string kind = "RTL");

  // add_hdl_path

  void add_hdl_path(uvm_hdl_path_slice[] slices,
		    string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) paths = _m_hdl_paths_pool.get(kind);
      uvm_hdl_path_concat concat = new uvm_hdl_path_concat();

      concat.set(slices);
      paths.push_back(concat);
    }
  }

  // Function: add_hdl_path_slice
  //
  // Append the specified HDL slice to the HDL path of the register instance
  // for the specified design abstraction.
  // If ~first~ is TRUE, starts the specification of a duplicate
  // HDL implementation of the register.
  //
  // extern function void add_hdl_path_slice(string name,
  // 					  int offset,
  // 					  int size,
  // 					  bool first = 0,
  // 					  string kind = "RTL");

  // add_hdl_path_slice

  void add_hdl_path_slice(string name,
			  int offset,
			  int size,
			  bool first = 0,
			  string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) paths = _m_hdl_paths_pool.get(kind);
      uvm_hdl_path_concat concat;
    
      if (first || paths.size() == 0) {
	concat = new uvm_hdl_path_concat();
	paths.push_back(concat);
      }
      else
	concat = paths.get(paths.length-1);

      concat.add_path(name, offset, size);
    }
  }


  // Function: has_hdl_path
  //
  // Check if a HDL path is specified
  //
  // Returns TRUE if the register instance has a HDL path defined for the
  // specified design abstraction. If no design abstraction is specified,
  // uses the default design abstraction specified for the parent block.
  //
  // extern function bool has_hdl_path (string kind = "");
  // has_hdl_path

  bool  has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "") {
	if (_m_regfile_parent !is null)
	  kind = _m_regfile_parent.get_default_hdl_path();
	else
	  kind = _m_parent.get_default_hdl_path();
      }

      if(kind in _m_hdl_paths_pool) return true;
      else return false;
    }
  }


  // Function:  get_hdl_path
  //
  // Get the incremental HDL path(s)
  //
  // Returns the HDL path(s) defined for the specified design abstraction
  // in the register instance.
  // Returns only the component of the HDL paths that corresponds to
  // the register, not a full hierarchical path
  //
  // If no design asbtraction is specified, the default design abstraction
  // for the parent block is used.
  //
  // extern function void get_hdl_path (ref uvm_hdl_path_concat paths[$],
  // 				     input string kind = "");


  // get_hdl_path

  void get_hdl_path(out uvm_hdl_path_concat[] paths,
		    string kind = "") {
    synchronized(this) {
      uvm_queue!(uvm_hdl_path_concat) hdl_paths;

      if (kind == "") {
	if (_m_regfile_parent !is null)
	  kind = _m_regfile_parent.get_default_hdl_path();
	else
	  kind = _m_parent.get_default_hdl_path();
      }

      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Register does not have hdl path defined for abstraction '" ~
		  kind ~ "'");
	return;
      }

      hdl_paths = _m_hdl_paths_pool.get(kind);

      for (int i=0; i<hdl_paths.length; i++) {
	paths ~= hdl_paths.get(i);
      }
    }
  }

  // Function:  get_hdl_path_kinds
  //
  // Get design abstractions for which HDL paths have been defined
  //
  // extern function void get_hdl_path_kinds (ref string kinds[$]);

  // get_hdl_path_kinds

  void get_hdl_path_kinds (out string[] kinds) {
    synchronized(this) {
      string kind;
      // kinds.delete();
      foreach(kind, unused; _m_hdl_paths_pool) {
	kinds ~= kind;
      }
      return;
    }
  }

  // Function:  get_full_hdl_path
  //
  // Get the full hierarchical HDL path(s)
  //
  // Returns the full hierarchical HDL path(s) defined for the specified
  // design abstraction in the register instance.
  // There may be more than one path returned even
  // if only one path was defined for the register instance, if any of the
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

  void get_full_hdl_path(out uvm_hdl_path_concat[] paths,
			 string kind = "",
			 string separator = ".") {
    synchronized(this) {
      if (kind == "") {
	if (_m_regfile_parent !is null) {
	  kind = _m_regfile_parent.get_default_hdl_path();
	}
	else {
	  kind = _m_parent.get_default_hdl_path();
	}
      }
   
      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Register " ~ get_full_name() ~
		  " does not have hdl path defined for abstraction '" ~ kind ~ "'");
	return;
      }

      uvm_queue!(uvm_hdl_path_concat) hdl_paths = _m_hdl_paths_pool.get(kind);
      string[] parent_paths;

      if (_m_regfile_parent !is null) {
	_m_regfile_parent.get_full_hdl_path(parent_paths, kind, separator);
      }
      else {
	_m_parent.get_full_hdl_path(parent_paths, kind, separator);
      }

      for (int i=0; i<hdl_paths.length; i++) {
	uvm_hdl_path_concat hdl_concat = hdl_paths.get(i);

	foreach (j, parent_path; parent_paths) {
	  uvm_hdl_path_concat t = new uvm_hdl_path_concat;

	  foreach (hdl_slice; hdl_concat.slices) {
	    if (hdl_slice.path == "") {
	      t.add_path(parent_path);
	    }
	    else {
	      t.add_path(parent_path ~ separator ~ hdl_slice.path,
			 hdl_slice.offset, hdl_slice.size);
	    }
	  }
	  paths ~= t;
	}
      }
    }
  }

  // Function: backdoor_read
  //
  // User-define backdoor read access
  //
  // Override the default string-based DPI backdoor access read
  // for this register type.
  // By default calls <uvm_reg::backdoor_read_func()>.
  //
  // extern virtual task backdoor_read(uvm_reg_item rw);
  // backdoor_read

  // task
  void backdoor_read (uvm_reg_item rw) {
    synchronized(rw) {
      rw.status = backdoor_read_func(rw);
    }
  }


  // Function: backdoor_write
  //
  // User-defined backdoor read access
  //
  // Override the default string-based DPI backdoor access write
  // for this register type.
  //
  // extern virtual task backdoor_write(uvm_reg_item rw);

  // backdoor_write

  // task
  void backdoor_write(uvm_reg_item rw) {
    uvm_hdl_path_concat[] paths;
    bool ok = true;
    get_full_hdl_path(paths, rw.bd_kind);
    foreach (path; paths) {
      uvm_hdl_path_concat hdl_concat = path;
      foreach (hdl_slice; hdl_concat.slices) {
	uvm_info("RegMem", "backdoor_write to " ~
		 hdl_slice.path, UVM_DEBUG);

	if (hdl_slice.offset < 0) {
	  // ok &= uvm_hdl_deposit(hdl_slice.path, rw.value[0]);
	  ok &= uvm_hdl_deposit(hdl_slice.path, rw.get_value(0));
	  continue;
	}
	// uvm_reg_data_t slice = rw.value[0] >> hdl_slice.offset;
	uvm_reg_data_t slice = rw.get_value(0) >> hdl_slice.offset;
	slice &= (1 << hdl_slice.size)-1;
	ok &= uvm_hdl_deposit(hdl_slice.path, slice);
      }
    }
    rw.status = (ok ? UVM_IS_OK : UVM_NOT_OK);
  }



  // Function: backdoor_read_func
  //
  // User-defined backdoor read access
  //
  // Override the default string-based DPI backdoor access read
  // for this register type.
  //

  // extern virtual function uvm_status_e backdoor_read_func(uvm_reg_item rw);
  // backdoor_read_func

  uvm_status_e backdoor_read_func(uvm_reg_item rw) {
    synchronized(this) {
      uvm_hdl_path_concat[] paths;
      uvm_reg_data_t val;
      bool ok = true;
      get_full_hdl_path(paths,rw.bd_kind);
      foreach (i, path; paths) {
	uvm_hdl_path_concat hdl_concat = path;
	val = 0;
	foreach (hdl_slice; hdl_concat.slices) {
	  uvm_info("RegMem", "backdoor_read from %s " ~
		   hdl_slice.path, UVM_DEBUG);

	  if (hdl_slice.offset < 0) {
	    ok &= uvm_hdl_read(hdl_slice.path,val);
	    continue;
	  }
	  uvm_reg_data_t slice;
	  int k = hdl_slice.offset;
           
	  ok &= uvm_hdl_read(hdl_slice.path, slice);
      
	  for(size_t idx=0; idx != hdl_slice.size; ++idx) {
	    val[k++] = slice[0];
	    slice >>= 1;
	  }
	}

	val &= (1 << _m_n_bits)-1;

	if (i == 0) {
	  // rw.value[0] = val;
	  rw.set_value(0, val);
	}
	
	// if (val !is rw.value[0]) {
	if (val !is rw.get_value(0)) {
	  uvm_error("RegModel",
		    format("Backdoor read of register %s with " ~
			   "multiple HDL copies: values are not" ~
			   " the same: %0h at path '%s', and %0h" ~
			   " at path '%s'. Returning first value.",
			   get_full_name(),
			   // rw.value[0], uvm_hdl_concat2string(paths[0]),
			   rw.get_value(0), uvm_hdl_concat2string(paths[0]),
			   val, uvm_hdl_concat2string(paths[i]))); 
	  return UVM_NOT_OK;
	}
	
	uvm_info("RegMem", 
		 // format("returned backdoor value 0x%0x", rw.value[0]),
		 format("returned backdoor value 0x%0x", rw.get_value(0)),
		 UVM_DEBUG);
      
      }

      rw.status = (ok) ? UVM_IS_OK : UVM_NOT_OK;
      return rw.status;
    }
  }



  // Function: backdoor_watch
  //
  // User-defined DUT register change monitor
  //
  // Watch the DUT register corresponding to this abstraction class
  // instance for any change in value and return when a value-change occurs.
  // This may be implemented a string-based DPI access if the simulation
  // tool provide a value-change callback facility. Such a facility does
  // not exists in the standard SystemVerilog DPI and thus no
  // default implementation for this method can be provided.
  //
  // virtual task  backdoor_watch(); endtask

  // task
  void backdoor_watch() { }

  //----------------
  // Group: Coverage
  //----------------

  // Function: include_coverage
  //
  // Specify which coverage model that must be included in
  // various block, register or memory abstraction class instances.
  //
  // The coverage models are specified by or'ing or adding the
  // <uvm_coverage_model_e> coverage model identifiers corresponding to the
  // coverage model to be included.
  //
  // The scope specifies a hierarchical name or pattern identifying
  // a block, memory or register abstraction class instances.
  // Any block, memory or register whose full hierarchical name
  // matches the specified scope will have the specified functional
  // coverage models included in them.
  //
  // The scope can be specified as a POSIX regular expression
  // or simple pattern.
  // See <uvm_resource_base::Scope Interface> for more details.
  //
  //| uvm_reg::include_coverage("*", UVM_CVR_ALL);
  //
  // The specification of which coverage model to include in
  // which abstraction class is stored in a <uvm_reg_cvr_t> resource in the
  // <uvm_resource_db> resource database,
  // in the "uvm_reg::" scope namespace.
  //

  // extern static function void include_coverage(string scope,
  // 					       uvm_reg_cvr_t models,
  // 					       uvm_object accessor = null);

  void include_coverage(string reg_scope,
			uvm_reg_cvr_t models,
			uvm_object accessor = null) {
    synchronized(this) {
      uvm_reg_cvr_rsrc_db.set("uvm_reg." ~ reg_scope,
			      "include_coverage",
			      models, accessor);
    }
  }

  // Function: build_coverage
  //
  // Check if all of the specified coverage models must be built.
  //
  // Check which of the specified coverage model must be built
  // in this instance of the register abstraction class,
  // as specified by calls to <uvm_reg::include_coverage()>.
  //
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  // Returns the sum of all coverage models to be built in the
  // register model.
  //
  // extern protected function uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models);

  // build_coverage

  uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      uvm_reg_cvr_t build_coverage_ = uvm_coverage_model_e.UVM_NO_COVERAGE;
      uvm_reg_cvr_rsrc_db.read_by_name("uvm_reg." ~ get_full_name(),
				       "include_coverage",
				       build_coverage_, this);
      return build_coverage_ & models;
    }
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

  void add_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      _m_has_cover |= models;
    }
  }


  // Function: has_coverage
  //
  // Check if register has coverage model(s)
  //
  // Returns TRUE if the register abstraction class contains a coverage model
  // for all of the models specified.
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  //
  // extern virtual function bool has_coverage(uvm_reg_cvr_t models);

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
  // for this register.
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
  // coverage models that are present in the register abstraction classes,
  // then enabled during construction.
  // See the <uvm_reg::has_coverage()> method to identify
  // the available functional coverage models.
  //
  // extern virtual function uvm_reg_cvr_t set_coverage(uvm_reg_cvr_t is_on);
  // set_coverage

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


  // Function: get_coverage
  //
  // Check if coverage measurement is on.
  //
  // Returns TRUE if measurement for all of the specified functional
  // coverage models are currently on.
  // Multiple functional coverage models can be specified by adding the
  // functional coverage model identifiers.
  //
  // See <uvm_reg::set_coverage()> for more details. 
  //
  // extern virtual function bool get_coverage(uvm_reg_cvr_t is_on);

  // get_coverage

  bool get_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      if (has_coverage(is_on) == 0)
	return 0;
      return ((_m_cover_on & is_on) == is_on);
    }
  }


  // Function: sample
  //
  // Functional coverage measurement method
  //
  // This method is invoked by the register abstraction class
  // whenever it is read or written with the specified ~data~
  // via the specified address ~map~.
  // It is invoked after the read or write operation has completed
  // but before the mirror has been updated.
  //
  // Empty by default, this method may be extended by the
  // abstraction class generator to perform the required sampling
  // in any provided functional coverage model.
  //
  // protected virtual function void sample(uvm_reg_data_t  data,
  //                                        uvm_reg_data_t  byte_en,
  //                                        bool             is_read,
  //                                        uvm_reg_map     map);
  protected void sample(uvm_reg_data_t  data,
			uvm_reg_data_t  byte_en,
			bool             is_read,
			uvm_reg_map     map) {}

  // Function: sample_values
  //
  // Functional coverage measurement method for field values
  //
  // This method is invoked by the user
  // or by the <uvm_reg_block::sample_values()> method of the parent block
  // to trigger the sampling
  // of the current field values in the
  // register-level functional coverage model.
  //
  // This method may be extended by the
  // abstraction class generator to perform the required sampling
  // in any provided field-value functional coverage model.
  //
  // virtual function void sample_values();
  void sample_values() {}

  // /*local*/ function void XsampleX(uvm_reg_data_t  data,
  //                                  uvm_reg_data_t  byte_en,
  //                                  bool             is_read,
  //                                  uvm_reg_map     map);
  void XsampleX(uvm_reg_data_t  data,
		uvm_reg_data_t  byte_en,
		bool            is_read,
		uvm_reg_map     map) {
    synchronized(this) {
      sample(data, byte_en, is_read, map);
    }
  }


  //-----------------
  // Group: Callbacks
  //-----------------
  mixin uvm_register_cb!uvm_reg_cbs;
   

  // Task: pre_write
  //
  // Called before register write.
  //
  // If the specified data value, access ~path~ or address ~map~ are modified,
  // the updated data value, access path or address map will be used
  // to perform the register operation.
  // If the ~status~ is modified to anything other than <UVM_IS_OK>,
  // the operation is aborted.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  // All register callbacks are executed before the corresponding
  // field callbacks
  //
  // virtual task pre_write(uvm_reg_item rw); endtask

  // task
  void pre_write(uvm_reg_item rw) {}


  // Task: post_write
  //
  // Called after register write.
  //
  // If the specified ~status~ is modified,
  // the updated status will be
  // returned by the register operation.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  // All register callbacks are executed before the corresponding
  // field callbacks
  //
  // virtual task post_write(uvm_reg_item rw); endtask
  // task
  void post_write(uvm_reg_item rw) {}


  // Task: pre_read
  //
  // Called before register read.
  //
  // If the specified access ~path~ or address ~map~ are modified,
  // the updated access path or address map will be used to perform
  // the register operation.
  // If the ~status~ is modified to anything other than <UVM_IS_OK>,
  // the operation is aborted.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  // All register callbacks are executed before the corresponding
  // field callbacks
  //
  // virtual task pre_read(uvm_reg_item rw); endtask
  // task
  void pre_read(uvm_reg_item rw) {}


  // Task: post_read
  //
  // Called after register read.
  //
  // If the specified readback data or ~status~ is modified,
  // the updated readback data or status will be
  // returned by the register operation.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  // All register callbacks are executed before the corresponding
  // field callbacks
  //
  // virtual task post_read(uvm_reg_item rw); endtask
  // task
  void post_read(uvm_reg_item rw) {}


  // extern virtual function void            do_print (uvm_printer printer);
  // do_print

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


  // extern virtual function string          convert2string();
  // convert2string

  override string convert2string() {
    synchronized(this) {
      string convert2string_;
      string res_str;
      string t_str;
      bool with_debug_info;

      string prefix;

      convert2string_ = format("Register %s -- %0d bytes, mirror value:'h%h",
			       get_full_name(), get_n_bytes(),get());

      if (_m_maps.length == 0) {
	convert2string_ ~= "  (unmapped)\n";
      }
      else {
	convert2string_ ~= "\n";
      }
      foreach (map, unused; _m_maps) {
	uvm_reg_map parent_map = map;
	uint offset;
	while (parent_map !is null) {
	  uvm_reg_map this_map = parent_map;
	  parent_map = this_map.get_parent_map();
	  offset = cast(int) (parent_map is null ?
			      this_map.get_base_addr(UVM_NO_HIER) :
			      parent_map.get_submap_offset(this_map));
	  prefix = prefix ~ "  ";
	  uvm_endianness_e e = this_map.get_endian();
	  convert2string_ = format("%sMapped in '%s' -- %d bytes, %s," ~
				   " offset 'h%0h\n", prefix,
				   this_map.get_full_name(),
				   this_map.get_n_bytes(), e, offset);
	}
      }
      prefix = "  ";
      foreach(field; _m_fields) {
	convert2string_ ~= "\n" ~ field.convert2string();
      }

      if (_m_read_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0) {
	  res_str = format("%s:%0d ",_m_fname, _m_lineno);
	}
	convert2string_ ~= "\n" ~ res_str ~ "currently executing read method"; 
      }
      if ( _m_write_in_progress == true) {
	if (_m_fname != "" && _m_lineno != 0)
	  res_str = format("%s:%0d ",_m_fname, _m_lineno);
	convert2string_ ~= "\n" ~ res_str ~ "currently executing write method"; 
      }
      return convert2string_;
    }
  }

  // extern virtual function uvm_object      clone      ();
  // clone

  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel registers cannot be cloned");
    return null;
  }

  // extern virtual function void            do_copy    (uvm_object rhs);
  // do_copy

  override void do_copy(uvm_object rhs) {
    uvm_fatal("RegModel","RegModel registers cannot be copied");
  }

  // extern virtual function bool             do_compare (uvm_object  rhs,
  // uvm_comparer comparer);
  // do_compare

  override bool do_compare (uvm_object  rhs,
			    uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel registers cannot be compared");
    return 0;
  }

  // extern virtual function void            do_pack    (uvm_packer packer);
  // do_pack

  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel registers cannot be packed");
  }

  // extern virtual function void            do_unpack  (uvm_packer packer);
  // do_unpack

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel registers cannot be unpacked");
  }

}
