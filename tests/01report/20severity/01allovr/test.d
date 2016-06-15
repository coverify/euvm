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

// This test checks that a generic severity override, INFO->WARNING,
// for example, works and can later be replaced back.


import esdl;
import uvm;
import std.stdio;
import uvm.base.uvm_coreservice;

class test_root: uvm_root
{
  mixin uvm_component_utils;
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}

bool pass = 1;

class my_catcher: uvm_report_catcher
{
  uint[uvm_severity] sev;
  uvm_severity s;

  override action_e do_catch()
  {
    uvm_coreservice_t cs_;
    cs_ = uvm_coreservice_t.get();
    ubyte k;
    k=get_severity();
    s = cast(uvm_severity) k;

    if(get_client() == cs_.get_root())
      {
	return THROW;
      }
    sev[s] ++;

    writefln("%s: got severity %d for id %s", getRootEntity.getSimTime(), this.get_severity(),  get_id());

    if(getRootEntity.getSimTime() <10000)
      {
	if(s != UVM_INFO)
	  {
	    writeln("**** UVM TEST FAILED expected UVM_INFO but got %d", this.get_severity());
	    pass =0;
	  }
      }

    else if(getRootEntity.getSimTime() <20000)
      {
	if(s != UVM_WARNING)
	  {
	    writefln("**** UVM TEST FAILED expected UVM_WARNING but got %s", this.get_severity());
	    pass =0;
	  }
      }

    else if(getRootEntity.getSimTime() <30000)
      {
	if(s != UVM_ERROR)
	  {
	    writefln("*** UVM TEST FAILED expected UVM_ERROR but got %s", this.get_severity());
	    pass=0;
	  }
      }

    else if(getRootEntity.getSimTime() <40000)
      {
	if(s != UVM_FATAL)
	  {
	    writefln("*** UVM TEST FAILED expected UVM_FATAL but got %s", this.get_severity());
	    pass=0;
	  }
      }

    return CAUGHT;
  }
}

class test: uvm_test
{
  mixin uvm_component_utils;
  my_catcher ctchr;
  
  this(string name, uvm_component parent)
  {
    super(name, parent);

    ctchr = new my_catcher;
  }
  
    
  override void run_phase(uvm_phase phase)
  {
 
    phase.raise_objection(this);
    uvm_report_cb.add(null,ctchr);

    set_all_severities(UVM_INFO);
    try_all_severities();

    wait(15.nsec);
  
    set_all_severities(UVM_WARNING);
    try_all_severities();

    wait(10.nsec);
    set_all_severities(UVM_ERROR);
    try_all_severities();

    wait(10.nsec);
  
    set_all_severities(UVM_FATAL);
    try_all_severities();


    phase.drop_objection(this);
  }

  override void report()
  {
    if(ctchr.sev.length != 4)
      {
	writeln("*** UVM TEST FAILED Expected to catch four different severities, but got %0d instead ***", ctchr.sev.length);
	pass = 0;
      }
    foreach(x,p;ctchr.sev)
      if(ctchr.sev[x] != 8)
	{
	  uvm_severity s = x;
	  {
	    //writeln("*** UVM TEST FAILED Expected to catch 8 messages of type %s, but got %0d instead ***", s.to!string, ctchr.sev[x]);
	    writeln("*** UVM TEST FAILED Expected to catch 8 messages of type %s, but got %0d instead ***", ctchr.sev[x]);
	    pass = 0;
 
	  }
	}

    if (pass)
      {
	writeln("** UVM TEST PASSED **\n");
      }
  }

  void set_all_severities(uvm_severity sev)
  {
    set_report_severity_override(UVM_INFO, sev);
    set_report_severity_override(UVM_WARNING, sev);
    set_report_severity_override(UVM_ERROR, sev);
    set_report_severity_override(UVM_FATAL, sev);
  }

  void try_all_severities()
  {
    uvm_info("INFO1", "first info message", UVM_NONE);
    uvm_warning("WARNING1", "first warning message");
    uvm_error("ERROR1", "first error message");
    uvm_fatal("FATAL1", "first fatal message");

    uvm_info("INFO2", "second info message", UVM_NONE);
    uvm_warning("WARNING2", "second warning message");
    uvm_error("ERROR2", "second error message");
    uvm_fatal("FATAL2", "second fatal message");
  }
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}

 
 
     
