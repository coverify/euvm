//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
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


module uvm.base.uvm_report_handler;

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_handler
//
// The uvm_report_handler is the class to which most methods in
// <uvm_report_object> delegate. It stores the maximum verbosity, actions,
// and files that affect the way reports are handled.
//
// The report handler is not intended for direct use. See <uvm_report_object>
// for information on the UVM reporting mechanism.
//
// The relationship between <uvm_report_object> (a base class for uvm_component)
// and uvm_report_handler is typically one to one, but it can be many to one
// if several uvm_report_objects are configured to use the same
// uvm_report_handler_object. See <uvm_report_object::set_report_handler>.
//
// The relationship between uvm_report_handler and <uvm_report_server> is many
// to one.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_pool;
import uvm.base.uvm_object_globals;

alias uvm_pool!(string, uvm_action) uvm_id_actions_array;
alias uvm_pool!(string, UVM_FILE) uvm_id_file_array;
alias uvm_pool!(string, int) uvm_id_verbosities_array;
alias uvm_pool!(uvm_severity_type, uvm_severity_type) uvm_sev_override_array;

import uvm.base.uvm_report_server;
import uvm.base.uvm_report_object;
import uvm.base.uvm_cmdline_processor;
import uvm.base.uvm_version;
import uvm.meta.misc;
import uvm.base.uvm_root: uvm_top;

class uvm_once_report_handler
{
  @uvm_private_sync private bool _m_relnotes_done;
}

class uvm_report_handler
{
  import std.string: format;

  mixin(uvm_once_sync!(uvm_once_report_handler));
  mixin(uvm_sync!uvm_report_handler);

  @uvm_public_sync private int _m_max_verbosity_level;

  // internal variables

  private uvm_action[uvm_severity] _severity_actions;

  private uvm_id_actions_array _id_actions;
  private uvm_id_actions_array[uvm_severity] _severity_id_actions;

  // id verbosity settings : default and severity
  private uvm_id_verbosities_array _id_verbosities;
  private uvm_id_verbosities_array[uvm_severity] _severity_id_verbosities;

  // severity overrides
  private uvm_sev_override_array _sev_overrides;
  private uvm_sev_override_array[string] _sev_id_overrides;


  // file handles : default, severity, action, (severity,id)
  private UVM_FILE _default_file_handle;
  private UVM_FILE[uvm_severity] _severity_file_handles;
  private uvm_id_file_array _id_file_handles;
  private uvm_id_file_array[uvm_severity] _severity_id_file_handles;


  // Function: new
  //
  // Creates and initializes a new uvm_report_handler object.

  public this() {
    synchronized(this) {
      _id_file_handles = new uvm_id_file_array();
      _id_actions = new uvm_id_actions_array();
      _id_verbosities = new uvm_id_verbosities_array();
      _sev_overrides = new uvm_sev_override_array();
      initialize;
    }
  }


  // Function- get_server
  //
  // Internal method called by <uvm_report_object::get_report_server>.

  static public uvm_report_server get_server() {
    return uvm_report_server.get_server();
  }


  // Function- set_max_quit_count
  //
  // Internal method called by <uvm_report_object::set_report_max_quit_count>.

  static public void set_max_quit_count(int max_count) {
    uvm_report_server srvr = uvm_report_server.get_server();
    srvr.set_max_quit_count(max_count);
  }


  // Function- summarize
  //
  // Internal method called by <uvm_report_object::report_summarize>.

  static public void summarize(UVM_FILE file = 0) {
    uvm_report_server srvr = uvm_report_server.get_server();
    srvr.summarize(file);
  }

  // Function- report_relnotes_banner
  //
  // Internal method called by <uvm_report_object::report_header>.

  static public void report_relnotes_banner(UVM_FILE file = 0) {
    if (m_relnotes_done) return;
    uvm_report_server srvr = uvm_report_server.get_server();
    srvr.f_display(file,
		   "\n  ***********       IMPORTANT RELEASE NOTES"
		   "         ************");
    m_relnotes_done = true;
  }


