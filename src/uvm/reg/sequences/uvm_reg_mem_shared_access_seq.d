// 
// -------------------------------------------------------------
//    Copyright 2004-2008 Synopsys, Inc.
//    Copyright 2010 Mentor Graphics Corporation
//    Copyright 2014 Coverify Systems Technology
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
// Title: Shared Register and Memory Access Test Sequences
//------------------------------------------------------------------------------
// This section defines sequences for testing registers and memories that are
// shared between two or more physical interfaces, i.e. are associated with
// more than one <uvm_reg_map> instance.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Class: uvm_reg_shared_access_seq
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

class uvm_reg_shared_access_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // Variable: rg
  // The register to be tested
  uvm_reg rg;

  mixin uvm_object_utils;

  public this(string name="uvm_reg_shared_access_seq") {
    super(name);
  }


  // task
  public void body() {
      uvm_reg_data_t  other_mask;
      uvm_reg_data_t  wo_mask[];
      uvm_reg_field fields[];
      uvm_reg_map maps[];

      if (rg is null) {
	uvm_error("uvm_reg_shared_access_seq",
		  "No register specified to run sequence on");
	return;
      }

      // Registers with some attributes are not to be tested
      if (uvm_resource_db!(bool).get_by_name("REG::" ~ rg.get_full_name(),
					     "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!(bool).get_by_name("REG::" ~ rg.get_full_name(),
					     "NO_REG_SHARED_ACCESS_TEST", 0) !is null ) {
	return;
      }

      // Only look at shared registers
      if (rg.get_n_maps() < 2) return;
      rg.get_maps(maps);

      // Let's see what kind of bits we have...
      rg.get_fields(fields);

      // Identify unpredictable bits and the ones we shouldn't change
      other_mask = 0;
      foreach (field; fields) {
	int lsb, w;
         
	lsb = field.get_lsb_pos();
	w   = field.get_n_bits();
         
	if (!field.is_known_access(maps[0])) {
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
	  int lsb, w;
            
	  lsb = field.get_lsb_pos();
	  w   = field.get_n_bits();
            
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
	uvm_reg_data_t  prev, v;
         
	// The mirror should contain the initial value
	prev = rg.get();
         
	// Write a random value, except in those "don't touch" fields
	v = (urandom!uvm_reg_data_t() & ~other_mask) | (prev & other_mask);
         
	uvm_info("uvm_reg_shared_access_seq",
		 format("Writing register %s via map \"%s\"...",
			rg.get_full_name(), map.get_full_name), UVM_LOW);
         
	uvm_info("uvm_reg_shared_access_seq",
		 format("Writing 'h%h over 'h%h", v, prev),UVM_DEBUG);
         
	rg.write(status, v, UVM_FRONTDOOR, map, this);
	if (status != UVM_IS_OK) {
	  uvm_error("uvm_reg_shared_access_seq",
		    format("Status was %s when writing register \"%s\"" ~
			   " through map \"%s\".",
			   status.name(), rg.get_full_name(),
			   map.get_full_name()));
	}
         
	foreach (map; maps) {
	  uvm_reg_data_t  actual, exp;
            
	  uvm_info("uvm_reg_shared_access_seq",
		   format("Reading register %s via map \"%s\"...",
			  rg.get_full_name(), map.get_full_name()), UVM_LOW);
            
	  // Was it what we expected?
	  exp = rg.get() & ~wo_mask[k];
            
	  rg.read(status, actual, UVM_FRONTDOOR, map, this);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_reg_shared_access_seq",
		      format("Status was %s when reading register \"%s\"" ~
			     " through map \"%s\".",
			     status.name(), rg.get_full_name(),
			     map.get_full_name()));
	  }
            
	  uvm_info("uvm_reg_shared_access_seq",
		   format("Read 'h%h, expecting 'h%h",
			  actual, exp),UVM_DEBUG);
            
	  if (actual != exp) {
	    uvm_error("uvm_reg_shared_access_seq",
		      format("Register \"%s\" through map \"%s\"" ~
			     " is 'h%h instead of 'h%h after writing" ~
			     " 'h%h via map \"%s\" over 'h%h.",
			     rg.get_full_name(), map.get_full_name(),
			     actual, exp, v, map.get_full_name(), prev));
	  }
	}
      }
    }
}


