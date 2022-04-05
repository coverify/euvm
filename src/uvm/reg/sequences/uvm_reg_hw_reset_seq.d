// 
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2018 Qualcomm, Inc.
// Copyright 2012-2020 Semifore
// Copyright 2004-2013 Synopsys, Inc.
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
// class -- NODOCS -- uvm_reg_hw_reset_seq
// Test the hard reset values of registers
//
// The test sequence performs the following steps
//
// 1. resets the DUT and the
// block abstraction class associated with this sequence.
//
// 2. reads all of the registers in the block,
// via all of the available address maps,
// comparing the value read with the expected reset value.
//
// If bit-type resource named
// "NO_REG_TESTS" or "NO_REG_HW_RESET_TEST"
// in the "REG::" namespace
// matches the full name of the block or register,
// the block or register is not tested.
//
//| uvm_resource_db#(bit)::set({"REG::",regmodel.blk.get_full_name(),".*"},
//|                            "NO_REG_TESTS", 1, this);
//
// This is usually the first test executed on any DUT.
//

module uvm.reg.sequences.uvm_reg_hw_reset_seq;

import uvm.reg.uvm_reg_sequence: uvm_reg_sequence;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_model: uvm_hier_e, uvm_door_e, uvm_status_e, uvm_reg_data_t,
  uvm_check_e;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;

import esdl;
import std.string: format;

// @uvm-ieee 1800.2-2020 auto E.1.1
class uvm_reg_hw_reset_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
{

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2020 auto E.1.2.1.1
  this(string name="uvm_reg_hw_reset_seq") {
    super(name);
  }


  // Variable -- NODOCS -- model
  //
  // The block to be tested. Declared in the base class.
  //
  //| uvm_reg_block model; 


  // Variable -- NODOCS -- body
  //
  // Executes the Hardware Reset sequence.
  // Do not call directly. Use seq.start() instead.

  // @uvm-ieee 1800.2-2020 auto E.1.2.1.2
  // task
  override void body() {

      if(model is null) {
	uvm_error("uvm_reg_hw_reset_seq",	"Not block or system specified to run sequence on");
	return;
      }
      
      uvm_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~ " sequence...\n", uvm_verbosity.UVM_LOW);
      
      this.reset_blk(model);
      model.reset();

      do_block(model);
    }

  // Task -- NODOCS -- do_block
  //
  // Test all of the registers in a given ~block~
  //

  // task
  void do_block(uvm_reg_block blk) {
    if (uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) !is null ||
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_HW_RESET_TEST", 0) !is null) {
      return;
    }

    uvm_reg[] regs;
    blk.get_registers(regs, uvm_hier_e.UVM_NO_HIER);
    
    foreach (reg; regs) {
      if(uvm_resource_db!(bool).get_by_name("REG::" ~ reg.get_full_name(),
					    "NO_REG_TESTS", 0) !is null ||
	 uvm_resource_db!(bool).get_by_name("REG::" ~ reg.get_full_name(),
					    "NO_REG_HW_RESET_TEST", 0) !is null)
	continue;


      uvm_reg_field[] fields;
      reg.get_fields(fields);
            
      uvm_check_e[uvm_reg_field] field_check_restore;
      foreach (field; fields) {
	if (field.has_reset() == 0 ||
	    field.get_compare() == uvm_check_e.UVM_NO_CHECK || 
	    uvm_resource_db!bool.get_by_name("REG::" ~ field.get_full_name(),
					     "NO_REG_HW_RESET_TEST", 0) !is null) {
	  field_check_restore[field] = field.get_compare();  
	  field.set_compare(uvm_check_e.UVM_NO_CHECK);
	}
      }
      // if there are some fields to check
      if (fields.length != field_check_restore.length) {
	uvm_reg_map[] rm;
	reg.get_maps(rm);
	foreach (reg_map; rm) {
	  uvm_info(get_type_name(),
		   format("Verifying reset value of register %s in map \"%s\"...",
			  reg.get_full_name(), reg_map.get_full_name()), uvm_verbosity.UVM_LOW);
               
	  uvm_status_e status;
	  reg.mirror(status, uvm_check_e.UVM_CHECK, uvm_door_e.UVM_FRONTDOOR, reg_map, this);
               
	  if (status != uvm_status_e.UVM_IS_OK) {
	    uvm_error(get_type_name(),
		      format("Status was %s when reading reset value of register \"%s\" through map \"%s\".",
			     status, reg.get_full_name(), reg_map.get_full_name()));
	  }
	}
      }
      // restore compare setting
      foreach (field, check; field_check_restore) {
	field.set_compare(check);
      }
    }
      
    uvm_reg_block[] sub_blks;
    blk.get_blocks(sub_blks, uvm_hier_e.UVM_NO_HIER);

    foreach (sub_blk; sub_blks) {
      do_block(sub_blk);
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
  public void reset_blk(uvm_reg_block blk) {
  }
}


