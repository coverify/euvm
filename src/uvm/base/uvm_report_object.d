//
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
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

module uvm.base.uvm_report_object;

// `ifndef UVM_REPORT_CLIENT_SVH
// `define UVM_REPORT_CLIENT_SVH

// typedef class uvm_component;
// typedef class uvm_env;
// typedef class uvm_root;

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_object
//
//------------------------------------------------------------------------------
//
// The uvm_report_object provides an interface to the UVM reporting facility.
// Through this interface, components issue the various messages that occur
// during simulation. Users can configure what actions are taken and what
// file(s) are output for individual messages from a particular component
// or for all messages from all components in the environment. Defaults are
// applied where there is no explicit configuration.
//
// Most methods in uvm_report_object are delegated to an internal instance of a
// <uvm_report_handler>, which stores the reporting configuration and determines
// whether an issued message should be displayed based on that configuration.
// Then, to display a message, the report handler delegates the actual
// formatting and production of messages to a central <uvm_report_server>.
//
// A report consists of an id string, severity, verbosity level, and the textual
// message itself. They may optionally include the filename and line number from
// which the message came. If the verbosity level of a report is greater than the
// configured maximum verbosity level of its report object, it is ignored.
// If a report passes the verbosity filter in effect, the report's action is
// determined. If the action includes output to a file, the configured file
// descriptor(s) are determined.
//
// Actions - can be set for (in increasing priority) severity, id, and
// (severity,id) pair. They include output to the screen <UVM_DISPLAY>,
// whether the message counters should be incremented <UVM_COUNT>, and
// whether a $finish should occur <UVM_EXIT>.
//
// Default Actions - The following provides the default actions assigned to
// each severity. These can be overridden by any of the ~set_*_action~ methods.
//|    UVM_INFO -       UVM_DISPLAY
//|    UVM_WARNING -    UVM_DISPLAY
//|    UVM_ERROR -      UVM_DISPLAY | UVM_COUNT
//|    UVM_FATAL -      UVM_DISPLAY | UVM_EXIT
//
// File descriptors - These can be set by (in increasing priority) default,
// severity level, an id, or (severity,id) pair.  File descriptors are
// standard SystemVerilog file descriptors; they may refer to more than one file.
// It is the user's responsibility to open and close them.
//
// Default file handle - The default file handle is 0, which means that reports
// are not sent to a file even if an UVM_LOG attribute is set in the action
// associated with the report. This can be overridden by any of the ~set_*_file~
// methods.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_coreservice;
import uvm.base.uvm_object;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_server;
import uvm.base.uvm_report_catcher;
import uvm.base.uvm_report_message;
import uvm.base.uvm_callback;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import esdl.base.core: finish;

version(UVM_NO_DEPRECATED) { }
 else {
   version = UVM_INCLUDE_DEPRECATED;
 }

class uvm_report_object: /*extends*/ uvm_object
{
  mixin(uvm_sync_string);

  // In SV this callback is part of the uvm_report_catcher.sv file
  mixin uvm_register_cb!(uvm_report_catcher);

  @uvm_public_sync
  private uvm_report_handler _m_rh;

  // Function: new
  //
  // Creates a new report object with the given name. This method also creates
  // a new <uvm_report_handler> object to which most tasks are delegated.

  this(string name = "") {
    synchronized(this) {
      super(name);
      _m_rh = uvm_report_handler.type_id.create(name);
    }
  }

  override void set_name(string name) {
    synchronized(this) {
      super.set_name(name);
      _m_rh.set_name(name);
    }
  }
  //----------------------------------------------------------------------------
  // Group: Reporting
  //----------------------------------------------------------------------------

  import uvm.base.uvm_message_defines: uvm_report_mixin;
  mixin uvm_report_mixin;

  // Function: uvm_get_report_object
  //
  // Returns the nearest uvm_report_object when called.  From inside a
  // uvm_component, the method simply returns ~this~.
  //
  // See also the global version of <uvm_get_report_object>.

  uvm_report_object uvm_get_report_object() {
    return this;
  }

