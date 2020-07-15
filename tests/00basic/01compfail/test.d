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

//
// This test is an example of an expected compile-time failure
//

import esdl;
import uvm;
import std.stdio;

class test: uvm_test
{
  mixin uvm_component_utils;
  
  this(string name, uvm_component parent){
    super(name, parent);
  }

  override void report_phase(uvm_phase phase) {
    uvm_component comp;
    static assert(__traits(compiles, comp = UVM_NONE) == false);
    writeln("** UVM TEST PASSED **\n");
  }
}
  
int main(string[] argv) {
  uvm_tb tb = new uvm_tb;
  tb.multicore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
