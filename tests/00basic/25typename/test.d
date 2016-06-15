//---------------------------------------------------------------------- 
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
import uvm.meta.meta;

class test_root: uvm_root{
  mixin uvm_component_utils;
}

class TestBench: RootEntity{
  uvm_entity!(test_root) tb;
}
  
class xyz {}

class bar(T=int) {}

class foo(T=int, int W=24): T
{ }

class test: uvm_test{
  mixin uvm_component_utils;
  @UVM_NO_AUTO test[2] list;

  this(string name, uvm_component parent=null) {
    super(name, parent);

    string typename;


    foo !(bar!xyz, 88) f = new foo!(bar!xyz, 88)();
    bar !(xyz) b = f;

    typename = qualifiedTypeName!(typeof(f));

    writeln("\nGOLD-FILE-START\n", typename, "\nGOLD-FILE-END\n");
  }
  
}

int main(string [] argv){
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}

				 
