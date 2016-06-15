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

import uvm;
import esdl;
import std.stdio;

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity !(test_root) tb;
}

class my_catcher: uvm_report_catcher
{
  static int seen = 0;
  override action_e do_catch(){
    writeln("Caught a message...\n");
    seen++;
    return CAUGHT;
  }
}

class test: uvm_test
{
  bool pass = 1;

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
    super(name, parent);
  }

  override void run_phase(uvm_phase phase)
  {
    my_catcher ctchr = new my_catcher();
    phase.raise_objection(this);
    writeln("UVM TEST EXPECT 2 UVM_ERROR\n");
    uvm_error("Test", "Error 1...");
    if(my_catcher.seen != 0)
      {
	writeln("ERROR: Message was caught with no catcher installed!\n");
	pass = 0;
      }
    uvm_report_cb.add(null, ctchr);
    uvm_error("Test", "Error 2...");

    if(my_catcher.seen != 1){
      writeln("ERROR: Message was NOT caught with default catcher installed!\n");
      pass=0;
    }
     uvm_info("XYZ", "Medium INFO...", UVM_MEDIUM);

    if(my_catcher.seen != 2){
      writeln("ERROR: Message was NOT caught with default catcher installed!\n");
      pass = 0;
    }
    uvm_fatal("Test", "FATAL...");

    if(my_catcher.seen !=3)
      {
	writeln("ERROR: Message was NOT caught with default catcher installed!\n");
	pass = 0;
      }
    
    uvm_report_cb.remove(null, ctchr);
    uvm_error("Test", "Error 3...");
    if(my_catcher.seen != 3){
    writeln("ERROR: Message was caught after all catcher removed!\n");
    pass=0;
    }
  phase.drop_objection(this);
  }

  override void report(){
    if(pass) writeln("** UVM TEST PASSED **\n");
    else writeln("** UVM TEST FAILED! **\n");
  }
}

int main(string [] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0,0);
  tb.elaborate("tb", argv);
  auto error = tb.simulate();	// error is expected
  if (error != 0) return 0;
  else return 1;
}
