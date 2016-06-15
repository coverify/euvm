//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
//   Copyright 2010 Cadence Design Systems, Inc. 
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

class my_catcher: uvm_report_catcher
{
  static uint seen = 0;
  uvm_report_object client;
  uint[uvm_report_object] client_cnt ;

  override action_e do_catch()
  {
    client = get_client();
    writeln("Caught a message from client \"%0s\"...\n",client.get_full_name());
    seen++; //  += 1;
    writeln("seen in seen++:",seen);
    if(client !in client_cnt)
      {
	client_cnt[client] = 0;
	writeln("client not present");
      }
    client_cnt[client]++;
    return CAUGHT;
  }
}

class leaf: uvm_component
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
    super(name, parent);
  }

  override void run()
  {
    for(int i = 0; i<=4; i++)
      {
	wait(10.nsec);
	uvm_info("from_leaf", "Message from leaf", UVM_NONE);
	writeln(getRootEntity.getSimTime);
      }
  }
}

class mid: uvm_component
{
  leaf leaf1, leaf2;

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) 
  {
    super(name, parent); 
    leaf1 = new leaf("leaf1",this);
    leaf2 = new leaf("leaf2", this);
  }

  override void run()
  {
    for(int i = 0; i<=4; i++)
      {
	wait(10.nsec);
	uvm_info("from mid", "Message from mid", UVM_NONE);
      }
  }
}

class test: uvm_test
{
  mid mid1;
  bool pass = 1;

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
    super(name, parent);
    mid1 = new mid("mid", this);
  }

  override void run_phase(uvm_phase phase)
  {
    my_catcher ctchr = new my_catcher;
    phase.raise_objection(this);
    writeln("UVM TEST EXPECT 3 UVM_INFO\n");
    wait(11.nsec);

    //writeln("seen:", my_catcher.seen);
    if (my_catcher.seen != 0)
      {
	//writeln("seen1:", my_catcher.seen);

	writeln("ERROR: Message was caught with no catcher installed!\n");
	pass = 0;
      }
    
    {
      //writeln("seen before 2 loop bfr add:", my_catcher.seen);

      uvm_report_cb.add(mid1.leaf1,ctchr); //add to mid1.leaf1
      uvm_report_cb.add(mid1,ctchr); //add to mid1

      wait(10.nsec);

      if (my_catcher.seen != 2)
	{
	  //writeln("seen2:", my_catcher.seen);

	  writeln("ERROR: Message was NOT caught with default catcher installed!\n");
	  pass = 0;
	}
      uvm_report_cb.remove(mid1,ctchr); //remove to mid1
      wait(10.nsec);
      if (my_catcher.seen != 3)
	{
	  //writeln("seen3:", my_catcher.seen);

	  writeln("/n ERROR: Message was NOT caught with default catcher installed!\n");
	  pass = 0;
	}
    }
    uvm_report_cb.remove(null,ctchr);
    wait(10.nsec);
    //writeln("seen before 3 loop:", my_catcher.seen);

    if (my_catcher.seen != 3)
      {
	//writeln("seen4:", my_catcher.seen);

	writeln("ERROR: Message was caught after all catcher removed!\n");
	pass = 0;
      }
    phase.drop_objection(this);
  }

  override void report()
  {
    //writeln("seen in report:", my_catcher.seen);

    if (pass)
      {
	writeln("** UVM TEST PASSED **\n");
      }
    else
      {
	writeln("** UVM TEST FAILED! **\n");
      }
  }
}

int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
