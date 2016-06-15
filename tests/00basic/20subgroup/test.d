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


class TestBench: RootEntity
{
    uvm_entity!(test_root) tb;
}

class test_root: uvm_root
{
  mixin uvm_component_utils;

  override void initial() {
    set_simulation_status(1);
    super.initial();
  }

}
  
class test: uvm_test
{

  mixin uvm_component_utils;

  this() {
    super("test", null);//nt registered with factory error
  }

  
  this(string name="", uvm_component parent = null)
  {
    super(name, parent);
  }
  
  override void run()
  {
    uvm_top.stop_request();
  }

  override void report()
  {
    import std.stdio;
    writeln("** UVM TEST PASSED **");
    set_simulation_status(0);
  }
}

int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("test", argv);
  return tb.simulate();
}
 

 
