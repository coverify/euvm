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

import uvm;
import esdl;
import std.stdio;

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class catcher_return_caught: uvm_report_catcher
{
  string id;

  this(string id){
    this.id = id;
  }

  override action_e do_catch(){
    if(get_id() != id)
      return THROW;
    writeln("An instance of catcher_return_caught, Caught a message...\n");
    writeln("===============================================\n");

    return CAUGHT;
  }
}

class catcher_return_caught_call_issue: uvm_report_catcher
{
  string id;

  this(string id){
    this.id = id;
  }
  override action_e do_catch(){
    if(get_id() != id)
      return THROW;
    writeln("An instance of catcher_return_caught_call_issue, Caught a message...calling issue()...\n");
    writeln("==============================================\n");
    issue();
    return CAUGHT;
  }
}

class catcher_return_throw: uvm_report_catcher
{
  string id;
  this(string id){
    this.id = id;
  }

  override action_e do_catch(){
    if(get_id() != id)
      return THROW;
    writeln("An instance of catcher_return_throw, Caught a message...\n");
    writeln("=================================================\n");
    return THROW;
  }
}

class catcher_return_throw_call_issue: uvm_report_catcher
{
  string id;
  this(string id){
    this.id = id;
  }

  override action_e do_catch(){
    if(get_id() != id)
      return THROW;
    writeln("An instance of catcher_return_throw_call_issue, Caught a message...calling issue()...\n");
    writeln("=======================================\n");
    issue();
    return THROW;
  }
}

class catcher_return_unknown_action: uvm_report_catcher
{
  string id;
  this(string id)
  {
    this.id = id;
  }

  override action_e do_catch(){
    if(get_id() != id)
      return THROW;
    writeln("An instance of catcher_return_unknown_action, Caught a message...\n");
    writeln("=========================================\n");
    return UNKNOWN_ACTION;
  }
}

class test: uvm_test
{
  int pass1 = 1;
  int pass2 = 1;

  mixin uvm_component_utils;

  this(string name ="", uvm_component parent = null){
    super(name, parent);
  }
  
  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
    writeln("UVM TEST - Catchers which return CAUGHT/THROW and call issue() \n");
      
    catcher_return_caught  ctchr1 = new catcher_return_caught("Catcher1");
    catcher_return_caught_call_issue ctchr2 = new catcher_return_caught_call_issue("Catcher2");
    catcher_return_throw  ctchr3 = new catcher_return_throw("Catcher3");
    catcher_return_throw_call_issue ctchr4 = new catcher_return_throw_call_issue("Catcher4");
    catcher_return_unknown_action ctchr5 = new catcher_return_unknown_action("Catcher5");
        
    writeln("===========================================\n");
    //add_report_id_catcher(string id, uvm_report_catcher catcher, uvm_apprepend ordering = UVM_APPEND);
    writeln("adding a catcher of type catcher_return_caught  with id of Catcher1\n");
    uvm_report_cb.add(null,ctchr1);
          
    writeln("adding a catcher of type catcher_return_caught_call_issue with id of Catcher2\n");
    uvm_report_cb.add(null,ctchr2);

    writeln("adding a catcher of type catcher_return_throw  with id of Catcher3\n");
    uvm_report_cb.add(null,ctchr3);
          
    writeln("adding a catcher of type catcher_return_throw_call_issue with id of Catcher4\n");
    uvm_report_cb.add(null,ctchr4);

    writeln("adding a catcher of type catcher_return_unknown_action with id of Catcher5\n");
    uvm_report_cb.add(null,ctchr5);

    writeln("===========================================\n");
        
    uvm_info("Catcher1", "This message is for Catcher1", UVM_MEDIUM);
    uvm_info("Catcher2", "This message is for Catcher2", UVM_MEDIUM);
    uvm_info("Catcher3", "This message is for Catcher3", UVM_MEDIUM);
    uvm_info("Catcher4", "This message is for Catcher4", UVM_MEDIUM);
    uvm_info("Catcher5", "This message is for Catcher5 which calls an UNKNOWN_ACTION", UVM_MEDIUM);
    uvm_info("XYZ", "This message is for No One", UVM_MEDIUM);
  
    writeln("UVM TEST EXPECT 1 UVM_ERROR\n");
    phase.drop_objection(this);
  }
  
  override void report(){
    writeln("** UVM TEST PASSED **\n"); 
  }
}

int main(string [] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
