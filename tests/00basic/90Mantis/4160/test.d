//---------------------------------------------------------------------- 
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
import std.string;

class ac: uvm_object
{
  @UVM_DEFAULT {
    @rand uint a;
    string b;
  }

  mixin uvm_object_utils; 

  this(string name="")
  {
    super(name);
  }
}

class b: uvm_comparer // provides a policy object for doing comparisions
{
  this()
  {   // function new()??? return type???
    super(); //????
    sev=UVM_FATAL; //sets the severity for printed messages
    verbosity=UVM_NONE;//sets verbosity for printed messages
    show_max=-1;//sets max no. of messages
  }
}

class catcher: uvm_report_catcher // used to catch messages issued by the uvm report server
{
  uint cnt=0;
  override action_e do_catch()
  {
    if(get_severity() == UVM_FATAL && get_id() == "MISCMP")
      { // get_id returns the string id of messages that is currently being processed
	cnt++;
	set_severity(UVM_INFO);
	return THROW;
      }
   
    if(get_severity() == UVM_INFO && get_id() == "MISCMP")
      {
	cnt++;
	return THROW;
      }
    return THROW;
  }
  
}

class test_root: uvm_root
{
  mixin uvm_component_utils;
  override void initial()
  {
    uvm_coreservice_t cs_ = uvm_coreservice_t.get();
    ac mya,myb;
    b policy;
    catcher catch_; // callbacks to report objects

    catch_ = new catcher; //????? needs to be checked for adding

    uvm_report_cb.add(null, catch_);

    mya=new ac;
    myb=new ac;
    policy=new b;

    mya.randomize();
    mya.b="bang";

    assert(mya.compare(myb, policy)==0);
    policy.verbosity=UVM_HIGH;
    policy.sev=UVM_INFO;
    assert(mya.compare(myb, policy)==0); // changes and checks the ver ans sev

    if(catch_.cnt != 3) {
      uvm_fatal("TEST", format("test failed, caught %0d messages", catch_.cnt));
    }

    uvm_report_server svr;
    svr = cs_.get_report_server();

    svr.summarize();

    if (svr.get_severity_count(UVM_FATAL) +
	svr.get_severity_count(UVM_ERROR) == 0) //if none is there thn test is passed
      uvm_info("PASSED", "** UVM TEST PASSED **\n", UVM_NONE);
    else
      uvm_error("FAILED", "!! UVM TEST FAILED !!\n");

  }
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}


int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
