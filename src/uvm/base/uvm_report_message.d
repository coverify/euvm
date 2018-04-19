//
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2016      Coverify Systems Technology
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

module uvm.base.uvm_report_message;
import uvm.base.uvm_object_globals: uvm_action, uvm_radix_enum, uvm_action_type,
  UVM_FILE, uvm_severity, uvm_verbosity;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_recorder: uvm_recorder;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_report_handler: uvm_report_handler;
import uvm.base.uvm_report_server: uvm_report_server;

import uvm.meta.misc;

import esdl.base.core;
import esdl.data.bvec;

import std.traits;
import std.random;
import std.conv: to;

// add_tag, add_string and add_object
uvm_report_message_element_base
uvm_message_add(alias VAR, string LABEL="",
		uvm_action ACTION=(uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))()
  if (is(typeof(VAR) == string) || is(typeof(VAR): uvm_object)) {
    static if (is (typeof(VAR): string)) {
      alias V = string;
    }
    else {
      alias V = uvm_object;
    }
    static if (VAR.stringof[0] == '"' &&
	       VAR.stringof[$-1] == '"') { // add_tag
      static assert(LABEL != "", "Must supply label for uvm_message_add!");
      return new uvm_report_message_element!V(VAR.stringof[1..$-1], LABEL, ACTION);
    }
    else static if (LABEL == "") {
      return new uvm_report_message_element!V(VAR.stringof, VAR, ACTION);
    }
    else {
      return new uvm_report_message_element!V(LABEL, VAR, ACTION);
    }
  }

uvm_report_message_element_base
uvm_message_add(alias VAR, uvm_action ACTION)()
  if (is(typeof(VAR) == string) || is(typeof(VAR): uvm_object)) {
    string LABEL = "";
    static if (is (typeof(VAR): string)) {
      alias V = string;
    }
    else {
      alias V = uvm_object;
    }
    static if (VAR.stringof[0] == '"' &&
	       VAR.stringof[$-1] == '"') { // add_tag
      static assert(LABEL != "", "Must supply label for uvm_message_add!");
      return new uvm_report_message_element!V(VAR.stringof[1..$-1], LABEL, ACTION);
    }
    else if (LABEL == "") {
      return new uvm_report_message_element!V(VAR.stringof, VAR, ACTION);
    }
    else {
      return new uvm_report_message_element!V(LABEL, VAR, ACTION);
    }
  }

// add_int
uvm_report_message_element_base
uvm_message_add(alias VAR, uvm_radix_enum RADIX=uvm_radix_enum.UVM_HEX, string LABEL="",
		uvm_action ACTION=(uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))()
  if (isIntegral!(typeof(VAR)) || isBitVector!(typeof(VAR))) {
    static if (LABEL == "") {
      return new uvm_report_message_element!(typeof(VAR))(VAR.stringof, VAR, ACTION, RADIX);
    }
    else {
      return new uvm_report_message_element!(typeof(VAR))(LABEL, VAR, ACTION, RADIX);
    }
  }

uvm_report_message_element_base
uvm_message_add(alias VAR, string LABEL,
		uvm_action ACTION=(uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))()
  if (isIntegral!(typeof(VAR)) || isBitVector!(typeof(VAR))) {
    uvm_radix_enum RADIX=uvm_radix_enum.UVM_HEX;    
    static if (LABEL == "") {
      return new uvm_report_message_element!(typeof(VAR))(VAR.stringof, VAR, ACTION, RADIX);
    }
    else {
      return new uvm_report_message_element!(typeof(VAR))(LABEL, VAR, ACTION, RADIX);
    }
  }

uvm_report_message_element_base
uvm_message_add(alias VAR, uvm_action ACTION)()
  if (isIntegral!(typeof(VAR)) || isBitVector!(typeof(VAR))) {
    uvm_radix_enum RADIX=uvm_radix_enum.UVM_HEX;
    string LABEL="";
    if (LABEL == "") {
      return new uvm_report_message_element!(typeof(VAR))(VAR.stringof, VAR, ACTION, RADIX);
    }
    else {
      return new uvm_report_message_element!(typeof(VAR))(LABEL, VAR, ACTION, RADIX);
    }
  }

