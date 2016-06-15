//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
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

import esdl;
import uvm;
import std.stdio;


class TestBench: RootEntity
{
  uvm_entity!(test_root) tb;
};

class test_root: uvm_root
{
  mixin uvm_component_utils;
  override void initial()
  {
    uvm_coreservice_t cs_ = uvm_coreservice_t.get();

    uvm_factory fact = cs_.get_factory();
    my_server server = new   my_server( );
    my_catcher catcher = new my_catcher();
    uvm_report_cb.add(null, catcher);
    uvm_report_server.set_server(server);
    fact.set_type_override_by_type(uvm_report_handler.get_type(),
				   my_handler.get_type());
    fact.print();

    run_test();
  }
};

class my_class : uvm_object
{
  int foo = 3;
  string bar = "hi there";
  this (string name = "unnamed-my_class")
  {
    super(name);
  }
};

class my_catcher: uvm_report_catcher
{
  override action_e do_catch()
  {
    my_class my_object;
    uvm_report_message_element_base[] elements;
    uvm_report_message_element_container container = get_element_container();

    elements = container.get_elements();
    foreach (idx, element; elements)
      {
	uvm_report_message_object_element o_e =
	  cast(uvm_report_message_object_element) element;

	if (o_e !is null)
	  {
	    my_object = cast(my_class) o_e.get_value();
	    if (o_e.get_name() == "my_obj" && my_object !is null)
	      {
		if (my_object.foo == 3)
		  container.remove(idx);
	      }
	  }
      }

    return THROW;
  }
};

class my_server :uvm_default_report_server
{
  override  string compose_report_message(uvm_report_message report_message, string report_object_name = "")
  {
    uvm_report_message_element_base[] elements;
    uvm_report_message_element_container container = report_message.get_element_container();

    elements = container.get_elements();
    foreach (idx, element; elements)
      {
	uvm_report_message_string_element s_e =
	  cast(uvm_report_message_string_element)  element;
	if (s_e !is null)
	  {
	    if (s_e.get_name() == "my_color" && s_e.get_value() == "red")
	      container.remove(idx);
	  }
      }

    return super.compose_report_message(report_message, report_object_name);
  }
};


class my_handler :uvm_report_handler

{
  mixin uvm_object_utils;

  this(string name = "my_report_handler")
  {
    super(name);
  }

  override  void process_report_message(uvm_report_message report_message)
  {
    uvm_report_message_element_base[] elements;
    uvm_report_message_element_container container = report_message.get_element_container();

    elements = container.get_elements();
    foreach (idx, element; elements)
      {
	uvm_report_message_string_element s_e =
	  cast(uvm_report_message_string_element) element;
	if (s_e !is null)
	  {
	    if (s_e.get_name() == "my_string" && s_e.get_value() == "foo")
	      container.remove(idx);
	  }
      }

    super.process_report_message(report_message);
  }
};



class test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null)
  {
    super(name, parent);
  }

  override void uvm_process_report_message(uvm_report_message report_message)
  {
    uvm_report_message_element_base[] elements;
    uvm_report_message_element_container container = report_message.get_element_container();
    int size;
    uvm_radix_enum radix;

    elements = container.get_elements();
    foreach (idx, element; elements)
      {
	uvm_report_message_element!int i_e =
	  cast(uvm_report_message_element!int) element;
	if (i_e !is null)
	  {
	    if (i_e.get_name() == "my_int" && i_e.get_value(radix) == 5)
	      container.remove(idx);
	  }
      }

    super.uvm_process_report_message(report_message);
  }

  

  override void  run_phase(uvm_phase phase)
  {
    int my_int;
    string my_string;
    my_class my_obj;

    phase.raise_objection(this);

    my_int = 5;
    my_string = "foo";
    my_obj = new my_class("my_obj");

    writeln("START OF GOLD FILE");
    uvm_info("TEST", "Testing message...", UVM_LOW,
	     uvm_message_add!("my_color", "red"),
	     uvm_message_add!(my_int, UVM_DEC, "", UVM_LOG),
	     uvm_message_add!(my_string, "", UVM_LOG|UVM_RM_RECORD),
	     uvm_message_add!(my_obj)
	     );
    writeln("END OF GOLD FILE");

    phase.drop_objection(this);
  }

};


int main(string[] argv) {
  TestBench tb = new TestBench;
  tb.multiCore(0, 0);
  tb.elaborate("tb", argv);
  return tb.simulate();
}
