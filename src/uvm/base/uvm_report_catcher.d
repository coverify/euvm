// $Id: uvm_report_catcher.svh,v 1.1.2.10 2010/04/09 15:03:25 janick Exp $
//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2018 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2018 Intel Corporation
// Copyright 2010-2013 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2010-2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2014 Cisco Systems, Inc.
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

module uvm.base.uvm_report_catcher;

import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_report_message: uvm_report_message,
  uvm_report_message_element_container;
import uvm.base.uvm_callback: uvm_callback, uvm_callbacks,
  uvm_callbacks_base, uvm_callback_iter;
import uvm.base.uvm_object: uvm_object;

import uvm.base.uvm_object_globals: uvm_severity, uvm_action, uvm_integral_t,
  uvm_bitstream_t, uvm_radix_enum, uvm_action_type, uvm_verbosity, UVM_FILE;
import uvm.base.uvm_globals: uvm_report_intf, uvm_info_context;

import uvm.base.uvm_once;

import uvm.meta.misc;
import uvm.meta.mcd;

import std.string: format;
import std.random: Random;
import std.traits: isIntegral;
import esdl.data.bvec: isBitVector;
import esdl.base.core: Process;

alias uvm_report_cb = uvm_callbacks!(uvm_report_object, uvm_report_catcher);
// @uvm-ieee 1800.2-2017 auto D.4.5
alias uvm_report_cb_iter = uvm_callback_iter!(uvm_report_object, uvm_report_catcher);

// Redundant -- not used anywhere in UVM
// class sev_id_struct
// {
//   bool sev_specified ;
//   bool id_specified ;
//   uvm_severity sev ;
//   string  id ;
//   bool is_on ;
// }

// TITLE: Report Catcher
//
// Contains debug methods in the Accellera UVM implementation not documented
// in the IEEE 1800.2-2017 LRM


//------------------------------------------------------------------------------
//
// CLASS: uvm_report_catcher
//


// @uvm-ieee 1800.2-2017 auto 6.6.1
abstract class uvm_report_catcher: uvm_callback, uvm_report_intf
{
  // Keep the message specific variables static (thread local)
  // as we know a message will not cross thread boudaries
  static private uvm_report_message _m_modified_report_message;
  static private uvm_report_message _m_orig_report_message;
  static private bool _m_set_action_called;

  static class uvm_once: uvm_once_base
  {
    // Counts for the demoteds and caughts
    @uvm_private_sync
    private int _m_demoted_fatal;
    @uvm_private_sync
    private int _m_demoted_error;
    @uvm_private_sync
    private int _m_demoted_warning;
    @uvm_private_sync
    private int _m_caught_fatal;
    @uvm_private_sync
    private int _m_caught_error;
    @uvm_private_sync
    private int _m_caught_warning;

    // Flag counts
    @uvm_private_sync
    private int _m_debug_flags;
    @uvm_private_sync
    private bool _do_report;

    this() {
      synchronized (this) {
	_do_report = true;
      }
    }
  }

  mixin (uvm_once_sync_string);

  // Flag counts
  enum int DO_NOT_CATCH = 1;
  enum int DO_NOT_MODIFY = 2;

  // Moved to the uvm_report_object module
  // `uvm_register_cb(uvm_report_object,uvm_report_catcher)

  enum action_e: int
    {   UNKNOWN_ACTION,
	THROW,
	CAUGHT
	};

  
  // Function -- NODOCS -- new
  //
  // Create a new report catcher. The name argument is optional, but
  // should generally be provided to aid in debugging.

  // @uvm-ieee 1800.2-2017 auto 6.6.2
  this(string name = "uvm_report_catcher") {
    synchronized (this) {
      super(name);
    }
  }

  // Group -- NODOCS -- Current Message State

  // Function -- NODOCS -- get_client
  //
  // Returns the <uvm_report_object> that has generated the message that
  // is currently being processed.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.1
  static uvm_report_object get_client() {
    return _m_modified_report_message.get_report_object();
  }

  // Function -- NODOCS -- get_severity
  //
  // Returns the <uvm_severity> of the message that is currently being
  // processed. If the severity was modified by a previously executed
  // catcher object (which re-threw the message), then the returned
  // severity is the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.2
  static uvm_severity get_severity() {
    return _m_modified_report_message.get_severity();
  }

