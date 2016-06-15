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
//This test is an example of an expected run-time failure
//

//macros.svh
import esdl;
import uvm;

import std.stdio;

class objA: uvm_object {}

class objB: uvm_object {}

class test_root: uvm_root
{
  mixin uvm_component_utils;
  override void initial()
  {
    objA a;
    objB b;
    uvm_object obj;
   
    a = new objA;
    obj = a;
    b = cast(objB) obj; // UVM TEST RUN-TIME FAILURE 
    if (b is null) {
      uvm_info("PASSED", "*** UVM TEST PASSED ***", UVM_NONE);
    }
  }
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}

