// -------------------------------------------------------------
//    Copyright 2004-2011 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010-2011 Cadence Design Systems, Inc.
//    Copyright 2016      Coverify Systems Technology
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

module uvm.reg.uvm_reg_map;

import uvm.base.uvm_object;
import uvm.base.uvm_printer;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;

import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequencer_base;

import uvm.meta.misc;

import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_adapter;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_cbs;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_sequence;
import uvm.reg.uvm_reg_field;
import uvm.reg.uvm_vreg;
import uvm.reg.uvm_vreg_field;
import uvm.reg.uvm_mem;
import uvm.seq.uvm_sequencer_base;

import std.string: format;
import std.conv: to;

class uvm_reg_map_info
{
  mixin(uvm_sync_string);
  @uvm_public_sync
    uvm_reg_addr_t         _offset;
  @uvm_public_sync
    string                 _rights;
  @uvm_public_sync
    bool                   _unmapped;
  @uvm_public_sync
    uvm_reg_addr_t[]       _addr;
  @uvm_public_sync
    uvm_reg_frontdoor      _frontdoor;
  @uvm_public_sync
    uvm_reg_map_addr_range _mem_range; 
   
  // if set marks the uvm_reg_map_info as initialized, prevents using an uninitialized map (for instance if the model 
  // has not been locked accidently and the maps have not been computed before)
  @uvm_public_sync
    bool                  _is_initialized;
}

//------------------------------------------------------------------------------
//
// Class: uvm_reg_map
//
// :Address map abstraction class
//
// This class represents an address map.
// An address map is a collection of registers and memories
// accessible via a specific physical interface.
// Address maps can be composed into higher-level address maps.
//
// Address maps are created using the <uvm_reg_block::create_map()>
// method.
//------------------------------------------------------------------------------

class uvm_reg_map: uvm_object
{
  mixin uvm_object_essentials;
   
  // info that is valid only if top-level map
  @uvm_private_sync
    private uvm_reg_addr_t                  _m_base_addr;
  @uvm_private_sync
    private uint                            _m_n_bytes;
  @uvm_private_sync
    private uvm_endianness_e                _m_endian;
  @uvm_private_sync
    private bool                            _m_byte_addressing;
  @uvm_private_sync
    private uvm_object_wrapper              _m_sequence_wrapper;
  @uvm_private_sync
    private uvm_reg_adapter                 _m_adapter;
  @uvm_private_sync
    private uvm_sequencer_base              _m_sequencer;
  @uvm_private_sync
    private bool                            _m_auto_predict;
  @uvm_private_sync
    private bool                            _m_check_on_read;

  @uvm_private_sync
    private uvm_reg_block                   _m_parent;

  @uvm_private_sync
    private uint                            _m_system_n_bytes;

  @uvm_private_sync
    private uvm_reg_map                     _m_parent_map;
  @uvm_private_sync
    private uvm_reg_addr_t[uvm_reg_map]     _m_parent_maps;   // value=offset of this map at parent level
  @uvm_private_sync
    private uvm_reg_addr_t[uvm_reg_map]     _m_submaps;       // value=offset of submap at this level
  @uvm_private_sync
    private string[uvm_reg_map]             _m_submap_rights; // value=rights of submap at this level

  @uvm_private_sync
    private uvm_reg_map_info[uvm_reg]       _m_regs_info;
  @uvm_private_sync
    private uvm_reg_map_info[uvm_mem]       _m_mems_info;

  @uvm_private_sync
    private uvm_reg[uvm_reg_addr_t]         _m_regs_by_offset;
  // Use only in addition to above if a RO and a WO
  // register share the same address.
  @uvm_private_sync
    private uvm_reg[uvm_reg_addr_t]         _m_regs_by_offset_wo; 
  @uvm_private_sync
    private uvm_mem[uvm_reg_map_addr_range] _m_mems_by_offset;

  // extern /*private*/ function void Xinit_address_mapX();

  // Xinit_address_mapX

  public void Xinit_address_mapX() {
    synchronized(this) {
      uint bus_width;

      uvm_reg_map top_map = get_root_map();

      if (this is top_map) {
	top_map._m_regs_by_offset = null; // .remove();
	top_map._m_regs_by_offset_wo = null; // .remove();
	top_map._m_mems_by_offset = null; // .remove();
      }

      foreach (l, submap; _m_submaps) {
	uvm_reg_map map=l;
	map.Xinit_address_mapX();
      }

      foreach (rg_, reg_info; _m_regs_info) {
	uvm_reg rg = rg_;
	reg_info.is_initialized=1;
	if (!reg_info.unmapped) {
	  string rg_acc = rg.Xget_fields_accessX(this);
	  uvm_reg_addr_t[] addrs;
        
	  bus_width = get_physical_addresses(reg_info.offset, 0,
					     rg.get_n_bytes(), addrs);
        
	  foreach (i, addr; addrs) {
	    // uvm_reg_addr_t addr = addrs[i];

	    if (addr in top_map._m_regs_by_offset) {

	      uvm_reg rg2 = top_map._m_regs_by_offset[addr];
	      string rg2_acc = rg2.Xget_fields_accessX(this);
            
	      // If the register at the same address is RO or WO
	      // and this register is WO or RO, this is OK
	      if (rg_acc == "RO" && rg2_acc == "WO") {
		top_map._m_regs_by_offset[addr]    = rg;
		uvm_reg_read_only_cbs.add(rg);
		top_map._m_regs_by_offset_wo[addr] = rg2;
		uvm_reg_write_only_cbs.add(rg2);
	      }
	      else if (rg_acc == "WO" && rg2_acc == "RO") {
		top_map._m_regs_by_offset_wo[addr] = rg;
		uvm_reg_write_only_cbs.add(rg);
		uvm_reg_read_only_cbs.add(rg2);
	      }
	      else {
		string a;
		a = format("%0h",addr);
		uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' register '" ~ 
			    rg.get_full_name() ~  "' maps to same address as register '" ~ 
			    top_map._m_regs_by_offset[addr].get_full_name() ~ "': 'h" ~ a);
	      }
	    }
	    else
	      top_map._m_regs_by_offset[addr] = rg;
          
	    foreach (range, mem_by_offset; top_map._m_mems_by_offset) {
	      if (addr >= range.min && addr <= range.max) {
		string a,b;
		a = format("%0h",addr);
		b = format("[%0h:%0h]",range.min,range.max);
		uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' register '" ~ 
			    rg.get_full_name() ~  "' with address " ~ a ~ 
			    "maps to same address as memory '" ~ 
			    top_map._m_mems_by_offset[range].get_full_name() ~ "': " ~ b);
	      }
	    }
	  }
	  reg_info.addr = addrs;
	}
      }


      foreach (mem_, mem_info; _m_mems_info) {
	uvm_mem mem = mem_;
	if (!mem_info.unmapped) {

	  uvm_reg_addr_t[] addrs, addrs_max;
	  uvm_reg_addr_t min, max, min2, max2;
	  uint stride;

	  bus_width = get_physical_addresses(mem_info.offset,0,mem.get_n_bytes(),addrs);
	  min = (addrs[0] < addrs[addrs.length-1]) ? addrs[0] : addrs[addrs.length-1];
	  min2 = addrs[0];

	  get_physical_addresses(mem_info.offset,(mem.get_size()-1),mem.get_n_bytes(),addrs_max);
	  max = (addrs_max[0] > addrs_max[addrs_max.length-1]) ? addrs_max[0] : addrs_max[addrs_max.length-1];
	  max2 = addrs_max[0];
	  // address interval between consecutive mem offsets
	  stride = cast(uint) ((max2 - min2)/(mem.get_size()-1));

	  foreach (reg_addr, reg_by_offset; top_map._m_regs_by_offset) {
	    if (reg_addr >= min && reg_addr <= max) {
	      string a;
	      a = format("%0h",reg_addr);
	      uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~ 
			  mem.get_full_name() ~  "' maps to same address as register '" ~ 
			  reg_by_offset.get_full_name() ~ "': 'h" ~ a);
	    }
	  }

	  foreach (range, mem_by_offset; top_map._m_mems_by_offset) {
	    if (min <= range.max && max >= range.max ||
		min <= range.min && max >= range.min ||
		min >= range.min && max <= range.max) {
	      string a;
	      a = format("[%0h:%0h]",min,max);
	      uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~ 
			  mem.get_full_name() ~  "' overlaps with address range of memory '" ~ 
			  top_map._m_mems_by_offset[range].get_full_name() ~ "': 'h" ~ a);
	    }
	  }