//------------------------------------------------------------------------------
// Class: uvm_mem_shared_access_seq
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
//| uvm_resource_db!(bool).set({"REG::",regmodel.blk.mem0.get_full_name()},
//|                            "NO_MEM_TESTS", 1, this);
//
// The DUT should be idle and not modify the memory during this test.
//
//------------------------------------------------------------------------------

class uvm_mem_shared_access_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // variable: mem
  // The memory to be tested
  uvm_mem mem;

  mixin uvm_object_utils;

  public this(string name="uvm_mem_shared_access_seq") {
    super(name);
  }

  // task
  public void frame() {
    if (mem is null) {
      uvm_error("uvm_mem_shared_access_seq",
		"No memory specified to run sequence on");
      return;
    }

    // Memories with some attributes are not to be tested
    if (uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_MEM_TESTS", 0) !is null ||
	uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_REG_SHARED_ACCESS_TEST", 0) !is null ||
	uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					   "NO_MEM_SHARED_ACCESS_TEST", 0) !is null) {
      return;
    }

    // Only look at shared memories
    if (mem.get_n_maps() < 2) return;

    uvm_reg_map maps[];
    mem.get_maps(maps);

    // We need at least a backdoor or a map that can read
    // the shared memory
    int read_from = -1;
    if (mem.get_backdoor() is null) {
      foreach (map; maps) {
	string right;
	right = mem.get_access(map);
	if (right == "RW" ||
	    right == "RO") {
	  read_from = j;
	  break;
	}
      }
      if (read_from < 0) {
	uvm_warning("uvm_mem_shared_access_seq",
		    format("Memory \"%s\" cannot be read from any maps" ~
			   " or backdoor. Shared access not verified.",
			   mem.get_full_name()));
	return;
      }
    }
      
    // Try to write through each map
    foreach (map; maps) {
         
      uvm_info("uvm_mem_shared_access_seq",
	       format("Writing shared memory \"%s\" via map \"%s\".",
		      mem.get_full_name(), map.get_full_name()), UVM_LOW);
         
      // All addresses
      for (int offset = 0; offset < mem.get_size(); offset++) {
	uvm_status_e status;
	uvm_reg_data_t  prev, v;
            
	// Read the initial value
	if (mem.get_backdoor() !is null) {
	  mem.peek(status, offset, prev);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_shared_access_seq",
		      format("Status was %s when reading initial" ~
			     " value of \"%s\"[%0d] through backdoor.",
			     status.name(), mem.get_full_name(), offset));
	  }
	}
	else {
	  mem.read(status, offset, prev, UVM_FRONTDOOR, maps[read_from], this);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_shared_access_seq",
		      format("Status was %s when reading initial" ~
			     " value of \"%s\"[%0d] through map \"%s\".",
			     status.name(), mem.get_full_name(),
			     offset, maps[read_from].get_full_name()));
	  }
	}
            
            
	// Write a random value,
	v = urandom!uvm_reg_data_t();
            
	mem.write(status, offset, v, UVM_FRONTDOOR, map, this);
	if (status != UVM_IS_OK) {
	  uvm_error("uvm_mem_shared_access_seq",
		    format("Status was %s when writing \"%s\"[%0d]" ~
			   " through map \"%s\".",
			   status.name(), mem.get_full_name(), offset, map.get_full_name()));
	}
            
	// Read back from all other maps
	foreach (map_; maps) {
	  uvm_reg_data_t  actual, exp;
               
	  mem.read(status, offset, actual, UVM_FRONTDOOR, map_, this);
	  if (status != UVM_IS_OK) {
	    uvm_error("uvm_mem_shared_access_seq",
		      format("Status was %s when reading %s[%0d]" ~
			     " through map \"%s\".",
			     status.name(), mem.get_full_name(), offset,
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
	  exp &= (1 << mem.get_n_bits()) - 1;
	  if (actual !== exp) {
	    uvm_error("uvm_mem_shared_access_seq",
		      format("%s[%0d] through map \"%s\" is 'h%h" ~
			     " instead of 'h%h after writing 'h%h" ~
			     " via map \"%s\" over 'h%h.",
			     mem.get_full_name(), offset,
			     map_.get_full_name(),
			     actual, exp, v, map.get_full_name(), prev));
	  }
	}
      }
    }
  }
}



