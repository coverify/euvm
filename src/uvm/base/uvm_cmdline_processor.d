//
//------------------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2010-2018 AMD
// Copyright 2015 Analog Devices, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2010-2018 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
// Copyright 2011 Synopsys, Inc.
// Copyright 2020 Verific
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

module uvm.base.uvm_cmdline_processor;

// struct uvm_cmd_line_verb
// {
//   string comp_path;
//   string id;
//   uvm_verbosity verb;
//   int exec_time;
// }

import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.base.uvm_globals: uvm_is_match;

import uvm.base.uvm_scope;

import uvm.meta.misc;

import std.regex; // : Regex, regex, match
import std.string: toUpper;

// TITLE: Command Line Debug
//
// Debug command line plusargs that are available in the Accellera reference implementation
// but not documented in the IEEE UVM 1800.2-2020 LRM
//

// Variable: +UVM_DUMP_CMDLINE_ARGS
//
// ~+UVM_DUMP_CMDLINE_ARGS~ allows the user to dump all command line arguments to the
// reporting mechanism.  The output in is tree format.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


// Variable: +UVM_PHASE_TRACE
//
// ~+UVM_PHASE_TRACE~ turns on tracing of phase executions.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

// Variable: +UVM_OBJECTION_TRACE
//
// ~+UVM_OBJECTION_TRACE~ turns on tracing of objection activity.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

// Variable: +UVM_RESOURCE_DB_TRACE
//
// ~+UVM_RESOURCE_DB_TRACE~ turns on tracing of resource DB accesses.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

// Variable: +UVM_CONFIG_DB_TRACE
//
// ~+UVM_CONFIG_DB_TRACE~ turns on tracing of configuration DB accesses.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


// Class -- NODOCS -- uvm_cmdline_processor
//
// This class provides an interface to the command line arguments that
// were provided for the given simulation.  The class is intended to be
// used as a singleton, but that isn't required.  The generation of the
// data structures which hold the command line argument information
// happens during construction of the class object.  A global variable
// called ~uvm_cmdline_proc~ is created at initialization time and may
// be used to access command line information.
//
// The uvm_cmdline_processor class also provides support for setting various UVM
// variables from the command line such as components' verbosities and configuration
// settings for integral types and strings.  Each of these capabilities is described
// in the Built-in UVM Aware Command Line Arguments section.
//