  // Function -- NODOCS -- get_context
  //
  // Returns the context name of the message that is currently being
  // processed. This is typically the full hierarchical name of the component
  // that issued the message. However, if user-defined context is set from
  // a uvm_report_message, the user-defined context will be returned.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.3
  static string get_context() {
    import uvm.base.uvm_report_handler;
    string context_str = _m_modified_report_message.get_context();
    if (context_str == "") {
      uvm_report_handler rh =
	_m_modified_report_message.get_report_handler();
      context_str = rh.get_full_name();
    }
    return context_str;
  }

  // Function -- NODOCS -- get_verbosity
  //
  // Returns the verbosity of the message that is currently being
  // processed. If the verbosity was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // verbosity is the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.4
  static int get_verbosity() {
    return _m_modified_report_message.get_verbosity();
  }

  // Function -- NODOCS -- get_id
  //
  // Returns the string id of the message that is currently being
  // processed. If the id was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // id is the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.5
  static string get_id() {
    return _m_modified_report_message.get_id();
  }

  // Function -- NODOCS -- get_message
  //
  // Returns the string message of the message that is currently being
  // processed. If the message was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // message is the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.6
  static string get_message() {
    return _m_modified_report_message.get_message();
  }

  // Function -- NODOCS -- get_action
  //
  // Returns the <uvm_action> of the message that is currently being
  // processed. If the action was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // action is the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.7
  static uvm_action get_action() {
    return _m_modified_report_message.get_action();
  }

  // Function -- NODOCS -- get_fname
  //
  // Returns the file name of the message.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.8
  static string get_fname() {
    return _m_modified_report_message.get_filename();
  }

  // Function -- NODOCS -- get_line
  //
  // Returns the line number of the message.

  // @uvm-ieee 1800.2-2017 auto 6.6.3.9
  static size_t get_line() {
    return _m_modified_report_message.get_line();
  }

  // Function -- NODOCS -- get_element_container
  //
  // Returns the element container of the message.

  static uvm_report_message_element_container get_element_container() {
    return _m_modified_report_message.get_element_container();
  }

  // Group -- NODOCS -- Change Message State

  // Function -- NODOCS -- set_severity
  //
  // Change the severity of the message to ~severity~. Any other
  // report catchers will see the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.4.1
  static protected void set_severity(uvm_severity severity) {
    _m_modified_report_message.set_severity(severity);
  }

  // Function -- NODOCS -- set_verbosity
  //
  // Change the verbosity of the message to ~verbosity~. Any other
  // report catchers will see the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.4.2
  static protected void set_verbosity(int verbosity) {
    _m_modified_report_message.set_verbosity(verbosity);
  }

  // Function -- NODOCS -- set_id
  //
  // Change the id of the message to ~id~. Any other
  // report catchers will see the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.4.3
  static protected void set_id(string id) {
    _m_modified_report_message.set_id(id);
  }

  // Function -- NODOCS -- set_message
  //
  // Change the text of the message to ~message~. Any other
  // report catchers will see the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.4.4
  static protected void set_message(string message) {
    _m_modified_report_message.set_message(message);
  }

  // Function -- NODOCS -- set_action
  //
  // Change the action of the message to ~action~. Any other
  // report catchers will see the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.4.5
  static protected void set_action(uvm_action action) {
    _m_modified_report_message.set_action(action);
    _m_set_action_called = true;
  }


  // Function -- NODOCS -- set_context
  //
  // Change the context of the message to ~context_str~. Any other
  // report catchers will see the modified value.

  // @uvm-ieee 1800.2-2017 auto 6.6.4.6
  static protected void set_context(string context_str) {
    _m_modified_report_message.set_context(context_str);
  }

  // Function -- NODOCS -- add_int
  //
  // Add an integral type of the name ~name~ and value ~value~ to
  // the message.  The required ~size~ field indicates the size of ~value~.
  // The required ~radix~ field determines how to display and
  // record the field. Any other report catchers will see the newly
  // added element.
  //

  static protected void add(T)(string name,
			       T value,
			       uvm_radix_enum radix,
			       uvm_action action =
			       (uvm_action_type.UVM_LOG|uvm_action_type.UVM_RM_RECORD))
    if (isBitVector!T || isIntegral!T) {
      _m_modified_report_message.add(name, value, radix, action);
    }

