// $Id: uvm_report_catcher.svh,v 1.1.2.10 2010/04/09 15:03:25 janick Exp $
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2009 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
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
import uvm.base.uvm_callback;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import uvm.meta.misc;
import uvm.meta.mcd;

import std.string: format;

alias uvm_callbacks!(uvm_report_object, uvm_report_catcher) uvm_report_cb;
alias uvm_callback_iter!(uvm_report_object, uvm_report_catcher) uvm_report_cb_iter;

// Redundant -- not used anywhere in UVM
// class sev_id_struct
// {
//   bool sev_specified ;
//   bool id_specified ;
//   uvm_severity_type sev ;
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
// so all factilities in the <uvm_callback> and <uvm_callbacks#(T,CB)>
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
//|  // To affect all reporters, use null for the object
//|  uvm_report_cb::add(null, demoter);
//|
//|  // To affect some specific object use the specific reporter
//|  uvm_report_cb::add(mytest.myenv.myagent.mydriver, demoter);
//|
//|  // To affect some set of components using the component name
//|  uvm_report_cb::add_by_name("*.*driver", demoter);
//| end
//
//
//------------------------------------------------------------------------------

class uvm_once_report_catcher
{
  @uvm_private_sync private uvm_severity_type _m_modified_severity;
  @uvm_private_sync private int _m_modified_verbosity;
  @uvm_private_sync private string _m_modified_id;
  @uvm_private_sync private string _m_modified_message;
  @uvm_private_sync private string _m_file_name;
  @uvm_private_sync private size_t _m_line_number;
  @uvm_private_sync private uvm_report_object _m_client;
  @uvm_private_sync private uvm_action _m_modified_action;
  @uvm_private_sync private bool _m_set_action_called;
  @uvm_private_sync private uvm_report_server _m_server;
  @uvm_private_sync private string _m_name;

  @uvm_private_sync private int _m_demoted_fatal;
  @uvm_private_sync private int _m_demoted_error;
  @uvm_private_sync private int _m_demoted_warning;
  @uvm_private_sync private int _m_caught_fatal;
  @uvm_private_sync private int _m_caught_error;
  @uvm_private_sync private int _m_caught_warning;

  @uvm_private_sync private int _m_debug_flags;

  @uvm_private_sync private uvm_severity_type _m_orig_severity;
  @uvm_private_sync private uvm_action _m_orig_action;
  @uvm_private_sync private string _m_orig_id;
  @uvm_private_sync private int _m_orig_verbosity;
  @uvm_private_sync private string _m_orig_message;

  @uvm_private_sync private bool _do_report;
}

abstract class uvm_report_catcher: uvm_callback
{

  // static uvm_once_report_catcher _once;
  mixin(uvm_once_sync!(uvm_once_report_catcher));

  // `uvm_register_cb(uvm_report_object,uvm_report_catcher)
  // FIXME -- this has moved to the constructor

  enum action_e: int
  {   UNKNOWN_ACTION,
      THROW,
      CAUGHT
      };

  mixin(declareEnums!action_e());


  enum int DO_NOT_CATCH = 1;
  enum int DO_NOT_MODIFY = 2;

  // Function: new
  //
  // Create a new report catcher. The name argument is optional, but
  // should generally be provided to aid in debugging.

  public this(string name = "uvm_report_catcher") {
    synchronized(this) {
      super(name);
      // do_report is a static variable and still it is being
      // initialized in the constructor. We inherit this functionality
      // from the SV version of UVM
      do_report = true;
      // FIXME -- this gets called everytime we instantiate a
      // report_catcher. Having it called once is sufficient.
      // The issue here is that SV uses static initilization to make
      // sure that the code is called only once. In Vlang, we do not
      // have any static initialization, and that is because we
      // support multiple uvm_root instances.
      uvm_callbacks!(uvm_report_object,
		     uvm_report_catcher).m_register_pair();
      do_report = true;
    }
  }

  // Group: Current Message State

  // Function: get_client
  //
  // Returns the <uvm_report_object> that has generated the message that
  // is currently being processes.

  static public uvm_report_object get_client() {
    return m_client;
  }

  // Function: get_severity
  //
  // Returns the <uvm_severity_type> of the message that is currently being
  // processed. If the severity was modified by a previously executed
  // catcher object (which re-threw the message), then the returned
  // severity is the modified value.

  static public uvm_severity_type get_severity() {
    return m_modified_severity;
  }

  // Function: get_context
  //
  // Returns the context (source) of the message that is currently being
  // processed. This is typically the full hierarchical name of the component
  // that issued the message. However, when the message comes via a report
  // handler that is not associated with a component, the context is
  // user-defined.

  static public string get_context() {
    return m_name;
  }

