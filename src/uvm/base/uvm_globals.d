//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2013-2014 NVIDIA Corporation
//   Copyright 2012-2016 Coverify Systems Technology
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


// Title: Globals

//------------------------------------------------------------------------------
//
// Group: Simulation Control
//
//------------------------------------------------------------------------------

// Task: run_test
//
// Convenience function for uvm_top.run_test(). See <uvm_root> for more
// information.

module uvm.base.uvm_globals;
import uvm.base.uvm_root;
import uvm.base.uvm_component;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_message;
import uvm.base.uvm_coreservice;

import esdl.base.core: wait;

import std.traits: EnumMembers;
import std.conv;

version(UVM_NO_DEPRECATED) { }
 else {
   version = UVM_INCLUDE_DEPRECATED;
 }

void run_test (string test_name = "") {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  auto top = cs.get_root();
  top.run_test(test_name);
}

version (UVM_INCLUDE_DEPRECATED) {
  import uvm.base.uvm_objection;
  import esdl.data.time;
  import esdl.base.core: EntityIntf, SimTime;
  // Variable- uvm_test_done - DEPRECATED
  //
  // An instance of the <uvm_test_done_objection> class, this object is
  // used by components to coordinate when to end the currently running
  // task-based phase. When all participating components have dropped their
  // raised objections, an implicit call to <global_stop_request> is issued
  // to end the run phase (or any other task-based phase).

  uvm_test_done_objection uvm_test_done() {
    return uvm_test_done_objection.get();
  }


  // Method- global_stop_request  - DEPRECATED
  //
  // Convenience function for uvm_test_done.stop_request(). See
  // <uvm_test_done_objection::stop_request> for more information.

  void global_stop_request() {
    uvm_test_done_objection tdo = uvm_test_done_objection.get();
    tdo.stop_request();
  }


  // Method- set_global_timeout  - DEPRECATED
  //
  // Convenience function for uvm_top.set_timeout(). See
  // <uvm_root::set_timeout> for more information.  The overridable bit
  // controls whether subsequent settings will be honored.


  void set_global_timeout(Time timeout, bool overridable = true) {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    auto top = cs.get_root();
    top.set_timeout(timeout, overridable);
  }


  // Function- set_global_stop_timeout - DEPRECATED
  //
  // Convenience function for uvm_test_done.stop_timeout = timeout.
  // See <uvm_uvm_test_done::stop_timeout> for more information.

  void set_global_stop_timeout(Time timeout) {
    uvm_test_done_objection tdo = uvm_test_done_objection.get();
    tdo.stop_timeout = SimTime(EntityIntf.getContextEntity(), timeout);
  }

  void set_global_stop_timeout(SimTime timeout) {
    uvm_test_done_objection tdo = uvm_test_done_objection.get();
    tdo.stop_timeout = timeout;
  }

}

//----------------------------------------------------------------------------
//
// Group: Reporting
//
//----------------------------------------------------------------------------

// import uvm.base.uvm_message_defines: uvm_report_mixin;
// mixin uvm_report_mixin;

// MACRO: `uvm_info
//
//| `uvm_info(ID,MSG,VERBOSITY)
//
// Calls uvm_report_info if ~VERBOSITY~ is lower than the configured verbosity of
// the associated reporter. ~ID~ is given as the message tag and ~MSG~ is given as
// the message text. The file and line are also sent to the uvm_report_info call.
//

void uvm_info(string file=__FILE__,
	      size_t line=__LINE__)(string id, string message,
				    int verbosity) {
  if (uvm_report_enabled(verbosity, UVM_INFO, id)) {
    uvm_report_info(id, message, verbosity, file, line);
  }
}

void uvm_info(string file=__FILE__,
	      size_t line=__LINE__,
	      T...)(string id, string message, int verbosity, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (uvm_report_enabled(verbosity, UVM_INFO, id)) {
    uvm_report_info(id, message, verbosity, file, line, "", false, t);
  }
 }


// MACRO: `uvm_warning
//
//| `uvm_warning(ID,MSG)
//
// Calls uvm_report_warning with a verbosity of UVM_NONE. The message can not
// be turned off using the reporter's verbosity setting, but can be turned off
// by setting the action for the message.  ~ID~ is given as the message tag and
// ~MSG~ is given as the message text. The file and line are also sent to the
// uvm_report_warning call.