  // Function- report_header
  //
  // Internal method called by <uvm_report_object::report_header>

  static public void report_header(UVM_FILE file = 0) {
    uvm_report_server srvr = uvm_report_server.get_server();
    srvr.f_display(file,
		   "--------------------------------"
		   "--------------------------------");
    srvr.f_display(file, uvm_revision_string());
    srvr.f_display(file, uvm_mgc_copyright);
    srvr.f_display(file, uvm_cdn_copyright);
    srvr.f_display(file, uvm_snps_copyright);
    srvr.f_display(file, uvm_cy_copyright);
    srvr.f_display(file, uvm_co_copyright);
    srvr.f_display(file,
		   "--------------------------------"
		   "--------------------------------");
    string[] args;

    uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();

    if (clp.get_arg_matches(`\+UVM_NO_RELNOTES`, args)) return;

    version(UVM_NO_DEPRECATED) {
      report_relnotes_banner(file);
      srvr.f_display(file, "\n  You are using a version of the UVM library"
		     " that has been compiled");
      srvr.f_display(file, "  with `UVM_NO_DEPRECATED undefined.");
      srvr.f_display(file, "  See http://www.eda.org/svdb/view.php?id=3313"
		     " for more details.");
    }

    // `ifndef UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
    version(UVM_OBJECT_MUST_HAVE_CONSTRUCTOR) {
      report_relnotes_banner(file);
      srvr.f_display(file, "\n  You are using a version of the UVM library"
		     " that has been compiled");
      srvr.f_display(file, "  with `UVM_OBJECT_MUST_HAVE_CONSTRUCTOR undefined.");
      srvr.f_display(file, "  See http://www.eda.org/svdb/view.php?id=3770"
		     " for more details.");
    }
    // `endif

    if (m_relnotes_done) {
      srvr.f_display(file, "\n      (Specify +UVM_NO_RELNOTES to turn off"
		     " this notice)\n");
    }
  }


  // Function- initialize
  //
  // This method is called by the constructor to initialize the arrays and
  // other variables described above to their default values.

  final public void initialize() {
    synchronized(this) {
      set_default_file(0);
      _m_max_verbosity_level = UVM_MEDIUM;
      set_defaults();
    }
  }


  // Function: run_hooks
  //
  // The run_hooks method is called if the <UVM_CALL_HOOK> action is set for a
  // report. It first calls the client's <uvm_report_object::report_hook> method,
  // followed by the appropriate severity-specific hook method. If either
  // returns 0, then the report is not processed.

  public bool run_hooks(uvm_report_object client,
			uvm_severity severity,
			string id,
			string message,
			int verbosity,
			string filename,
			size_t line) {
    synchronized(this) {
      bool ok = client.report_hook(id, message, verbosity, filename, line);

      final switch(severity) {
      case UVM_INFO:
	ok &= client.report_info_hook(id, message, verbosity,
				      filename, line);
	break;
      case UVM_WARNING:
	ok &= client.report_warning_hook(id, message, verbosity,
					 filename, line);
	break;
      case UVM_ERROR:
	ok &= client.report_error_hook(id, message, verbosity,
				       filename, line);
	break;
      case UVM_FATAL:
	ok &= client.report_fatal_hook(id, message, verbosity,
				       filename, line);
	break;
      }
      return ok;
    }
  }


  // Function- get_severity_id_file
  //
  // Return the file id based on the severity and the id

  final private UVM_FILE get_severity_id_file(uvm_severity severity, string id) {
    synchronized(this) {
      uvm_id_file_array array;

      if(severity in _severity_id_file_handles) {
	array = _severity_id_file_handles[severity];
	if(array.exists(id))
	  return array.get(id);
      }


      if(_id_file_handles.exists(id))
	return _id_file_handles.get(id);

      if(severity in _severity_file_handles)
	return _severity_file_handles[severity];

      return _default_file_handle;
    }
  }


  // Function- set_verbosity_level
  //
  // Internal method called by uvm_report_object.

  final public void set_verbosity_level(int verbosity_level) {
    synchronized(this) {
      _m_max_verbosity_level = verbosity_level;
    }
  }

