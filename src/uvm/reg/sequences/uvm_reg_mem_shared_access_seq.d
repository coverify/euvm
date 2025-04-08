// 
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
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
// Title -- NODOCS -- Shared Register and Memory Access Test Sequences
//------------------------------------------------------------------------------
// This section defines sequences for testing registers and memories that are
// shared between two or more physical interfaces, i.e. are associated with
// more than one <uvm_reg_map> instance.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_shared_access_seq
//
// Verify the accessibility of a shared register
// by writing through each address map
// then reading it via every other address maps
// in which the register is readable and the backdoor,
// making sure that the resulting value matches the mirrored value.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_SHARED_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the register,
// the register is not tested.
//
//| uvm_resource_db#(bit)::set({"REG::",regmodel.blk.r0.get_full_name()},
//|                            "NO_REG_TESTS", 1, this);
//
// Registers that contain fields with unknown access policies
// cannot be tested.
//
// The DUT should be idle and not modify any register during this test.
//
//------------------------------------------------------------------------------

module uvm.reg.sequences.uvm_reg_mem_shared_access_seq;

import uvm.reg.uvm_reg_sequence: uvm_reg_sequence;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_model: uvm_hier_e, uvm_door_e, uvm_status_e, uvm_reg_data_t,
  uvm_check_e;


import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;
import uvm.reg.sequences.uvm_reg_randval;
import uvm.reg.uvm_reg_defines: UVM_REG_DATA_WIDTH, UVM_REG_DATA_1;

import esdl;
import std.string: format;

