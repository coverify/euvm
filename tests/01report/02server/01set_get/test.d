//---------------------------------------------------------------------- 
//   Copyright 2010 Cadence Design Systems.
//   Copyright 2010 Mentor Graphics Corporation
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
//---------------------------------------------------------------------

import esdl;
import uvm;
import std.stdio;


class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

uint cnt = 0;
bool success =0;

class my_server: uvm_default_report_server
{
  alias compose_report_message =uvm_default_report_server.compose_report_message;
  override string compose_report_message(uvm_report_message report_message,
				   string report_object_name = "")
  {
    
    cnt++;
    return "MY_SERVER: " ~
      super.compose_report_message(report_message, report_object_name);
  }
  override void report_summarize(UVM_FILE file=0)
  {
     if (success == 1)
       {
       writeln("**** UVM TEST PASSED ****");
       writeln("--- UVM Report Summary ---");
       writeln("");
       writeln("** Report counts by severity");
       writeln("UVM_INFO :    6");
       writeln("UVM_WARNING :    0");
       writeln("UVM_ERROR :    0");
       writeln("UVM_FATAL :    0");
       }
    else
      {
       writeln("**** UVM TEST FAILED ****");
       super.report_summarize(file) ;
      }
  }
}

class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent){
    super(name, parent);
   
  }


override void run_phase(uvm_phase phase)
{
  my_server serv = new my_server;
  uvm_info("MSG1", "Some message", UVM_LOW);
  uvm_info("MSG2", "Another message", UVM_LOW);
    
  uvm_report_server.set_server(serv);
  
  uvm_info("MSG1", "Some message again", UVM_LOW);
  uvm_info("MSG2", "Another message again", UVM_LOW);
    
}

  override void report()
  {
    uvm_report_server serv = uvm_report_server.get_server();
    if(serv.get_id_count("MSG1") == 2 && serv.get_id_count("MSG2") == 2)
      {
	writeln("**** UVM TEST PASSED ****");
      }
    else{
      writeln("**** UVM TEST FAILED ****");
    }
  }
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(2, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