uvm_report_message
uvm_report_message_create(T...)(uvm_severity severity,
				string id,
				string message,
				int verbosity,
				string fname,
				size_t line,
				string context_name,
				T fields) {
  uvm_report_message l_report_message =
    uvm_report_message.new_report_message();
  l_report_message.set_report_message(severity, id, message, verbosity,
				      fname, line, context_name);
  l_report_message.add(fields);
  return l_report_message;
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message_element_base
//
// Base class for report message element. Defines common interface.
//
//------------------------------------------------------------------------------

abstract class uvm_report_message_element_base
{
  mixin(uvm_sync_string);

  @uvm_protected_sync
  private uvm_action _action;
  @uvm_protected_sync
  private string     _name;


  this(string name="", uvm_action action=(uvm_action_type.UVM_LOG |
					  uvm_action_type.UVM_RM_RECORD)) {
    synchronized(this) {
      _name = name;
      _action = action;
    }
  }
  
  // Function: get_name
  //

  string get_name() {
    synchronized(this) {
      return _name;
    }
  }

  // Function: set_name
  //
  // Get or set the name of the element
  //

  void set_name(string name) {
    synchronized(this) {
      _name = name;
    }
  }


  // Function: get_action
  //

  uvm_action get_action() {
    synchronized(this) {
      return _action;
    }
  }

  // Function: set_action
  //
  // Get or set the authorized action for the element
  //

  void set_action(uvm_action action) {
    synchronized(this) {
      _action = action;
    }
  }

  void print(uvm_printer printer) {
    synchronized(this) {
      if (_action & (uvm_action_type.UVM_LOG | uvm_action_type.UVM_DISPLAY)) {
	do_print(printer);
      }
    }
  }

  void record(uvm_recorder recorder) {
    synchronized(this) {
      if (_action & uvm_action_type.UVM_RM_RECORD) {
	do_record(recorder);
      }
    }
  }

  void copy(uvm_report_message_element_base rhs) {
    do_copy(rhs);
  }

  uvm_report_message_element_base clone() {
    return do_clone();
  }

  abstract void do_print(uvm_printer printer);
  abstract void do_record(uvm_recorder recorder);
  abstract void do_copy(uvm_report_message_element_base rhs);
  abstract uvm_report_message_element_base do_clone();
}


//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message_int_element
//
// Message element class for integral type
//
//------------------------------------------------------------------------------

class uvm_report_message_element(T) if(isIntegral!T || isBitVector!T):
  uvm_report_message_element_base
{
  mixin(uvm_sync_string);

  alias this_type = uvm_report_message_element!T;

  @uvm_protected_sync
  private T _val;
  @uvm_protected_sync
  private uvm_radix_enum  _radix;

  this(string name="", T value=T.init, uvm_action action=(uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD),
       uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX) {
    synchronized(this) {
      super(name, action);
      _val = value;
      _radix = radix;
    }
  }

  // Function: get_value
  //

  T get_value(out uvm_radix_enum radix) {
    synchronized(this) {
      radix = _radix;
      return _val;
    }
  }

  // Function: set_value
  //
  // Get or set the value (integral type) of the element, with size and radix
  //

  void set_value(T value, uvm_radix_enum radix) {
    synchronized(this) {
      _radix = radix;
      _val = value;
    }
  }


  override void do_print(uvm_printer printer) {
    synchronized(this) {
      printer.print(_name, _val, _radix);
    }
  }

  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      recorder.record(_name, _val, _radix);
    }
  }

  override void do_copy(uvm_report_message_element_base rhs) {
    synchronized(this) {
      this_type _rhs = cast(this_type) rhs;
      assert(_rhs !is null);
      _name = _rhs.name;
      _val = _rhs.val;
      _radix = _rhs.radix;
      _action = rhs.action;
    }
  }

  override uvm_report_message_element_base do_clone() {
    synchronized(this) {
      this_type tmp = new this_type;
      tmp.copy(this);
      return tmp;
    }
  }
}


//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message_int_element
//
// Message element class for integral type
//
//------------------------------------------------------------------------------