void uvm_warning(string file=__FILE__,
		 size_t line=__LINE__)(string id, string message) {
  if (uvm_report_enabled(UVM_NONE, UVM_WARNING, id))
    uvm_report_warning(id, message, UVM_NONE, file, line);
}

void uvm_warning(string file=__FILE__,
		 size_t line=__LINE__,
		 T...)(string id, string message, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (uvm_report_enabled(UVM_NONE, UVM_WARNING, id)) {
    uvm_report_warning(id, message, UVM_NONE, file, line, "", false, t);
  }
 }

// MACRO: `uvm_error
//
//| `uvm_error(ID,MSG)
//
// Calls uvm_report_error with a verbosity of UVM_NONE. The message can not
// be turned off using the reporter's verbosity setting, but can be turned off
// by setting the action for the message.  ~ID~ is given as the message tag and
// ~MSG~ is given as the message text. The file and line are also sent to the
// uvm_report_error call.

void uvm_error(string file=__FILE__,
	       size_t line=__LINE__)(string id, string message) {
  if (uvm_report_enabled(UVM_NONE, UVM_ERROR, id))
    uvm_report_error(id, message, UVM_NONE, file, line);
}

void uvm_error(string file=__FILE__,
	       size_t line=__LINE__,
	       T...)(string id, string message, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (uvm_report_enabled(UVM_NONE, UVM_ERROR, id)) {
    uvm_report_error(id, message, UVM_NONE, file, line, "", false, t);
  }
 }

// MACRO: `uvm_fatal
//
//| `uvm_fatal(ID,MSG)
//
// Calls uvm_report_fatal with a verbosity of UVM_NONE. The message can not
// be turned off using the reporter's verbosity setting, but can be turned off
// by setting the action for the message.  ~ID~ is given as the message tag and
// ~MSG~ is given as the message text. The file and line are also sent to the
// uvm_report_fatal call.

void uvm_fatal(string file=__FILE__,
	       size_t line=__LINE__)(string id, string message) {
  if (uvm_report_enabled(UVM_NONE, UVM_FATAL, id))
    uvm_report_fatal(id, message, UVM_NONE, file, line);
}

void uvm_fatal(string file=__FILE__,
	       size_t line=__LINE__,
	       T...)(string id, string message, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (uvm_report_enabled(UVM_NONE, UVM_FATAL, id)) {
    uvm_report_fatal(id, message, UVM_NONE, file, line, "", false, t);
  }
 }

// MACRO: `uvm_info_context
//
//| `uvm_info_context(ID,MSG,VERBOSITY,CNTXT)
//
// Operates identically to `uvm_info but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

void uvm_info_context(string file=__FILE__,
		      size_t line=__LINE__)(string id, string message,
					    int verbosity,
					    uvm_report_object context) {
  if (context.uvm_report_enabled(verbosity, UVM_INFO, id))
    context.uvm_report_info(id, message, verbosity, file, line);
}

void uvm_info_context(string file=__FILE__,
		      size_t line=__LINE__,
		      T...)(string id, string message, int verbosity,
			    uvm_report_object context, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (context.uvm_report_enabled(verbosity, UVM_INFO, id)) {
    context.uvm_report_info(id, message, verbosity, file, line, "", false, t);
  }
 }

// MACRO: `uvm_warning_context
//
//| `uvm_warning_context(ID,MSG,CNTXT)
//
// Operates identically to `uvm_warning but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

void uvm_warning_context(string file=__FILE__,
			 size_t line=__LINE__)
  (string id, string message, uvm_report_object context) {
  if (context.uvm_report_enabled(UVM_NONE, UVM_WARNING, id))
    context.uvm_report_warning(id, message, UVM_NONE, file, line);
}

void uvm_warning_context(string file=__FILE__,
			 size_t line=__LINE__,
			 T...)(string id, string message,
			       uvm_report_object context, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (context.uvm_report_enabled(UVM_NONE, UVM_WARNING, id)) {
    context.uvm_report_warning(id, message, UVM_NONE, file, line, "", false, t);
  }
 }
// MACRO: `uvm_error_context
//
//| `uvm_error_context(ID,MSG,CNTXT)
//
// Operates identically to `uvm_error but requires that the
// context, or <uvm_report_object> in which the message is printed be
// explicitly supplied as a macro argument.

