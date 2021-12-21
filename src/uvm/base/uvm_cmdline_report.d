//
//------------------------------------------------------------------------------
// Copyright 2021 Coverify Systems Technology
// Copyright 2007-2009 Cadence Design Systems, Inc.
// Copyright 2007-2009 Mentor Graphics Corporation
// Copyright 2020 NVIDIA Corporation
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

module uvm.base.uvm_cmdline_report;

import std.format: formattedRead, format;
import std.algorithm: sort;
import std.array: join;

import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_cmdline_processor: uvm_cmdline_processor;
import uvm.base.uvm_scope;

import uvm.meta.meta;
import uvm.meta.misc;

import esdl.base.core;
import esdl.base.cmdl;


// Command line classes
class uvm_cmdline_setting_base
{
  mixin (uvm_sync_string);

  @uvm_public_sync {
    private string _arg; // Original command line option
    private bool[uvm_component] _used; // Usage tracking
  }
}

class uvm_cmdline_verbosity: uvm_cmdline_setting_base
{

  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    private uvm_cmdline_verbosity[] _settings;
  }

  // Instance Methods/Variables
  @uvm_public_sync
  private int _verbosity;
  
  enum source_e: ubyte {STANDARD, NON_STANDARD, ILLEGAL};

  @uvm_public_sync
  private source_e _src;
  
  // Static Methods/Variables
  // static const string prefix = "+UVM_VERBOSITY=";
  enum string prefix = "+UVM_VERBOSITY=";

  // static uvm_cmdline_verbosity settings[$];
  

  // Function --NODOCS-- init
  // Initializes the ~settings~ queue with the command line verbosity settings.
  //
  // Warnings for incorrectly formatted command line arguments are routed through
  // the report object ~ro~.  If ~ro~ is null, then no warnings shall be generated.

  // euvm -- can not name a function init
  static void initialize(uvm_report_object ro) {
    string[]  setting_str;
    int       verbosity;
    int       verb_count;
    string    verb_string;
    bool      skip;
    uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();

    version(UVM_CMDLINE_NO_DPI) {
      // Retrieve the verbosities provided on the command line
      verb_count = clp.get_arg_values(prefix, setting_str);
    }
    else {
      CommandLine cmdline = new CommandLine();
      verb_count = cmdline.plusArgs("UVM_VERBOSITY=%s", verb_string);
      if (verb_count)
	setting_str ~= verb_string;
    }

    foreach (sstr; setting_str) {
      uvm_cmdline_verbosity setting = new uvm_cmdline_verbosity();
      uvm_verbosity temp_verb;

      synchronized (setting) {
	setting._arg = sstr;
	setting._src = source_e.STANDARD;
      
	if (!uvm_string_to_verbosity(sstr, temp_verb)) {
	  int code = sstr.formattedRead("%d", setting._verbosity);
	  if (code > 0) {
	    uvm_info_context("NSTVERB", 
			     format("Non-standard verbosity value '%s', converted to '%0d'.",
				    sstr, verbosity),
			     uvm_verbosity.UVM_NONE,
			     ro);
	    setting.src = source_e.NON_STANDARD;
	  }
	  else {
	    setting._verbosity = uvm_verbosity.UVM_MEDIUM;
	    setting._src = source_e.ILLEGAL;
	  }
	} // if (!uvm_string_to_verbosity(sstr, verbosity))
	else {
	  setting._verbosity = temp_verb;
	}
	synchronized (_uvm_scope_inst) {
	  _uvm_scope_inst._settings ~= setting;
	}
      }
    }
  }

  // Function --NODOCS-- check
  // Checks the settings queue for unused verbosity settings.
  //
  // Verbosity could be unused because it wasn't first on the command line.
  static void check(uvm_report_object ro) {
    string[] verb_q;
    
    foreach (i, setting; settings) {
      if (setting.src == source_e.ILLEGAL) {
	uvm_warning_context("ILLVERB",
			    format("Illegal verbosity value '%s', converted to default of UVM_MEDIUM.",
				   setting.arg),
			    ro);
      }
      if (i != 0) verb_q ~= ", ";
      verb_q ~= setting.arg;
    } // foreach (setting)
    
    if (settings.length > 1) {
      uvm_warning_context("MULTVERB",
			  format("Multiple (%0d) +UVM_VERBOSITY arguments provided " ~
				 "on the command line.  '%s' will be used.  Provided list: %s.", 
				 settings.length, settings[0].arg, verb_q.join()),
			  ro);
    } // if (settings.length > 1)
  }

  // Function --NODOCS-- dump
  // Dumps the usage information for the verbosity settings as a string.
  //
  static string dump() {
    string[] msgs;
    int      tmp_verb;

    foreach (i, setting; settings) {
      msgs ~= format("\n%s%s: ", prefix, setting.arg);
      if (i == 0)
        msgs ~= "Applied";
      else
        msgs ~= "Not applied (not first on command line)";
      if (setting.src == source_e.NON_STANDARD)
        msgs ~= format(", converted as non-standard to '%0d'", setting.verbosity); 
      else if (setting.src == source_e.ILLEGAL)
        msgs ~= ", converted as ILLEGAL to UVM_MEDIUM";
    } // foreach (setting)

    return msgs.join();
  }

}