class uvm_report_message_int_element(T) if(isIntegral!T || isBitVector!T):
  uvm_report_message_element_base
{
  mixin(uvm_sync_string);

  alias this_type = uvm_report_message_int_element!T;

  @uvm_protected_sync
  private T _val;
  @uvm_protected_sync
  private size_t _size;
  @uvm_protected_sync
  private uvm_radix_enum  _radix;

  // Function: get_value
  //

  T get_value(out size_t size, out uvm_radix_enum radix) {
    synchronized(this) {
      size = _size;
      radix = _radix;
      return _val;
    }
  }

  // Function: set_value
  //
  // Get or set the value (integral type) of the element, with size and radix
  //

  void set_value(T value, size_t size, uvm_radix_enum radix) {
    synchronized(this) {
      _size = size;
      _radix = radix;
      _val = value;
    }
  }


  override void do_print(uvm_printer printer) {
    synchronized(this) {
      printer.print_int(_name, _val, _size, _radix);
    }
  }

  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      recorder.record(_name, _val, _size, _radix);
    }
  }

  override void do_copy(uvm_report_message_element_base rhs) {
    synchronized(this) {
      this_type _rhs = cast(this_type) rhs;
      assert(_rhs !is null);
      _name = _rhs.name;
      _val = _rhs.val;
      _size = _rhs.size;
      _radix = _rhs.radix;
      _action = rhs.action;
    }
  }

  override uvm_report_message_element_base do_clone() {
    synchronized(this) {
      this_type tmp = new this_type;
      tmp.copy(this);
      return tmp;
    }
  }
}


//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message_string_element
//
// Message element class for string type
//
//------------------------------------------------------------------------------

class uvm_report_message_element(T) if(is(T == string))
  : uvm_report_message_element_base
{
  alias  this_type = uvm_report_message_string_element;
  private string  _val;


  this(string name="", T value=T.init,
       uvm_action action=(uvm_action_type.UVM_LOG |
			  uvm_action_type.UVM_RM_RECORD)) {
    synchronized(this) {
      super(name, action);
      _val = value;
    }
  }

  // Function: get_value
  //

  string get_value() {
    synchronized(this) {
      return _val;
    }
  }

  // Function: set_value
  //
  // Get or set the value (string type) of the element
  //

  void set_value(string value) {
    synchronized(this) {
      _val = value;
    }
  }


  override void do_print(uvm_printer printer) {
    synchronized(this) {
      printer.print_string(_name, _val);
    }
  }

  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      recorder.record_string(_name, _val);
    }
  }

  override void do_copy(uvm_report_message_element_base rhs) {
    this_type rhs_ = cast(this_type) rhs;
    assert(rhs_ !is null);
    set_name   = rhs_.get_name;
    set_value  = rhs_.get_value;
    set_action = rhs_.get_action;
  }

  override uvm_report_message_element_base do_clone() {
    synchronized(this) {
      this_type tmp = new this_type;
      tmp.copy(this);
      return tmp;
    }
  }
}


alias uvm_report_message_string_element = uvm_report_message_element!string;

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message_object_element
//
// Message element class for object type
//
//------------------------------------------------------------------------------

class uvm_report_message_element(T) if(is(T: uvm_object))
  : uvm_report_message_element_base
{
  alias this_type = uvm_report_message_element!T;
  private T _val;


  this(string name="", T value=T.init,
       uvm_action action=(uvm_action_type.UVM_LOG |
			  uvm_action_type.UVM_RM_RECORD)) {
    synchronized(this) {
      super(name, action);
      _val = value;
    }
  }

  // Function: get_value
  //
  // Get the value (object reference) of the element
  //

  T get_value() {
    synchronized(this) {
      return _val;
    }
  }

  // Function: set_value
  //
  // Get or set the value (object reference) of the element
  //

  void set_value(T value) {
    synchronized(this) {
      _val = value;
    }
  }

  override void do_print(uvm_printer printer) {
    synchronized(this) {
      printer.print(_name, _val);
    }
  }

  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      recorder.record(_name, _val);
    }
  }

  override void do_copy(uvm_report_message_element_base rhs) {
    this_type rhs_ = cast(this_type) rhs;
    assert(rhs_ !is null);
    set_name   = rhs_.get_name;
    set_value  = rhs_.get_value;
    set_action = rhs_.get_action;
  }

  override uvm_report_message_element_base do_clone() {
    this_type tmp = new this_type;
    tmp.copy(this);
    return tmp;
  }
}

