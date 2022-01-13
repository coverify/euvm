// -------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2012 Accellera Systems Initiative
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2014-2017 Intel Corporation
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2014 Semifore
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

module uvm.reg.uvm_reg_map;

import uvm.base.uvm_object: uvm_object;
import uvm.meta.misc;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_scope: uvm_scope_base;
import uvm.base.uvm_globals: uvm_fatal, uvm_error, uvm_warning, uvm_info;
import uvm.base.uvm_object_globals: uvm_verbosity, uvm_radix_enum;
import uvm.base.uvm_component: uvm_event_pool;
import uvm.base.uvm_event: uvm_event;
import uvm.base.uvm_printer: uvm_printer;

import uvm.seq.uvm_sequence_item: uvm_sequence_item;
import uvm.seq.uvm_sequence_base: uvm_sequence_base;
import uvm.seq.uvm_sequencer_base: uvm_sequencer_base;

import uvm.meta.misc;

import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_adapter: uvm_reg_adapter;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_cbs: uvm_reg_cbs, uvm_reg_read_only_cbs, uvm_reg_write_only_cbs;
import uvm.reg.uvm_reg_item: uvm_reg_item, uvm_reg_bus_op;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_sequence: uvm_reg_frontdoor;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_vreg: uvm_vreg;
import uvm.reg.uvm_vreg_field: uvm_vreg_field;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_reg_defines: UVM_REG_DATA_WIDTH;

import esdl.data.bvec;
import esdl.rand;

import std.string: format;
import std.conv: to;
import std.bitmanip: swapEndian;

// Class -- NODOCS -- uvm_reg_transaction_order_policy
// Not in LRM.
class uvm_reg_map_info
{
  mixin uvm_sync;
  @uvm_public_sync
  private uvm_reg_addr_t         _offset;
  @uvm_public_sync
  private string                 _rights;
  @uvm_public_sync
  private bool                   _unmapped;
  @uvm_public_sync
  private uvm_reg_addr_t[]       _addr;
  @uvm_public_sync
  private uvm_reg_frontdoor      _frontdoor;
  @uvm_public_sync
  private uvm_reg_map_addr_range _mem_range;
   
  // if set marks the uvm_reg_map_info as initialized, prevents using an uninitialized map (for instance if the model 
  // has not been locked accidently and the maps have not been computed before)
  @uvm_public_sync
  private bool                  _is_initialized;

}


// Class -- NODOCS -- uvm_reg_transaction_order_policy
abstract class uvm_reg_transaction_order_policy: uvm_object, rand.barrier
{
  this(string name = "policy") {
    super(name);
  }
    
  // Function -- NODOCS -- order
  // the order() function may reorder the sequence of bus transactions
  // produced by a single uvm_reg transaction (read/write).
  // This can be used in scenarios when the register width differs from 
  // the bus width and one register access results in a series of bus transactions.
  // the first item (0) of the queue will be the first bus transaction (the last($) 
  // will be the final transaction
  abstract void order(ref uvm_reg_bus_op[] q);
}

// Extends virtual class uvm_sequence_base so that it can be constructed:
class uvm_reg_seq_base: uvm_sequence_base
{
 
  mixin uvm_object_essentials;


  this(string name = "uvm_reg_seq_base") {
    super(name);
  }

}

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_reg_map
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

// @uvm-ieee 1800.2-2020 auto 18.2.1
class uvm_reg_map: uvm_object, rand.barrier
{
  mixin uvm_object_essentials;

  mixin uvm_sync;
  
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

