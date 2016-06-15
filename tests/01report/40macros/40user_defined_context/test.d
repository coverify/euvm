//---------------------------------------------------------------------- 
//   Copyright 2012 Mentor Graphics Corporation
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

/*
Test that the report catcher can catch messages issued by non-uvm_components
based on the user-defined context (i.e. the source of the message). The
source of the message for uvm_components is usually the hierarchical name
(get_full_name).  For non-UVM components the full name is always "reporter",
representing uvm_top. This means you can't filter non-uvm_component reports
based on their context. This test proves that you now can.


report(uvm_severity severity,
      string name,
      string id,
      string message,
      int verbosity_level,
      string filename,
      int line,
      uvm_report_object client
*/

import esdl;
import uvm;
import std.stdio;

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class test_root:uvm_root
{
  mixin uvm_component_utils;

  override void initial()
  {
    fork(
	 {
	   uvm_report_handler msg = new uvm_report_handler() ;
	   uvm_report_message rm = new uvm_report_message();
	   catcher rc = new catcher();
	   uvm_report_cb.add(null,rc);

	   writeln("UVM TEST EXPECT 1 UVM_ERROR");

	   wait(1.nsec);
	   //msg.report(UVM_ERROR, "some_context",       "SOME_ID", "Issuing message that should be filtered");
	   //msg.report(UVM_ERROR, "some_other_context", "SOME_ID", "Issuing message that should not be filtered", UVM_MEDIUM, `__FILE__, `__LINE__); // UVM TEST RUN-TIME FAILURE
	   rm.set_context("some_context");
	   uvm_error("SOME_ID", "Issuing message that should be filtered", rm);
	   rm.set_context("some_other_context");
	   uvm_error("SOME_ID", "Issuing message that should not be filtered", rm);
	 },
	 {
	   run_test();
	 }
	 );
  }
}


bool ok = 0;

class catcher: uvm_report_catcher
{
  override  action_e do_catch()
  {
    if (get_context() == "some_context")
      {
        set_severity(UVM_INFO);
        ok = 1;
        return CAUGHT;
      }
    return THROW;
  }
}


// dummy test to satisfy regression environment's expectation of a uvm test
class test : uvm_test
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent = null)
  {
    super(name, parent);
  }
  override void  run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
    wait(10.nsec);
    phase.drop_objection(this);
  }
  override void report()
  {
    if (ok)
      {
	writeln("** UVM TEST PASSED **\n");
      }
    else
      {
        writeln("** UVM TEST FAILED! **\n");
      }
  }
}


int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(2, 0);
  tb.elaborate("tb", argv);
  tb.simulate();
  return 0;
}

