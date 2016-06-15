//
//------------------------------------------------------------------------------
//   Copyright 2011 Mentor Graphics
//   Copyright 2011 Cadence
//   Copyright 2011 Synopsys, Inc.
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
import std.string;
import uvm.base.uvm_coreservice;

class test_root: uvm_root
{
  mixin uvm_component_utils;

  override void initial()
  {
    my_catcher catcher = new my_catcher;
    uvm_report_cb.add(null, catcher);
    run_test();
  }
}

class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
}


// bool block_bit;			// unused in SV

class my_class: uvm_object
{
  mixin uvm_object_utils;
  @UVM_DEFAULT {
    @UVM_DEC int foo = 3;
    string bar = "hi there";
  }
  this(string name = "unnamed-my_class") {
    super(name);
  }
}

class my_catcher: uvm_report_catcher
{
  override action_e do_catch()
  {
    if(get_severity() == UVM_FATAL)
      {
	set_severity(UVM_ERROR);
      }
    return THROW;
  }
}

class my_item: uvm_sequence_item
{
  @UVM_DEFAULT @rand Bit!8 addr;

  mixin uvm_object_utils;

  this(string name = "unnamed-my_item")
  {
    super(name);
    uvm_info(get_type_name(), format("new sequence item"), UVM_LOW);
  }
}

class my_sequence: uvm_sequence!my_item
{
  mixin uvm_object_utils;

  this(string name = "my_sequence")
  {
    super(name);
  }

  override void  pre_frame()
  {
    uvm_info(get_type_name(), "pre_body starting", UVM_LOW);
  }
  
  override void frame()
  {

    uvm_info(get_type_name(), "body starting", UVM_LOW);
    wait(100.nsec);
    uvm_do(req);//???? `uvm_do
    uvm_info(get_type_name(), "item done, sequence is finishing", UVM_LOW);

    {

      int my_int = 5;
      string my_string = "foo";
      my_class my_obj = new my_class("my_obj");

      writeln("GOLD-FILE-START");

      uvm_info("TEST", "Testing message...", UVM_LOW,
	       uvm_message_add!("my_color", "red"),
	       uvm_message_add!(my_int, UVM_DEC,"",UVM_LOG),
	       uvm_message_add!(my_string,UVM_LOG|UVM_RM_RECORD),
	       uvm_message_add!(my_obj));

      uvm_warning("TEST", "Testing message...",
		  uvm_message_add!("my_color", "red"),
		  uvm_message_add!(my_int, UVM_DEC,"",UVM_LOG),
		  uvm_message_add!(my_string,UVM_LOG|UVM_RM_RECORD),
		  uvm_message_add!(my_obj));

      uvm_error("TEST", "Testing message...",
		uvm_message_add!("my_color", "red"),
		uvm_message_add!(my_int, UVM_DEC,"",UVM_LOG),
		uvm_message_add!(my_string,UVM_LOG|UVM_RM_RECORD),
		uvm_message_add!(my_obj));

      uvm_fatal("TEST", "Testing message...",
		uvm_message_add!("my_color", "red"),
		uvm_message_add!(my_int, UVM_DEC,"",UVM_LOG),
		uvm_message_add!(my_string,UVM_LOG|UVM_RM_RECORD),
		uvm_message_add!(my_obj));

      writeln("GOLD-FILE-END");
    }
  }
}

class top_seq: uvm_sequence!my_item
{
  mixin uvm_object_utils;
  
  my_sequence seq;
     
  this(string name = "top_seq")
    {
      super(name);
    }
  
  override void pre_frame()
  {
    uvm_info(get_type_name(), format("pre_body starting"), UVM_LOW);
  }
  
  override void frame()
  {
    uvm_info(get_type_name(), format("body starting"), UVM_LOW);
    wait(100.nsec);
    uvm_create(seq);
    assert(seq !is null);
    uvm_send(seq);
    // seq.start(get_sequencer(), this);
    uvm_info(get_type_name(), format("item done, sequence is finishing"), UVM_LOW);
  }
}

class my_sequencer: uvm_sequencer!my_item
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent)
    {
      super(name, parent);
    }
}  

class my_driver: uvm_driver!my_item
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent)
    {
      super(name, parent);
    }

    override void run()
    {
      while(true)
	{
	  seq_item_port.get_next_item(req);
	  uvm_info(get_type_name(), format("Request is:\n%s", req.sprint()), UVM_LOW);
	  wait(100.nsec);
	  seq_item_port.item_done();
	}
    }
}


class my_agent: uvm_agent
{
  mixin uvm_component_utils;

  @UVM_BUILD {
    my_sequencer ms;
    my_driver md;
  }

  this(string name, uvm_component parent)
  {
    super(name, parent);
  }

  // override void build()
  // {
  //   super.build();
  //   ms = my_sequencer.type_id.create("ms", this);
  //   md = my_driver.type_id.create("md", this);
  // }

  override void connect()
  {
    md.seq_item_port.connect(ms.seq_item_export);
  }
}

 
class test: uvm_test
{
  mixin uvm_component_utils;

  @UVM_BUILD {
    my_agent ma0;
  }

  this(string name, uvm_component parent)
  {
    super(name, parent);
  }

  // override void build()
  // {
  //   super.build();
  //   ma0 = my_agent.type_id.create("ma0", this);
  // }

    override void end_of_elaboration()
  {
    uvm_info(get_type_name(), format("The topology:\n%s", this.sprint()), UVM_LOW);
  }

  override void run_phase(uvm_phase phase)
  {
    top_seq the_0seq;
    phase.raise_objection(this);
    the_0seq = top_seq.type_id.create("the_0seq", this);
    the_0seq.start(ma0.ms);
    phase.drop_objection(this);
  }
}



 
int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  tb.simulate();
  return 0;
}
