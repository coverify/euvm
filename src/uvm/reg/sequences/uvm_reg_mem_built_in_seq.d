//
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
// Copyright 2010 Synopsys, Inc.
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
// Class -- NODOCS -- uvm_reg_mem_built_in_seq
//
// Sequence that executes a user-defined selection
// of pre-defined register and memory test sequences.
//
//------------------------------------------------------------------------------

module uvm.reg.sequences.uvm_reg_mem_built_in_seq;

import uvm.reg.uvm_reg_sequence: uvm_reg_sequence;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_block: uvm_reg_block;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_model: uvm_hier_e, uvm_door_e, uvm_status_e, uvm_reg_data_t,
  uvm_check_e, UVM_DO_ALL_REG_MEM_TESTS, UVM_DO_REG_HW_RESET, UVM_DO_REG_BIT_BASH,
  UVM_DO_REG_ACCESS, UVM_DO_MEM_ACCESS, UVM_DO_SHARED_ACCESS, UVM_DO_MEM_WALK;


import uvm.base.uvm_object_defines;
import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.seq.uvm_sequence: uvm_sequence;

import esdl;
import std.string: format;

import uvm.reg.sequences.uvm_mem_access_seq: uvm_mem_access_seq;
import uvm.reg.sequences.uvm_mem_walk_seq: uvm_mem_walk_seq;
import uvm.reg.sequences.uvm_reg_access_seq: uvm_reg_access_seq;
import uvm.reg.sequences.uvm_reg_bit_bash_seq: uvm_reg_bit_bash_seq;
import uvm.reg.sequences.uvm_reg_hw_reset_seq: uvm_reg_hw_reset_seq;
import uvm.reg.sequences.uvm_reg_mem_shared_access_seq: uvm_reg_mem_shared_access_seq;

// import uvm.reg.sequences.uvm_reg_mem_hdl_paths_seq;

// @uvm-ieee 1800.2-2020 auto E.8.1
class uvm_reg_mem_built_in_seq: uvm_reg_sequence!(uvm_sequence!uvm_reg_item)
{

  mixin uvm_object_utils;

  // @uvm-ieee 1800.2-2020 auto E.8.3.1
  this(string name="uvm_reg_mem_built_in_seq") {
    super(name);
  }

  // Variable -- NODOCS -- model
  //
  // The block to be tested. Declared in the base class.
  //
  //| uvm_reg_block model; 


  // Variable -- NODOCS -- tests
  //
  // The pre-defined test sequences to be executed.
  //
  Bit!64 tests = UVM_DO_ALL_REG_MEM_TESTS;


  // Task -- NODOCS -- body
  //
  // Executes any or all the built-in register and memory sequences.
  // Do not call directly. Use seq.start() instead.
   
  // @uvm-ieee 1800.2-2020 auto E.8.3.2
  // task
  override public void body() {

    if (model is null) {
      uvm_error("uvm_reg_mem_built_in_seq", "Not block or system specified to run sequence on");
      return;
    }

    uvm_report_info("START_SEQ", "\n\nStarting " ~ get_name() ~ " sequence...\n",
		    uvm_verbosity.UVM_LOW);

    if (((tests & UVM_DO_REG_HW_RESET) != 0) &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_HW_RESET_TEST", 0) is null ) {
      uvm_reg_hw_reset_seq seq = uvm_reg_hw_reset_seq.type_id.create("reg_hw_reset_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.", uvm_verbosity.UVM_LOW);
    }

    if (((tests & UVM_DO_REG_BIT_BASH) != 0) &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_BIT_BASH_TEST", 0) is null ) {
      uvm_reg_bit_bash_seq seq = uvm_reg_bit_bash_seq.type_id.create("reg_bit_bash_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.", uvm_verbosity.UVM_LOW);
    }

    if (((tests & UVM_DO_REG_ACCESS) != 0) &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_ACCESS_TEST", 0) is null ) {
      uvm_reg_access_seq seq = uvm_reg_access_seq.type_id.create("reg_access_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.", uvm_verbosity.UVM_LOW);
    }

    if (((tests & UVM_DO_MEM_ACCESS) != 0) &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_MEM_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_MEM_ACCESS_TEST", 0) is null ) {
      uvm_mem_access_seq seq = uvm_mem_access_seq.type_id.create("mem_access_seq");
      seq.model = model;
      seq.start(null,this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.", uvm_verbosity.UVM_LOW);
    }

    if (((tests & UVM_DO_SHARED_ACCESS) != 0) &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_SHARED_ACCESS_TEST", 0) is null ) {
      uvm_reg_mem_shared_access_seq seq =
	uvm_reg_mem_shared_access_seq.type_id.create("shared_access_seq");
      seq.model = model;
      seq.start(null,this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.", uvm_verbosity.UVM_LOW);
    }

    if (((tests & UVM_DO_MEM_WALK) != 0) &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_REG_TESTS", 0) is null &&
	uvm_resource_db!bool.get_by_name("REG::" ~ model.get_full_name(),
					 "NO_MEM_WALK_TEST", 0) is null ) {
      uvm_mem_walk_seq seq = uvm_mem_walk_seq.type_id.create("mem_walk_seq");
      seq.model = model;
      seq.start(null, this);
      uvm_info("FINISH_SEQ", "Finished " ~ seq.get_name() ~ " sequence.", uvm_verbosity.UVM_LOW);
    }

  }
}