alias uvm_report_message_object_element = uvm_report_message_element!(uvm_object);

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message_element_container
//
// A container used by report message to contain the dynamically added elements,
// with APIs to add and delete the elements.
//
//------------------------------------------------------------------------------

class uvm_report_message_element_container: uvm_object
{

  private uvm_report_message_element_base[] _elements;

  mixin uvm_object_essentials;
  // `uvm_object_utils(uvm_report_message_element_container)

  // Function: new
  //
  // Create a new uvm_report_message_element_container object
  //

  this(string name = "element_container") {
    super(name);
  }


  // Function: size
  //
  // Returns the size of the container, i.e. the number of elements
  //

  int size() {
    synchronized(this) {
      return cast(int) _elements.length;
    }
  }

  alias length = size;
  // Function: delete
  //
  // Delete the ~index~-th element in the container
  //

  void remove(size_t index) {
    synchronized(this) {
      _elements = _elements[0..index] ~ _elements[index+1..$];
    }
  }


  // Function: delete_elements
  //
  // Delete all the elements in the container
  //

  void remove_elements() {
    synchronized(this) {
      _elements.length = 0;
    }
  }

  alias clear = remove_elements;
  // Function: get_elements
  //
  // Get all the elements from the container and put them in a queue
  //

  uvm_report_message_element_base[] get_elements() {
    synchronized(this) {
      return _elements.dup;
    }
  }

  // Function: add_int
  //
  // This method adds an integral type of the name ~name~ and value ~value~ to
  // the container.  The required ~size~ field indicates the size of ~value~.
  // The required ~radix~ field determines how to display and
  // record the field. The optional print/record bit is to specify whether
  // the element will be printed/recorded.
  //

  void add_int(T)(string name, T value,
		  size_t size, uvm_radix_enum radix,
		  uvm_action action = (uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))
    if(isIntegral!T || isBitVector!T) {
      synchronized(this) {
	uvm_report_message_int_element!T urme;
	// TBD
	// FIXME Vlang does not change the rand_state when creating a
	// non-rand class object
	Process p = Process.self();
	Random rand_state;
	if (p !is null) {
	  p.getRandState(rand_state);
	}
	urme = new uvm_report_message_int_element!T();
	if (p !is null) {
	  p.setRandState(rand_state);
	}

	urme.set_name(name);
	urme.set_value(value, size, radix);
	urme.set_action(action);
	_elements ~= urme;
      }
    }

  void add(T)(string name, T value,
	      uvm_radix_enum radix,
	      uvm_action action = (uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))
    if(isIntegral!T || isBitVector!T) {
      synchronized(this) {
	uvm_report_message_int_element!T urme;

	Process p = Process.self();
	Random rand_state;
	if (p !is null) {
	  p.getRandState(rand_state);
	}
	urme = new uvm_report_message_element!T();
	if (p !is null) {
	  p.setRandState(rand_state);
	}

	urme.set_name(name);
	urme.set_value(value, radix);
	urme.set_action(action);
	_elements ~= urme;
      }
    }


  // Function: add_string
  //
  // This method adds a string of the name ~name~ and value ~value~ to the
  // message. The optional print/record bit is to specify whether
  // the element will be printed/recorded.
  //

  void add(T)(string name, T value,
	      uvm_action action = (uvm_action_type.UVM_LOG |
				   uvm_action_type.UVM_RM_RECORD))
    if(is(T == string)) {
      synchronized(this) {
	Random rand_state;
	uvm_report_message_string_element urme;

	Process p = Process.self();
	if (p !is null) {
	  p.getRandState(rand_state);
	}

	urme = new uvm_report_message_element!T();
	if (p !is null) {
	  p.setRandState(rand_state);
	}

	urme.set_name(name);
	urme.set_value(value);
	urme.set_action(action);
	_elements ~= urme;
      }
    }