void uvm_error_context(string file=__FILE__,
		       size_t line=__LINE__)
  (string id, string message, uvm_report_object context) {
  if (context.uvm_report_enabled(UVM_NONE, UVM_ERROR, id))
    context.uvm_report_error(id, message, UVM_NONE, file, line);
}

void uvm_error_context(string file=__FILE__,
		       size_t line=__LINE__,
		       T...)(string id, string message,
			     uvm_report_object context, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (context.uvm_report_enabled(UVM_NONE, UVM_ERROR, id)) {
    context.uvm_report_error(id, message, UVM_NONE, file, line, "", false, t);
  }
 }
// MACRO: `uvm_fatal_context
//
//| `uvm_fatal_context(ID,MSG,CNTXT)
//
// Operates identically to `uvm_fatal but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

void uvm_fatal_context(string file=__FILE__,
		       size_t line=__LINE__)
  (string id, string message, uvm_report_object context) {
  if (context.uvm_report_enabled(UVM_NONE, UVM_FATAL, id))
    context.uvm_report_fatal(id, message, UVM_NONE, file, line);
}

void uvm_fatal_context(string file=__FILE__,
		       size_t line=__LINE__,
		       T...)(string id, string message,
			     uvm_report_object context, T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  if (context.uvm_report_enabled(UVM_NONE, UVM_FATAL, id)) {
    context.uvm_report_fatal(id, message, UVM_NONE, file, line, "", false, t);
  }
 }

import uvm.base.uvm_object_globals;


// Function: uvm_get_report_object
//
// Returns the nearest uvm_report_object when called.
// For the global version, it returns uvm_root.
//
uvm_report_object uvm_get_report_object() {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  return top;
}


// Function: uvm_report_enabled
//
// Returns 1 if the configured verbosity in ~uvm_top~ for this
// severity/id is greater than or equal to ~verbosity~ else returns 0.
//
// See also <uvm_report_object::uvm_report_enabled>.
//
// Static methods of an extension of uvm_report_object, e.g. uvm_component-based
// objects, cannot call ~uvm_report_enabled~ because the call will resolve to
// the <uvm_report_object::uvm_report_enabled>, which is non-static.
// Static methods cannot call non-static methods of the same class.
int uvm_report_enabled (int verbosity,
			uvm_severity severity = uvm_severity.UVM_INFO,
			string id = "") {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  return top.uvm_report_enabled(verbosity, severity, id);
}

// Function: uvm_report

void uvm_report( uvm_severity severity,
		 string id,
		 string message,
		 int verbosity = int.min,
		 string filename = "",
		 size_t line = 0,
		 string context_name = "",
		 bool report_enabled_checked = false) {
  if(verbosity is int.min) {
    verbosity = (severity is UVM_ERROR) ? UVM_LOW :
      (severity is UVM_FATAL) ? UVM_NONE : UVM_MEDIUM;
  }

  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report(severity, id, message, verbosity, filename, line,
		 context_name, report_enabled_checked);
}

// Function: uvm_report_info

void uvm_report_info(string file=__FILE__,
		     size_t line=__LINE__)(string id,
					   string message,
					   int verbosity=uvm_verbosity.UVM_MEDIUM,
					   string context_name = "",
					   bool report_enabled_checked = false) {
  uvm_report_info(id, message, verbosity, file, line,
		  context_name, report_enabled_checked);
}

void uvm_report_info(string id,
		     string message,
		     int verbosity = uvm_verbosity.UVM_MEDIUM,
		     string filename = "",
		     size_t line = 0,
		     string context_name = "",
		     bool report_enabled_checked = false) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_info(id, message, verbosity, filename, line,
		      context_name, report_enabled_checked);
}

void uvm_report_info(string file=__FILE__,
		     size_t line=__LINE__,
		     T...)(string id,
			   string message,
			   int verbosity,
			   string context_name,
			   bool report_enabled_checked,
			   T t)
if(T.length > 0 && is(T[0 ]: uvm_report_message_element_base)) {
  uvm_report_info(id, message, verbosity, file, line,
		  context_name, report_enabled_checked, t);
}

void uvm_report_info(T...)(string id,
			   string message,
			   int verbosity,
			   string filename,
			   size_t line,
			   string context_name,
			   bool report_enabled_checked,
			   T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_info(id, message, verbosity, filename, line,
		      context_name, report_enabled_checked, t);
}

