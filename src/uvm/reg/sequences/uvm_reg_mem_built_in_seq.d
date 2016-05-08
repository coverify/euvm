//
// -------------------------------------------------------------
//    Copyright 2010 Mentor Graphics Corporation
//    Copyright 2010 Synopsys, Inc.
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
// Class: uvm_reg_mem_built_in_seq
//
// Sequence that executes a user-defined selection
// of pre-defined register and memory test sequences.
//
//------------------------------------------------------------------------------

class uvm_reg_mem_built_in_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  mixin uvm_object_utils;

  this(string name="uvm_reg_mem_built_in_seq") {
    super(name);
  }

  // Variable: model
  //
  // The block to be tested. Declared in the base class.
  //
  //| uvm_reg_block model; 


  // Variable: tests
  //
  // The pre-defined test sequences to be executed.
  //
  Bit!64 tests = UVM_DO_ALL_REG_MEM_TESTS;


  // Task: body
  //
  // Executes any or all the built-in register and memory sequences.
  // Do not call directly. Use seq.start() instead.
   
  // virtual task body();

  // task
  public void frame() {

    if (model is null) {
      uvm_error("uvm_reg_mem_built_in_seq",
		"Not block or system specified to run sequence on");
      return;
    }

    uvm_report_info("START_SEQ", "\n\nStarting " ~ get_name()
		    ~ " sequence...\n", UVM_LOW);

    if (tests & UVM_DO_REG_HW_RESET &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_HW_RESET_TEST", 0) is null ) {
      uvm_reg_hw_reset_seq seq =
	uvm_reg_hw_reset_seq.type_id.create("reg_hw_reset_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.",
	       UVM_LOW);
    }

    if (tests & UVM_DO_REG_BIT_BASH &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_BIT_BASH_TEST", 0) is null )
      {
	uvm_reg_bit_bash_seq seq =
	  uvm_reg_bit_bash_seq.type_id.create("reg_bit_bash_seq");
	seq.model = model;
	seq.start(null, this);
	uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.",
		 UVM_LOW);
      }

    if (tests & UVM_DO_REG_ACCESS &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_ACCESS_TEST", 0) is null ) {
      uvm_reg_access_seq seq =
	uvm_reg_access_seq.type_id.create("reg_access_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.",
	       UVM_LOW);
    }

    if (tests & UVM_DO_MEM_ACCESS &&
	uvm_resource_db!(bool).get_by_name({"REG::",model.get_full_name()},
					   "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name({"REG::",model.get_full_name()},
					   "NO_MEM_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name({"REG::",model.get_full_name()},
					   "NO_MEM_ACCESS_TEST", 0) is null ) {
      uvm_mem_access_seq seq =
	uvm_mem_access_seq.type_id::create("mem_access_seq");
      seq.model = model;
      seq.start(null,this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.",
	       UVM_LOW);
    }

    if (tests & UVM_DO_SHARED_ACCESS &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_SHARED_ACCESS_TEST", 0) is null )
      {
	uvm_reg_mem_shared_access_seq seq =
	  uvm_reg_mem_shared_access_seq.type_id.create("shared_access_seq");
	seq.model = model;
	seq.start(null,this);
	uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.",
		 UVM_LOW);
      }

    if (tests & UVM_DO_MEM_WALK &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!(bool).get_by_name("REG::" ~ model.get_full_name(),
					   "NO_MEM_WALK_TEST", 0) is null ) {
      uvm_mem_walk_seq seq = uvm_mem_walk_seq.type_id.create("mem_walk_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.",
	       UVM_LOW);
    }

  }
}