  // Function: uvm_report_enabled
  //
  // Returns 1 if the configured verbosity for this severity/id is greater than
  // or equal to ~verbosity~ else returns 0.
  //
  // See also <get_report_verbosity_level> and the global version of
  // <uvm_report_enabled>.

  final bool uvm_report_enabled(int verbosity,
				uvm_severity severity=uvm_severity.UVM_INFO,
				string id="") {
    if (get_report_verbosity_level(severity, id) < verbosity) {
      return false;
    }
    return true;
  }


  // Function: uvm_report

  void uvm_report(string file=__FILE__,
		  size_t line=__LINE__)(uvm_severity severity,
					string id,
					string message,
					int verbosity = -1,
					string context_name = "",
					bool report_enabled_checked = false) {
    if(verbosity == -1) {
      verbosity = (severity == UVM_ERROR) ? UVM_LOG :
	(severity == UVM_FATAL) ? UVM_NONE : UVM_MEDIUM;
    }
    uvm_report(severity, id, message, verbosity, file, line,
	       context_name, report_enabled_checked);
  }

  void uvm_report(uvm_severity severity,
		  string id,
		  string message,
		  int verbosity,
		  string filename,
		  size_t line,
		  string context_name = "",
		  bool report_enabled_checked = false) {
    uvm_report_message l_report_message;
    if(report_enabled_checked is false) {
      if (!uvm_report_enabled(verbosity, severity, id)) {
	return;
      }
    }
    l_report_message = uvm_report_message.new_report_message();
    l_report_message.set_report_message(severity, id, message,
					verbosity, filename, line, context_name);
    uvm_process_report_message(l_report_message);
  }

  // Function: uvm_report_info

  void uvm_report_info(string file=__FILE__,
		       size_t line=__LINE__)(string id,
					     string message,
					     int verbosity=UVM_MEDIUM,
					     string context_name = "",
					     bool report_enabled_checked = false) {
    uvm_report_info(id, message, verbosity, file, line,
		    context_name, report_enabled_checked);
  }


  void uvm_report_info(string id,
  		       string message,
  		       int verbosity,
  		       string filename,
  		       size_t line,
  		       string context_name = "",
  		       bool report_enabled_checked = false) {

    uvm_report(UVM_INFO, id, message, verbosity,
  	       filename, line, context_name, report_enabled_checked);
  }

  // Function: uvm_report_warning

  void uvm_report_warning(string file=__FILE__,
			  size_t line=__LINE__)(string id,
						string message,
						int verbosity=UVM_MEDIUM,
						string context_name = "",
						bool report_enabled_checked = false) {
    uvm_report_warning(id, message, verbosity, file, line,
		       context_name, report_enabled_checked);
  }

  void uvm_report_warning( string id,
			   string message,
			   int verbosity,
			   string filename,
			   size_t line,
			   string context_name = "",
			   bool report_enabled_checked = false) {

    uvm_report (UVM_WARNING, id, message, verbosity,
		filename, line, context_name, report_enabled_checked);
  }

  // Function: uvm_report_error

  void uvm_report_error(string file=__FILE__,
			size_t line=__LINE__)(string id,
					      string message,
					      int verbosity=UVM_LOW,
					      string context_name = "",
					      bool report_enabled_checked = false) {
    uvm_report_error(id, message, verbosity, file, line,
		     context_name, report_enabled_checked);
  }

  void uvm_report_error( string id,
			 string message,
			 int verbosity,
			 string filename,
			 size_t line,
			 string context_name = "",
			 bool report_enabled_checked = false) {
    uvm_report(UVM_ERROR, id, message, verbosity,
	       filename, line, context_name, report_enabled_checked);
  }

