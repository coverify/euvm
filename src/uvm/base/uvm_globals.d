//
//------------------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2010-2012 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
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
import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_report_message: uvm_report_message,
  uvm_report_message_element_base;
import uvm.base.uvm_object_globals: uvm_severity, uvm_verbosity,
  uvm_action, uvm_action_type, uvm_core_state, m_uvm_core_state;
import uvm.base.uvm_root: uvm_root;
import uvm.dpi.uvm_regex: uvm_re_match, uvm_glob_to_re;

import esdl.base.core: wait;
import esdl.data.bvec;
import esdl.data.bstr;		// BitStream

import std.traits: EnumMembers;
import std.conv;

// version (UVM_NO_DEPRECATED) { }
//  else {
//    version = UVM_INCLUDE_DEPRECATED;
//  }

interface uvm_report_intf
{
  bool uvm_report_enabled(int verbosity, uvm_severity severity=uvm_severity.UVM_INFO,
			  string id="");
  void uvm_process_report_message(uvm_report_message msg);
  void uvm_report_trace(string id, lazy string message, int verbosity, string filename,
			size_t line, string context_name = "",
			bool report_enabled_checked = false);
  void uvm_report_info(string id, lazy string message, int verbosity, string filename,
		       size_t line, string context_name = "",
		       bool report_enabled_checked = false);
  void uvm_report_warning( string id, lazy string message, int verbosity, string filename,
			   size_t line, string context_name = "", bool report_enabled_checked = false);
  void uvm_report_error( string id, lazy string message, int verbosity, string filename,
			 size_t line, string context_name = "", bool report_enabled_checked = false);
  void uvm_report_fatal( string id, lazy string message, int verbosity, string filename,
			 size_t line, string context_name = "", bool report_enabled_checked = false);

  void uvm_message(MF...)(uvm_severity severity, string id, lazy string message,
			  uvm_verbosity verbosity, string file, size_t line,
			  ref uvm_report_message rm, MF mf) {
    if (uvm_report_enabled(verbosity, severity, id)) {
      if (rm is null) {
	rm = uvm_report_message.new_report_message();
      }
      rm.set_report_message(severity, id, message(), verbosity, file, line, "");
      rm.add(mf);
      uvm_process_report_message(rm);
    }
  }
  
  // MACRO: `uvm_trace
  //
  //| `uvm_trace(ID,MSG,VERBOSITY)
  //
  // Calls uvm_report_trace if ~VERBOSITY~ is lower than the configured verbosity of
  // the associated reporter. ~ID~ is given as the message tag and ~MSG~ is given as
  // the message text. The file and line are also sent to the uvm_report_trace call.
  //

  void uvm_trace(string file=__FILE__, size_t line=__LINE__)
    (string id, lazy string message, uvm_verbosity verbosity) {
    if (uvm_report_enabled(verbosity, uvm_severity.UVM_TRACE, id))
      uvm_report_trace(id, message, verbosity, file, line);
  }

