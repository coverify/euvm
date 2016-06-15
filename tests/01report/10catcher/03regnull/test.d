//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
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

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class my_catcher: uvm_report_catcher
{
  static uint seen = 0;
  override  action_e do_catch()
  {
    writeln("Caught a message...\n");
    seen++;
    return CAUGHT;
  }
}

class test: uvm_test
{
  bool  pass = 1; // Bit! pass ???? needs to be added 
  
  my_catcher ctchr;
  my_catcher ctchr1;
  my_catcher ctchr2;
  my_catcher ctchr3;

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
    super(name, parent);
  }

  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
     writeln("UVM TEST - ERROR expected since registering a default catcher with NULL handle\n");
        
    //add_report_default_catcher(uvm_report_catcher catcher, uvm_apprepend ordering = UVM_APPEND);
    uvm_report_cb.add(null,ctchr);// shud have a component handle instead of null

    writeln("UVM TEST EXPECT 1 UVM_ERROR\n");
    phase.drop_objection(this);
  }

  override void report()
  {
    writeln("** UVM TEST PASSED **\n");
  }
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  auto error = tb.simulate();	// error is expected
  if (error != 0) return 0;
  else return 1;
}