// Function: uvm_report_warning

void uvm_report_warning(string file=__FILE__,
			size_t line=__LINE__)(string id,
					      string message,
					      int verbosity=uvm_verbosity.UVM_MEDIUM,
					      string context_name = "",
					      bool report_enabled_checked = false) {
  uvm_report_warning(id, message, verbosity, file, line,
		     context_name, report_enabled_checked);
}

void uvm_report_warning(string id,
			string message,
			int verbosity = uvm_verbosity.UVM_MEDIUM,
			string filename = "",
			size_t line = 0,
			string context_name = "",
			bool report_enabled_checked = false) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_warning(id, message, verbosity, filename, line,
			 context_name, report_enabled_checked);
}

void uvm_report_warning(string file=__FILE__,
			size_t line=__LINE__,
			T...)(string id,
			      string message,
			      int verbosity,
			      string context_name,
			      bool report_enabled_checked,
			      T t)
if(T.length > 0 && is(T[0 ]: uvm_report_message_element_base)) {
  uvm_report_warning(id, message, verbosity, file, line,
		     context_name, report_enabled_checked, t);
 }

void uvm_report_warning(T...)(string id,
			      string message,
			      int verbosity,
			      string filename,
			      size_t line,
			      string context_name,
			      bool report_enabled_checked,
			      T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_warning(id, message, verbosity, filename, line,
			 context_name, report_enabled_checked, t);
 }

// Function: uvm_report_error

void uvm_report_error(string file=__FILE__,
		      size_t line=__LINE__)(string id,
					    string message,
					    int verbosity=uvm_verbosity.UVM_LOW,
					    string context_name = "",
					    bool report_enabled_checked = false) {
  uvm_report_error(id, message, verbosity, file, line,
		   context_name, report_enabled_checked);
}

void uvm_report_error(string id,
		      string message,
		      int verbosity = uvm_verbosity.UVM_LOW,
		      string filename = "",
		      size_t line = 0,
		      string context_name = "",
		      bool report_enabled_checked = false) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_error(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked);
}

void uvm_report_error(string file=__FILE__,
		      size_t line=__LINE__,
		      T...)(string id,
			    string message,
			    int verbosity,
			    string context_name,
			    bool report_enabled_checked,
			    T t)
if(T.length > 0 && is(T[0 ]: uvm_report_message_element_base)) {
  uvm_report_error(id, message, verbosity, file, line,
		   context_name, report_enabled_checked, t);
 }

void uvm_report_error(T...)(string id,
			    string message,
			    int verbosity,
			    string filename,
			    size_t line,
			    string context_name,
			    bool report_enabled_checked,
			    T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_error(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked, t);
 }

// Function: uvm_report_fatal
//
// These methods, defined in package scope, are convenience functions that
// delegate to the corresponding component methods in ~uvm_top~. They can be
// used in module-based code to use the same reporting mechanism as class-based
// components. See <uvm_report_object> for details on the reporting mechanism.
//
// *Note:* Verbosity is ignored for warnings, errors, and fatals to ensure users
// do not inadvertently filter them out. It remains in the methods for backward
// compatibility.

void uvm_report_fatal(string file=__FILE__,
		      size_t line=__LINE__)(string id,
					    string message,
					    int verbosity=uvm_verbosity.UVM_NONE,
					    string context_name = "",
					    bool report_enabled_checked = false) {
  uvm_report_fatal(id, message, verbosity, file, line,
		   context_name, report_enabled_checked);
}

void uvm_report_fatal(string id,
		      string message,
		      int verbosity = uvm_verbosity.UVM_NONE,
		      string filename = "",
		      size_t line = 0,
		      string context_name = "",
		      bool report_enabled_checked = false) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_fatal(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked);
}

void uvm_report_fatal(string file=__FILE__,
		      size_t line=__LINE__,
		      T...)(string id,
			    string message,
			    int verbosity,
			    string context_name,
			    bool report_enabled_checked,
			    T t)
if(T.length > 0 && is(T[0 ]: uvm_report_message_element_base)) {
  uvm_report_fatal(id, message, verbosity, file, line,
		   context_name, report_enabled_checked, t);
 }

void uvm_report_fatal(T...)(string id,
			    string message,
			    int verbosity,
			    string filename,
			    size_t line,
			    string context_name,
			    bool report_enabled_checked,
			    T t)
