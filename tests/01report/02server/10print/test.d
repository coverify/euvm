//
//------------------------------------------------------------------------------
//   Copyright 2011 Cadence Design Systems, Inc.
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

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}


class test: uvm_component

{
  mixin uvm_component_utils;
  uvm_report_server l_rs;
  
  
  this(string name, uvm_component parent)
  {
    super(name,parent);
    l_rs = uvm_report_server.get_server();
  }

  override void report_phase(uvm_phase phase)
  {

      // Produce some id counts
    uvm_info("ID1", "Message", UVM_NONE);
    uvm_info("ID2", "Message", UVM_NONE);
    uvm_info("ID3", "Message", UVM_NONE);

      // A few warning to bump the warning count
    uvm_warning("ID2", "Message");
    uvm_warning("ID3", "Message");

      // Cheating to set the fatal count
    l_rs.set_severity_count(UVM_ERROR, 50);

      // Cheating to set the fatal count
    l_rs.set_severity_count(UVM_FATAL, 10);

    l_rs.set_max_quit_count(5);

    writeln("GOLD-FILE-START");
    l_rs.print();
    writeln("GOLD-FILE-END");

  }
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}


