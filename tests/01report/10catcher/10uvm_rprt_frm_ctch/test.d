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

class test_root: uvm_root{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(uvm_root) tb; 
}

class my_catcher_info: uvm_report_catcher
{
  this(string name){
    super(name);
  }

  override action_e do_catch(){
    if(get_name() != get_id) return THROW;
    if(get_severity() != UVM_INFO) return THROW;
    writeln("Info Catcher Caught a message...\n");
    uvm_report_info("INFO CATCHER", "From my_catcher_info catch()", UVM_MEDIUM, uvm_file, uvm_line);
    return THROW;
  }
}

class my_catcher_warning: uvm_report_catcher
{
  string id;

  this(string id){
    super(id);
    this.id = id;
  }

  override action_e do_catch(){
    if(get_id() != id)
      return THROW;
    if(get_severity() != UVM_WARNING)
      return THROW;
    uvm_report_warning("WARNING CATCHER", "From my_catcher_warning catcher()", UVM_MEDIUM, uvm_file, uvm_line);
    return THROW;
  }
}

class my_catcher_error: uvm_report_catcher
{

  this(string id){
    super(id);
  }

  override action_e do_catch(){
    if(get_name() != get_id())
      return THROW;
    if(get_severity() != UVM_ERROR)
      return THROW;
    writeln("Error Catcher Caught a message...\n");
    uvm_report_error("ERROR CATCHER ","From my_catcher_error catch()", UVM_MEDIUM , uvm_file, uvm_line);
    return THROW;
  }
}

class my_catcher_fatal: uvm_report_catcher{

  this(string name){
    super(name);
  }

  override action_e do_catch(){
    if(get_name() != get_id()) return THROW;
    if(get_severity() != UVM_FATAL) return THROW;
    writeln("Fatal Catcher Caught a Fatal message...\n");
    uvm_report_fatal("FATAL CATCHER", "From my_catcher_fatal catch()", UVM_MEDIUM , uvm_file, uvm_line);
    return THROW;
  }
}

class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent=null){
    super(name, parent);
  }

  override void run_phase(uvm_phase phase){
    phase.raise_objection(this);
    writeln("UVM TEST - Same catcher type - different IDs\n");

    {
      my_catcher_info ctchr1 = new my_catcher_info("Catcher1");
      my_catcher_warning ctchr2 = new my_catcher_warning("Catcher2");
      my_catcher_error ctchr3 = new my_catcher_error("Catcher3");
      my_catcher_fatal ctchr4 = new my_catcher_fatal("Catcher4");

      writeln("adding a catcher of type my_catcher_info with id of Catcher1\n");
      uvm_report_cb.add(null,ctchr1);

      writeln("adding a catcher of type my_catcher_warning with id of Catcher2\n");
      uvm_report_cb.add(null,ctchr2);

      writeln("adding a catcher of type my_catcher_error with id of Catcher3\n");
      uvm_report_cb.add(null,ctchr3);
          
      writeln("adding a catcher of type my_catcher_fatal with id of Catcher4\n");
      uvm_report_cb.add(null,ctchr4);
          
      uvm_info("Catcher1", "This message is for Catcher1", UVM_MEDIUM);

      uvm_info("Catcher2", "This message is for Catcher2", UVM_MEDIUM);

      uvm_info("Catcher3", "This message is for Catcher3", UVM_MEDIUM);
      //uvm_info("Catcher4", "This message is for Catcher4", UVM_MEDIUM);
          
      uvm_info("XYZ", "This second message is for No One", UVM_MEDIUM);
    }
  

  
    //$write("UVM TEST EXPECT 1 UVM_ERROR\n");
  
    phase.drop_objection(this);
  }

  override void report(){
    writeln("** UVM TEST PASSED **\n");
  }
}   


int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0,0);
  tb.elaborate("test", argv);
  return tb.simulate();
}