	  {
	    uvm_reg_map_addr_range range =
	      uvm_reg_map_addr_range(min, max, stride);
	    top_map._m_mems_by_offset[range] = mem;
	    mem_info.addr  = addrs;
	    mem_info.mem_range = range;
	  }
	}
      }

      // If the block has no registers or memories,
      // bus_width won't be set
      if (bus_width == 0) bus_width = _m_n_bytes;

      _m_system_n_bytes = bus_width;
    }
  }


  

  static private uvm_reg_map   _m_backdoor;

  // Function: backdoor
  // Return the backdoor pseudo-map singleton
  //
  // This pseudo-map is used to specify or configure the backdoor
  // instead of a real address map.
  //
  public static uvm_reg_map backdoor() {
    if (_m_backdoor is null)
      _m_backdoor = new uvm_reg_map("Backdoor");
    return _m_backdoor;
  }


  //----------------------
  // Group: Initialization
  //----------------------


  //---------------
  // Initialization
  //---------------

  // Function: new
  //
  // Create a new instance
  //
  // extern function new(string name="uvm_reg_map");

  // new

  this(string name = "uvm_reg_map") {
    synchronized(this) {
      super((name == "") ? "default_map" : name);
      _m_auto_predict = 0;
      _m_check_on_read = 0;
    }
  }


  // Function: configure
  //
  // Instance-specific configuration
  //
  // Configures this map with the following properties.
  //
  // parent    - the block in which this map is created and applied
  //
  // base_addr - the base address for this map. All registers, memories,
  //             and sub-blocks will be at offsets to this address
  //
  // n_bytes   - the byte-width of the bus on which this map is used 
  //
  // endian    - the endian format. See <uvm_endianness_e> for possible
  //             values
  //
  // byte_addressing - specifies whether the address increment is on a
  //             per-byte basis. For example, consecutive memory locations
  //             with ~n_bytes~=4 (32-bit bus) are 4 apart: 0, 4, 8, and
  //             so on. Default is TRUE.
  //
  // extern function void configure(uvm_reg_block     parent,
  // 				 uvm_reg_addr_t    base_addr,
  // 				 uint      n_bytes,
  // 				 uvm_endianness_e  endian,
  // 				 bool byte_addressing = 1);

  // configure

  public void configure(uvm_reg_block    parent,
			uvm_reg_addr_t   base_addr,
			uint             n_bytes,
			uvm_endianness_e endian,
			bool             byte_addressing=true) {
    synchronized(this) {
      _m_parent     = parent;
      _m_n_bytes    = n_bytes;
      _m_endian     = endian;
      _m_base_addr  = base_addr;
      _m_byte_addressing = byte_addressing;
    }
  }

  // Function: add_reg
  //
  // Add a register
  //
  // Add the specified register instance ~rg~ to this address map.
  //
  // The register is located at the specified address ~offset~ from
  // this maps configured base address.
  //
  // The ~rights~ specify the register's accessibility via this map.
  // Valid values are "RW", "RO", and "WO". Whether a register field
  // can be read or written depends on both the field's configured access
  // policy (see <uvm_reg_field::configure> and the register's rights in
  // the map being used to access the field. 
  //
  // The number of consecutive physical addresses occupied by the register
  // depends on the width of the register and the number of bytes in the
  // physical interface corresponding to this address map.
  //
  // If ~unmapped~ is TRUE, the register does not occupy any
  // physical addresses and the base address is ignored.
  // Unmapped registers require a user-defined ~frontdoor~ to be specified.
  //
  // A register may be added to multiple address maps
  // if it is accessible from multiple physical interfaces.
  // A register may only be added to an address map whose parent block
  // is the same as the register's parent block.
  //
  // extern virtual function void add_reg (uvm_reg           rg,
  // 					uvm_reg_addr_t    offset,
  // 					string            rights = "RW",
  // 					bool              unmapped=0,
  // 					uvm_reg_frontdoor frontdoor=null);

  // add_reg

  public void add_reg(T)(uvm_reg rg, 
			 T offset,
			 string rights = "RW",
			 bool unmapped=false,
			 uvm_reg_frontdoor frontdoor=null) {
    synchronized(this) {

      if (rg in _m_regs_info) {
	uvm_error("RegModel", "Register '" ~ rg.get_name() ~ 
		  "' has already been added to map '" ~ get_name() ~ "'");
	return;
      }

      if (rg.get_parent() !is get_parent()) {
	uvm_error("RegModel",
		  "Register '" ~ rg.get_full_name() ~ "' may not be added to address map '" ~ 
		  get_full_name() ~ "' : they are not in the same block");
	return;
      }
   
      rg.add_map(this);

      {
	uvm_reg_map_info info = new uvm_reg_map_info();
	synchronized(info) {
	  info._offset   = offset;
	  info._rights   = rights;
	  info._unmapped = unmapped;
	  info._frontdoor = frontdoor;
	}
	_m_regs_info[rg] = info;
      }
    }
  }



  // Function: add_mem
  //
  // Add a memory
  //
  // Add the specified memory instance to this address map.
  // The memory is located at the specified base address and has the
  // specified access rights ("RW", "RO" or "WO").
  // The number of consecutive physical addresses occupied by the memory
  // depends on the width and size of the memory and the number of bytes in the
  // physical interface corresponding to this address map.
  //
  // If ~unmapped~ is TRUE, the memory does not occupy any
  // physical addresses and the base address is ignored.
  // Unmapped memorys require a user-defined ~frontdoor~ to be specified.
  //
  // A memory may be added to multiple address maps
  // if it is accessible from multiple physical interfaces.
  // A memory may only be added to an address map whose parent block
  // is the same as the memory's parent block.
  //
  // extern virtual function void add_mem (uvm_mem        mem,
  // 					uvm_reg_addr_t offset,
  // 					string         rights = "RW",
  // 					bool           unmapped=0,
  // 					uvm_reg_frontdoor frontdoor=null);

  // add_mem

  public void add_mem(uvm_mem mem,
		      uvm_reg_addr_t offset,
		      string rights = "RW",
		      bool unmapped=false,
		      uvm_reg_frontdoor frontdoor=null) {
    synchronized(this) {
      if (mem in _m_mems_info) {
	uvm_error("RegModel",  "Memory '" ~ mem.get_name() ~ 
		  "' has already been added to map '" ~ get_name() ~ "'");
	return;
      }

      if (mem.get_parent() !is get_parent()) {
	uvm_error("RegModel",
		  "Memory '" ~ mem.get_full_name() ~ "' may not be added to address map '" ~ 
		  get_full_name() ~ "' : they are not in the same block");
	return;
      }
   
      mem.add_map(this);

      {
	uvm_reg_map_info info = new uvm_reg_map_info();
	synchronized(info) {
	  info.offset   = offset;
	  info.rights   = rights;
	  info.unmapped = unmapped;
	  info.frontdoor = frontdoor;
	}
	_m_mems_info[mem] = info;
      }
    }
  }
   
  // Function: add_submap
  //
  // Add an address map
  //
  // Add the specified address map instance to this address map.
  // The address map is located at the specified base address.
  // The number of consecutive physical addresses occupied by the submap
  // depends on the number of bytes in the physical interface
  // that corresponds to the submap,
  // the number of addresses used in the submap and
  // the number of bytes in the
  // physical interface corresponding to this address map.
  //
  // An address map may be added to multiple address maps
  // if it is accessible from multiple physical interfaces.
  // An address map may only be added to an address map
  // in the grand-parent block of the address submap.
  //
  // extern virtual function void add_submap (uvm_reg_map    child_map,
  // 					   uvm_reg_addr_t offset);

  // add_submap

  public void add_submap (uvm_reg_map child_map,
			  uvm_reg_addr_t offset) {
    synchronized(this) {
      uvm_reg_map parent_map;

      if (child_map is null) {
	uvm_error("RegModel", "Attempting to add NULL map to map '" ~ get_full_name() ~ "'");
	return;
      }

      parent_map = child_map.get_parent_map();

      // Can not have more than one parent (currently)
      if (parent_map !is null) {
	uvm_error("RegModel", "Map '" ~  child_map.get_full_name() ~ 
		  "' is already a child of map '" ~ 
		  parent_map.get_full_name() ~ 
		  "'. Cannot also be a child of map '" ~ 
		  get_full_name() ~ 
		  "'");
	return;
      }

      { // parent_block_check
	uvm_reg_block child_blk = child_map.get_parent();
	if (child_blk is null) {
	  uvm_error("RegModel", "Cannot add submap '" ~ child_map.get_full_name() ~ 
		    "' because it does not have a parent block");
	  return;
	}
	if (get_parent() !is child_blk.get_parent()) {
	  uvm_error("RegModel",
		    "Submap '" ~ child_map.get_full_name() ~ "' may not be added to this " ~ 
		    "address map ~  '" ~  get_full_name() ~ "' ~  as the submap's parent block ~  '" ~ 
		    child_blk.get_full_name() ~ "' ~  is not a child of this map's parent block ~  '" ~ 
		    _m_parent.get_full_name() ~ "'");
	  return;
	}
      }
   
      { // n_bytes_match_check
	if (_m_n_bytes > child_map.get_n_bytes(UVM_NO_HIER)) {
	  uvm_warning("RegModel",
		      format("Adding %0d-byte submap '%s' to %0d-byte parent map '%s'",
			     child_map.get_n_bytes(UVM_NO_HIER), child_map.get_full_name(),
			     _m_n_bytes, get_full_name()));
	}
      }

      child_map.add_parent_map(this,offset);

      set_submap_offset(child_map, offset);
    }
  }

  // Function: set_sequencer
  //
  // Set the sequencer and adapter associated with this map. This method
  // ~must~ be called before starting any sequences based on uvm_reg_sequence.

  // extern virtual function void set_sequencer (uvm_sequencer_base sequencer,
  //                                             uvm_reg_adapter    adapter=null);

  // set_sequencer

  public void set_sequencer(uvm_sequencer_base sequencer,
			    uvm_reg_adapter adapter=null) {
    synchronized(this) {
      if (sequencer is null) {
	uvm_error("REG_NULL_SQR", "Null reference specified for bus sequencer");
	return;
      }

      if (adapter is null) {
	uvm_info("REG_NO_ADAPT", "Adapter not specified for map '" ~
		 get_full_name() ~
		 "'. Accesses via this map will send abstract " ~
		 "'uvm_reg_item' items to sequencer '" ~
		 sequencer.get_full_name() ~ "'", uvm_verbosity.UVM_MEDIUM);
      }

      _m_sequencer = sequencer;
      _m_adapter = adapter;
    }
  }


  // Function: set_submap_offset
  //
  // Set the offset of the given ~submap~ to ~offset~.

  // extern virtual function void set_submap_offset (uvm_reg_map submap,
  //                                                 uvm_reg_addr_t offset);

  // set_submap_offset

  public void set_submap_offset(uvm_reg_map submap, uvm_reg_addr_t offset) {
    synchronized(this) {
      if (submap is null) {
	uvm_error("REG/NULL","set_submap_offset: submap handle is null");
	return;
      }
      _m_submaps[submap] = offset;
      if (_m_parent.is_locked()) {
	uvm_reg_map root_map = get_root_map();
	root_map.Xinit_address_mapX();
      }
    }
  }


  // Function: get_submap_offset
  //
  // Return the offset of the given ~submap~.

  // extern virtual function uvm_reg_addr_t get_submap_offset (uvm_reg_map submap);

  // get_submap_offset

  public uvm_reg_addr_t get_submap_offset(uvm_reg_map submap) {
    synchronized(this) {
      if (submap is null) {
	uvm_error("REG/NULL","set_submap_offset: submap handle is null");
	return uvm_reg_addr_t(-1);
      }
      if (submap !in _m_submaps) {
	uvm_error("RegModel","Map '" ~ submap.get_full_name() ~ 
		  "' is not a submap of '" ~ get_full_name() ~ "'");
	return uvm_reg_addr_t(-1);
      }
      return _m_submaps[submap];
    }
  }


  // Function: set_base_addr
  //
  // Set the base address of this map.

  //extern virtual function void   set_base_addr (uvm_reg_addr_t  offset);

  // set_base_addr

  public void set_base_addr(uvm_reg_addr_t offset) {
    synchronized(this) {
      if (_m_parent_map !is null) {
	_m_parent_map.set_submap_offset(this, offset);
      }
      else {
	_m_base_addr = offset;
	if (_m_parent.is_locked()) {
	  uvm_reg_map top_map = get_root_map();
	  top_map.Xinit_address_mapX();
	}
      }
    }
  }


  // Function: reset
  //
  // Reset the mirror for all registers in this address map.
  //
  // Sets the mirror value of all registers in this address map
  // and all of its submaps
  // to the reset value corresponding to the specified reset event.
  // See <uvm_reg_field::reset()> for more details.
  // Does not actually set the value of the registers in the design,
  // only the values mirrored in their corresponding mirror.
  //
  // Note that, unlike the other reset() method, the default
  // reset event for this method is "SOFT".
  //
  // extern virtual function void reset(string kind = "SOFT");

  // reset

  public void reset(string kind = "SOFT") {
    synchronized(this) {
      uvm_reg[] regs;

      get_registers(regs);

      foreach (i, reg; regs) {
	reg.reset(kind);
      }
    }
  }


  // /*private*/ extern virtual function void add_parent_map(uvm_reg_map  parent_map,
  //                                                       uvm_reg_addr_t offset);

  // add_parent_map

  public void add_parent_map(uvm_reg_map parent_map, uvm_reg_addr_t offset) {
    synchronized(this) {

      if (parent_map is null) {
	uvm_error("RegModel",
		  "Attempting to add NULL parent map to map '" ~
		  get_full_name() ~ "'");
	return;
      }

      if (_m_parent_map !is null) {
	uvm_error("RegModel",
		  format("Map \"%s\" already a submap of map \"%s\" at offset 'h%h",
			 get_full_name(), _m_parent_map.get_full_name(),
			 _m_parent_map.get_submap_offset(this)));
	return;
      }

      _m_parent_map = parent_map;
      _m_parent_maps[parent_map] = offset; // prep for multiple parents
      parent_map._m_submaps[this] = offset;

    }
  }

  // /*private*/ extern virtual public void Xverify_map_configX();
  public void Xverify_map_configX() {
    synchronized(this) {
      // Make sure there is a generic payload sequence for each map
      // in the model and vice-versa if this is a root sequencer
      bool error;
      uvm_reg_map root_map = get_root_map();

      if (root_map.get_adapter() is null) {
	uvm_error("RegModel", "Map '" ~ root_map.get_full_name() ~ 
		  "' does not have an adapter registered");
	// error++;
	error = true;
      }
      if (root_map.get_sequencer() is null) {
	uvm_error("RegModel", "Map '" ~ root_map.get_full_name() ~ 
		  "' does not have a sequencer registered");
	// error++;
	error = true;
      }
      if (error) {
	uvm_fatal("RegModel", "Must register an adapter and sequencer " ~
		  "for each top-level map in RegModel model");
	return;
      }

    }
  }
  

  // /*private*/ extern virtual public void m_set_reg_offset(uvm_reg   rg,
  // 							uvm_reg_addr_t offset,
  // 							bool unmapped);

  // m_set_reg_offset
  public void m_set_reg_offset(uvm_reg rg, 
			       uvm_reg_addr_t offset,
			       bool unmapped) {
    synchronized(this) {
      if (rg !in _m_regs_info) {
	uvm_error("RegModel",
		  "Cannot modify offset of register '" ~ rg.get_full_name() ~ 
		  "' in address map '" ~ get_full_name() ~ 
		  "' : register not mapped in that address map");
	return;
      }

      uvm_reg_map_info info    = _m_regs_info[rg];
      uvm_reg_block    blk     = get_parent();
      uvm_reg_map      top_map = get_root_map();
      uvm_reg_addr_t[] addrs;

      // if block is not locked, Xinit_address_mapX will resolve map when block is locked
      if (blk.is_locked()) {

	// remove any existing cached addresses
	if (!info.unmapped) {
	  foreach (i, iaddr; info.addr) {

	    if (iaddr !in top_map._m_regs_by_offset_wo) {
	      top_map._m_regs_by_offset.remove(iaddr);
	    }
	    else {
	      if (top_map._m_regs_by_offset[iaddr] == rg) {
		top_map._m_regs_by_offset[iaddr] = 
		  top_map._m_regs_by_offset_wo[iaddr];
		uvm_reg_read_only_cbs.remove(rg);
		uvm_reg_write_only_cbs.remove(top_map._m_regs_by_offset[iaddr]);
	      }
	      else {
		uvm_reg_write_only_cbs.remove(rg);
		uvm_reg_read_only_cbs.remove(top_map._m_regs_by_offset[iaddr]);
	      }
	      top_map._m_regs_by_offset_wo.remove(iaddr);
	    }
	  }
	}

	// if we are remapping...
	if (!unmapped) {
	  string rg_acc = rg.Xget_fields_accessX(this);
            
	  // get new addresses
	  get_physical_addresses(offset,0,rg.get_n_bytes(),addrs);

	  // make sure they do not conflict with others
	  foreach (i, addr; addrs) {
	    if (addr in top_map._m_regs_by_offset) {

	      uvm_reg rg2 = top_map._m_regs_by_offset[addr];
	      string rg2_acc = rg2.Xget_fields_accessX(this);

	      // If the register at the same address is RO or WO
	      // and this register is WO or RO, this is OK
	      if (rg_acc == "RO" && rg2_acc == "WO") {
		top_map._m_regs_by_offset[addr]    = rg;
		uvm_reg_read_only_cbs.add(rg);
		top_map._m_regs_by_offset_wo[addr] = rg2;
		uvm_reg_write_only_cbs.add(rg2);
	      }
	      else if (rg_acc == "WO" && rg2_acc == "RO") {
		top_map._m_regs_by_offset_wo[addr] = rg;
		uvm_reg_write_only_cbs.add(rg);
		uvm_reg_read_only_cbs.add(rg2);
	      }
	      else {
		string a;
		a = format("%0h",addr);
		uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' register '" ~ 
			    rg.get_full_name() ~  "' maps to same address as register '" ~ 
			    top_map._m_regs_by_offset[addr].get_full_name() ~ "': 'h" ~ a);
	      }
	    }
	    else
	      top_map._m_regs_by_offset[addr] = rg;

	    foreach (range, memoff; top_map._m_mems_by_offset) {
	      if (addr >= range.min && addr <= range.max) {
		string a;
		a = format("%0h",addr);
		uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' register '" ~ 
			    rg.get_full_name() ~  "' overlaps with address range of memory '" ~ 
			    top_map._m_mems_by_offset[range].get_full_name() ~ "': 'h" ~ a);
	      }
	    }
	  }
	  info.addr = addrs; // cache it
	}
      }

      if (unmapped) {
	info.offset   = uvm_reg_addr_t(-1);
	info.unmapped = 1;
      }
      else {
	info.offset   = offset;
	info.unmapped = 0;
      }
      
    }
  }

  // /*private*/ extern virtual public void m_set_mem_offset(uvm_mem mem,
  // 							  uvm_reg_addr_t offset,
  // 							  bool unmapped);

  // m_set_mem_offset

  void m_set_mem_offset(uvm_mem mem, 
			uvm_reg_addr_t offset,
			bool unmapped) {

    if (mem !in _m_mems_info) {
      uvm_error("RegModel",
		"Cannot modify offset of memory '" ~ mem.get_full_name() ~ 
		"' in address map '" ~ get_full_name() ~ 
		"' : memory not mapped in that address map");
      return;
    }

    uvm_reg_map_info info    = _m_mems_info[mem];
    uvm_reg_block    blk     = get_parent();
    uvm_reg_map      top_map = get_root_map();
    // uvm_reg_addr_t   addrs[];

    // if block is not locked, Xinit_address_mapX will resolve map when block is locked
    if (blk.is_locked()) {

      // remove any existing cached addresses
      if (!info.unmapped) {
	foreach (range, memoff; top_map._m_mems_by_offset) {
	  if (memoff == mem)
	    top_map._m_mems_by_offset.remove(range);
	}
      }

      // if we are remapping...
      if (!unmapped) {
	uvm_reg_addr_t[] addrs, addrs_max;
	uvm_reg_addr_t min, max, min2, max2;
	uint stride;

	get_physical_addresses(offset,0,mem.get_n_bytes(),addrs);
	min = (addrs[0] < addrs[addrs.length-1]) ? addrs[0] : addrs[addrs.length-1];
	min2 = addrs[0];

	get_physical_addresses(offset,(mem.get_size()-1),
			       mem.get_n_bytes(),addrs_max);
	max = (addrs_max[0] > addrs_max[addrs_max.length-1]) ?
	  addrs_max[0] : addrs_max[addrs_max.length-1];
	max2 = addrs_max[0];
	// address interval between consecutive mem locations
	stride = cast(uint) ((max2 - max)/(mem.get_size()-1));

	// make sure new offset does not conflict with others
	foreach (reg_addr, regoff; top_map._m_regs_by_offset) {
	  if (reg_addr >= min && reg_addr <= max) {
	    string a,b;
	    a = format("[%0h:%0h]",min,max);
	    b = format("%0h",reg_addr);
	    uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~ 
			mem.get_full_name() ~  "' with range " ~ a ~ 
			" overlaps with address of existing register '" ~ 
			regoff.get_full_name() ~ "': 'h" ~ b);
	  }
	}

	foreach (range, memoff; top_map._m_mems_by_offset) {
	  if (min <= range.max && max >= range.max ||
	      min <= range.min && max >= range.min ||
	      min >= range.min && max <= range.max) {
	    string a,b;
	    a = format("[%0h:%0h]",min,max);
	    b = format("[%0h:%0h]",range.min,range.max);
	    uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~ 
			mem.get_full_name() ~  "' with range " ~ a ~ 
			" overlaps existing memory with range '" ~ 
			top_map._m_mems_by_offset[range].get_full_name() ~ "': " ~ b);
	  }
	}

	{
	  uvm_reg_map_addr_range range = uvm_reg_map_addr_range(min, max, stride);
	  top_map._m_mems_by_offset[range] = mem;
	  info.addr  = addrs;
	  info.mem_range = range;
	}

      }
    }

    if (unmapped) {
      info.offset   = uvm_reg_addr_t(-1);
      info.unmapped = 1;
    }
    else {
      info.offset   = offset;
      info.unmapped = 0;
    }
  }

  //---------------------
  // Group: Introspection
  //---------------------

  // Public: get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this address map.
  //

  // Public: get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this address map.
  // The base of the hierarchical name is the root block.
  //
  // extern virtual public string get_full_name();

  // get_full_name

  override string get_full_name() {
    synchronized(this) {
      auto full_name = get_name();
      if (_m_parent is null) {
	return full_name;
      }
      return _m_parent.get_full_name() ~ "." ~ full_name;
    }
  }

  

  // Public: get_root_map
  //
  // Get the externally-visible address map
  //
  // Get the top-most address map where this address map is instantiated.
  // It corresponds to the externally-visible address map that can
  // be accessed by the verification environment.
  //
  // extern virtual public uvm_reg_map get_root_map();

  // get_root_map

  public uvm_reg_map get_root_map() {
    synchronized(this) {
      return (_m_parent_map is null) ? this : _m_parent_map.get_root_map();
    }
  }


  // Public: get_parent
  //
  // Get the parent block
  //
  // Return the block that is the parent of this address map.
  //
  //extern virtual public uvm_reg_block get_parent();
  //------------
  // get methods
  //------------

  // get_parent

  public uvm_reg_block get_parent() {
    synchronized(this) {
      return _m_parent;
    }
  }



  // Public: get_parent_map
  // Get the higher-level address map
  //
  // Return the address map in which this address map is mapped.
  // returns ~null~ if this is a top-level address map.
  //
  // extern virtual public uvm_reg_map           get_parent_map();
  // get_parent_map

  public uvm_reg_map get_parent_map() {
    synchronized(this) {
      return _m_parent_map;
    }
  }





  // Public: get_base_addr
  //
  // Get the base offset address for this map. If this map is the
  // root map, the base address is that set with the ~base_addr~ argument
  // to <uvm_reg_block::create_map()>. If this map is a submap of a higher-level map,
  // the base address is offset given this submap by the parent map.
  // See <set_submap_offset>.
  //
  // extern virtual public uvm_reg_addr_t get_base_addr (uvm_hier_e hier=UVM_HIER);
  // get_base_addr

  public uvm_reg_addr_t  get_base_addr(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      // the next line seems redundant
      // uvm_reg_map child = this;
      if (hier == UVM_NO_HIER || _m_parent_map is null) {
	return _m_base_addr;
      }
      auto base_addr = _m_parent_map.get_submap_offset(this);
      base_addr += _m_parent_map.get_base_addr(UVM_HIER);
      return base_addr;
    }
  }


  // Public: get_n_bytes
  //
  // Get the width in bytes of the bus associated with this map. If ~hier~
  // is ~UVM_HIER~, then gets the effective bus width relative to the system
  // level. The effective bus width is the narrowest bus width from this
  // map to the top-level root map. Each bus access will be limited to this
  // bus width.
  //
  // extern virtual public uint get_n_bytes (uvm_hier_e hier=UVM_HIER);

  // get_n_bytes

  public uint get_n_bytes(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      if (hier == UVM_NO_HIER) {
	return _m_n_bytes;
      }
      return _m_system_n_bytes;
    }
  }



  // Public: get_addr_unit_bytes
  //
  // Get the number of bytes in the smallest addressable unit in the map.
  // Returns 1 if the address map was configured using byte-level addressing.
  // Returns <get_n_bytes()> otherwise.
  //
  // extern virtual public uint get_addr_unit_bytes();

  // get_addr_unit_bytes

  public uint get_addr_unit_bytes() {
    synchronized(this) {
      return (_m_byte_addressing) ? 1 : _m_n_bytes;
    }
  }



  // Public: get_base_addr
  //
  // Gets the endianness of the bus associated with this map. If ~hier~ is
  // set to ~UVM_HIER~, gets the system-level endianness.
  //
  // extern virtual public uvm_endianness_e get_endian (uvm_hier_e hier=UVM_HIER);

  // get_endian

  public uvm_endianness_e get_endian(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      if (hier == UVM_NO_HIER || _m_parent_map is null) {
	return _m_endian;
      }
      return _m_parent_map.get_endian(hier);
    }
  }



  // Public: get_sequencer
  //
  // Gets the sequencer for the bus associated with this map. If ~hier~ is
  // set to ~UVM_HIER~, gets the sequencer for the bus at the system-level.
  // See <set_sequencer>.
  //
  // extern virtual public uvm_sequencer_base get_sequencer (uvm_hier_e hier=UVM_HIER);
  // get_sequencer

  public uvm_sequencer_base get_sequencer(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      if (hier == UVM_NO_HIER || _m_parent_map is null) {
	return _m_sequencer;
      }
      return _m_parent_map.get_sequencer(hier);
    }
  }




  // Public: get_adapter
  //
  // Gets the bus adapter for the bus associated with this map. If ~hier~ is
  // set to ~UVM_HIER~, gets the adapter for the bus used at the system-level.
  // See <set_sequencer>.
  //
  // extern virtual public uvm_reg_adapter get_adapter (uvm_hier_e hier=UVM_HIER);

  // get_adapter

  public uvm_reg_adapter get_adapter(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      if (hier == UVM_NO_HIER || _m_parent_map is null) {
	return _m_adapter;
      }
      return _m_parent_map.get_adapter(hier);
    }
  }


  // Public: get_submaps
  //
  // Get the address sub-maps
  //
  // Get the address maps instantiated in this address map.
  // If ~hier~ is ~UVM_HIER~, recursively includes the address maps,
  // in the sub-maps.
  //
  // extern virtual public void  get_submaps (ref uvm_reg_map maps[$],
  // 					 input uvm_hier_e hier=UVM_HIER);
  // get_submaps

  public void get_submaps(ref uvm_reg_map[] maps,
			  uvm_hier_e        hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (submap, unused; _m_submaps) {
	maps ~= submap;
      }
      if (hier == UVM_HIER) {
	foreach (submap, unused; _m_submaps) {
	  submap.get_submaps(maps);
	}
      }
    }
  }


  // Public: get_registers
  //
  // Get the registers
  //
  // Get the registers instantiated in this address map.
  // If ~hier~ is ~UVM_HIER~, recursively includes the registers
  // in the sub-maps.
  //
  // extern virtual public void  get_registers (ref uvm_reg regs[$],
  // 					     input uvm_hier_e hier=UVM_HIER);
  // get_registers

  public void get_registers(ref uvm_reg[] regs,
			    uvm_hier_e    hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (rg, unused; _m_regs_info) {
	regs ~= rg;
      }
      if (hier == UVM_HIER) {
	foreach (submap, unused; _m_submaps) {
	  submap.get_registers(regs);
	}
      }
    }
  }


  // Public: get_fields
  //
  // Get the fields
  //
  // Get the fields in the registers instantiated in this address map.
  // If ~hier~ is ~UVM_HIER~, recursively includes the fields of the registers
  // in the sub-maps.
  //
  // extern virtual public void  get_fields (ref uvm_reg_field fields[$],
  // 					  input uvm_hier_e hier=UVM_HIER);
  // get_fields

  public void get_fields(ref uvm_reg_field[] fields,
			 uvm_hier_e          hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (rg, unused; _m_regs_info) {
	rg.get_fields(fields);
      }
   
      if (hier == UVM_HIER) {
	foreach (submap, unused; _m_submaps) {
	  submap.get_fields(fields);
	}
      }
    }
  }


   
  // Public get_memories
  //
  // Get the memories
  //
  // Get the memories instantiated in this address map.
  // If ~hier~ is ~UVM_HIER~, recursively includes the memories
  // in the sub-maps.
  //
  // extern virtual public void  get_memories (ref uvm_mem mems[$],
  // 					    input uvm_hier_e hier=UVM_HIER);

  // get_memories

  public void get_memories(ref uvm_mem[] mems,
			   uvm_hier_e    hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      foreach (mem, unused; _m_mems_info) {
	mems ~= mem;
      }
    
      if (hier == UVM_HIER) {
	foreach (submap, unused; _m_submaps) {
	  submap.get_memories(mems);
	}
      }
    }
  }


  // Public: get_virtual_registers
  //
  // Get the virtual registers
  //
  // Get the virtual registers instantiated in this address map.
  // If ~hier~ is ~UVM_HIER~, recursively includes the virtual registers
  // in the sub-maps.
  //
  // extern virtual public void  get_virtual_registers (ref uvm_vreg regs[$],
  // 						   input uvm_hier_e hier=UVM_HIER);
  // get_virtual_registers

  public void get_virtual_registers(ref uvm_vreg[] regs,
				    uvm_hier_e     hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      uvm_mem[] mems;
      get_memories(mems,hier);

      foreach (mem; mems) {
	mem.get_virtual_registers(regs);
      }
    }
  }


  // Public: get_virtual_fields
  //
  // Get the virtual fields
  //
  // Get the virtual fields from the virtual registers instantiated
  // in this address map.
  // If ~hier~ is ~UVM_HIER~, recursively includes the virtual fields
  // in the virtual registers in the sub-maps.
  //
  // extern virtual public void  get_virtual_fields (ref uvm_vreg_field fields[$],
  // 						input uvm_hier_e hier=UVM_HIER);
  // get_virtual_fields

  public void get_virtual_fields(ref uvm_vreg_field[] fields,
				 uvm_hier_e           hier = uvm_hier_e.UVM_HIER) {
    synchronized(this) {
      uvm_vreg[] regs;
      get_virtual_registers(regs, hier);

      foreach (reg; regs) {
	reg.get_fields(fields);
      }
    }
  }




  // extern virtual public uvm_reg_map_info get_reg_map_info(uvm_reg rg,  bool error=1);
  // get_reg_map_info

  public uvm_reg_map_info get_reg_map_info(uvm_reg rg, bool error=true) {
    synchronized(this) {
      uvm_reg_map_info result;
      if (rg !in _m_regs_info) {
	if (error) {
	  uvm_error("REG_NO_MAP", "Register '" ~ rg.get_name() ~
		    "' not in map '" ~ get_name() ~ "'");
	}
	return null;
      }
      result = _m_regs_info[rg];
      if(! result.is_initialized) {
	uvm_warning("RegModel", "map '" ~ get_name() ~
		    "' does not seem to be initialized " ~
		    "correctly, check that the top register " ~
		    "model is locked()");
      }
      return result;
    }
  }

  // extern virtual public uvm_reg_map_info get_mem_map_info(uvm_mem mem, bool error=1);

  // get_mem_map_info

  public uvm_reg_map_info get_mem_map_info(uvm_mem mem, bool error=true) {
    synchronized(this) {
      if (mem !in _m_mems_info) {
	if (error) {
	  uvm_error("REG_NO_MAP", "Memory '" ~ mem.get_name() ~
		    "' not in map '" ~ get_name() ~ "'");
	}
	return null;
      }
      return _m_mems_info[mem];
    }
  }


  // extern virtual public uint get_size();
  //----------
  // Size and Overlap Detection
  //---------

  // get_size

  public uint get_size() {
    synchronized(this) {

      uint max_addr;
      uint addr;

      // get max offset from registers
      foreach (rg, reg_info; _m_regs_info) {
	addr = cast(uint) (reg_info.offset + ((rg.get_n_bytes()-1)/_m_n_bytes));
	if (addr > max_addr) {	/* SV code has a bug here */
	  max_addr = addr;
	}
      }

      // get max offset from memories
      foreach (mem, mem_info; _m_mems_info) {
	addr = cast(uint) (mem_info.offset +
			   (mem.get_size() *
			    (((mem.get_n_bytes()-1)/_m_n_bytes)+1)) -1);
	if (addr > max_addr)  {
	  max_addr = addr;
	}
      }

      // get max offset from submaps
      foreach (submap, reg_addr; _m_submaps) {
	addr = cast(uint) (reg_addr + submap.get_size());
	if (addr > max_addr)
	  max_addr = addr;
      }

      return max_addr + 1;
    }
  }




  // Public: get_physical_addresses
  //
  // Translate a local address into external addresses
  //
  // Identify the sequence of addresses that must be accessed physically
  // to access the specified number of bytes at the specified address
  // within this address map.
  // Returns the number of bytes of valid data in each access.
  //
  // Returns in ~addr~ a list of address in little endian order,
  // with the granularity of the top-level address map.
  //
  // A register is specified using a base address with ~mem_offset~ as 0.
  // A location within a memory is specified using the base address
  // of the memory and the index of the location within that memory.
  //

  // extern virtual public int get_physical_addresses(uvm_reg_addr_t        base_addr,
  // 						   uvm_reg_addr_t        mem_offset,
  // 						   uint          n_bytes,
  // 						   ref uvm_reg_addr_t    addr[]);
   
  // get_physical_addresses

  public int get_physical_addresses(RA, RB)(RA                   base_addr,
					    RB                   mem_offset,
					    uint                 n_bytes,
					    ref uvm_reg_addr_t[] addr)
    if(uvm_reg_addr_t.isAssignableBitVec!RA &&
       uvm_reg_addr_t.isAssignableBitVec!RB) {
      synchronized(this) {

	if (n_bytes <= 0) {
	  uvm_fatal("RegModel",
		    format("Cannot access %0d bytes. Must be greater than 0",
			   n_bytes));
	  return 0;
	}

	// First, identify the addresses within the block/system
	uint bus_width = get_n_bytes(UVM_NO_HIER);
	uvm_reg_addr_t[]  local_addr;
	uint multiplier = _m_byte_addressing ? bus_width : 1;
	if (n_bytes <= bus_width) {
	  local_addr ~= cast(uvm_reg_addr_t)
	    (base_addr + (mem_offset * multiplier));
	} else {
	  auto n = ((n_bytes-1) / bus_width) + 1;
	  base_addr = cast(uvm_reg_addr_t)
	    (base_addr + mem_offset * (n * multiplier));
	  switch (get_endian(UVM_NO_HIER)) {
	  case UVM_LITTLE_ENDIAN:
	    for (uint i=0; i != n; ++i) {
	      local_addr ~= cast(uvm_reg_addr_t)
		(base_addr + (i * multiplier));
	    }
	    break;
	  case UVM_BIG_ENDIAN:
	    for (uint i=0; i != n; ++i) {
	      local_addr ~= cast(uvm_reg_addr_t)
		(base_addr + ((n - i - 1) * multiplier));
	    }
	    break;
	  case UVM_LITTLE_FIFO:
	    for (uint i=0; i != n; ++i) {
	      local_addr ~= base_addr;
	    }
	    break;
	  case UVM_BIG_FIFO:
	    for (uint i=0; i != n; ++i) {
	      local_addr ~= base_addr;
	    }
	    break;
	  default:
	    uvm_error("RegModel",
		      "Map has no specified endianness. " ~
		      format("Cannot access %0d bytes register " ~
			     "via its %0d byte \"%s\" interface",
			     n_bytes, bus_width, get_full_name()));
	    break;
	  }
	}

	uvm_reg_map up_map = get_parent_map();

	// Then translate these addresses in the parent's space
	if (up_map is null) {
	  // This is the top-most system/block!
	  addr = local_addr.dup;
	  foreach (ref ad; addr) {
	    ad += _m_base_addr;
	  }
	} else {
	  int w, k;

	  // Scale the consecutive local address in the system's granularity
	  if (bus_width < up_map.get_n_bytes(UVM_NO_HIER)) {
	    k = 1;
	  }
	  else {
	    k = ((bus_width-1) / up_map.get_n_bytes(UVM_NO_HIER)) + 1;
	  }

	  uvm_reg_addr_t  base_addr_ = up_map.get_submap_offset(this);
	
	  foreach (i, lad; local_addr) {
	    uvm_reg_addr_t[]  sys_addr;
	    w = up_map.get_physical_addresses(cast(uvm_reg_addr_t)
					      (base_addr_ + local_addr[i] * k),
					      0,
					      bus_width,
					      sys_addr);
	    foreach (sad; sys_addr) {
	      addr ~= sad;
	    }
	  }
	  // The width of each access is the minimum of this block or the system's width
	  if (w < bus_width) {
	    bus_width = w;
	  }
	}

	return bus_width;

      }
    }  // get_physical_addresses


  // Public: get_reg_by_offset
  //
  // Get register mapped at offset
  //
  // Identify the register located at the specified offset within
  // this address map for the specified type of access.
  // Returns ~null~ if no such register is found.
  //
  // The model must be locked using <uvm_reg_block::lock_model()>
  // to enable this publicality.
  //
  // extern virtual public uvm_reg get_reg_by_offset(uvm_reg_addr_t offset,
  // 						  bool           read = 1);
  //--------------
  // Get-By-Offset
  //--------------


  // get_reg_by_offset

  public uvm_reg get_reg_by_offset(uvm_reg_addr_t offset,
				   bool           read = true) {
    synchronized(this) {
      if (!_m_parent.is_locked()) {
	uvm_error("RegModel", format("Cannot get register by offset: " ~
				     "Block %s is not locked.",
				     _m_parent.get_full_name()));
	return null;
      }

      if (!read && offset in _m_regs_by_offset_wo) {
	return _m_regs_by_offset_wo[offset];
      }
   
      if (offset in _m_regs_by_offset) {
	return _m_regs_by_offset[offset];
      }
      return null;
    }
  }


  //
  // Public: get_mem_by_offset
  // Get memory mapped at offset
  //
  // Identify the memory located at the specified offset within
  // this address map. The offset may refer to any memory location
  // in that memory.
  // Returns ~null~ if no such memory is found.
  //
  // The model must be locked using <uvm_reg_block::lock_model()>
  // to enable this publicality.
  //
  // extern virtual public uvm_mem    get_mem_by_offset(uvm_reg_addr_t offset);

  // get_mem_by_offset

  public uvm_mem get_mem_by_offset(uvm_reg_addr_t offset) {
    synchronized(this) {
      if (! _m_parent.is_locked()) {
	uvm_error("RegModel", format("Cannot memory register by offset: " ~
				     "Block %s is not locked.",
				     _m_parent.get_full_name()));
	return null;
      }

      foreach (range, mem; _m_mems_by_offset) {
	if (range.min <= offset && offset <= range.max) {
	  return mem;
	}
      }
   
      return null;
    }
  }



  //------------------
  // Group: Bus Access
  //------------------

  // Public: set_auto_predict 
  //
  // Sets the auto-predict mode for his map.
  //
  // When ~on~ is ~TRUE~, 
  // the register model will automatically update its mirror
  // (what it thinks should be in the DUT) immediately after
  // any bus read or write operation via this map. Before a <uvm_reg::write>
  // or <uvm_reg::read> operation returns, the register's <uvm_reg::predict>
  // method is called to update the mirrored value in the register.
  //
  // When ~on~ is ~FALSE~, bus reads and writes via this map do not
  // automatically update the mirror. For real-time updates to the mirror
  // in this mode, you connect a <uvm_reg_predictor> instance to the bus
  // monitor. The predictor takes observed bus transactions from the
  // bus monitor, looks up the associated <uvm_reg> register given
  // the address, then calls that register's <uvm_reg::predict> method.
  // While more complex, this mode will capture all register read/write
  // activity, including that not directly descendant from calls to
  // <uvm_reg::write> and <uvm_reg::read>.
  //
  // By default, auto-prediction is turned off.
  // 
  // public void set_auto_predict(bool on=1); _m_auto_predict = on; }
  public void set_auto_predict(bool on = true) {
    synchronized(this) {
      _m_auto_predict = on;
    }
  }


  // Public: get_auto_predict
  //
  // Gets the auto-predict mode setting for this map.
  // 
  // public bool  get_auto_predict(); return _m_auto_predict; }
  public bool  get_auto_predict() {
    synchronized(this) {
      return _m_auto_predict;
    }
  }


  // Public: set_check_on_read
  // 
  // Sets the check-on-read mode for his map
  // and all of its submaps.
  //
  // When ~on~ is ~TRUE~, 
  // the register model will automatically check any value read back from
  // a register or field against the current value in its mirror
  // and report any discrepancy.
  // This effectively combines the publicality of the
  // <uvm_reg::read()> and <uvm_reg::mirror(UVM_CHECK)> method.
  // This mode is useful when the register model is used passively.
  //
  // When ~on~ is ~FALSE~, no check is made against the mirrored value.
  //
  // At the end of the read operation, the mirror value is updated based
  // on the value that was read reguardless of this mode setting.
  //
  // By default, auto-prediction is turned off.
  // 
  // public void set_check_on_read(bool on=1);
  public void set_check_on_read(bool on = true) {
    synchronized(this) {
      _m_check_on_read = on;
      foreach (submap, unused; _m_submaps) {
	submap.set_check_on_read(on);
      }
    }
  }


  // Public: get_check_on_read
  //
  // Gets the check-on-read mode setting for this map.
  // 
  public bool  get_check_on_read() {
    synchronized(this) {
      return _m_check_on_read;
    }
  }


   
  // Task: do_bus_write
  //
  // Perform a bus write operation.
  //
  // extern virtual task do_bus_write (uvm_reg_item rw,
  // 				    uvm_sequencer_base sequencer,
  // 				    uvm_reg_adapter adapter);

  // do_bus_write

  // task
  public void do_bus_write (uvm_reg_item rw,
			    uvm_sequencer_base sequencer,
			    uvm_reg_adapter adapter) {

    uvm_reg_map        system_map = get_root_map();
    uint               bus_width  = get_n_bytes();
    uvm_reg_byte_en_t  byte_en    = cast(uvm_reg_byte_en_t) -1;
    uvm_reg_map_info   map_info;
    int                n_bits;
    int                lsb;
    int                skip;
    uint               curr_byte;
    int                n_access_extra, n_access;
    int                n_bits_init;

    Xget_bus_infoX(rw, map_info, n_bits_init, lsb, skip);
    auto addrs = map_info.addr;

    // if a memory, adjust addresses based on offset
    if (rw.element_kind == UVM_MEM) {
      foreach (ref addr; addrs) {
	addr = addr + map_info.mem_range.stride * rw.offset;
      }
    }

    foreach (uvm_reg_data_t value; rw.get_value()) { // foreach_value

      /* calculate byte_enables */
      if (rw.element_kind == UVM_FIELD) {
	int temp_be;
	int idx;
	n_access_extra = lsb%(bus_width*8);                
	n_access = n_access_extra + n_bits_init;
	temp_be = n_access_extra;
	value = value << n_access_extra;
	while(temp_be >= 8) {
	  byte_en[idx++] = 0;
	  temp_be -= 8;
	}                        
	temp_be += n_bits_init;
	while(temp_be > 0) {
	  byte_en[idx++] = 1;
	  temp_be -= 8;
	}
	byte_en &= (1<<idx)-1;
	for (int i=0; i<skip; i++) {
	  addrs = addrs[1..$];
	}
	while (addrs.length > (n_bits_init/(bus_width*8) + 1)) {
	  addrs = addrs[0..$-1];
	}
      }
      curr_byte=0;
      n_bits= n_bits_init;     
              
      foreach(i, addr; addrs) { // : foreach_addr

	uvm_sequence_item bus_req;
	uvm_reg_bus_op rw_access;
	uvm_reg_data_t data;


	data = (value >> (curr_byte*8)) & ((1L << (bus_width * 8))-1);
       
	uvm_info(get_type_name(),
		 format("Writing 'h%0h at 'h%0h via map \"%s\"...",
			data, addr, rw.map.get_full_name()), uvm_verbosity.UVM_FULL);

	if (rw.element_kind == UVM_FIELD) {
	  for (int z=0; z<bus_width; z++) {
	    rw_access.byte_en[z] = byte_en[curr_byte+z];
	  }
	}
                
	rw_access.kind    = rw.kind;
	rw_access.addr    = addr;
	rw_access.data    = data;
	rw_access.n_bits  = (n_bits > bus_width*8) ? bus_width*8 : n_bits;
	rw_access.byte_en = byte_en;

	adapter.m_set_item(rw);
	bus_req = adapter.reg2bus(rw_access);
	adapter.m_set_item(null);
      
	if (bus_req is null) {
	  uvm_fatal("RegMem",
		    "adapter [" ~ adapter.get_name() ~
		    "] didnt return a bus transaction");
	}
      
	bus_req.set_sequencer(sequencer);
	rw.parent.start_item(bus_req, rw.prior);

	if (rw.parent !is null && i == 0) {
	  rw.parent.mid_do(rw);
	}

	rw.parent.finish_item(bus_req);
	bus_req.end_event.wait_on();

	if (adapter.provides_responses) {
	  uvm_sequence_item bus_rsp;
	  uvm_access_e op;
	  // TODO: need to test for right trans type, if not put back in q
	  rw.parent.get_base_response(bus_rsp);
	  adapter.bus2reg(bus_rsp,rw_access);
	}
	else {
	  adapter.bus2reg(bus_req,rw_access);
	}

	if (rw.parent !is null && i == addrs.length-1) {
	  rw.parent.post_do(rw);
	}

	rw.status = rw_access.status;

	uvm_info(get_type_name(),
		 format("Wrote 'h%0h at 'h%0h via map \"%s\": %s...",
			data, addr, rw.map.get_full_name(),
			rw.status), uvm_verbosity.UVM_FULL);

	if (rw.status == UVM_NOT_OK) break;

	curr_byte += bus_width;
	n_bits -= bus_width * 8;

      } // : foreach_addr

      foreach (ref addr; addrs) {
	addr = addr + map_info.mem_range.stride;
      }

    } // foreach_value
  }
  // endtask: do_bus_write

  

  // Task: do_bus_read
  //
  // Perform a bus read operation.
  //
  // extern virtual task do_bus_read (uvm_reg_item rw,
  // 				   uvm_sequencer_base sequencer,
  // 				   uvm_reg_adapter adapter);

  // task do_bus_read (uvm_reg_item rw,
  // 		    uvm_sequencer_base sequencer,
  // 		    uvm_reg_adapter adapter);

  // task
  public void do_bus_read (uvm_reg_item rw,
			   uvm_sequencer_base sequencer,
			   uvm_reg_adapter adapter) {

    uvm_reg_map        system_map = get_root_map();
    uint               bus_width  = get_n_bytes();
    uvm_reg_byte_en_t  byte_en    = -1;
    uvm_reg_map_info   map_info;
    int                size, n_bits;
    int                skip;
    int                lsb;
    uint               curr_byte;
    int                n_access_extra, n_access;

    Xget_bus_infoX(rw, map_info, n_bits, lsb, skip);

    auto addrs = map_info.addr;

    size = n_bits;

    // if a memory, adjust addresses based on offset
    if (rw.element_kind == UVM_MEM) {
      foreach (ref addr; addrs) {
	addr = addr + map_info.mem_range.stride * rw.offset;
      }
    }
    
    foreach (ref value; rw.get_value()) { // : foreach_value

      /* calculate byte_enables */
      if (rw.element_kind == UVM_FIELD) {
	int temp_be;
	int idx;
	n_access_extra = lsb%(bus_width*8);                
	n_access = n_access_extra + n_bits;
	temp_be = n_access_extra;
	while(temp_be >= 8) {
	  byte_en[idx++] = 0;
	  temp_be -= 8;
	}                        
	temp_be += n_bits;
	while(temp_be > 0) {
	  byte_en[idx++] = 1;
	  temp_be -= 8;
	}
	byte_en &= (1<<idx)-1;
	for (int i=0; i<skip; i++) {
	  addrs = addrs[1..$]; // .pop_front();
	}
	while (addrs.length > (n_bits/(bus_width*8) + 1)) {
	  addrs = addrs[0..$-1]; // .pop_back();
	}
      }
      curr_byte=0;
      value = 0;
              
      foreach (i, ref addr; addrs) {

	uvm_sequence_item bus_req;
	uvm_reg_bus_op rw_access;
	uvm_reg_data_logic_t data;
       

	uvm_info(get_type_name(),
		 format("Reading address 'h%0h via map \"%s\"...",
			addr, get_full_name()), uvm_verbosity.UVM_FULL);
                
	if (rw.element_kind == UVM_FIELD) {
	  for (int z=0;z<bus_width;z++) {
	    rw_access.byte_en[z] = byte_en[curr_byte+z];
	  }
	}

	rw_access.kind = rw.kind;
	rw_access.addr = addr;
	rw_access.data = 0;
	rw_access.byte_en = byte_en;
	rw_access.n_bits = (n_bits > bus_width*8) ? bus_width*8 : n_bits;
                          
	adapter.m_set_item(rw);
	bus_req = adapter.reg2bus(rw_access);
	adapter.m_set_item(null);
	if (bus_req is null) {
	  uvm_fatal("RegMem",
		    "adapter [" ~ adapter.get_name() ~
		    "] didnt return a bus transaction");
	}
	bus_req.set_sequencer(sequencer);
	rw.parent.start_item(bus_req,rw.prior);

	if (rw.parent !is null && i == 0) {
	  rw.parent.mid_do(rw);
	}

	rw.parent.finish_item(bus_req);
	bus_req.end_event.wait_on();

	if (adapter.provides_responses) {
	  uvm_sequence_item bus_rsp;
	  uvm_access_e op;
	  // TODO: need to test for right trans type, if not put back in q
	  rw.parent.get_base_response(bus_rsp);
	  adapter.bus2reg(bus_rsp,rw_access);
	}
	else {
	  adapter.bus2reg(bus_req,rw_access);
	}

	data = rw_access.data & ((1<<bus_width*8)-1);

	rw.status = rw_access.status;

	if (rw.status == UVM_IS_OK && data.isX()) {
	  rw.status = UVM_HAS_X;
	}
         
	uvm_info(get_type_name(),
		 format("Read 'h%0h at 'h%0h via map \"%s\": %s...",
			data, addr, get_full_name(), rw.status),
		 uvm_verbosity.UVM_FULL);

	if (rw.status == UVM_NOT_OK) break;

	value |= data << curr_byte*8;

	if (rw.parent !is null && i == addrs.length-1) {
	  rw.parent.post_do(rw);
	}

	curr_byte += bus_width;
	n_bits -= bus_width * 8;
      }

      foreach (ref addr; addrs) {
	addr = addr + map_info.mem_range.stride;
      }

      if (rw.element_kind == UVM_FIELD)
	value = (value >> (n_access_extra)) & ((1<<size)-1);
    }
  } // endtask: do_bus_read

  // Task: do_write
  //
  // Perform a write operation.
  //
  // extern virtual task do_write(uvm_reg_item rw);
  // do_write(uvm_reg_item rw)

  // task
  // do_bus_read

  public void do_write(uvm_reg_item rw) {

    uvm_sequence_base tmp_parent_seq;
    uvm_reg_map system_map = get_root_map();
    uvm_reg_adapter adapter = system_map.get_adapter();
    uvm_sequencer_base sequencer = system_map.get_sequencer();

    if (adapter !is null && adapter.parent_sequence !is null) {
      uvm_object obj = adapter.parent_sequence.clone();
      auto seq = cast(uvm_sequence_base) obj;
      assert(seq !is null); // assert($cast(seq,o));
      seq.set_parent_sequence(rw.parent);
      rw.parent = seq;
      tmp_parent_seq = seq;
    }

    if (rw.parent is null) {
      rw.parent = new uvm_sequence_base("default_parent_seq");
      tmp_parent_seq = rw.parent;
    }

    if (adapter is null) {
      rw.set_sequencer(sequencer);
      rw.parent.start_item(rw,rw.prior);
      rw.parent.finish_item(rw);
      rw.end_event.wait_on();
    }
    else {
      do_bus_write(rw, sequencer, adapter);
    }

    if (tmp_parent_seq !is null) {
      sequencer.m_sequence_exiting(tmp_parent_seq);
    }
  }

  // Task: do_read
  //
  // Perform a read operation.
  //
  // extern virtual task do_read(uvm_reg_item rw);

  // do_read(uvm_reg_item rw)

  // task
  public void do_read(uvm_reg_item rw) {

    uvm_sequence_base tmp_parent_seq;
    uvm_reg_map system_map = get_root_map();
    uvm_reg_adapter adapter = system_map.get_adapter();
    uvm_sequencer_base sequencer = system_map.get_sequencer();

    if (adapter !is null && adapter.parent_sequence !is null) {
      uvm_object obj = adapter.parent_sequence.clone();
      auto seq = cast(uvm_sequence_base) obj;
      assert(seq !is null); // assert($cast(seq,obj));
      seq.set_parent_sequence(rw.parent);
      rw.parent = seq;
      tmp_parent_seq = seq;
    }

    if (rw.parent is null) {
      rw.parent = new uvm_sequence_base("default_parent_seq");
      tmp_parent_seq = rw.parent;
    }

    if (adapter is null) {
      rw.set_sequencer(sequencer);
      rw.parent.start_item(rw,rw.prior);
      rw.parent.finish_item(rw);
      rw.end_event.wait_on();
    }
    else {
      do_bus_read(rw, sequencer, adapter);
    }

    if (tmp_parent_seq !is null) {
      sequencer.m_sequence_exiting(tmp_parent_seq);
    }
  } // endtask


  // extern public void Xget_bus_infoX (uvm_reg_item rw,
  // 				     output uvm_reg_map_info map_info,
  // 				     output int size,
  // 				     output int lsb,
  // 				     output int addr_skip);
  //-----------
  // Bus Access
  //-----------

  public void Xget_bus_infoX(uvm_reg_item rw,
			     out uvm_reg_map_info map_info,
			     out int size,
			     out int lsb,
			     out int addr_skip) {

    if (rw.element_kind == UVM_MEM) {
      auto mem = cast(uvm_mem) rw.element;
      if(rw.element is null || mem is null) {
	uvm_fatal("REG/CAST",
		  "uvm_reg_item 'element_kind' is UVM_MEM, " ~ 
		  "but 'element' does not point to a memory: " ~
		  rw.get_name());
      }
      map_info = get_mem_map_info(mem);
      size = mem.get_n_bits();
    }
    else if (rw.element_kind == UVM_REG) {
      auto rg = cast (uvm_reg) rw.element;
      if(rw.element is null || rg is null) {
	uvm_fatal("REG/CAST",
		  "uvm_reg_item 'element_kind' is UVM_REG, " ~ 
		  "but 'element' does not point to a register: " ~
		  rw.get_name());
      }
      map_info = get_reg_map_info(rg);
      size = rg.get_n_bits();
    }
    else if (rw.element_kind == UVM_FIELD) {
      auto field = cast(uvm_reg_field) rw.element;
      if(rw.element is null || field is null) {
	uvm_fatal("REG/CAST",
		  "uvm_reg_item 'element_kind' is UVM_FIELD, " ~ 
		  "but 'element' does not point to a field: " ~
		  rw.get_name());
      }
      map_info = get_reg_map_info(field.get_parent());
      size = field.get_n_bits();
      lsb = field.get_lsb_pos();
      addr_skip = lsb/(get_n_bytes()*8);
    }
  }


  //-------------
  // Standard Ops
  //-------------

  // extern virtual public string      convert2string();
  // convert2string

  override string convert2string() {

    uvm_reg[]  regs;
    uvm_vreg[] vregs;
    uvm_mem[]  mems;
    uvm_endianness_e endian;
    string prefix;

    string result = format("%sMap %s", prefix, get_full_name());
    endian = get_endian(UVM_NO_HIER);
    result ~= format(" -- %0d bytes (%s)", 
		     get_n_bytes(UVM_NO_HIER), endian);
    get_registers(regs);
    foreach (reg; regs) {
      result ~= format("\n%s", 
		       reg.convert2string());//{prefix, "   "}, this));
    }
    get_memories(mems);
    foreach (mem; mems) {
      result ~= format("\n%s",
		       mem.convert2string());//{prefix, "   "}, this));
    }
    get_virtual_registers(vregs);
    foreach (vreg; vregs) {
      result ~= format("\n%s", 
		       vreg.convert2string());//{prefix, "   "}, this));
    }
    return result;
  }

  // extern virtual public uvm_object  clone();

  // clone

  override uvm_object clone() {
    //uvm_rap_map me;
    //me = new this;
    //return me;
    return null;
  }


  // extern virtual public void        do_print (uvm_printer printer);
  // do_print

  override void do_print (uvm_printer printer) {

    uvm_reg[]          regs;
    uvm_vreg[]         vregs;
    uvm_mem[]          mems;
    uvm_endianness_e   endian;
    uvm_reg_map[]      maps;
    string             prefix;
    uvm_sequencer_base sqr = get_sequencer();
  
    super.do_print(printer);
    //  printer.print_generic(get_name(), get_type_name(), -1, convert2string()); 

    endian = get_endian(UVM_NO_HIER);
    //   $sformat(convert2string, "%s -- %0d bytes (%s)", convert2string,
    //            get_n_bytes(UVM_NO_HIER), endian.name());
   
    printer.print_generic("endian", "", -2, endian.to!string); 
    if(sqr !is null) {
      printer.print_generic("effective sequencer",
			    sqr.get_type_name(), -2, sqr.get_full_name());
    }
             
    get_registers(regs,UVM_NO_HIER);
    foreach (reg; regs) {
      printer.print_generic(reg.get_name(), reg.get_type_name(),
			    -2, format("@%0d +'h%0x", reg.get_inst_id(),
				       reg.get_address(this)));
    }
    get_memories(mems);
    foreach (mem; mems) {
      printer.print_generic(mem.get_name(), mem.get_type_name(),
			    -2, format("@%0d +'h%0x",
				       mem.get_inst_id(),
				       mem.get_address(0, this)));
    }
   
    get_virtual_registers(vregs);
    foreach (vreg; vregs) {
      printer.print_generic(vreg.get_name(), vreg.get_type_name(),
			    -2, format("@%0d +'h%0x", vreg.get_inst_id(),
				       vreg.get_address(0,this)));
    }
    
    get_submaps(maps);
    foreach (map; maps) {
      printer.print_object(map.get_name(), map);
    }
  }

  // extern virtual public void        do_copy   (uvm_object rhs);
  // do_copy

  override void do_copy (uvm_object rhs) {
    //uvm_reg_map rhs_;
    //assert($cast(rhs_,rhs));

    //rhs_.regs = regs;
    //rhs_.mems = mems;
    //rhs_.vregs = vregs;
    //rhs_.blks = blks;
    //... and so on
  }

  //extern virtual public bit       do_compare (uvm_object rhs, uvm_comparer comparer);
  //extern virtual public void      do_pack (uvm_packer packer);
  //extern virtual public void      do_unpack (uvm_packer packer);
} // endclass: uvm_reg_map
   