  // Function: uvm_report_fatal
  //
  // These are the primary reporting methods in the UVM. Using these instead
  // of ~$display~ and other ad hoc approaches ensures consistent output and
  // central control over where output is directed and any actions that
  // result. All reporting methods have the same arguments, although each has
  // a different default verbosity:
  //
  //   id        - a unique id for the report or report group that can be used
  //               for identification and therefore targeted filtering. You can
  //               configure an individual report's actions and output file(s)
  //               using this id string.
  //
  //   message   - the message body, preformatted if necessary to a single
  //               string.
  //
  //   verbosity - the verbosity of the message, indicating its relative
  //               importance. If this number is less than or equal to the
  //               effective verbosity level, see <set_report_verbosity_level>,
  //               then the report is issued, subject to the configured action
  //               and file descriptor settings.  Verbosity is ignored for
  //               warnings, errors, and fatals. However, if a warning, error
  //               or fatal is demoted to an info message using the
  //               <uvm_report_catcher>, then the verbosity is taken into
  //               account.
  //
  //   filename/line - (Optional) The location from which the report was issued.
  //               Use the predefined macros, `__FILE__ and `__LINE__.
  //               If specified, it is displayed in the output.
  //
  //   context_name - (Optional) The string context from where the message is
  //               originating.  This can be the %m of a module, a specific
  //               method, etc.
  //
  //   report_enabled_checked - (Optional) This bit indicates whether the
  //               currently provided message has been checked as to whether
  //               the message should be processed. If it hasn't been checked,
  //               it will be checked inside the uvm_report function.

  void uvm_report_fatal(string file=__FILE__,
			size_t line=__LINE__)(string id,
					      string message,
					      int verbosity=UVM_NONE,
					      string context_name = "",
					      bool report_enabled_checked = false) {
    uvm_report_fatal(id, message, verbosity, file, line,
		     context_name, report_enabled_checked);
  }

  void uvm_report_fatal( string id,
			 string message,
			 int verbosity,
			 string filename,
			 size_t line,
			 string context_name = "",
			 bool report_enabled_checked = false) {

    uvm_report (UVM_FATAL, id, message, verbosity,
		filename, line, context_name, report_enabled_checked);
  }

  // Function: uvm_process_report_message
  //
  // This method takes a preformed uvm_report_message, populates it with
  // the report object and passes it to the report handler for processing.
  // It is expected to be checked for verbosity and populated.

  void uvm_process_report_message(uvm_report_message report_message) {
    report_message.set_report_object(this);
    m_rh.process_report_message(report_message);
  }

  //----------------------------------------------------------------------------
  // Group: Verbosity Configuration
  //----------------------------------------------------------------------------


  // Function: get_report_verbosity_level
  //
  // Gets the verbosity level in effect for this object. Reports issued
  // with verbosity greater than this will be filtered out. The severity
  // and tag arguments check if the verbosity level has been modified for
  // specific severity/tag combinations.

  final int get_report_verbosity_level(uvm_severity severity=uvm_severity.UVM_INFO,
				       string id="") {
    return m_rh.get_verbosity_level(severity, id);
  }


  // Function: get_report_max_verbosity_level
  //
  // Gets the maximum verbosity level in effect for this report object.
  // Any report from this component whose verbosity exceeds this maximum will
  // be ignored.

  final int get_report_max_verbosity_level() {
    return m_rh.m_max_verbosity_level;
  }


  // Function: set_report_verbosity_level
  //
  // This method sets the maximum verbosity level for reports for this component.
  // Any report from this component whose verbosity exceeds this maximum will
  // be ignored.

  final void set_report_verbosity_level (int verbosity_level) {
    m_rh.set_verbosity_level(verbosity_level);
  }

  // Function: set_report_id_verbosity
  //
  final void set_report_id_verbosity (string id, int verbosity) {
    m_rh.set_id_verbosity(id, verbosity);
  }

  // Function: set_report_severity_id_verbosity
  //
  // These methods associate the specified verbosity threshold with reports of the
  // given ~severity~, ~id~, or ~severity-id~ pair. This threshold is compared with
  // the verbosity originally assigned to the report to decide whether it gets
  // processed.  A verbosity threshold associated with a particular ~severity-id~
  // pair takes precedence over a verbosity threshold associated with ~id~, which
  // takes precedence over a verbosity threshold associated with a ~severity~.
  //
  // The ~verbosity~ argument can be any integer, but is most commonly a
  // predefined <uvm_verbosity> value, <UVM_NONE>, <UVM_LOW>, <UVM_MEDIUM>,
  // <UVM_HIGH>, <UVM_FULL>.

