//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
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

public void run_test (string test_name = "") {
  auto top = uvm_root.get();
  top.run_test(test_name);
}

version (UVM_NO_DEPRECATED) { }
// `ifndef UVM_NO_DEPRECATED
 else {
   import uvm.base.uvm_objection;
   import esdl.base.time;
   // Variable- uvm_test_done - DEPRECATED
   //
   // An instance of the <uvm_test_done_objection> class, this object is
   // used by components to coordinate when to end the currently running
   // task-based phase. When all participating components have dropped their
   // raised objections, an implicit call to <global_stop_request> is issued
   // to end the run phase (or any other task-based phase).

   public uvm_test_done_objection uvm_test_done() {
     return uvm_test_done_objection.get();
   }


   // Method- global_stop_request  - DEPRECATED
   //
   // Convenience function for uvm_test_done.stop_request(). See
   // <uvm_test_done_objection::stop_request> for more information.

   public void global_stop_request() {
     uvm_test_done_objection tdo = uvm_test_done_objection.get();
     tdo.stop_request();
   }


   // Method- set_global_timeout  - DEPRECATED
   //
   // Convenience function for uvm_top.set_timeout(). See
   // <uvm_root::set_timeout> for more information.  The overridable bit
   // controls whether subsequent settings will be honored.


   public void set_global_timeout(Time timeout, bool overridable = true) {
     uvm_root top = uvm_root.get();
     top.set_timeout(timeout, overridable);
   }

   public void set_global_timeout(SimTime timeout, bool overridable = true) {
     uvm_root top = uvm_root.get();
     top.set_timeout(timeout, overridable);
   }


   // Function- set_global_stop_timeout - DEPRECATED
   //
   // Convenience function for uvm_test_done.stop_timeout = timeout.
   // See <uvm_uvm_test_done::stop_timeout> for more information.

   public void set_global_stop_timeout(Time timeout) {
     uvm_test_done_objection tdo = uvm_test_done_objection.get();
     tdo.stop_timeout = SimTime(getRootEntity, timeout);
   }

   public void set_global_stop_timeout(SimTime timeout) {
     uvm_test_done_objection tdo = uvm_test_done_objection.get();
     tdo.stop_timeout = timeout;
   }

 }

//----------------------------------------------------------------------------
//
// Group: Reporting
//
//----------------------------------------------------------------------------

// Function: uvm_report_enabled
//
// Returns 1 if the configured verbosity in ~uvm_top~ is greater than
// ~verbosity~ and the action associated with the given ~severity~ and ~id~
// is not UVM_NO_ACTION, else returns 0.
//
// See also <uvm_report_object::uvm_report_enabled>.
//
//
// Static methods of an extension of uvm_report_object, e.g. uvm_compoent-based
// objects, can not call ~uvm_report_enabled~ because the call will resolve to
// the <uvm_report_object::uvm_report_enabled>, which is non-static.
// Static methods can not call non-static methods of the same class.

import uvm.base.uvm_object_globals;

public bool uvm_report_enabled (int verbosity,
				uvm_severity severity = UVM_INFO,
				string id = "") {
  auto top = uvm_root.get();
  return top.uvm_report_enabled(verbosity, severity, id);
}

// Function: uvm_report

public void uvm_report( uvm_severity_type severity,
			string id,
			string message,
			int verbosity = int.min,
			string filename = "",
			int line = 0) {
  if(verbosity is int.min) {
    verbosity = (severity is UVM_ERROR) ? UVM_LOW :
      (severity is UVM_FATAL) ? UVM_NONE : UVM_MEDIUM;
  }

  uvm_root top = uvm_root.get();
  top.uvm_report(severity, id, message, verbosity, filename, line);
}

// Function: uvm_report_info

public void uvm_report_info(string id,
			    string message,
			    int verbosity = UVM_MEDIUM,
			    string filename = "",
			    int line = 0) {
  auto top = uvm_root.get();
  top.uvm_report_info(id, message, verbosity, filename, line);
}

// Function: uvm_report_warning

public void uvm_report_warning(string id,
			       string message,
			       int verbosity = UVM_MEDIUM,
			       string filename = "",
			       int line = 0) {
  auto top = uvm_root.get();
  top.uvm_report_warning(id, message, verbosity, filename, line);
}

// Function: uvm_report_error