class uvm_cmdline_set_verbosity: uvm_cmdline_setting_base
{
  import std.conv: to;

  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    private uvm_cmdline_set_verbosity[] _settings;
  }

  // Instance Methods/Variables
  @uvm_public_sync {
    private string    _comp;
    private string    _id;
    private int       _verbosity;
    private string    _phase;
    private SimTime   _offset;
  }


  // Static Methods/Variables
  enum string prefix = "+uvm_set_verbosity="; 
  // static uvm_cmdline_set_verbosity settings[$]; // Processed command line settings

  
  // Function --NODOCS-- init
  // Initializes the ~settings~ queue with the command line verbosity settings.
  //
  // Warnings for incorrectly formatted command line arguments are routed through
  // the report object ~ro~.  If ~ro~ is null, then no warnings shall be generated.

  // euvm -- can not name a function init
  static void initialize(uvm_report_object ro) {
    string[]  setting_str;
    uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();

    if (clp.get_arg_values(prefix, setting_str) > 0) {
      uvm_verbosity temp_verb;
      string[]  args;
      string  message;
      
      foreach (sstr; setting_str) {
        bool skip = false;
        uvm_string_split(sstr, ',', args);
        if (args.length < 4 || args.length > 5) {
          message = "Invalid number of arguments found, expected 4 or 5";
          skip = true;
        }
        if (args.length == 5 && args[3] != "time") {
          message = "Too many arguments found for <phase>, expected only 4";
          skip = true;
        }
        if (args.length == 4 && args[3] == "time") {
          message = "Too few arguments found for <time>, expected 5";
          skip = true;
        }
        if (!uvm_string_to_verbosity(args[2], temp_verb)) {
          message = "Invalid verbosity found";
          skip = true;
        }
        
        if (!skip) {
          uvm_cmdline_set_verbosity setting =
	    new uvm_cmdline_set_verbosity();

	  synchronized (setting) {
	    setting.arg = sstr;
	    setting.comp = args[0];
	    setting.id = args[1];
	    setting.verbosity = temp_verb;
	    setting.phase = args[3];
	    if (setting.phase == "time")
	      setting.offset = SimTime(args[4].to!int());
	    else
	      setting.offset = SimTime(0);

	    synchronized (_uvm_scope_inst) {
	      _uvm_scope_inst._settings ~= setting;
	    }
	  }
        } // if (!skip)

        else if (ro !is null) {
          uvm_warning_context("INVLCMDARGS",
			      format("%s, setting '%s%s' will be ignored.",
				     message, prefix, sstr),
			      ro);
        }
      } // foreach (setting_string[i])
    } // if (clp.get_arg_values(prefix, setting_string) > 0)
  }

  // Function --NODOCS-- check
  // Checks the settings queue for unused verbosity settings.
  //
  // Verbosity could be unused because:
  //   a) It didn't match any components
  //   b) The ~offset~ specified hasn't occurred yet
  //   c) The ~phase~ specified hasn't occurred yet
  static void check(uvm_report_object ro) {
    foreach (setting; settings) {
      if (setting.used.length == 0) {
        // Warn if we didn't match any components
        uvm_warning_context("INVLCMDARGS",
			    format("\"%s%s\" never took effect due to either a mismatching component pattern.",
				   prefix, setting.arg),
			    ro);
      }
      else {
        if (setting.phase == "time") {
          if (getSimTime() < setting.offset) {
            // Warn if we haven't hit the time yet
            uvm_warning_context("INVLCMDARGS",
				format("\"%s%s\" never took effect due to test ending before offset was reached.",
				       prefix, setting.arg),
				ro);
          }
        }
        else {
          bool hit;
          foreach (comp, used; setting.used) {
            if (used) {
              hit = true;
              break;
            }
	  } // foreach (setting.used[i])
          
          if (!hit) {
            // Warn if all our matching components never saw ~phase~
            uvm_warning_context("INVLCMDARGS",
				format("\"%s%s\" never took effect due to phase never occurring for matching component(s).",
				       prefix, setting.arg),
				ro);
          }
        } // else: !if(setting.phase == "time")
      } // else: !if(setting.used.length == 0)
    } // foreach (setting)
  }
  
  // Function --NODOCS-- dump
  // Dumps the usage information for the verbosity settings as a string.
  //
  static string dump() {
    string[] msgs;
    uvm_component[] sorted_list;
    foreach (setting; settings) {
      msgs ~= format("\n%s%s", prefix, setting.arg);
      msgs ~= "\n  matching components:";
      if (setting.used.length == 0)
        msgs ~= "\n    <none>";
      else {
        sorted_list.length = 0;
        foreach (comp, used; setting.used)
          sorted_list ~= comp;
        sorted_list.sort!((uvm_component a, uvm_component b)
			  {return a.get_full_name() < b.get_full_name();})();
        foreach (comp; sorted_list) {
          string full_name = comp.get_full_name();
          if (full_name == "")
            full_name = "<uvm_root>";
          msgs ~= "\n    ";
          msgs ~= full_name;
          msgs ~= ": ";
          if ((setting.phase == "time" && setting.used[comp]) ||
              (setting.phase != "time" && setting.used[comp]))
            msgs ~= "Applied";
          else {
            msgs ~= "Not applied ";
            if (setting.phase == "time")
              msgs ~= "(component never reached offset)";
            else
              msgs ~= "(component never saw phase)";
          }
        } // foreach (setting.used[j])
      } // else: !if(setting.used.length == 0)
    } // foreach (settings[i])

    return msgs.join();
  }
}

