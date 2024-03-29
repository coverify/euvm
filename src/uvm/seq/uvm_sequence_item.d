//----------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2012 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2014 Cisco Systems, Inc.
// Copyright 2007-2020 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2010-2013 Synopsys, Inc.
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

// typedef class uvm_sequence_base;
// typedef class uvm_sequencer_base;


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_sequence_item
//
// The base class for user-defined sequence items and also the base class for
// the uvm_sequence class. The uvm_sequence_item class provides the basic
// functionality for objects, both sequence items and sequences, to operate in
// the sequence mechanism.
//
//------------------------------------------------------------------------------

module uvm.seq.uvm_sequence_item;
import uvm.base.uvm_factory;
import uvm.base.uvm_printer;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals: uvm_report_intf;
import uvm.base.uvm_transaction;
import uvm.base.uvm_registry;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_message;

import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequencer_base;
import uvm.meta.misc;
import uvm.meta.meta;
import esdl.data.queue;
import esdl.rand.misc: rand;

// version(UVM_NO_RAND) {}
//  else {
//    import esdl.rand;
//  }

// @uvm-ieee 1800.2-2020 auto 14.1.1
class uvm_sequence_item: uvm_transaction, uvm_report_intf, rand.barrier
{
  mixin(uvm_sync_string);

  // version(UVM_NO_RAND) {}
  // else {
  //   mixin Randomization;
  // }
  
  private int  _m_sequence_id = -1;
  @uvm_protected_sync
  private bool _m_use_sequence_info;
  @uvm_protected_sync
  private int  _m_depth = -1;

  version(UVM_NO_RAND) {
    @uvm_protected_sync
      protected uvm_sequencer_base _m_sequencer;
    @uvm_protected_sync
      protected uvm_sequence_base  _m_parent_sequence;
  }
  else {
    @uvm_protected_sync
      protected uvm_sequencer_base _m_sequencer;
    @uvm_protected_sync
      protected uvm_sequence_base  _m_parent_sequence;
  }

  // issued1 and issued2 seem redundant -- declared in SV version though
  // static     bool               issued1,issued2;

  @uvm_public_sync
  private bool _print_sequence_info;


  // Function -- NODOCS -- new
  //
  // The constructor method for uvm_sequence_item.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.1
  this(string name = "uvm_sequence_item") {
    super(name);
  }

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  // Macro for factory creation
  // `uvm_object_registry(uvm_sequence_item, "uvm_sequence_item")

  alias type_id = uvm_object_registry!(uvm_sequence_item);

