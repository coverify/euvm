//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
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
//----------------------------------------------------------------

import esdl;
import uvm;


class test: uvm_test {

    mixin uvm_component_utils;
  
    this(string name, uvm_component parent = null)
    {
      super(name, parent);
    }
  
    override void report_phase(uvm_phase phase)
    {
      import std.stdio;
      // to be done
      
      version(BAR)
      {
	//if ($test$plusargs("OK")) 
	uvm_info("PASSED", "** UVM TEST PASSED **\n", UVM_NONE);
      }
      else
	{
	  uvm_error("WRONGVER", "** UVM TEST FAILED **\n");
	}
    }
}

int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.elaborate("tb", argv);
  return tb.start(); 
}



