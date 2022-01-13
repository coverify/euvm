// 
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2004-2010 Synopsys, Inc.
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


//------------------------------------------------------------------------------
// Title -- NODOCS -- Memory Walking-Ones Test Sequences
//
// This section defines sequences for applying a "walking-ones"
// algorithm on one or more memories.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_mem_single_walk_seq
//
// Runs the walking-ones algorithm on the memory given by the <mem> property,
// which must be assigned prior to starting this sequence.
//
// If bit-type resource named
// "NO_REG_TESTS", "NO_MEM_TESTS", or "NO_MEM_WALK_TEST"
// in the "REG::" namespace
// matches the full name of the memory,
// the memory is not tested.
//
//| uvm_resource_db#(bit)::set({"REG::",regmodel.blk.mem0.get_full_name()},
//|                            "NO_MEM_TESTS", 1, this);
//
// The walking ones algorithm is performed for each map in which the memory
// is defined.
//
//| for (k = 0 thru memsize-1)
//|   write addr=k data=~k
//|   if (k > 0) {
//|     read addr=k-1, expect data=~(k-1)
//|     write addr=k-1 data=k-1
//|   if (k == last addr)
//|     read addr=k, expect data=~k
//
//------------------------------------------------------------------------------

module uvm.reg.sequences.uvm_mem_walk_seq;

import uvm.reg.uvm_reg_sequence: uvm_reg_sequence;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_model: uvm_hier_e, uvm_door_e, uvm_status_e, uvm_reg_data_t;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;

import esdl;
import std.string: format;


// @uvm-ieee 1800.2-2020 auto E.6.1.1
class uvm_mem_single_walk_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{
  mixin uvm_object_utils;


  // Variable -- NODOCS -- mem
  //
  // The memory to test; must be assigned prior to starting sequence.

  uvm_mem mem;


  // Function -- NODOCS -- new
  //
  // Creates a new instance of the class with the given name.

  // @uvm-ieee 1800.2-2020 auto E.6.1.3.1
  public this(string name="uvm_mem_walk_seq") {
    super(name);
  }


  // Task -- NODOCS -- body
  //
  // Performs the walking-ones algorithm on each map of the memory
  // specifed in <mem>.

  // @uvm-ieee 1800.2-2020 auto E.6.1.3.2
  // task
  override public void body() {
    uvm_reg_map[] maps;

    if (mem is null) {
      uvm_error("uvm_mem_walk_seq", "No memory specified to run sequence on");
      return;
    }

    // Memories with some attributes are not to be tested
    if (uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					 "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					 "NO_MEM_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					 "NO_MEM_WALK_TEST", 0) !is null) {
      return;
    }

    int n_bits = mem.get_n_bits();

    // Memories may be accessible from multiple physical interfaces (maps)
    mem.get_maps(maps);
      
    // Walk the memory via each map
    foreach (map; maps) {
      uvm_status_e status;
      uvm_reg_data_t  val, exp, v;
      uvm_reg_data_t mask = 1;
      mask = (mask << n_bits) - 1;

      // Only deal with RW memories
      if (mem.get_access(map) != "RW") continue;

      uvm_info("uvm_mem_walk_seq",
	       format("Walking memory %s in map \"%s\"...",
		      mem.get_full_name(), map.get_full_name()), uvm_verbosity.UVM_LOW);
         
      // The walking process is, for address k:
      // - Write ~k
      // - Read k-1 and expect ~(k-1) if k > 0
      // - Write k-1 at k-1
      // - Read k and expect ~k if k == last address
      for (int k = 0; k < mem.get_size(); k++) {
	mem.write(status, k, cast(uvm_reg_data_t) ~k, uvm_door_e.UVM_FRONTDOOR, map, this);

	if (status != uvm_status_e.UVM_IS_OK) {
	  uvm_error("uvm_mem_walk_seq",
		    format("Status was %s when writing \"%s[%0d]\" through map \"%s\".",
			   status, mem.get_full_name(), k, map.get_full_name()));
	}
            
	if (k > 0) {
	  mem.read(status, k-1, val, uvm_door_e.UVM_FRONTDOOR, map, this);
	  if (status != uvm_status_e.UVM_IS_OK) {
	    uvm_error("uvm_mem_walk_seq",
		      format("Status was %s when reading \"%s[%0d]\" through map \"%s\".",
			     status, mem.get_full_name(), k, map.get_full_name()));
	  }
	  else {
	    uvm_reg_data_t kk = k - 1;
	    exp = ~kk & mask;
	    if (val != exp) {
	      uvm_error("uvm_mem_walk_seq",
			format("\"%s[%0d-1]\" read back as 'h%h" ~
			       " instead of 'h%h.",
			       mem.get_full_name(), k, val, exp));
                     
	    }
	  }
               
	  mem.write(status, k-1, cast(uvm_reg_data_t) (k-1), uvm_door_e.UVM_FRONTDOOR, map, this);
	  if (status != uvm_status_e.UVM_IS_OK) {
	    uvm_error("uvm_mem_walk_seq",
		      format("Status was %s when writing \"%s[%0d-1]\" through map \"%s\".",
			     status, mem.get_full_name(), k, map.get_full_name()));
	  }
	}
            
	if (k == mem.get_size() - 1) {
	  mem.read(status, k, val, uvm_door_e.UVM_FRONTDOOR, map, this);
	  if (status != uvm_status_e.UVM_IS_OK) {
	    uvm_error("uvm_mem_walk_seq",
		      format("Status was %s when reading \"%s[%0d]\" through map \"%s\".",
			     status, mem.get_full_name(), k, map.get_full_name()));
	  }
	  else {
	    uvm_reg_data_t kk = k;
	    exp = ~kk & mask;
	    if (val !is exp) {
	      uvm_error("uvm_mem_walk_seq",
			format("\"%s[%0d]\" read back as 'h%h instead of 'h%h.",
			       mem.get_full_name(), k, val, exp));
	    }
	  }
	}
      }
    }
  }
}