// @uvm-ieee 1800.2-2020 auto E.4.1.1
class uvm_reg_shared_access_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // Variable -- NODOCS -- rg
  // The register to be tested
  uvm_reg rg;
  @rand uvm_reg_randval rand_reg_val;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2020 auto E.4.1.3
  public this(string name="uvm_reg_shared_access_seq") {
    super(name);
    rand_reg_val = new uvm_reg_randval();
  }


  // task
  override public void body() {
      uvm_reg_data_t[]  wo_mask;
      uvm_reg_field[] fields;
      uvm_reg_map[] maps;

      if (rg is null) {
	uvm_error("uvm_reg_shared_access_seq",
		  "No register specified to run sequence on");
	return;
      }

      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ rg.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ rg.get_full_name(),
					   "NO_REG_SHARED_ACCESS_TEST", 0) !is null )
	return;

      // Only look at shared registers
      if (rg.get_n_maps() < 2) return;
      rg.get_maps(maps);

      // Let's see what kind of bits we have...
      rg.get_fields(fields);

      // Identify unpredictable bits and the ones we shouldn't change
      uvm_reg_data_t other_mask = 0;
      foreach (field; fields) {
	int lsb = field.get_lsb_pos();
	int w = field.get_n_bits();
         
	if (! field.is_known_access(maps[0])) {
	  for (size_t count=0; count!=w; ++count) {
	    other_mask[lsb++] = 1;
	  }
	}
      }
      
      // WO bits will always readback as 0's but the mirror
      // with return what is supposed to have been written
      // so we cannot use the mirror-check function
      foreach (j, map; maps) {
	uvm_reg_data_t  wo = 0;
	foreach (field; fields) {
	  int lsb = field.get_lsb_pos();
	  int w = field.get_n_bits();
            
	  if (field.get_access(map) == "WO") {
	    for (size_t count=0; count!=wo; ++count) {
	      wo[lsb++] = 1;
	    }
	  }
	}
	wo_mask[j] = wo;
      }
      
      // Try to write through each map
      foreach (map; maps) {
	uvm_status_e status;
         
	// The mirror should contain the initial value
	uvm_reg_data_t prev = rg.get();
         
	// Write a random value, except in those "don't touch" fields
	rand_reg_val.randomize();
	uvm_reg_data_t v = (rand_reg_val.randval & ~other_mask) | (prev & other_mask);
         
	uvm_info("uvm_reg_shared_access_seq",
		 format("Writing register %s via map \"%s\"...",
			rg.get_full_name(), map.get_full_name), uvm_verbosity.UVM_LOW);
         
	uvm_info("uvm_reg_shared_access_seq",
		 format("Writing 0x%x over 0x%x", v, prev), uvm_verbosity.UVM_DEBUG);
         
	rg.write(status, v, uvm_door_e.UVM_FRONTDOOR, map, this);
	if (status != uvm_status_e.UVM_IS_OK) {
	  uvm_error("uvm_reg_shared_access_seq",
		    format("Status was %s when writing register \"%s\" through map \"%s\".",
			   status, rg.get_full_name(), map.get_full_name()));
	}
         
	foreach (k, map_; maps) {
	  uvm_reg_data_t  actual, exp;
            
	  uvm_info("uvm_reg_shared_access_seq", format("Reading register %s via map \"%s\"...",
			  rg.get_full_name(), map_.get_full_name()), uvm_verbosity.UVM_LOW);
            
	  // Was it what we expected?
	  exp = rg.get() & ~wo_mask[k];
            
	  rg.read(status, actual, uvm_door_e.UVM_FRONTDOOR, map_, this);
	  if (status != uvm_status_e.UVM_IS_OK) {
	    uvm_error("uvm_reg_shared_access_seq",
		      format("Status was %s when reading register \"%s\" through map \"%s\".",
			     status, rg.get_full_name(), map_.get_full_name()));
	  }
            
	  uvm_info("uvm_reg_shared_access_seq", format("Read 0x%x, expecting 0x%x",
			  actual, exp),uvm_verbosity.UVM_DEBUG);
            
	  if (actual != exp) {
	    uvm_error("uvm_reg_shared_access_seq",
		      format("Register \"%s\" through map \"%s\" is 0x%x instead of 0x%x after writing 0x%x via map \"%s\" over 0x%x.",
			     rg.get_full_name(), map_.get_full_name(), actual, exp, v, map_.get_full_name(), prev));
	  }
	}
      }
    }
}


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_mem_shared_access_seq
//------------------------------------------------------------------------------
//
// Verify the accessibility of a shared memory
// by writing through each address map
// then reading it via every other address maps
// in which the memory is readable and the backdoor,
// making sure that the resulting value matches the written value.
//
// If bit-type resource named
// "NO_REG_TESTS", "NO_MEM_TESTS",
// "NO_REG_SHARED_ACCESS_TEST" or "NO_MEM_SHARED_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the memory,
// the memory is not tested.
//
//| uvm_resource_db!bool.set({"REG::",regmodel.blk.mem0.get_full_name()},
//|                            "NO_MEM_TESTS", 1, this);
//
// The DUT should be idle and not modify the memory during this test.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto E.4.2.1
class uvm_mem_shared_access_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // variable -- NODOCS -- mem
  // The memory to be tested
  uvm_mem mem;
  @rand uvm_reg_randval rand_reg_val;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2020 auto E.4.2.3
  public this(string name="uvm_mem_shared_access_seq") {
    super(name);
    rand_reg_val = new uvm_reg_randval();
  }

  // task
  override public void body() {
      if (mem is null) {
	uvm_error("uvm_mem_shared_access_seq", "No memory specified to run sequence on");
	return;
      }

      // Memories with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_SHARED_ACCESS_TEST", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_SHARED_ACCESS_TEST", 0) !is null)
	return;

      // Only look at shared memories
      if (mem.get_n_maps() < 2) return;

      uvm_reg_map[] maps;
      mem.get_maps(maps);

      // We need at least a backdoor or a map that can read
      // the shared memory
      int read_from = -1;
      if (mem.get_backdoor() is null) {
	foreach (j, map; maps) {
	  string right;
	  right = mem.get_access(map);
	  if (right == "RW" ||
	      right == "RO") {
	    read_from = cast(uint) j;
	    break;
	  }
	}
	if (read_from < 0) {
	  uvm_warning("uvm_mem_shared_access_seq",
		      format("Memory \"%s\" cannot be read from any maps or backdoor. Shared access not verified.",
			     mem.get_full_name()));
	  return;
	}
      }
      
      // Try to write through each map
      foreach (map; maps) {
         
	uvm_info("uvm_mem_shared_access_seq",
		 format("Writing shared memory \"%s\" via map \"%s\".",
			mem.get_full_name(), map.get_full_name()), uvm_verbosity.UVM_LOW);
         
	// All addresses
	for (int offset = 0; offset < mem.get_size(); offset++) {
	  uvm_status_e status;
	  uvm_reg_data_t  prev, v;
            
	  // Read the initial value
	  if (mem.get_backdoor() !is null) {
	    mem.peek(status, offset, prev);
	    if (status != uvm_status_e.UVM_IS_OK) {
	      uvm_error("uvm_mem_shared_access_seq",
			format("Status was %s when reading initial value of \"%s\"[%0d] through backdoor.",
			       status, mem.get_full_name(), offset));
	    }
	  }
	  else {
	    mem.read(status, offset, prev, uvm_door_e.UVM_FRONTDOOR, maps[read_from], this);
	    if (status != uvm_status_e.UVM_IS_OK) {
	      uvm_error("uvm_mem_shared_access_seq",
			format("Status was %s when reading initial value of \"%s\"[%0d] through map \"%s\".",
			       status, mem.get_full_name(),
			       offset, maps[read_from].get_full_name()));
	    }
	  }
            
            
	  // Write a random value,
	  rand_reg_val.randomize();
	  v = rand_reg_val.randval;
            
	  mem.write(status, offset, v, uvm_door_e.UVM_FRONTDOOR, map, this);
	  if (status != uvm_status_e.UVM_IS_OK) {
	    uvm_error("uvm_mem_shared_access_seq",
		      format("Status was %s when writing \"%s\"[%0d] through map \"%s\".",
			     status, mem.get_full_name(), offset, map.get_full_name()));
	  }
            
	  // Read back from all other maps
	  foreach (map_; maps) {
	    uvm_reg_data_t  actual, exp;
               
	    mem.read(status, offset, actual, uvm_door_e.UVM_FRONTDOOR, map_, this);
	    if (status != uvm_status_e.UVM_IS_OK) {
	      uvm_error("uvm_mem_shared_access_seq",
			format("Status was %s when reading %s[%0d] through map \"%s\".",
			       status, mem.get_full_name(), offset,
			       map_.get_full_name()));
	    }
               
	    // Was it what we expected?
	    exp = v;
	    if (mem.get_access(map) == "RO") {
	      exp = prev;
	    }
	    if (mem.get_access(map_) == "WO") {
	      exp = 0;
	    }
	    // Trim to number of bits
	    exp &= (UVM_REG_DATA_1 << mem.get_n_bits()) - 1;
	    if (actual !is exp) {
	      uvm_error("uvm_mem_shared_access_seq",
			format("%s[%0d] through map \"%s\" is 0x%x instead of 0x%x after writing 0x%x via map \"%s\" over 0x%x.",
			       mem.get_full_name(), offset, map_.get_full_name(), actual, exp, v, map.get_full_name(), prev));
	    }
	  }
	}
      }
    }
}



