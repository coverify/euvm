// $Id: uvm_report_catcher.svh,v 1.1.2.10 2010/04/09 15:03:25 janick Exp $
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2009 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2014-2016 Coverify Systems Technology
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

import uvm.base.uvm_report_object;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_server;
import uvm.base.uvm_report_message;
import uvm.base.uvm_callback;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import uvm.base.uvm_object;
import uvm.base.uvm_globals;
import uvm.meta.misc;
import uvm.meta.mcd;

import std.string: format;
import std.random: Random;
import std.traits: isIntegral;
import esdl.data.bvec: isBitVector;
import esdl.base.core: Process;

alias uvm_report_cb = uvm_callbacks!(uvm_report_object, uvm_report_catcher);
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

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_catcher
//
// The uvm_report_catcher is used to catch messages issued by the uvm report
// server. Catchers are
// uvm_callbacks#(<uvm_report_object>,uvm_report_catcher) objects,
// so all facilities in the <uvm_callback> and <uvm_callbacks#(T,CB)>
// classes are available for registering catchers and controlling catcher
// state.
// The uvm_callbacks#(<uvm_report_object>,uvm_report_catcher) class is
// aliased to ~uvm_report_cb~ to make it easier to use.
// Multiple report catchers can be
// registered with a report object. The catchers can be registered as default
// catchers which catch all reports on all <uvm_report_object> reporters,
// or catchers can be attached to specific report objects (i.e. components).
//
// User extensions of <uvm_report_catcher> must implement the <catch> method in
// which the action to be taken on catching the report is specified. The catch
// method can return ~CAUGHT~, in which case further processing of the report is
// immediately stopped, or return ~THROW~ in which case the (possibly modified) report
// is passed on to other registered catchers. The catchers are processed in the order
// in which they are registered.
//
// On catching a report, the <catch> method can modify the severity, id, action,
// verbosity or the report string itself before the report is finally issued by
// the report server. The report can be immediately issued from within the catcher
// class by calling the <issue> method.
//
// The catcher maintains a count of all reports with FATAL,ERROR or WARNING severity
// and a count of all reports with FATAL, ERROR or WARNING severity whose severity
// was lowered. These statistics are reported in the summary of the <uvm_report_server>.
//
// This example shows the basic concept of creating a report catching
// callback and attaching it to all messages that get emitted:
//
//| class my_error_demoter extends uvm_report_catcher;
//|   function new(string name="my_error_demoter");
//|     super.new(name);
//|   endfunction
//|   //This example demotes "MY_ID" errors to an info message
//|   function action_e catch();
//|     if(get_severity() is UVM_ERROR && get_id() == "MY_ID")
//|       set_severity(UVM_INFO);
//|     return THROW;
//|   endfunction
//| endclass
//|
//| my_error_demoter demoter = new;
//| initial begin
//|  // Catchers are callbacks on report objects (components are report
//|  // objects, so catchers can be attached to components).
//|
//|  // To affect all reporters, use ~null~ for the object
//|  uvm_report_cb::add(null, demoter);
//|
//|  // To affect some specific object use the specific reporter
//|  uvm_report_cb::add(mytest.myenv.myagent.mydriver, demoter);
//|
//|  // To affect some set of components (any "*driver" under mytest.myenv)
//|  // using the component name
//|  uvm_report_cb::add_by_name("*driver", demoter, mytest.myenv);
//| end
//
//
//------------------------------------------------------------------------------

abstract class uvm_report_catcher: uvm_callback
{

  static class uvm_once
  {
    @uvm_none_sync
    private uvm_report_message _m_modified_report_message;
    @uvm_none_sync
    private uvm_report_message _m_orig_report_message;
    @uvm_none_sync
    private bool _m_set_action_called;

    // Counts for the demoteds and caughts
    @uvm_none_sync
    private int _m_demoted_fatal;
    @uvm_none_sync
    private int _m_demoted_error;
    @uvm_none_sync
    private int _m_demoted_warning;
    @uvm_none_sync
    private int _m_caught_fatal;
    @uvm_none_sync
    private int _m_caught_error;
    @uvm_none_sync
    private int _m_caught_warning;