//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_mem_walk_seq
//
// Verifies the all memories in a block
// by executing the <uvm_mem_single_walk_seq> sequence on
// every memory within it.
//
// If bit-type resource named
// "NO_REG_TESTS", "NO_MEM_TESTS", or "NO_MEM_WALK_TEST"
// in the "REG::" namespace
// matches the full name of the block,
// the block is not tested.
//
//| uvm_resource_db!(bool).set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_MEM_TESTS", 1, this);
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto E.6.2.1
class uvm_mem_walk_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // Variable -- NODOCS -- model
  //
  // The block to be tested. Declared in the base class.
  //
  //| uvm_reg_block model; 


  // Variable -- NODOCS -- mem_seq
  //
  // The sequence used to test one memory
  //
  protected uvm_mem_single_walk_seq mem_seq;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2020 auto E.6.3.1
  public this(string name="uvm_mem_walk_seq") {
    super(name);
  }


  // Task -- NODOCS -- body
  //
  // Executes the mem walk sequence, one block at a time.
  // Do not call directly. Use seq.start() instead.
  //

  // @uvm-ieee 1800.2-2020 auto E.6.3.2
  // task
  override public void body() {
    if (model is null) {
      uvm_error("uvm_mem_walk_seq", "No register model specified to run sequence on");
      return;
    }

    uvm_report_info("STARTING_SEQ","\n\nStarting " ~
		    get_name() ~ " sequence...\n", uvm_verbosity.UVM_LOW);

    mem_seq = uvm_mem_single_walk_seq.type_id.create("single_mem_walk_seq");

    this.reset_blk(model);
    model.reset();
    
    do_block(model);
  }


  // Task -- NODOCS -- do_block
  //
  // Test all of the memories in a given ~block~
  //
  // task
  public void do_block(uvm_reg_block blk) {
    uvm_mem[] mems;
      
    if (uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_MEM_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_MEM_ACCESS_TEST", 0) !is null )
      return;
      
    // Iterate over all memories, checking accesses
    blk.get_memories(mems, uvm_hier_e.UVM_NO_HIER);
    foreach (mem; mems) {
      // Memories with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_WALK_TEST", 0) !is null)
	continue;
         
      mem_seq.mem = mem;
      mem_seq.start(null, this);
    }

    uvm_reg_block[] blks;
         
    blk.get_blocks(blks);
    foreach (blk_; blks) {
      do_block(blk_);
    }
  }


  // Task -- NODOCS -- reset_blk
  //
  // Reset the DUT that corresponds to the specified block abstraction class.
  //
  // Currently empty.
  // Will rollback the environment's phase to the ~reset~
  // phase once the new phasing is available.
  //
  // In the meantime, the DUT should be reset before executing this
  // test sequence or this method should be implemented
  // in an extension to reset the DUT.
  //
  // task
  public void reset_blk(uvm_reg_block blk) {}
}
