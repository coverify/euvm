//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
//   Copyright 2011 Mentor Graphics Corporation
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


class TestBench: RootEntity
  {
    uvm_entity!(test_root) tb;
    // override void doFinish() {
    //   uvm_report_server srvr;
    //   srvr = tb.get_root.uvm_report_server.get_server();
    //   srvr.report_summarize();
    // }
}

class test_root:uvm_root
{
  mixin uvm_component_utils;
}

class my_class: uvm_object
{
  int foo = 3;
  string bar = "hi there";
  //mixin uvm_component_utils;
  this (string name = "unnamed-my_class")
  {
    super(name);
  }
}


class test : uvm_test
{
  mixin uvm_component_utils;
 
  this(string name, uvm_component parent = null)
  {
     super(name, parent);
  }

  override void  run_phase(uvm_phase phase)
  {
    int my_int;
    string my_string;
    my_class my_obj;
    uvm_report_message msg;

    phase.raise_objection(this);

    my_int = 5;
    my_string = "foo";
    my_obj = new my_class("my_obj");

    uvm_info("TEST", "Testing message...", UVM_LOW, msg,
	     uvm_message_add!("my_color", "red"),
	     uvm_message_add!(my_int, UVM_DEC, "", UVM_LOG),
	     uvm_message_add!(my_string, "", UVM_LOG|UVM_RM_RECORD),
	     uvm_message_add!(my_obj)
	     );

    writeln("START OF GOLD FILE");
    msg.print();
    writeln("END OF GOLD FILE");

    phase.drop_objection(this);
  }
}

int main( string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("test", argv);
  return tb.simulate();  
}