    // Flag counts
    @uvm_none_sync
    private int _m_debug_flags;

    @uvm_none_sync
    private bool _do_report;
  };

  mixin(uvm_once_sync_string);

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

  mixin(declareEnums!action_e());


  // Function: new
  //
  // Create a new report catcher. The name argument is optional, but
  // should generally be provided to aid in debugging.

  this(string name = "uvm_report_catcher") {
    synchronized(this) {
      super(name);
    }
    synchronized(once) {
      // do_report is a static variable and still it is being
      // initialized in the constructor. We inherit this functionality
      // from the SV version of UVM
      once._do_report = true;
    }
  }

  // Group: Current Message State

  // Function: get_client
  //
  // Returns the <uvm_report_object> that has generated the message that
  // is currently being processed.

  static uvm_report_object get_client() {
    synchronized(once) {
      return once._m_modified_report_message.get_report_object();
    }
  }

  // Function: get_severity
  //
  // Returns the <uvm_severity> of the message that is currently being
  // processed. If the severity was modified by a previously executed
  // catcher object (which re-threw the message), then the returned
  // severity is the modified value.

  static uvm_severity get_severity() {
    synchronized(once) {
      return once._m_modified_report_message.get_severity();
    }
  }

  // Function: get_context
  //
  // Returns the context name of the message that is currently being
  // processed. This is typically the full hierarchical name of the component
  // that issued the message. However, if user-defined context is set from
  // a uvm_report_message, the user-defined context will be returned.

  static string get_context() {
    synchronized(once) {
      string context_str = once._m_modified_report_message.get_context();
      if (context_str == "") {
	uvm_report_handler rh =
	  once._m_modified_report_message.get_report_handler();
	context_str = rh.get_full_name();
      }
      return context_str;
    }
  }

  // Function: get_verbosity
  //
  // Returns the verbosity of the message that is currently being
  // processed. If the verbosity was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // verbosity is the modified value.

  static int get_verbosity() {
    synchronized(once) {
      return once._m_modified_report_message.get_verbosity();
    }
  }

  // Function: get_id
  //
  // Returns the string id of the message that is currently being
  // processed. If the id was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // id is the modified value.

  static string get_id() {
    synchronized(once) {
      return once._m_modified_report_message.get_id();
    }
  }

  // Function: get_message
  //
  // Returns the string message of the message that is currently being
  // processed. If the message was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // message is the modified value.

  static string get_message() {
    synchronized(once) {
      return once._m_modified_report_message.get_message();
    }
  }

  // Function: get_action
  //
  // Returns the <uvm_action> of the message that is currently being
  // processed. If the action was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // action is the modified value.

  static uvm_action get_action() {
    synchronized(once) {
      return once._m_modified_report_message.get_action();
    }
  }

  // Function: get_fname
  //
  // Returns the file name of the message.

  static string get_fname() {
    synchronized(once) {
      return once._m_modified_report_message.get_filename();
    }
  }

  // Function: get_line
  //
  // Returns the line number of the message.

  static size_t get_line() {
    synchronized(once) {
      return once._m_modified_report_message.get_line();
    }
  }

  // Function: get_element_container
  //
  // Returns the element container of the message.

  static uvm_report_message_element_container get_element_container() {
    synchronized(once) {
      return once._m_modified_report_message.get_element_container();
    }
  }

  // Group: Change Message State

  // Function: set_severity
  //
  // Change the severity of the message to ~severity~. Any other
  // report catchers will see the modified value.

  static protected void set_severity(uvm_severity severity) {
    synchronized(once) {
      once._m_modified_report_message.set_severity(severity);
    }
  }

  // Function: set_verbosity
  //
  // Change the verbosity of the message to ~verbosity~. Any other
  // report catchers will see the modified value.

  static protected void set_verbosity(int verbosity) {
    synchronized(once) {
      once._m_modified_report_message.set_verbosity(verbosity);
    }
  }

  // Function: set_id
  //
  // Change the id of the message to ~id~. Any other
  // report catchers will see the modified value.