  static protected void add_int(string name,
				uvm_bitstream_t value,
				int size,
				uvm_radix_enum radix,
				uvm_action action =
				(uvm_action_type.UVM_LOG |
				 uvm_action_type.UVM_RM_RECORD)) {
    _m_modified_report_message.add_int(name, value, size, radix, action);
  }

  // Function -- NODOCS -- add_string
  //
  // Adds a string of the name ~name~ and value ~value~ to the
  // message. Any other report catchers will see the newly
  // added element.
  //

  static protected void add(T)(string name,
			       T value,
			       uvm_action action =
			       (uvm_action_type.UVM_LOG |
				uvm_action_type.UVM_RM_RECORD))
    if (is (T == string)) {
      _m_modified_report_message.add(name, value, action);
    }

  alias add_string = add!string;
  // Function -- NODOCS -- add_object
  //
  // Adds a uvm_object of the name ~name~ and reference ~obj~ to
  // the message. Any other report catchers will see the newly
  // added element.
  //

  static protected void add(T)(string name,
			       T obj,
			       uvm_action action =
			       (uvm_action_type.UVM_LOG |
				uvm_action_type.UVM_RM_RECORD))
    if (is (T: uvm_object)) {
      _m_modified_report_message.add(name, obj, action);
    }

  alias add_object = add!(uvm_object);

  // Function -- NODOCS -- print_catcher
  //
  // Prints debug information about all of the typewide report catchers that are 
  // registered.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  static void print_catcher(UVM_FILE file=0) {
    import uvm.base.uvm_root: uvm_root;
    string enabled;
    // static uvm_report_cb_iter iter = new(null);
    string q;
    q ~= "-------------UVM REPORT CATCHERS----------------------------\n";

