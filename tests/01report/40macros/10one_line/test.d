//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
//   Copyright 2011 Mentor Graphics Corporation
//   Copyright 2016 Coverify Systems Technology
//   All Rights Reserved Worldwide 
// 
//   Licensed under the Apache License, Version 2.0 (the 
//   "License"); you may not use this file except in 
//   compliance with the License.  You may obtain a copy of 
//   the License at 
// 
//       http://www.apache.org/licenses/LICENSE-2.0 
// 
//   Unless required by applicable law or agreed to in 
//   writing, software distributed under the License is 
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
//   CONDITIONS OF ANY KIND, either express or implied.  See 
//   the License for the specific language governing 
//   permissions and limitations under the License. 
//----------------------------------------------------------------------

import esdl;
import uvm;
import std.stdio;

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

//module top;

//import uvm_pkg::*;
//include "uvm_macros.svh"

class test_root:uvm_root
{
  mixin uvm_component_utils;
  override void initial()
  {
    my_catcher catcher = new my_catcher();
    uvm_report_cb.add(null, catcher);

    run_test();
  }
  //override void initial()
}

class my_catcher: uvm_report_catcher
{
  override  action_e do_catch()
    {

      if(get_severity() == UVM_FATAL)
	set_severity(UVM_ERROR);

      return THROW;
    }
}

class test: uvm_test
{

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
     super(name, parent);
  }

  override void  run_phase(uvm_phase phase)
  {

    uvm_coreservice_t cs_ = uvm_coreservice_t.get();

    uvm_report_message msg;
    uvm_root top = cs_.get_root();

    phase.raise_objection(this);

    writeln("GOLD-FILE-START");

    uvm_info("I_TEST", "Testing info macro...", UVM_LOW);
    uvm_warning("W_TEST", "Testing warning macro...");
    uvm_error("E_TEST", "Testing error macro...");
    uvm_fatal("F_TEST", "Testing fatal macro...");

    uvm_info_context("I_TEST", "Testing info macro...", UVM_LOW, top);
    uvm_warning_context("W_TEST", "Testing warning macro...", top);
    uvm_error_context("E_TEST", "Testing error macro...", top);
    uvm_fatal_context("F_TEST", "Testing fatal macro...", top);

    writeln("GOLD-FILE-END");

    phase.drop_objection(this);
  }

}

int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(2, 0);
  tb.elaborate("tb", argv);
  if (tb.simulate() == 0) return 1;
  else return 0;
}

