//---------------------------------------------------------------------- 
//   Copyright 2010 Cadence Design Systems, Inc. 
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

// This test checks that a id specific severity overrides work.
// For this test, all of the override ids have _OVR as part of
// the name, and all non-overrides do not.
//
// This test is identical to the 02idspec test, except it uses
// the new uvm_report generic method to send the messages

//`define test_report(SEVERITY,ID,MSG,VERBOSITY)	\
//begin							\
//  if (uvm_report_enabled(VERBOSITY,SEVERITY,ID))		 \
//  uvm_report(SEVERITY,ID,MSG,VERBOSITY, `uvm_file, `uvm_line);	\
//end

import esdl;
import uvm;
import std.stdio;
import std.conv: to;
import uvm.base.uvm_coreservice;

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

void test_report(uvm_severity SEVERITY, string ID, string MSG, uvm_verbosity VERBOSITY)	{
  if (uvm_report_enabled(VERBOSITY,SEVERITY,ID)) {
    uvm_report(SEVERITY,ID,MSG,VERBOSITY, uvm_file, uvm_line);
  }
}

//module top;

//import uvm_pkg::*;
//include "uvm_macros.svh"

class test_root:uvm_root
{
  mixin uvm_component_utils;
  //override void initial()
}
bool pass = 1;
class sev_id_pair
{
  uvm_severity sev;
  string id;
  this(uvm_severity sev, string id)
  {
    this.sev = sev;
    this.id = id;

  }
}

class my_catcher: uvm_report_catcher
{
  int[sev_id_pair]  sev;
  sev_id_pair p;
  //mixin uvm_component_utils;
  
  override action_e do_catch()
  {
    string s_str;
    string exp_sev;
    import std.stdio;
    uvm_coreservice_t cs_;
    cs_ = uvm_coreservice_t.get();
    byte k;
    uvm_severity usev;

    // Ignore messages from root
    if(get_client() == cs_.get_root())
      return THROW;
    k = get_severity();
    usev = cast(uvm_severity) k;
    p = new sev_id_pair(usev, get_id());
      
    sev[p] ++;

    writeln("GOT MESSAGE %0s WITH SEVERITY %0s AND EXPECTED SEVERITY %0s",p.id, p.sev, get_message());

    exp_sev = get_message();
    
    if(p.sev.to!string != exp_sev)
      {
        writeln("**** UVM_TEST FAILED EXPECTED SEVERITY %0s GOT %0s ****", exp_sev, p.sev);
        pass = 0; 
      }

    return CAUGHT;
  }
}

class test: uvm_test
{
  mixin uvm_component_utils;
  
  this(string name, uvm_component parent = null)
  {
    super(name, parent);
    ctchr = new my_catcher();
  }

  my_catcher ctchr;
  override void run_phase(uvm_phase phase)
  {
    phase.raise_objection(this);
    uvm_report_cb.add(null,ctchr);

    // Set severities to INFO and then do a couple of messages of each type
    set_id_severities("id1", UVM_INFO);
    try_severities("id1", "UVM_INFO");

    wait(10.nsec);
    // Set severities to WARNING and then do a couple of messages of each type
    set_id_severities("id2", UVM_WARNING);
    try_severities("id2", "UVM_WARNING");
      
    wait(10.nsec);
    // Set severities to ERROR and then do a couple of messages of each type
    set_id_severities("id1", UVM_ERROR);
    try_severities("id1", "UVM_ERROR");

    wait(10.nsec);
    // Set severities to FATAL and then do a couple of messages of each type
    set_id_severities("id1", UVM_FATAL);
    try_severities("id1", "UVM_FATAL");

    phase.drop_objection(this);
  }

  override void report()
  {
    import std.stdio;
    if(ctchr.sev.length != 32)
      {
	
        writefln("*** UVM TEST FAILED Expected to catch eight different severity/id pairs, but got %0d instead ***", ctchr.sev.length);
        pass = 0;
      }
    foreach(i, p; ctchr.sev)
      {
	if(ctchr.sev[i] != 1)
	  {
            sev_id_pair s = i;
            writeln("*** UVM TEST FAILED Expected to catch 1 messages of type {%s,%s}, but got %0d instead ***", s.sev, s.id, ctchr.sev[i]);
            pass = 0;
	  }
         
      }
    if (pass) writeln("** UVM TEST PASSED **\n");
  }

  void set_id_severities(string id, uvm_severity sev)
  {
    set_report_severity_id_override(UVM_INFO, "INFO_" ~ id, sev);
    set_report_severity_id_override(UVM_WARNING, "WARNING_" ~ id, sev);
    set_report_severity_id_override(UVM_ERROR, "ERROR_" ~ id, sev);
    set_report_severity_id_override(UVM_FATAL, "FATAL_" ~ id, sev);
  }

  void try_severities(string id, string sev)
  {
    //For each type, there is one that will be overridden and one that will be
    //untouched. The message string is the expected verbosity of the message.
    test_report(UVM_INFO,"INFO_" ~ id, sev, UVM_NONE);
    test_report(UVM_INFO,"INFO_" ~ id~"_SAFE", "UVM_INFO", UVM_NONE);
    test_report(UVM_WARNING,"WARNING_" ~id, sev, UVM_NONE);
    test_report(UVM_WARNING,"WARNING_" ~id ~"_SAFE", "UVM_WARNING", UVM_NONE);
    test_report(UVM_ERROR,"ERROR_" ~ id, sev, UVM_NONE);
    test_report(UVM_ERROR,"ERROR_" ~ id ~",_SAFE", "UVM_ERROR", UVM_NONE);
    test_report(UVM_FATAL,"FATAL_" ~ id, sev, UVM_NONE);
    test_report(UVM_FATAL,"FATAL_" ~id~"_SAFE", "UVM_FATAL", UVM_NONE);
  }
}

int main(string[] argv)
{
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  if (tb.simulate() != 0) {	// uvm_fatal is expected
    return 0;
  }
  else {
    return 1;
  }
}