  alias add_string = add!string;

  // Function: add_object
  //
  // This method adds a uvm_object of the name ~name~ and reference ~obj~ to
  // the message. The optional print/record bit is to specify whether
  // the element will be printed/recorded.
  //

  void add(T)(string name, T obj,
	      uvm_action action = (uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))
    if(is(T: uvm_object)) {
      synchronized(this) {
	Random rand_state;
	uvm_report_message_object_element urme;

	Process p = Process.self();
	if (p !is null) {
	  p.getRandState(rand_state);
	}
	urme = new uvm_report_message_element!T();
	if (p !is null) {
	  p.setRandState(rand_state);
	}

	urme.set_name(name);
	urme.set_value(obj);
	urme.set_action(action);
	_elements ~= urme;
      }
    }

  void add(E...)(E urme)
    if (E.length == 0 || is(E[0]: uvm_report_message_element_base)) {
    static if (E.length > 0) {
      synchronized(this) {
	_elements ~= urme[0];
	this.add(urme[1..$]);
      }
    }
  }

  uvm_report_message_element_container
  opOpAssign(string op)(uvm_report_message_element_base urme)
    if (op == "~") {
    synchronized(this) {
      _elements ~= urme;
    }
    return this;
  }
  
  void add_object(string name, uvm_object obj,
		  uvm_action action = (uvm_action_type.UVM_LOG |
				       uvm_action_type.UVM_RM_RECORD)) {
    synchronized(this) {
      Random rand_state;
      uvm_report_message_object_element urme;

      Process p = Process.self();
      if (p !is null) {
	p.getRandState(rand_state);
      }
      urme = new uvm_report_message_object_element();
      if (p !is null) {
	p.setRandState(rand_state);
      }

      urme.set_name(name);
      urme.set_value(obj);
      urme.set_action(action);
      _elements ~= urme;
    }
  }

  override void do_print(uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      for(int i = 0; i < _elements.length; i++) {
	_elements[i].print(printer);
      }
    }
  }

  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      super.do_record(recorder);
      for(int i = 0; i < _elements.length; i++) {
	_elements[i].record(recorder);
      }
    }
  }

  override void do_copy(uvm_object rhs) {
    auto urme_container = cast(uvm_report_message_element_container) rhs;
    super.do_copy(rhs);
    if(urme_container is null) {
      return;
    }
    remove_elements();
    
    synchronized(this) {
      foreach (element; urme_container.get_elements) {
	_elements ~= element.clone();
      }
    }
  }
}


//------------------------------------------------------------------------------
//
// CLASS: uvm_report_message
//
// The uvm_report_message is the basic UVM object message class.  It provides
// the fields that are common to all messages.  It also has a message element
// container and provides the APIs necessary to add integral types, strings and
// uvm_objects to the container. The report message object can be initialized
// with the common fields, and passes through the whole reporting system (i.e.
// report object, report handler, report server, report catcher, etc) as an
// object. The additional elements can be added/deleted to/from the message
// object anywhere in the reporting system, and can be printed or recorded
// along with the common fields.
//
//------------------------------------------------------------------------------

class uvm_report_message: uvm_object
{

  private uvm_report_object _report_object;
  private uvm_report_handler _report_handler;
  private uvm_report_server _report_server;

  private uvm_severity _severity;
  private string _id;
  private string _message;
  private int _verbosity;
  private string _filename;
  private size_t _line;
  private string _context_name;
  private uvm_action _action;
  private UVM_FILE _file;

  // Not documented.
  // Effectively Immutable
  private uvm_report_message_element_container _report_message_element_container;

  // Function: new
  //
  // Creates a new uvm_report_message object.
  //

  this(string name = "uvm_report_message") {
    synchronized(this) {
      super(name);
      _report_message_element_container =
	new uvm_report_message_element_container();
    }
  }


  // Function: new_report_message
  //
  // Creates a new uvm_report_message object.
  // This function is the same as new(), but keeps the random stability.
  //