  // Function: get_verbosity_level
  //
  // Returns the verbosity associated with the given ~severity~ and ~id~.
  //
  // First, if there is a verbosity associated with the ~(severity,id)~ pair,
  // return that.  Else, if there is an verbosity associated with the ~id~, return
  // that.  Else, return the max verbosity setting.

  final public int get_verbosity_level(uvm_severity severity=UVM_INFO,
				       string id="" ) {
    synchronized(this) {
      uvm_id_verbosities_array array;
      if(severity in _severity_id_verbosities) {
	array = _severity_id_verbosities[severity];
	if(id in array) {
	  return array.get(id);
	}
      }

      if(id in _id_verbosities) {
	return _id_verbosities.get(id);
      }

      return _m_max_verbosity_level;

    }
  }


  // Function: get_action
  //
  // Returns the action associated with the given ~severity~ and ~id~.
  //
  // First, if there is an action associated with the ~(severity,id)~ pair,
  // return that.  Else, if there is an action associated with the ~id~, return
  // that.  Else, if there is an action associated with the ~severity~, return
  // that. Else, return the default action associated with the ~severity~.

  final public uvm_action get_action(uvm_severity severity, string id) {
    synchronized(this) {
      uvm_id_actions_array array;
      if(severity in _severity_id_actions) {
	array = _severity_id_actions[severity];
	if(array.exists(id))
	  return array.get(id);
      }

      if(_id_actions.exists(id))
	return _id_actions.get(id);

      return _severity_actions[severity];

    }
  }


  // Function: get_file_handle
  //
  // Returns the file descriptor associated with the given ~severity~ and ~id~.
  //
  // First, if there is a file handle associated with the ~(severity,id)~ pair,
  // return that. Else, if there is a file handle associated with the ~id~, return
  // that. Else, if there is an file handle associated with the ~severity~, return
  // that. Else, return the default file handle.

  final public UVM_FILE get_file_handle(uvm_severity severity, string id) {
    synchronized(this) {
      UVM_FILE file;

      file = get_severity_id_file(severity, id);
      if (file !is 0) return file;
      if (_id_file_handles.exists(id)) {
	file = _id_file_handles.get(id);
	if (file !is 0) return file;
      }
      if (severity in _severity_file_handles) {
	file = _severity_file_handles[severity];
	if(file !is 0) return file;
      }

      return _default_file_handle;
    }
  }

  // Function: report
  //
  // This is the common handler method used by the four core reporting methods
  // (e.g., uvm_report_error) in <uvm_report_object>.

  public void report(uvm_severity_type severity,
		     string name,
		     string id,
		     string message,
		     int verbosity_level = UVM_MEDIUM,
		     string filename = "",
		     size_t line = 0,
		     uvm_report_object client = null
		     ) {
    synchronized(this) {
      import uvm.base.uvm_root;
      uvm_report_server srvr;
      srvr = uvm_report_server.get_server();

      if (client is null) client = uvm_root.get();

      // Check for severity overrides and apply them before calling the server.
      // An id specific override has precedence over a generic severity override.
      if(id in _sev_id_overrides) {
	if(_sev_id_overrides[id].exists(severity)) {
	  severity = _sev_id_overrides[id].get(severity);
	}
      }
      else {
	if(_sev_overrides.exists(severity)) {
	  severity = _sev_overrides.get(severity);
	}
      }

      srvr.report(severity,name,id,message,verbosity_level,filename,line,client);
    }
  }


  // Function: format_action
  //
  // Returns a string representation of the ~action~, e.g., "DISPLAY".

  static public string format_action(uvm_action action) {
    string s;

    if(action is UVM_NO_ACTION) {
      s = "NO ACTION";
    }
    else {
      s = "";
      if(action & UVM_DISPLAY)   s ~= "DISPLAY ";
      if(action & UVM_LOG)       s ~= "LOG ";
      if(action & UVM_COUNT)     s ~= "COUNT ";
      if(action & UVM_EXIT)      s ~= "EXIT ";
      if(action & UVM_CALL_HOOK) s ~= "CALL_HOOK ";
      if(action & UVM_STOP)      s ~= "STOP ";
    }

    return s;
  }


