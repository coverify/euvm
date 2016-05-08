// 
// -------------------------------------------------------------
//    Copyright 2004-2008 Synopsys, Inc.
//    Copyright 2010 Mentor Graphics Corporation
//    Copyright 2014 Coverify systems Technology
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
// class: uvm_reg_hw_reset_seq
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

class uvm_reg_hw_reset_seq: uvm_reg_sequence!(uvm_sequence!(uvm_reg_item))
{

  mixin uvm_object_utils;

  this(string name="uvm_reg_hw_reset_seq") {
    super(name);
  }


  // Variable: model
  //
  // The block to be tested. Declared in the base class.
  //
  //| uvm_reg_block model; 


  // Variable: body
  //
  // Executes the Hardware Reset sequence.
  // Do not call directly. Use seq.start() instead.

  // virtual task body();

  // task
  void frame() {

    if(model is null) {
      uvm_error("uvm_reg_hw_reset_seq",
		"Not block or system specified to run sequence on");
      return;
    }
      
    uvm_report_info("STARTING_SEQ", "\n\nStarting " ~ get_name() ~
		    " sequence...\n", UVM_LOW);

    if(uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					  "NO_REG_TESTS", 0) !is null ||
       uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					  "NO_REG_HW_RESET_TEST", 0) !is null)
      {
	return;
      }

    this.reset_blk(model);
    model.reset();

    uvm_reg_map maps[];
    model.get_maps(maps);

    // Iterate over all maps defined for the RegModel block

    foreach (map; maps) {

      // Iterate over all registers in the map, checking accesses
      // Note: if map were in inner loop, could test simulataneous
      // access to same reg via different bus interfaces 

      uvm_reg regs[];
      map.get_registers(regs);

      foreach (reg; regs) {

	uvm_status_e status;

	// Registers with certain attributes are not to be tested
	if(uvm_resource_db!(bool).get_by_name("REG::" ~ reg.get_full_name(),
					      "NO_REG_TESTS", 0) !is null ||
	   uvm_resource_db#(bool).get_by_name("REG::" ~ reg.get_full_name(),
					      "NO_REG_HW_RESET_TEST", 0) !is null) {
	  continue;
	}

	uvm_info(get_type_name(),
		 format("Verifying reset value of register %s in map \"%s\"...",
			reg.get_full_name(), map.get_full_name()), UVM_LOW);
            
	reg.mirror(status, UVM_CHECK, UVM_FRONTDOOR, map, this);

	if(status !is UVM_IS_OK) {
	  uvm_error(get_type_name(),
		    format("Status was %s when reading reset value of register \"%s\" through map \"%s\".",
			   status.name(), reg.get_full_name(), map.get_full_name()));
	}
      }
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
  // virtual task reset_blk(uvm_reg_block blk);
  // task
  public void reset_blk(uvm_reg_block blk) {
  }
}


