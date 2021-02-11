// 
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2004-2010 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2015-2018 NVIDIA Corporation
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

//
// TITLE -- NODOCS -- Memory Access Test Sequence
//

//
// class -- NODOCS -- uvm_mem_single_access_seq
//
// Verify the accessibility of a memory
// by writing through its default address map
// then reading it via the backdoor, then reversing the process,
// making sure that the resulting value matches the written value.
//
// If bit-type resource named
// "NO_REG_TESTS", "NO_MEM_TESTS", or "NO_MEM_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the memory,
// the memory is not tested.
//
//| uvm_resource_db!(bit).set({"REG::",regmodel.blk.mem0.get_full_name()},
//|                            "NO_MEM_TESTS", 1, this);
//
// Memories without an available backdoor
// cannot be tested.
//
// The DUT should be idle and not modify the memory during this test.
//

module uvm.reg.sequences.uvm_mem_access_seq;

import uvm.reg;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;

import esdl;
import std.string: format;

// @uvm-ieee 1800.2-2017 auto E.5.1.1
class uvm_mem_single_access_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
{

  // Variable -- NODOCS -- mem
  //
  // The memory to be tested
  //
  uvm_mem mem;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.5.1.3
  this(string name="uam_mem_single_access_seq") {
    super(name);
  }

  // task
  override public void body() {
      string mode;

      if (mem is null) {
	uvm_error("uvm_mem_access_seq",
		  "No register specified to run sequence on");
	return;
      }

      // Memories with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					    "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					    "NO_MEM_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					    "NO_MEM_ACCESS_TEST", 0) !is null) {
	return;
      }

      // Can only deal with memories with backdoor access
      if (mem.get_backdoor() is null && !mem.has_hdl_path()) {
	uvm_error("uvm_mem_access_seq", "Memory '" ~ mem.get_full_name() ~
		  "' does not have a backdoor mechanism available");
	return;
      }

      int n_bits = mem.get_n_bits();
      
      // Memories may be accessible from multiple physical interfaces (maps)
      uvm_reg_map[] maps;
      mem.get_maps(maps);

      // Walk the memory via each map
      foreach (map; maps) {
	uvm_status_e status;
	uvm_reg_data_t  val, exp, v;
         
	uvm_info("uvm_mem_access_seq", "Verifying access of memory '" ~
		 mem.get_full_name() ~ "' in map '" ~ map.get_full_name() ~
		 "' ...", uvm_verbosity.UVM_LOW);

	mode = mem.get_access(map);
         
	// The access process is, for address k:
	// - Write random value via front door
	// - Read via backdoor and expect same random value if RW
	// - Write complement of random value via back door
	// - Read via front door and expect inverted random value
	uvm_reg_data_t mask = 1;
	mask = (mask << n_bits) - 1;
	for (int k = 0; k < mem.get_size(); k++) {
	  val = urandom!uvm_reg_data_t & mask;
	  // if (n_bits > 32)
	  //   val = uvm_reg_data_t'(val << 32) | $random;
	  if (mode == "RO") {
	    mem.peek(status, k, exp);
	    if (status != UVM_IS_OK) {
	      uvm_error("uvm_mem_access_seq",
			format("Status was %s when reading \"%s[%0d]\" through backdoor.",
			       status, mem.get_full_name(), k));
	    }
	  }
	  else exp = val;
            
	  mem.write(status, k, val, UVM_FRONTDOOR, map, this);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_access_seq",
		      format("Status was %s when writing \"%s[%0d]\" through map \"%s\".",
			     status, mem.get_full_name(), k, map.get_full_name()));
	  }
	  wait(1);
	  val = 0;
	  mem.peek(status, k, val);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_access_seq", format("Status was %s when reading \"%s[%0d]\" through backdoor.",
						   status, mem.get_full_name(), k));
	  }
	  else {
	    if (val !is exp) {
	      uvm_error("uvm_mem_access_seq", format("Backdoor \"%s[%0d]\" read back as 'h%h instead of 'h%h.",
						     mem.get_full_name(), k, val, exp));
	    }
	  }
            
	  exp = ~exp & mask;
	  mem.poke(status, k, exp);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_access_seq", format("Status was %s when writing \"%s[%0d-1]\" through backdoor.",
						   status, mem.get_full_name(), k));
	  }
            
	  mem.read(status, k, val, UVM_FRONTDOOR, map, this);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_access_seq", format("Status was %s when reading \"%s[%0d]\" through map \"%s\".",
						   status, mem.get_full_name(), k, map.get_full_name()));
	  }
	  else {
	    if (mode == "WO") {
	      if (val !is uvm_reg_data_t(0)) {
		uvm_error("uvm_mem_access_seq", format("Front door \"%s[%0d]\" read back as 'h%h instead of 'h%h.",
						       mem.get_full_name(), k, val, 0));
	      }
	    }
	    else {
	      if (val !is exp) {
		uvm_error("uvm_mem_access_seq", format("Front door \"%s[%0d]\" read back as 'h%h instead of 'h%h.",
						       mem.get_full_name(), k, val, exp));
	      }
	    }
	  }
	}
      }
    }
}




//
// class -- NODOCS -- uvm_mem_access_seq
//
// Verify the accessibility of all memories in a block
// by executing the <uvm_mem_single_access_seq> sequence on
// every memory within it.
//
// If bit-type resource named
// "NO_REG_TESTS", "NO_MEM_TESTS", or "NO_MEM_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the block,
// the block is not tested.
//
//| uvm_resource_db!(bit).set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_MEM_TESTS", 1, this);
//

// @uvm-ieee 1800.2-2017 auto E.5.2.1
class uvm_mem_access_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
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
  protected uvm_mem_single_access_seq mem_seq;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.5.2.3.1
  this(string name="uvm_mem_access_seq") {
    super(name);
  }

  // @uvm-ieee 1800.2-2017 auto E.5.2.3.2
  override public void body() {

      if (model is null) {
	uvm_error("uvm_mem_access_seq", "No register model specified to run sequence on");
	return;
      }

      uvm_report_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~ " sequence...\n",
		      uvm_verbosity.UVM_LOW);
      
      mem_seq = uvm_mem_single_access_seq.type_id.create("single_mem_access_seq");

      this.reset_blk(model);
      model.reset();

      do_block(model);
    }


  // Task -- NODOCS -- do_block
  //
  // Test all of the memories in a given ~block~
  //

  // task
  protected void do_block(uvm_reg_block blk) {
    uvm_mem[] mems;
      
    if (uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					 "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					 "NO_MEM_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					 "NO_MEM_ACCESS_TEST", 0) !is null )
      return;
      
    // Iterate over all memories, checking accesses
    blk.get_memories(mems, UVM_NO_HIER);
    foreach (mem; mems) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_MEM_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_MEM_ACCESS_TEST", 0) !is null)
	continue;
         
      // Can only deal with memories with backdoor access
      if (mem.get_backdoor() is null &&
	  ! mem.has_hdl_path()) {
	uvm_warning("uvm_mem_access_seq", format("Memory \"%s\" does not have a backdoor mechanism available",
						 mem.get_full_name()));
	continue;
      }
         
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
  void reset_blk(uvm_reg_block blk) { }

}