  // Function: get_verbosity
  //
  // Returns the verbosity of the message that is currently being
  // processed. If the verbosity was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // verbosity is the modified value.

  static public int get_verbosity() {
    return m_modified_verbosity;
  }

  // Function: get_id
  //
  // Returns the string id of the message that is currently being
  // processed. If the id was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // id is the modified value.

  static public string get_id() {
      return m_modified_id;
  }

  // Function: get_message
  //
  // Returns the string message of the message that is currently being
  // processed. If the message was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // message is the modified value.

  static public string get_message() {
    return m_modified_message;
  }

  // Function: get_action
  //
  // Returns the <uvm_action> of the message that is currently being
  // processed. If the action was modified by a previously executed
  // catcher (which re-threw the message), then the returned
  // action is the modified value.

  static public uvm_action get_action() {
    return m_modified_action;
  }

  // Function: get_fname
  //
  // Returns the file name of the message.

  static public string get_fname() {
    return m_file_name;
  }

  // Function: get_line
  //
  // Returns the line number of the message.

  static public size_t get_line() {
    return m_line_number;
  }

  // Group: Change Message State

  // Function: set_severity
  //
  // Change the severity of the message to ~severity~. Any other
  // report catchers will see the modified value.

  static protected void set_severity(uvm_severity_type severity) {
    m_modified_severity = severity;
  }

  // Function: set_verbosity
  //
  // Change the verbosity of the message to ~verbosity~. Any other
  // report catchers will see the modified value.

  static protected void set_verbosity(int verbosity) {
    m_modified_verbosity = verbosity;
  }

  // Function: set_id
  //
  // Change the id of the message to ~id~. Any other
  // report catchers will see the modified value.

  static protected void set_id(string id) {
    m_modified_id = id;
  }

  // Function: set_message
  //
  // Change the text of the message to ~message~. Any other
  // report catchers will see the modified value.

  static protected void set_message(string message) {
    m_modified_message = message;
  }

  // Function: set_action
  //
  // Change the action of the message to ~action~. Any other
  // report catchers will see the modified value.

  static protected void set_action(uvm_action action) {
    m_modified_action = action;
    m_set_action_called = true;
  }

  // Group: Debug

  // Function: get_report_catcher
  //
  // Returns the first report catcher that has ~name~.

