//---------------------------------------------------------------------- 
//   Copyright 2010-2011 Cadence Design Systems, Inc. 
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

// Tests that the pre_abort() callback is called for all components on
// exit.

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

uint[uvm_component] aborts;

class base: uvm_component
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent){
    super(name, parent);
  }


  override void pre_abort()
  {
    uvm_info("preabort", "In pre_abort...", UVM_NONE);
    if(this !in aborts){
      aborts[this]++;
    }
    else
      {
	aborts[this] = 1;
      }
  }
}

class A: base
{
  mixin uvm_component_utils;
  this(string name, uvm_component parent){
    super(name, parent);}
}

class B: base
{
  A aa, aa2;
  mixin uvm_component_utils;
  this(string name, uvm_component parent){
    super(name, parent);
  
    aa = new A("aa", this);
    aa2 = new A("aa2", this);
  }
}

class test: base
{
  B bb;
  mixin uvm_component_utils;
  this(string name, uvm_component parent){
    super(name, parent);
  
    bb = new B("bb", this);
  }
  
  override void run()
  {
    writeln("UVM TEST EXPECT 1 UVM_ERROR");
    set_report_max_quit_count(1);

    uvm_error("someerror", "Create an error condition");
  }


  override void pre_abort()
  {
    bool failed = 0;
    super.pre_abort();

    if(aborts.length != 4)
      { // begin
	failed = 1;
	writeln("**** UVM TEST FAILED, %0d pre_aborts called, expected 4", aborts.length);
	// end
      }

    else if(aborts[this] != 1)
      //begin
      { failed = 1;
	writeln("**** UVM TEST FAILED, %0d pre_abort called from %s, expected 1", aborts.length, bb.aa.get_full_name());
      }
    //end

    else if(aborts[bb] != 1)
      //begin
      {  failed = 1;
	writeln("**** UVM TEST FAILED, %0d pre_abort called from %s, expected 1", aborts.length, bb.get_full_name());
	//end
      }

    else if(aborts[bb.aa] != 1)// begin
      {failed = 1;
	writeln("**** UVM TEST FAILED, %0d pre_abort called from %s, expected 1", aborts.length, bb.aa.get_full_name());
	// end
      }

    else if(aborts[bb.aa2] != 1) //begin
      { failed = 1;
	writeln("**** UVM TEST FAILED, %0d pre_abort called from %s, expected 1", aborts.length, bb.aa2.get_full_name());
	//end 
      }
  
    else if(failed == 0)
      writeln("**** UVM TEST PASSED ****");
  }
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}


