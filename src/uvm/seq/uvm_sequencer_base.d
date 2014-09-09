//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
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

module uvm.seq.uvm_sequencer_base;
import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequence_base;
import uvm.base.uvm_component;
import uvm.base.uvm_config_db;
import uvm.base.uvm_factory;
import uvm.base.uvm_message_defines;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_globals;
import uvm.base.uvm_phase;
import uvm.base.uvm_domain;
import uvm.base.uvm_printer;
import uvm.base.uvm_misc;
import uvm.meta.misc;

import esdl.data.rand;
import esdl.data.queue;
import esdl.base.core;
import std.random: uniform;
import std.algorithm: filter;
import std.string: format;

alias uvm_config_db!uvm_sequence_base uvm_config_seq;
// typedef class uvm_sequence_request;


//------------------------------------------------------------------------------
//
// CLASS: uvm_sequencer_base
//
// Controls the flow of sequences, which generate the stimulus (sequence item
// transactions) that is passed on to drivers for execution.
//
//------------------------------------------------------------------------------

class uvm_once_sequencer_base
{
  @uvm_private_sync private int _g_request_id;
  @uvm_private_sync private int _g_sequence_id = 1;
  @uvm_private_sync private int _g_sequencer_id = 1;
}

class uvm_sequencer_base: uvm_component
{
  mixin(uvm_once_sync!uvm_once_sequencer_base);
  mixin(uvm_sync!uvm_sequencer_base);

  mixin uvm_component_utils;

  static inc_g_request_id() {
    synchronized(_once) {
      return _once._g_request_id++;
    }
  }

  static inc_g_sequence_id() {
    synchronized(_once) {
      return _once._g_sequence_id++;
    }
  }

  static inc_g_sequencer_id() {
    synchronized(_once) {
      return _once._g_sequencer_id++;
    }
  }

  // make sure that all accesses to _arb_sequence_q are made under
  // synchronized(this) lock
  protected Queue!uvm_sequence_request _arb_sequence_q;

  // make sure that all accesses to _arb_completed are made under
  // synchronized(this) lock
  // declared protected in SV version
  private bool[int]                    _arb_completed;

  // make sure that all accesses to _lock_list are made under
  // synchronized(this) lock
  // declared protected in SV version
  private Queue!uvm_sequence_base      _lock_list;

  // make sure that all accesses to _reg_sequences are made under
  // synchronized(this) lock
  // declared protected in SV version
  private uvm_sequence_base[int]       _reg_sequences;

  @uvm_protected_sync private int      _m_sequencer_id;


  // declared protected in SV version
  @uvm_immutable_sync
    private WithEvent!int              _m_lock_arb_size;  // used for waiting processes
  @uvm_private_sync
    private int                        _m_arb_size;       // used for waiting processes
  @uvm_immutable_sync
    private WithEvent!int              _m_wait_for_item_sequence_id;

  @uvm_immutable_sync
    private WithEvent!int              _m_wait_for_item_transaction_id;

  private uvm_sequencer_arb_mode       _m_arbitration = SEQ_ARB_FIFO;


  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for uvm_component: name is the name of the
  // instance, and parent is the handle to the hierarchical parent.