public void uvm_report_error(string id,
			     string message,
			     int verbosity = UVM_LOW,
			     string filename = "",
			     int line = 0) {
  auto top = uvm_root.get();
  top.uvm_report_error(id, message, verbosity, filename, line);
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

public void uvm_report_fatal(string id,
			     string message,
			     int verbosity = UVM_NONE,
			     string filename = "",
			     int line = 0) {
  auto top = uvm_root.get();
  top.uvm_report_fatal(id, message, verbosity, filename, line);
}

public bool uvm_string_to_severity (string sev_str, out uvm_severity sev) {
  switch (sev_str) {
  case "UVM_INFO":    sev = UVM_INFO;    break;
  case "UVM_WARNING": sev = UVM_WARNING; break;
  case "UVM_ERROR":   sev = UVM_ERROR;   break;
  case "UVM_FATAL":   sev = UVM_FATAL;   break;
  default: return false;
  }
  return true;
}

public bool uvm_string_to_action (string action_str, out uvm_action action) {
  string actions[];
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
    default: retval = false;
    }
  }
  return retval;
}

//------------------------------------------------------------------------------
//
// Group: Configuration
//
//------------------------------------------------------------------------------

// Function: set_config_int
//
// This is the global version of set_config_int in <uvm_component>. This
// function places the configuration setting for an integral field in a
// global override table, which has highest precedence over any
// component-level setting.  See <uvm_component::set_config_int> for
// details on setting configuration.

public void  set_config_int(T)(string inst_name,
			       string field_name,
			       T value) {
  auto top = uvm_root.get();
  top.set_config_int(inst_name, field_name, value);
}

// Function: set_config_object
//
// This is the global version of set_config_object in <uvm_component>. This
// function places the configuration setting for an object field in a
// global override table, which has highest precedence over any
// component-level setting.  See <uvm_component::set_config_object> for
// details on setting configuration.

import uvm.base.uvm_object;
public void set_config_object (string inst_name,
			       string field_name,
			       uvm_object value,
			       bool clone=true) {
  auto top = uvm_root.get();
  top.set_config_object(inst_name, field_name, value, clone);
}


// Function: set_config_string
//
// This is the global version of set_config_string in <uvm_component>. This
// function places the configuration setting for an string field in a
// global override table, which has highest precedence over any
// component-level setting.  See <uvm_component::set_config_string> for
// details on setting configuration.

public void set_config_string (string inst_name,
			       string field_name,
			       string value) {
  auto top = uvm_root.get();
  top.set_config_string(inst_name, field_name, value);
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

public bool uvm_is_match (string expr, string str) {
  auto s = uvm_glob_to_re(expr);
  return (uvm_re_match(s, str) is 0);
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

public bstr uvm_string_to_bits(string str) {
  bstr retval;
  retval.fromArray(str);
  return retval;
}

//----------------------------------------------------------------------------
//
// Function: uvm_bits_to_string
//
// Converts an input bit-vector to its string equivalent. Max bit-vector
// length is approximately 14000 characters.
//----------------------------------------------------------------------------

public string uvm_bits_to_string(bstr str) {
  char[] retval;
  str.toArray(retval);
  return cast(string) retval;
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
public void uvm_wait_for_nba_region() {
  version(UVM_NO_WAIT_FOR_NBA) {
    // repeat(UVM_POUND_ZERO_COUNT) #0;
    for (size_t i=0; i!=UVM_POUND_ZERO_COUNT; ++i)
      {
	wait(0);
      }
  }
  else {
    import esdl.base.core: Signal, wait;

    // These are not declared static in the SV version
    static Signal!int nba;
    static int next_nba;

    //If `included directly in a program block, can't use a non-blocking assign,
    //but it isn't needed since program blocks are in a seperate region.
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

public void uvm_split_string (string str, char sep, out string[] values) {
  int s = 0;
  int e = 0;
  // values.length = 0; // this is taken care of since values is "out"
  while(e < str.length) {
    for(s=e; e<str.length; ++e) if(str[e] is sep) break;
    if(s !is e) values ~= str[s..e];
    e++;
  }
}

public string[] uvm_split_string (string str, char sep) {
  string[] values;
  int s = 0;
  int e = 0;
  // values.length = 0; // this is taken care of since values is "out"
  while(e < str.length) {
    for(s=e; e<str.length; ++e) if(str[e] is sep) break;
    if(s !is e) values ~= str[s..e];
    e++;
  }
  return values;
}

// From dpi/uvm_regex.cc in SV

enum char uvm_re_bracket_char = '/';

public int uvm_re_match(in string re, in string str) {
  import std.regex;
  Regex!char rx;
  if (re.length > 1 && re[0] is uvm_re_bracket_char &&
      re[$-1] is uvm_re_bracket_char) {
    rx = regex(re[1..$-1]);
  }
  else {
    rx = regex(re);
  }
  if(match(str, rx)) return 0;
  else return -1;
}

//--------------------------------------------------------------------
// uvm_glob_to_re
//
// Convert a glob expression to a normal regular expression.
//--------------------------------------------------------------------

public string uvm_glob_to_re(in string glob) {
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
    retval = cast(string) glob.dup;
    return retval;
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

  if (retval[$-1] !is '$')
    retval ~= '$';

  retval ~= uvm_re_bracket_char;

  return retval;
}