class uvm_cmdline_set_action: uvm_cmdline_setting_base
{
  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    private uvm_cmdline_set_action[] _settings;
  }


  // Instance Methods/Variables
  @uvm_public_sync {
    private string    _comp;
    private string    _id;
    private bool      _all_sev;
    private uvm_severity _sev;
    private uvm_action _action;
  }


  // Static Methods/Variables
  enum string prefix="+uvm_set_action=";

  // static uvm_cmdline_set_action settings[$]; // Processed command line settings
  
  // Function --NODOCS-- init
  // Initializes the ~settings~ queue with the command line action settings.
  //
  // Warnings for incorrectly formatted command line arguments are routed through
  // the report object ~ro~.  If ~ro~ is null, then no warnings shall be generated.

  // euvm -- can not name a function init
  static void initialize(uvm_report_object ro) {
    string[]  setting_str;
    uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
    
    if (clp.get_arg_values(prefix, setting_str) > 0) {
      uvm_action action;
      uvm_severity sev;
      string[]  args;
      string  message;

      foreach (sstr; setting_str) {
	bool skip = false;
        uvm_string_split(sstr, ',', args);
        if (args.length != 4) {
          message = "Invalid number of arguments found, expected 4";
          skip = true;
        }
        if (args[2] != "_ALL_" && !uvm_string_to_severity(args[2], sev)) {
          message = format("Bad severity argument '%s'", args[2]);
          skip = true;
        }
        if (!uvm_string_to_action(args[3], action)) {
          message = format("Bad action argument '%s'", args[3]);
          skip = true;
        }

        if (!skip) {
          uvm_cmdline_set_action setting = new uvm_cmdline_set_action();
	  synchronized (setting) {
	    setting.arg = sstr;
	    setting.comp = args[0];
	    setting.id = args[1];
	    setting.all_sev = (args[2] == "_ALL_");
	    setting.sev = sev;
	    setting.action = action;

	    synchronized (_uvm_scope_inst) {
	      _uvm_scope_inst._settings ~= setting;
	    }
	  }
	} // if (!skip)
        else if (ro !is null) {
          uvm_warning_context("INVLCMDARGS", 
			      format("%s, setting '%s%s' will be ignored.",
				     message, prefix, sstr),
			      ro);
        }
      } // foreach (sstr)
    } // if (clp.get_arg_values(prefix, setting_str) > 0)
    
  }

  // Function --NODOCS-- check
  // Checks the settings queue for unused action settings.
  //
  // Verbosity could be unused because:
  //   a) It didn't match any components
  static void check(uvm_report_object ro) {
    foreach (setting; settings) {
      if (setting.used.length == 0) {
	uvm_warning_context("INVLCMDARGS",
			    format("\"%s%s\" never took effect due to a mismatching component pattern",
				   prefix, setting.arg),
			    ro);
      }
    }
  }
  
  // Function --NODOCS-- dump
  // Dumps the usage information for the verbosity settings as a string.
  //
  static string dump() {
    string[] msgs;
    uvm_component[] sorted_list;

    foreach (setting; settings) {
      msgs ~= format("\n%s%s", prefix, setting.arg);
      msgs ~= "\n  matching components:";
      if (setting.used.length == 0)
        msgs ~= "\n    <none>";
      else {
        sorted_list.length = 0;
        foreach (comp, used; setting.used) {
          sorted_list ~= comp;
	  sorted_list.sort!((uvm_component a, uvm_component b)
			    {return a.get_full_name() < b.get_full_name();})();
	}
	foreach (comp; sorted_list) {
	  string full_name = comp.get_full_name();
	  if (full_name == "")
	    full_name = "<uvm_root>";
	  msgs ~= "\n    ";
	  msgs ~= full_name;
	  msgs ~= ": Applied";
	} // foreach (setting.used[j])
      } // else: !if(setting.used.length == 0)
    } // foreach (settings[i])

    return msgs.join();
  }

}
  