  public this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      _m_lock_arb_size = new WithEvent!int;
      _m_is_relevant_completed = new WithEvent!bool;
      _m_wait_for_item_sequence_id = new WithEvent!int;
      _m_wait_for_item_transaction_id = new WithEvent!int;
      _m_sequencer_id = inc_g_sequencer_id();
      _m_lock_arb_size = -1;
    }
  }

  // Function: is_child
  //
  // Returns 1 if the child sequence is a child of the parent sequence,
  // 0 otherwise.
  //
  // is_child
  // --------

  final public bool is_child(uvm_sequence_base parent,
			     uvm_sequence_base child) {

    if(child is null) {
      uvm_report_fatal("uvm_sequencer", "is_child passed null child", UVM_NONE);
    }

    if (parent is null) {
      uvm_report_fatal("uvm_sequencer", "is_child passed null parent", UVM_NONE);
    }

    uvm_sequence_base child_parent = child.get_parent_sequence();
    while (child_parent !is null) {
      if (child_parent.get_inst_id() == parent.get_inst_id()) {
	return true;
      }
      child_parent = child_parent.get_parent_sequence();
    }
    return false;
  }



  // Function: user_priority_arbitration
  //
  // When the sequencer arbitration mode is set to SEQ_ARB_USER (via the
  // <set_arbitration> method), the sequencer will call this function each
  // time that it needs to arbitrate among sequences.
  //
  // Derived sequencers may override this method to perform a custom arbitration
  // policy. The override must return one of the entries from the
  // avail_sequences queue, which are indexes into an internal queue,
  // arb_sequence_q. The
  //
  // The default implementation behaves like SEQ_ARB_FIFO, which returns the
  // entry at avail_sequences[0].
  //
  // user_priority_arbitration
  // -------------------------

  static public int user_priority_arbitration(Queue!int avail_sequences) {
    return avail_sequences[0];
  }


  // Task: execute_item
  //
  // Executes the given transaction ~item~ directly on this sequencer. A temporary
  // parent sequence is automatically created for the ~item~.  There is no capability to
  // retrieve responses. If the driver returns responses, they will accumulate in the
  // sequencer, eventually causing response overflow unless
  // <set_response_queue_error_report_disabled> is called.

  // execute_item
  // ------------

  // task
  final public void execute_item(uvm_sequence_item item) {
    uvm_sequence_base seq = new uvm_sequence_base();
    item.set_sequencer(this);
    item.set_parent_sequence(seq);
    seq.set_sequencer(this);
    seq.start_item(item);
    seq.finish_item(item);
  }



  // Function: start_phase_sequence
  //
  // Start the default sequence for this phase, if any.
  // The default sequence is configured via resources using
  // either a sequence instance or sequence type (object wrapper).
  // If both are used,
  // the sequence instance takes precedence. When attempting to override
  // a previous default sequence setting, you must override both
  // the instance and type (wrapper) reources, else your override may not
  // take effect.
  //
  // When setting the resource using ~set~, the 1st argument specifies the
  // context pointer, usually "this" for components or "null" when executed from
  // outside the component hierarchy (i.e. in module).
  // The 2nd argument is the instance string, which is a path name to the
  // target sequencer, relative to the context pointer.  The path must include
  // the name of the phase with a "_phase" suffix. The 3rd argument is the
  // resource name, which is "default_sequence". The 4th argument is either
  // an object wrapper for the sequence type, or an instance of a sequence.
  //
  // Configuration by instances
  // allows pre-initialization, setting rand_mode, use of inline
  // constraints, etc.
  //
  //| myseq_t myseq = new("myseq");
  //| myseq.randomize() with { ... };
  //| uvm_config_db #(uvm_sequence_base)::set(null, "top.agent.myseqr.main_phase",
  //|                                         "default_sequence",
  //|                                         myseq);
  //
  // Configuration by type is shorter and can be substituted via the
  // the factory.
  //
  //| uvm_config_db #(uvm_object_wrapper)::set(null, "top.agent.myseqr.main_phase",
  //|                                          "default_sequence",
  //|                                          myseq_type::type_id::get());
  //
  // The uvm_resource_db can similarly be used.
  //
  //| myseq_t myseq = new("myseq");
  //| myseq.randomize() with { ... };
  //| uvm_resource_db #(uvm_sequence_base)::set({get_full_name(), ".myseqr.main_phase",
  //|                                           "default_sequence",
  //|                                           myseq, this);
  //
  //| uvm_resource_db #(uvm_object_wrapper)::set({get_full_name(), ".myseqr.main_phase",
  //|                                            "default_sequence",
  //|                                            myseq_t::type_id::get(),
  //|                                            this );
  //
  //



  // start_phase_sequence
  // --------------------

  final public void start_phase_sequence(uvm_phase phase) {
    synchronized(this) {
      uvm_object_wrapper wrapper;
      uvm_sequence_base  seq;

      // default sequence instance?
      if(!uvm_config_db!(uvm_sequence_base).get(this, phase.get_name() ~
						"_phase", "default_sequence",
						seq) || seq is null) {
	// default sequence object wrapper?
	if(uvm_config_db!(uvm_object_wrapper).get(this, phase.get_name() ~
						  "_phase", "default_sequence",
						  wrapper) && wrapper !is null) {
	  uvm_factory f = uvm_factory.get();
	  // use wrapper is a sequence type
	  seq = cast(uvm_sequence_base)
	    f.create_object_by_type(wrapper, get_full_name(),
				    wrapper.get_type_name());
	  if(seq is null) {
	    uvm_warning("PHASESEQ", "Default sequence for phase '" ~
			phase.get_name() ~ "' %s is not a sequence type");
	    return;
	  }
	}
	else {
	  uvm_info("PHASESEQ", "No default phase sequence for phase '" ~
		   phase.get_name() ~ "'", UVM_FULL);
	  return;
	}
      }

      uvm_info("PHASESEQ",
	       "Starting default sequence '" ~ seq.get_type_name() ~
	       "' for phase '" ~ phase.get_name() ~ "'", UVM_FULL);

      seq.print_sequence_info = true;
      seq.set_sequencer(this);
      seq.reseed();
      seq.starting_phase = phase;

      if (!seq.do_not_randomize && !seq.randomize()) {
	uvm_warning("STRDEFSEQ",
		    "Randomization failed for default sequence '" ~
		    seq.get_type_name() ~ "' for phase '" ~
		    phase.get_name() ~ "'");
	return;
      }

      fork({
	  // reseed this process for random stability
	  Process proc = Process.self;
	  proc.srandom(uvm_create_random_seed(seq.get_type_name(),
					      this.get_full_name()));
	  seq.start(this);
	});
    }
  }


  // Task: wait_for_grant
  //
  // This task issues a request for the specified sequence.  If item_priority
  // is not specified, then the current sequence priority will be used by the
  // arbiter.  If a lock_request is made, then the  sequencer will issue a lock
  // immediately before granting the sequence.  (Note that the lock may be
  // granted without the sequence being granted if is_relevant is not asserted).
  //
  // When this method returns, the sequencer has granted the sequence, and the
  // sequence must call send_request without inserting any simulation delay
  // other than delta cycles.  The driver is currently waiting for the next
  // item to be sent via the send_request call.

  // wait_for_grant
  // --------------

  // task
  public void wait_for_grant(uvm_sequence_base sequence_ptr,
			     int item_priority = -1,
			     bool lock_request = false) {
    uvm_sequence_request req_s;

    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequencer",
		       "wait_for_grant passed null sequence_ptr", UVM_NONE);
    }

    synchronized(this) {
      // FIXME -- decide whether this has to be under synchronized lock
      int my_seq_id = m_register_sequence(sequence_ptr);

      // If lock_request is asserted, then issue a lock.  Don't wait for the response, since
      // there is a request immediately following the lock request
      if (lock_request is true) {
	req_s = new uvm_sequence_request();
	synchronized(req_s) {
	  req_s.grant = false;
	  req_s.sequence_id = my_seq_id;
	  req_s.request = SEQ_TYPE_LOCK;
	  req_s.sequence_ptr = sequence_ptr;
	  req_s.request_id = inc_g_request_id();
	  req_s.process_id = Process.self;
	}
	_arb_sequence_q.pushBack(req_s);
      }

      // Push the request onto the queue
      req_s = new uvm_sequence_request();
      synchronized(req_s) {
	req_s.grant = false;
	req_s.request = SEQ_TYPE_REQ;
	req_s.sequence_id = my_seq_id;
	req_s.item_priority = item_priority;
	req_s.sequence_ptr = sequence_ptr;
	req_s.request_id = inc_g_request_id();
	req_s.process_id = Process.self;
      }
      _arb_sequence_q.pushBack(req_s);
      m_update_lists();
    }

    // Wait until this entry is granted
    // Continue to point to the element, since location in queue will change
    m_wait_for_arbitration_completed(req_s.request_id); // this is a task call

    // The wait_for_grant_semaphore is used only to check that send_request
    // is only called after wait_for_grant.  This is not a complete check, since
    // requests might be done in parallel, but it will catch basic errors
    req_s.sequence_ptr.inc_wait_for_grant_semaphore();
  }


  // Task: wait_for_item_done
  //
  // A sequence may optionally call wait_for_item_done.  This task will block
  // until the driver calls item_done() or put() on a transaction issued by the
  // specified sequence.  If no transaction_id parameter is specified, then the
  // call will return the next time that the driver calls item_done() or put().
  // If a specific transaction_id is specified, then the call will only return
  // when the driver indicates that it has completed that specific item.
  //
  // Note that if a specific transaction_id has been specified, and the driver
  // has already issued an item_done or put for that transaction, then the call
  // will hang waiting for that specific transaction_id.
  //
  // wait_for_item_done
  // ------------------

  // task
  public void wait_for_item_done(uvm_sequence_base sequence_ptr,
				 int transaction_id) {
    int sequence_id;
    synchronized(this) {
      sequence_id = sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, 1);
      _m_wait_for_item_sequence_id = -1;
      _m_wait_for_item_transaction_id = -1;
    }

    if (transaction_id == -1) {
      // wait (m_wait_for_item_sequence_id == sequence_id);
      while(m_wait_for_item_sequence_id.get != sequence_id) {
	m_wait_for_item_sequence_id.getEvent.wait();
      }
    }
    else {
      // wait ((m_wait_for_item_sequence_id == sequence_id &&
      //	      m_wait_for_item_transaction_id == transaction_id));

      // while((m_wait_for_item_sequence_id != sequence_id) ||
      //	     (m_wait_for_item_transaction_id != transaction_id)) {
      //	 wait(m_wait_for_item_sequence_event || m_wait_for_item_transaction_event);
      // }
      while(m_wait_for_item_sequence_id.get != sequence_id ||
	    m_wait_for_item_transaction_id.get != transaction_id) {
	wait(m_wait_for_item_sequence_id.getEvent() |
	     m_wait_for_item_transaction_id.getEvent());
      }
    }
  }



  // Function: is_blocked
  //
  // Returns 1 if the sequence referred to by sequence_ptr is currently locked
  // out of the sequencer.  It will return 0 if the sequence is currently
  // allowed to issue operations.
  //
  // Note that even when a sequence is not blocked, it is possible for another
  // sequence to issue a lock before this sequence is able to issue a request
  // or lock.
  //

  // is_blocked
  // ----------

  public bool is_blocked(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequence_controller",
		       "is_blocked passed null sequence_ptr", UVM_NONE);
    }

    synchronized(this) {
      foreach (lock; _lock_list) {
	if ((lock.get_inst_id() != sequence_ptr.get_inst_id()) &&
	    (is_child(lock, sequence_ptr) is false)) {
	  return true;
	}
      }
      return false;
    }
  }

  // Function: has_lock
  //
  // Returns 1 if the sequence refered to in the parameter currently has a lock
  // on this sequencer, 0 otherwise.
  //
  // Note that even if this sequence has a lock, a child sequence may also have
  // a lock, in which case the sequence is still blocked from issueing
  // operations on the sequencer
  //

  // has_lock
  // --------

  public bool has_lock(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequence_controller",
		       "has_lock passed null sequence_ptr", UVM_NONE);
    }
    synchronized(this) {
      // FIXME -- deadlock possibility flag
      int my_seq_id = m_register_sequence(sequence_ptr);
      foreach (lock; _lock_list) {
	if (lock.get_inst_id() == sequence_ptr.get_inst_id()) {
	  return true;
	}
      }
      return false;
    }
  }



  // Task: lock
  //
  // Requests a lock for the sequence specified by sequence_ptr.
  //
  // A lock request will be arbitrated the same as any other request. A lock is
  // granted after all earlier requests are completed and no other locks or
  // grabs are blocking this sequence.
  //
  // The lock call will return when the lock has been granted.
  //

  // lock
  // ----

  // task
  public void lock(uvm_sequence_base sequence_ptr) {
    m_lock_req(sequence_ptr, true);
  }

  // Task: grab
  //
  // Requests a lock for the sequence specified by sequence_ptr.
  //
  // A grab request is put in front of the arbitration queue. It will be
  // arbitrated before any other requests. A grab is granted when no other
  // grabs or locks are blocking this sequence.
  //
  // The grab call will return when the grab has been granted.
  //


  // grab
  // ----

  // task
  public void grab(uvm_sequence_base sequence_ptr) {
    m_lock_req(sequence_ptr, false);
  }


  // Function: unlock
  //
  // Removes any locks and grabs obtained by the specified sequence_ptr.
  //

  // unlock
  // ------

  public void unlock(uvm_sequence_base sequence_ptr) {
    m_unlock_req(sequence_ptr);
  }

  // Function: ungrab
  //
  // Removes any locks and grabs obtained by the specified sequence_ptr.
  //

  // ungrab
  // ------

  public void  ungrab(uvm_sequence_base sequence_ptr) {
    m_unlock_req(sequence_ptr);
  }

  // Function: stop_sequences
  //
  // Tells the sequencer to kill all sequences and child sequences currently
  // operating on the sequencer, and remove all requests, locks and responses
  // that are currently queued.  This essentially resets the sequencer to an
  // idle state.
  //


  // stop_sequences
  // --------------

  public void stop_sequences() { // FIXME -- find out if it would be
				 // appropriate to have a synchronized
				 // lock for this function
    synchronized(this) {
      uvm_sequence_base seq_ptr = m_find_sequence(-1);
      while (seq_ptr !is null) {
	kill_sequence(seq_ptr);
	seq_ptr = m_find_sequence(-1);
      }
    }
  }


  // Function: is_grabbed
  //
  // Returns 1 if any sequence currently has a lock or grab on this sequencer,
  // 0 otherwise.
  //

  // is_grabbed
  // ----------

  public bool is_grabbed() {
    synchronized(this) {
      return (_lock_list.length !is 0);
    }
  }


  // Function: current_grabber
  //
  // Returns a reference to the sequence that currently has a lock or grab on
  // the sequence.  If multiple hierarchical sequences have a lock, it returns
  // the child that is currently allowed to perform operations on the sequencer.
  //

  // current_grabber
  // ---------------

  public uvm_sequence_base current_grabber() {
    synchronized(this) {
      if (_lock_list.length is 0) {
	return null;
      }
      return _lock_list[$-1];
    }
  }


  // Function: has_do_available
  //
  // Returns 1 if any sequence running on this sequencer is ready to supply a
  // transaction, 0 otherwise. A sequence is ready if it is not blocked (via
  // ~grab~ or ~lock~ and ~is_relevant~ returns 1.
  //

  // has_do_available
  // ----------------

  public bool has_do_available() {
    synchronized(this) {
      foreach(arb_seq; _arb_sequence_q) {
	if ((arb_seq.sequence_ptr.is_relevant() is true) &&
	    (is_blocked(arb_seq.sequence_ptr) is false)) {
	  return true;
	}
      }
      return false;
    }
  }


  // Function: set_arbitration
  //
  // Specifies the arbitration mode for the sequencer. It is one of
  //
  // SEQ_ARB_FIFO          - Requests are granted in FIFO order (default)
  // SEQ_ARB_WEIGHTED      - Requests are granted randomly by weight
  // SEQ_ARB_RANDOM        - Requests are granted randomly
  // SEQ_ARB_STRICT_FIFO   - Requests at highest priority granted in fifo order
  // SEQ_ARB_STRICT_RANDOM - Requests at highest priority granted in randomly
  // SEQ_ARB_USER          - Arbitration is delegated to the user-defined
  //                         function, user_priority_arbitration. That function
  //                         will specify the next sequence to grant.
  //
  // The default user function specifies FIFO order.
  //

  // set_arbitration
  // ---------------

  public void set_arbitration(SEQ_ARB_TYPE val) {
    synchronized(this) {
      _m_arbitration = val;
    }
  }

  // Function: get_arbitration
  //
  // Return the current arbitration mode set for this sequencer. See
  // <set_arbitration> for a list of possible modes.
  //

  // get_arbitration
  // ---------------

  public SEQ_ARB_TYPE get_arbitration() {
    synchronized(this) {
      return _m_arbitration;
    }
  }


  // Task: wait_for_sequences
  //
  // Waits for a sequence to have a new item available. Uses
  // <uvm_wait_for_nba_region> to give a sequence as much time as
  // possible to deliver an item before advancing time.

  // wait_for_sequences
  // ------------------

  // task
  public void wait_for_sequences() {
    uvm_wait_for_nba_region();
  }


  // Function: send_request
  //
  // Derived classes implement this function to send a request item to the
  // sequencer, which will forward it to the driver.  If the rerandomize bit
  // is set, the item will be randomized before being sent to the driver.
  //
  // This function may only be called after a <wait_for_grant> call.

  // send_request
  // ------------

  public void send_request(uvm_sequence_base sequence_ptr,
			   uvm_sequence_item t,
			   bool rerandomize = false) {
    return;
  }




  //----------------------------------------------------------------------------
  // INTERNAL METHODS - DO NOT CALL DIRECTLY, ONLY OVERLOAD IF VIRTUAL
  //----------------------------------------------------------------------------

  // grant_queued_locks
  // ------------------
  // Any lock or grab requests that are at the front of the queue will be
  // granted at the earliest possible time.  This function grants any queues
  // at the front that are not locked out

  public void grant_queued_locks() {
    synchronized(this) {
      size_t i = 0;
      while (i < _arb_sequence_q.length) {

	// Check for lock requests.  Any lock request at the head
	// of the queue that is not blocked will be granted immediately.
	bool temp = false;
	if (i < _arb_sequence_q.length) {
	  if (_arb_sequence_q[i].request == SEQ_TYPE_LOCK) {
	    if(_arb_sequence_q[i].process_id.isDefunct()) {
	      uvm_error("SEQLCKZMB",
			format("The task responsible for requesting a lock"
			       " on sequencer '%s' for sequence '%s' has"
			       " been killed, to avoid a deadlock the "
			       "sequence will be removed from the "
			       "arbitration queues", this.get_full_name(),
			       _arb_sequence_q[i].sequence_ptr.get_full_name()));
	      remove_sequence_from_queues(_arb_sequence_q[i].sequence_ptr);
	      continue;
	    }
	    temp = (is_blocked(_arb_sequence_q[i].sequence_ptr) is false);
	  }
	}

	// Grant the lock request and remove it from the queue.
	// This is a loop to handle multiple back-to-back locks.
	// Since each entry is deleted, i remains constant
	while (temp) {
	  _lock_list.pushBack(_arb_sequence_q[i].sequence_ptr);
	  m_set_arbitration_completed(_arb_sequence_q[i].request_id);
	  _arb_sequence_q.remove(i);
	  m_update_lists();

	  temp = false;
	  if (i < _arb_sequence_q.length) {
	    if (_arb_sequence_q[i].request == SEQ_TYPE_LOCK) {
	      temp = is_blocked(_arb_sequence_q[i].sequence_ptr) is false;
	    }
	  }
	}
	++i;
      }
    }
  }




  // m_select_sequence
  // -----------------

  // task
  public void m_select_sequence() {
    long selected_sequence;
    // Select a sequence
    do {
      wait_for_sequences();
      selected_sequence = m_choose_next_request();
      if (selected_sequence == -1) {
	m_wait_for_available_sequence();
      }
    } while (selected_sequence == -1);
    // issue grant
    synchronized(this) {
      if (selected_sequence >= 0) {
	m_set_arbitration_completed(_arb_sequence_q[selected_sequence].request_id);
	_arb_sequence_q.remove(selected_sequence);
	m_update_lists();
      }
    }
  }


  // m_choose_next_request
  // ---------------------
  // When a driver requests an operation, this function must find the next
  // available, unlocked, relevant sequence.
  //
  // This function returns -1 if no sequences are available or the entry into
  // arb_sequence_q for the chosen sequence

  public int m_choose_next_request() {
    synchronized(this) {
      Queue!int avail_sequences;
      Queue!int highest_sequences;
      grant_queued_locks();

      int i = 0;
      while (i < _arb_sequence_q.length) {
	if(_arb_sequence_q[i].process_id.isDefunct()) {
	  uvm_error("SEQREQZMB",
		    format("The task responsible for requesting a"
			   " wait_for_grant on sequencer '%s' for"
			   " sequence '%s' has been killed, to avoid"
			   " a deadlock the sequence will be removed"
			   " from the arbitration queues",
			   this.get_full_name(), _arb_sequence_q[i].sequence_ptr.get_full_name()));
	  remove_sequence_from_queues(_arb_sequence_q[i].sequence_ptr);
	  continue;
	}

	if (i < _arb_sequence_q.length)
	  if (_arb_sequence_q[i].request == SEQ_TYPE_REQ)
	    if (is_blocked(_arb_sequence_q[i].sequence_ptr) is false)
	      if (_arb_sequence_q[i].sequence_ptr.is_relevant() is true) {
		if (_m_arbitration == SEQ_ARB_FIFO) {
		  return i;
		}
		else avail_sequences.pushBack(i);
	      }

	++i;
      }

      // Return immediately if there are 0 or 1 available sequences
      if (_m_arbitration is SEQ_ARB_FIFO) {
	return -1;
      }
      if (avail_sequences.length < 1)  {
	return -1;
      }

      if (avail_sequences.length == 1) {
	return avail_sequences[0];
      }

      // If any locks are in place, then the available queue must
      // be checked to see if a lock prevents any sequence from proceeding
      if (_lock_list.length > 0) {
	for (i = 0; i < avail_sequences.length; i++) {
	  if (is_blocked(_arb_sequence_q[avail_sequences[i]].sequence_ptr) != 0) {
	    avail_sequences.remove(i);
	    --i;
	  }
	}
	if (avail_sequences.length < 1) return -1;
	if (avail_sequences.length == 1) return avail_sequences[0];
      }

      //  Weighted Priority Distribution
      // Pick an available sequence based on weighted priorities of available sequences
      if (_m_arbitration == SEQ_ARB_WEIGHTED) {
	int sum_priority_val = 0;
	for (i = 0; i < avail_sequences.length; ++i) {
	  sum_priority_val +=
	    m_get_seq_item_priority(_arb_sequence_q[avail_sequences[i]]);
	}

	// int temp = $urandom_range(sum_priority_val-1, 0);
	int temp = uniform(0, sum_priority_val);

	sum_priority_val = 0;
	for (i = 0; i < avail_sequences.length; ++i) {
	  if ((m_get_seq_item_priority(_arb_sequence_q[avail_sequences[i]]) +
	       sum_priority_val) > temp) {
	    return avail_sequences[i];
	  }
	  sum_priority_val +=
	    m_get_seq_item_priority(_arb_sequence_q[avail_sequences[i]]);
	}
	uvm_report_fatal("Sequencer", "UVM Internal error in weighted"
			 " arbitration code", UVM_NONE);
      }

      //  Random Distribution
      if (_m_arbitration == SEQ_ARB_RANDOM) {
	i = cast(int) uniform(0, avail_sequences.length);
	return avail_sequences[i];
      }

      //  Strict Fifo
      if (_m_arbitration == SEQ_ARB_STRICT_FIFO ||
	  _m_arbitration == SEQ_ARB_STRICT_RANDOM) {
	int highest_pri = 0;
	// Build a list of sequences at the highest priority
	for (i = 0; i < avail_sequences.length; ++i) {
	  if (m_get_seq_item_priority(_arb_sequence_q[avail_sequences[i]])
	      > highest_pri) {
	    // New highest priority, so start new list
	    highest_sequences.clear();
	    highest_sequences.pushBack(avail_sequences[i]);
	    highest_pri =
	      m_get_seq_item_priority(_arb_sequence_q[avail_sequences[i]]);
	  }
	  else if (m_get_seq_item_priority(_arb_sequence_q[avail_sequences[i]]) ==
		   highest_pri) {
	    highest_sequences.pushBack(avail_sequences[i]);
	  }
	}

	// Now choose one based on arbitration type
	if (_m_arbitration == SEQ_ARB_STRICT_FIFO) {
	  return(highest_sequences[0]);
	}

	i = cast(int) uniform(0, highest_sequences.length);
	return highest_sequences[i];
      }

      if (_m_arbitration == SEQ_ARB_USER) {
	i = user_priority_arbitration( avail_sequences);

	// Check that the returned sequence is in the list of available
	// sequences.  Failure to use an available sequence will cause
	// highly unpredictable results.

	// highest_sequences = avail_sequences[].find with (item == i);
	highest_sequences = filter!(a => a == i)(avail_sequences[]);
	if (highest_sequences.length is 0) {
	  uvm_report_fatal("Sequencer",
			   format("Error in User arbitration, sequence %0d"
				  " not available\n%s", i, convert2string()),
			   UVM_NONE);
	}
	return(i);
      }

      uvm_report_fatal("Sequencer", "Internal error: Failed to choose sequence",
		       UVM_NONE);
      // The assert statement is required since otherwise DMD
      // complains that the function does not return a value
      assert(false, "Sequencer, Internal error: Failed to choose sequence");
    }
  }


  // m_wait_for_arbitration_completed
  // --------------------------------

  // task
  public void m_wait_for_arbitration_completed(int request_id) {

    // Search the list of arb_wait_q, see if this item is done
    while(true) {
      int lock_arb_size = m_lock_arb_size.get;
      synchronized(this) {
	if (request_id in _arb_completed) {
	  _arb_completed.remove(request_id);
	  return;
	}
      }
      while(lock_arb_size == m_lock_arb_size.get) {
	m_lock_arb_size.getEvent.wait();
      }
    }
  }

  // m_set_arbitration_completed
  // ---------------------------

  public void m_set_arbitration_completed(int request_id) {
    synchronized(this) {
      _arb_completed[request_id] = true;
    }
  }


  // m_lock_req
  // ----------
  // Internal method. Called by a sequence to request a lock.
  // Puts the lock request onto the arbitration queue.

  //task
  public void m_lock_req(uvm_sequence_base sequence_ptr, bool lock) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequence_controller",
		       "lock_req passed null sequence_ptr", UVM_NONE);
    }
    uvm_sequence_request new_req;
    synchronized(this) {	// FIXME -- deadlock possible flag
      int my_seq_id = m_register_sequence(sequence_ptr);
      new_req = new uvm_sequence_request();
      synchronized(new_req) {
	new_req.grant = false;
	new_req.sequence_id = sequence_ptr.get_sequence_id();
	new_req.request = SEQ_TYPE_LOCK;
	new_req.sequence_ptr = sequence_ptr;
	new_req.request_id = inc_g_request_id();
	new_req.process_id = Process.self;
      }

      if (lock is 1) {
	// Locks are arbitrated just like all other requests
	_arb_sequence_q.pushBack(new_req);
      } else {
	// Grabs are not arbitrated - they go to the front
	// TODO:
	// Missing: grabs get arbitrated behind other grabs
	_arb_sequence_q.pushFront(new_req);
	m_update_lists();
      }
      // If this lock can be granted immediately, then do so.
      grant_queued_locks();
    }
    m_wait_for_arbitration_completed(new_req.request_id);
  }



  // Function - m_unlock_req
  //
  // Called by a sequence to request an unlock.  This
  // will remove a lock for this sequence if it exists

  // m_unlock_req
  // ------------
  // Called by a sequence to request an unlock.  This
  // will remove a lock for this sequence if it exists

  public void m_unlock_req(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequencer",
		       "m_unlock_req passed null sequence_ptr", UVM_NONE);
    }
    synchronized(this) {	// FIXME -- deadlock possible flag
      int my_seq_id = m_register_sequence(sequence_ptr);
      foreach (i, lock; _lock_list) {
	if (lock.get_inst_id() == sequence_ptr.get_inst_id()) {
	  _lock_list.remove(i);
	  m_update_lists();
	  return;
	}
      }
      uvm_report_warning("SQRUNL",
			 "Sequence '" ~ sequence_ptr.get_full_name() ~
			 "' called ungrab / unlock, but didn't have lock",
			 UVM_NONE);
    }
  }


  // remove_sequence_from_queues
  // ---------------------------

  public void remove_sequence_from_queues(uvm_sequence_base sequence_ptr) {
    synchronized(this) {
      int seq_id = sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, 0);
      // Remove all queued items for this sequence and any child sequences
      int i = 0;
      do {
	if (_arb_sequence_q.length > i) {
	  if ((_arb_sequence_q[i].sequence_id == seq_id) ||
	      (is_child(sequence_ptr, _arb_sequence_q[i].sequence_ptr))) {
	    if (sequence_ptr.get_sequence_state() == FINISHED)
	      uvm_error("SEQFINERR",
			format("Parent sequence '%s' should not finish before"
			       " all items from itself and items from descendent"
			       " sequences are processed.  The item request from"
			       " the sequence '%s' is being removed.",
			       sequence_ptr.get_full_name(),
			       _arb_sequence_q[i].sequence_ptr.get_full_name()));
	    _arb_sequence_q.remove(i);
	    m_update_lists();
	  }
	  else {
	    ++i;
	  }
	}
      } while (i < _arb_sequence_q.length);

      // remove locks for this sequence, and any child sequences
      i = 0;
      do {
	if (_lock_list.length > i) {
	  if ((_lock_list[i].get_inst_id() == sequence_ptr.get_inst_id()) ||
	      (is_child(sequence_ptr, _lock_list[i]))) {
	    if (sequence_ptr.get_sequence_state() == FINISHED)
	      uvm_error("SEQFINERR",
			format("Parent sequence '%s' should not finish before"
			       " locks from itself and descedent sequences are"
			       " removed.  The lock held by the child sequence"
			       " '%s' is being removed.",
			       sequence_ptr.get_full_name(),
			       _lock_list[i].get_full_name()));
	    _lock_list.remove(i);
	    m_update_lists();
	  }
	  else {
	    ++i;
	  }
	}
      } while (i < _lock_list.length);

      // Unregister the sequence_id, so that any returning data is dropped
      m_unregister_sequence(sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, 1));
    }
  }

  // m_sequence_exiting
  // ------------------

  public void m_sequence_exiting(uvm_sequence_base sequence_ptr) {
    remove_sequence_from_queues(sequence_ptr);
  }

  // kill_sequence
  // -------------

  public void kill_sequence(uvm_sequence_base sequence_ptr) {
    synchronized(this) {
      remove_sequence_from_queues(sequence_ptr);
      sequence_ptr.m_kill();
    }
  }


  // analysis_write
  // --------------

  public void analysis_write(uvm_sequence_item t) {
    return;
  }

  // build_phase
  // -----------

  override public void build_phase(uvm_phase phase) {
    // For mantis 3402, the config stuff must be done in the deprecated
    // build() phase in order for a manual build call to work. Both
    // the manual build call and the config settings in build() are
    // deprecated.
    super.build_phase(phase);
  }


  override public void build() {
    int dummy;
    super.build();
    version(UVM_NO_DEPRECATED) {}
    else {
      // deprecated parameters for sequencer. Use uvm_sequence_library class
      // for sequence library functionality.
      if (get_config_string("default_sequence", default_sequence)) {
	uvm_warning("UVM_DEPRECATED", "default_sequence config parameter is"
		    " deprecated and not part of the UVM standard. See"
		    " documentation for uvm_sequencer_base::"
		    "start_phase_sequence().");
	this.m_default_seq_set = true;
      }
      if (get_config_int("count", count)) {
	uvm_warning("UVM_DEPRECATED", "count config parameter is deprecated"
		    " and not part of the UVM standard");
      }
      if (get_config_int("max_random_count", max_random_count)) {
	uvm_warning("UVM_DEPRECATED", "count config parameter is deprecated"
		    " and not part of the UVM standard");
      }
      if (get_config_int("max_random_depth", max_random_depth)) {
	uvm_warning("UVM_DEPRECATED", "max_random_depth config parameter is"
		    " deprecated and not part of the UVM standard. Use "
		    "'uvm_sequence_library' class for sequence library "
		    "functionality");
      }
      if (get_config_int("pound_zero_count", dummy)) {
	uvm_warning("UVM_DEPRECATED", "pound_zero_count was set but ignored. "
		    "Sequencer/driver synchronization now uses "
		    "'uvm_wait_for_nba_region'");
      }
    }
  }

  // do_print
  // --------

  override public void do_print(uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      printer.print_array_header("arbitration_queue", _arb_sequence_q.length);
      foreach(i, arb_seq; _arb_sequence_q) {
	printer.print_string(format("[%0d]", i) ~
			     format("%s@seqid%0d", arb_seq.request,
				    arb_seq.sequence_id), "[");
      }
      printer.print_array_footer(_arb_sequence_q.length);

      printer.print_array_header("lock_queue", _lock_list.length);
      foreach(i, lock; _lock_list) {
	printer.print_string(format("[%0d]", i) ~
			     format("%s@seqid%0d", lock.get_full_name(),
				    lock.get_sequence_id()), "[");
      }
      printer.print_array_footer(_lock_list.length);
    }
  }

  // m_register_sequence
  // -------------------

  public int m_register_sequence(uvm_sequence_base sequence_ptr) {
    synchronized(this) {
      if (sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, 1) > 0) {
	return sequence_ptr.get_sequence_id();
      }
      sequence_ptr.m_set_sqr_sequence_id(_m_sequencer_id, inc_g_sequence_id());
      _reg_sequences[sequence_ptr.get_sequence_id()] = sequence_ptr;
      // }
      // Decide if it is fine to have sequence_ptr under
      // synchronized(this) lock -- may lead to deadlocks
      return sequence_ptr.get_sequence_id();
    }
  }

  // m_unregister_sequence
  // ---------------------

  public void m_unregister_sequence(int sequence_id) {
    synchronized(this) {
      if (sequence_id !in _reg_sequences) {
	return;
      }
      _reg_sequences.remove(sequence_id);
    }
  }

  // m_find_sequence
  // ---------------

  public uvm_sequence_base m_find_sequence(int sequence_id) {
    synchronized(this) {
      // When sequence_id is -1, return the first available sequence.  This is used
      // when deleting all sequences
      if (sequence_id == -1) {
	auto r = _reg_sequences.keys;
	if(r.length != 0) {
	  return(_reg_sequences[r[0]]);
	}
	return null;
      }
      if (sequence_id !in _reg_sequences) {
	return null;
      }
      return _reg_sequences[sequence_id];
    }
  }

  // m_update_lists
  // --------------

  public void m_update_lists() {
    ++m_lock_arb_size;
  }


  // convert2string
  // ----------------

  override public string convert2string() {
    synchronized(this) {
      string s = "  -- arb i/id/type: ";
      foreach(i, arb_seq; _arb_sequence_q) {
	s ~= format(" %0d/%0d/%s ", i, arb_seq.sequence_id,
		    arb_seq.request);
      }
      s ~= "\n -- _lock_list i/id: ";
      foreach (i, lock; _lock_list) {
	s ~= format(" %0d/%0d", i, lock.get_sequence_id());
      }
      return(s);
    }
  }

  // m_find_number_driver_connections
  // --------------------------------

  public size_t m_find_number_driver_connections() {
    return 0;
  }


  // m_wait_arb_not_equal
  // --------------------

  // task
  public void m_wait_arb_not_equal() {
    // wait (m_arb_size != m_lock_arb_size);
    while(m_lock_arb_size.get == m_arb_size) {
      m_lock_arb_size.getEvent.wait();
    }
  }

  // m_wait_for_available_sequence
  // -----------------------------

  // task
  public void m_wait_for_available_sequence() {
    Queue!int is_relevant_entries;
    // This routine will wait for a change in the request list, or for
    // wait_for_relevant to return on any non-relevant, non-blocked sequence
    synchronized(this) {
      m_arb_size = m_lock_arb_size.get;
      for (int i = 0; i < _arb_sequence_q.length; ++i) {
	if (_arb_sequence_q[i].request == SEQ_TYPE_REQ) {
	  if (is_blocked(_arb_sequence_q[i].sequence_ptr) is false) {
	    if (_arb_sequence_q[i].sequence_ptr.is_relevant() is false) {
	      is_relevant_entries.pushBack(i);
	    }
	  }
	}
      }
    }

    // Typical path - don't need fork if all queued entries are relevant
    if (is_relevant_entries.length == 0) {
      m_wait_arb_not_equal();
      return;
    }

    //     fork  // isolate inner fork block for disabling
    // join({
    auto seqF = fork({
	// One path in fork is for any wait_for_relevant to return
	synchronized(this) {
	  m_is_relevant_completed = false;

	  for(size_t i = 0; i < is_relevant_entries.length; ++i) {
	    m_complete_relevant(is_relevant_entries[i]);
	  }
	}
	// wait (m_is_relevant_completed is true);
	while(m_is_relevant_completed.get is false) {
	  m_is_relevant_completed.getEvent.wait();
	}
      },
      // The other path in the fork is for any queue entry to change
      {
	m_wait_arb_not_equal();
      });
    seqF.joinAny();
    seqF.abortTree();
    // });
  }

  public void m_complete_relevant(int is_relevant) {
    synchronized(this) {
      uvm_sequence_request req = _arb_sequence_q[is_relevant];
      fork({
	  req.sequence_ptr.wait_for_relevant();
	  m_is_relevant_completed = true;
	});
    }
  }

  // m_get_seq_item_priority
  // -----------------------

  public int m_get_seq_item_priority(uvm_sequence_request seq_q_entry) {
    // If the priority was set on the item, then that is used
    if (seq_q_entry.item_priority != -1) {
      if (seq_q_entry.item_priority <= 0) {
	uvm_report_fatal("SEQITEMPRI",
			 format("Sequence item from %s has illegal priority: %0d",
				seq_q_entry.sequence_ptr.get_full_name(),
				seq_q_entry.item_priority), UVM_NONE);
      }
      return seq_q_entry.item_priority;
    }
    // Otherwise, use the priority of the calling sequence
    if (seq_q_entry.sequence_ptr.get_priority() < 0) {
      uvm_report_fatal("SEQDEFPRI",
		       format("Sequence %s has illegal priority: %0d",
			      seq_q_entry.sequence_ptr.get_full_name(),
			      seq_q_entry.sequence_ptr.get_priority()), UVM_NONE);
    }
    return seq_q_entry.sequence_ptr.get_priority();
  }

  @uvm_immutable_sync private WithEvent!bool _m_is_relevant_completed;


  //----------------------------------------------------------------------------
  // DEPRECATED - DO NOT USE IN NEW DESIGNS - NOT PART OF UVM STANDARD
  //----------------------------------------------------------------------------

  version(UVM_NO_DEPRECATED) {}
  else {
    // Variable- count
    //
    // Sets the number of items to execute.
    //
    // Supercedes the max_random_count variable for uvm_random_sequence class
    // for backward compatibility.

    int count = -1;

    int m_random_count;
    int m_exhaustive_count;
    int m_simple_count;

    uint max_random_count = 10;
    uint max_random_depth = 4;

    protected string default_sequence = "uvm_random_sequence";
    protected bool m_default_seq_set;


    Queue!string sequences;
    protected int[string] sequence_ids;
    protected @rand int seq_kind;

    // add_sequence
    // ------------
    //
    // Adds a sequence of type specified in the type_name paramter to the
    // sequencer's sequence library.

    public void add_sequence(string type_name) {

      uvm_warning("UVM_DEPRECATED", "Registering sequence '" ~ type_name ~
		  "' with sequencer '" ~ get_full_name() ~ "' is deprecated. ");

      //assign typename key to an int based on size
      //used with get_seq_kind to return an int key to match a type name
      if (type_name !in sequence_ids) {
	sequence_ids[type_name] = cast(int) sequences.length;
	//used w/ get_sequence to return a uvm_sequence factory object that
	//matches an int id
	sequences.pushBack(type_name);
      }
    }

    // remove_sequence
    // ---------------

    public void remove_sequence(string type_name) {
      sequence_ids.remove(type_name);
      for (int i = 0; i < this.sequences.length; i++) {
	if (this.sequences[i] == type_name) {
	  this.sequences.remove(i);
	}
      }
    }

    // set_sequences_queue
    // -------------------

    public void set_sequences_queue(ref Queue!string sequencer_sequence_lib) {

      for(int j=0; j < sequencer_sequence_lib.length; j++) {
	sequence_ids[sequencer_sequence_lib[j]] = cast(int) sequences.length;
	this.sequences.pushBack(sequencer_sequence_lib[j]);
      }
    }

    // start_default_sequence
    // ----------------------
    // Called when the run phase begins, this method starts the default sequence,
    // as specified by the default_sequence member variable.
    //

    // task
    public void start_default_sequence() {

      // Default sequence was cleared, or the count is zero
      if (default_sequence == "" || count == 0 ||
	  (sequences.length == 0 && default_sequence == "uvm_random_sequence")) {
	return;
      }

      // Have run-time phases and no user setting of default sequence
      if(this.m_default_seq_set == false && m_domain !is null) {
	default_sequence = "";
	uvm_info("NODEFSEQ", "The \"default_sequence\" has not been set. "
		 "Since this sequencer has a runtime phase schedule, the "
		 "uvm_random_sequence is not being started for the run phase.",
		 UVM_HIGH);
	return;
      }

      // Have a user setting for both old and new default sequence mechanisms
      if (this.m_default_seq_set == true &&
	  (uvm_config_db!(uvm_sequence_base).exists(this, "run_phase",
						    "default_sequence", 0) ||
	   uvm_config_db!(uvm_object_wrapper).exists(this, "run_phase",
						     "default_sequence", 0))) {

	uvm_warning("MULDEFSEQ", "A default phase sequence has been set via the "
		    "\"<phase_name>.default_sequence\" configuration option."
		    "The deprecated \"default_sequence\" configuration option"
		    " is ignored.");
	return;
      }

      // no user sequences to choose from
      if(sequences.length == 2 &&
	 sequences[0] == "uvm_random_sequence" &&
	 sequences[1] == "uvm_exhaustive_sequence") {
	uvm_report_warning("NOUSERSEQ", "No user sequence available. "
			   "Not starting the (deprecated) default sequence.",
			   UVM_HIGH);
	return;
      }

      uvm_warning("UVM_DEPRECATED", "Starting (deprecated) default sequence '" ~
		  default_sequence ~ "' on sequencer '" ~ get_full_name() ~
		  "'. See documentation for uvm_sequencer_base::"
		  "start_phase_sequence() for information on " ~
		  "starting default sequences in UVM.");
      if(sequences.length != 0) {
	auto factory = uvm_factory.get();
	uvm_sequence_base m_seq = cast(uvm_sequence_base)
	  factory.create_object_by_name(default_sequence,
					get_full_name(), default_sequence);
	//create the sequence object
	if (m_seq is null) {
	  uvm_report_fatal("FCTSEQ", "Default sequence set to invalid value : " ~
			   default_sequence, UVM_NONE);
	}

	if (m_seq is null) {
	  uvm_report_fatal("STRDEFSEQ", "Null m_sequencer reference", UVM_NONE);
	}
	synchronized(this) {
	  m_seq.starting_phase = run_ph;
	  m_seq.print_sequence_info = true;
	  m_seq.set_parent_sequence(null);
	  m_seq.set_sequencer(this);
	  m_seq.reseed();
	}
	if (!m_seq.randomize()) {
	  uvm_report_warning("STRDEFSEQ", "Failed to randomize sequence");
	}
	m_seq.start(this);
      }
    }

    // get_seq_kind
    // ------------
    // Returns an int seq_kind correlating to the sequence of type type_name
    // in the sequencer's sequence library. If the named sequence is not
    // registered a SEQNF warning is issued and -1 is returned.

    public int get_seq_kind(string type_name) {

      uvm_warning("UVM_DEPRECATED", format("%m is deprecated"));
      synchronized(this) {
	if (type_name in sequence_ids) {
	  return sequence_ids[type_name];
	}
      }

      uvm_warning("SEQNF",
		  "Sequence type_name '" ~ type_name ~
		  "' not registered with this sequencer.");

      return -1;
    }

    // get_sequence
    // ------------
    // Returns a reference to a sequence specified by the seq_kind int.
    // The seq_kind int may be obtained using the get_seq_kind() method.

    public uvm_sequence_base get_sequence(int req_kind) {

      uvm_warning("UVM_DEPRECATED", format("%m is deprecated"));

      if (req_kind < 0 || req_kind >= sequences.length) {
	uvm_report_error("SEQRNG",
			 format("Kind arg '%0d' out of range. Need 0-%0d",
				req_kind, sequences.length-1));
      }

      string m_seq_type = sequences[req_kind];

      uvm_factory factory = uvm_factory.get();
      uvm_sequence_base m_seq = cast(uvm_sequence_base)
	factory.create_object_by_name(m_seq_type, get_full_name(), m_seq_type);
      if (m_seq is null) {
	uvm_report_fatal("FCTSEQ",
			 format("Factory can not produce a sequence of type %0s.",
				m_seq_type), UVM_NONE);
      }

      m_seq.print_sequence_info = true;
      m_seq.set_sequencer (this);
      return m_seq;
    }

    // num_sequences
    // -------------

    public size_t num_sequences() {
      synchronized(this) {
	return sequences.length;
      }
    }

    // m_add_builtin_seqs
    // ------------------

    public void m_add_builtin_seqs(bool add_simple = true) {
      if("uvm_random_sequence" !in sequence_ids) {
	add_sequence("uvm_random_sequence");
      }
      if("uvm_exhaustive_sequence" !in sequence_ids) {
	add_sequence("uvm_exhaustive_sequence");
      }
      if(add_simple is true) {
	if("uvm_simple_sequence" !in sequence_ids)
	  add_sequence("uvm_simple_sequence");
      }
    }

    // run_phase
    // ---------

    // task
    override public void run_phase(uvm_phase phase) {
      super.run_phase(phase);
      start_default_sequence();
    }
  }
}

//------------------------------------------------------------------------------
//
// Class- uvm_sequence_request
//
//------------------------------------------------------------------------------

// The SV version has this enum defined inside the
// uvm_sequencer_base class. But since the enum is used in both
// the uvm_sequencer_base and uvm_sequence_request class, it seems
// better to keep it independent
private enum seq_req_t: byte
  {   SEQ_TYPE_REQ,
      SEQ_TYPE_LOCK,
      SEQ_TYPE_GRAB}

mixin(declareEnums!seq_req_t());

class uvm_sequence_request
{
  mixin(uvm_sync!uvm_sequence_request);
  @uvm_public_sync private bool               _grant;
  @uvm_public_sync private int                _sequence_id;
  @uvm_public_sync private int                _request_id;
  @uvm_public_sync private int                _item_priority;
  @uvm_public_sync private Process            _process_id;
  @uvm_public_sync private seq_req_t          _request;
  @uvm_public_sync private uvm_sequence_base  _sequence_ptr;
}