  void uvm_trace(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, uvm_verbosity verbosity, MF mf)
    if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
      uvm_report_message rm;
      uvm_message(uvm_severity.UVM_TRACE, id, message, verbosity, file, line, rm, mf);
    }

  void uvm_trace(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, uvm_verbosity verbosity,
     ref uvm_report_message rm, MF mf)
    if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
      uvm_message(uvm_severity.UVM_TRACE, id, message, verbosity, file, line, rm, mf);
    }

  // MACRO: `uvm_info
  //
  //| `uvm_info(ID,MSG,VERBOSITY)
  //
  // Calls uvm_report_info if ~VERBOSITY~ is lower than the configured verbosity of
  // the associated reporter. ~ID~ is given as the message tag and ~MSG~ is given as
  // the message text. The file and line are also sent to the uvm_report_info call.
  //

  void uvm_info(string file=__FILE__, size_t line=__LINE__)
    (string id, lazy string message, uvm_verbosity verbosity) {
    if (uvm_report_enabled(verbosity, uvm_severity.UVM_INFO, id))
      uvm_report_info(id, message, verbosity, file, line);
  }

  void uvm_info(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, uvm_verbosity verbosity, MF mf)
    if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
      uvm_report_message rm;
      uvm_message(uvm_severity.UVM_INFO, id, message, verbosity, file, line, rm, mf);
    }

  void uvm_info(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, uvm_verbosity verbosity,
     ref uvm_report_message rm, MF mf)
    if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
      uvm_message(uvm_severity.UVM_INFO, id, message, verbosity, file, line, rm, mf);
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

  void uvm_warning(string file=__FILE__, size_t line=__LINE__)
    (string id, lazy string message) {
    if (uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_WARNING, id))
      uvm_report_warning(id, message, uvm_verbosity.UVM_NONE, file, line);
  }

  void uvm_warning(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, MF mf)
    if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
      uvm_report_message rm;
      uvm_message(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
    }

  void uvm_warning(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, ref uvm_report_message rm, MF mf)
    if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
      uvm_message(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
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

  void uvm_error(string file=__FILE__, size_t line=__LINE__)
    (string id, lazy string message) {
    if (uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_ERROR, id))
      uvm_report_error(id, message, uvm_verbosity.UVM_NONE, file, line);
  }

  void uvm_error(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, MF mf)
    if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
      uvm_report_message rm;
      uvm_message(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
    }

  void uvm_error(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, ref uvm_report_message rm, MF mf)
    if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
      uvm_message(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
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

  void uvm_fatal(string file=__FILE__, size_t line=__LINE__)
    (string id, lazy string message) {
    if (uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_FATAL, id))
      uvm_report_fatal(id, message, uvm_verbosity.UVM_NONE, file, line);
  }

  void uvm_fatal(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, MF mf)
    if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
      uvm_report_message rm;
      uvm_message(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
    }

  void uvm_fatal(string file=__FILE__, size_t line=__LINE__, MF...)
    (string id, lazy string message, ref uvm_report_message rm, MF mf)
    if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
      uvm_message(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
    }
}



// mixin uvm_report_mixin;
// mixin (uvm_report_mixin_string());

void uvm_message(MF...)(uvm_severity severity, string id, lazy string message,
			uvm_verbosity verbosity, string file, size_t line,
			ref uvm_report_message rm, MF mf) {
  if (uvm_report_enabled(verbosity, severity, id)) {
    if (rm is null) {
      rm = uvm_report_message.new_report_message();
    }
    rm.set_report_message(severity, id, message(), verbosity, file, line, "");
    rm.add(mf);
    uvm_process_report_message(rm);
  }
}
  
// MACRO: `uvm_trace
//
//| `uvm_trace(ID,MSG,VERBOSITY)
//
// Calls uvm_report_trace if ~VERBOSITY~ is lower than the configured verbosity of
// the associated reporter. ~ID~ is given as the message tag and ~MSG~ is given as
// the message text. The file and line are also sent to the uvm_report_trace call.
//

void uvm_trace(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_verbosity verbosity) {
  if (uvm_report_enabled(verbosity, uvm_severity.UVM_TRACE, id))
    uvm_report_trace(id, message, verbosity, file, line);
}

void uvm_trace(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message(uvm_severity.UVM_TRACE, id, message, verbosity, file, line, rm, mf);
  }

void uvm_trace(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity,
   ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message(uvm_severity.UVM_TRACE, id, message, verbosity, file, line, rm, mf);
  }

// MACRO: `uvm_info
//
//| `uvm_info(ID,MSG,VERBOSITY)
//
// Calls uvm_report_info if ~VERBOSITY~ is lower than the configured verbosity of
// the associated reporter. ~ID~ is given as the message tag and ~MSG~ is given as
// the message text. The file and line are also sent to the uvm_report_info call.
//

void uvm_info(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_verbosity verbosity) {
  if (uvm_report_enabled(verbosity, uvm_severity.UVM_INFO, id))
    uvm_report_info(id, message, verbosity, file, line);
}

void uvm_info(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message(uvm_severity.UVM_INFO, id, message, verbosity, file, line, rm, mf);
  }

void uvm_info(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity,
   ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message(uvm_severity.UVM_INFO, id, message, verbosity, file, line, rm, mf);
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

void uvm_warning(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message) {
  if (uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_WARNING, id))
    uvm_report_warning(id, message, uvm_verbosity.UVM_NONE, file, line);
}