    foreach (catcher; uvm_report_cb.get_all(null)) {
      while (catcher !is null) {
	if (catcher.callback_mode()) {
	  enabled = "ON";
	}
	else {
	  enabled = "OFF";
	}
      }
      q ~= format("%20s : %s\n", catcher.get_name(), enabled);
    }
    q ~= "--------------------------------------------------------------\n";
    uvm_info_context("UVM/REPORT/CATCHER", q, uvm_verbosity.UVM_LOW, uvm_root.get());

  }

  // Funciton: debug_report_catcher
  //
  // Turn on report catching debug information. bits[1:0] of ~what~ enable debug features
  // * bit 0 - when set to 1 -- forces catch to be ignored so that all catchers see the
  //   the reports.
  // * bit 1 - when set to 1 -- forces the message to remain unchanged
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  
  static void debug_report_catcher(int what= 0) {
    m_debug_flags = what;
  }

  // Group -- NODOCS -- Callback Interface

  // Function -- NODOCS -- catch
  //
  // This is the method that is called for each registered report catcher.
  // There are no arguments to this function. The <Current Message State>
  // interface methods can be used to access information about the
  // current message being processed.

  // catch is a keyword in Dlang
  // @uvm-ieee 1800.2-2017 auto 6.6.5
  abstract action_e do_catch();


  // Group -- NODOCS -- Reporting

  // import uvm.base.uvm_message_defines: uvm_report_mixin_string;

  // mixin uvm_report_mixin;
  // mixin (uvm_report_mixin_string());

  // Function -- NODOCS -- uvm_report_fatal
  //
  // Issues a fatal message using the current message's report object.
  // This message will bypass any message catching callbacks.

  protected void uvm_report_fatal(string id,
				  string message,
				  int verbosity,
				  string fname = "",
				  size_t line = 0,
				  string context_name = "",
				  bool report_enabled_checked = false) {
    this.uvm_report(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE, fname, line,
		    context_name, report_enabled_checked);
  }


  // Function -- NODOCS -- uvm_report_error
  //
  // Issues an error message using the current message's report object.
  // This message will bypass any message catching callbacks.


  protected void uvm_report_error(string id,
				  string message,
				  int verbosity,
				  string fname = "",
				  size_t line = 0,
				  string context_name = "",
				  bool report_enabled_checked = 0) {

    this.uvm_report(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE, fname, line,
		    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report_warning
  //
  // Issues a warning message using the current message's report object.
  // This message will bypass any message catching callbacks.

  protected void uvm_report_warning(string id,
				    string message,
				    int verbosity,
				    string fname = "",
				    size_t line = 0,
				    string context_name = "",
				    bool report_enabled_checked = 0) {
    this.uvm_report(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE, fname, line,
		    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report_info
  //
  // Issues a info message using the current message's report object.
  // This message will bypass any message catching callbacks.

  protected void uvm_report_info(string id,
				 string message,
				 int verbosity,
				 string fname = "",
				 size_t line = 0,
				 string context_name = "",
				 bool report_enabled_checked = false) {
    this.uvm_report(uvm_severity.UVM_INFO, id, message, verbosity, fname, line,
		    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report
  //
  // Issues a message using the current message's report object.
  // This message will bypass any message catching callbacks.

  protected void uvm_report(uvm_severity severity,
			    string id,
			    string message,
			    int verbosity,
			    string fname = "",
			    size_t line = 0,
			    string context_name = "",
			    bool report_enabled_checked = false) {
    uvm_report_message l_report_message;
    if (report_enabled_checked is false) {
      if (!uvm_report_enabled(verbosity, severity, id)) {
	return;
      }
    }
    l_report_message = uvm_report_message.new_report_message();
    l_report_message.set_report_message(severity, id, message,
					verbosity, fname, line, context_name);
    this.uvm_process_report_message(l_report_message);
  }
  
  // protected
  void uvm_process_report_message(uvm_report_message msg) {
    import uvm.base.uvm_report_server;
    uvm_report_object ro = _m_modified_report_message.get_report_object();
    uvm_action a = ro.get_report_action(msg.get_severity(), msg.get_id());
    if (a) {
      string composed_message;
      uvm_report_server rs = _m_modified_report_message.get_report_server();

      msg.set_report_object(ro);
      msg.set_report_handler(_m_modified_report_message.get_report_handler());
      msg.set_report_server(rs);
      msg.set_file(ro.get_report_file_handle(msg.get_severity(), msg.get_id()));
      msg.set_action(a);
      // no need to compose when neither UVM_DISPLAY nor UVM_LOG is set
      if (a & (uvm_action_type.UVM_LOG|uvm_action_type.UVM_DISPLAY)) {
	composed_message = rs.compose_report_message(msg);
      }
      rs.execute_report_message(msg, composed_message);
    }
  }

  // Function -- NODOCS -- issue
  // Immediately issues the message which is currently being processed. This
  // is useful if the message is being ~CAUGHT~ but should still be emitted.
  //
  // Issuing a message will update the report_server stats, possibly multiple
  // times if the message is not ~CAUGHT~.

  static protected void issue() {
    import uvm.base.uvm_report_server;
    string composed_message;
    uvm_report_server rs = _m_modified_report_message.get_report_server();

    if (cast (uvm_action_type) (_m_modified_report_message.get_action()) !=
       uvm_action_type.UVM_NO_ACTION) {
      // no need to compose when neither UVM_DISPLAY nor UVM_LOG is set
      if (_m_modified_report_message.get_action() & (uvm_action_type.UVM_LOG|uvm_action_type.UVM_DISPLAY)) {
	composed_message = rs.compose_report_message(_m_modified_report_message);
      }
      rs.execute_report_message(_m_modified_report_message, composed_message);
    }
  }

  //process_all_report_catchers
  //method called by report_server.report to process catchers
  //

  static bool process_all_report_catchers(uvm_report_message rm) {
    synchronized (_uvm_once_inst) {
      bool thrown = true;
      uvm_severity orig_severity;

      uvm_report_object l_report_object = rm.get_report_object();

      static bool in_catcher;
      if (in_catcher) {
	return true;
      }
      in_catcher = true;

      uvm_callbacks_base.m_tracing = false;  //turn off cb tracing so catcher stuff doesn't print

      orig_severity = cast (uvm_severity) rm.get_severity();
      _m_modified_report_message = rm;

      auto catchers = uvm_report_cb.get_all_enabled(l_report_object);
      if (catchers.length > 0) {
	if (m_debug_flags & DO_NOT_MODIFY) {

	  version (PRESERVE_RANDSTATE) {
	    Process p = Process.self(); // Keep random stability
	    Random randstate;
	    if (p !is null)
	      p.getRandState(randstate);
	  }

	  _m_orig_report_message = cast (uvm_report_message) rm.clone();
	  assert (_m_orig_report_message !is null);

	  version (PRESERVE_RANDSTATE) {
	    if (p !is null)
	      p.setRandState(randstate);
	  }
	}

	foreach (catcher; catchers) {
	  uvm_severity prev_sev;

	  // no need to check for callback_mode
	  // get_all_enabled already does that

	  prev_sev = _m_modified_report_message.get_severity();
	  _m_set_action_called = false;
	  thrown = catcher.process_report_catcher();

	  // Set the action to the default action for the new severity
	  // if it is still at the default for the previous severity,
	  // unless it was explicitly set.
	  if (!_m_set_action_called &&
	      _m_modified_report_message.get_severity() != prev_sev &&
	      _m_modified_report_message.get_action() ==
	      l_report_object.get_report_action(prev_sev, "*@&*^*^*#")) {
	    _m_modified_report_message.set_action
	      (l_report_object.get_report_action
	       (_m_modified_report_message.get_severity(), "*@&*^*^*#"));
	  }

	  if (thrown is false) {
	    // bool break_loop = true;
	    final switch (orig_severity) {
	    case uvm_severity.UVM_FATAL:   _uvm_once_inst._m_caught_fatal++; break;
	    case uvm_severity.UVM_ERROR:   _uvm_once_inst._m_caught_error++; break;
	    case uvm_severity.UVM_WARNING: _uvm_once_inst._m_caught_warning++; break;
	    case uvm_severity.UVM_INFO:    // break_loop = false;
	      break;
	    }
	    // if (break_loop) {
	    break;
	    // }
	  }
	}

	//update counters if message was returned with demoted severity
	switch (orig_severity) {
	case uvm_severity.UVM_FATAL:
	  if (_m_modified_report_message.get_severity() < orig_severity) {
	    _uvm_once_inst._m_demoted_fatal++;
	  }
	  break;
	case uvm_severity.UVM_ERROR:
	  if (_m_modified_report_message.get_severity() < orig_severity) {
	    _uvm_once_inst._m_demoted_error++;
	  }
	  break;
	case uvm_severity.UVM_WARNING:
	  if (_m_modified_report_message.get_severity() < orig_severity) {
	    _uvm_once_inst._m_demoted_warning++;
	  }
	  break;
	default: break;
	}
      }
      in_catcher = false;
      uvm_callbacks_base.m_tracing = true;  //turn tracing stuff back on

      return thrown;
    }
  }


  //process_report_catcher
  //internal method to call user <catch()> method
  //

  private bool process_report_catcher// (string file=__FILE__,
  //  size_t line=__LINE__)
  () {
    // catch is a keyword in Dlang
    action_e act = this.do_catch();

    if (act == action_e.UNKNOWN_ACTION) {
      this.uvm_report_error("RPTCTHR",
			    "uvm_report_this.catch() in catcher instance " ~
			    this.get_name() ~ " must return THROW or CAUGHT",
			    uvm_verbosity.UVM_NONE, __FILE__, __LINE__);
    }

    if (m_debug_flags & DO_NOT_MODIFY) {
      _m_modified_report_message.copy(_m_orig_report_message);
    }

    if (act is action_e.CAUGHT  && !(m_debug_flags & DO_NOT_CATCH)) {
      return false;
    }
    return true;
  }


  // Function -- NODOCS -- summarize
  //
  // This function is called automatically by <uvm_report_server::report_summarize()>.
  // It prints the statistics for the active catchers.

  static void summarize() {
    synchronized (_uvm_once_inst) {
      import uvm.base.uvm_root: uvm_root;
      string s;
      string q;
      if (_uvm_once_inst._do_report) {
	q ~= "\n--- UVM Report catcher Summary ---\n\n\n";
	q ~= format("Number of demoted UVM_FATAL reports  :%5d\n",
		    _uvm_once_inst._m_demoted_fatal);
	q ~= format("Number of demoted UVM_ERROR reports  :%5d\n",
		    _uvm_once_inst._m_demoted_error);
	q ~= format("Number of demoted UVM_WARNING reports:%5d\n",
		    _uvm_once_inst._m_demoted_warning);
	q ~= format("Number of caught UVM_FATAL reports   :%5d\n",
		    _uvm_once_inst._m_caught_fatal);
	q ~= format("Number of caught UVM_ERROR reports   :%5d\n",
		    _uvm_once_inst._m_caught_error);
	q ~= format("Number of caught UVM_WARNING reports :%5d\n",
		    _uvm_once_inst._m_caught_warning);

	uvm_info_context("UVM/REPORT/CATCHER", q, uvm_verbosity.UVM_LOW, uvm_root.get());
      }
    }
  }
}