if(T.length > 0 && is(T[0]: uvm_report_message_element_base)) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_fatal(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked, t);
 }

// Function: uvm_process_report_message
//
// This method, defined in package scope, is a convenience function that
// delegate to the corresponding component method in ~uvm_top~. It can be
// used in module-based code to use the same reporting mechanism as class-based
// components. See <uvm_report_object> for details on the reporting mechanism.

void uvm_process_report_message(uvm_report_message report_message) {
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  // Process p = Process.self();
  top.uvm_process_report_message(report_message);
}


// TODO merge with uvm_enum_wrapper#(uvm_severity)
bool uvm_string_to_severity (string sev_str, out uvm_severity sev) {
  switch (sev_str) {
  case "UVM_INFO":    sev = UVM_INFO;    break;
  case "UVM_WARNING": sev = UVM_WARNING; break;
  case "UVM_ERROR":   sev = UVM_ERROR;   break;
  case "UVM_FATAL":   sev = UVM_FATAL;   break;
  default: return false;
  }
  return true;
}

bool uvm_string_to_action (string action_str, out uvm_action action) {
  string[] actions;
  uvm_split_string(action_str,'|',actions);
  bool retval = true;
  // action = 0; // taken care since action is of type "out"
  foreach(a; actions[]) {
    switch (a) {
    case "UVM_NO_ACTION": action |= UVM_NO_ACTION; break;
    case "UVM_DISPLAY":   action |= UVM_DISPLAY;   break;
    case "UVM_LOG":       action |= UVM_LOG;       break;
    case "UVM_COUNT":     action |= UVM_COUNT;     break;
    case "UVM_EXIT":      action |= UVM_EXIT;      break;
    case "UVM_CALL_HOOK": action |= UVM_CALL_HOOK; break;
    case "UVM_STOP":      action |= UVM_STOP;      break;
    case "UVM_RM_RECORD": action |= UVM_RM_RECORD; break;
    default: retval = false;
    }
  }
  return retval;
}

version(UVM_INCLUDE_DEPRECATED) {
  //------------------------------------------------------------------------------
  //
  // Group- Configuration
  //
  //------------------------------------------------------------------------------

  // Function- set_config_int
  //
  // This is the global version of set_config_int in <uvm_component>. This
  // function places the configuration setting for an integral field in a
  // global override table, which has highest precedence over any
  // component-level setting.  See <uvm_component::set_config_int> for
  // details on setting configuration.

  void  set_config_int(T)(string inst_name,
			  string field_name,
			  T value) {
    if (!uvm_component.m_config_deprecated_warned) {
      uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been deprecated. Use uvm_config_db instead.");
      uvm_component.m_config_deprecated_warned = true;
    }
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    auto top = cs.get_root();
    top.set_config_int(inst_name, field_name, value);
  }

  // Function- set_config_object
  //
  // This is the global version of set_config_object in <uvm_component>. This
  // function places the configuration setting for an object field in a
  // global override table, which has highest precedence over any
  // component-level setting.  See <uvm_component::set_config_object> for
  // details on setting configuration.

  import uvm.base.uvm_object;
  void set_config_object (string inst_name,
			  string field_name,
			  uvm_object value,
			  bool clone=true) {
    if (!uvm_component.m_config_deprecated_warned) {
      uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been deprecated. Use uvm_config_db instead.");
      uvm_component.m_config_deprecated_warned = true;
    }
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    auto top = cs.get_root();
    top.set_config_object(inst_name, field_name, value, clone);
  }


  // Function- set_config_string
  //
  // This is the global version of set_config_string in <uvm_component>. This
  // function places the configuration setting for an string field in a
  // global override table, which has highest precedence over any
  // component-level setting.  See <uvm_component::set_config_string> for
  // details on setting configuration.

  void set_config_string (string inst_name,
			  string field_name,
			  string value) {
    if (!uvm_component.m_config_deprecated_warned) {
      uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been deprecated. Use uvm_config_db instead.");
      uvm_component.m_config_deprecated_warned = true;
    }
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    auto top = cs.get_root();
    top.set_config_string(inst_name, field_name, value);
  }
}

//----------------------------------------------------------------------------
//
// Group: Miscellaneous
//
//----------------------------------------------------------------------------