void uvm_warning(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
  }

void uvm_warning(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
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

void uvm_error(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message) {
  if (uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_ERROR, id))
    uvm_report_error(id, message, uvm_verbosity.UVM_NONE, file, line);
}

void uvm_error(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
  }

void uvm_error(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
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

void uvm_fatal(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message) {
  if (uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_FATAL, id))
    uvm_report_fatal(id, message, uvm_verbosity.UVM_NONE, file, line);
}

void uvm_fatal(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
  }

void uvm_fatal(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE, file, line, rm, mf);
  }

static void uvm_message_context(MF...)(uvm_severity severity, string id,
				       lazy string message, uvm_verbosity verbosity,
				       string file, size_t line,
				       uvm_report_object ro,
				       ref uvm_report_message rm, MF mf) {
  if (ro.uvm_report_enabled(verbosity, severity, id)) {
    if (rm is null) {
      rm = uvm_report_message.new_report_message();
    }
    rm.set_report_message(severity, id, message(), verbosity, file, line, "");
    rm.add(mf);
    ro.uvm_process_report_message(rm);
  }
}

// MACRO: `uvm_trace_context
//
//| `uvm_trace_context(ID,MSG,VERBOSITY,CNTXT)
//
// Operates identically to `uvm_trace but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

static void uvm_trace_context(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_verbosity verbosity, uvm_report_object ro) {
  if (ro.uvm_report_enabled(verbosity, uvm_severity.UVM_TRACE, id)) {
    ro.uvm_report_trace(id, message, verbosity, file, line);
  }
}

static void uvm_trace_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity,
   uvm_report_object ro, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message_context(uvm_severity.UVM_TRACE, id, message, verbosity,
			file, line, ro, rm, mf);
  }

static void uvm_trace_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity,
   uvm_report_object ro, ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message_context(uvm_severity.UVM_TRACE, id, message, verbosity,
			file, line, ro, rm, mf);
  }

// MACRO: `uvm_info_context
//
//| `uvm_info_context(ID,MSG,VERBOSITY,CNTXT)
//
// Operates identically to `uvm_info but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

static void uvm_info_context(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_verbosity verbosity, uvm_report_object ro) {
  if (ro.uvm_report_enabled(verbosity, uvm_severity.UVM_INFO, id)) {
    ro.uvm_report_info(id, message, verbosity, file, line);
  }
}

static void uvm_info_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity,
   uvm_report_object ro, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message_context(uvm_severity.UVM_INFO, id, message, verbosity,
			file, line, ro, rm, mf);
  }

static void uvm_info_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_verbosity verbosity,
   uvm_report_object ro, ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message_context(uvm_severity.UVM_INFO, id, message, verbosity,
			file, line, ro, rm, mf);
  }

// MACRO: `uvm_warning_context
//
//| `uvm_warning_context(ID,MSG,CNTXT)
//
// Operates identically to `uvm_warning but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

static void uvm_warning_context(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_report_object ro) {
  if (ro.uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_WARNING, id)) {
    ro.uvm_report_warning(id, message, uvm_verbosity.UVM_NONE, file, line);
  }
}

static void uvm_warning_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_report_object ro, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message_context(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE,
			file, line, ro, rm, mf);
  }

static void uvm_warning_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_report_object ro,
   ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message_context(uvm_severity.UVM_WARNING, id, message, uvm_verbosity.UVM_NONE,
			file, line, ro, rm, mf);
  }

// MACRO: `uvm_error_context
//
//| `uvm_error_context(ID,MSG,CNTXT)
//
// Operates identically to `uvm_error but requires that the
// context, or <uvm_report_object> in which the message is printed be
// explicitly supplied as a macro argument.

static void uvm_error_context(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_report_object ro) {
  if (ro.uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_ERROR, id)) {
    ro.uvm_report_error(id, message, uvm_verbosity.UVM_NONE, file, line);
  }
}

static void uvm_error_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_report_object ro, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message_context(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE,
			file, line, ro, rm, mf);
  }

static void uvm_error_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_report_object ro,
   ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message_context(uvm_severity.UVM_ERROR, id, message, uvm_verbosity.UVM_NONE,
			file, line, ro, rm, mf);
  }