class uvm_cmdline_set_severity: uvm_cmdline_setting_base
{
  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    private uvm_cmdline_set_severity[] _settings;
  }


  // Instance Methods/Variables
  @uvm_public_sync {
    private string    _comp;
    private string    _id;
    private bool      _all_sev;
    private uvm_severity _orig_sev;
    private uvm_severity _sev;
  }

  // Static Methods/Variables
  enum string prefix="+uvm_set_severity=";
  // static uvm_cmdline_set_severity settings[$]; // Processed command line settings
  
  // Function --NODOCS-- init
  // Initializes the ~settings~ queue with the command line severity settings.
  //
  // Warnings for incorrectly formatted command line arguments are routed through
  // the report object ~ro~.  If ~ro~ is null, then no warnings shall be generated.

  // euvm -- can not name a function init
  static void initialize(uvm_report_object ro) {
    string[] setting_str;
    uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
    
    if (clp.get_arg_values(prefix, setting_str) > 0) {
      uvm_severity orig_sev, sev;
      string[]  args;
      string  message;

      foreach (sstr; setting_str) {
	bool skip = false;
        uvm_string_split(sstr, ',', args);
        if (args.length != 4) {
          message = "Invalid number of arguments found, expected 4";
          skip = true;
        }
        if (args[2] != "_ALL_" && !uvm_string_to_severity(args[2], orig_sev)) {
          message = format("Bad severity argument '%s'", args[2]);
          skip = true;
        }
        if (!uvm_string_to_severity(args[3], sev)) {
          message = format("Bad severity argument '%s'", args[3]);
          skip = true;
        }

        if (!skip) {
          uvm_cmdline_set_severity setting = new uvm_cmdline_set_severity();
	  synchronized (setting) {
	    setting.arg = sstr;
	    setting.comp = args[0];
	    setting.id = args[1];
	    setting.all_sev = (args[2] == "_ALL_");
	    setting.orig_sev = orig_sev;
	    setting.sev = sev;
	    synchronized (_uvm_scope_inst) {
	      _uvm_scope_inst._settings ~= setting;
	    }
	  }
        } // if (!skip)
        else if (ro !is null) {
          uvm_warning_context("INVLCMDARGS", 
			      format("%s, setting '%s%s' will be ignored.",
				     message, prefix, sstr),
			      ro);
        }
      } // foreach (sstr)
    } // if (clp.get_arg_values(prefix, setting_str) > 0)
  }

    
  // Function --NODOCS-- check
  // Checks the settings queue for unused action settings.
  //
  // Verbosity could be unused because:
  //   a) It didn't match any components
  static void check(uvm_report_object ro) {
    foreach (setting; settings) {
      if (setting.used.length == 0) {
        uvm_warning_context("INVLCMDARGS",
			    format("\"%s%s\" never took effect due to a mismatching component pattern",
				   prefix, setting.arg),
			    ro);
      }
    }
  }
  
  // Function --NODOCS-- dump
  // Dumps the usage information for the verbosity settings as a string.
  //
  static string dump() {
    string[] msgs;
    uvm_component[] sorted_list;
    foreach (setting; settings) {
      msgs ~= format("\n%s%s", prefix, setting.arg);
      msgs ~= "\n  matching components:";
      if (setting.used.length == 0)
        msgs ~= "\n    <none>";
      else {
        sorted_list.length = 0;
        foreach (comp, used; setting.used)
          sorted_list ~= comp;
	  sorted_list.sort!((uvm_component a, uvm_component b)
			    {return a.get_full_name() < b.get_full_name();})();
	  foreach (comp; sorted_list) {
	    string full_name = comp.get_full_name();
	    if (full_name == "")
	      full_name = "<uvm_root>";
	    msgs ~= "\n    ";
	    msgs ~= full_name;
	    msgs ~= ": Applied";
	  } // foreach (setting.used[j])
      } // else: !if(setting.used.length == 0)
    } // foreach (setting)

    return msgs.join();
  }

}