//------------------------------------------------------------------------------
// Class: uvm_reg_mem_shared_access_seq
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
//| uvm_resource_db!(bool).set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_REG_TESTS", 1, this);
//
//------------------------------------------------------------------------------

class uvm_reg_mem_shared_access_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // Variable: model
  //
  // The block to be tested
  //
  //| uvm_reg_block model; 


  // Variable: reg_seq
  //
  // The sequence used to test one register
  //
  protected uvm_reg_shared_access_seq reg_seq;
   

  // Variable: mem_seq
  //
  // The sequence used to test one memory
  //
  protected uvm_mem_shared_access_seq mem_seq;
   
  mixin uvm_object_utils;

  public this(string name="uvm_reg_mem_shared_access_seq") {
    super(name);
  }


  // Task: body
  //
  // Executes the Shared Register and Memory sequence
  //
  // task
  public void frame() {

    if (model is null) {
      uvm_error("uvm_reg_mem_shared_access_seq",
		"No register model specified to run sequence on");
      return;
    }
      
    uvm_report_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~
		    " sequence...\n", UVM_LOW);

    reg_seq = uvm_reg_shared_access_seq.type_id.create("reg_shared_access_seq");
    mem_seq = uvm_mem_shared_access_seq.type_id.create("reg_shared_access_seq");

    this.reset_blk(model);
    model.reset();

    do_block(model);
  }


  // Task: do_block
  //
  // Test all of the registers and memories in a block
  //
  // task
  protected void do_block(uvm_reg_block blk) {
    uvm_reg regs[];
    uvm_mem mems[];
      
    if (uvm_resource_db!(bool).get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!(bool).get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_MEM_TESTS", 0) !is null ||
	uvm_resource_db!(bool).get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_SHARED_ACCESS_TEST", 0) !is null ||
	uvm_resource_db!(bool).get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_MEM_SHARED_ACCESS_TEST", 0) !is null) {
      return;
    }

    this.reset_blk(model);
    model.reset();

    // Iterate over all registers, checking accesses
    blk.get_registers(regs, UVM_NO_HIER);
    foreach (reg; regs) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!(bool).get_by_name({"REG::",reg.get_full_name()},
					     "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!(bool).get_by_name({"REG::",reg.get_full_name()},
					     "NO_REG_SHARED_ACCESS_TEST", 0) !is null )
	continue;
      reg_seq.rg = reg;
      reg_seq.start(this.get_sequencer(), this);
    }

    // Iterate over all memories, checking accesses
    blk.get_memories(mems, UVM_NO_HIER);
    foreach (mem; mems) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_TESTS", 0) !is null ||
	  uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_REG_SHARED_ACCESS_TEST", 0) !is null ||
	  uvm_resource_db!(bool).get_by_name("REG::" ~ mem.get_full_name(),
					     "NO_MEM_SHARED_ACCESS_TEST", 0) !is null ) {
	continue;
      }
      mem_seq.mem = mem;
      mem_seq.start(this.get_sequencer(), this);
    }

    uvm_reg_block blks[];
         
    blk.get_blocks(blks);
    foreach (blk; blks) {
      do_block(blk);
    }
  }


  //
  // task: reset_blk
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
