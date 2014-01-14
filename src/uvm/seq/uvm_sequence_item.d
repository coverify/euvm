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

// typedef class uvm_sequence_base;
// typedef class uvm_sequencer_base;


//------------------------------------------------------------------------------
//
// CLASS: uvm_sequence_item
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
import uvm.base.uvm_transaction;
import uvm.base.uvm_registry;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_root;

import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequencer_base;
import esdl.data.queue;

import uvm.meta.misc;

class uvm_sequence_item: uvm_transaction
{
  mixin(uvm_sync!uvm_sequence_item);

  private    int                _m_sequence_id = -1;
  protected  bool               _m_use_sequence_info;
  protected  int                _m_depth = -1;
  @uvm_protected_sync protected uvm_sequencer_base _m_sequencer;
  @uvm_protected_sync protected uvm_sequence_base  _m_parent_sequence;

  // issued1 and issued2 seem redundant -- declared in SV version though
  // static     bool               issued1,issued2;

  @uvm_public_sync private bool                  _print_sequence_info;


  // Function: new
  //
  // The constructor method for uvm_sequence_item.

  this(string name = "uvm_sequence_item") {
    super(name);
  }

  override public string get_type_name() {
    return "uvm_sequence_item";
  }

  // Macro for factory creation
  // `uvm_object_registry(uvm_sequence_item, "uvm_sequence_item")

  alias uvm_object_registry!(uvm_sequence_item, "uvm_sequence_item") type_id;
  public static type_id get_type() {
    return type_id.get();
  }
  // overridable
  override public uvm_object_wrapper get_object_type() {
    return type_id.get();
  }


  // Function- set_sequence_id

  public void set_sequence_id(int id) {
    synchronized(this) {
      _m_sequence_id = id;
    }
  }


  // Function: get_sequence_id
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
  // initiates communication through any sequencer calls (i.e. `uvm_do_xxx,
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

  public int get_sequence_id() {
    synchronized(this) {
      return _m_sequence_id;
    }
  }


  // Function: set_item_context
  //
  // Set the sequence and sequencer execution context for a sequence item

  public void set_item_context(uvm_sequence_base parent_seq,
			       uvm_sequencer_base sequencer = null) {
    synchronized(this) {
      set_use_sequence_info(true);
      if (parent_seq !is null) set_parent_sequence(parent_seq);
      if (sequencer is null && _m_parent_sequence !is null) sequencer = _m_parent_sequence.get_sequencer();
      set_sequencer(sequencer);
      if (_m_parent_sequence !is null) set_depth(_m_parent_sequence.get_depth() + 1);
      reseed();
    }
  }


  // Function: set_use_sequence_info
  //

  public void set_use_sequence_info(bool value) {
    synchronized(this) {
      _m_use_sequence_info = value;
    }
  }


  // Function: get_use_sequence_info
  //
  // These methods are used to set and get the status of the use_sequence_info
  // bit. Use_sequence_info controls whether the sequence information
  // (sequencer, parent_sequence, sequence_id, etc.) is printed, copied, or
  // recorded. When use_sequence_info is the default value of 0, then the
  // sequence information is not used. When use_sequence_info is set to 1,
  // the sequence information will be used in printing and copying.

  public bool get_use_sequence_info() {
    synchronized(this) {
      return _m_use_sequence_info;
    }
  }



  // Function: set_id_info
  //
  // Copies the sequence_id and transaction_id from the referenced item into
  // the calling item.  This routine should always be used by drivers to
  // initialize responses for future compatibility.

  public void set_id_info(uvm_sequence_item item) {
    if (item is null) {
      uvm_report_fatal(get_full_name(), "set_id_info called with null parameter", UVM_NONE);
    }
    this.set_transaction_id(item.get_transaction_id());
    this.set_sequence_id(item.get_sequence_id());
  }


  // Function: set_sequencer
  //
  // Sets the default sequencer for the sequence to sequencer.  It will take
  // effect immediately, so it should not be called while the sequence is
  // actively communicating with the sequencer.

  public void set_sequencer(uvm_sequencer_base sequencer) {
    synchronized(this) {
      _m_sequencer = sequencer;
      m_set_p_sequencer();
    }
  }


  // Function: get_sequencer
  //
  // Returns a reference to the default sequencer used by this sequence.

  public uvm_sequencer_base get_sequencer() {
    synchronized(this) {
      return _m_sequencer;
    }
  }


  // Function: set_parent_sequence
  //
  // Sets the parent sequence of this sequence_item.  This is used to identify
  // the source sequence of a sequence_item.

  public void set_parent_sequence(uvm_sequence_base parent) {
    synchronized(this) {
      _m_parent_sequence = parent;
    }
  }


  // Function: get_parent_sequence
  //
  // Returns a reference to the parent sequence of any sequence on which this
  // method was called. If this is a parent sequence, the method returns null.

  public uvm_sequence_base get_parent_sequence() {
    synchronized(this) {
      return _m_parent_sequence;
    }
  }


  // Function: set_depth
  //
  // The depth of any sequence is calculated automatically.  However, the user
  // may use  set_depth to specify the depth of a particular sequence. This
  // method will override the automatically calculated depth, even if it is
  // incorrect.

  public void set_depth(int value) {
    synchronized(this) {
      _m_depth = value;
    }
  }


  // Function: get_depth
  //
  // Returns the depth of a sequence from it's parent.  A  parent sequence will
  // have a depth of 1, it's child will have a depth  of 2, and it's grandchild
  // will have a depth of 3.

