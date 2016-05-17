//
// -------------------------------------------------------------
//    Copyright 2004-2011 Synopsys, Inc.
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
module uvm.reg.uvm_reg_block;

import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_printer;
import uvm.base.uvm_packer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_globals;
import uvm.base.uvm_resource_db;
import uvm.base.uvm_resource;

import uvm.seq.uvm_sequence_base;

import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_backdoor;
import uvm.reg.uvm_reg_defines;
import uvm.reg.uvm_reg_field;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_mem;
import uvm.reg.uvm_vreg;
import uvm.reg.uvm_vreg_field;

import std.string: format;

//------------------------------------------------------------------------
// Class: uvm_reg_block
//
// Block abstraction base class
//
// A block represents a design hierarchy. It can contain registers,
// register files, memories and sub-blocks.
//
// A block has one or more address maps, each corresponding to a physical
// interface on the block.
//
//------------------------------------------------------------------------
abstract class uvm_reg_block: uvm_object
{

  private uvm_reg_block    _parent;

  private static bool[uvm_reg_block]      _m_roots;
  private uint[uvm_reg_block]             _blks;
  uint[uvm_reg_block] get_blks() {
    synchronized(this) {
      return _blks.dup;
    }
  }
  private uint[uvm_reg]                   _regs;
  uint[uvm_reg] get_regs() {
    synchronized(this) {
      return _regs.dup;
    }
  }
  private uint[uvm_vreg]                  _vregs;
  private uint[uvm_mem]                   _mems;
  private bool[uvm_reg_map]               _maps;

  // Variable: default_path
  // Default access path for the registers and memories in this block.
  uvm_path_e               _default_path = uvm_path_e.UVM_DEFAULT_PATH;

  private string           _default_hdl_path = "RTL";
  private uvm_reg_backdoor _backdoor;
  private uvm_object_string_pool!(uvm_queue!string) _hdl_paths_pool;
  private string[string]   _root_hdl_paths;

  private bool             _locked;

  private int              _has_cover;
  private int              _cover_on;
  private string           _fname;
  private int              _lineno;

  private static int       _id;

  //----------------------
  // Group: Initialization
  //----------------------

  // Function: new
  //
  // Create a new instance and type-specific configuration
  //
  // Creates an instance of a block abstraction class with the specified
  // name.
  //
  // ~has_coverage~ specifies which functional coverage models are present in
  // the extension of the block abstraction class.
  // Multiple functional coverage models may be specified by adding their
  // symbolic names, as defined by the <uvm_coverage_model_e> type.
  //

  // extern function new(string name="", int has_coverage=UVM_NO_COVERAGE);

  // new