  static type_id get_type() {
    return type_id.get();
  }
  // overridable
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
  }


  // Function- set_sequence_id

  void set_sequence_id(int id) {
    synchronized (this) {
      _m_sequence_id = id;
    }
  }


  // Function -- NODOCS -- get_sequence_id
  //
  // private
  //
  // Get_sequence_id is an internal method that is not intended for user code.
  // The sequence_id is not a simple integer.  The get_transaction_id is meant
  // for users to identify specific transactions.
  //
  // These methods allow access to the sequence_item sequence and transaction
  // IDs. get_transaction_id and set_transaction_id are methods on the
  // uvm_transaction base_class. These IDs are used to identify sequences to
  // the sequencer, to route responses back to the sequence that issued a
  // request, and to uniquely identify transactions.
  //
  // The sequence_id is assigned automatically by a sequencer when a sequence
  // initiates communication through any sequencer calls (i.e. `uvm_do_*,
  // wait_for_grant).  A sequence_id will remain unique for this sequence
  // until it ends or it is killed.  However, a single sequence may have
  // multiple valid sequence ids at any point in time.  Should a sequence
  // start again after it has ended, it will be given a new unique sequence_id.
  //
  // The transaction_id is assigned automatically by the sequence each time a
  // transaction is sent to the sequencer with the transaction_id in its
  // default (-1) value.  If the user sets the transaction_id to any non-default
  // value, that value will be maintained.
  //
  // Responses are routed back to this sequences based on sequence_id. The
  // sequence may use the transaction_id to correlate responses with their
  // requests.

  int get_sequence_id() {
    synchronized (this) {
      return _m_sequence_id;
    }
  }


  // Function -- NODOCS -- set_item_context
  //
  // Set the sequence and sequencer execution context for a sequence item

  // @uvm-ieee 1800.2-2020 auto 14.1.2.2
  void set_item_context(uvm_sequence_base parent_seq,
			uvm_sequencer_base sequencer = null) {
    synchronized (this) {
      set_use_sequence_info(true);
      if (parent_seq !is null) set_parent_sequence(parent_seq);
      if (sequencer is null && _m_parent_sequence !is null) {
	sequencer = _m_parent_sequence.get_sequencer();
      }
      set_sequencer(sequencer);
      if (_m_parent_sequence !is null) {
	set_depth(_m_parent_sequence.get_depth() + 1);
      }
      reseed();
    }
  }


  // Function -- NODOCS -- set_use_sequence_info
  //

  // @uvm-ieee 1800.2-2020 auto 14.1.2.3
  void set_use_sequence_info(bool value) {
    synchronized (this) {
      _m_use_sequence_info = value;
    }
  }


  // Function -- NODOCS -- get_use_sequence_info
  //
  // These methods are used to set and get the status of the use_sequence_info
  // bit. Use_sequence_info controls whether the sequence information
  // (sequencer, parent_sequence, sequence_id, etc.) is printed, copied, or
  // recorded. When use_sequence_info is the default value of 0, then the
  // sequence information is not used. When use_sequence_info is set to 1,
  // the sequence information will be used in printing and copying.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.3
  bool get_use_sequence_info() {
    synchronized (this) {
      return _m_use_sequence_info;
    }
  }



  // Function -- NODOCS -- set_id_info
  //
  // Copies the sequence_id and transaction_id from the referenced item into
  // the calling item.  This routine should always be used by drivers to
  // initialize responses for future compatibility.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.4
  void set_id_info(uvm_sequence_item item) {
    synchronized (this) {
      if (item is null) {
	uvm_report_fatal(get_full_name(),
			 "set_id_info called with null parameter", uvm_verbosity.UVM_NONE);
      }
      this.set_transaction_id(item.get_transaction_id());
      this.set_sequence_id(item.get_sequence_id());
    }
  }


  // Function -- NODOCS -- set_sequencer
  //
  // Sets the default sequencer for the sequence to sequencer.  It will take
  // effect immediately, so it should not be called while the sequence is
  // actively communicating with the sequencer.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.6
  void set_sequencer(uvm_sequencer_base sequencer) {
    synchronized (this) {
      _m_sequencer = sequencer;
      m_set_p_sequencer();
    }
  }


  // Function -- NODOCS -- get_sequencer
  //
  // Returns a reference to the default sequencer used by this sequence.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.5
  uvm_sequencer_base get_sequencer() {
    synchronized (this) {
      return _m_sequencer;
    }
  }


  // Function -- NODOCS -- set_parent_sequence
  //
  // Sets the parent sequence of this sequence_item.  This is used to identify
  // the source sequence of a sequence_item.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.8
  void set_parent_sequence(uvm_sequence_base parent) {
    synchronized (this) {
      _m_parent_sequence = parent;
    }
  }


  // Function -- NODOCS -- get_parent_sequence
  //
  // Returns a reference to the parent sequence of any sequence on which this
  // method was called. If this is a parent sequence, the method returns ~null~.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.7
  uvm_sequence_base get_parent_sequence() {
    synchronized (this) {
      return _m_parent_sequence;
    }
  }


  // Function -- NODOCS -- set_depth
  //
  // The depth of any sequence is calculated automatically.  However, the user
  // may use  set_depth to specify the depth of a particular sequence. This
  // method will override the automatically calculated depth, even if it is
  // incorrect.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.10
  void set_depth(int value) {
    synchronized (this) {
      _m_depth = value;
    }
  }


  // Function -- NODOCS -- get_depth
  //
  // Returns the depth of a sequence from its parent.  A  parent sequence will
  // have a depth of 1, its child will have a depth  of 2, and its grandchild
  // will have a depth of 3.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.9
  int get_depth() {
    synchronized (this) {
      // If depth has been set or calculated, then use that
      if (_m_depth != -1) {
	return (_m_depth);
      }
      // Calculate the depth, store it, and return the value
      if (_m_parent_sequence is null) {
	_m_depth = 1;
      }
      else {
	_m_depth = _m_parent_sequence.get_depth() + 1;
      }
      return (_m_depth);
    }
  }


  // Function -- NODOCS -- is_item
  //
  // This function may be called on any sequence_item or sequence. It will
  // return 1 for items and 0 for sequences (which derive from this class).

  // @uvm-ieee 1800.2-2020 auto 14.1.2.11
  bool is_item() {
    return true;
  }


  // Function- get_full_name
  //
  // Internal method; overrides must follow same naming convention

  override string get_full_name() {
    string get_full_name_;
    uvm_sequence_base parent_sequence;
    uvm_sequencer_base sequencer;
    synchronized (this) {
      parent_sequence = _m_parent_sequence;
      sequencer = _m_sequencer;
    }
    if (parent_sequence !is null) {
      get_full_name_ = parent_sequence.get_full_name() ~ ".";
    }
    else if (sequencer !is null) {
      get_full_name_ = m_sequencer.get_full_name() ~ ".";
    }
    if (get_name() != "") {
      get_full_name_ ~= get_name();
    }
    else {
      get_full_name_ ~= "_item";
    }
    return get_full_name_;
  }


  // Function -- NODOCS -- get_root_sequence_name
  //
  // Provides the name of the root sequence (the top-most parent sequence).

  // @uvm-ieee 1800.2-2020 auto 14.1.2.12
  string get_root_sequence_name() {
    uvm_sequence_base root_seq = get_root_sequence();
    if (root_seq is null) {
      return "";
    }
    else {
      return root_seq.get_name();
    }
  }

  // Function- m_set_p_sequencer
  //
  // Internal method

  void m_set_p_sequencer() {
    return;
  }


  // Function -- NODOCS -- get_root_sequence
  //
  // Provides a reference to the root sequence (the top-most parent sequence).

  // @uvm-ieee 1800.2-2020 auto 14.1.2.13
  uvm_sequence_base get_root_sequence() {
    uvm_sequence_base root_seq;
    uvm_sequence_item root_seq_base = this;
    while (true) {
      if (root_seq_base.get_parent_sequence() !is null) {
	root_seq_base = root_seq_base.get_parent_sequence();
	root_seq = cast (uvm_sequence_base) root_seq_base;
      }
      else {
	return root_seq;
      }
    }
  }


  // Function -- NODOCS -- get_sequence_path
  //
  // Provides a string of names of each sequence in the full hierarchical
  // path. A "." is used as the separator between each sequence.

  // @uvm-ieee 1800.2-2020 auto 14.1.2.14
  string get_sequence_path() {
    uvm_sequence_item this_item = this;
    string seq_path = this.get_name();
    while (true) {
      if (this_item.get_parent_sequence() !is null) {
	this_item = this_item.get_parent_sequence();
	seq_path = this_item.get_name() ~ "." ~ seq_path;
      }
      else {
	return seq_path;
      }
    }
  }


  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Reporting
  //----------------------------------------------------------------------------

  // mixin uvm_report_mixin;

  //---------------------------
  // Group -- NODOCS -- Reporting Interface
  //---------------------------
  //
  // Sequence items and sequences will use the sequencer which they are
  // associated with for reporting messages. If no sequencer has been set
  // for the item/sequence using <set_sequencer> or indirectly via
  // <uvm_sequence_base::start_item> or <uvm_sequence_base::start>),
  // then the global reporter will be used.

  // The sequence path string is an on-demand string. To avoid building this name
  // information continuously, we save the info here. The m_get_client_info function
  // should only be called for a message that has passed the is_enabled check,
  // e.g. from the `uvm_info macro.

  // @uvm-ieee 1800.2-2020 auto 14.1.3.1
  uvm_report_object uvm_get_report_object() {
    synchronized (this) {
      import uvm.base.uvm_coreservice;
      if (_m_sequencer is null) {
	uvm_coreservice_t cs = uvm_coreservice_t.get();
	return cs.get_root();
      }
      else {
	return _m_sequencer;
      }
    }
  }

  // @uvm-ieee 1800.2-2020 auto 14.1.3.2
  bool uvm_report_enabled(int verbosity, 
			  uvm_severity severity=uvm_severity.UVM_INFO,
			  string id="") {
    synchronized (this) {
      uvm_report_object l_report_object = uvm_get_report_object();
      if (l_report_object.get_report_verbosity_level(severity, id) <
	 verbosity) {
	return false;
      }
      return true;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 14.1.3.3
  void uvm_report(string file = __FILE__,
		  size_t line = __LINE__)
    (uvm_severity severity,
     string id,
     lazy string message,
     int verbosity =
     (severity == uvm_severity.UVM_ERROR) ? uvm_verbosity.UVM_NONE :
     (severity == uvm_severity.UVM_FATAL) ? uvm_verbosity.UVM_NONE :
     (severity == uvm_severity.UVM_WARNING) ? uvm_verbosity.UVM_NONE :
     uvm_verbosity.UVM_MEDIUM,
     string context_name = "",
     bool report_enabled_checked = false) {
    uvm_report(severity, id, message, verbosity, file,
	       line, context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report
  void uvm_report( uvm_severity severity,
		   string id,
		   lazy string message,
		   int verbosity,
		   string filename,
		   size_t line,
		   string context_name = "",
		   bool report_enabled_checked = false) {
    if ((severity == uvm_severity.UVM_INFO) &&
	(report_enabled_checked == false)) {
      if (!uvm_report_enabled(verbosity, severity, id)) {
	return;
      }
    }
    uvm_report_message l_report_message =
      uvm_report_message.new_report_message();
    l_report_message.set_report_message(severity, id, message, 
					verbosity, filename, line,
					context_name);
    uvm_process_report_message(l_report_message);
  }

  // Function -- NODOCS -- uvm_report_trace

  void uvm_report_trace(string file = __FILE__,
			size_t line = __LINE__)( string id,
						 lazy string message,
						 int verbosity = uvm_verbosity.UVM_MEDIUM,
						 string context_name = "",
						 bool report_enabled_checked = false) {

    this.uvm_report_trace(id, message, verbosity, file, line,
			  context_name, report_enabled_checked);
  }

  void uvm_report_trace( string id,
			 lazy string message,
			 int verbosity,
			 string filename,
			 size_t line,
			 string context_name = "",
			 bool report_enabled_checked = false) {

    this.uvm_report(uvm_severity.UVM_TRACE, id, message, verbosity, filename, line,
                    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report_info

  // @uvm-ieee 1800.2-2020 auto 14.1.3.3
  void uvm_report_info(string file = __FILE__,
		       size_t line = __LINE__)( string id,
						lazy string message,
						int verbosity = uvm_verbosity.UVM_MEDIUM,
						string context_name = "",
						bool report_enabled_checked = false) {

    this.uvm_report_info(id, message, verbosity, file, line,
			 context_name, report_enabled_checked);
  }

  void uvm_report_info( string id,
			lazy string message,
			int verbosity,
			string filename,
			size_t line,
			string context_name = "",
			bool report_enabled_checked = false) {

    this.uvm_report(uvm_severity.UVM_INFO, id, message, verbosity, filename, line,
                    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report_warning

  // @uvm-ieee 1800.2-2020 auto 14.1.3.3
  void uvm_report_warning(string file = __FILE__,
			  size_t line = __LINE__)( string id,
						   lazy string message,
						   int verbosity = uvm_verbosity.UVM_NONE,
						   string context_name = "",
						   bool report_enabled_checked = false) {

    this.uvm_report_warning(id, message, verbosity, file, line,
			    context_name, report_enabled_checked);
  }

  void uvm_report_warning( string id,
			   lazy string message,
			   int verbosity,
			   string filename,
			   size_t line,
			   string context_name = "",
			   bool report_enabled_checked = false) {

    this.uvm_report(uvm_severity.UVM_WARNING, id, message, verbosity, filename, line,
                    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report_error

  // @uvm-ieee 1800.2-2020 auto 14.1.3.3
  void uvm_report_error(string file = __FILE__,
			size_t line = __LINE__)( string id,
						 lazy string message,
						 int verbosity=uvm_verbosity.UVM_NONE,
						 string context_name = "",
						 bool report_enabled_checked = false) {

    this.uvm_report_error(id, message, verbosity, file, line,
			  context_name, report_enabled_checked);
  }

  void uvm_report_error( string id,
			 lazy string message,
			 int verbosity = uvm_verbosity.UVM_LOW,
			 string filename = "",
			 size_t line = 0,
			 string context_name = "",
			 bool report_enabled_checked = false) {
    this.uvm_report(uvm_severity.UVM_ERROR, id, message, verbosity, filename, line,
                    context_name, report_enabled_checked);
  }

  // Function -- NODOCS -- uvm_report_fatal
  //
  // These are the primary reporting methods in the UVM. uvm_sequence_item
  // derived types delegate these functions to their associated sequencer
  // if they have one, or to the global reporter. See <uvm_report_object::Reporting>
  // for details on the messaging functions.

  // @uvm-ieee 1800.2-2020 auto 14.1.3.3
  void uvm_report_fatal(string file = __FILE__,
			size_t line = __LINE__)( string id,
						 lazy string message,
						 int verbosity = uvm_verbosity.UVM_NONE,
						 string context_name = "",
						 bool report_enabled_checked = false) {

    this.uvm_report_fatal(id, message, verbosity, file, line,
			  context_name, report_enabled_checked);
  }

  void uvm_report_fatal( string id,
			 lazy string message,
			 int verbosity,
			 string filename,
			 size_t line,
			 string context_name = "",
			 bool report_enabled_checked = false) {
    this.uvm_report(uvm_severity.UVM_FATAL, id, message, verbosity, filename, line,
                    context_name, report_enabled_checked);
  }

  // @uvm-ieee 1800.2-2020 auto 14.1.3.4
  void uvm_process_report_message (uvm_report_message report_message) {
    uvm_report_object l_report_object = uvm_get_report_object();
    report_message.set_report_object(l_report_object);
    if (report_message.get_context() == "") {
      report_message.set_context(get_sequence_path());
    }
    l_report_object.m_rh.process_report_message(report_message);
  }

  // Function- do_print
  //
  // Internal method

  override void do_print (uvm_printer printer) {
    super.do_print(printer);
    bool print_seq;
    uvm_sequence_base parent_sequence;
    uvm_sequencer_base sequencer;
    synchronized (this) {
      print_seq = _print_sequence_info || _m_use_sequence_info;
      parent_sequence = _m_parent_sequence;
      sequencer = _m_sequencer;
    }
    if (print_seq) {
      int depth = get_depth();
      string temp_str0, temp_str1;
      printer.print("depth", depth, uvm_radix_enum.UVM_DEC, '.', "int");
      if (parent_sequence !is null) {
	temp_str0 = parent_sequence.get_name();
	temp_str1 = parent_sequence.get_full_name();
	printer.print_string("parent sequence (name)", temp_str0);
	printer.print_string("parent sequence (full name)", temp_str1);
      }
      temp_str1 = "";
      if (sequencer !is null) {
	temp_str1 = sequencer.get_full_name();
	printer.print_string("sequencer", temp_str1);
      }
    }
  }

  /*
    virtual task pre_do(bit is_item);
    return;
    endtask

    virtual task body();
    return;
    endtask

    virtual function void mid_do(uvm_sequence_item this_item);
    return;
    endfunction

    virtual function void post_do(uvm_sequence_item this_item);
    return;
    endfunction

    virtual task wait_for_grant(int item_priority = -1, bit  lock_request = 0);
    return;
    endtask

    virtual function void send_request(uvm_sequence_item request, bit rerandomize = 0);
    return;
    endfunction

    virtual task wait_for_item_done(int transaction_id = -1);
    return;
    endtask
  */

}