  public int get_depth() {
    synchronized(this) {
      // If depth has been set or calculated, then use that
      if (_m_depth !is -1) {
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


  // Function: is_item
  //
  // This function may be called on any sequence_item or sequence. It will
  // return 1 for items and 0 for sequences (which derive from this class).

  public bool is_item() {
    return true;
  }


  // Function- get_full_name
  //
  // Internal method; overrides must follow same naming convention

  override public string get_full_name() {
    synchronized(this) {
      string retval;
      if(_m_parent_sequence !is null) {
	retval = _m_parent_sequence.get_full_name() ~ ".";
      }
      else if(_m_sequencer !is null) {
	retval = _m_sequencer.get_full_name() ~ ".";
      }
      if(get_name() != "") {
	retval ~= get_name();
      }
      else {
	retval ~= "_item";
      }
      return retval;
    }
  }


  // Function: get_root_sequence_name
  //
  // Provides the name of the root sequence (the top-most parent sequence).

  public string get_root_sequence_name() {
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

  public void m_set_p_sequencer() {
    return;
  }


  // Function: get_root_sequence
  //
  // Provides a reference to the root sequence (the top-most parent sequence).

  public uvm_sequence_base get_root_sequence() {
    uvm_sequence_base root_seq;
    uvm_sequence_item root_seq_base = this;
    while(true) {
      if(root_seq_base.get_parent_sequence() !is null) {
	root_seq_base = root_seq_base.get_parent_sequence();
	root_seq = cast(uvm_sequence_base) root_seq_base;
      }
      else {
	return root_seq;
      }
    }
  }


  // Function: get_sequence_path
  //
  // Provides a string of names of each sequence in the full hierarchical
  // path. A "." is used as the separator between each sequence.

  public string get_sequence_path() {
    uvm_sequence_item this_item = this;
    string seq_path = this.get_name();
    while(true) {
      if(this_item.get_parent_sequence() !is null) {
	this_item = this_item.get_parent_sequence();
	seq_path = this_item.get_name() ~ "." ~ seq_path;
      }
      else {
	return seq_path;
      }
    }
  }


  //---------------------------
  // Group: Reporting Interface
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
  protected string _m_client_str;
  protected uvm_report_object _m_client;
  protected uvm_report_handler _m_rh;

  public string m_get_client_info(out uvm_report_object client) {
    synchronized(this) {
      if(_m_client_str != "") {
	client = _m_client;
	return _m_client_str;
      }
      if(_m_sequencer !is null) {
	_m_client = _m_sequencer;
      }
      else {
	_m_client = uvm_root.get();
      }
      _m_rh = _m_client.get_report_handler();
      client = _m_client;

      _m_client_str = client.get_full_name();
      if(_m_client_str == "") {
	_m_client_str = "reporter@@" ~ get_sequence_path();
      }
      else {
	_m_client_str ~= "@@" ~ get_sequence_path();
      }
      return _m_client_str;
    }
  }

  // Function: uvm_report_info

  public void uvm_report_info(string id,
			      string message,
			      int verbosity = UVM_MEDIUM,
			      string filename = "",
			      int line = 0) {
    synchronized(this) {
      uvm_report_object client;
      string str = m_get_client_info(client);

      _m_rh.report(UVM_INFO, str, id, message, verbosity, filename,
		   line, client);
    }
  }

  // Function: uvm_report_warning

  public void uvm_report_warning(string id,
				 string message,
				 int verbosity = UVM_MEDIUM,
				 string filename = "",
				 int line = 0) {
    synchronized(this) {
      uvm_report_object client;
      string str = m_get_client_info(client);

      _m_rh.report(UVM_WARNING, str, id, message, verbosity, filename,
		   line, client);
    }
  }

  // Function: uvm_report_error

  public void uvm_report_error(string id,
			       string message,
			       int verbosity = UVM_LOW,
			       string filename = "",
			       int line = 0) {
    synchronized(this) {
      uvm_report_object client;
      string str = m_get_client_info(client);

      _m_rh.report(UVM_ERROR, str, id, message, verbosity, filename,
		   line, client);
    }
  }

  // Function: uvm_report_fatal
  //
  // These are the primary reporting methods in the UVM. uvm_sequence_item
  // derived types delegate these functions to their associated sequencer
  // if they have one, or to the global reporter. See <uvm_report_object::Reporting>
  // for details on the messaging functions.

  public void uvm_report_fatal(string id,
			       string message,
			       int verbosity = UVM_NONE,
			       string filename = "",
			       int line = 0) {
    synchronized(this) {
      uvm_report_object client;
      string str = m_get_client_info(client);

      _m_rh.report(UVM_FATAL, str, id, message, verbosity, filename,
		   line, client);
    }
  }


  public bool uvm_report_enabled(int verbosity,
				 uvm_severity severity = UVM_INFO, string id = "") {
    synchronized(this) {
      if(_m_client is null) {
	if(_m_sequencer !is null) _m_client = _m_sequencer;
	else _m_client = uvm_root.get();
      }
      if (_m_client.get_report_verbosity_level(severity, id) < verbosity ||
	  _m_client.get_report_action(severity,id) is UVM_NO_ACTION) {
	return false;
      }
      else {
	return true;
      }
    }
  }


  // Function- do_print
  //
  // Internal method

  override public void do_print (uvm_printer printer) {
    synchronized(this) {
      string temp_str0, temp_str1;
      int depth = get_depth();
      super.do_print(printer);
      if(_print_sequence_info || _m_use_sequence_info) {
	printer.print_int("depth", depth, UVM_DEC, '.', "int");
	if(_m_parent_sequence !is null) {
	  temp_str0 = _m_parent_sequence.get_name();
	  temp_str1 = _m_parent_sequence.get_full_name();
	}
	printer.print_string("parent sequence (name)", temp_str0);
	printer.print_string("parent sequence (full name)", temp_str1);
	temp_str1 = "";
	if(_m_sequencer !is null) {
	  temp_str1 = _m_sequencer.get_full_name();
	}
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
