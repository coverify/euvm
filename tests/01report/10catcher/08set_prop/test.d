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
import std.stdio;

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

class my_catcher: uvm_report_catcher //Default Catcher modifying the message
{
  override  action_e do_catch() //action_e is an enum that are UNKNOWN_ACTION , THROW, CAUGHT
  {
    writeln("Default Catcher Caught a Message...\n");
    if(get_message() == "SQUARE")
      {
	writeln("Default Catcher modified the message\n");
	set_message("Modifying SQUARE to TRIANGLE");
      }
    if(get_message() == "CIRCLE")
      {
	writeln("Default Catcher modified the action to UNKNOWN_ACTION\n " );
	set_action(UNKNOWN_ACTION);
	return UNKNOWN_ACTION;
      }
    return THROW;
  }
}

class my_catcher1: uvm_report_catcher// Severity Catcher modifying the message severity
{
  override action_e do_catch()
  {
    writeln("Severity Catcher Caught a Message...\n");
    if(get_message() == "MSG2")
      {
	writeln("Severity Catcher is Changing the severity from UVM_WARNING to UVM_ERROR\n");
	set_severity(UVM_ERROR);
      }
    return THROW;
  }
}

class my_catcher2: uvm_report_catcher// Severity Catcher modifying the message severity
{
  override action_e do_catch()
  {
    writeln("ID Catcher Caught a Message...\n");
    if(get_message() == "MSG3")
      {
	writeln("ID Catcher is Changing the ID from Orion to Jupiter\n");
	set_id("Jupiter");
      }
    return THROW;
  }
}

class my_catcher3: uvm_report_catcher // Severity Catcher modifying the message severity
{
  override action_e do_catch()
  {
    uint verbo;
    verbo = this.get_verbosity();
  
    if (verbo > UVM_HIGH)
      {
	writeln("A: ID Catcher3  is Changing the verbosity from %0d to %0d \n", verbo, UVM_DEBUG);
	this.set_verbosity(UVM_DEBUG);
	writeln("A: ID Catcher3 new verbosity is %d \n", this.get_verbosity());
      }
    else 
      {
	writeln("B: ID Catcher3 is Changing the verbosity from %0d to %0d \n", verbo, UVM_LOW);
	this.set_verbosity(UVM_LOW);
	writeln("B: ID Catcher3 new verbosity is %0d \n", this.get_verbosity());
      }
    return THROW;
  }
}
   

class test: uvm_test
{
  bool pass = 1;

  
  my_catcher ctchr;
  my_catcher1 ctchr1;
  my_catcher2 ctchr2;
  my_catcher3 ctchr3;

  mixin uvm_component_utils;
  
  this(string name, uvm_component parent = null)
  {
    super(name, parent);
    ctchr  = new my_catcher;
    ctchr1 = new my_catcher1;
    ctchr2 = new my_catcher2;
    ctchr3 = new my_catcher3;
  }

  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
    writeln("UVM TEST - Changing catcher severity, id, message, action, verbosity \n");
        
    //add_report_default_catcher(uvm_report_catcher catcher, uvm_apprepend ordering = UVM_APPEND);
    uvm_report_cb.add(null,ctchr);
    uvm_info("ctchr", "SQUARE", UVM_MEDIUM);
    
    uvm_report_cb.add(null, ctchr1);
    uvm_warning("ctchr1", "MSG2");

    
    uvm_report_cb.add(null, ctchr2);
    uvm_info("Orion", "MSG3", UVM_MEDIUM);

    writeln("Calling a message CIRCLE so the Default catcher modify its actions to UNKNOWN_ACTION");
    
    uvm_info("ctchr", "CIRCLE", UVM_MEDIUM);
    
   
    uvm_report_cb.add(null,ctchr3); 
    uvm_info("MyOtherID", "Message1 Sending a UVM_MEDIUM message", UVM_MEDIUM);
    uvm_info("MyOtherID", "Message2 Sending a UVM_FULL message", UVM_FULL);
  
    writeln("UVM TEST EXPECT 2 UVM_ERROR\n");
    phase.drop_objection(this);
  }

  override void report()
  {
    writeln("** UVM TEST PASSED **\n");
  }
}

int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  auto error = tb.simulate();	// error is expected
  if (error != 0) return 0;
  else return 1;
}