  static public uvm_report_catcher get_report_catcher(string name) {
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

  static public void print_catcher(UVM_FILE file=0) {
    synchronized(typeid(uvm_report_catcher)) {
      string enabled;
      // static uvm_report_cb_iter iter = new(null);

      f_display(file, "-------------UVM REPORT CATCHERS----------------------------");

      foreach(catcher; uvm_report_cb.get_all(null)) {
	while(catcher !is null) {
	  if(catcher.callback_mode()) enabled = "ON";
	  else enabled = "OFF";
	}
	f_display(file, format("%20s : %s", catcher.get_name(), enabled));
      }
      f_display(file, "--------------------------------------------------------------");
    }
  }

  // Funciton: debug_report_catcher
  //
  // Turn on report catching debug information. ~what~ is a bitwise and of
  // * DO_NOT_CATCH  -- forces catch to be ignored so that all catchers see the
  //   the reports.
  // * DO_NOT_MODIFY -- forces the message to remain unchanged

  static public void debug_report_catcher(int what= 0) {
    m_debug_flags = what;
  }

  // Group: Callback Interface

  // Function: catch
  //
  // This is the method that is called for each registered report catcher.
  // There are no arguments to this function. The <Current Message State>
  // interface methods can be used to access information about the
  // current message being processed.

  abstract public action_e do_catch();


  // Group: Reporting

  import uvm.base.uvm_message_defines: uvm_report_mixin;
  mixin uvm_report_mixin;

  // Function: uvm_report_fatal
  //
  // Issues a fatal message using the current message's report object.
  // This message will bypass any message catching callbacks.

  static protected void uvm_report_fatal(string id, string message,
					 int verbosity, string fname = "",
					 size_t line = 0 ) {
    uvm_report(UVM_FATAL, id, message, verbosity, fname, line);
    // synchronized(this) {
    //   uvm_report_handler rh   = this.m_client.get_report_handler();
    //   uvm_action a    = rh.get_action(UVM_FATAL,id);
    //   UVM_FATAL f    = rh.get_file_handle(UVM_FATAL,id);

    //   string m    = this.m_server.compose_message(UVM_FATAL, this.m_name, id, message, fname, line);
    //   this.m_server.process_report(UVM_FATAL, this.m_name, id, message, a, f, fname, line,
    //				   m, verbosity, this.m_client);
    // }
  }


  // Function: uvm_report_error
  //
  // Issues a error message using the current message's report object.
  // This message will bypass any message catching callbacks.


  static protected void uvm_report_error(string id, string message,
					 int verbosity, string fname = "",
					 size_t line = 0 ) {
    uvm_report(UVM_ERROR, id, message, verbosity, fname, line);
    // synchronized(this) {
    //   uvm_report_handler rh   = this.m_client.get_report_handler();
    //   uvm_action a    = rh.get_action(UVM_ERROR,id);
    //   UVM_FILE f    = rh.get_file_handle(UVM_ERROR,id);

    //   string m    = this.m_server.compose_message(UVM_ERROR, this.m_name, id, message, fname, line);
    //   this.m_server.process_report(UVM_ERROR, this.m_name, id, message, a, f, fname, line,
    //				   m, verbosity, this.m_client);
    // }
  }


  // Function: uvm_report_warning
  //
  // Issues a warning message using the current message's report object.
  // This message will bypass any message catching callbacks.

  static protected void uvm_report_warning(string id, string message,
					   int verbosity, string fname = "",
					   size_t line = 0 ) {
    uvm_report(UVM_WARNING, id, message, verbosity, fname, line);
    // synchronized(this) {
    //   uvm_report_handler rh   = this.m_client.get_report_handler();
    //   uvm_action a    = rh.get_action(UVM_WARNING,id);
    //   UVM_FILE f    = rh.get_file_handle(UVM_WARNING,id);

    //   string m    = this.m_server.compose_message(UVM_WARNING, this.m_name, id, message, fname, line);
    //   this.m_server.process_report(UVM_WARNING, this.m_name, id, message, a, f, fname, line,
    //				   m, verbosity, this.m_client);
    // }
  }


  // Function: uvm_report_info
  //
  // Issues a info message using the current message's report object.
  // This message will bypass any message catching callbacks.

  static protected void uvm_report_info(string id, string message,
					int verbosity, string fname = "",
					size_t line = 0 ) {
    uvm_report(UVM_INFO, id, message, verbosity, fname, line);
    // synchronized(this) {
    //   uvm_report_handler rh    = this.m_client.get_report_handler();
    //   uvm_action a    = rh.get_action(UVM_INFO,id);
    //   UVM_FILE f     = rh.get_file_handle(UVM_INFO,id);

    //   string m     = this.m_server.compose_message(UVM_INFO,this.m_name, id, message, fname, line);
    //   this.m_server.process_report(UVM_INFO, this.m_name, id, message, a, f, fname, line,
    //				   m, verbosity, this.m_client);
    // }
  }

  // Function: uvm_report
  //
  // Issues a message using the current message's report object.
  // This message will bypass any message catching callbacks.

  static protected void uvm_report(uvm_severity_type severity, string id,
				   string message, int verbosity,
				   string fname = "", size_t line = 0) {
    synchronized(typeid(uvm_report_catcher)) {
      uvm_report_handler rh = _m_client.get_report_handler();
      uvm_action a = rh.get_action(severity, id);
      UVM_FILE f = rh.get_file_handle(severity, id);

      string m = _m_server.compose_message(severity, this.m_name, id,
					   message, fname, line);
      _m_server.process_report(severity, this.m_name, id, message, a , f,
			       fname, line, m, verbosity, this.m_client);
    }
  }

  // Function: issue
  // Immediately issues the message which is currently being processed. This
  // is useful if the message is being ~CAUGHT~ but should still be emitted.
  //
  // Issuing a message will update the report_server stats, possibly multiple
  // times if the message is not ~CAUGHT~.

  static protected void issue() {
    synchronized(typeid(uvm_report_catcher)) {
      uvm_report_handler rh = _m_client.get_report_handler();
      uvm_action a  =  _m_modified_action;
      UVM_FILE f  = rh.get_file_handle(this.m_modified_severity,
				       this.m_modified_id);
      string m  = _m_server.compose_message(this.m_modified_severity,
					    this.m_name,
					    this.m_modified_id,
					    this.m_modified_message,
					    this.m_file_name,
					    this.m_line_number);
      _m_server.process_report(this.m_modified_severity, this.m_name,
			       this.m_modified_id, this.m_modified_message,
			       a, f, this.m_file_name, this.m_line_number,
			       m, this.m_modified_verbosity,this.m_client);
    }
  }


  //process_all_report_catchers
  //method called by report_server.report to process catchers
  //

  static public bool process_all_report_catchers(uvm_report_server server,
						 uvm_report_object client,
						 ref uvm_severity_type severity,
						 string name,
						 ref string id,
						 ref string message,
						 ref int verbosity_level,
						 ref uvm_action action,
						 string filename,
						 size_t line) {
    synchronized(_once) {
      bool thrown = true;
      uvm_severity_type orig_severity;

      uvm_callbacks_base.m_tracing = false;  //turn off cb tracing so catcher stuff doesn't print

      _m_server             = server;
      _m_client             = client;
      orig_severity        = severity;
      _m_name               = name;
      _m_file_name          = filename;
      _m_line_number        = line;
      _m_modified_id        = id;
      _m_modified_severity  = severity;
      _m_modified_message   = message;
      _m_modified_verbosity = verbosity_level;
      _m_modified_action    = action;

      _m_orig_severity  = severity;
      _m_orig_id        = id;
      _m_orig_verbosity = verbosity_level;
      _m_orig_action    = action;
      _m_orig_message   = message;

      foreach(catcher; uvm_report_cb.get_all_enabled(null)) {
	uvm_severity_type prev_sev;

	prev_sev = _m_modified_severity;
	_m_set_action_called = 0;
	thrown = catcher.process_report_catcher();

	// Set the action to the default action for the new severity
	// if it is still at the default for the previous severity,
	// unless it was explicitly set.
	if (!_m_set_action_called &&
	    _m_modified_severity !is prev_sev &&
	    _m_modified_action is _m_client.get_report_action(prev_sev, "*@&*^*^*#")) {
	  _m_modified_action = _m_client.get_report_action(_m_modified_severity, "*@&*^*^*#");
	}

	if(thrown is false) {
	  bool break_loop = true;
	  switch(orig_severity) {
	  case UVM_FATAL:   _m_caught_fatal++; break;
	  case UVM_ERROR:   _m_caught_error++; break;
	  case UVM_WARNING: _m_caught_warning++; break;
	  default: break_loop = false; break;
	  }
	  if(break_loop) break;
	}
      }

      //update counters if message was returned with demoted severity
      switch(orig_severity) {
      case UVM_FATAL: if(_m_modified_severity < orig_severity) _m_demoted_fatal++;
	break;
      case UVM_ERROR: if(_m_modified_severity < orig_severity) _m_demoted_error++;
	break;
      case UVM_WARNING: if(_m_modified_severity < orig_severity) _m_demoted_warning++;
	break;
      default: break;
      }

      uvm_callbacks_base.m_tracing = true;  //turn tracing stuff back on

      severity        = _m_modified_severity;
      id              = _m_modified_id;
      message         = _m_modified_message;
      verbosity_level = _m_modified_verbosity;
      action          = _m_modified_action;

      return thrown;
    }
  }


  //process_report_catcher
  //internal method to call user catch() method
  //

  private bool process_report_catcher(string file=__FILE__,
				      size_t line=__LINE__)() {
    action_e act = this.do_catch();

    if(act is UNKNOWN_ACTION) {
      this.uvm_report_error("RPTCTHR",
			    "uvm_report_this.catch() in catcher instance " ~
			    this.get_name() ~ " must return THROW or CAUGHT",
			    UVM_NONE, __FILE__, __LINE__);
    }

    synchronized(_once) {
      if(m_debug_flags & DO_NOT_MODIFY) {
	m_modified_severity    = m_orig_severity;
	m_modified_id          = m_orig_id;
	m_modified_verbosity   = m_orig_verbosity;
	m_modified_action      = m_orig_action;
	m_modified_message     = m_orig_message;
      }

      if(act is CAUGHT  && !(m_debug_flags & DO_NOT_CATCH)) {
	return false;
      }
      return true;
    }
  }

  //f_display
  //internal method to check if file is open
  //

  static private void f_display(UVM_FILE file, string str) {
    synchronized(typeid(uvm_report_catcher)) {
      if (file is 0) vdisplay("%s", str);
      else vfdisplay(file, "%s", str);
    }
  }

  // Function: summarize_report_catcher
  //
  // This public is called automatically by <uvm_report_server::summarize()>.
  // It prints the statistics for the active catchers.

  static public void summarize_report_catcher(UVM_FILE file) {
    synchronized(typeid(uvm_report_catcher)) {
      string s;
      if(do_report) {
	f_display(file, "");
	f_display(file, "--- UVM Report catcher Summary ---");
	f_display(file, "");
	f_display(file, "");
	f_display(file, format("Number of demoted UVM_FATAL reports  :%5d",
			       m_demoted_fatal));
	f_display(file, format("Number of demoted UVM_ERROR reports  :%5d",
			       m_demoted_error));
	f_display(file, format("Number of demoted UVM_WARNING reports:%5d",
			       m_demoted_warning));
	f_display(file, format("Number of caught UVM_FATAL reports   :%5d",
			       m_caught_fatal));
	f_display(file, format("Number of caught UVM_ERROR reports   :%5d",
			       m_caught_error));
	f_display(file, format("Number of caught UVM_WARNING reports :%5d",
			       m_caught_warning));
      }
    }
  }
}