// Function: uvm_is_match
//
// Returns 1 if the two strings match, 0 otherwise.
//
// The first string, ~expr~, is a string that may contain '*' and '?'
// characters. A * matches zero or more characters, and ? matches any single
// character. The 2nd argument, ~str~, is the string begin matched against.
// It must not contain any wildcards.
//
//----------------------------------------------------------------------------

bool uvm_is_match (string expr, string str) {
  auto s = uvm_glob_to_re(expr);
  return uvm_re_match(s, str);
}

enum UVM_LINE_WIDTH = 120;

enum UVM_NUM_LINES = 120;

// for the next two constants, the SV version definitions are one less
// That is because SV uses these two variables to identify LSB, we
// interpret these variables as defining length

enum UVM_SMALL_STRING = UVM_LINE_WIDTH*8;
enum UVM_LARGE_STRING = UVM_LINE_WIDTH*UVM_NUM_LINES*8;


//----------------------------------------------------------------------------
//
// Function: uvm_string_to_bits
//
// Converts an input string to its bit-vector equivalent. Max bit-vector
// length is approximately 14000 characters.
//----------------------------------------------------------------------------

import esdl.data.bvec;
import esdl.data.bstr;		// BitStream

bstr uvm_string_to_bits(string str) {
  bstr uvm_string_to_bits_;
  uvm_string_to_bits_.fromArray(str);
  return uvm_string_to_bits_;
}

//----------------------------------------------------------------------------
//
// Function: uvm_bits_to_string
//
// Converts an input bit-vector to its string equivalent. Max bit-vector
// length is approximately 14000 characters.
//----------------------------------------------------------------------------

string uvm_bits_to_string(bstr str) {
  char[] uvm_bits_to_string_;
  str.toArray(uvm_bits_to_string_);
  return cast(string) uvm_bits_to_string_;
}


//----------------------------------------------------------------------------
//
// Task: uvm_wait_for_nba_region
//
// Callers of this task will not return until the NBA region, thus allowing
// other processes any number of delta cycles (#0) to settle out before
// continuing. See <uvm_sequencer_base::wait_for_sequences> for example usage.
//
//----------------------------------------------------------------------------

enum size_t UVM_POUND_ZERO_COUNT=1;
void uvm_wait_for_nba_region() {
  version(UVM_NO_WAIT_FOR_NBA) {
    // repeat(UVM_POUND_ZERO_COUNT) #0;
    for (size_t i=0; i!=UVM_POUND_ZERO_COUNT; ++i) {
      wait(0);
    }
  }
  else {
    import esdl.base.core: Signal, wait;

    // These are not declared static in the SV version
    Signal!int nba;
    int next_nba;

    //If `included directly in a program block, can't use a non-blocking assign,
    //but it isn't needed since program blocks are in a separate region.
    next_nba++;
    nba = next_nba;
    wait(nba);
  }
}


//----------------------------------------------------------------------------
//
// Function: uvm_split_string
//
// Returns a queue of strings, ~values~, that is the result of the ~str~ split
// based on the ~sep~.  For example:
//
//| uvm_split_string("1,on,false", ",", splits);
//
// Results in the 'splits' queue containing the three elements: 1, on and
// false.
//----------------------------------------------------------------------------

void uvm_split_string (string str, char sep, out string[] values) {
  int s = 0;
  int e = 0;
  // values.length = 0; // this is taken care of since values is "out"
  while(e < str.length) {
    for(s = e; e < str.length; ++e) {
      if(str[e] == sep) {
	break;
      }
    }
    if(s !is e) {
      values ~= str[s..e];
    }
    e++;
  }
}

string[] uvm_split_string (string str, char sep) {
  string[] values;
  int s = 0;
  int e = 0;
  // values.length = 0; // this is taken care of since values is "out"
  while(e < str.length) {
    for(s = e; e < str.length; ++e) {
      if(str[e] is sep) {
	break;
      }
    }
    if(s !is e) {
      values ~= str[s..e];
    }
    e++;
  }
  return values;
}

// From dpi/uvm_regex.cc in SV

enum char uvm_re_bracket_char = '/';

