// 
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2013 Semifore
// Copyright 2004-2010 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2014-2018 NVIDIA Corporation
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
// Title -- NODOCS -- Bit Bashing Test Sequences
//------------------------------------------------------------------------------
// This section defines classes that test individual bits of the registers
// defined in a register model.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_single_bit_bash_seq
//
// Verify the implementation of a single register
// by attempting to write 1's and 0's to every bit in it,
// via every address map in which the register is mapped,
// making sure that the resulting value matches the mirrored value.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_BIT_BASH_TEST"
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
// The DUT should be idle and not modify any register durign this test.
//
//------------------------------------------------------------------------------

module uvm.reg.sequences.uvm_reg_bit_bash_seq;

import uvm.reg;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;

import esdl;
import std.string: format;


// @uvm-ieee 1800.2-2017 auto E.2.1.1
class uvm_reg_single_bit_bash_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  // Variable -- NODOCS -- rg
  // The register to be tested
  uvm_reg rg;

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.2.1.3
  public this(string name="uvm_reg_single_bit_bash_seq") {
    super(name);
  }

  // task
  override public void body() {
    uvm_reg_field[] fields;
    string[UVM_REG_DATA_WIDTH] mode;
    uvm_reg_map[] maps;
    uvm_reg_data_t  dc_mask;
    uvm_reg_data_t  reset_val;
    int n_bits;
         
    if (rg is null) {
      uvm_error("uvm_reg_bit_bash_seq", "No register specified to run sequence on");
      return;
    }

    // Registers with some attributes are not to be tested
    if(uvm_resource_db!bool.get_by_name("REG::" ~ rg.get_full_name(),
					"NO_REG_TESTS", 0) !is null ||
       uvm_resource_db!bool.get_by_name("REG::" ~ rg.get_full_name(),
					"NO_REG_BIT_BASH_TEST", 0) !is null)
      return;
      
    n_bits = rg.get_n_bytes() * 8;
         
    // Let's see what kind of bits we have...
    rg.get_fields(fields);
         
    // Registers may be accessible from multiple physical interfaces (maps)
    rg.get_maps(maps);
         
    // Bash the bits in the register via each map
    foreach (map; maps) {
      uvm_status_e status;
      uvm_reg_data_t  val, exp, v;
      int next_lsb;
         
      next_lsb = 0;
      dc_mask  = 0;
      foreach(field; fields) {

	string field_access = field.get_access(map);
	bool dc = (field.get_compare() == UVM_NO_CHECK);
	int lsb = field.get_lsb_pos();
	int w   = field.get_n_bits();
	// Ignore Write-only fields because
	// you are not supposed to read them
	switch (field_access) {
	case "WO", "WOC", "WOS", "WO1": dc = true; break;
	default: break;
	}
	// Any unused bits on the right side of the LSB?
	while (next_lsb < lsb) mode[next_lsb++] = "RO";
            
	for (size_t repeat=0; repeat!=w; ++repeat) {
	  mode[next_lsb] = field.get_access(map);
	  dc_mask[next_lsb] = dc;
	  next_lsb++;
	}
      }
      // Any unused bits on the left side of the MSB?
      while (next_lsb < UVM_REG_DATA_WIDTH)
	mode[next_lsb++] = "RO";

      uvm_info("uvm_reg_bit_bash_seq", format("Verifying bits in register %s in map \"%s\"...",
			  rg.get_full_name(), map.get_full_name()), uvm_verbosity.UVM_LOW);
         
      // Bash the kth bit
      for (int k = 0; k < n_bits; k++) {
	// Cannot test unpredictable bit behavior
	if (dc_mask[k]) continue;

	bash_kth_bit(rg, k, mode[k], map, dc_mask);
      }
            
    }
  }


  // task
  public void bash_kth_bit(uvm_reg         rg,
			   int             k,
			   string          mode,
			   uvm_reg_map     map,
			   uvm_reg_data_t  dc_mask) {
    uvm_status_e status;
    uvm_reg_data_t  val, exp, v;
    bool bit_val;

    uvm_info("uvm_reg_bit_bash_seq", format("...Bashing %s bit #%0d", mode, k),
	     uvm_verbosity.UVM_HIGH);
      
    for (size_t repeat=0; repeat!=2; ++repeat) {
      val = rg.get();
      v   = val;
      exp = val;
      val[k] = ~val[k];
      bit_val = val[k];
         
      rg.write(status, val, UVM_FRONTDOOR, map, this);
      if (status != UVM_IS_OK) {
	uvm_error("uvm_reg_bit_bash_seq",
		  format("Status was %s when writing to register \"%s\" through map \"%s\".",
			 status, rg.get_full_name(), map.get_full_name()));
      }
         
      exp = rg.get() & ~dc_mask;
      rg.read(status, val, UVM_FRONTDOOR, map, this);
      if (status != UVM_IS_OK) {
	uvm_error("uvm_reg_bit_bash_seq",
		  format("Status was %s when reading register \"%s\" through map \"%s\".",
			 status, rg.get_full_name(), map.get_full_name()));
      }

      val &= ~dc_mask;
      if (val != exp) {
	uvm_error("uvm_reg_bit_bash_seq",
		  format("Writing a %b in bit #%0d of register \"%s\" with initial value 'h%h yielded 'h%h instead of 'h%h",
			 bit_val, k, rg.get_full_name(), v, val, exp));
      }
    }
  }

}

//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_bit_bash_seq
//
//
// Verify the implementation of all registers in a block
// by executing the <uvm_reg_single_bit_bash_seq> sequence on it.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_BIT_BASH_TEST"
// in the "REG::" namespace
// matches the full name of the block,
// the block is not tested.
//
//| uvm_resource_db!(bit).set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_REG_TESTS", 1, this);
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto E.2.2.1
class uvm_reg_bit_bash_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
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
  protected uvm_reg_single_bit_bash_seq reg_seq;
   
  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2017 auto E.2.2.3.1
  public this(string name="uvm_reg_bit_bash_seq") {
    super(name);
  }


  // Task -- NODOCS -- body
  //
  // Executes the Register Bit Bash sequence.
  // Do not call directly. Use seq.start() instead.
  //

  // @uvm-ieee 1800.2-2017 auto E.2.2.3.2
  // task
  override public void body() {
      
    if (model is null) {
      uvm_error("uvm_reg_bit_bash_seq", "No register model specified to run sequence on");
      return;
    }

    uvm_report_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~ " sequence...\n",
		    uvm_verbosity.UVM_LOW);

    reg_seq = uvm_reg_single_bit_bash_seq.type_id.create("reg_single_bit_bash_seq");

    this.reset_blk(model);
    model.reset();

    do_block(model);
  }


  // Task -- NODOCS -- do_block
  //
  // Test all of the registers in a a given ~block~
  //
  // task
  protected void do_block(uvm_reg_block blk) {
    uvm_reg[] regs;

    if (uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ blk.get_full_name(),
					   "NO_REG_BIT_BASH_TEST", 0) !is null)
      return;

    // Iterate over all registers, checking accesses
    blk.get_registers(regs, UVM_NO_HIER);
    foreach (reg; regs) {
      // Registers with some attributes are not to be tested
      if (uvm_resource_db!bool.get_by_name("REG::" ~ reg.get_full_name(),
					   "NO_REG_TESTS", 0) !is null ||
	  uvm_resource_db!bool.get_by_name("REG::" ~ reg.get_full_name(),
					   "NO_REG_BIT_BASH_TEST", 0) !is null)
	continue;
         
      reg_seq.rg = reg;
      reg_seq.start(null,this);
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