  // Function- set_default
  //
  // Internal method for initializing report handler.

  final public void set_defaults() {
    synchronized(this) {
      set_severity_action(UVM_INFO,    UVM_DISPLAY);
      set_severity_action(UVM_WARNING, UVM_DISPLAY);
      set_severity_action(UVM_ERROR,   UVM_DISPLAY | UVM_COUNT);
      set_severity_action(UVM_FATAL,   UVM_DISPLAY | UVM_EXIT);

      set_severity_file(UVM_INFO, _default_file_handle);
      set_severity_file(UVM_WARNING, _default_file_handle);
      set_severity_file(UVM_ERROR,   _default_file_handle);
      set_severity_file(UVM_FATAL,   _default_file_handle);
    }
  }

  // Function- set_severity_action
  // Function- set_id_action
  // Function- set_severity_id_action
  // Function- set_id_verbosity
  // Function- set_severity_id_verbosity
  //
  // Internal methods called by uvm_report_object.

  final public void set_severity_action(in uvm_severity severity,
					in uvm_action action) {
    synchronized(this) {
      _severity_actions[severity] = action;
    }
  }

  final public void set_id_action(in string id, in uvm_action action) {
    synchronized(this) {
      _id_actions.add(id, action);
    }
  }

  final public void set_severity_id_action(uvm_severity severity,
					   string id,
					   uvm_action action) {
    synchronized(this) {
      if(severity !in _severity_id_actions)
	_severity_id_actions[severity] = new uvm_id_actions_array();
      _severity_id_actions[severity].add(id,action);
    }
  }

  final public void set_id_verbosity(in string id, in int verbosity) {
    synchronized(this) {
      _id_verbosities.add(id, verbosity);
    }
  }

  final public void set_severity_id_verbosity(uvm_severity severity,
					      string id,
					      int verbosity) {
    synchronized(this) {
      if(severity !in _severity_id_verbosities)
	_severity_id_verbosities[severity] = new uvm_id_verbosities_array;
      _severity_id_verbosities[severity].add(id,verbosity);
    }
  }

  // Function- set_default_file
  // Function- set_severity_file
  // Function- set_id_file
  // Function- set_severity_id_file
  //
  // Internal methods called by uvm_report_object.

  final public void set_default_file (UVM_FILE file) {
    synchronized(this) {
      _default_file_handle = file;
    }
  }

  final public void set_severity_file (uvm_severity severity, UVM_FILE file) {
    synchronized(this) {
      _severity_file_handles[severity] = file;
    }
  }

  final public void set_id_file (string id, UVM_FILE file) {
    synchronized(this) {
      _id_file_handles.add(id, file);
    }
  }

  final public void set_severity_id_file(uvm_severity severity,
					 string id, UVM_FILE file) {
    synchronized(this) {
      if(severity !in _severity_id_file_handles)
	_severity_id_file_handles[severity] = new uvm_id_file_array;
      _severity_id_file_handles[severity].add(id, file);
    }
  }

  final public void set_severity_override(uvm_severity_type cur_severity,
					  uvm_severity_type new_severity) {
    synchronized(this) {
      _sev_overrides.add(cur_severity, new_severity);
    }
  }

  final public void set_severity_id_override(uvm_severity_type cur_severity,
					     string id,
					     uvm_severity_type new_severity) {
    synchronized(this) {
      // has precedence over set_severity_override
      // silently override previous setting
      uvm_sev_override_array arr;
      if(id !in _sev_id_overrides)
	_sev_id_overrides[id] = new uvm_sev_override_array;
      _sev_id_overrides[id].add(cur_severity, new_severity);
    }
  }


  // Function- dump_state
  //
  // Internal method for debug.