  final void set_report_severity_id_verbosity (uvm_severity severity,
					       string id, int verbosity) {
    m_rh.set_severity_id_verbosity(severity, id, verbosity);
  }


  //----------------------------------------------------------------------------
  // Group: Action Configuration
  //----------------------------------------------------------------------------


  // Function: get_report_action
  //
  // Gets the action associated with reports having the given ~severity~
  // and ~id~.

  final int get_report_action(uvm_severity severity, string id) {
    return m_rh.get_action(severity, id);
  }


  // Function: set_report_severity_action
  //
  final void set_report_severity_action (uvm_severity severity,
					 uvm_action action) {
    m_rh.set_severity_action(severity, action);
  }

  // Function: set_report_id_action
  //
  final void set_report_id_action (string id, uvm_action action) {
    m_rh.set_id_action(id, action);
  }

  // Function: set_report_severity_id_action
  //
  // These methods associate the specified action or actions with reports of the
  // given ~severity~, ~id~, or ~severity-id~ pair. An action associated with a
  // particular ~severity-id~ pair takes precedence over an action associated with
  // ~id~, which takes precedence over an action associated with a ~severity~.
  //
  // The ~action~ argument can take the value <UVM_NO_ACTION>, or it can be a
  // bitwise OR of any combination of <UVM_DISPLAY>, <UVM_LOG>, <UVM_COUNT>,
  // <UVM_STOP>, <UVM_EXIT>, and <UVM_CALL_HOOK>.

  final void set_report_severity_id_action (uvm_severity severity,
					    string id, uvm_action action) {
    m_rh.set_severity_id_action(severity, id, action);
  }


  //----------------------------------------------------------------------------
  // Group: File Configuration
  //----------------------------------------------------------------------------


  // Function: get_report_file_handle
  //
  // Gets the file descriptor associated with reports having the given
  // ~severity~ and ~id~.

  final size_t get_report_file_handle(uvm_severity severity, string id) {
    return m_rh.get_file_handle(severity,id);
  }


  // Function: set_report_default_file

  final void set_report_default_file ( UVM_FILE file) {
    m_rh.set_default_file(file);
  }

  // Function: set_report_id_file

  final void set_report_id_file (string id, UVM_FILE file) {
    m_rh.set_id_file(id, file);
  }

  // Function: set_report_severity_file
  //
  final void set_report_severity_file (uvm_severity severity, UVM_FILE file) {
    m_rh.set_severity_file(severity, file);
  }

  // Function: set_report_severity_id_file
  //
  // These methods configure the report handler to direct some or all of its
  // output to the given file descriptor. The ~file~ argument must be a
  // multi-channel descriptor (mcd) or file id compatible with $fdisplay.
  //
  // A FILE descriptor can be associated with reports of
  // the given ~severity~, ~id~, or ~severity-id~ pair.  A FILE associated with
  // a particular ~severity-id~ pair takes precedence over a FILE associated
  // with ~id~, which take precedence over an a FILE associated with a
  // ~severity~, which takes precedence over the default FILE descriptor.
  //
  // When a report is issued and its associated action has the UVM_LOG bit
  // set, the report will be sent to its associated FILE descriptor.
  // The user is responsible for opening and closing these files.

  final void set_report_severity_id_file (uvm_severity severity,
					  string id, UVM_FILE file) {
    m_rh.set_severity_id_file(severity, id, file);
  }


  //----------------------------------------------------------------------------
  // Group: Override Configuration
  //----------------------------------------------------------------------------


  // Function: set_report_severity_override
  //
  final void set_report_severity_override(uvm_severity cur_severity,
					  uvm_severity new_severity) {
    m_rh.set_severity_override(cur_severity, new_severity);
  }
  // Function: set_report_severity_id_override
  //
  // These methods provide the ability to upgrade or downgrade a message in
  // terms of severity given ~severity~ and ~id~.  An upgrade or downgrade for
  // a specific ~id~ takes precedence over an upgrade or downgrade associated
  // with a ~severity~.
  final void set_report_severity_id_override(uvm_severity cur_severity,
					     string id,
					     uvm_severity new_severity) {
    m_rh.set_severity_id_override(cur_severity, id, new_severity);
  }


