//
//------------------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2010-2012 AMD
// Copyright 2012 Accellera Systems Initiative
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2011 Cypress Semiconductor Corp.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2010-2014 Synopsys, Inc.
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


import uvm.base.uvm_pool: uvm_pool;
import uvm.base.uvm_object_globals: uvm_action, UVM_FILE,
  uvm_severity, uvm_verbosity, uvm_action_type, uvm_radix_enum;

import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_report_message: uvm_report_message;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_globals: uvm_report_enabled;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_version;
import uvm.base.uvm_scope;

import uvm.meta.misc;

import esdl.base.core: Process;

import std.string: format;
import std.conv: to;

// version (UVM_NO_DEPRECATED) { }
//  else {
//    version = UVM_INCLUDE_DEPRECATED;
//  }

alias uvm_id_actions_array = uvm_pool!(string, uvm_action);
alias uvm_id_file_array = uvm_pool!(string, UVM_FILE);
alias uvm_id_verbosities_array = uvm_pool!(string, int);
alias uvm_sev_override_array = uvm_pool!(uvm_severity, uvm_severity);

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_report_handler
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

// @uvm-ieee 1800.2-2020 auto 6.4.1
class uvm_report_handler: uvm_object
{

  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private bool _m_relnotes_done;
  }

  mixin (uvm_scope_sync_string);
  mixin (uvm_sync_string);

  // internal variables

  @uvm_public_sync
  private int _m_max_verbosity_level;

  // id verbosity settings : default and severity
  private uvm_id_verbosities_array _id_verbosities;
  private uvm_id_verbosities_array[uvm_severity] _severity_id_verbosities;


  // actions
  private uvm_id_actions_array _id_actions;
  private uvm_action[uvm_severity] _severity_actions;
  private uvm_id_actions_array[uvm_severity] _severity_id_actions;

  // severity overrides
  private uvm_sev_override_array _sev_overrides;
  private uvm_sev_override_array[string] _sev_id_overrides;


  // file handles : default, severity, action, (severity,id)
  private UVM_FILE _default_file_handle;
  private uvm_id_file_array _id_file_handles;
  private UVM_FILE[uvm_severity] _severity_file_handles;
  private uvm_id_file_array[uvm_severity] _severity_id_file_handles;

  mixin uvm_object_essentials;

  // Function -- NODOCS -- new
  //
  // Creates and initializes a new uvm_report_handler object.

  // @uvm-ieee 1800.2-2020 auto 6.4.2.1
  this(string name = "uvm_report_handler") {
    synchronized (this) {
      super(name);
      initialize;
    }
  }


  // Function -- NODOCS -- print
  //
  // The uvm_report_handler implements the <uvm_object::do_print()> such that
  // ~print~ method provides UVM printer formatted output
  // of the current configuration.  A snippet of example output is shown here:
  //
  // |uvm_test_top                uvm_report_handler  -     @555                    
  // |  max_verbosity_level       uvm_verbosity       32    uvm_verbosity.UVM_FULL                
  // |  id_verbosities            uvm_pool            3     -                       
  // |    [ID1]                   uvm_verbosity       32    uvm_verbosity.UVM_LOW                 
  // |  severity_id_verbosities   array               4     -                       
  // |    [UVM_INFO:ID4]          int                 32    501                     
  // |  id_actions                uvm_pool            2     -                       
  // |    [ACT_ID]                uvm_action          32    DISPLAY LOG COUNT       
  // |  severity_actions          array               4     -                       
  // |    [UVM_INFO]              uvm_action          32    DISPLAY                 
  // |    [UVM_WARNING]           uvm_action          32    DISPLAY RM_RECORD COUNT 
  // |    [UVM_ERROR]             uvm_action          32    DISPLAY COUNT           
  // |    [UVM_FATAL]             uvm_action          32    DISPLAY EXIT            
  // |  default_file_handle       int                 32    'h1                     

  // @uvm-ieee 1800.2-2020 auto 6.4.2.2
  override void do_print (uvm_printer printer) {
    synchronized (this) {
      // max verb
      uvm_verbosity l_verbosity = cast (uvm_verbosity) _m_max_verbosity_level;
    
      // if ($cast(l_verbosity, m_max_verbosity_level))
      printer.print_generic("max_verbosity_level", "uvm_verbosity", 32, 
			    l_verbosity.to!string);
      // else
      //   printer.print_field("max_verbosity_level", m_max_verbosity_level, 32, UVM_DEC,
      // 		      '.', "int");

      // id verbs
      if (_id_verbosities.num() != 0) {
	printer.print_array_header("id_verbosities", _id_verbosities.num(),
				   "uvm_pool");
	foreach (idx, l_int; _id_verbosities) {
	  l_verbosity = cast (uvm_verbosity) l_int;
	  // if ($cast(l_verbosity, l_int))
	  printer.print_generic(format("[%s]", idx), "uvm_verbosity", 32, 
				l_verbosity.to!string());
	  // else {
	  //   string l_str;
	  //   l_str.itoa(l_int);
	  //   printer.print_generic($sformatf("[%s]", idx), "int", 32, l_str);
	  // }
	}
	printer.print_array_footer();
      }

      // sev and id verbs
      if (_severity_id_verbosities.length != 0) {
	int _total_cnt;
	foreach (l_severity, id_v_ary; _severity_id_verbosities) {
	  _total_cnt += id_v_ary.num();
	}
	printer.print_array_header("severity_id_verbosities", _total_cnt,
				   "array");
	foreach (l_severity, id_v_ary; _severity_id_verbosities) {
	  foreach (idx, l_int; id_v_ary) {
	    l_verbosity = cast (uvm_verbosity) l_int;
	    // if ($cast(l_verbosity, l_int))
	    printer.print_generic(format("[%s:%s]", l_severity.to!string(), idx), 
				  "uvm_verbosity", 32, l_verbosity.to!string());
	    // else {
	    //   string l_str;
	    //   l_str.itoa(l_int);
	    //   printer.print_generic($sformatf("[%s:%s]", l_severity.to!string(), idx), 
	    // 			  "int", 32, l_str);
	    // }
	  } //  while (id_v_ary.next(idx));
	} // while (severity_id_verbosities.next(l_severity));
	printer.print_array_footer();
      }

      // id actions
      if (_id_actions.num() != 0) {
	printer.print_array_header("id_actions", _id_actions.num(),
				   "uvm_pool");
	foreach (idx, l_int; _id_actions) {
	  printer.print_generic(format("[%s]", idx), "uvm_action", 32, 
				format_action(l_int));
	}
	printer.print_array_footer();
      }

      // severity actions
      
      if (_severity_actions.length != 0) {
	printer.print_array_header("severity_actions", 4, "array");
	foreach (l_severity, l_action; _severity_actions) {
	  printer.print_generic(format("[%s]", l_severity.to!string()),
				"uvm_action", 32, 
				format_action(l_action));
	}
	printer.print_array_footer();
      }

      // sev and id actions 
      if (_severity_id_actions.length != 0) {
	int _total_cnt;
	foreach (l_severity, id_a_ary; _severity_id_actions) {
	  _total_cnt += id_a_ary.num();
	}
	printer.print_array_header("severity_id_actions", _total_cnt,
				   "array");
	foreach (l_severity, id_a_ary; _severity_id_actions) {
	  foreach (idx, l_action;id_a_ary) {
	    printer.print_generic(format("[%s:%s]", l_severity.to!string(), idx), 
				  "uvm_action", 32, format_action(l_action));
	  }
	}
	printer.print_array_footer();
      }

      // sev overrides
      if (_sev_overrides.num() != 0) {
	printer.print_array_header("sev_overrides", _sev_overrides.num(),
				   "uvm_pool");
	foreach (l_severity, l_severity_new; _sev_overrides) {
	  printer.print_generic(format("[%s]", l_severity.to!string()),
				"uvm_severity", 32, l_severity_new.to!string());
	}
	printer.print_array_footer();
      }

      // sev and id overrides
      if (_sev_id_overrides.length != 0) {
	int _total_cnt;
	foreach (idx, sev_o_ary; _sev_id_overrides) {
	  _total_cnt += sev_o_ary.num();
	}
	printer.print_array_header("sev_id_overrides", _total_cnt,
				   "array");
	foreach (idx, sev_o_ary; _sev_id_overrides) {
	  foreach (l_severity, new_sev; sev_o_ary) {
	    printer.print_generic(format("[%s:%s]",
					 l_severity.to!string(), idx), 
				  "uvm_severity", 32, new_sev.to!string());
	  }
	}
	printer.print_array_footer();
      }

      // default file handle
      printer.print("default_file_handle", _default_file_handle, uvm_radix_enum.UVM_HEX,
		    '.', "int");

      // id files 
      if (_id_file_handles.num() != 0) {
	printer.print_array_header("id_file_handles", _id_file_handles.num(),
				   "uvm_pool");
	foreach (idx, handle; _id_file_handles) {
	  printer.print(format("[%s]", idx), handle, uvm_radix_enum.UVM_HEX, '.', "UVM_FILE");
	}
	printer.print_array_footer();
      }

      // severity files
      if (_severity_file_handles.length != 0) {
	printer.print_array_header("severity_file_handles", 4, "array");
	foreach (l_severity, handle; _severity_file_handles) {
	  printer.print(format("[%s]", l_severity.to!string()), 
			handle, uvm_radix_enum.UVM_HEX, '.', "UVM_FILE");
	}
	printer.print_array_footer();
      }

      // sev and id files
      if (_severity_id_file_handles.length != 0) {
	int _total_cnt;
	foreach (l_severity, id_f_ary; _severity_id_file_handles) {
	  _total_cnt += id_f_ary.num();
	}
	printer.print_array_header("severity_id_file_handles", _total_cnt,
				   "array");

	foreach (l_severity, id_f_ary; _severity_id_file_handles) {
	  foreach (idx, handle; id_f_ary) {
	    printer.print(format("[%s:%s]", l_severity.to!string(), idx),
			  handle, uvm_radix_enum.UVM_HEX, '.', "UVM_FILE");
	  }
	}
	printer.print_array_footer();
      }

    }
  }

  
  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Message Processing
  //----------------------------------------------------------------------------


  // Function -- NODOCS -- process_report_message
  //
  // This is the common handler method used by the four core reporting methods
  // (e.g. <uvm_report_error>) in <uvm_report_object>.

  // @uvm-ieee 1800.2-2020 auto 6.4.7
  void process_report_message(uvm_report_message report_message) {
    import uvm.base.uvm_report_server;
    synchronized (this) {
      uvm_report_server srvr = uvm_report_server.get_server();
      string id = report_message.get_id();
      uvm_severity severity = report_message.get_severity();

      // Check for severity overrides and apply them before calling the server.
      // An id specific override has precedence over a generic severity override.
      if (id in _sev_id_overrides) {
	if (severity in _sev_id_overrides[id]) {
	  severity = _sev_id_overrides[id].get(severity);
	  report_message.set_severity(severity);
	}
      }
      else {
	if (severity in _sev_overrides) {
	  severity = _sev_overrides.get(severity);
	  report_message.set_severity(severity);
	}
      }

      report_message.set_file(get_file_handle(severity, id));
      report_message.set_report_handler(this);
      report_message.set_action(get_action(severity, id));
      srvr.process_report_message(report_message);
    }
  }

  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Convenience Methods
  //----------------------------------------------------------------------------

  // Function -- NODOCS -- format_action
  //
  // Returns a string representation of the ~action~, e.g., "DISPLAY".

  static string format_action(uvm_action action) {
    string s;

    if (action is uvm_action_type.UVM_NO_ACTION) {
      s = "NO ACTION";
    }
    else {
      s = "";
      if (action & uvm_action_type.UVM_DISPLAY)   s ~= "DISPLAY ";
      if (action & uvm_action_type.UVM_LOG)       s ~= "LOG ";
      if (action & uvm_action_type.UVM_RM_RECORD) s ~= "RM_RECORD ";
      if (action & uvm_action_type.UVM_COUNT)     s ~= "COUNT ";
      if (action & uvm_action_type.UVM_EXIT)      s ~= "EXIT ";
      if (action & uvm_action_type.UVM_CALL_HOOK) s ~= "CALL_HOOK ";
      if (action & uvm_action_type.UVM_STOP)      s ~= "STOP ";
    }

    return s;
  }

  // Function- initialize
  //
  // This method is called by the constructor to initialize the arrays and
  // other variables described above to their default values.

  final void initialize() {
    synchronized (this) {
      set_default_file(0);
      _m_max_verbosity_level = uvm_verbosity.UVM_MEDIUM;

      _id_file_handles = new uvm_id_file_array();
      _id_actions = new uvm_id_actions_array();
      _id_verbosities = new uvm_id_verbosities_array();
      _sev_overrides = new uvm_sev_override_array();

      set_severity_action(uvm_severity.UVM_TRACE,   uvm_action_type.UVM_DISPLAY);
      set_severity_action(uvm_severity.UVM_INFO,    uvm_action_type.UVM_DISPLAY);
      set_severity_action(uvm_severity.UVM_WARNING, uvm_action_type.UVM_DISPLAY);
      set_severity_action(uvm_severity.UVM_ERROR,   uvm_action_type.UVM_DISPLAY | uvm_action_type.UVM_COUNT);
      set_severity_action(uvm_severity.UVM_FATAL,   uvm_action_type.UVM_DISPLAY | uvm_action_type.UVM_EXIT);

      set_severity_file(uvm_severity.UVM_TRACE,   _default_file_handle);
      set_severity_file(uvm_severity.UVM_INFO,    _default_file_handle);
      set_severity_file(uvm_severity.UVM_WARNING, _default_file_handle);
      set_severity_file(uvm_severity.UVM_ERROR,   _default_file_handle);
      set_severity_file(uvm_severity.UVM_FATAL,   _default_file_handle);
    }
  }

  // Function- get_severity_id_file
  //
  // Return the file id based on the severity and the id

  final private UVM_FILE get_severity_id_file(uvm_severity severity, string id) {
    synchronized (this) {
      uvm_id_file_array array;

      if (severity in _severity_id_file_handles) {
	array = _severity_id_file_handles[severity];
	if (array.exists(id))
	  return array.get(id);
      }


      if (_id_file_handles.exists(id)) {
	return _id_file_handles.get(id);
      }

      if (severity in _severity_file_handles) {
	return _severity_file_handles[severity];
      }

      return _default_file_handle;
    }
  }


  // Function- set_verbosity_level
  //
  // Internal method called by uvm_report_object.

  // @uvm-ieee 1800.2-2020 auto 6.4.3.2
  final void set_verbosity_level(int verbosity_level) {
    synchronized (this) {
      _m_max_verbosity_level = verbosity_level;
    }
  }

  // Function- get_verbosity_level
  //
  // Returns the verbosity associated with the given ~severity~ and ~id~.
  //
  // First, if there is a verbosity associated with the ~(severity,id)~ pair,
  // return that.  Else, if there is a verbosity associated with the ~id~, return
  // that.  Else, return the max verbosity setting.

  // @uvm-ieee 1800.2-2020 auto 6.4.3.1
  final int get_verbosity_level(uvm_severity severity=uvm_severity.UVM_INFO,
				string id="" ) {
    synchronized (this) {
      uvm_id_verbosities_array array;
      if (severity in _severity_id_verbosities) {
	array = _severity_id_verbosities[severity];
	if (id in array) {
	  return array.get(id);
	}
      }

      if (id in _id_verbosities) {
	return _id_verbosities.get(id);
      }

      return _m_max_verbosity_level;

    }
  }


  // Function- get_action
  //
  // Returns the action associated with the given ~severity~ and ~id~.
  //
  // First, if there is an action associated with the ~(severity,id)~ pair,
  // return that.  Else, if there is an action associated with the ~id~, return
  // that.  Else, if there is an action associated with the ~severity~, return
  // that. Else, return the default action associated with the ~severity~.

  // @uvm-ieee 1800.2-2020 auto 6.4.4.1
  final uvm_action get_action(uvm_severity severity, string id) {
    synchronized (this) {
      uvm_id_actions_array array;
      if (severity in _severity_id_actions) {
	array = _severity_id_actions[severity];
	if (array.exists(id))
	  return array.get(id);
      }

      if (_id_actions.exists(id))
	return _id_actions.get(id);

      return _severity_actions[severity];

    }
  }


  // Function- get_file_handle
  //
  // Returns the file descriptor associated with the given ~severity~ and ~id~.
  //
  // First, if there is a file handle associated with the ~(severity,id)~ pair,
  // return that. Else, if there is a file handle associated with the ~id~, return
  // that. Else, if there is an file handle associated with the ~severity~, return
  // that. Else, return the default file handle.

  // @uvm-ieee 1800.2-2020 auto 6.4.5.1
  final UVM_FILE get_file_handle(uvm_severity severity, string id) {
    synchronized (this) {
      UVM_FILE file;

      file = get_severity_id_file(severity, id);
      if (file !is 0) {
	return file;
      }
      if (_id_file_handles.exists(id)) {
	file = _id_file_handles.get(id);
	if (file !is 0) {
	  return file;
	}
      }
      if (severity in _severity_file_handles) {
	file = _severity_file_handles[severity];
	if (file !is 0) {
	  return file;
	}
      }

      return _default_file_handle;
    }
  }

  // Function- set_severity_action
  // Function- set_id_action
  // Function- set_severity_id_action
  // Function- set_id_verbosity
  // Function- set_severity_id_verbosity
  //
  // Internal methods called by uvm_report_object.

  // @uvm-ieee 1800.2-2020 auto 6.4.4.2
  final void set_severity_action(in uvm_severity severity,
				 in uvm_action action) {
    synchronized (this) {
      _severity_actions[severity] = action;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.4.2
  final void set_id_action(in string id, in uvm_action action) {
    synchronized (this) {
      _id_actions.add(id, action);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.4.2
  final void set_severity_id_action(uvm_severity severity,
				    string id,
				    uvm_action action) {
    synchronized (this) {
      if (severity !in _severity_id_actions)
	_severity_id_actions[severity] = new uvm_id_actions_array();
      _severity_id_actions[severity].add(id,action);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.3.3
  final void set_id_verbosity(in string id, in int verbosity) {
    synchronized (this) {
      _id_verbosities.add(id, verbosity);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.3.3
  final void set_severity_id_verbosity(uvm_severity severity,
				       string id,
				       int verbosity) {
    synchronized (this) {
      if (severity !in _severity_id_verbosities)
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

  // @uvm-ieee 1800.2-2020 auto 6.4.5.2
  final void set_default_file (UVM_FILE file) {
    synchronized (this) {
      _default_file_handle = file;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.5.2
  final void set_severity_file (uvm_severity severity, UVM_FILE file) {
    synchronized (this) {
      _severity_file_handles[severity] = file;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.5.2
  final void set_id_file (string id, UVM_FILE file) {
    synchronized (this) {
      _id_file_handles.add(id, file);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.5.2
  final void set_severity_id_file(uvm_severity severity,
				  string id, UVM_FILE file) {
    synchronized (this) {
      if (severity !in _severity_id_file_handles)
	_severity_id_file_handles[severity] = new uvm_id_file_array;
      _severity_id_file_handles[severity].add(id, file);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.6
  final void set_severity_override(uvm_severity cur_severity,
				   uvm_severity new_severity) {
    synchronized (this) {
      _sev_overrides.add(cur_severity, new_severity);
    }
  }

  // @uvm-ieee 1800.2-2020 auto 6.4.6
  final void set_severity_id_override(uvm_severity cur_severity,
				      string id,
				      uvm_severity new_severity) {
    synchronized (this) {
      // has precedence over set_severity_override
      // silently override previous setting
      uvm_sev_override_array arr;
      if (id !in _sev_id_overrides)
	_sev_id_overrides[id] = new uvm_sev_override_array;
      _sev_id_overrides[id].add(cur_severity, new_severity);
    }
  }


  // Function- report
  //
  // This is the common handler method used by the four core reporting methods
  // (e.g., uvm_report_error) in <uvm_report_object>.

  void report(uvm_severity severity,
	      string name,
	      string id,
	      lazy string message,
	      int verbosity_level=uvm_verbosity.UVM_MEDIUM,
	      string filename = "",
	      size_t line = 0,
	      uvm_report_object client = null
	      ) {
    import uvm.base.uvm_coreservice;
    synchronized (this) {
      bool l_report_enabled = false;
      uvm_report_message l_report_message;
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      if (! uvm_report_enabled(verbosity_level, uvm_severity.UVM_INFO, id)) {
	return;
      }

      if (client is null) {
	client = cs.get_root();
      }

      l_report_message = uvm_report_message.new_report_message();
      l_report_message.set_report_message(severity, id, message(), 
					  verbosity_level, filename, line, name);
      l_report_message.set_report_object(client);
      l_report_message.set_action(get_action(severity,id));
      process_report_message(l_report_message);
    }
  }

}