  this(string name="", int has_coverage = uvm_coverage_model_e.UVM_NO_COVERAGE) {
    synchronized(this) {
      super(name);
      _hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!string)
	("hdl_paths");
      this._has_cover = has_coverage;
      // Root block until registered with a parent
      _m_roots[this] = false;
    }
  }


  // Function: configure
  //
  // Instance-specific configuration
  //
  // Specify the parent block of this block.
  // A block without parent is a root block.
  //
  // If the block file corresponds to a hierarchical RTL structure,
  // it's contribution to the HDL path is specified as the ~hdl_path~.
  // Otherwise, the block does not correspond to a hierarchical RTL
  // structure (e.g. it is physically flattened) and does not contribute
  // to the hierarchical HDL path of any contained registers or memories.
  //

  // extern function void configure(uvm_reg_block parent=null,
  // 				 string hdl_path="");

  // configure

  final void configure(uvm_reg_block parent=null, string hdl_path="") {
    synchronized(this) {
      this._parent = parent; 
      if (parent !is null) {
	this._parent.add_block(this);
      }
      add_hdl_path(hdl_path);

      uvm_resource_db!(uvm_reg_block).set("uvm_reg.*", get_full_name(), this);
    }
  }



  // Function: create_map
  //
  // Create an address map in this block
  //
  // Create an address map with the specified ~name~, then
  // configures it with the following properties.
  //
  // base_addr - the base address for the map. All registers, memories,
  //             and sub-blocks within the map will be at offsets to this
  //             address
  //
  // n_bytes   - the byte-width of the bus on which this map is used 
  //
  // endian    - the endian format. See <uvm_endianness_e> for possible
  //             values
  //
  // byte_addressing - specifies whether consecutive addresses refer are 1 byte
  //             apart (TRUE) or ~n_bytes~ apart (FALSE). Default is TRUE. 
  //
  //| APB = create_map("APB", 0, 1, UVM_LITTLE_ENDIAN, 1);
  //

  // extern virtual function uvm_reg_map create_map(string name,
  // 						 uvm_reg_addr_t base_addr,
  // 						 uint n_bytes,
  // 						 uvm_endianness_e endian,
  // 						 bool byte_addressing = 1);

  // create_map

  uvm_reg_map create_map(T)(string name,
			    T base_addr,
			    uint n_bytes,
			    uvm_endianness_e endian,
			    bool byte_addressing = true) {

    synchronized(this) {
      uvm_reg_map  map;

      uvm_reg_addr_t base_addr_ = base_addr;
      if (this._locked) {
	uvm_error("RegModel", "Cannot add map to locked model");
	return null;
      }

      map = uvm_reg_map.type_id.create(name,null,this.get_full_name());
      map.configure(this, base_addr_, n_bytes, endian, byte_addressing);

      this._maps[map] = true;
      if (_maps.length == 1) {
	_default_map = map;
      }

      return map;
    }
  }


  // Function: check_data_width
  //
  // Check that the specified data width (in bits) is less than
  // or equal to the value of `UVM_REG_DATA_WIDTH
  //
  // This method is designed to be called by a static initializer
  //
  //| class my_blk extends uvm_reg_block;
  //|   local static bit m_data_width = check_data_width(356);
  //|   ...
  //| endclass
  //

  // extern protected static function bool check_data_width(uint width);

  // check_data_width

  static bool check_data_width(uint width) {
    if (width <= uvm_reg_data_t.SIZE) return true;

    uvm_report_fatal("RegModel", format("Register model requires that UVM_REG_DATA_WIDTH be defined as %0d or greater. Currently defined as %0d", width, UVM_REG_DATA_WIDTH));

    return false;
  }




  // Function: set_default_map
  //
  // Defines the default address map
  //
  // Set the specified address map as the <default_map> for this
  // block. The address map must be a map of this address block.
  //

  // extern function void set_default_map (uvm_reg_map map);

  // set_default_map

  void set_default_map(uvm_reg_map map) {
    synchronized(this) {
      if (map !in _maps) {
	uvm_report_warning("RegModel", "Map '" ~ map.get_full_name() ~
		    "' does not exist in block");
      }
      _default_map = map;
    }
  }


  // Variable: default_map
  //
  // Default address map
  //
  // Default address map for this block, to be used when no
  // address map is specified for a register operation and that
  // register is accessible from more than one address map.
  //
  // It is also the implciit address map for a block with a single,
  // unamed address map because it has only one physical interface.
  //
  private uvm_reg_map _default_map;

  // extern function uvm_reg_map get_default_map ();
  // get_default_map

  final uvm_reg_map get_default_map() {
    synchronized(this) {
      return _default_map;
    }
  }

  // extern virtual function void set_parent(uvm_reg_block parent);
  // set_parent

  void set_parent(uvm_reg_block parent) {
    synchronized(this) {
      if (this !is parent) {
	this._parent = parent;
      }
    }
  }



  // /*private*/ extern function void add_block (uvm_reg_block blk);
  // add_block

  final void add_block (uvm_reg_block blk) {
    synchronized(this) {
      if (this.is_locked()) {
	uvm_error("RegModel", "Cannot add subblock to locked block model");
	return;
      }
      if (blk in this._blks) {
	uvm_error("RegModel", "Subblock '" ~ blk.get_name() ~ 
		  "' has already been registered with block '" ~ get_name() ~ "'");
	return;
      }
      _blks[blk] = _id++;
      if (blk in _m_roots) _m_roots.remove(blk);
    }
  }

  // /*private*/ extern function void add_map   (uvm_reg_map map);
  // add_map

  final void add_map(uvm_reg_map map) {
    synchronized(this) {
      if (this._locked) {
	uvm_error("RegModel", "Cannot add map to locked model");
	return;
      }

      if (map in this._maps) {
	uvm_error("RegModel", "Map '" ~ map.get_name() ~ 
		  "' already exists in '" ~ get_full_name() ~ "'");
	return;
      }

      this._maps[map] = true;
      if (_maps.length == 1) {
	_default_map = map;
      }
    }
  }


  // /*private*/ extern function void add_reg   (uvm_reg  rg);
  // add_reg

  final void add_reg(uvm_reg rg) {
    synchronized(this) {
      if (this.is_locked()) {
	uvm_error("RegModel", "Cannot add register to locked block model");
	return;
      }

      if (rg in this._regs) {
	uvm_error("RegModel", "Register '" ~ rg.get_name() ~ 
		  "' has already been registered with block '" ~ get_name() ~ "'");
	return;
      }

      _regs[rg] = _id++;
    }
  }


  // /*private*/ extern function void add_vreg  (uvm_vreg vreg);
  // add_vreg

  final void add_vreg(uvm_vreg vreg) {
    synchronized(this) {
      if (this.is_locked()) {
	uvm_error("RegModel", "Cannot add virtual register to locked block model");
	return;
      }

      if (vreg in this._vregs) {
	uvm_error("RegModel", "Virtual register '" ~ vreg.get_name() ~ 
		  "' has already been registered with block '" ~ get_name() ~ "'");
	return;
      }
      _vregs[vreg] = _id++;
    }
  }


  // /*private*/ extern function void add_mem   (uvm_mem  mem);
  // add_mem

  void add_mem(uvm_mem mem) {
    synchronized(this) {
      if (this.is_locked()) {
	uvm_error("RegModel", "Cannot add memory to locked block model");
	return;
      }

      if (mem in this._mems) {
	uvm_error("RegModel", "Memory '" ~ mem.get_name() ~ 
		  "' has already been registered with block '" ~ get_name() ~ "'");
	return;
      }
      _mems[mem] = _id++;
    }
  }


  // Function: lock_model
  //
  // Lock a model and build the address map.
  //
  // Recursively lock an entire register model
  // and build the address maps to enable the
  // <uvm_reg_map::get_reg_by_offset()> and
  // <uvm_reg_map::get_mem_by_offset()> methods.
  //
  // Once locked, no further structural changes,
  // such as adding registers or memories,
  // can be made.
  //
  // It is not possible to unlock a model.
  //

  // extern virtual function void lock_model();
  // lock_model

  void lock_model() {
    synchronized(this) {

      if (is_locked()) return;

      _locked = true;

      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	rg.Xlock_modelX();
      }

      foreach (mem_, unused; _mems) {
	uvm_mem mem = mem_;
	mem.Xlock_modelX();
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk=blk_;
	blk.lock_model();
      }

      if (this._parent is null) {
	int max_size = uvm_reg.get_max_size();

	if (uvm_reg_field.get_max_size() > max_size) {
	  max_size = uvm_reg_field.get_max_size();
	}

	if (uvm_mem.get_max_size() > max_size) {
	  max_size = uvm_mem.get_max_size();
	}

	if (max_size > UVM_REG_DATA_WIDTH) {
	  uvm_report_fatal("RegModel",
		    format("Register model requires that UVM_REG_DATA_WIDTH be defined as %0d or greater. Currently defined as %0d",
			   max_size, UVM_REG_DATA_WIDTH));
	}

	Xinit_address_mapsX();

	// Check that root register models have unique names

	// Has this name has been checked before?
	if (_m_roots[this] != true) {
	  int n;

	  foreach (_blk, unused; _m_roots) {
            uvm_reg_block blk = _blk;

            if (blk.get_name() == get_name()) {
	      _m_roots[blk] = true;
	      n++;
	    }
	  }

	  if (n > 1) {
            uvm_error("UVM/REG/DUPLROOT",
		      format("There are %0d root register models named \"%s\". The names of the root register models have to be unique",
			     n, get_name()));
	      }
	}
      }
    }
  }


  // Function: is_locked
  //
  // Return TRUE if the model is locked.
  //

  // extern function bool is_locked();
  // is_locked

  final bool is_locked() {
    synchronized(this) {
      return this._locked;
    }
  }




  //---------------------
  // Group: Introspection
  //---------------------


  // Function: get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this block.
  //


  // Function: get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this block.
  // The base of the hierarchical name is the root block.
  //

  // extern virtual function string get_full_name();
  override string get_full_name() {
    synchronized(this) {
      if (_parent is null) {
	return get_name();
      }

      return _parent.get_full_name() ~ "." ~ get_name();

    }
  }

  // Function: get_parent
  //
  // Get the parent block
  //
  // If this a top-level block, returns ~null~. 
  //

  // extern virtual function uvm_reg_block get_parent();

  // get_parent

  uvm_reg_block get_parent() {
    synchronized(this) {
      return this._parent;
    }
  }


  // Function: get_root_blocks
  //
  // Get the all root blocks
  //
  // Returns an array of all root blocks in the simulation.
  //

  // extern static  function void get_root_blocks(ref uvm_reg_block blks[$]);
  // get_root_blocks

  static void get_root_blocks(out uvm_reg_block[] blks) {
    // synchronized
    foreach (blk, unused; _m_roots) {
      blks ~= blk;
    }
  }

      

  // Function: find_blocks
  //
  // Find the blocks whose hierarchical names match the
  // specified ~name~ glob.
  // If a ~root~ block is specified, the name of the blocks are
  // relative to that block, otherwise they are absolute.
  //
  // Returns the number of blocks found.
  //

  // extern static function int find_blocks(input string        name,
  // 					 ref   uvm_reg_block blks[$],
  // 					 input uvm_reg_block root = null,
  // 					 input uvm_object    accessor = null);
      
  // find_blocks

  static int find_blocks(string              name,
			 out uvm_reg_block[] blks,
			 uvm_reg_block       root = null,
			 uvm_object          accessor = null) {
    // synchronized

    uvm_resource_pool rpl = uvm_resource_pool.get();
    uvm_resource_types.rsrc_q_t rs;

    // blks.remove(); -- taken care as declared out

    if (root !is null) name = root.get_full_name() ~ "." ~ name;

    rs = rpl.lookup_regex(name, "uvm_reg.");
    for (int i = 0; i < rs.length; i++) {
      auto blk = cast(uvm_resource!(uvm_reg_block)) rs.get(i);
      if (blk is null) continue;
      blks ~= blk.read(accessor);
    }
   
    return cast(uint) blks.length;
  }


  // Function: find_block
  //
  // Find the first block whose hierarchical names match the
  // specified ~name~ glob.
  // If a ~root~ block is specified, the name of the blocks are
  // relative to that block, otherwise they are absolute.
  //
  // Returns the first block found or ~null~ otherwise.
  // A warning is issued if more than one block is found.
  //

  // extern static function uvm_reg_block find_block(input string        name,
  // 						  input uvm_reg_block root = null,
  // 						  input uvm_object    accessor = null);
  // find_blocks

  static uvm_reg_block find_block(string        name,
				  uvm_reg_block root = null,
				  uvm_object    accessor = null) {
    // synchronized
    uvm_reg_block[] blks_;
    if (!find_blocks(name, blks_, root, accessor)) {
      return null;
    }

    if (blks_.length > 1) {
      uvm_report_warning("MRTH1BLK",
		  "More than one block matched the name \"" ~ name ~ "\".");
    }
   

    return blks_[0];
  }


      

  // Function: get_blocks
  //
  // Get the sub-blocks
  //
  // Get the blocks instantiated in this blocks.
  // If ~hier~ is TRUE, recursively includes any sub-blocks.
  //

  // extern virtual function void get_blocks (ref uvm_reg_block  blks[$],
  // 					   input uvm_hier_e hier=UVM_HIER);

  // get_blocks

  void get_blocks(ref uvm_reg_block[] blks,
			 in uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized(this) {

      foreach (blk_, unused; this._blks) {
	uvm_reg_block blk = blk_;
	blks ~= blk;
	if (hier == uvm_hier_e.UVM_HIER) {
	  blk.get_blocks(blks);
	}
      }
    }
  }

  // Function: get_maps
  //
  // Get the address maps
  //
  // Get the address maps instantiated in this block.
  //

  // extern virtual function void get_maps (ref uvm_reg_map maps[$]);
  // get_maps

  void get_maps(ref uvm_reg_map[] maps) {
    synchronized(this) {
      foreach (map, unused; this._maps) {
	maps ~= map;
      }
    }
  }



  // Function: get_registers
  //
  // Get the registers
  //
  // Get the registers instantiated in this block.
  // If ~hier~ is TRUE, recursively includes the registers
  // in the sub-blocks.
  //
  // Note that registers may be located in different and/or multiple
  // address maps. To get the registers in a specific address map,
  // use the <uvm_reg_map::get_registers()> method.
  //
  // extern virtual function void get_registers (ref uvm_reg regs[$],
  // 					      input uvm_hier_e hier=UVM_HIER);

  // get_registers

  void get_registers(ref uvm_reg[] regs,
		     in uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (rg, unused; this._regs) {
	regs ~= rg;
      }

      if (hier == uvm_hier_e.UVM_HIER)
	foreach (blk_, unused; _blks) {
	  uvm_reg_block blk = blk_;
	  blk.get_registers(regs);
	}
    }
  }


  // Function: get_fields
  //
  // Get the fields
  //
  // Get the fields in the registers instantiated in this block.
  // If ~hier~ is TRUE, recursively includes the fields of the registers
  // in the sub-blocks.
  //
  // extern virtual function void get_fields (ref uvm_reg_field  fields[$],
  // 					   input uvm_hier_e hier=UVM_HIER);

  // get_fields

  void get_fields(ref uvm_reg_field[] fields,
			 in uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	rg.get_fields(fields);
      }
   
      if (hier == uvm_hier_e.UVM_HIER)
	foreach (blk_, unused; _blks) {
	  uvm_reg_block blk = blk_;
	  blk.get_fields(fields);
	}
    }
  }



  // Function: get_memories
  //
  // Get the memories
  //
  // Get the memories instantiated in this block.
  // If ~hier~ is TRUE, recursively includes the memories
  // in the sub-blocks.
  //
  // Note that memories may be located in different and/or multiple
  // address maps. To get the memories in a specific address map,
  // use the <uvm_reg_map::get_memories()> method.
  //

  // extern virtual function void get_memories (ref uvm_mem mems[$],
  // 					     input uvm_hier_e hier=UVM_HIER);

  // get_memories

  void get_memories(ref uvm_mem[] mems,
			   in uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (mem_, unused; this._mems) {
	uvm_mem mem = mem_;
	mems ~= mem;
      }

      if (hier == uvm_hier_e.UVM_HIER)
	foreach (blk_, unused; _blks) {
	  uvm_reg_block blk = blk_;
	  blk.get_memories(mems);
	}
    }
  }

  // Function: get_virtual_registers
  //
  // Get the virtual registers
  //
  // Get the virtual registers instantiated in this block.
  // If ~hier~ is TRUE, recursively includes the virtual registers
  // in the sub-blocks.
  //

  // extern virtual function void get_virtual_registers(ref uvm_vreg regs[$],
  // 						     input uvm_hier_e hier=UVM_HIER);

  // get_virtual_registers

  void get_virtual_registers(ref uvm_vreg[] regs,
				    in uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (rg, unused; _vregs) {
	regs ~= rg;
      }

      if (hier == uvm_hier_e.UVM_HIER)
	foreach (blk_, unused; _blks) {
	  uvm_reg_block blk = blk_;
	  blk.get_virtual_registers(regs);
	}
    }
  }


  // Function: get_virtual_fields
  //
  // Get the virtual fields
  //
  // Get the virtual fields from the virtual registers instantiated
  // in this block.
  // If ~hier~ is TRUE, recursively includes the virtual fields
  // in the virtual registers in the sub-blocks.
  //
  // extern virtual function void get_virtual_fields (ref uvm_vreg_field fields[$],
  // 						   input uvm_hier_e hier=UVM_HIER);

  // get_virtual_fields

  void get_virtual_fields(ref uvm_vreg_field[] fields,
				 in uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (vreg_, unused; _vregs) {
	uvm_vreg vreg = vreg_;
	vreg.get_fields(fields);
      }
   
      if (hier == uvm_hier_e.UVM_HIER)
	foreach (blk_, unused; _blks) {
	  uvm_reg_block blk = blk_;
	  blk.get_virtual_fields(fields);
	}
    }
  }



  // Function: get_block_by_name
  //
  // Finds a sub-block with the specified simple name.
  //
  // The name is the simple name of the block, not a hierarchical name.
  // relative to this block.
  // If no block with that name is found in this block, the sub-blocks
  // are searched for a block of that name and the first one to be found
  // is returned.
  //
  // If no blocks are found, returns ~null~.
  //

  // extern virtual function uvm_reg_block get_block_by_name (string name);  
  // get_block_by_name

  uvm_reg_block get_block_by_name(string name) {
    synchronized(this) {
      if (get_name() == name) {
	return this;
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;

	if (blk.get_name() == name)
	  return blk;
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	uvm_reg_block[] subblks;
	blk_.get_blocks(subblks, uvm_hier_e.UVM_HIER);

	foreach (subblk; subblks)
	  if (subblk.get_name() == name)
	    return subblk;
      }

      uvm_report_warning("RegModel", "Unable to locate block '" ~ name ~
		  "' in block '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  // Function: get_map_by_name
  //
  // Finds an address map with the specified simple name.
  //
  // The name is the simple name of the address map, not a hierarchical name.
  // relative to this block.
  // If no map with that name is found in this block, the sub-blocks
  // are searched for a map of that name and the first one to be found
  // is returned.
  //
  // If no address maps are found, returns ~null~.
  //

  // extern virtual function uvm_reg_map get_map_by_name (string name);

  // get_map_by_name

  uvm_reg_map get_map_by_name(string name) {
    synchronized(this) {
      uvm_reg_map[] _maps;

      this.get_maps(_maps);

      foreach (map; _maps) {
	if (map.get_name() == name) {
	  return map;
	}
      }

      foreach (map; _maps) {
	uvm_reg_map[] submaps;
	map.get_submaps(submaps, uvm_hier_e.UVM_HIER);

	foreach (submap; submaps) {
	  if (submap.get_name() == name) {
	    return submap;
	  }
	}
      }

      uvm_report_warning("RegModel", "Map with name '" ~ name ~
		  "' does not exist in block");
      return null;
    }
  }

  // Function: get_reg_by_name
  //
  // Finds a register with the specified simple name.
  //
  // The name is the simple name of the register, not a hierarchical name.
  // relative to this block.
  // If no register with that name is found in this block, the sub-blocks
  // are searched for a register of that name and the first one to be found
  // is returned.
  //
  // If no registers are found, returns ~null~.
  //

  // extern virtual function uvm_reg get_reg_by_name (string name);

  // get_reg_by_name

  uvm_reg get_reg_by_name(string name) {
    synchronized(this) {

      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	if (rg.get_name() == name)
	  return rg;
      }
    

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	uvm_reg[] subregs;
	blk_.get_registers(subregs, uvm_hier_e.UVM_HIER);

	foreach (subreg; subregs)
	  if (subreg.get_name() == name)
	    return subreg;
      }

      uvm_report_warning("RegModel", "Unable to locate register '" ~ name ~ 
		  "' in block '" ~ get_full_name() ~ "'");
      return null;
    }
  }


  // Function: get_field_by_name
  //
  // Finds a field with the specified simple name.
  //
  // The name is the simple name of the field, not a hierarchical name.
  // relative to this block.
  // If no field with that name is found in this block, the sub-blocks
  // are searched for a field of that name and the first one to be found
  // is returned.
  //
  // If no fields are found, returns ~null~.
  //

  // extern virtual function uvm_reg_field get_field_by_name (string name);

  // get_field_by_name

  uvm_reg_field get_field_by_name(string name) {
    synchronized(this) {

      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	uvm_reg_field[] fields;

	rg.get_fields(fields);
	foreach (field; fields) {
	  if (field.get_name() == name) {
	    return field;
	  }
	}
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	uvm_reg[] subregs;
	blk_.get_registers(subregs, uvm_hier_e.UVM_HIER);

	foreach (subreg; subregs) {
	  uvm_reg_field[] fields;
	  subreg.get_fields(fields);
	  foreach (field; fields) {
	    if (field.get_name() == name) {
	      return field;
	    }
	  }
	}
      }

      uvm_report_warning("RegModel", "Unable to locate field '" ~ name ~ 
		  "' in block '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  // Function: get_mem_by_name
  //
  // Finds a memory with the specified simple name.
  //
  // The name is the simple name of the memory, not a hierarchical name.
  // relative to this block.
  // If no memory with that name is found in this block, the sub-blocks
  // are searched for a memory of that name and the first one to be found
  // is returned.
  //
  // If no memories are found, returns ~null~.
  //

  // extern virtual function uvm_mem get_mem_by_name (string name);
  uvm_mem get_mem_by_name(string name) {
    synchronized(this) {
      foreach (mem_, unused; _mems) {
	uvm_mem mem = mem_;
	if (mem.get_name() == name) {
	  return mem;
	}
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	uvm_mem[] submems;
	blk_.get_memories(submems, uvm_hier_e.UVM_HIER);

	foreach (submem; submems) {
	  if (submem.get_name() == name) {
	    return submem;
	  }
	}
      }
      

      uvm_report_warning("RegModel", "Unable to locate memory '" ~ name ~ 
		  "' in block '" ~ get_full_name() ~ "'");
      return null;
    }
  }


  // Function: get_vreg_by_name
  //
  // Finds a virtual register with the specified simple name.
  //
  // The name is the simple name of the virtual register,
  // not a hierarchical name.
  // relative to this block.
  // If no virtual register with that name is found in this block,
  // the sub-blocks are searched for a virtual register of that name
  // and the first one to be found is returned.
  //
  // If no virtual registers are found, returns ~null~.
  //

  // extern virtual function uvm_vreg get_vreg_by_name (string name);

  // get_vreg_by_name

  uvm_vreg get_vreg_by_name(string name) {
    synchronized(this) {
      foreach (rg_, unused; _vregs) {
	uvm_vreg rg = rg_;
	if (rg.get_name() == name) {
	  return rg;
	}
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	uvm_vreg[] subvregs;
	blk_.get_virtual_registers(subvregs, uvm_hier_e.UVM_HIER);

	foreach (subvreg; subvregs) {
	  if (subvreg.get_name() == name) {
	    return subvreg;
	  }
	}
      }

      uvm_report_warning("RegModel", "Unable to locate virtual register '" ~ name ~ 
		  "' in block '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  // Function: get_vfield_by_name
  //
  // Finds a virtual field with the specified simple name.
  //
  // The name is the simple name of the virtual field,
  // not a hierarchical name.
  // relative to this block.
  // If no virtual field with that name is found in this block,
  // the sub-blocks are searched for a virtual field of that name
  // and the first one to be found is returned.
  //
  // If no virtual fields are found, returns ~null~.
  //

  // extern virtual function uvm_vreg_field get_vfield_by_name (string name);
  // get_vfield_by_name

  uvm_vreg_field get_vfield_by_name(string name) {
    synchronized(this) {
      foreach (rg_, unused; _vregs) {
	uvm_vreg rg = rg_;
	uvm_vreg_field[] fields;

	rg.get_fields(fields);
	foreach (field; fields) {
	  if (field.get_name() == name) {
	    return field;
	  }
	}
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	uvm_vreg[] subvregs;
	blk_.get_virtual_registers(subvregs, uvm_hier_e.UVM_HIER);

	foreach (subvreg; subvregs) {
	  uvm_vreg_field[] fields;
	  subvreg.get_fields(fields);
	  foreach (field; fields)
	    if (field.get_name() == name)
	      return field;
	}
      }

      uvm_report_warning("RegModel", "Unable to locate virtual field '" ~ name ~ 
		  "' in block '" ~ get_full_name() ~ "'");

      return null;
    }
  }



  //----------------
  // Group: Coverage
  //----------------


  // Function: build_coverage
  //
  // Check if all of the specified coverage model must be built.
  //
  // Check which of the specified coverage model must be built
  // in this instance of the block abstraction class,
  // as specified by calls to <uvm_reg::include_coverage()>.
  //
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  // Returns the sum of all coverage models to be built in the
  // block model.
  //

  // extern protected function uvm_reg_cvr_t build_coverage(uvm_reg_cvr_t models);

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
      this._has_cover |= models;
    }
  }



  // Function: has_coverage
  //
  // Check if block has coverage model(s)
  //
  // Returns TRUE if the block abstraction class contains a coverage model
  // for all of the models specified.
  // Models are specified by adding the symbolic value of individual
  // coverage model as defined in <uvm_coverage_model_e>.
  //
  // extern virtual function bool has_coverage(uvm_reg_cvr_t models);

  // has_coverage

  bool has_coverage(uvm_reg_cvr_t models) {
    synchronized(this) {
      return ((this._has_cover & models) == models);
    }
  }

  // Function: set_coverage
  //
  // Turns on coverage measurement.
  //
  // Turns the collection of functional coverage measurements on or off
  // for this block and all blocks, registers, fields and memories within it.
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
  // coverage models that are present in the various abstraction classes,
  // then enabled during construction.
  // See the <uvm_reg_block::has_coverage()> method to identify
  // the available functional coverage models.
  //

  // extern virtual function uvm_reg_cvr_t set_coverage(uvm_reg_cvr_t is_on);
  // set_coverage

  uvm_reg_cvr_t set_coverage(uvm_reg_cvr_t is_on) {
    synchronized(this) {
      this._cover_on = this._has_cover & is_on;

      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	rg.set_coverage(is_on);
      }

      foreach (mem_, unused; _mems) {
	uvm_mem mem = mem_;
	mem.set_coverage(is_on);
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	blk.set_coverage(is_on);
      }

      return cast(uvm_reg_cvr_t) this._cover_on;
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
  // See <uvm_reg_block::set_coverage()> for more details. 
  //

  // extern virtual function bool get_coverage(uvm_reg_cvr_t is_on = UVM_CVR_ALL);
  // get_coverage

  bool get_coverage(uvm_reg_cvr_t is_on = uvm_coverage_model_e.UVM_CVR_ALL) {
    synchronized(this) {
      if (this.has_coverage(is_on) == false) return false;
      return ((this._cover_on & is_on) == is_on);
    }
  }

  // Function: sample
  //
  // Functional coverage measurement method
  //
  // This method is invoked by the block abstraction class
  // whenever an address within one of its address map
  // is succesfully read or written.
  // The specified offset is the offset within the block,
  // not an absolute address.
  //
  // Empty by default, this method may be extended by the
  // abstraction class generator to perform the required sampling
  // in any provided functional coverage model.
  //
  protected void  sample(uvm_reg_addr_t offset, bool is_read,
			 uvm_reg_map map) { }


  // Function: sample_values
  //
  // Functional coverage measurement method for field values
  //
  // This method is invoked by the user
  // or by the <uvm_reg_block::sample_values()> method of the parent block
  // to trigger the sampling
  // of the current field values in the
  // block-level functional coverage model.
  // It recursively invokes the <uvm_reg_block::sample_values()>
  // and <uvm_reg::sample_values()> methods
  // in the blocks and registers in this block.
  //
  // This method may be extended by the
  // abstraction class generator to perform the required sampling
  // in any provided field-value functional coverage model.
  // If this method is extended, it MUST call super.sample_values().
  //

  // extern virtual function void sample_values();

  // sample_values

  void sample_values() {
    synchronized(this) {
      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	rg.sample_values();
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	blk.sample_values();
      }
    }
  }

  // /*private*/ extern function void XsampleX(uvm_reg_addr_t addr,
  // 					  bool            is_read,
  // 					  uvm_reg_map    map);
  // XsampleX

  void XsampleX(uvm_reg_addr_t addr,
		       bool           is_read,
		       uvm_reg_map    map) {
    synchronized(this) {
      sample(addr, is_read, map);
      if (_parent !is null) {
	// ToDo: Call XsampleX in the parent block
	//       with the offset and map within that block's context
      }
    }
  }



  //--------------
  // Group: Access
  //--------------

  // Function: get_default_path
  //
  // Default access path
  //
  // Returns the default access path for this block.
  //

  // extern virtual function uvm_path_e get_default_path();

  // get_default_path

   uvm_path_e get_default_path() {
    synchronized(this) {
      if (this._default_path != uvm_path_e.UVM_DEFAULT_PATH) {
	return this._default_path;
      }

      if (this._parent !is null) {
	return this._parent.get_default_path();
      }

      return UVM_FRONTDOOR;
    }
  }


  // Function: reset
  //
  // Reset the mirror for this block.
  //
  // Sets the mirror value of all registers in the block and sub-blocks
  // to the reset value corresponding to the specified reset event.
  // See <uvm_reg_field::reset()> for more details.
  // Does not actually set the value of the registers in the design,
  // only the values mirrored in their corresponding mirror.
  //

  // extern virtual function void reset(string kind = "HARD");
  // reset

  void reset(string kind = "HARD") {
    synchronized(this) {
      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	rg.reset(kind);
      }

      foreach (blk_, unused; _blks) {
	uvm_reg_block blk = blk_;
	blk.reset(kind);
      }
    }
  }




  // Function: needs_update
  //
  // Check if DUT registers need to be written
  //
  // If a mirror value has been modified in the abstraction model
  // without actually updating the actual register
  // (either through randomization or via the <uvm_reg::set()> method,
  // the mirror and state of the registers are outdated.
  // The corresponding registers in the DUT need to be updated.
  //
  // This method returns TRUE if the state of at lest one register in
  // the block or sub-blocks needs to be updated to match the mirrored
  // values.
  // The mirror values, or actual content of registers, are not modified.
  // For additional information, see <uvm_reg_block::update()> method.
  //

  // extern virtual function bool needs_update();
  // needs_update

  bool needs_update() {
    synchronized(this) {
      foreach (rg_, unused; _regs) {
	uvm_reg rg = rg_;
	if (rg.needs_update())
	  return true;
      }
      foreach (blk_, unused; _blks) {
	uvm_reg_block blk =blk_;
	if (blk.needs_update())
	  return true;
      }
      return false;
    }
  }

  // Task: update
  //
  // Batch update of register.
  //
  // Using the minimum number of write operations, updates the registers
  // in the design to match the mirrored values in this block and sub-blocks.
  // The update can be performed using the physical
  // interfaces (front-door access) or back-door accesses.
  // This method performs the reverse operation of <uvm_reg_block::mirror()>. 
  //

  // extern virtual task update(output uvm_status_e       status,
  // 			     input  uvm_path_e         path = UVM_DEFAULT_PATH,
  // 			     input  uvm_sequence_base  parent = null,
  // 			     input  int                prior = -1,
  // 			     input  uvm_object         extension = null,
  // 			     input  string             fname = "",
  // 			     input  int                lineno = 0);

  // update

  // task
  void update(out uvm_status_e   status,
	      uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
	      uvm_sequence_base  parent = null,
	      int                prior = -1,
	      uvm_object         extension = null,
	      string             fname = "",
	      int                lineno = 0) {
    status = UVM_IS_OK;

    if (!needs_update()) {
      uvm_report_info("RegModel", format("%s:%0d - RegModel block %s does not need updating",
				  fname, lineno, this.get_name()), UVM_HIGH);
      return;
    }
   
    uvm_report_info("RegModel", format("%s:%0d - Updating model block %s with %s path",
				fname, lineno, this.get_name(), path ), UVM_HIGH);

    foreach (rg_, unused; get_regs()) {
      uvm_reg rg = rg_;
      if (rg.needs_update()) {
	rg.update(status, path, null, parent, prior, extension);
	if (status != UVM_IS_OK && status != UVM_HAS_X) {
	  uvm_error("RegModel", format("Register \"%s\" could not be updated",
				       rg.get_full_name()));
	  return;
	}
      }
    }

    foreach (blk_, unused; get_blks()) {
      uvm_reg_block blk = blk_;
      blk.update(status,path,parent,prior,extension,fname,lineno);
    }
  }


  // Task: mirror
  //
  // Update the mirrored values
  //
  // Read all of the registers in this block and sub-blocks and update their
  // mirror values to match their corresponding values in the design.
  // The mirroring can be performed using the physical interfaces
  // (front-door access) or back-door accesses.
  // If the ~check~ argument is specified as <UVM_CHECK>,
  // an error message is issued if the current mirrored value
  // does not match the actual value in the design.
  // This method performs the reverse operation of <uvm_reg_block::update()>.
  // 

  // extern virtual task mirror(output uvm_status_e       status,
  // 			     input  uvm_check_e        check = UVM_NO_CHECK,
  // 			     input  uvm_path_e         path  = UVM_DEFAULT_PATH,
  // 			     input  uvm_sequence_base  parent = null,
  // 			     input  int                prior = -1,
  // 			     input  uvm_object         extension = null,
  // 			     input  string             fname = "",
  // 			     input  int                lineno = 0);

  // mirror

  // task
  void mirror(out uvm_status_e   status,
	      uvm_check_e        check = uvm_check_e.UVM_NO_CHECK,
	      uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
	      uvm_sequence_base  parent = null,
	      int                prior = -1,
	      uvm_object         extension = null,
	      string             fname = "",
	      int                lineno = 0) {

    uvm_status_e final_status = UVM_IS_OK;

    foreach (rg_, unused; get_regs()) { 
      uvm_reg rg = rg_;
      rg.mirror(status, check, path, null,
		parent, prior, extension, fname, lineno);
      if (status != UVM_IS_OK && status != UVM_HAS_X) {
	final_status = status;
      }
    }

    foreach (blk_, unused; get_blks()) {
      uvm_reg_block blk = blk_;

      blk.mirror(status, check, path, parent, prior, extension, fname, lineno);
      if (status != UVM_IS_OK && status != UVM_HAS_X) {
	final_status = status;
      }
    }
  }



  // Task: write_reg_by_name
  //
  // Write the named register
  //
  // Equivalent to <get_reg_by_name()> followed by <uvm_reg::write()>
  //

  // extern virtual task write_reg_by_name(
  // 					output uvm_status_e        status,
  // 					input  string              name,
  // 					input  uvm_reg_data_t      data,
  // 					input  uvm_path_e     path = UVM_DEFAULT_PATH,
  // 					input  uvm_reg_map         map = null,
  // 					input  uvm_sequence_base   parent = null,
  // 					input  int                 prior = -1,
  // 					input  uvm_object          extension = null,
  // 					input  string              fname = "",
  // 					input  int                 lineno = 0);

  // write_reg_by_name

  void write_reg_by_name(out uvm_status_e    status,
			 string              name,
			 uvm_reg_data_t      data,
			 uvm_path_e          path = uvm_path_e.UVM_DEFAULT_PATH,
			 uvm_reg_map         map = null,
			 uvm_sequence_base   parent = null,
			 int                 prior = -1,
			 uvm_object          extension = null,
			 string              fname = "",
			 int                 lineno = 0) {
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    status = UVM_NOT_OK;
    uvm_reg rg = this.get_reg_by_name(name);
    if (rg !is null) {
      rg.write(status, data, path, map, parent, prior, extension);
    }
  }



  // Task: read_reg_by_name
  //
  // Read the named register
  //
  // Equivalent to <get_reg_by_name()> followed by <uvm_reg::read()>
  //
  // extern virtual task read_reg_by_name(
  // 				       output uvm_status_e       status,
  // 				       input  string             name,
  // 				       output uvm_reg_data_t     data,
  // 				       input  uvm_path_e    path = UVM_DEFAULT_PATH,
  // 				       input  uvm_reg_map        map = null,
  // 				       input  uvm_sequence_base  parent = null,
  // 				       input  int                prior = -1,
  // 				       input  uvm_object         extension = null,
  // 				       input  string             fname = "",
  // 				       input  int                lineno = 0);

  // read_reg_by_name

  void read_reg_by_name(out uvm_status_e       status,
			string                 name,
			out uvm_reg_data_t     data,
			uvm_path_e             path = uvm_path_e.UVM_DEFAULT_PATH,
			uvm_reg_map            map = null,
			uvm_sequence_base      parent = null,
			int                    prior = -1,
			uvm_object             extension = null,
			string                 fname = "",
			int                    lineno = 0) {
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }
    status = UVM_NOT_OK;
    uvm_reg rg = this.get_reg_by_name(name);
    if (rg !is null) {
      rg.read(status, data, path, map, parent, prior, extension);
    }
  }


  // Task: write_mem_by_name
  //
  // Write the named memory
  //
  // Equivalent to <get_mem_by_name()> followed by <uvm_mem::write()>
  //

  // extern virtual task write_mem_by_name(
  // 					output uvm_status_e       status,
  // 					input  string             name,
  // 					input  uvm_reg_addr_t     offset,
  // 					input  uvm_reg_data_t     data,
  // 					input  uvm_path_e    path = UVM_DEFAULT_PATH,
  // 					input  uvm_reg_map        map = null,
  // 					input  uvm_sequence_base  parent = null,
  // 					input  int                prior = -1,
  // 					input  uvm_object         extension = null,
  // 					input  string             fname = "",
  // 					input  int                lineno = 0);
  // write_mem_by_name

  void write_mem_by_name(out uvm_status_e  status,
			 string             name,
			 uvm_reg_addr_t     offset,
			 uvm_reg_data_t     data,
			 uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
			 uvm_reg_map        map = null,
			 uvm_sequence_base  parent = null,
			 int                prior = -1,
			 uvm_object         extension = null,
			 string             fname = "",
			 int                lineno = 0) {
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }

    status = UVM_NOT_OK;
    uvm_mem mem = get_mem_by_name(name);
    if (mem !is null) {
      mem.write(status, offset, data, path, map, parent, prior, extension);
    }
  }

  // Task: read_mem_by_name
  //
  // Read the named memory
  //
  // Equivalent to <get_mem_by_name()> followed by <uvm_mem::read()>
  //
  // extern virtual task read_mem_by_name(
  // 				       output uvm_status_e       status,
  // 				       input  string             name,
  // 				       input  uvm_reg_addr_t     offset,
  // 				       output uvm_reg_data_t     data,
  // 				       input  uvm_path_e    path = UVM_DEFAULT_PATH,
  // 				       input  uvm_reg_map        map = null,
  // 				       input  uvm_sequence_base  parent = null,
  // 				       input  int                prior = -1,
  // 				       input  uvm_object         extension = null,
  // 				       input  string             fname = "",
  // 				       input  int                lineno = 0);


  // read_mem_by_name


  void read_mem_by_name(out uvm_status_e   status,
			string             name,
			uvm_reg_addr_t     offset,
			out uvm_reg_data_t data,
			uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
			uvm_reg_map        map = null,
			uvm_sequence_base  parent = null,
			int                prior = -1,
			uvm_object         extension = null,
			string             fname = "",
			int                lineno = 0) {
    synchronized(this) {
      this._fname = fname;
      this._lineno = lineno;
    }
    status = UVM_NOT_OK;
    uvm_mem mem = get_mem_by_name(name);
    if (mem !is null) {
      mem.read(status, offset, data, path, map, parent, prior, extension);
    }
  }


  // extern virtual task readmemh(string filename);
  // readmemh

  void readmemh(string filename) {/* TODO */}


  // extern virtual task writememh(string filename);
  // writememh

  void writememh(string filename) {/* TODO */}


  //----------------
  // Group: Backdoor
  //----------------

  // Function: get_backdoor
  //
  // Get the user-defined backdoor for all registers in this block
  //
  // Return the user-defined backdoor for all register in this
  // block and all sub-blocks -- unless overriden by a backdoor set
  // in a lower-level block or in the register itself.
  //
  // If ~inherited~ is TRUE, returns the backdoor of the parent block
  // if none have been specified for this block.
  //

  // extern function uvm_reg_backdoor get_backdoor(bool inherited = 1);
  // get_backdoor

  final uvm_reg_backdoor get_backdoor(bool inherited = true) {
    synchronized(this) {
      if (_backdoor is null && inherited) {
	uvm_reg_block blk = get_parent();
	while (blk !is null) {
	  uvm_reg_backdoor bkdr = blk.get_backdoor();
	  if (bkdr !is null)
	    return bkdr;
	  blk = blk.get_parent();
	}
      }
      return this._backdoor;
    }
  }


  // Function: set_backdoor
  //
  // Set the user-defined backdoor for all registers in this block
  //
  // Defines the backdoor mechanism for all registers instantiated
  // in this block and sub-blocks, unless overriden by a definition
  // in a lower-level block or register.
  //
  // extern function void set_backdoor (uvm_reg_backdoor bkdr,
  // 				     string fname = "",
  // 				     int lineno = 0);

  // set_backdoor

  final void set_backdoor(uvm_reg_backdoor bkdr,
			  string           fname = "",
			  int              lineno = 0) {
    synchronized(this) {
      bkdr.fname = fname;
      bkdr.lineno = lineno;
      if (this._backdoor !is null &&
	  this._backdoor.has_update_threads()) {
	uvm_report_warning("RegModel",
		    "Previous register backdoor still has update threads running. Backdoors with active mirroring should only be set before simulation starts.");
      }
      this._backdoor = bkdr;
    }
  }


  // Function:  clear_hdl_path
  //
  // Delete HDL paths
  //
  // Remove any previously specified HDL path to the block instance
  // for the specified design abstraction.
  //

  // extern function void clear_hdl_path (string kind = "RTL");
  // clear_hdl_path

  final void clear_hdl_path(string kind = "RTL") {
    synchronized(this) {
      if (kind == "ALL") {
	_hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!string)
	  ("hdl_paths");
	return;
      }

      if (kind == "") {
	kind = get_default_hdl_path();
      }

      if (!_hdl_paths_pool.exists(kind)) {
	uvm_report_warning("RegModel", "Unknown HDL Abstraction '" ~ kind ~ "'");
	return;
      }

      _hdl_paths_pool.remove(kind);
    }
  }




  // Function:  add_hdl_path
  //
  // Add an HDL path
  //
  // Add the specified HDL path to the block instance for the specified
  // design abstraction. This method may be called more than once for the
  // same design abstraction if the block is physically duplicated
  // in the design abstraction
  //

  // extern function void add_hdl_path (string path, string kind = "RTL");
  // add_hdl_path

  final void add_hdl_path(string path, string kind = "RTL") {
    synchronized(this) {
      uvm_queue!string paths = _hdl_paths_pool.get(kind);
      paths.push_back(path);
    }
  }

  // Function:   has_hdl_path
  //
  // Check if a HDL path is specified
  //
  // Returns TRUE if the block instance has a HDL path defined for the
  // specified design abstraction. If no design abstraction is specified,
  // uses the default design abstraction specified for this block or
  // the nearest block ancestor with a specified default design abstraction.
  //

  // extern function bool has_hdl_path (string kind = "");
  // has_hdl_path

  final bool  has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "") {
	kind = get_default_hdl_path();
      }
      if(kind in _hdl_paths_pool) return true;
      else return false;
    }
  }




  // Function:  get_hdl_path
  //
  // Get the incremental HDL path(s)
  //
  // Returns the HDL path(s) defined for the specified design abstraction
  // in the block instance.
  // Returns only the component of the HDL paths that corresponds to
  // the block, not a full hierarchical path
  //
  // If no design asbtraction is specified, the default design abstraction
  // for this block is used.
  //

  // extern function void get_hdl_path (ref string paths[$], input string kind = "");
  // get_hdl_path

  void get_hdl_path(ref string[] paths, string kind = "") {
    synchronized(this) {
      if (kind == "")
	kind = get_default_hdl_path();

      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Block does not have hdl path defined for abstraction '" ~
		  kind ~ "'");
	return;
      }

      uvm_queue!string hdl_paths = _hdl_paths_pool.get(kind);

      for (int i=0; i<hdl_paths.length; ++i) {
	paths ~= hdl_paths.get(i);
      }

    }
  }




  // Function:  get_full_hdl_path
  //
  // Get the full hierarchical HDL path(s)
  //
  // Returns the full hierarchical HDL path(s) defined for the specified
  // design abstraction in the block instance.
  // There may be more than one path returned even
  // if only one path was defined for the block instance, if any of the
  // parent components have more than one path defined for the same design
  // abstraction
  //
  // If no design asbtraction is specified, the default design abstraction
  // for each ancestor block is used to get each incremental path.
  //

  // extern function void get_full_hdl_path (ref string paths[$],
  // 					  input string kind = "",
  // 					  string separator = ".");
  // get_full_hdl_path

  final void get_full_hdl_path(out string[] paths,
			       string       kind = "",
			       string       separator = ".") {
    synchronized(this) {
      if (kind == "")
	kind = get_default_hdl_path();

      // paths.remove(); // paths is scoped as out
      if (is_hdl_path_root(kind)) {
	if (_root_hdl_paths[kind] != "")
	  paths ~= _root_hdl_paths[kind];
	return;
      }

      if (!has_hdl_path(kind)) {
	uvm_error("RegModel",
		  "Block does not have hdl path defined for abstraction '" ~
		  kind ~ "'");
	return;
      }
   
      uvm_queue!string hdl_paths = _hdl_paths_pool.get(kind);
      string[] parent_paths;

      if (_parent !is null) {
	_parent.get_full_hdl_path(parent_paths, kind, separator);
      }

      for (int i=0; i < hdl_paths.length; ++i) {
	string hdl_path = hdl_paths.get(i);

	if (parent_paths.length == 0) {
	  if (hdl_path != "") {
	    paths ~= hdl_path;
	  }
	  continue;
	}
         
	foreach (path; parent_paths)  {
	  if (hdl_path == "") {
	    paths ~= path;
	  }
	  else {
	    paths ~= path ~ separator ~ hdl_path;
	  }
	}
      }
    }
  }
  

  // Function: set_default_hdl_path
  //
  // Set the default design abstraction
  //
  // Set the default design abstraction for this block instance.
  //

  // extern function void   set_default_hdl_path (string kind);

  // set_default_hdl_path

  void set_default_hdl_path(string kind) {
    synchronized(this) {

      if (kind == "") {
	if (_parent is null) {
	  uvm_error("RegModel", "Block has no parent. " ~
		    "Must specify a valid HDL abstraction (kind)");
	}
	kind = _parent.get_default_hdl_path();
      }

      _default_hdl_path = kind;
    }
  }


  // Function:  get_default_hdl_path
  //
  // Get the default design abstraction
  //
  // Returns the default design abstraction for this block instance.
  // If a default design abstraction has not been explicitly set for this
  // block instance, returns the default design absraction for the
  // nearest block ancestor.
  // Returns "" if no default design abstraction has been specified.
  //
  // extern function string get_default_hdl_path ();

  // get_default_hdl_path

  string get_default_hdl_path() {
    synchronized(this) {
      if (_default_hdl_path == "" && _parent !is null) {
	return _parent.get_default_hdl_path();
      }
      return _default_hdl_path;
    }
  }


  // Function: set_hdl_path_root
  //
  // Specify a root HDL path
  //
  // Set the specified path as the absolute HDL path to the block instance
  // for the specified design abstraction.
  // This absolute root path is preppended to all hierarchical paths
  // under this block. The HDL path of any ancestor block is ignored.
  // This method overrides any incremental path for the
  // same design abstraction specified using <add_hdl_path>.
  //

  // extern function void set_hdl_path_root (string path, string kind = "RTL");

  // set_hdl_path_root

  void set_hdl_path_root (string path, string kind = "RTL") {
    synchronized(this) {
      if (kind == "")
	kind = get_default_hdl_path();

      _root_hdl_paths[kind] = path;
    }
  }


  // Function: is_hdl_path_root
  //
  // Check if this block has an absolute path
  //
  // Returns TRUE if an absolute HDL path to the block instance
  // for the specified design abstraction has been defined.
  // If no design asbtraction is specified, the default design abstraction
  // for this block is used.
  //

  // extern function bool is_hdl_path_root (string kind = "");
  // is_hdl_path_root

  final bool  is_hdl_path_root (string kind = "") {
    synchronized(this) {
      if (kind == "") {
	kind = get_default_hdl_path();
      }

      if(kind in _root_hdl_paths) return true;
      else return false;
    }
  }


  // extern virtual function void   do_print      (uvm_printer printer);
  // do_print
  override void do_print (uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);

      foreach(i, unused; _blks) {
	uvm_reg_block b = i;
	uvm_object obj = b;
	printer.print_object(obj.get_name(), obj);
      }
   
      foreach(i, unused; _regs) {
	uvm_reg r = i;
	uvm_object obj = r;
	printer.print_object(obj.get_name(), obj);
      }

      foreach(i, unused; _vregs) {
	uvm_vreg r = i;
	uvm_object obj = r;
	printer.print_object(obj.get_name(), obj);
      }

      foreach(i, unused; _mems) {
	uvm_mem m = i;
	uvm_object obj = m;
	printer.print_object(obj.get_name(), obj);
      }

      foreach(i, unused; _maps) {
	uvm_reg_map m = i;
	uvm_object obj = m;
	printer.print_object(obj.get_name(), obj);
      }
  
    }
  }



  // extern virtual function void   do_copy       (uvm_object rhs);
  // do_copy

  override void do_copy(uvm_object rhs) {
    uvm_report_fatal("RegModel","RegModel blocks cannot be copied");
  }


  // extern virtual function bool    do_compare    (uvm_object  rhs,
  // 						uvm_comparer comparer);
  // do_compare

  override bool do_compare (uvm_object  rhs,
		   uvm_comparer comparer) {
    uvm_report_warning("RegModel","RegModel blocks cannot be compared");
    return false;
  }


  // extern virtual function void   do_pack       (uvm_packer packer);
  // do_pack

  override void do_pack (uvm_packer packer) {
    uvm_report_warning("RegModel","RegModel blocks cannot be packed");
  }


  // extern virtual function void   do_unpack     (uvm_packer packer);
  // do_unpack

  override void do_unpack (uvm_packer packer) {
    uvm_report_warning("RegModel","RegModel blocks cannot be unpacked");
  }

  // extern virtual function string convert2string ();
  // convert2string

  override string convert2string() {
    synchronized(this) {

      string image;
      string[] maps;
      string[] blk_maps;
      bool         single_map;
      uvm_endianness_e endian;
      string prefix = "  ";

      version(TODO) {
	single_map = 1;
	if (map == "") {
	  this.get_maps(maps);
	  if (maps.size() > 1) single_map = 0;
	}

	if (single_map) {
	  image = format("%sBlock %s", prefix, this.get_full_name());

	  if (map != "")
	    image = format("%s.%s", image, map);

	  endian = this.get_endian(map);

	  image = format("%s -- %0d bytes (%s)", image,
			 this.get_n_bytes(map), endian.name());

	  foreach (i, blk; _blks) {
	    string img;
	    img = blk.convert2string(prefix ~ "   ", blk_maps[i]);
	    image = image ~ "\n" ~ img;
	  }

	}
	else {
	  image = format("%Block %s", prefix, this.get_full_name());
	  foreach (i, map; maps) {
	    endian = this.get_endian(map);
	    string img =
	      format("%s   Map \"%s\" -- %0d bytes (%s)",
		     prefix, map,
		     this.get_n_bytes(map), endian.name());
	    image ~= "\n" ~ img;

	    this.get_blocks(_blks, blk_maps, map);
	    foreach (j, blk; _blks) {
	      img = blk.convert2string(prefix ~ "      ",
				       blk_maps[j]);
	      image = image ~ "\n" ~ img;
	    }

	    this.get_subsys(sys, blk_maps, map);
	    foreach (j, y; sys) {
	      img = y.convert2string(prefix ~ "      ",
				     blk_maps[j]);
	      image = image ~ "\n" ~ img;
	    }
	  }
	}
      }
      return image;
    }
  }
  
  // extern virtual function uvm_object clone();
  // clone

  override uvm_object clone() {
    uvm_report_fatal("RegModel","RegModel blocks cannot be cloned");
    return null;
  }

   
  // extern private function void Xinit_address_mapsX();
  // Xinit_address_mapsX

  final void Xinit_address_mapsX() {
    synchronized(this) {
      foreach (map_, unused; _maps) {
	uvm_reg_map map = map_;
	map.Xinit_address_mapX();
      }
      //map.Xverify_map_configX();
    }
  }

}