// MACRO: `uvm_fatal_context
//
//| `uvm_fatal_context(ID,MSG,CNTXT)
//
// Operates identically to `uvm_fatal but requires that the
// context, or <uvm_report_object>, in which the message is printed be
// explicitly supplied as a macro argument.

static void uvm_fatal_context(string file=__FILE__, size_t line=__LINE__)
  (string id, lazy string message, uvm_report_object ro) {
  if (ro.uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_FATAL, id)) {
    ro.uvm_report_fatal(id, message, uvm_verbosity.UVM_NONE, file, line);
  }
}

static void uvm_fatal_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_report_object ro, MF mf)
  if (MF.length > 0 && is (MF[0]: uvm_report_message_element_base)) {
    uvm_report_message rm;
    uvm_message_context(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE,
			file, line, ro, rm, mf);
  }

static void uvm_fatal_context(string file=__FILE__, size_t line=__LINE__, MF...)
  (string id, lazy string message, uvm_report_object ro,
   ref uvm_report_message rm, MF mf)
  if (MF.length == 0 || is (MF[0]: uvm_report_message_element_base)) {
    uvm_message_context(uvm_severity.UVM_FATAL, id, message, uvm_verbosity.UVM_NONE,
			file, line, ro, rm, mf);
  }

// Title -- NODOCS -- Globals

//------------------------------------------------------------------------------
//
// Group -- NODOCS -- Simulation Control
//
//------------------------------------------------------------------------------

// Task -- NODOCS -- run_test
//
// Convenience function for uvm_top.run_test(). See <uvm_root> for more
// information.

// @uvm-ieee 1800.2-2020 auto F.3.1.2
void run_test (string test_name = "") {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.run_test(test_name);
}


//----------------------------------------------------------------------------
//
// Group: Reporting
//
//----------------------------------------------------------------------------



// @uvm-ieee 1800.2-2020 auto F.3.2.1
uvm_report_object uvm_get_report_object() {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  return top;
}


// Function -- NODOCS -- uvm_report_enabled
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

// @uvm-ieee 1800.2-2020 auto F.3.2.2
int uvm_report_enabled (int verbosity,
			uvm_severity severity = uvm_severity.UVM_INFO,
			string id = "") {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  return top.uvm_report_enabled(verbosity, severity, id);
}