  //----------------------------------------------------------------------------
  // Group: Report Handler Configuration
  //----------------------------------------------------------------------------

  // Function: set_report_handler
  //
  // Sets the report handler, overwriting the default instance. This allows
  // more than one component to share the same report handler.

  final void set_report_handler(uvm_report_handler handler) {
    synchronized(this) {
      _m_rh = handler;
    }
  }


  // Function: get_report_handler
  //
  // Returns the underlying report handler to which most reporting tasks
  // are delegated.

  final uvm_report_handler get_report_handler() {
    synchronized(this) {
      return _m_rh;
    }
  }


  // Function: reset_report_handler
  //
  // Resets the underlying report handler to its default settings. This clears
  // any settings made with the set_report_* methods (see below).

  final void reset_report_handler() {
    m_rh.initialize;
  }

  version(UVM_INCLUDE_DEPRECATED) {


    //----------------------------------------------------------------------------
    // Group: Callbacks
    //----------------------------------------------------------------------------


    // Function: report_info_hook
    //
    //

    bool report_info_hook(string id, string message,
  			  int verbosity, string filename, size_t line) {
      return true;
    }

    // Function: report_error_hook
    //
    //

    bool report_error_hook(string id, string message,
  			   int verbosity, string filename, size_t line) {
      return true;
    }

    // Function: report_warning_hook
    //
    //

    bool report_warning_hook(string id, string message,
  			     int verbosity, string filename, size_t line) {
      return true;
    }

    // Function: report_fatal_hook
    //
    //

    bool report_fatal_hook(string id, string message,
  			   int verbosity, string filename, size_t line) {
      return true;
    }

    // Function: report_hook
    //
    // These hook methods can be defined in derived classes to perform additional
    // actions when reports are issued. They are called only if the <UVM_CALL_HOOK>
    // bit is specified in the action associated with the report. The default
    // implementations return 1, which allows the report to be processed. If an
    // override returns 0, then the report is not processed.
    //
    // First, the report_hook method is called, followed by the severity
    // severity specific hook (report_info_hook, etc.). If either hook method
    // returns 0 then the report is not processed further.

    bool report_hook(string id, string message,
  		     int verbosity, string filename, size_t line) {
      return true;
    }


    // Function- report_header
    //
    // Prints version and copyright information. This information is sent to the
    // command line if ~file~ is 0, or to the file descriptor ~file~ if it is not 0.
    // The <uvm_root::run_test> task calls this method just before it component
    // phasing begins.
    //
    // Use <uvm_root::report_header()>

    void report_header(UVM_FILE file = UVM_FILE.init) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root l_root = cs.get_root();
      l_root.report_header(file);
    }


    // Function- report_summarize
    //
    // Outputs statistical information on the reports issued by the central report
    // server. This information will be sent to the command line if ~file~ is 0, or
    // to the file descriptor ~file~ if it is not 0.
    //
    // The <run_test> method in uvm_top calls this method.
    //
    // Use:
    // uvm_report_server rs =uvm_report_server::get_server();
    // rs.report_summarize();

    void report_summarize(UVM_FILE file = UVM_FILE.init) {
      uvm_report_server l_rs = uvm_report_server.get_server();
      l_rs.report_summarize(file);
    }


    // Function- die
    //
    // This method is called by the report server if a report reaches the maximum
    // quit count or has a UVM_EXIT action associated with it, e.g., as with
    // fatal errors.
    //
    // Calls the <uvm_component::pre_abort()> method
    // on the entire <uvm_component> hierarchy in a bottom-up fashion.
    // It then call calls <report_summarize> and terminates the simulation
    // with ~$finish~.
    //
    // Use:
    // uvm_report_server rs =uvm_report_server::get_server();
    // rs.die()

    void die() {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root l_root = cs.get_root();
      l_root.die();
    }

    // Function- set_report_max_quit_count
    //
    // Sets the maximum quit count in the report handler to ~max_count~. When the
    // number of UVM_COUNT actions reaches ~max_count~, the <die> method is called.
    //
    // The default value of 0 indicates that there is no upper limit to the number
    // of UVM_COUNT reports.
    //
    // Use:
    // uvm_report_server rs =uvm_report_server::get_server();
    // rs.set_max_quit_count()

