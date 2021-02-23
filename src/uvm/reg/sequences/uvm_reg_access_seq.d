// 
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2004-2010 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2015 NVIDIA Corporation
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
//
// Title -- NODOCS -- Register Access Test Sequences
//
// This section defines sequences that test DUT register access via the
// available frontdoor and backdoor paths defined in the provided register
// model.
//------------------------------------------------------------------------------

// typedef class uvm_mem_access_seq;

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_reg_single_access_seq
//
// Verify the accessibility of a register
// by writing through its default address map
// then reading it via the backdoor, then reversing the process,
// making sure that the resulting value matches the mirrored value.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the register,
// the register is not tested.
//
//| uvm_resource_db!(bool).set({"REG::",regmodel.blk.r0.get_full_name()},
//|                            "NO_REG_TESTS", 1, this);
//
// Registers without an available backdoor or
// that contain read-only fields only,
// or fields with unknown access policies
// cannot be tested.
//
// The DUT should be idle and not modify any register during this test.
//
//------------------------------------------------------------------------------

module uvm.reg.sequences.uvm_reg_access_seq;

// import uvm.reg.sequences.uvm_mem_access_seq: uvm_mem_access_seq;
import uvm.reg;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;

import esdl;
import std.string: format;

// @uvm-ieee 1800.2-2017 auto E.3.1.1
class uvm_reg_single_access_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
{

  // Variable -- NODOCS -- rg
  // The register to be tested
  @rand(false)
    uvm_reg rg;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.3.1.3
  this(string name="uvm_reg_single_access_seq") {
    super(name);
  }

  // task
  override public void body() {
      uvm_reg_map[] maps;

      if (rg is null) {
	uvm_error("uvm_reg_access_seq", "No register specified to run sequence on");
	return;
      }

      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ rg.get_full_name(),
					   "NO_REG_TESTS", 0) !is null || 
          uvm_resource_db!bool.get_by_name("REG::" ~ rg.get_full_name(),
					   "NO_REG_ACCESS_TEST", 0) !is null )
	return;

      // Can only deal with registers with backdoor access
      if (rg.get_backdoor() is null && !rg.has_hdl_path()) {
	uvm_error("uvm_reg_access_seq", "Register '" ~ rg.get_full_name() ~
		  "' does not have a backdoor mechanism available");
	return;
      }

      // Registers may be accessible from multiple physical interfaces (maps)
      rg.get_maps(maps);

      // Cannot test access if register contains RO or OTHER fields
      uvm_reg_field[] fields;

      rg.get_fields(fields);

      foreach (map; maps) {
	int ro = 0;

	foreach (field; fields) {
	  if (field.get_access(map) == "RO") {
	    ro++;
	  }
	  if (! field.is_known_access(map)) {
	    uvm_warning("uvm_reg_access_seq", "Register '" ~ rg.get_full_name() ~
			"' has field with unknown access type '" ~
			field.get_access(map) ~ "', skipping");
	    return;
	  }
	}
	if (ro == fields.length) {
	  uvm_warning("uvm_reg_access_seq", "Register '" ~
		      rg.get_full_name() ~ "' has only RO fields in map " ~
		      map.get_full_name() ~ ", skipping");
	  return;
	}
      }
     
      
      // Access each register:
      // - Write complement of reset value via front door
      // - Read value via backdoor and compare against mirror
      // - Write reset value via backdoor
      // - Read via front door and compare against mirror
      foreach (map; maps) {
	import std.conv: to;
	uvm_status_e status;
	uvm_reg_data_t  v, exp;
         
	uvm_info("uvm_reg_access_seq", "Verifying access of register '" ~
		 rg.get_full_name() ~ "' in map '" ~ map.get_full_name() ~
		 "' ...", uvm_verbosity.UVM_LOW);
         
	v = rg.get();
         
	rg.write(status, ~v, UVM_FRONTDOOR, map, this);

	if (status != UVM_IS_OK) {
	  uvm_error("uvm_reg_access_seq", "Status was '" ~ status.to!string() ~
		    "' when writing '" ~ rg.get_full_name() ~
		    "' through map '" ~ map.get_full_name() ~ "'");
	}
	// #1;
	wait(1);
         
	rg.mirror(status, UVM_CHECK, UVM_BACKDOOR, uvm_reg_map.backdoor(), this);
	if (status != UVM_IS_OK) {
	  uvm_error("uvm_reg_access_seq", "Status was '" ~ status.to!string() ~
		    "' when reading reset value of register '" ~
		    rg.get_full_name() ~ "' through backdoor");
	}
         
	rg.write(status, v, UVM_BACKDOOR, map, this);
	if (status != UVM_IS_OK) {
	  uvm_error("uvm_reg_access_seq", "Status was '" ~ status.to!string() ~
		    "' when writing '" ~ rg.get_full_name() ~
		    "' through backdoor");
	}
         
	rg.mirror(status, UVM_CHECK, UVM_FRONTDOOR, map, this);
	if (status != UVM_IS_OK) {
	  uvm_error("uvm_reg_access_seq", "Status was '" ~ status.to!string() ~
		    "' when reading reset value of register '" ~
		    rg.get_full_name() ~ "' through map '" ~
		    map.get_full_name() ~ "'");
	}
      }
    }
}


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_reg_access_seq
//
// Verify the accessibility of all registers in a block
// by executing the <uvm_reg_single_access_seq> sequence on
// every register within it.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_ACCESS_TEST"
// in the "REG::" namespace
// matches the full name of the block,
// the block is not tested.
//
//| uvm_resource_db!(bool).set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_REG_TESTS", 1, this);
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto E.3.2.1
class uvm_reg_access_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
{
  // Variable -- NODOCS -- model
  //
  // The block to be tested. Declared in the base class.
  //
  //| uvm_reg_block model; 