void uvm_report_debug(string file=__FILE__,
		      size_t line=__LINE__) (uvm_severity severity,
					     string id,
					     lazy string message,
					     int verbosity = int.min,
					     string context_name = "",
					     bool report_enabled_checked = false) {
  uvm_report(severity, id, message, verbosity, file, line,
	     context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_report

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_report(uvm_severity severity,
		string id,
		lazy string message,
		int verbosity = int.min,
		string filename = "",
		size_t line = 0,
		string context_name = "",
		bool report_enabled_checked = false) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;

  if (verbosity is int.min) {
    verbosity = (severity is uvm_severity.UVM_ERROR) ? uvm_verbosity.UVM_LOW :
      (severity is uvm_severity.UVM_FATAL) ? uvm_verbosity.UVM_NONE : uvm_verbosity.UVM_MEDIUM;
  }

  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report(severity, id, message, verbosity, filename, line,
		 context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_report_trace

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_report_trace(string file=__FILE__,
		      size_t line=__LINE__)(string id,
					    lazy string message,
					    int verbosity=uvm_verbosity.UVM_MEDIUM,
					    string context_name = "",
					    bool report_enabled_checked = false) {
  uvm_report_trace(id, message, verbosity, file, line,
		   context_name, report_enabled_checked);
}

void uvm_report_trace(string id,
		      lazy string message,
		      int verbosity = uvm_verbosity.UVM_MEDIUM,
		      string filename = "",
		      size_t line = 0,
		      string context_name = "",
		      bool report_enabled_checked = false) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_trace(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_report_info

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_report_info(string file=__FILE__,
		     size_t line=__LINE__)(string id,
					   lazy string message,
					   int verbosity=uvm_verbosity.UVM_MEDIUM,
					   string context_name = "",
					   bool report_enabled_checked = false) {
  uvm_report_info(id, message, verbosity, file, line,
		  context_name, report_enabled_checked);
}

void uvm_report_info(string id,
		     lazy string message,
		     int verbosity = uvm_verbosity.UVM_MEDIUM,
		     string filename = "",
		     size_t line = 0,
		     string context_name = "",
		     bool report_enabled_checked = false) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_info(id, message, verbosity, filename, line,
		      context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_report_warning

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_report_warning(string file=__FILE__,
			size_t line=__LINE__)(string id,
					      lazy string message,
					      int verbosity=uvm_verbosity.UVM_MEDIUM,
					      string context_name = "",
					      bool report_enabled_checked = false) {
  uvm_report_warning(id, message, verbosity, file, line,
		     context_name, report_enabled_checked);
}

void uvm_report_warning(string id,
			lazy string message,
			int verbosity = uvm_verbosity.UVM_MEDIUM,
			string filename = "",
			size_t line = 0,
			string context_name = "",
			bool report_enabled_checked = false) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_warning(id, message, verbosity, filename, line,
			 context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_report_error

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_report_error(string file=__FILE__,
		      size_t line=__LINE__)(string id,
					    lazy string message,
					    int verbosity=uvm_verbosity.UVM_LOW,
					    string context_name = "",
					    bool report_enabled_checked = false) {
  uvm_report_error(id, message, verbosity, file, line,
		   context_name, report_enabled_checked);
}

void uvm_report_error(string id,
		      lazy string message,
		      int verbosity = uvm_verbosity.UVM_LOW,
		      string filename = "",
		      size_t line = 0,
		      string context_name = "",
		      bool report_enabled_checked = false) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_error(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_report_fatal
//
// These methods, defined in package scope, are convenience functions that
// delegate to the corresponding component methods in ~uvm_top~. They can be
// used in module-based code to use the same reporting mechanism as class-based
// components. See <uvm_report_object> for details on the reporting mechanism.
//
// *Note:* Verbosity is ignored for warnings, errors, and fatals to ensure users
// do not inadvertently filter them out. It remains in the methods for backward
// compatibility.

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_report_fatal(string file=__FILE__,
		      size_t line=__LINE__)(string id,
					    lazy string message,
					    int verbosity=uvm_verbosity.UVM_NONE,
					    string context_name = "",
					    bool report_enabled_checked = false) {
  uvm_report_fatal(id, message, verbosity, file, line,
		   context_name, report_enabled_checked);
}

void uvm_report_fatal(string id,
		      lazy string message,
		      int verbosity = uvm_verbosity.UVM_NONE,
		      string filename = "",
		      size_t line = 0,
		      string context_name = "",
		      bool report_enabled_checked = false) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  top.uvm_report_fatal(id, message, verbosity, filename, line,
		       context_name, report_enabled_checked);
}

// Function -- NODOCS -- uvm_process_report_message
//
// This method, defined in package scope, is a convenience function that
// delegate to the corresponding component method in ~uvm_top~. It can be
// used in module-based code to use the same reporting mechanism as class-based
// components. See <uvm_report_object> for details on the reporting mechanism.

// @uvm-ieee 1800.2-2020 auto F.3.2.3
void uvm_process_report_message(uvm_report_message report_message) {
  import uvm.base.uvm_coreservice;
  import uvm.base.uvm_root;
  uvm_coreservice_t cs = uvm_coreservice_t.get();
  uvm_root top = cs.get_root();
  // Process p = Process.self();
  top.uvm_process_report_message(report_message);
}


// TODO merge with uvm_enum_wrapper#(uvm_severity)
bool uvm_string_to_severity (string sev_str, out uvm_severity sev) {
  switch (sev_str) {
  case "UVM_INFO":    sev = uvm_severity.UVM_INFO;    break;
  case "UVM_WARNING": sev = uvm_severity.UVM_WARNING; break;
  case "UVM_ERROR":   sev = uvm_severity.UVM_ERROR;   break;
  case "UVM_FATAL":   sev = uvm_severity.UVM_FATAL;   break;
  default: return false;
  }
  return true;
}

bool uvm_string_to_action (string action_str, out uvm_action action) {
  string[] actions;
  uvm_string_split(action_str,'|',actions);
  bool retval = true;
  // action = 0; // taken care since action is of type "out"
  foreach (a; actions[]) {
    switch (a) {
    case "UVM_NO_ACTION": action |= uvm_action_type.UVM_NO_ACTION; break;
    case "UVM_DISPLAY":   action |= uvm_action_type.UVM_DISPLAY;   break;
    case "UVM_LOG":       action |= uvm_action_type.UVM_LOG;       break;
    case "UVM_COUNT":     action |= uvm_action_type.UVM_COUNT;     break;
    case "UVM_EXIT":      action |= uvm_action_type.UVM_EXIT;      break;
    case "UVM_CALL_HOOK": action |= uvm_action_type.UVM_CALL_HOOK; break;
    case "UVM_STOP":      action |= uvm_action_type.UVM_STOP;      break;
    case "UVM_RM_RECORD": action |= uvm_action_type.UVM_RM_RECORD; break;
    default: retval = false;
    }
  }
  return retval;
}

bool uvm_string_to_verbosity(string verb_str, out uvm_verbosity verb_enum) {
  switch (verb_str) {
  case "NONE"       : verb_enum = uvm_verbosity.UVM_NONE;   return true;
  case "UVM_NONE"   : verb_enum = uvm_verbosity.UVM_NONE;   return true;
  case "LOW"        : verb_enum = uvm_verbosity.UVM_LOW;    return true;
  case "UVM_LOW"    : verb_enum = uvm_verbosity.UVM_LOW;    return true;
  case "MEDIUM"     : verb_enum = uvm_verbosity.UVM_MEDIUM; return true;
  case "UVM_MEDIUM" : verb_enum = uvm_verbosity.UVM_MEDIUM; return true;
  case "HIGH"       : verb_enum = uvm_verbosity.UVM_HIGH;   return true;
  case "UVM_HIGH"   : verb_enum = uvm_verbosity.UVM_HIGH;   return true;
  case "FULL"       : verb_enum = uvm_verbosity.UVM_FULL;   return true;
  case "UVM_FULL"   : verb_enum = uvm_verbosity.UVM_FULL;   return true;
  case "DEBUG"      : verb_enum = uvm_verbosity.UVM_DEBUG;  return true;
  case "UVM_DEBUG"  : verb_enum = uvm_verbosity.UVM_DEBUG;  return true;
  default           :                                       return false;
  }
}

//----------------------------------------------------------------------------
//
// Group: Miscellaneous
//
// The library implements the following public API at the package level beyond
// what is documented in IEEE 1800.2.
//----------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto F.3.3.1
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
// Function -- NODOCS -- uvm_string_to_bits
//
// Converts an input string to its bit-vector equivalent. Max bit-vector
// length is approximately 14000 characters.
//----------------------------------------------------------------------------

bstr uvm_string_to_bits(string str) {
  bstr uvm_string_to_bits_;
  uvm_string_to_bits_.fromArray(str);
  return uvm_string_to_bits_;
}

// @uvm-ieee 1800.2-2020 auto F.3.1.1
uvm_core_state get_core_state() {
  return m_uvm_core_state;
}

// Function: uvm_init
// Implementation of uvm_init, as defined in section
// F.3.1.3 in 1800.2-2020.
//
// *Note:* The LRM states that subsequent calls to <uvm_init> after
// the first are silently ignored, however there are scenarios wherein
// the implementation breaks this requirement.
//
// If the core state (see <get_core_state>) is ~UVM_CORE_PRE_INIT~ when <uvm_init>,
// is called, then the library can not determine the appropriate core service.  As
// such, the default core service will be constructed and a fatal message
// shall be generated.
//
// If the core state is past ~UVM_CORE_PRE_INIT~, and ~cs~ is a non-null core 
// service instance different than the value passed to the first <uvm_init> call, 
// then the library will generate a warning message to alert the user that this 
// call to <uvm_init> is being ignored.
//
// @uvm-contrib This API represents a potential contribution to IEEE 1800.2
  
// @uvm-ieee 1800.2-2020 auto F.3.1.3
void uvm_init() {
  uvm_root top = uvm_root.get();
  // These next calls were moved to uvm_init from uvm_root,
  // because they could emit messages, resulting in the
  // report server being queried, which causes uvm_init.
  top.report_header();
  top.m_check_uvm_field_flag_size();
  // This sets up the global verbosity. Other command line args may
  // change individual component verbosity.
  top.m_check_verbosity();
    
  m_uvm_core_state = uvm_core_state.UVM_CORE_INITIALIZED;
}

//----------------------------------------------------------------------------
//
// Function -- NODOCS -- uvm_bits_to_string
//
// Converts an input bit-vector to its string equivalent. Max bit-vector
// length is approximately 14000 characters.
//----------------------------------------------------------------------------

string uvm_bits_to_string(bstr str) {
  char[] uvm_bits_to_string_;
  str.toArray(uvm_bits_to_string_);
  return cast (string) uvm_bits_to_string_;
}


//----------------------------------------------------------------------------
//
// Task: uvm_wait_for_nba_region
//
// This task will block until SystemVerilog's NBA region (or Re-NBA region if 
// called from a program context).  The purpose is to continue the calling 
// process only after allowing other processes any number of delta cycles (#0) 
// to settle out.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
//----------------------------------------------------------------------------

// eUVM does not used uvm_wait_for_nba_region -- it instead defines
// method wait_for_nba_region in uvm_phase class and uses that. This
// is done for the following reasons:
// 1. This function is used in uvm_phase class only
// 2. The function instantiates a Signal, which can be made an element
// of the uvm_phase class, thus doing away with creating the Signal
// object every time the function is called. Note that in SV global
// functions have static scoping by default


enum size_t UVM_POUND_ZERO_COUNT=1;
void uvm_wait_for_nba_region() {
  version (UVM_NO_WAIT_FOR_NBA) {
    // repeat(UVM_POUND_ZERO_COUNT) #0;
    for (size_t i=0; i!=UVM_POUND_ZERO_COUNT; ++i) {
      wait(0);
    }
  }
  else {
    import esdl.base.core: Signal, wait;

    // These are not declared static in the SV version
    static Signal!int nba;
    static int next_nba;

    // if (nba is null) nba = new Signal!int;

    //If `included directly in a program block, can't use a non-blocking assign,
    //but it isn't needed since program blocks are in a separate region.
    next_nba++;
    nba = next_nba;
    wait(nba);
  }
}


//----------------------------------------------------------------------------
//
// Function -- NODOCS -- uvm_string_split
//
// Returns a queue of strings, ~values~, that is the result of the ~str~ split
// based on the ~sep~.  For example:
//
//| uvm_string_split("1,on,false", ",", splits);
//
// Results in the 'splits' queue containing the three elements: 1, on and
// false.
//----------------------------------------------------------------------------

void uvm_string_split (string str, char sep, out string[] values) {
  int s = 0;
  int e = 0;

  size_t limit = str.length + 1;
  
  do {
      for (s=e; e < str.length; ++e)
        if (str[e] == sep) break;
      values ~= str[s..e];
      e += 1;
  }
  while(e < limit);
}

string[] uvm_string_split (string str, char sep) {
  string[] values;
  int s = 0;
  int e = 0;

  size_t limit = str.length + 1;
  
  do {
      for (s=e; e < str.length; ++e)
        if (str[e] == sep) break;
      values ~= str[s..e];
      e += 1;
  }
  while(e < limit);
  return values;
}



// Class -- NODOCS -- uvm_enum_wrapper#(T)
//
// The ~uvm_enum_wrapper#(T)~ class is a utility mechanism provided
// as a convenience to the end user.  It provides a <from_name>
// method which is the logical inverse of the System Verilog ~name~
// method which is built into all enumerations.

// No synchronized blocks required since all data is thread local
// all functions are static
// @uvm-ieee 1800.2-2020 auto F.3.4.1
struct uvm_enum_wrapper(T) if (is (T == enum))
{
  alias this_type = uvm_enum_wrapper!T;

  private static T[string] _map;

  // @uvm-ieee 1800.2-2020 auto F.3.4.2
  static bool from_name(string name, ref T value) {
    if (_map.length == 0)
	m_init_map();

    if (name in _map) {
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
    foreach (e; EnumMembers!T) {
	_map[e.to!string] = e;
    }
  }
}