    final void set_report_max_quit_count(int max_count) {
      uvm_report_server l_rs = uvm_report_server.get_server();
      l_rs.set_max_quit_count(max_count);
    }


    // Function- get_report_server
    //
    // Returns the <uvm_report_server> instance associated with this report object.
    //
    // Use <uvm_report_server::get_server()>

    final uvm_report_server get_report_server() {
      uvm_report_server l_rs = uvm_report_server.get_server();
      return l_rs;
    }


    // Function- dump_report_state
    //
    // This method dumps the internal state of the report handler. This includes
    // information about the maximum quit count, the maximum verbosity, and the
    // action and files associated with severities, ids, and (severity, id) pairs.
    //
    // Use:
    // uvm_report_handler rh =get_report_handler();
    // rh.print().

    void dump_report_state() {
      m_rh.dump_state();
    }


    //----------------------------------------------------------------------------
    //                     PRIVATE or PSUEDO-PRIVATE members
    //                      *** Do not call directly ***
    //         Implementation and even existence are subject to change.
    //----------------------------------------------------------------------------

    protected override uvm_report_object m_get_report_object() {
      return this;
    }
  }

} // endclass

// `endif // UVM_REPORT_CLIENT_SVH



// ****************************
// From UVM_MESSAGE_DEFINES_SVH
// ****************************

// `ifndef UVM_LINE_WIDTH
enum int UVM_LINE_WIDTH=120;
// `endif

// `ifndef UVM_NUM_LINES
enum int UVM_NUM_LINES=120;
// `endif

//`ifndef UVM_USE_FILE_LINE
//`define UVM_REPORT_DISABLE_FILE_LINE
//`endif

// `ifdef UVM_REPORT_DISABLE_FILE_LINE
// `define UVM_REPORT_DISABLE_FILE
// `define UVM_REPORT_DISABLE_LINE
// `endif

// `ifdef UVM_REPORT_DISABLE_FILE
// `define uvm_file ""
// `else
// `define uvm_file `__FILE__
// `endif

// `ifdef UVM_REPORT_DISABLE_LINE
// `define uvm_line 0
// `else
// `define uvm_line `__LINE__
// `endif


//------------------------------------------------------------------------------
//
// Title: Report Macros
//
// This set of macros provides wrappers around the uvm_report_* <Reporting>
// functions. The macros serve two essential purposes:
//
// - To reduce the processing overhead associated with filtered out messages,
//   a check is made against the report's verbosity setting and the action
//   for the id/severity pair before any string formatting is performed. This
//   affects only `uvm_info reports.
//
// - The `__FILE__ and `__LINE__ information is automatically provided to the
//   underlying uvm_report_* call. Having the file and line number from where
//   a report was issued aides in debug. You can disable display of file and
//   line information in reports by defining UVM_REPORT_DISABLE_FILE_LINE on
//   the command line.
//
// The macros also enforce a verbosity setting of UVM_NONE for warnings, errors
// and fatals so that they cannot be mistakingly turned off by setting the
// verbosity level too low (warning and errors can still be turned off by
// setting the actions appropriately).
//
// To use the macros, replace the previous call to uvm_report_* with the
// corresponding macro.
//
//| //Previous calls to uvm_report_*
//| uvm_report_info("MYINFO1", $sformatf("val: %0d", val), UVM_LOW);
//| uvm_report_warning("MYWARN1", "This is a warning");
//| uvm_report_error("MYERR", "This is an error");
//| uvm_report_fatal("MYFATAL", "A fatal error has occurred");
//
// The above code is replaced by
//
//| //New calls to `uvm_*
//| `uvm_info("MYINFO1", $sformatf("val: %0d", val), UVM_LOW)
//| `uvm_warning("MYWARN1", "This is a warning")
//| `uvm_error("MYERR", "This is an error")
//| `uvm_fatal("MYFATAL", "A fatal error has occurred")
//
// Macros represent text substitutions, not statements, so they should not be
// terminated with semi-colons.
