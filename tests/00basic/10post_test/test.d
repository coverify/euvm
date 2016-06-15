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

class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override void run_phase(uvm_phase phase) { }

  override void report_phase(uvm_phase phase){
    uvm_error("FAILED", "** UVM TEST FAILED **\n");
  }
}

int main(string [] argv){
  TestBench tb = new TestBench;
  tb.multiCore(0,0);
  tb.elaborate("tb", argv);
  if (tb.simulate() == 1) {	// fialure is expected
    return 0;
  }
  else {
    return 1;
  }
}