  static uvm_report_message
  new_report_message(string name = "uvm_report_message") {
    uvm_report_message result;
    Random rand_state;

    Process p = Process.self();

    if (p !is null) {
      p.getRandState(rand_state);
    }

    result = new uvm_report_message(name);
    if (p !is null) {
      p.setRandState(rand_state);
    }
    return result;
  }


  // Function: print
  //
  // The uvm_report_message implements <uvm_object::do_print()> such that
  // ~print~ method provides UVM printer formatted output
  // of the message.  A snippet of example output is shown here:
  //
  //| --------------------------------------------------------
  //| Name                Type               Size  Value
  //| --------------------------------------------------------
  //| uvm_report_message  uvm_report_message  -     @532
  //|   severity          uvm_severity        2     UVM_INFO
  //|   id                string              10    TEST_ID
  //|   message           string              12    A message...
  //|   verbosity         uvm_verbosity       32    UVM_LOW
  //|   filename          string              7     test.sv
  //|   line              integral            32    'd58
  //|   context_name      string              0     ""
  //|   color             string              3     red
  //|   my_int            integral            32    'd5
  //|   my_string         string              3     foo
  //|   my_obj            my_class            -     @531
  //|     foo             integral            32    'd3
  //|     bar             string              8     hi there


  override void do_print(uvm_printer printer) {
    synchronized(this) {

      super.do_print(printer);

      printer.print_generic("severity", "uvm_severity",
			    _severity.sizeof * 8, _severity.to!string);
      printer.print_string("id", _id);
      printer.print_string("message", _message);
      uvm_verbosity l_verbosity = cast(uvm_verbosity) _verbosity;

      // if (l_verbosity !is null) {
      printer.print_generic("verbosity", "uvm_verbosity",
			    l_verbosity.sizeof * 8, l_verbosity.to!string);
      // }
      // else {
      //	printer.print_int("verbosity", _verbosity, uvm_radix_enum.UVM_HEX);
      // }

      printer.print("filename", _filename);
      printer.print("line", _line, uvm_radix_enum.UVM_UNSIGNED);
      printer.print("context_name", _context_name);

      if (_report_message_element_container.size != 0) {
	_report_message_element_container.print(printer);
      }
    }
  }

  mixin uvm_object_essentials;



  // do_pack() not needed
  // do_unpack() not needed
  // do_compare() not needed


  // Not documented.
  override void do_copy (uvm_object rhs) {
    super.do_copy(rhs);

    uvm_report_message report_message = cast(uvm_report_message) rhs;
    if(report_message is null) {
      return;
    }
    synchronized(this) {
      _report_object = report_message.get_report_object();
      _report_handler = report_message.get_report_handler();
      _report_server = report_message.get_report_server();
      _context_name = report_message.get_context();
      _file = report_message.get_file();
      _filename = report_message.get_filename();
      _line = report_message.get_line();
      _action = report_message.get_action();
      _severity = report_message.get_severity();
      _id = report_message.get_id();
      _message = report_message.get_message();
      _verbosity = report_message.get_verbosity();

      _report_message_element_container.copy(report_message.get_element_container());
    }
  }

  //----------------------------------------------------------------------------
  // Group:  Infrastructure References
  //----------------------------------------------------------------------------


  // Function: get_report_object

  uvm_report_object get_report_object() {
    synchronized(this) {
      return _report_object;
    }
  }

  // Function: set_report_object
  //
  // Get or set the uvm_report_object that originated the message.

  void set_report_object(uvm_report_object ro) {
    synchronized(this) {
      _report_object = ro;
    }
  }


  // Function: get_report_handler

  uvm_report_handler get_report_handler() {
    synchronized(this) {
      return _report_handler;
    }
  }


  // Function: set_report_handler
  //
  // Get or set the uvm_report_handler that is responsible for checking
  // whether the message is enabled, should be upgraded/downgraded, etc.

  void set_report_handler(uvm_report_handler rh) {
    synchronized(this) {
      _report_handler = rh;
    }
  }


  // Function: get_report_server

  uvm_report_server get_report_server() {
    synchronized(this) {
      return _report_server;
    }
  }


