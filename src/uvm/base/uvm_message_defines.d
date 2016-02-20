//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
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
//----------------------------------------------------------------------

module uvm.base.uvm_message_defines;

import uvm.base.uvm_report_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;

enum UVM_LINE_WIDTH = 120;
enum UVM_NUM_LINES  = 120;

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

mixin template uvm_report_mixin()
{
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
				      int verbosity = UVM_MEDIUM) {
    if (uvm_report_enabled(verbosity, UVM_INFO, id))
      uvm_report_info(id, message, verbosity, file, line);
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

  // MACRO: `uvm_info_context
  //
  //| `uvm_info_context(ID,MSG,VERBOSITY,CNTXT)
  //
  // Operates identically to `uvm_info but requires that the
  // context, or <uvm_report_object>, in which the message is printed be
  // explicitly supplied as a macro argument.

  static void uvm_info_context(string file=__FILE__,
			       size_t line=__LINE__)(string id, string message,
						     int verbosity,
						     uvm_report_object context) {
    if (context.uvm_report_enabled(verbosity, UVM_INFO, id))
      context.uvm_report_info(id, message, verbosity, file, line);
  }

  // MACRO: `uvm_warning_context
  //
  //| `uvm_warning_context(ID,MSG,CNTXT)
  //
  // Operates identically to `uvm_warning but requires that the
  // context, or <uvm_report_object>, in which the message is printed be
  // explicitly supplied as a macro argument.

  static void uvm_warning_context(string file=__FILE__,
				  size_t line=__LINE__)
    (string id, string message, uvm_report_object context) {
    if (context.uvm_report_enabled(UVM_NONE, UVM_WARNING, id))
      context.uvm_report_warning(id, message, UVM_NONE, file, line);
  }

  // MACRO: `uvm_error_context
  //
  //| `uvm_error_context(ID,MSG,CNTXT)
  //
  // Operates identically to `uvm_error but requires that the
  // context, or <uvm_report_object> in which the message is printed be
  // explicitly supplied as a macro argument.

  static void uvm_error_context(string file=__FILE__,
				size_t line=__LINE__)
    (string id, string message, uvm_report_object context) {
    if (context.uvm_report_enabled(UVM_NONE, UVM_ERROR, id))
      context.uvm_report_error(id, message, UVM_NONE, file, line);
  }

  // MACRO: `uvm_fatal_context
  //
  //| `uvm_fatal_context(ID,MSG,CNTXT)
  //
  // Operates identically to `uvm_fatal but requires that the
  // context, or <uvm_report_object>, in which the message is printed be
  // explicitly supplied as a macro argument.

  static void uvm_fatal_context(string file=__FILE__,
				size_t line=__LINE__)
    (string id, string message, uvm_report_object context) {
    if (context.uvm_report_enabled(UVM_NONE, UVM_FATAL, id))
      context.uvm_report_fatal(id, message, UVM_NONE, file, line);
  }
}

// mixin uvm_report_mixin;  // have it in the uvm_globals