  // Variable -- NODOCS -- reg_seq
  //
  // The sequence used to test one register
  //
  protected uvm_reg_single_access_seq reg_seq;
   
  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.3.2.3.1
  public this(string name="uvm_reg_access_seq") {
    super(name);
  }


  // @uvm-ieee 1800.2-2017 auto E.3.2.3.2
  override public void body() {

    if (model is null) {
      uvm_error("uvm_reg_access_seq", "No register model specified to run sequence on");
      return;
    }

    uvm_report_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~ " sequence...\n",
		    uvm_verbosity.UVM_LOW);
      
    reg_seq = uvm_reg_single_access_seq.type_id.create("single_reg_access_seq");

    this.reset_blk(model);
    model.reset();

    do_block(model);
  }


  // Task -- NODOCS -- do_block
  //
  // Test all of the registers in a block
  //

  // task
  protected void do_block(uvm_reg_block blk) {
    uvm_reg[] regs;
      
    if (uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					 "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					 "NO_REG_ACCESS_TEST", 0) !is null ) {
      return;
    }

    // Iterate over all registers, checking accesses
    blk.get_registers(regs, UVM_NO_HIER);
    foreach (reg; regs) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ reg.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ reg.get_full_name(),
					   "NO_REG_ACCESS_TEST", 0) !is null )
	continue;
         
      // Can only deal with registers with backdoor access
      if (reg.get_backdoor() is null && !reg.has_hdl_path()) {
	uvm_warning("uvm_reg_access_seq", "Register '" ~ reg.get_full_name() ~
		    "' does not have a backdoor mechanism available");
	continue;
      }
         
      reg_seq.rg = reg;
      reg_seq.start(null, this);
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
  public void reset_blk(uvm_reg_block blk) { }

}


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_reg_mem_access_seq
//
// Verify the accessibility of all registers and memories in a block
// by executing the <uvm_reg_access_seq> and
// <uvm_mem_access_seq> sequence respectively on every register
// and memory within it.
//
// Blocks and registers with the NO_REG_TESTS or
// the NO_REG_ACCESS_TEST attribute are not verified.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto E.3.3.1
class uvm_reg_mem_access_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
{
  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.3.3.2
  public this(string name="uvm_reg_mem_access_seq") {
    super(name);
  }

  override public void body() {

    if (model is null) {
      uvm_error("uvm_reg_mem_access_seq", "Register model handle is null");
      return;
    }

    uvm_report_info("STARTING_SEQ",
		    "\n\nStarting " ~ get_name() ~ " sequence...\n", uvm_verbosity.UVM_LOW);
      
    if (uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null) {
      if (uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_ACCESS_TEST", 0) is null) {
	uvm_reg_access_seq sub_seq = new uvm_reg_access_seq("reg_access_seq");
	this.reset_blk(model);
	model.reset();
	sub_seq.model = model;
	sub_seq.start(null, this);
      }
      if (uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					     "NO_MEM_ACCESS_TEST", 0) is null) {
	import uvm.reg.sequences.uvm_mem_access_seq: uvm_mem_access_seq;
	uvm_mem_access_seq sub_seq = new uvm_mem_access_seq("mem_access_seq");
	this.reset_blk(model);
	model.reset();
	sub_seq.model = model;
	sub_seq.start(null, this);
      }
    }

  }


  // Any additional steps required to reset the block
  // and make it accessibl

  // task
  public void reset_blk(uvm_reg_block blk) { }
}