  // Function: set_report_server
  //
  // Get or set the uvm_report_server that is responsible for servicing
  // the message's actions.

  void set_report_server(uvm_report_server rs) {
    synchronized(this) {
      _report_server = rs;
    }
  }


  //----------------------------------------------------------------------------
  // Group:  Message Fields
  //----------------------------------------------------------------------------


  // Function: get_severity

  uvm_severity get_severity() {
    synchronized(this) {
      return _severity;
    }
  }

  // Function: set_severity
  //
  // Get or set the severity (UVM_INFO, UVM_WARNING, UVM_ERROR or
  // UVM_FATAL) of the message.  The value of this field is determined via
  // the API used (`uvm_info(), `uvm_waring(), etc.) and populated for the user.

  void set_severity(uvm_severity sev) {
    synchronized(this) {
      _severity = sev;
    }
  }


  // Function: get_id

  string get_id() {
    synchronized(this) {
      return _id;
    }
  }

  // Function: set_id
  //
  // Get or set the id of the message.  The value of this field is
  // completely under user discretion.  Users are recommended to follow a
  // consistent convention.  Settings in the uvm_report_handler allow various
  // messaging controls based on this field.  See <uvm_report_handler>.

  void set_id(string id) {
    synchronized(this) {
      _id = id;
    }
  }


  // Function: get_message

  string get_message() {
    synchronized(this) {
      return _message;
    }
  }

  // Function: set_message
  //
  // Get or set the user message content string.

  void set_message(string msg) {
    synchronized(this) {
      _message = msg;
    }
  }


  // Function: get_verbosity

  int get_verbosity() {
    synchronized(this) {
      return _verbosity;
    }
  }

  // Function: set_verbosity
  //
  // Get or set the message threshold value.  This value is compared
  // against settings in the <uvm_report_handler> to determine whether this
  // message should be executed.

  void set_verbosity(int ver) {
    synchronized(this) {
      _verbosity = ver;
    }
  }


  // Function: get_filename

  string get_filename() {
    synchronized(this) {
      return _filename;
    }
  }

  // Function: set_filename
  //
  // Get or set the file from which the message originates.  This value
  // is automatically populated by the messaging macros.

  void set_filename(string fname) {
    synchronized(this) {
      _filename = fname;
    }
  }


  // Function: get_line

  size_t get_line() {
    synchronized(this) {
      return _line;
    }
  }

  // Function: set_line
  //
  // Get or set the line in the ~file~ from which the message originates.
  // This value is automatically populate by the messaging macros.

  void set_line(size_t ln) {
    synchronized(this) {
      _line = ln;
    }
  }


  // Function: get_context

  string get_context() {
    synchronized(this) {
      return _context_name;
    }
  }

  // Function: set_context
  //
  // Get or set the optional user-supplied string that is meant to convey
  // the context of the message.  It can be useful in scopes that are not
  // inherently UVM like modules, interfaces, etc.

  void set_context(string cn) {
    synchronized(this) {
      _context_name = cn;
    }
  }


  // Function: get_action

  uvm_action get_action() {
    synchronized(this) {
      return _action;
    }
  }

  // Function: set_action
  //
  // Get or set the action(s) that the uvm_report_server should perform
  // for this message.  This field is populated by the uvm_report_handler during
  // message execution flow.

  void set_action(uvm_action act) {
    synchronized(this) {
      _action = act;
    }
  }


  // Function: get_file

  UVM_FILE get_file() {
    synchronized(this) {
      return _file;
    }
  }

  // Function: set_file
  //
  // Get or set the file that the message is to be written to when the
  // message's action is UVM_LOG.  This field is populated by the
  // uvm_report_handler during message execution flow.

  void set_file(UVM_FILE fl) {
    synchronized(this) {
      _file = fl;
    }
  }

  // Function: get_element_container
  //
  // Get the element_container of the message

  // _report_message_element_container is effectively immutable
  uvm_report_message_element_container get_element_container() {
    return _report_message_element_container;
  }


  // Function: set_report_message
  //
  // Set all the common fields of the report message in one shot.
  //