//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_mem_shared_access_seq
//------------------------------------------------------------------------------
//
// Verify the accessibility of all shared registers
// and memories in a block
// by executing the <uvm_reg_shared_access_seq>
// and <uvm_mem_shared_access_seq>
// sequence respectively on every register and memory within it.
//
// If bit-type resource named
// "NO_REG_TESTS", "NO_MEM_TESTS",
// "NO_REG_SHARED_ACCESS_TEST" or "NO_MEM_SHARED_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the block,
// the block is not tested.
//
//| uvm_resource_db!bool.set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_REG_TESTS", 1, this);
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto E.4.3.1
class uvm_reg_mem_shared_access_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // Variable -- NODOCS -- model
  //
  // The block to be tested
  //
  //| uvm_reg_block model; 


  // Variable -- NODOCS -- reg_seq
  //
  // The sequence used to test one register
  //
  protected uvm_reg_shared_access_seq reg_seq;
   

  // Variable -- NODOCS -- mem_seq
  //
  // The sequence used to test one memory
  //
  protected uvm_mem_shared_access_seq mem_seq;
   
  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2020 auto E.4.3.3.1
  public this(string name="uvm_reg_mem_shared_access_seq") {
    super(name);
  }


  // @uvm-ieee 1800.2-2020 auto E.4.3.3.2
  // task
  override public void body() {

    if (model is null) {
      uvm_error("uvm_reg_mem_shared_access_seq", "No register model specified to run sequence on");
      return;
    }
      
    uvm_report_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~ " sequence...\n", uvm_verbosity.UVM_LOW);

    reg_seq = uvm_reg_shared_access_seq.type_id.create("reg_shared_access_seq");
    mem_seq = uvm_mem_shared_access_seq.type_id.create("reg_shared_access_seq");

    this.reset_blk(model);
    model.reset();

    do_block(model);
  }


  // Task -- NODOCS -- do_block
  //
  // Test all of the registers and memories in a block
  //
  // task
  protected void do_block(uvm_reg_block blk) {
    uvm_reg[] regs;
    uvm_mem[] mems;
      
    if (uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_MEM_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_SHARED_ACCESS_TEST", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_MEM_SHARED_ACCESS_TEST", 0) !is null) {
      return;
    }

    this.reset_blk(model);
    model.reset();

    // Iterate over all registers, checking accesses
    blk.get_registers(regs, uvm_hier_e.UVM_NO_HIER);
    foreach (reg; regs) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ reg.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ reg.get_full_name(),
					   "NO_REG_SHARED_ACCESS_TEST", 0) !is null )
	continue;
      reg_seq.rg = reg;
      reg_seq.start(this.get_sequencer(), this);
    }

    // Iterate over all memories, checking accesses
    blk.get_memories(mems, uvm_hier_e.UVM_NO_HIER);
    foreach (mem; mems) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_SHARED_ACCESS_TEST", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_SHARED_ACCESS_TEST", 0) !is null ) {
	continue;
      }
      mem_seq.mem = mem;
      mem_seq.start(this.get_sequencer(), this);
    }

    uvm_reg_block[] blks;
         
    blk.get_blocks(blks);
    foreach (blk_; blks) {
      do_block(blk_);
    }
  }


  //
  // task -- NODOCS -- reset_blk
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
  public void reset_blk(uvm_reg_block blk) { }

}
