// 
// -------------------------------------------------------------
//    Copyright 2010 Cadence.
//    Copyright 2011 Mentor Graphics Corporation
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

//
// TITLE: HDL Paths Checking Test Sequence
//

//
// class: uvm_reg_mem_hdl_paths_seq
//
// Verify the correctness of HDL paths specified for registers and memories.
//
// This sequence is be used to check that the specified backdoor paths
// are indeed accessible by the simulator.
// By default, the check is performed for the default design abstraction.
// If the simulation contains multiple models of the DUT,
// HDL paths for multiple design abstractions can be checked.
// 
// If a path is not accessible by the simulator, it cannot be used for 
// read/write backdoor accesses. In that case a warning is produced. 
// A simulator may have finer-grained access permissions such as separate 
// read or write permissions.
// These extra access permissions are NOT checked.
//
// The test is performed in zero time and
// does not require any reads/writes to/from the DUT.
//

class uvm_reg_mem_hdl_paths_seq: uvm_reg_sequence !(uvm_sequence!(uvm_reg_item))
{
  // Variable: abstractions
  // If set, check the HDL paths for the specified design abstractions.
  // If empty, check the HDL path for the default design abstraction,
  // as specified with <uvm_reg_block::set_default_hdl_path()>
  string abstractions[];
    
  mixin uvm_object_utils_begin;
    
  this(string name="uvm_reg_mem_hdl_paths_seq") {
    super(name);
  }

  // virtual task body();

  // task
  public void frame() {
    if(model is null) {
      uvm_report_error("uvm_reg_mem_hdl_paths_seq",
		       "Register model handle is null");
      return;
    }

    uvm_info("uvm_reg_mem_hdl_paths_seq",
	     "checking HDL paths for all registers/memories in " ~
	     model.get_full_name(), UVM_LOW);

    if (abstractions.length == 0) {
      do_block(model, "");
    }
    else {
      foreach (abstraction; abstractions) {
	do_block(model, abstraction);
      }
    }

    uvm_info("uvm_reg_mem_hdl_paths_seq",
	     "HDL path validation completed ",UVM_LOW);
        
  }


  // Any additional steps required to reset the block
  // and make it accessible

  // virtual task reset_blk(uvm_reg_block blk);
  // task
  public void reset_blk(uvm_reg_block blk) {}


  protected void do_block(uvm_reg_block blk,
			  string kind) {
    uvm_info("uvm_reg_mem_hdl_paths_seq",
	     "Validating HDL paths in " ~ blk.get_full_name() ~
	     " for " ~ (kind == "") ? "default" : kind ~
	     " design abstraction", UVM_MEDIUM);

    // Iterate over all registers, checking accesses
    uvm_reg       regs[];
    blk.get_registers(regs, UVM_NO_HIER);
    foreach (reg; regs) {
      check_reg(reg, kind);
    }
       
    uvm_mem       mems[];
    blk.get_memories(mems, UVM_NO_HIER);
    foreach (mem; mems) {
      check_mem(mem, kind);
    }
    
    uvm_reg_block blks[];
          
    blk.get_blocks(blks);
    foreach (blk; blks) {
      do_block(blk, kind);
    }
  }

  protected void check_reg(uvm_reg r,
			   string kind) {

    uvm_hdl_path_concat paths[];

    // avoid calling get_full_hdl_path when the register has not path for this abstraction kind
    if(!r.has_hdl_path(kind)) {
      return;
    }

    r.get_full_hdl_path(paths, kind);
    if (paths.length == 0) {
      return;
    }

    foreach(path; paths) {
      foreach (slice; path.slices) {
	string p_ = slice.path;
	uvm_reg_data_t d;
	if (!uvm_hdl_read(p_,d))
	  uvm_error("uvm_reg_mem_hdl_paths_seq",
		    format("HDL path \"%s\" for register \"%s\" is not readable",
			   p_, r.get_full_name()));
	if (!uvm_hdl_check_path(p_))
	  uvm_error("uvm_reg_mem_hdl_paths_seq",
		    format("HDL path \"%s\" for register \"%s\" is not accessible",
			   p_, r.get_full_name()));
      }
    }
  }
 

  protected void check_mem(uvm_mem m,
			   string kind) {
    uvm_hdl_path_concat paths[];

    // avoid calling get_full_hdl_path when the register has not path for this abstraction kind
    if(!m.has_hdl_path(kind)) {
      return;
    }

    m.get_full_hdl_path(paths, kind);
    if (paths.length == 0) {
      return;
    }

    foreach(path; paths) {
      foreach (slice; path.slices) {
	string p_ = slice.path;
	if(!uvm_hdl_check_path(p_))
	  uvm_error("uvm_reg_mem_hdl_paths_seq",
		    format("HDL path \"%s\" for memory \"%s\" is not accessible",
			   p_, m.get_full_name()));
      }
    }
  }
}
