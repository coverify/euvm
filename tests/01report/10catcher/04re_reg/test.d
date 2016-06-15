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

class test_root:uvm_root
{
  mixin uvm_component_utils;
}

class my_catcher: uvm_report_catcher
{
    static int seen = 0;
  //  mixin uvm_object_utils;

  // this(string name)
  // {
  //   super(name);
  // }

  override  action_e do_catch()
    {
     import std.stdio;
     writeln("Caught a message...\n");
      seen++;
      return CAUGHT;
    }
}

class test:  uvm_test
{
    
  bool pass = 1;


  
  my_catcher ctchr ;
  my_catcher ctchr1 ;
  my_catcher ctchr2 ;
  my_catcher ctchr3;

  mixin uvm_component_utils;
  
  // this(){
  //   super("test",null);
  // }

  this(string name, uvm_component parent = null)
  {
      super(name, parent);
      ctchr = new my_catcher;
      ctchr1 = new my_catcher;
      ctchr2 = new my_catcher;
      ctchr3= new my_catcher;
  }

  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
      
    import std.stdio;
      
    writeln("UVM TEST - WARNING expected since re_registering a default catcher\n");
        
    //add_report_default_catcher(ctchr, UVM_APPEND);
    uvm_report_cb.add(null, ctchr);
    uvm_report_cb.add(null, ctchr);
    
  
    uvm_report_cb.remove(null, ctchr);
    
    phase.drop_objection(this);
  
    }

  override void report()
  {
      import std.stdio;
      writeln("** UVM TEST PASSED **\n");
  }
}


int main( string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("test", argv);
  return tb.simulate();  
}