  static protected void set_id(string id) {
    synchronized(once) {
      once._m_modified_report_message.set_id(id);
    }
  }

  // Function: set_message
  //
  // Change the text of the message to ~message~. Any other
  // report catchers will see the modified value.

  static protected void set_message(string message) {
    synchronized(once) {
      once._m_modified_report_message.set_message(message);
    }
  }

  // Function: set_action
  //
  // Change the action of the message to ~action~. Any other
  // report catchers will see the modified value.

  static protected void set_action(uvm_action action) {
    synchronized(once) {
      once._m_modified_report_message.set_action(action);
      once._m_set_action_called = true;
    }
  }


  // Function: set_context
  //
  // Change the context of the message to ~context_str~. Any other
  // report catchers will see the modified value.

  static protected void set_context(string context_str) {
    synchronized(once) {
      once._m_modified_report_message.set_context(context_str);
    }
  }

  // Function: add_int
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
			       (UVM_LOG|UVM_RM_RECORD))
    if(isBitVector!T || isIntegral!T) {
      synchronized(once) {
	once._m_modified_report_message.add(name, value, radix, action);
      }
    }

  static protected void add_int(string name,
				uvm_bitstream_t value,
				int size,
				uvm_radix_enum radix,
				uvm_action action =
				(UVM_LOG|UVM_RM_RECORD)) {
    synchronized(once) {
      once._m_modified_report_message.add_int(name, value, size, radix, action);
    }
  }

  // Function: add_string
  //
  // Adds a string of the name ~name~ and value ~value~ to the
  // message. Any other report catchers will see the newly
  // added element.
  //

  static protected void add(T)(string name,
			       T value,
			       uvm_action action =
			       (UVM_LOG|UVM_RM_RECORD))
    if(is(T == string)) {
      synchronized(once) {
	once._m_modified_report_message.add(name, value, action);
      }
    }

  alias add_string = add!string;
  // Function: add_object
  //
  // Adds a uvm_object of the name ~name~ and reference ~obj~ to
  // the message. Any other report catchers will see the newly
  // added element.
  //

  static protected void add(T)(string name,
			       T obj,
			       uvm_action action =
			       (UVM_LOG|UVM_RM_RECORD))
    if(is(T: uvm_object)) {
      synchronized(once) {
	once._m_modified_report_message.add(name, obj, action);
      }
    }

  alias add_object = add!(uvm_object);

  // Group: Debug

  // Function: get_report_catcher
  //
  // Returns the first report catcher that has ~name~.

  static uvm_report_catcher get_report_catcher(string name) {
    // static uvm_report_cb_iter iter = new uvm_report_cb_iter(null);
    foreach(catcher; uvm_report_cb.get_all_enabled(null)) {
      if(catcher.get_name() == name) {
	return catcher;
      }
    }
    return null;
  }


  // Function: print_catcher
  //
  // Prints information about all of the report catchers that are
  // registered. For finer grained detail, the <uvm_callbacks #(T,CB)::display>
  // method can be used by calling uvm_report_cb::display(<uvm_report_object>).

  static void print_catcher(UVM_FILE file=0) {
    string enabled;
    // static uvm_report_cb_iter iter = new(null);
    string q;
    q ~= "-------------UVM REPORT CATCHERS----------------------------\n";

    foreach(catcher; uvm_report_cb.get_all(null)) {
      while(catcher !is null) {
	if(catcher.callback_mode()) {
	  enabled = "ON";
	}
	else {
	  enabled = "OFF";
	}
      }
      q ~= format("%20s : %s\n", catcher.get_name(), enabled);
    }
    q ~= "--------------------------------------------------------------\n";
    uvm_info_context("UVM/REPORT/CATCHER", q, UVM_LOW, uvm_top);

  }

  // Funciton: debug_report_catcher
  //
  // Turn on report catching debug information. ~what~ is a bitwise AND of
  // * DO_NOT_CATCH  -- forces catch to be ignored so that all catchers see the
  //   the reports.
  // * DO_NOT_MODIFY -- forces the message to remain unchanged

  static void debug_report_catcher(int what= 0) {
    synchronized(once) {
      once._m_debug_flags = what;
    }
  }

  // Group: Callback Interface

  // Function: catch
  //
  // This is the method that is called for each registered report catcher.
  // There are no arguments to this function. The <Current Message State>
  // interface methods can be used to access information about the
  // current message being processed.

  // catch is a keyword in Dlang
  abstract action_e do_catch();


  // Group: Reporting

  import uvm.base.uvm_message_defines: uvm_report_mixin;
  mixin uvm_report_mixin;

  // Function: uvm_report_fatal
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
    this.uvm_report(UVM_FATAL, id, message, UVM_NONE, fname, line,
		    context_name, report_enabled_checked);
  }


  // Function: uvm_report_error
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

    this.uvm_report(UVM_ERROR, id, message, UVM_NONE, fname, line,
		    context_name, report_enabled_checked);
  }


  // Function: uvm_report_warning
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
    this.uvm_report(UVM_WARNING, id, message, UVM_NONE, fname, line,
		    context_name, report_enabled_checked);
  }


  // Function: uvm_report_info
  //
  // Issues a info message using the current message's report object.
  // This message will bypass any message catching callbacks.

  protected void uvm_report_info(string id,
				 string message,
				 int verbosity,
				 string fname = "",
				 size_t line = 0,
				 string context_name = "",
				 bool report_enabled_checked = 0) {
    this.uvm_report(UVM_INFO, id, message, verbosity, fname, line,
		    context_name, report_enabled_checked);
  }

  // Function: uvm_report
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
  static void uvm_process_report_message(uvm_report_message msg) {
    synchronized(once) {
      uvm_report_object ro = once._m_modified_report_message.get_report_object();
      uvm_action a = ro.get_report_action(msg.get_severity(), msg.get_id());
      if(a) {
	string composed_message;
	uvm_report_server rs = once._m_modified_report_message.get_report_server();

	msg.set_report_object(ro);
	msg.set_report_handler(once._m_modified_report_message.get_report_handler());
	msg.set_report_server(rs);
	msg.set_file(ro.get_report_file_handle(msg.get_severity(), msg.get_id()));
	msg.set_action(a);
	// no need to compose when neither UVM_DISPLAY nor UVM_LOG is set
	if (a & (UVM_LOG|UVM_DISPLAY)) {
	  composed_message = rs.compose_report_message(msg);
	}
	rs.execute_report_message(msg, composed_message);
      }
    }
  }

  // Function: issue
  // Immediately issues the message which is currently being processed. This
  // is useful if the message is being ~CAUGHT~ but should still be emitted.
  //
  // Issuing a message will update the report_server stats, possibly multiple
  // times if the message is not ~CAUGHT~.

  static protected void issue() {
    synchronized(once) {
      string composed_message;
      uvm_report_server rs = once._m_modified_report_message.get_report_server();

      if(cast(uvm_action_type) (once._m_modified_report_message.get_action()) !=
	 UVM_NO_ACTION) {
	// no need to compose when neither UVM_DISPLAY nor UVM_LOG is set
	if(once._m_modified_report_message.get_action() & (UVM_LOG|UVM_DISPLAY)) {
	  composed_message = rs.compose_report_message(once._m_modified_report_message);
	}
	rs.execute_report_message(once._m_modified_report_message, composed_message);
      }
    }
  }

  //process_all_report_catchers
  //method called by report_server.report to process catchers
  //

  static bool process_all_report_catchers(uvm_report_message rm) {
    synchronized(once) {
      bool thrown = true;
      uvm_severity orig_severity;

      uvm_report_object l_report_object = rm.get_report_object();

      static bool in_catcher;
      if(in_catcher) {
	return true;
      }
      in_catcher = true;

      uvm_callbacks_base.m_tracing = false;  //turn off cb tracing so catcher stuff doesn't print

      orig_severity = cast(uvm_severity) rm.get_severity();
      once._m_modified_report_message = rm;

      auto catchers = uvm_report_cb.get_all_enabled(l_report_object);
      if(catchers.length > 0) {
	if(once._m_debug_flags & DO_NOT_MODIFY) {
	  Process p = Process.self(); // Keep random stability
	  Random randstate;
	  if (p !is null) {
	    randstate = p.getRandState();
	  }
	  once._m_orig_report_message = cast(uvm_report_message) rm.clone();
	  assert(once._m_orig_report_message !is null);
	  if (p !is null) {
	    p.setRandState(randstate);
	  }
	}

	foreach(catcher; catchers) {
	  uvm_severity prev_sev;

	  // no need to check for callback_mode
	  // get_all_enabled already does that

	  prev_sev = once._m_modified_report_message.get_severity();
	  once._m_set_action_called = 0;
	  thrown = catcher.process_report_catcher();

	  // Set the action to the default action for the new severity
	  // if it is still at the default for the previous severity,
	  // unless it was explicitly set.
	  if (!once._m_set_action_called &&
	      once._m_modified_report_message.get_severity() != prev_sev &&
	      once._m_modified_report_message.get_action() ==
	      l_report_object.get_report_action(prev_sev, "*@&*^*^*#")) {
	    once._m_modified_report_message.set_action
	      (l_report_object.get_report_action
	       (once._m_modified_report_message.get_severity(), "*@&*^*^*#"));
	  }

	  if(thrown is false) {
	    // bool break_loop = true;
	    final switch(orig_severity) {
	    case UVM_FATAL:   once._m_caught_fatal++; break;
	    case UVM_ERROR:   once._m_caught_error++; break;
	    case UVM_WARNING: once._m_caught_warning++; break;
	    case UVM_INFO:    // break_loop = false;
	      break;
	    }
	    // if(break_loop) {
	    break;
	    // }
	  }
	}

	//update counters if message was returned with demoted severity
	switch(orig_severity) {
	case UVM_FATAL:
	  if(once._m_modified_report_message.get_severity() < orig_severity) {
	    once._m_demoted_fatal++;
	  }
	  break;
	case UVM_ERROR:
	  if(once._m_modified_report_message.get_severity() < orig_severity) {
	    once._m_demoted_error++;
	  }
	  break;
	case UVM_WARNING:
	  if(once._m_modified_report_message.get_severity() < orig_severity) {
	    once._m_demoted_warning++;
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

    if(act == UNKNOWN_ACTION) {
      this.uvm_report_error("RPTCTHR",
			    "uvm_report_this.catch() in catcher instance " ~
			    this.get_name() ~ " must return THROW or CAUGHT",
			    UVM_NONE, __FILE__, __LINE__);
    }

    synchronized(once) {
      if(once._m_debug_flags & DO_NOT_MODIFY) {
	once._m_modified_report_message.copy(once._m_orig_report_message);
      }

      if(act is CAUGHT  && !(once._m_debug_flags & DO_NOT_CATCH)) {
	return false;
      }
      return true;
    }
  }


  // Function: summarize
  //
  // This function is called automatically by <uvm_report_server::report_summarize()>.
  // It prints the statistics for the active catchers.

  static void summarize() {
    synchronized(once) {
      string s;
      string q;
      if(once._do_report) {
	q ~= "\n--- UVM Report catcher Summary ---\n\n\n";
	q ~= format("Number of demoted UVM_FATAL reports  :%5d\n",
		    once._m_demoted_fatal);
	q ~= format("Number of demoted UVM_ERROR reports  :%5d\n",
		    once._m_demoted_error);
	q ~= format("Number of demoted UVM_WARNING reports:%5d\n",
		    once._m_demoted_warning);
	q ~= format("Number of caught UVM_FATAL reports   :%5d\n",
		    once._m_caught_fatal);
	q ~= format("Number of caught UVM_ERROR reports   :%5d\n",
		    once._m_caught_error);
	q ~= format("Number of caught UVM_WARNING reports :%5d\n",
		    once._m_caught_warning);

	uvm_info_context("UVM/REPORT/CATCHER", q, UVM_LOW, uvm_top);
      }
    }
  }
}
