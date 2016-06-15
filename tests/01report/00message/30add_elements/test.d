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

class test_root: uvm_root
{
  mixin uvm_component_utils;
  override void initial()
  {
     static uvm_coreservice_t cs_ = uvm_coreservice_t.get();

     static uvm_factory fact = cs_.get_factory();
     static my_server server = new my_server;
     static my_catcher catcher = new my_catcher;
     uvm_report_cb.add(null, catcher);
     uvm_report_server.set_server(server);
     fact.set_type_override_by_type(uvm_report_handler.get_type(), my_handler.get_type());
     fact.print();
  }
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class my_catcher: uvm_report_catcher
{
  override action_e do_catch()
  {
    add_string ("catcher_name", get_name());
    return THROW;
  }
}

class my_server: uvm_default_report_server
{
  override string compose_report_message(uvm_report_message report_message, string report_object_name = "")
  {
    report_message.add_string("server_name", get_name());
    
    compose_report_message = super.compose_report_message(report_message, report_object_name);
  }
}

class my_handler: uvm_report_handler
{
  mixin uvm_object_utils;

  this(string name = "my_report_handler")
  {
    super(name);
  }

  override void process_report_message(uvm_report_message report_message)
  {
    report_message.add_string("handler_name", get_name());
    super.process_report_message(report_message);
  }
}


class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
    super(name, parent);
  }

  override void uvm_process_report_message(uvm_report_message report_message)
  {
    report_message.add_string ("component_name", get_name());
    super.uvm_process_report_message(report_message);
  }
  
  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);

    writeln("START OF GOLD FILE");
    uvm_info("ID0", "Message 0", UVM_MEDIUM);
    writeln("END OF GOLD FILE");

    phase.drop_objection(this);
  }
}

void main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  tb.simulate();
}