  void set_report_message(uvm_severity severity,
			  string id,
			  string message,
			  int verbosity,
			  string filename,
			  size_t line,
			  string context_name = "") {
    synchronized(this) {
      if (context_name != "") {
	_context_name = context_name;
      }
      _filename     = filename;
      _line         = line;
      _severity     = severity;
      _id           = id;
      _message      = message;
      _verbosity    = verbosity;
    }
  }


  //----------------------------------------------------------------------------
  // Group-  Message Recording
  //----------------------------------------------------------------------------

  // Not documented.
  void m_record_message(uvm_recorder recorder) {
    synchronized(this) {
      recorder.record_string("message", _message);
    }
  }


  // Not documented.
  void m_record_core_properties(uvm_recorder recorder) {
    synchronized(this) {

      if (_context_name != "") {
	recorder.record_string("context_name", _context_name);
      }
      recorder.record_string("filename", _filename);
      recorder.record_field("line", _line, uvm_radix_enum.UVM_UNSIGNED);
      recorder.record_string("severity", _severity.to!string);
      uvm_verbosity l_verbosity = cast(uvm_verbosity) _verbosity;
      // if (l_verbosity !is null) {
      recorder.record_string("verbosity", l_verbosity.to!string);
      // }
      // else {
      //	recorder.record_string("verbosity", _verbosity.to!string);
      // }
      recorder.record_string("id", _id);
      m_record_message(recorder);
    }
  }

  // Not documented.
  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      super.do_record(recorder);

      m_record_core_properties(recorder);
      _report_message_element_container.record(recorder);
    }
  }


  //----------------------------------------------------------------------------
  // Group:  Message Element APIs
  //----------------------------------------------------------------------------


  // Function: add_int
  //
  // This method adds an integral type of the name ~name~ and value ~value~ to
  // the message.  The required ~size~ field indicates the size of ~value~.
  // The required ~radix~ field determines how to display and
  // record the field. The optional print/record bit is to specify whether
  // the element will be printed/recorded.
  //

  void add(T)(string name, T value,
	      uvm_radix_enum radix,
	      uvm_action action = (uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))
    if(isIntegral!T || isBitVector!T) {
      // synchronized(this) {
      _report_message_element_container.add(name, value, radix, action);
      // }
    }

  void add_int(T)(string name, T value,
		  size_t size,
		  uvm_radix_enum radix,
		  uvm_action action = (uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))
    if(isIntegral!T || isBitVector!T) {
      // synchronized(this) {
      _report_message_element_container.add_int(name, value, size, radix, action);
      // }
    }


  // Function: add_string
  //
  // This method adds a string of the name ~name~ and value ~value~ to the
  // message. The optional print/record bit is to specify whether
  // the element will be printed/recorded.
  //

  void add(T)(string name, T value,
	      uvm_action action = (uvm_action_type.UVM_LOG |
				   uvm_action_type.UVM_RM_RECORD))
    if(is(T == string)) {
      // synchronized(this) {
      _report_message_element_container.add_string(name, value, action);
      // }
    }

  alias add_string = add!string;

  // Function: add_object
  //
  // This method adds a uvm_object of the name ~name~ and reference ~obj~ to
  // the message. The optional print/record bit is to specify whether
  // the element will be printed/recorded.
  //

  void add(T)(string name, T obj,
	      uvm_action action = (uvm_action_type.UVM_LOG |
				   uvm_action_type.UVM_RM_RECORD))
    if(is(T: uvm_object)) {
      // synchronized(this) {
      _report_message_element_container.add_object(name, obj, action);
      // }
    }

  alias add_object = add!uvm_object;

  void add(E...)(E urme)
    if (E.length == 0 || is(E[0]: uvm_report_message_element_base)) {
    static if (E.length > 0) {
      synchronized(this) {
	_report_message_element_container ~= urme[0];
	this.add(urme[1..$]);
      }
    }
  }

  void add(uvm_report_message_element_base urme) {
    _report_message_element_container.add(urme);
  }

  uvm_report_message
  opOpAssign(string op)(uvm_report_message_element_base urme)
    if (op == "~") {
      _report_message_element_container ~= urme;
      return this;
    }
}