  final public void dump_state() {
    synchronized(this) {
      string s;
      uvm_action a;
      string idx;
      UVM_FILE file;
      uvm_report_server srvr;

      uvm_id_actions_array id_a_ary;
      uvm_id_verbosities_array id_v_ary;
      uvm_id_file_array id_f_ary;

      srvr = uvm_report_server.get_server();

      srvr.f_display(0,
		     "-----------------------------------"
		     "-----------------------------------");
      srvr.f_display(0, "report handler state dump");
      srvr.f_display(0, "");

      // verbosities

      srvr.f_display(0, "");
      srvr.f_display(0, "+-----------------+");
      srvr.f_display(0, "|   Verbosities   |");
      srvr.f_display(0, "+-----------------+");
      srvr.f_display(0, "");

      s = format("max verbosity level = %d", _m_max_verbosity_level);
      srvr.f_display(0, s);

      srvr.f_display(0, "*** verbosities by id");


      foreach(key, val; _id_verbosities) {
	uvm_verbosity v = cast(uvm_verbosity) val;
	s = format("[%s] --> %s", key, v);
	srvr.f_display(0, s);
      }

      // verbosities by id

      srvr.f_display(0, "");
      srvr.f_display(0, "*** verbosities by id and severity");

      foreach(severity, id; _severity_id_verbosities) {
	uvm_severity_type sev = cast(uvm_severity_type) severity;
	id_v_ary = _severity_id_verbosities[severity];
	foreach(key, val; id_v_ary) {
	  uvm_verbosity v = cast(uvm_verbosity) val;
	  s = format("%s:%s --> %s",
		     sev, idx, v);
	  srvr.f_display(0, s);
	}
      }

      // actions

      srvr.f_display(0, "");
      srvr.f_display(0, "+-------------+");
      srvr.f_display(0, "|   actions   |");
      srvr.f_display(0, "+-------------+");
      srvr.f_display(0, "");

      srvr.f_display(0, "*** actions by severity");
      foreach(severity, action; _severity_actions) {
	uvm_severity_type sev = cast(uvm_severity_type) severity;
	s = format("%s = %s",
		   sev, format_action(action));
	srvr.f_display(0, s);
      }

      srvr.f_display(0, "");
      srvr.f_display(0, "*** actions by id");

      foreach(key, val; _id_actions) {
	s = format("[%s] --> %s", key, format_action(val));
	srvr.f_display(0, s);
      }

      // actions by id

      srvr.f_display(0, "");
      srvr.f_display(0, "*** actions by id and severity");

      foreach(severity, action; _severity_id_actions) {
	uvm_severity_type sev = cast(uvm_severity_type) severity;
	id_a_ary = action;
	foreach(key, val; id_a_ary) {
	  s = format("%s:%s --> %s",
		     sev, key, format_action(val));
	  srvr.f_display(0, s);
	}
      }

      // Files

      srvr.f_display(0, "");
      srvr.f_display(0, "+-------------+");
      srvr.f_display(0, "|    files    |");
      srvr.f_display(0, "+-------------+");
      srvr.f_display(0, "");

      s = format("default file handle = %d", _default_file_handle);
      srvr.f_display(0, s);

      srvr.f_display(0, "");
      srvr.f_display(0, "*** files by severity");
      foreach(severity, handle; _severity_file_handles) {
	uvm_severity_type sev = cast(uvm_severity_type) severity;
	file = handle;
	s = format("%s = %d", sev, file);
	srvr.f_display(0, s);
      }

      srvr.f_display(0, "");
      srvr.f_display(0, "*** files by id");

      foreach(key, val;_id_file_handles) {
	s = format("id %s --> %d", key, val);
	srvr.f_display(0, s);
      }

      srvr.f_display(0, "");
      srvr.f_display(0, "*** files by id and severity");

      foreach(severity, handle;  _severity_id_file_handles ) {
	uvm_severity_type sev = cast(uvm_severity_type) severity;
	id_f_ary = handle;
	foreach(key, val; id_f_ary) {
	  s = format("%s:%s --> %d", sev, key, val);
	  srvr.f_display(0, s);
	}
      }
      srvr.dump_server_state();
      srvr.f_display(0,
		     "-----------------------------------"
		     "-----------------------------------");
    }
  }
}