bool uvm_re_match(in string re, in string str) {
  import std.regex;
  Regex!char rx;
  if (re.length > 1 && re[0] is uvm_re_bracket_char &&
      re[$-1] is uvm_re_bracket_char) {
    rx = regex(re[1..$-1]);
  }
  else {
    rx = regex(re);
  }
  if(match(str, rx)) {
    return true;
  }
  else {
    return false;
  }
}

//--------------------------------------------------------------------
// uvm_glob_to_re
//
// Convert a glob expression to a normal regular expression.
//--------------------------------------------------------------------

string uvm_glob_to_re(string glob) {
  string retval;
  // safety check.  Glob should never be null since this is called
  // from DPI.  But we'll check anyway.
  if(glob is null) return null;

  // SV puts this condition since there we use DPI and we have a hard
  // limit to the string size

  // if (len > 2040) {
  //   vpi_printf((PLI_BYTE8*)  "UVM_ERROR: uvm_glob_to_re : glob expression greater than max 2040: |%s|\n",glob);
  //   return glob;
  // }

  // If either of the following cases appear then return an empty string
  //
  //  1.  The glob string is empty (it has zero characters)
  //  2.  The glob string has a single character that is the
  //      uvm_re_bracket_char  (i.e. "/")
  if(glob.length is 0 || (glob.length is 1 && glob[0] is uvm_re_bracket_char)) {
    return retval;  // return an empty string
  }

  // If bracketed with the /glob/, then it's already a regex
  if(glob[0] is uvm_re_bracket_char && glob[$-1] is uvm_re_bracket_char) {
    // take out the uvm_re_bracket_char and return
    return glob;
  }
  else {
    // Convert the glob to a true regular expression (Posix syntax)

    retval ~= uvm_re_bracket_char;

    // ^ goes at the beginning...
    if (glob[0] !is '^') retval ~= '^';

    foreach(p; glob) {
      // Replace the glob metacharacters with corresponding regular
      // expression metacharacters.
      switch(p) {
      case '?':
	retval ~= '.';      break;
      case '*', '+':
	retval ~= "." ~ p;  break;
      case '.', '[', ']', '(', ')':
	retval ~= "\\" ~ p; break;
      default:
	retval ~= p;        break;
      }
    }
  }

  // Let's check to see if the regular expression is bounded by ^ at
  // the beginning and $ at the end.  If not, add those characters in
  // the appropriate position.

  if (retval[$-1] !is '$') {
    retval ~= '$';
  }

  retval ~= uvm_re_bracket_char;

  return retval;
}


// Class: uvm_enum_wrapper#(T)
//
// The ~uvm_enum_wrapper#(T)~ class is a utility mechanism provided
// as a convenience to the end user.  It provides a <from_name>
// method which is the logical inverse of the System Verilog ~name~
// method which is built into all enumerations.

// No synchronized blocks required since all data is thread local
// all functions are static
struct uvm_enum_wrapper(T) if (is(T == enum))
  {

    alias this_type = uvm_enum_wrapper!T;

    private static T[string] _map;

    // Function: from_name
    // Attempts to convert a string ~name~ to an enumerated value.
    //
    // If the conversion is successful, the method will return
    // 1, otherwise 0.
    //
    // Note that the ~name~ passed in to the method must exactly
    // match the value which would be produced by ~enum::name~, and
    // is case sensitive.
    //
    // For example:
    //| typedef uvm_enum_wrapper#(uvm_radix_enum) radix_wrapper;
    //| uvm_radix_enum r_v;
    //|
    //| // The following would return '0', as "foo" isn't a value
    //| // in uvm_radix_enum:
    //| radix_wrapper::from_name("foo", r_v);
    //|
    //| // The following would return '0', as "uvm_bin" isn't a value
    //| // in uvm_radix_enum (although the upper case "UVM_BIN" is):
    //| radix_wrapper::from_name("uvm_bin", r_v);
    //|
    //| // The following would return '1', and r_v would be set to
    //| // the value of UVM_BIN
    //| radix_wrapper::from_name("UVM_BIN", r_v);
    //
    static bool from_name(string name, ref T value) {
      if(_map.length == 0) {
	m_init_map();
      }
      if(name in _map) {
	value = _map[name];
	return true;
      }

      else {
	return false;
      }
    }

    @disable this();

    // Function- m_init_map
    // Initializes the name map, only needs to be performed once
    private static void m_init_map() {
      foreach(e; EnumMembers!T) {
	_map[e.to!string] = e;
      }
    }
  }
