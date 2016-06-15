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
  
  this(string name, uvm_component parent)
  {
    super(name,parent);
  }

  override void build_phase(uvm_phase phase)
  {
    writeln("Building: ", get_full_name());
    set_report_verbosity_level(UVM_FULL);
    
    set_report_id_verbosity("ID1", UVM_LOW);
    set_report_id_verbosity_hier("ID2", UVM_MEDIUM);
    set_report_id_verbosity("ID3", 301);

    set_report_severity_id_verbosity(UVM_INFO, "ID4", 501);
    set_report_severity_id_verbosity(UVM_WARNING, "ID7", UVM_NONE);
    set_report_severity_id_verbosity(UVM_INFO, "ID5", UVM_FULL);

    set_report_severity_action(UVM_WARNING, UVM_RM_RECORD|UVM_DISPLAY|UVM_COUNT);

    set_report_id_action_hier("ACT_ID", UVM_DISPLAY|UVM_LOG|UVM_COUNT);
    set_report_id_action("ACT_ID2", UVM_DISPLAY);

    set_report_severity_id_action(UVM_INFO, "ID1", UVM_DISPLAY|UVM_COUNT);

    set_report_severity_override(UVM_ERROR,UVM_FATAL);
    
    set_report_severity_id_override(UVM_INFO, "ID8", UVM_ERROR);
    set_report_severity_id_override(UVM_ERROR, "ID9", UVM_WARNING);
    
    set_report_severity_id_verbosity_hier(UVM_INFO, "ID6", UVM_LOW);

    set_report_default_file(1);

    set_report_id_file("ID3", 467);
    set_report_id_file("ID7", 987893);

    set_report_severity_file(UVM_INFO, 23);
    set_report_severity_file(UVM_FATAL, 1001);

    set_report_severity_id_file(UVM_ERROR, "ID0", 7);
    set_report_severity_id_file(UVM_WARNING, "ID207", 300500);

  }

  override void run_phase(uvm_phase phase)
  {
    uvm_report_handler l_rh = get_report_handler();
    writeln("START OF GOLD FILE");
    l_rh.print();
    writeln("END OF GOLD FILE");
  }
 }


int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
