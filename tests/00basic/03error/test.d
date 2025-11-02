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
import std.stdio: writeln;

class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent){
    super(name, parent);
  }

  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
    uvm_error("Test", "Error 1...");
    uvm_error("Test", "Error 2...");
    uvm_error("Test", "Error 3...");
    writeln("UVM TEST EXPECT 3 UVM_ERROR\n");
    phase.drop_objection(this);
    // uvm_top.stop_request(); 
  }
  
  override void report_phase(uvm_phase phase) {
    writeln("** UVM TEST PASSED **");
  }
}

int main(string[] argv) {
  auto tb = new uvm_tb;
  tb.elaborate("tb", argv);
  if (tb.start() == 1) {	// error is expected
    return 0;
  }
  else {
    return 1;
  }
}