// @uvm-ieee 1800.2-2020 auto G.1.1
final class uvm_cmdline_processor: uvm_report_object
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    private uvm_cmdline_processor _m_inst;

    this() {
      synchronized (this) {
	_m_inst = new uvm_cmdline_processor("uvm_cmdline_proc");
      }
    }
  };

  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  // Group -- NODOCS -- Singleton

  // Function -- NODOCS -- get_inst
  //
  // Returns the singleton instance of the UVM command line processor.

  // @uvm-ieee 1800.2-2020 auto G.1.2
  static uvm_cmdline_processor get_inst() {
    return m_inst;
  }

  // There are no tasks associated with uvm_cmdline_processor
  // As a result there is no need to take take of synchronization as
  // long as the state variables are private/protected and all the
  // methods defined in the class are synchronized
  // Ofcource any derived class shall make sure that all the functions
  // are synchronized

  // next three elements are declared as protected in SV version
  immutable private string[] _m_argv;
  string[] m_argv() {
    return _m_argv.dup;
  }
  
  immutable private string[] _m_plus_argv;
  string[] m_plus_argv() {
    return _m_plus_argv.dup;
  }
  
  immutable private string[] _m_uvm_argv;
  string[] m_uvm_argv() {
    return _m_uvm_argv.dup;
  }

  // Group -- NODOCS -- Basic Arguments

  // Function -- NODOCS -- get_args
  //
  // This function returns a queue with all of the command line
  // arguments that were used to start the simulation. Note that
  // element 0 of the array will always be the name of the
  // executable which started the simulation.

  // @uvm-ieee 1800.2-2020 auto G.1.3.1
  final void get_args (out string[] args) {
    args ~= _m_argv;
  }

  final string[] get_args () {
    return _m_argv.dup;
  }

  // Function -- NODOCS -- get_plusargs
  //
  // This function returns a queue with all of the plus arguments
  // that were used to start the simulation. Plusarguments may be
  // used by the simulator vendor, or may be specific to a company
  // or individual user. Plusargs never have extra arguments
  // (i.e. if there is a plusarg as the second argument on the
  // command line, the third argument is unrelated); this is not
  // necessarily the case with vendor specific dash arguments.

  // @uvm-ieee 1800.2-2020 auto G.1.3.2
  final void get_plusargs (out string[] args) {
    args ~= _m_plus_argv;
  }

  final string[] get_plusargs () {
    return _m_plus_argv.dup;
  }

  // Function -- NODOCS -- get_uvmargs
  //
  // This function returns a queue with all of the uvm arguments
  // that were used to start the simulation. A UVM argument is
  // taken to be any argument that starts with a - or + and uses
  // the keyword UVM (case insensitive) as the first three
  // letters of the argument.

  // @uvm-ieee 1800.2-2020 auto G.1.3.3
  final void get_uvm_args (out string[] args) {
    args ~= _m_uvm_argv;
  }

  final string[] get_uvm_args() {
    return _m_uvm_argv.dup;
  }

  // Function -- NODOCS -- get_arg_matches
  //
  // This function loads a queue with all of the arguments that
  // match the input expression and returns the number of items
  // that matched. If the input expression is bracketed
  // with //, then it is taken as an extended regular expression
  // otherwise, it is taken as the beginning of an argument to match.
  // For example:
  //
  //| string myargs[$]
  //| initial begin
  //|    void'(uvm_cmdline_proc.get_arg_matches("+foo",myargs)); //matches +foo, +foobar
  //|                                                            //doesn't match +barfoo
  //|    void'(uvm_cmdline_proc.get_arg_matches("/foo/",myargs)); //matches +foo, +foobar,
  //|                                                             //foo.sv, barfoo, etc.
  //|    void'(uvm_cmdline_proc.get_arg_matches("/^foo.*\.sv",myargs)); //matches foo.sv
  //|                                                                   //and foo123.sv,
  //|                                                                   //not barfoo.sv.

  // @uvm-ieee 1800.2-2020 auto G.1.3.4
  final size_t get_arg_matches (string gmatch, out string[] args) {

    bool match_is_regex = (gmatch.length > 2) && (gmatch[0] is '/') &&
      (gmatch[$-1] is '/');

    auto len = gmatch.length;

    foreach (arg; get_args()) {
      if (match_is_regex && uvm_is_match(gmatch, arg)) {
	args ~= arg;
      }
      else if ((arg.length >= len) && (arg[0..len] == gmatch)) {
	args ~= arg;
      }
    }
    return args.length;
  }


  // Group -- NODOCS -- Argument Values

  // Function -- NODOCS -- get_arg_value
  //
  // This function finds the first argument which matches the ~match~ arg and
  // returns the suffix of the argument. This is similar to the $value$plusargs
  // system task, but does not take a formatting string. The return value is
  // the number of command line arguments that match the ~match~ string, and
  // ~value~ is the value of the first match.

  // @uvm-ieee 1800.2-2020 auto G.1.4.1
  final int get_arg_value (string match, out string value) {
    auto chars = match.length;
    int get_arg_value_ = 0;
    foreach (arg; _m_argv) {
      if (arg.length >= chars) {
	if (arg[0..chars] == match) {
	  get_arg_value_++;
	  if (get_arg_value_ == 1)
	    value = arg[chars..$];
	}
      }
    }
    return get_arg_value_;
  }

  // Function -- NODOCS -- get_arg_values
  //
  // This function finds all the arguments which matches the ~match~ arg and
  // returns the suffix of the arguments in a list of values. The return
  // value is the number of matches that were found (it is the same as
  // values.size() ).
  // For example if '+foo=1,yes,on +foo=5,no,off' was provided on the command
  // line and the following code was executed:
  //
  //| string foo_values[$]
  //| initial begin
  //|    void'(uvm_cmdline_proc.get_arg_values("+foo=",foo_values));
  //|
  //
  // The foo_values queue would contain two entries.  These entries are shown
  // here:
  //
  //   0 - "1,yes,on"
  //   1 - "5,no,off"
  //
  // Splitting the resultant string is left to user but using the
  // uvm_string_split() function is recommended.

  // @uvm-ieee 1800.2-2020 auto G.1.4.2
  final size_t get_arg_values (string match, out string[] values) {
    auto chars = match.length;
    foreach (arg; _m_argv) {
      if (arg.length >= chars) {
	if (arg[0..chars] == match)
	  values ~= arg[chars..$];
      }
    }
    return values.length;
  }

  // Group -- NODOCS -- Tool information

  // Function -- NODOCS -- get_tool_name
  //
  // Returns the simulation tool that is executing the simulation.
  // This is a vendor specific string.

  static string get_tool_name () {
    import uvm.dpi.uvm_svcmd_dpi;
    return uvm_dpi_get_tool_name();
  }

  // Function -- NODOCS -- get_tool_version
  //
  // Returns the version of the simulation tool that is executing the simulation.
  // This is a vendor specific string.

  static string  get_tool_version () {
    import uvm.dpi.uvm_svcmd_dpi;
    return uvm_dpi_get_tool_version();
  }

  // constructor

  this(string name = "") {
    import uvm.dpi.uvm_svcmd_dpi;
    synchronized (this) {
      string[] argv;
      string[] plus_argv;
      string[] uvm_argv;
      super(name);
      foreach (opts; uvm_dpi_get_args()) {
	foreach (opt; opts) {
	  argv ~= opt;
	  if (opt[0] is '+') {
	    plus_argv ~= opt;
	  }
	  if (opt.length >= 4 && (opt[0] is '-' || opt[0] is '+')) {
	    if (opt[1..4].toUpper() == "UVM")
	      uvm_argv ~= opt;
	  }
	}
      }
      _m_argv ~= argv;
      _m_plus_argv ~= plus_argv;
      _m_uvm_argv ~= uvm_argv;
    }
  }

}
