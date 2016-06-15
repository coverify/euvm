//
//------------------------------------------------------------------------------
//   Copyright 2012 Synopsys
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
//------------------------------------------------------------------------------

import esdl;
import uvm;
import std.stdio;

class TestBench: RootEntity
{
    uvm_entity!(test_root) tb;
}
class test_root:uvm_root
{
  mixin uvm_component_utils;
  override void initial()
  {
   my_catcher ct;
   uvm_root top;
   top = uvm_coreservice_t.get.get_root();
   //to be done   
   //`uvm_info("TEST", "Checking global catchers with same name...warning expected", UVM_NONE)
   ct = new my_catcher("A");
   uvm_report_cb.add(null, ct);
   ct = new my_catcher("A");
   uvm_report_cb.add(null, ct);
   //to be done   
   //   `uvm_info("TEST", "Checking instance catchers with same name...warning expected", UVM_NONE)
   ct = new my_catcher("B");
   uvm_report_cb.add(top, ct);
   ct = new my_catcher("B");
   uvm_report_cb.add(top, ct);

   //   `uvm_info("TEST", "Checking global+instance catchers with same name...warning expected", UVM_NONE)
   ct = new my_catcher("C");
   uvm_report_cb.add(null, ct);
   ct = new my_catcher("C");
   uvm_report_cb.add(top, ct);

   //   `uvm_info("TEST", "Checking instance+global catchers with same name...warning expected", UVM_NONE)
   ct = new my_catcher("D");
   uvm_report_cb.add(top, ct);
   ct = new my_catcher("D");
   uvm_report_cb.add(null, ct);

   
      uvm_report_server svr;
      svr = uvm_coreservice_t.get.get_report_server();
      import std.stdio;

      if (svr.get_severity_count(UVM_FATAL) +
          svr.get_severity_count(UVM_ERROR) == 0 &&
          svr.get_severity_count(UVM_WARNING) == 4)
         writeln("** UVM TEST PASSED! **\n");
      else
         writeln("** UVM TEST FAILED! **\n");

      svr.summarize();
   
  }
}

  
  
class my_catcher: uvm_report_catcher
{
  this(string name)
  {
      super(name);
  }

  override   action_e do_catch()
    {
      return THROW;
    }
}


int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(2, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();  
}