  @uvm_private_sync
  private uvm_reg_transaction_order_policy _policy;
  
  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uvm_reg_map   _m_backdoor;
    this() {
      _m_backdoor = new uvm_reg_map("Backdoor");
    }
  }

  mixin (uvm_scope_sync_string);

  // @uvm-ieee 1800.2-2020 auto 18.2.2
  public static uvm_reg_map backdoor() {
    synchronized (_uvm_scope_inst) {
      return _m_backdoor;
    }
  }

  // Xinit_address_mapX

  public void Xinit_address_mapX() {
    synchronized (this) {
      uint bus_width;

      uvm_reg_map top_map = get_root_map();

      synchronized(top_map) {

	if (this is top_map) {
	  top_map._m_regs_by_offset.clear();
	  top_map._m_regs_by_offset_wo.clear();
	  top_map._m_mems_by_offset.clear();
	}

	foreach (l, submap; _m_submaps) {
	  uvm_reg_map map=l;
	  map.Xinit_address_mapX();
	}

	foreach (rg_, reg_info; _m_regs_info) {
	  uvm_reg rg = rg_;
	  reg_info.is_initialized = true;
	  if (!reg_info.unmapped) {
	    string rg_acc = rg.Xget_fields_accessX(this);
	    uvm_reg_addr_t[] addrs;
        
	    bus_width = get_physical_addresses(reg_info.offset, 0,
					       rg.get_n_bytes(), addrs);
        
	    foreach (i, addr; addrs) {
	      if (addr in top_map._m_regs_by_offset &&
			    top_map._m_regs_by_offset[addr] != rg) {

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
		  string a = format("%0h",addr);
		  uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' register '" ~ 
			      rg.get_full_name() ~  "' maps to same address as register '" ~ 
			      top_map._m_regs_by_offset[addr].get_full_name() ~ "': 'h" ~ a);
		}
	      }
	      else
		top_map._m_regs_by_offset[addr] = rg;
          
	      foreach (range, mem_by_offset; top_map._m_mems_by_offset) {
		if (addr >= range.min && addr <= range.max) {
		  string a = format("%0h",addr);
		  string b = format("[%0h:%0h]",range.min,range.max);
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
	    uint bo;
	  
	    bus_width = get_physical_addresses_to_map(mem_info.offset, 0, mem.get_n_bytes(),
						      addrs, null, bo, mem);
	    min = (addrs[0] < addrs[addrs.length-1]) ? addrs[0] : addrs[addrs.length-1];

	    // foreach(addrs[idx])
	    //   `uvm_info("UVM/REG/ADDR",$sformatf("idx%0d addr=%0x",idx,addrs[idx]),UVM_DEBUG)

	    get_physical_addresses_to_map(mem_info.offset, (mem.get_size()-1),
					  mem.get_n_bytes(), addrs_max, null, bo, mem);
	    max = (addrs_max[0] > addrs_max[addrs_max.length-1]) ?
	      addrs_max[0] : addrs_max[addrs_max.length-1];

	    stride = mem.get_n_bytes()/get_addr_unit_bytes(); 
	    
	    // foreach(addrs_max[idx])
	    //   `uvm_info("UVM/REG/ADDR",$sformatf("idx%0d addr=%0x",idx,addrs_max[idx]),UVM_DEBUG)
	          
	    // `uvm_info("UVM/REG/ADDR",$sformatf("mem %0d x %0d in map aub(bytes)=%0d n_bytes=%0d",mem.get_size(),mem.get_n_bits(),
	    //   get_addr_unit_bytes(),get_n_bytes(UVM_NO_HIER)),UVM_DEBUG)
 
	    /*
	      if (uvm_report_enabled(UVM_DEBUG, UVM_INFO,"UVM/REG/ADDR")) begin
	      uvm_reg_addr_t ad[];
	      for(int idx=0;idx<mem.get_size();idx++) begin
	      void'(get_physical_addresses_to_map(m_mems_info[mem].offset,idx,1,ad,null,bo,mem));
		   
	      `uvm_info("UVM/REG/ADDR",$sformatf("idx%d addr=%x",idx,ad[0]),UVM_DEBUG)
	      end	
	      end   
	    */

	    if (mem.get_n_bytes()<get_addr_unit_bytes())
	      uvm_warning("UVM/REG/ADDR",
			  format("this version of UVM does not properly support memories with a smaller word width than the enclosing map. map %s has n_bytes=%0d aub=%0d while the mem has get_n_bytes %0d. multiple memory words fall into one bus address. if that happens memory addressing will be unpacked.",
				 get_full_name(), get_n_bytes(uvm_hier_e.UVM_NO_HIER),
				 get_addr_unit_bytes(), mem.get_n_bytes()));

	    if (mem.get_n_bytes() > get_addr_unit_bytes())
	      if (mem.get_n_bytes() % get_addr_unit_bytes())  {
		uvm_warning("UVM/REG/ADDR",
			    format("memory %s is not matching the word width of the enclosing map %s (one memory word not fitting into k map addresses)",
				   mem.get_full_name(), get_full_name()));
	      }

	    if (mem.get_n_bytes() < get_addr_unit_bytes())
	      if (get_addr_unit_bytes() % mem.get_n_bytes()) 
		uvm_warning("UVM/REG/ADDR",
			    format("the memory %s is not matching the word width of the enclosing map %s one map address doesnt cover k memory words)",
				   mem.get_full_name(), get_full_name()));

	    if (mem.get_n_bits() % 8)
	      uvm_warning("UVM/REG/ADDR",
			  format("this implementation of UVM requires memory words to be k*8 bits (mem %s has %0d bit words)",
				 mem.get_full_name(), mem.get_n_bits()));
		
	    foreach (reg_addr, reg_by_offset; top_map.m_regs_by_offset) {
	      if (reg_addr >= min && reg_addr <= max) {
		string a = format("%0h", reg_addr);
		uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~
			    mem.get_full_name() ~ "' maps to same address as register '" ~
			    reg_by_offset.get_full_name() ~ "': 'h" ~ a);
	      }
	    }

	    foreach (range, mem_by_offset; top_map.m_mems_by_offset) {
	      if (min <= range.max && max >= range.max ||
		  min <= range.min && max >= range.min ||
		  min >= range.min && max <= range.max) 
		if (mem_by_offset != mem) // do not warn if the same mem is located at the same address via different paths
		  {
		    string a = format("[%0h:%0h]", min, max);
		    uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~
				mem.get_full_name() ~ "' overlaps with address range of memory '" ~
				mem_by_offset.get_full_name() ~ "': 'h" ~ a);
		  }
	    }

	    uvm_reg_map_addr_range range = uvm_reg_map_addr_range(min, max, stride);
	    top_map.m_mems_by_offset[range] = mem;
	    m_mems_info[mem].addr  = addrs;
	    m_mems_info[mem].mem_range = range;
	  }
	}

	// If the block has no registers or memories,
	// bus_width won't be set
	if (bus_width == 0) bus_width = m_n_bytes;

	m_system_n_bytes = bus_width;
      }
    }
  }


  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------


  // @uvm-ieee 1800.2-2020 auto 18.2.3.1
  this(string name = "uvm_reg_map") {
    synchronized (this) {
      super((name == "") ? "default_map" : name);
      _m_auto_predict = false;
      _m_check_on_read = false;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.3.2
  public void configure(uvm_reg_block    parent,
			uvm_reg_addr_t   base_addr,
			uint             n_bytes,
			uvm_endianness_e endian,
			bool             byte_addressing=true) {
    synchronized (this) {
      _m_parent     = parent;
      _m_n_bytes    = n_bytes;
      _m_endian     = endian;
      _m_base_addr  = base_addr;
      _m_byte_addressing = byte_addressing;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.3.3
  public void add_reg(uvm_reg rg, 
		      uvm_reg_addr_t offset,
		      string rights = "RW",
		      bool unmapped = false,
		      uvm_reg_frontdoor frontdoor = null) {
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

      uvm_reg_map_info info = new uvm_reg_map_info();
      synchronized (info) {
	info._offset   = offset;
	info._rights   = rights;
	info._unmapped = unmapped;
	info._frontdoor = frontdoor;
	info._is_initialized = false;
      }
      _m_regs_info[rg] = info;
    }
  }



  // @uvm-ieee 1800.2-2020 auto 18.2.3.4
  public void add_mem(uvm_mem mem,
		      uvm_reg_addr_t offset,
		      string rights = "RW",
		      bool unmapped=false,
		      uvm_reg_frontdoor frontdoor=null) {
    synchronized (this) {
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

      uvm_reg_map_info info = new uvm_reg_map_info();
      synchronized (info) {
	info.offset   = offset;
	info.rights   = rights;
	info.unmapped = unmapped;
	info.frontdoor = frontdoor;
      }
      _m_mems_info[mem] = info;
    }
  }
   

  // NOTE THIS isnt really true because one can add a map only to another map if the 
  // map parent blocks are either the same or the maps parent is an ancestor of the submaps parent
  // also AddressUnitBits needs to match which means essentially that within a block there can only be one 
  // AddressUnitBits
   
  // @uvm-ieee 1800.2-2020 auto 18.2.3.5
  public void add_submap (uvm_reg_map child_map,
			  uvm_reg_addr_t offset) {
    synchronized (this) {
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

      // this check means that n_bytes cannot change in a map hierarchy, that should work with 5446
      // { // n_bytes_match_check
      if (_m_n_bytes > child_map.get_n_bytes(uvm_hier_e.UVM_NO_HIER)) {
	uvm_warning("RegModel",
		    format("Adding %0d-byte submap '%s' to %0d-byte parent map '%s'",
			   child_map.get_n_bytes(uvm_hier_e.UVM_NO_HIER), child_map.get_full_name(),
			   _m_n_bytes, get_full_name()));
      }
      // }

      child_map.add_parent_map(this,offset);

      set_submap_offset(child_map, offset);
    }
  }


  // Function -- NODOCS -- set_sequencer
  //
  // Set the sequencer and adapter associated with this map. This method
  // ~must~ be called before starting any sequences based on uvm_reg_sequence.

  // @uvm-ieee 1800.2-2020 auto 18.2.3.6
  public void set_sequencer(uvm_sequencer_base sequencer,
			    uvm_reg_adapter adapter=null) {
    synchronized (this) {
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


  // Function -- NODOCS -- set_submap_offset
  //
  // Set the offset of the given ~submap~ to ~offset~.

  // @uvm-ieee 1800.2-2020 auto 18.2.3.8
  public void set_submap_offset(uvm_reg_map submap, uvm_reg_addr_t offset) {
    synchronized (this) {
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


  // Function -- NODOCS -- get_submap_offset
  //
  // Return the offset of the given ~submap~.

  // @uvm-ieee 1800.2-2020 auto 18.2.3.7
  public uvm_reg_addr_t get_submap_offset(uvm_reg_map submap) {
    synchronized (this) {
      if (submap is null) {
	uvm_error("REG/NULL","set_submap_offset: submap handle is null");
	return -1;
      }
      if (submap !in _m_submaps) {
	uvm_error("RegModel","Map '" ~ submap.get_full_name() ~ 
		  "' is not a submap of '" ~ get_full_name() ~ "'");
	return -1;
      }
      return _m_submaps[submap];
    }
  }


  // Function -- NODOCS -- set_base_addr
  //
  // Set the base address of this map.

  // @uvm-ieee 1800.2-2020 auto 18.2.3.9
  public void set_base_addr(uvm_reg_addr_t offset) {
    synchronized (this) {
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


  // @uvm-ieee 1800.2-2020 auto 18.2.3.10
  public void reset(string kind = "SOFT") {
    synchronized (this) {
      uvm_reg[] regs;

      get_registers(regs);

      foreach (i, reg; regs) {
	reg.reset(kind);
      }
    }
  }


  public void add_parent_map(uvm_reg_map parent_map,
			     uvm_reg_addr_t offset) {
    synchronized (this) {

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
      parent_map._m_submaps[this] = offset;

    }
  }

  public void Xverify_map_configX() {
    synchronized (this) {
      // Make sure there is a generic payload sequence for each map
      // in the model and vice-versa if this is a root sequencer
      bool error;
      uvm_reg_map root_map = get_root_map();

      if (root_map.get_adapter() is null) {
	uvm_error("RegModel", "Map '" ~ root_map.get_full_name() ~ 
		  "' does not have an adapter registered");
	error = true;
      }
      if (root_map.get_sequencer() is null) {
	uvm_error("RegModel", "Map '" ~ root_map.get_full_name() ~ 
		  "' does not have a sequencer registered");
	error = true;
      }
      if (error) {
	uvm_fatal("RegModel", "Must register an adapter and sequencer " ~
		  "for each top-level map in RegModel model");
	return;
      }

    }
  }
  

  public void m_set_reg_offset(uvm_reg rg, 
			       uvm_reg_addr_t offset,
			       bool unmapped) {
    synchronized (this) {
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
      synchronized (top_map) {
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
		  string a = format("%0h",addr);
		  uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' register '" ~ 
			      rg.get_full_name() ~  "' maps to same address as register '" ~ 
			      top_map._m_regs_by_offset[addr].get_full_name() ~ "': 'h" ~ a);
		}
	      }
	      else
		top_map._m_regs_by_offset[addr] = rg;

	      foreach (range, memoff; top_map._m_mems_by_offset) {
		if (addr >= range.min && addr <= range.max) {
		  string a = format("%0h",addr);
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
	  info.offset   = -1;
	  info.unmapped = 1;
	}
	else {
	  info.offset   = offset;
	  info.unmapped = 0;
	}
      
      }
    }
  }

  void m_set_mem_offset(uvm_mem mem, 
			uvm_reg_addr_t offset,
			bool unmapped) {
    synchronized(this) {
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

      synchronized(top_map) {
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
	    stride = cast (uint) ((max2 - max)/(mem.get_size()-1));

	    // make sure new offset does not conflict with others
	    foreach (reg_addr, regoff; top_map._m_regs_by_offset) {
	      if (reg_addr >= min && reg_addr <= max) {
		string a = format("[%0h:%0h]", min, max);
		string b = format("%0h", reg_addr);
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
		string a = format("[%0h:%0h]",min,max);
		string b = format("[%0h:%0h]",range.min,range.max);
		uvm_warning("RegModel", "In map '" ~ get_full_name() ~ "' memory '" ~ 
			    mem.get_full_name() ~  "' with range " ~ a ~ 
			    " overlaps existing memory with range '" ~ 
			    top_map._m_mems_by_offset[range].get_full_name() ~ "': " ~ b);
	      }
	    }

	    uvm_reg_map_addr_range range =
	      uvm_reg_map_addr_range(min, max, stride);
	    top_map._m_mems_by_offset[range] = mem;
	    info.addr  = addrs;
	    info.mem_range = range;
	  }
	}

	if (unmapped) {
	  info.offset   = -1;
	  info.unmapped = 1;
	}
	else {
	  info.offset   = offset;
	  info.unmapped = 0;
	}
      }
    }
  }

  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  // Public -- NODOCS -- get_name
  //
  // Get the simple name
  //
  // Return the simple object name of this address map.
  //

  // Public -- NODOCS -- get_full_name
  //
  // Get the hierarchical name
  //
  // Return the hierarchal name of this address map.
  // The base of the hierarchical name is the root block.
  //
  override string get_full_name() {
    synchronized (this) {
      if (_m_parent is null)
	return get_name();
      else
	return _m_parent.get_full_name() ~ "." ~ get_name();
    }
  }

  

  // @uvm-ieee 1800.2-2020 auto 18.2.4.1
  public uvm_reg_map get_root_map() {
    synchronized (this) {
      return (_m_parent_map is null) ? this : _m_parent_map.get_root_map();
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.2.4.2
  public uvm_reg_block get_parent() {
    synchronized (this) {
      return _m_parent;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.3
  public uvm_reg_map get_parent_map() {
    synchronized (this) {
      return _m_parent_map;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.4
  public uvm_reg_addr_t  get_base_addr(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      if (hier == uvm_hier_e.UVM_NO_HIER || _m_parent_map is null)
	return _m_base_addr;
      uvm_reg_addr_t base_addr = _m_parent_map.get_submap_offset(this);
      base_addr += _m_parent_map.get_base_addr(uvm_hier_e.UVM_HIER);
      return base_addr;
    }
  }


  // Public -- NODOCS -- get_n_bytes
  //
  // Get the width in bytes of the bus associated with this map. If ~hier~
  // is ~UVM_HIER~, then gets the effective bus width relative to the system
  // level. The effective bus width is the narrowest bus width from this
  // map to the top-level root map. Each bus access will be limited to this
  // bus width.
  //
  public uint get_n_bytes(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      if (hier == uvm_hier_e.UVM_NO_HIER)
	return _m_n_bytes;
      return _m_system_n_bytes;
    }
  }



  // Public -- NODOCS -- get_addr_unit_bytes
  //
  // Get the number of bytes in the smallest addressable unit in the map.
  // Returns 1 if the address map was configured using byte-level addressing.
  // Returns <get_n_bytes()> otherwise.
  //
  public uint get_addr_unit_bytes() {
    synchronized (this) {
      return (_m_byte_addressing) ? 1 : _m_n_bytes;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.7
  public uvm_endianness_e get_endian(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      if (hier == uvm_hier_e.UVM_NO_HIER || _m_parent_map is null)
	return _m_endian;
      return _m_parent_map.get_endian(hier);
    }
  }



  // @uvm-ieee 1800.2-2020 auto 18.2.4.8
  public uvm_sequencer_base get_sequencer(uvm_hier_e hier=uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      if (hier == uvm_hier_e.UVM_NO_HIER || _m_parent_map is null)
	return _m_sequencer;
      return _m_parent_map.get_sequencer(hier);
    }
  }



  // @uvm-ieee 1800.2-2020 auto 18.2.4.9
  public uvm_reg_adapter get_adapter(uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      if (hier == uvm_hier_e.UVM_NO_HIER || _m_parent_map is null)
	return _m_adapter;
      return _m_parent_map.get_adapter(hier);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.10
  public void get_submaps(ref uvm_reg_map[] maps,
			  uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      foreach (submap, unused; _m_submaps)
	maps ~= submap;
      if (hier == uvm_hier_e.UVM_HIER)
	foreach (submap, unused; _m_submaps) {
	  submap.get_submaps(maps);
	}
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.11
  public void get_registers(ref uvm_reg[] regs,
			    uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      foreach (rg, unused; _m_regs_info)
	regs ~= rg;
      if (hier == uvm_hier_e.UVM_HIER) {
	foreach (submap, unused; _m_submaps) {
	  submap.get_registers(regs);
	}
      }
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.12
  public void get_fields(ref uvm_reg_field[] fields,
			 uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      foreach (rg, unused; _m_regs_info) {
	rg.get_fields(fields);
      }
   
      if (hier == uvm_hier_e.UVM_HIER)
	foreach (submap, unused; _m_submaps) {
	  submap.get_fields(fields);
	}
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.13
  public void get_memories(ref uvm_mem[] mems,
			   uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      foreach (mem, unused; _m_mems_info)
	mems ~= mem;
    
      if (hier == uvm_hier_e.UVM_HIER)
	foreach (submap, unused; _m_submaps) {
	  submap.get_memories(mems);
	}
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.14
  public void get_virtual_registers(ref uvm_vreg[] regs,
				    uvm_hier_e hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      uvm_mem[] mems;
      get_memories(mems, hier);

      foreach (mem; mems)
	mem.get_virtual_registers(regs);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.15
  public void get_virtual_fields(ref uvm_vreg_field[] fields,
				 uvm_hier_e           hier = uvm_hier_e.UVM_HIER) {
    synchronized (this) {
      uvm_vreg[] regs;
      get_virtual_registers(regs, hier);

      foreach (reg; regs)
	reg.get_fields(fields);
    }
  }



  public uvm_reg_map_info get_reg_map_info(uvm_reg rg, bool error=true) {
    synchronized (this) {
      uvm_reg_map_info result;
      if (rg !in _m_regs_info) {
	if (error)
	  uvm_error("REG_NO_MAP", "Register '" ~ rg.get_name() ~
		    "' not in map '" ~ get_name() ~ "'");
	return null;
      }
      result = _m_regs_info[rg];
      if (! result.is_initialized)
	uvm_warning("RegModel", "map '" ~ get_name() ~
		    "' does not seem to be initialized " ~
		    "correctly, check that the top register " ~
		    "model is locked()");
      return result;
    }
  }

  public uvm_reg_map_info get_mem_map_info(uvm_mem mem, bool error=true) {
    synchronized (this) {
      if (mem !in _m_mems_info) {
	if (error)
	  uvm_error("REG_NO_MAP", "Memory '" ~ mem.get_name() ~
		    "' not in map '" ~ get_name() ~ "'");
	return null;
      }
      return _m_mems_info[mem];
    }
  }


  public uint get_size() {
    synchronized (this) {

      uint max_addr;
      uint addr;

      // get max offset from registers
      foreach (rg, reg_info; _m_regs_info) {
	addr = cast (uint) (reg_info.offset + ((rg.get_n_bytes()-1)/_m_n_bytes));
	if (addr > max_addr) max_addr = addr;
      }

      // get max offset from memories
      foreach (mem, mem_info; _m_mems_info) {
	addr = cast (uint) (mem_info.offset + (mem.get_size() * (((mem.get_n_bytes()-1)/_m_n_bytes)+1)) -1);
	if (addr > max_addr) max_addr = addr;
      }

      // get max offset from submaps
      foreach (submap, reg_addr; _m_submaps) {
	addr = cast (uint) (reg_addr + submap.get_size());
	if (addr > max_addr) max_addr = addr;
      }

      return max_addr + 1;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.16
  public int get_physical_addresses(uvm_reg_addr_t base_addr,
				    uvm_reg_addr_t mem_offset,
				    uint n_bytes,
				    ref uvm_reg_addr_t[] addr)
  {
    uint skip;
    return get_physical_addresses_to_map(base_addr, mem_offset, n_bytes,
					 addr, null, skip, null);
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.4.17
  public uvm_reg get_reg_by_offset(uvm_reg_addr_t offset,
				   bool           read = true) {
    synchronized (this) {
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


   // @uvm-ieee 1800.2-2020 auto 18.2.4.18
  public uvm_mem get_mem_by_offset(uvm_reg_addr_t offset) {
    synchronized (this) {
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


  // @uvm-ieee 1800.2-2020 auto 18.2.5.2
  public void set_auto_predict(bool on=true) {
    synchronized (this) {
      _m_auto_predict = on;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.5.1
  public bool  get_auto_predict() {
    synchronized (this) {
      return _m_auto_predict;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.2.5.3
  public void set_check_on_read(bool on=true) {
    synchronized (this) {
      _m_check_on_read = on;
      foreach (submap, unused; _m_submaps) {
	submap.set_check_on_read(on);
      }
    }
  }


  // Public -- NODOCS -- get_check_on_read
  //
  // Gets the check-on-read mode setting for this map.
  // 
  public bool  get_check_on_read() {
    synchronized (this) {
      return _m_check_on_read;
    }
  }


   
  // Task -- NODOCS -- do_bus_write
  //
  // Perform a bus write operation.
  //
  // task
  public void do_bus_write (uvm_reg_item rw,
			    uvm_sequencer_base sequencer,
			    uvm_reg_adapter adapter) {
    do_bus_access(rw, sequencer, adapter);
  }

  

  // Task -- NODOCS -- do_bus_read
  //
  // Perform a bus read operation.
  //
  // task
  public void do_bus_read (uvm_reg_item rw,
			   uvm_sequencer_base sequencer,
			   uvm_reg_adapter adapter) {
    do_bus_access(rw, sequencer, adapter);
  }

  // Task -- NODOCS -- do_write
  //
  // Perform a write operation.
  //
  public void do_write(uvm_reg_item rw) {

    uvm_sequence_base tmp_parent_seq;
    uvm_reg_map system_map = get_root_map();
    uvm_reg_adapter adapter = system_map.get_adapter();
    uvm_sequencer_base sequencer = system_map.get_sequencer();

    if (adapter !is null && adapter.parent_sequence !is null) {
      uvm_object obj = adapter.parent_sequence.clone();
      auto seq = cast (uvm_sequence_base) obj;

      if (obj is null)
	uvm_fatal("REG/CLONE",
		  "failed to clone adapter's parent sequence: '" ~
                  adapter.parent_sequence.get_full_name() ~
                  "' (of type '" ~
                  adapter.parent_sequence.get_type_name() ~
		  "')");
      if (seq is null)
      uvm_fatal("REG/CAST",
		"failed to cast: '" ~
		obj.get_full_name() ~
		"' (of type '" ~
		obj.get_type_name() ~
		"') to uvm_sequence_base!");
      
      seq.set_parent_sequence(rw.get_parent_sequence());
      rw.set_parent_sequence(seq);
      tmp_parent_seq = seq;
    }

    if (rw.get_parent_sequence() is null) {
      uvm_reg_seq_base parent_proxy =
	new uvm_reg_seq_base("default_parent_seq");
      rw.set_parent_sequence(parent_proxy);
      tmp_parent_seq = parent_proxy;
    }

    if (adapter is null) {
      uvm_event_pool ep = rw.get_event_pool();
      uvm_event!(uvm_object) end_event = ep.get("end") ;
      rw.set_sequencer(sequencer);
      tmp_parent_seq = rw.get_parent_sequence();
      tmp_parent_seq.start_item(rw,rw.get_priority());
      tmp_parent_seq.finish_item(rw);
      end_event.wait_on();
    }
    else {
      do_bus_write(rw, sequencer, adapter);
    }

    if (tmp_parent_seq !is null) {
      sequencer.m_sequence_exiting(tmp_parent_seq);
    }
  }

  // Task -- NODOCS -- do_read
  //
  // Perform a read operation.
  //
  // task
  public void do_read(uvm_reg_item rw) {

    uvm_sequence_base tmp_parent_seq;
    uvm_reg_map system_map = get_root_map();
    uvm_reg_adapter adapter = system_map.get_adapter();
    uvm_sequencer_base sequencer = system_map.get_sequencer();

    if (adapter !is null && adapter.parent_sequence !is null) {
      uvm_object obj = adapter.parent_sequence.clone();
      auto seq = cast (uvm_sequence_base) obj;
      if (obj is null)
	uvm_fatal("REG/CLONE",
		  "failed to clone adapter's parent sequence: '" ~
                  adapter.parent_sequence.get_full_name() ~
                  "' (of type '" ~
                  adapter.parent_sequence.get_type_name() ~
		  "')");
      if (seq is null)
	uvm_fatal("REG/CAST",
		  "failed to cast: '" ~
		  obj.get_full_name() ~
		  "' (of type '" ~
		  obj.get_type_name() ~
		  "') to uvm_sequence_base!");
      seq.set_parent_sequence(rw.get_parent_sequence());
      rw.set_parent_sequence(seq);
      tmp_parent_seq = seq;
    }

    if (rw.get_parent_sequence() is null) {
      uvm_reg_seq_base parent_proxy =
	new uvm_reg_seq_base("default_parent_seq");
      rw.set_parent_sequence(parent_proxy);
      tmp_parent_seq = parent_proxy;
    }

    if (adapter is null) {
      uvm_event_pool ep = rw.get_event_pool();
      uvm_event!(uvm_object) end_event = ep.get("end") ;
      rw.set_sequencer(sequencer);
      tmp_parent_seq = rw.get_parent_sequence();
      tmp_parent_seq.start_item(rw,rw.get_priority());
      tmp_parent_seq.finish_item(rw);
      end_event.wait_on();
    }
    else {
      do_bus_read(rw, sequencer, adapter);
    }

    if (tmp_parent_seq !is null) {
      sequencer.m_sequence_exiting(tmp_parent_seq);
    }
  } // endtask


  public void Xget_bus_infoX(uvm_reg_item rw,
			     out uvm_reg_map_info map_info,
			     out int size,
			     out int lsb,
			     out int addr_skip) {

    if (rw.get_element_kind() == uvm_elem_kind_e.UVM_MEM) {
      uvm_mem mem = cast (uvm_mem) rw.get_element();
      if (rw.get_element() is null || mem is null) {
	uvm_fatal("REG/CAST", "uvm_reg_item 'element_kind' is UVM_MEM, " ~ 
		  "but 'element' does not point to a memory: " ~ rw.get_name());
      }
      map_info = get_mem_map_info(mem);
      size = mem.get_n_bits();
    }
    else if (rw.get_element_kind() == uvm_elem_kind_e.UVM_REG) {
      auto rg = cast (uvm_reg) rw.get_element();
      if (rw.get_element() is null || rg is null) {
	uvm_fatal("REG/CAST", "uvm_reg_item 'element_kind' is UVM_REG, " ~ 
		  "but 'element' does not point to a register: " ~ rw.get_name());
      }
      map_info = get_reg_map_info(rg);
      size = rg.get_n_bits();
    }
    else if (rw.get_element_kind() == uvm_elem_kind_e.UVM_FIELD) {
      auto field = cast (uvm_reg_field) rw.get_element();
      if (rw.get_element() is null || field is null) {
	uvm_fatal("REG/CAST", "uvm_reg_item 'element_kind' is UVM_FIELD, " ~ 
		  "but 'element' does not point to a field: " ~ rw.get_name());
      }
      map_info = get_reg_map_info(field.get_parent());
      size = field.get_n_bits();
      lsb = field.get_lsb_pos();
      addr_skip = lsb/(get_n_bytes()*8);
    }
  }


  override string convert2string() {
    synchronized(this) {
      uvm_reg[]  regs;
      uvm_vreg[] vregs;
      uvm_mem[]  mems;
      uvm_endianness_e endian;
      string prefix;

      string result = format("%sMap %s", prefix, get_full_name());
      endian = get_endian(uvm_hier_e.UVM_NO_HIER);
      result ~= format(" -- %0d bytes (%s)", 
		       get_n_bytes(uvm_hier_e.UVM_NO_HIER), endian);
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
  }

  override uvm_object clone() {
    uvm_fatal("UVM/REGMAP/NOCLONE", "uvm_reg_map doesnt support clone()");
    return null;
  }


  override void do_print (uvm_printer printer) {
    synchronized(this) {
      uvm_reg[]          regs;
      uvm_vreg[]         vregs;
      uvm_mem[]          mems;
      uvm_reg_map[]      maps;
      string             prefix;
      uvm_sequencer_base sqr = get_sequencer();
  
      super.do_print(printer);
      uvm_endianness_e endian = get_endian(uvm_hier_e.UVM_NO_HIER);
      printer.print("endian", endian); 
    
      printer.print("n_bytes", get_n_bytes(uvm_hier_e.UVM_NO_HIER),
		    uvm_radix_enum.UVM_DEC);
      printer.print("byte addressing", get_addr_unit_bytes()==1 ,
		    uvm_radix_enum.UVM_DEC);

      if (sqr !is null) {
	printer.print_generic("effective sequencer",
			      sqr.get_type_name(), -2, sqr.get_full_name());
      }
             
      get_registers(regs, uvm_hier_e.UVM_NO_HIER);
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
  }

  override void do_copy (uvm_object rhs) {
    //uvm_reg_map rhs_;
    //assert ($cast(rhs_,rhs));

    //rhs_.regs = regs;
    //rhs_.mems = mems;
    //rhs_.vregs = vregs;
    //rhs_.blks = blks;
    //... and so on
  }

  // @uvm-ieee 1800.2-2020 auto 18.2.5.5
  void set_transaction_order_policy(uvm_reg_transaction_order_policy pol) {
    synchronized (this) {
      _policy = pol;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 18.2.5.4
  uvm_reg_transaction_order_policy get_transaction_order_policy() {
    synchronized (this) {
      return _policy;
    }
  }
   
  // ceil() function
  private uint ceil(uint a, uint b) {
    uint r = a / b;
    uint r0 = a % b;
    return r0 ? (r+1) : r;
  }
  
  private ulong ceil(ulong a, ulong b) {
    ulong r = a / b;
    ulong r0 = a % b;
    return r0 ? (r+1) : r;
  }
  
  /*
   * translates an access from the current map ~this~ to an address ~base_addr~ (within the current map) with a 
   * length of ~n_bytes~ into an access from map ~parent_map~. 
   * if ~mem~ and ~mem_offset~ are supplied then a memory access is assumed 
   * results: ~addr~ contains the set of addresses and ~byte_offset~ holds the number of bytes the data stream needs to be shifted 
   * 
   * this implementation assumes a packed data access
   */ 
  int get_physical_addresses_to_map(uvm_reg_addr_t base_addr,
				    uvm_reg_addr_t mem_offset,
				    ulong n_bytes,  // number of bytes
				    ref uvm_reg_addr_t[] addr, // array of addresses
				    uvm_reg_map parent_map, // translate till parent_map is the parent of the actual map or NULL if this is a root_map
				    ref uint byte_offset,
				    uvm_mem mem =null
				    ) {
      synchronized (this) {
	int bus_width = get_n_bytes(uvm_hier_e.UVM_NO_HIER);
	uvm_reg_addr_t[]  local_addr;

	//	`uvm_info("RegModel",$sformatf("this=%p enter base=0x%0x mem_offset=0x%0d request=%0dbytes byte_enable=%0d byte-offset=%0d",
	//		this,base_addr,mem_offset,n_bytes,m_byte_addressing,byte_offset),UVM_HIGH)

	//	`uvm_info("RegModel",$sformatf("addressUnitBits=%0d busWidthBits=%0d",get_addr_unit_bytes()*8,bus_width*8),UVM_HIGH)

	uvm_reg_map up_map = get_parent_map();
	uvm_reg_addr_t lbase_addr = up_map is null ?
	  get_base_addr(uvm_hier_e.UVM_NO_HIER): up_map.get_submap_offset(this);
	// `uvm_info("RegModel",$sformatf("lbase =0x%0x",lbase_addr),UVM_HIGH)

	if (up_map != parent_map) {
	  uvm_reg_addr_t lb;
	  // now just translate first address and request same number of bytes
	  // may need to adjust addr,n_bytes if base_addr*AUB is not a multiple of upmap.AUB
	  // addr=5,aub=8 and up.aub=16 and n_bytes=1 which is translated addr=2,n_bytes=2
	  uvm_reg_addr_t laddr;
	  // begin
	  // adjust base_addr to find the base of memword(mem_offset)
	  if (mem_offset) {
	    base_addr += mem_offset*mem.get_n_bytes()/get_addr_unit_bytes();
	  }
	  laddr = lbase_addr + base_addr*get_addr_unit_bytes()/up_map.get_addr_unit_bytes(); // start address in terms of the upper map
	  lb = (base_addr*get_addr_unit_bytes()) % up_map.get_addr_unit_bytes(); // potential byte offset on top of the start address in the upper map
	  byte_offset += lb; // accumulate!
	  // end	
	  return up_map.get_physical_addresses_to_map(laddr, 0, (n_bytes+lb),
						      addr, parent_map, byte_offset);
	}
	else {
	  uvm_reg_addr_t lbase_addr2;
	  // first need to compute set of addresses
	  // each address is for one full bus width (the last beat may have less bytes to transfer)
	  local_addr.length = ceil(n_bytes,bus_width);

	  lbase_addr2 = base_addr;
	  if (mem_offset) {
	    if (mem !is null &&	(mem.get_n_bytes() >= get_addr_unit_bytes())) { // packed model
	      lbase_addr2 = base_addr + mem_offset*mem.get_n_bytes()/get_addr_unit_bytes();
	      byte_offset += (mem_offset*mem.get_n_bytes() % get_addr_unit_bytes());
	    }
	    else {
	      lbase_addr2 = base_addr + mem_offset;
	    }
	  }
	  //			`uvm_info("UVM/REG/ADDR",$sformatf("gen addrs map-aub(bytes)=%0d addrs=%0d map-bus-width(bytes)=%0d lbase_addr2=%0x",
	  //				get_addr_unit_bytes(),local_addr.size(),bus_width,lbase_addr2),UVM_DEBUG)

	  switch (get_endian(uvm_hier_e.UVM_NO_HIER)) {
	  case uvm_endianness_e.UVM_LITTLE_ENDIAN:
	    foreach (i, ref laddr; local_addr) {
	      laddr = lbase_addr2 + i*bus_width/get_addr_unit_bytes();
	    }
	    break;
	  case uvm_endianness_e.UVM_BIG_ENDIAN:
	    foreach (i, ref laddr; local_addr) {
	      laddr = lbase_addr2 + (local_addr.length-1-i) * bus_width/get_addr_unit_bytes() ;
	    }
	    break;
	  case uvm_endianness_e.UVM_LITTLE_FIFO:
	    foreach (ref laddr; local_addr) {
	      laddr = lbase_addr2;
	    }
	    break;
	  case uvm_endianness_e.UVM_BIG_FIFO:
	    foreach (ref laddr; local_addr) {
	      laddr = lbase_addr2;
	    }
	    break;
	  default:
	    uvm_error("UVM/REG/MAPNOENDIANESS",
		      "Map has no specified endianness. " ~
		      format("Cannot access %0d bytes register via its %0d byte \"%s\" interface",
			     n_bytes, bus_width, get_full_name()));
	  }

	  // foreach(local_addr[idx])
	  //   `uvm_info("UVM/REG/ADDR",$sformatf("local_addr idx=%0d addr=%0x",idx,local_addr[idx]),UVM_DEBUG)

	  // now need to scale in terms of upper map

	  addr = local_addr.dup;

	  foreach (ref a; addr)
	    a += lbase_addr;
			
	  // foreach(addr[idx])
	  //   `uvm_info("UVM/REG/ADDR",$sformatf("top %0x:",addr[idx]),UVM_DEBUG)
			
	}
	return 0;
      }
    }
  
  // performs all bus operations ~accesses~ generated from ~rw~ via adapter ~adapter~ on sequencer ~sequencer~
  // task
  void perform_accesses(ref uvm_reg_bus_op[] accesses,
			uvm_reg_item rw,
			uvm_reg_adapter adapter,
			uvm_sequencer_base sequencer) {
	
    string op = (rw.get_kind().inside(UVM_READ, UVM_BURST_READ)) ? "Read" : "Wrote";
    uvm_endianness_e endian = get_endian(uvm_hier_e.UVM_NO_HIER);
  
    // if set utilize the order policy
    if (policy !is null)
      policy.order(accesses);
    
    // perform accesses
    foreach (i, ref access; accesses) {
      uvm_reg_bus_op rw_access = access;  
      uvm_sequence_item bus_req;

      if ((rw_access.kind == uvm_access_e.UVM_WRITE) &&
	  (endian == uvm_endianness_e.UVM_BIG_ENDIAN)) {
	rw_access.data = rw_access.data.swapEndian();
      }
          
      adapter.m_set_item(rw);
      bus_req = adapter.reg2bus(rw_access);
      adapter.m_set_item(null);
      
      if (bus_req is null)
        uvm_fatal("RegMem", "adapter [" ~ adapter.get_name() ~
		  "] didnt return a bus transaction");
      bus_req.set_sequencer(sequencer);
      uvm_sequence_base rw_parent_seq = rw.get_parent_sequence();
      rw_parent_seq.start_item(bus_req, rw.get_priority());
      if (rw_parent_seq !is null && i == 0)
        rw_parent_seq.mid_do(rw);

      rw_parent_seq.finish_item(bus_req);

      // {
      uvm_event_pool ep = bus_req.get_event_pool();
      uvm_event!(uvm_object) end_event = ep.get("end") ;
      end_event.wait_on();
      // }

      if (adapter.provides_responses) {
        uvm_sequence_item bus_rsp;
        // uvm_access_e op;
        // TODO: need to test for right trans type, if not put back in q
        rw_parent_seq.get_base_response(bus_rsp, bus_req.get_transaction_id());
        adapter.bus2reg(bus_rsp, rw_access);
      }
      else {
        adapter.bus2reg(bus_req, rw_access);
      }

      if ((rw_access.kind == uvm_access_e.UVM_READ)
	  && (endian == uvm_endianness_e.UVM_BIG_ENDIAN)) {
	rw_access.data = rw_access.data.swapEndian();
      }

      rw.set_status(rw_access.status);

      // begin
      uvm_reg_data_t mask = 1;
      mask <<= get_n_bytes()*8;
      mask -= 1;
      
      uvm_reg_data_logic_t data = rw_access.data & mask; // mask the upper bits
      
      if (rw.get_kind().inside(UVM_READ, UVM_BURST_READ))
      	if (rw.get_status() == uvm_status_e.UVM_IS_OK && data.isX())
	  rw.set_status(uvm_status_e.UVM_HAS_X);
      	
      rw_access.data = cast(uvm_reg_data_t) data;    	
      // end	

      uvm_reg_map rw_map = rw.get_map();
      uvm_status_e rw_status = rw.get_status();

      uvm_info("UVM/REG/ADDR",
         format("%s 'h%0h at 'h%0h via map \"%s\": %s...", op,
		rw_access.data, rw_access.addr, rw_map.get_full_name(),
		rw_status// .name()
		), uvm_verbosity.UVM_FULL);

      if (rw.get_status() == uvm_status_e.UVM_NOT_OK)
	break;
      rw_parent_seq = rw.get_parent_sequence();  
        
      if (rw_parent_seq !is null && i == accesses.length-1)
        rw_parent_seq.post_do(rw);
        
      access = rw_access;
    }
  }

  // performs all necessary bus accesses defined by ~rw~ on the sequencer ~sequencer~ utilizing the adapter ~adapter~
  // task
  void do_bus_access(uvm_reg_item rw,
		     uvm_sequencer_base sequencer,
		     uvm_reg_adapter adapter) {
    uint bus_width  = get_n_bytes();
    uvm_reg_map_info   map_info;
    int                n_bits;
    int                lsb;
    int                skip;
    uvm_reg_bus_op[]   accesses;
    //	int n_bits_init;
    uvm_reg_addr_t[]   adr;
    uint byte_offset;
    ulong num_stream_bytes;
    uint n_bytes;
    uint bytes_per_value;
    uint bit_shift;
    uint extra_byte;
	
    Xget_bus_infoX(rw, map_info, n_bits, lsb, skip);

    uvm_reg_addr_t[] addrs = map_info.addr;
    string op = (rw.get_kind().inside(UVM_READ, UVM_BURST_READ)) ? "Reading" : "Writing";

    final switch (rw.get_element_kind()) {
    case uvm_elem_kind_e.UVM_MEM:
      uvm_mem mem = cast (uvm_mem) rw.get_element();
      assert (mem !is null);
      get_physical_addresses_to_map(m_mems_info[mem].offset, rw.get_offset(),
				    cast(uint) (rw.get_value_size()*mem.get_n_bytes()),
				    adr, null, byte_offset, mem);
      num_stream_bytes = rw.get_value_size*mem.get_n_bytes();
      n_bytes = mem.get_n_bytes();
      bytes_per_value = mem.get_n_bytes();
      break;
    case uvm_elem_kind_e.UVM_FIELD:
      uvm_reg_addr_t ad;
      uvm_reg_field f = cast (uvm_reg_field) rw.get_element();
      assert (f !is null);
      // adjust adr bit skipped bytes; still need to shift data by byte fractions (lsb)
      get_physical_addresses_to_map(m_regs_info[f.get_parent()].offset+skip,
				    0, ceil(f.get_n_bits(), 8),
				    adr, null, byte_offset);
      num_stream_bytes = ceil(f.get_n_bits(), 8);
      n_bytes = get_n_bytes(uvm_hier_e.UVM_NO_HIER);	
      bytes_per_value = ceil(f.get_n_bits(), 8);
      bit_shift = lsb % (get_n_bytes()*8);
      if (bit_shift+f.get_n_bits() / 8 !=  f.get_n_bits() /8)
	extra_byte = 1;
      // `uvm_info("UVM/REG/ADDR",$sformatf("need to byte skip %0d and bit shift %0d",skip,bit_shift),UVM_DEBUG)
      break;
    case uvm_elem_kind_e.UVM_REG:
      uvm_reg_addr_t ad;
      uvm_reg r = cast (uvm_reg) rw.get_element();
      assert (r !is null);
      get_physical_addresses_to_map(m_regs_info[r].offset,
				    0, r.get_n_bytes(),
				    adr ,null, byte_offset);
      num_stream_bytes = r.get_n_bytes();
      n_bytes = get_n_bytes(uvm_hier_e.UVM_NO_HIER);
      bytes_per_value = r.get_n_bytes();
    }

    bool[] be;
    ubyte[] p;

    // adjust bytes if there is a leading bit shift
    num_stream_bytes += extra_byte;

    for (size_t i=0; i!=byte_offset; ++i) be ~= false;
    for (size_t i=0; i!=num_stream_bytes; ++i) be ~= true;
    for (size_t i=0; i!=bus_width; ++i) be ~= false;

    // now shift data to match the alignment
    for (size_t i = 0; i != byte_offset; ++i) p ~= 0;
    foreach (val; rw.get_value()) {
      for (int i=0; i<bytes_per_value; i++) {
	p ~= val.getByte(i);
      }
    }

    // retain this from version 2017-1.0 -- the later versions use bit streaming operator
    if (bit_shift) {
      uvm_reg_data_t ac = 0;
      foreach(byt; p) {
	uvm_reg_data_t n;
	n = (ac | (byt << bit_shift)) & 0xff;
	ac = (byt >> bit_shift) & 0xff;
	byt = cast(ubyte) n;
      }
      if (extra_byte)
	p ~= cast(ubyte) ac;
    }

    /*
      if (uvm_report_enabled(UVM_NONE, UVM_INFO, "UVM/REG/ADDR")) begin
      `uvm_info("UVM/REG/ADDR", $sformatf("bit_shift = %0d", bit_shift), UVM_NONE)
      foreach(be[idx])
      `uvm_info("UVM/REG/ADDR",$sformatf("idx %0d en=%0d",idx,be[idx]),UVM_NONE)

      foreach(adr[idx])
      `uvm_info("UVM/REG/ADDR",$sformatf("mem-adr %0x byte-offset=%0d",adr[idx],byte_offset),UVM_NONE)
      foreach(values[idx])
      `uvm_info("UVM/REG/ADDR", $sformatf("idx %0d mem-val=%0x", idx, values[idx]), UVM_NONE)

      foreach(p[idx])
      `uvm_info("UVM/REG/ADDR",$sformatf("idx %0d data=%x enable=%0d",idx,p[idx],be[idx]),UVM_NONE)
		
      foreach(rw.value[idx])
      `uvm_info("UVM/REG/ADDR",$sformatf("original idx=%0d %0x",idx,rw.value[idx]),UVM_NONE)
		
      end
    */
		
    // transform into accesses per address
    accesses.length = 0;
    foreach (i, ad; adr) {
      uvm_reg_bus_op rw_access;
      uvm_reg_data_t data;
      uvm_reg_map tmp_map = rw.get_map();
      

      for (int i0=0; i0 < bus_width; i0++)
	data.setByte(i0, p[i*bus_width+i0]);

      uvm_info("UVM/REG/ADDR",
	       format("%s 'h%0h at 'h%0h via map \"%s\"...",op,
		      data, adr[i], tmp_map.get_full_name()),
	       uvm_verbosity.UVM_FULL);

      for (int z=0; z<bus_width; z++)
	rw_access.byte_en[z] = be[bus_width*i+z];

      rw_access.kind    = rw.get_kind();
      rw_access.addr    = ad;
      rw_access.data    = data;
			
      rw_access.n_bits = 8*bus_width;
      for (int ii=bus_width-1; ii>=0; ii--) {
	if (rw_access.byte_en[ii] == 0)
	  rw_access.n_bits -= 8;
	else
	  break;
      }

      accesses ~= rw_access;
    }
		
    perform_accesses(accesses, rw, adapter, sequencer);

    // for reads copy back to rw.value
    if(rw.get_kind().inside(UVM_READ, UVM_BURST_READ)) {
      p.length = 0;

      foreach (access; accesses) {
	uvm_reg_data_t data = access.data;
	for (int i1=0; i1<bus_width; i1++)
	  p ~= data.getByte(i1);
      }

      // repeat(byte_offset) void'(p.pop_front());
      p = p[byte_offset..$];
      size_t rw_value_size = rw.get_value_size();
      for(int i = 0; i < rw_value_size; i++) {
	rw.set_value(uvm_reg_data_t(0), i);
      }

      if (bit_shift) {
	uvm_reg_data_t ac = 0;
	for (int i=0; i<p.length; i++) {
	  byte nv = cast(byte) (p[i] >> bit_shift);
	  if (i != p.length-1)
	    nv |= cast(byte) (p[i+1] << bit_shift);
	  p[i] = nv;
	}
	if (extra_byte)
	  p.length -= 1;
      }

      rw_value_size = rw.get_value_size();
      for(int idx = 0; idx < rw_value_size; idx++) {
	uvm_reg_data_t rw_value = rw.get_value(idx);
	for (int i0=0; i0<bytes_per_value; i0++)
	  rw_value.setByte(i0, p[idx*bytes_per_value+i0]);
	rw.set_value(rw_value, idx);
      }
      
      if (rw.get_element_kind() == uvm_elem_kind_e.UVM_FIELD) {

	uvm_reg_field f = cast(uvm_reg_field) rw.get_element();
						
	uvm_reg_data_t m = 1;
	m <<= f.get_n_bits();
	m -= 1;

	rw_value_size = rw.get_value_size();
	for (int idx = 0; idx < rw_value_size; idx++) {
	  uvm_reg_data_t rw_value = rw.get_value(idx);
	  rw_value &= m;
	  rw.set_value(rw_value, idx);
	}
      }

      /*
	if (uvm_report_enabled(UVM_DEBUG, UVM_INFO, "UVM/REG/ADDR")) 
	foreach(rw.value[idx])
	`	uvm_info("UVM/REG/ADDR",$sformatf("read return idx=%0d %0x",idx,rw.value[idx]),UVM_DEBUG)
      */
			        
    }
  }
  
  // unregisters all content from this map recursively
  // it is NOT expected that this leads to a fresh new map 
  // it rather removes all knowledge of this map from other objects 
  // so that they can be reused with a fresh map instance
  // @uvm-ieee 1800.2-2020 auto 18.2.3.11
  void unregister() {
    synchronized (this) {
      uvm_reg_block[] q;
      uvm_reg_block.get_root_blocks(q);
		
      foreach (block; q)
	block.set_lock(0);
		
      foreach (block; q)
	block.unregister(this);
		
      foreach (map_, submap; _m_submaps)
	map_.unregister();
    
      _m_submaps.clear();
      _m_submap_rights.clear();


      foreach (reg_by_offset; _m_regs_by_offset)
	reg_by_offset.unregister(this);
		
      _m_regs_by_offset.clear();
      _m_regs_by_offset_wo.clear();
      _m_mems_by_offset.clear();

      _m_regs_info.clear();
      _m_mems_info.clear();
			
      _m_parent_map = null;
    }
  }

  uvm_reg_map clone_and_update(string rights) {
    synchronized (this) {
      if (_m_parent_map !is null)
	uvm_error("UVM/REG/CLONEMAPWITHPARENT",
		  "cannot clone a map which already has a parent");
      if (_m_submaps.length != 0)
	uvm_error("UVM/REG/CLONEMAPWITHCHILDREN",
		  "cannot clone a map which already has children");
		
      uvm_reg_map m;
      uvm_reg_block b = get_parent();
			
      m = b.create_map(get_name(), 0 , _m_n_bytes,
		       _m_endian, _m_byte_addressing);
			
      foreach(rg; _m_regs_by_offset) {
	uvm_reg_map_info info = get_reg_map_info(rg);
	m.add_reg(rg, info.offset, rights, info.unmapped, info.frontdoor);
      }
      foreach(rg; m_mems_by_offset) {
	uvm_reg_map_info info = get_mem_map_info(rg);
	m.add_mem(rg, info.offset, rights, info.unmapped, info.frontdoor);
      }
      return m;
    }
  }
}
