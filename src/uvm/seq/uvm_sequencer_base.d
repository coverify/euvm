//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2013-2014 NVIDIA Corporation
//   Copyright 2014-2016 Coverify Systems Technology
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
import uvm.base.uvm_coreservice;
import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequence_base;
import uvm.base.uvm_component;
import uvm.base.uvm_once;
import uvm.base.uvm_config_db;
import uvm.base.uvm_entity;
import uvm.base.uvm_factory;
import uvm.base.uvm_message_defines;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_globals;
import uvm.base.uvm_resource;
import uvm.base.uvm_phase;
import uvm.base.uvm_domain;
import uvm.base.uvm_printer;
import uvm.base.uvm_misc;
import uvm.meta.misc;

import esdl.data.queue;
import esdl.base.core;

version(UVM_NO_RAND) {}
 else {
   import esdl.data.rand;
 }
  
import std.random: uniform;
import std.algorithm;
import std.string: format;

alias uvm_config_seq = uvm_config_db!uvm_sequence_base;
// typedef class uvm_sequence_request;


// Utility class for tracking default_sequences
// TBD -- make this a struct
class uvm_sequence_process_wrapper {
  mixin(uvm_sync_string);
  @uvm_private_sync
  Process _pid;
  @uvm_private_sync
  uvm_sequence_base _seq;
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_sequencer_base
//
// Controls the flow of sequences, which generate the stimulus (sequence item
// transactions) that is passed on to drivers for execution.
//
//------------------------------------------------------------------------------

class uvm_sequencer_base: uvm_component
{
  static class uvm_once: uvm_once_base
  {
    @uvm_private_sync
    private int _g_request_id;
    @uvm_private_sync
    private int _g_sequence_id = 1;
    @uvm_private_sync
    private int _g_sequencer_id = 1;
  };

  mixin(uvm_once_sync_string);
  mixin(uvm_sync_string);

  mixin uvm_component_essentials;

  static int inc_g_request_id() {
    synchronized(once) {
      return once._g_request_id++;
    }
  }

  static int inc_g_sequence_id() {
    synchronized(once) {
      return once._g_sequence_id++;
    }
  }

  static int inc_g_sequencer_id() {
    synchronized(once) {
      return once._g_sequencer_id++;
    }
  }

  // make sure that all accesses to _arb_sequence_q are made under
  // synchronized(this) lock

  // queue of sequences waiting for arbitration
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

  @uvm_protected_sync
  private int      _m_sequencer_id;


  // declared protected in SV version
  @uvm_immutable_sync
  private WithEvent!int              _m_lock_arb_size;  // used for waiting processes
  @uvm_private_sync
  private int                        _m_arb_size;       // used for waiting processes
  @uvm_immutable_sync
  private WithEvent!int              _m_wait_for_item_sequence_id;

  @uvm_immutable_sync
  private WithEvent!int              _m_wait_for_item_transaction_id;

  @uvm_immutable_sync
  private Event                      _m_wait_for_item_ids;

  @uvm_protected_sync
  protected int                 _m_wait_relevant_count = 0 ;
  @uvm_protected_sync
  protected int                 _m_max_zero_time_wait_relevant_count = 10;
  @uvm_protected_sync
  protected SimTime                _m_last_wait_relevant_time = 0 ;

  private uvm_sequencer_arb_mode       _m_arbitration = uvm_sequencer_arb_mode.UVM_SEQ_ARB_FIFO;


  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for uvm_component: name is the name of the
  // instance, and parent is the handle to the hierarchical parent.

  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      _m_lock_arb_size = new WithEvent!int;
      _m_is_relevant_completed = new WithEvent!bool;
      _m_wait_for_item_sequence_id = new WithEvent!int;
      _m_wait_for_item_transaction_id = new WithEvent!int;
      _m_wait_for_item_ids = _m_wait_for_item_sequence_id.getEvent() |
	_m_wait_for_item_transaction_id.getEvent();
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

  final bool is_child(uvm_sequence_base parent,
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
  // When the sequencer arbitration mode is set to UVM_SEQ_ARB_USER (via the
  // <set_arbitration> method), the sequencer will call this function each
  // time that it needs to arbitrate among sequences.
  //
  // Derived sequencers may override this method to perform a custom arbitration
  // policy. The override must return one of the entries from the
  // avail_sequences queue, which are indexes into an internal queue,
  // arb_sequence_q.
  //
  // The default implementation behaves like UVM_SEQ_ARB_FIFO, which returns the
  // entry at avail_sequences[0].
  //
  // user_priority_arbitration
  // -------------------------

  static int user_priority_arbitration(Queue!int avail_sequences) {
    return avail_sequences[0];
  }


  // Task: execute_item
  //
  // Executes the given transaction ~item~ directly on this sequencer. A temporary
  // parent sequence is automatically created for the ~item~.  There is no capability to
  // retrieve responses. If the driver returns responses, they will accumulate in the
  // sequencer, eventually causing response overflow unless
  // <uvm_sequence_base::set_response_queue_error_report_disabled> is called.

  // execute_item
  // ------------

  // task
  final void execute_item(uvm_sequence_item item) {
    uvm_sequence_base seq = new uvm_sequence_base();
    item.set_sequencer(this);
    item.set_parent_sequence(seq);
    seq.set_sequencer(this);
    seq.start_item(item);
    seq.finish_item(item);
  }

  // Hidden array, keeps track of running default sequences
  private uvm_sequence_process_wrapper[uvm_phase] _m_default_sequences;


  // Function: start_phase_sequence
  //
  // Start the default sequence for this phase, if any.
  // The default sequence is configured via resources using
  // either a sequence instance or sequence type (object wrapper).
  // If both are used,
  // the sequence instance takes precedence. When attempting to override
  // a previous default sequence setting, you must override both
  // the instance and type (wrapper) resources, else your override may not
  // take effect.
  //
  // When setting the resource using ~set~, the 1st argument specifies the
  // context pointer, usually ~this~ for components or ~null~ when executed from
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
  // Configuration by type is shorter and can be substituted via
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

  final void start_phase_sequence(uvm_phase phase) {
    synchronized(this) {
      uvm_resource_pool            rp = uvm_resource_pool.get();
      uvm_sequence_base            seq;
      uvm_coreservice_t            cs = uvm_coreservice_t.get();
      uvm_factory                  f = cs.get_factory();
  
      // Has a default sequence been specified?
      uvm_resource_types.rsrc_q_t  rq
	= rp.lookup_name(get_full_name() ~ "." ~ phase.get_name() ~ "_phase",
			 "default_sequence", null, false);
      uvm_resource_pool.sort_by_precedence(rq);
  
      // Look for the first one if the appropriate type
      for(int i = 0; seq is null && i < rq.length; i++) {
	uvm_resource_base rsrc = rq.get(i);
    
	// uvm_config_db#(uvm_sequence_base)?
	// Priority is given to uvm_sequence_base because it is a specific sequence instance
	// and thus more specific than one that is dynamically created via the
	// factory and the object wrapper.
	auto sbr = cast(uvm_resource!(uvm_sequence_base)) rsrc;
	if (sbr !is null) {
	  seq = sbr.read(this);
	  if (seq is null) {
	    uvm_info("UVM/SQR/PH/DEF/SB/NULL",
		     "Default phase sequence for phase '" ~ phase.get_name() ~
		     "' explicitly disabled", UVM_FULL);
	    return;
	  }
	}
    
	// uvm_config_db#(uvm_object_wrapper)?
	else {
	  auto owr = cast(uvm_resource!(uvm_object_wrapper)) rsrc;
	  if (owr !is null) {
	    uvm_object_wrapper wrapper = owr.read(this);
	    if (wrapper is null) {
	      uvm_info("UVM/SQR/PH/DEF/OW/NULL",
		       "Default phase sequence for phase '" ~
		       phase.get_name() ~ "' explicitly disabled", UVM_FULL);
	      return;
	    }

	    seq = cast(uvm_sequence_base)
	      f.create_object_by_type(wrapper, get_full_name(),
				      wrapper.get_type_name());
	    if (seq is null) {
	      uvm_warning("PHASESEQ",
			  "Default sequence for phase '" ~
			  phase.get_name() ~ "' %s is not a sequence type");
	      return;
	    }
	  }
	}
      }
  
      if(seq is null) {
	uvm_info("PHASESEQ", "No default phase sequence for phase '" ~
		 phase.get_name() ~ "'", UVM_FULL);
	return;
      }
  
      uvm_info("PHASESEQ", "Starting default sequence '" ~
	       seq.get_type_name() ~ "' for phase '" ~ phase.get_name() ~
	       "'", UVM_FULL);
  
      seq.print_sequence_info = true;
      seq.set_sequencer(this);
      seq.reseed();
      seq.set_starting_phase(phase);
  
      version(UVM_NO_RAND) {}
      else {
	if(!seq.do_not_randomize) {
	  try {
	    seq.randomize();
	  }
	  catch(Exception e) {
	    uvm_warning("STRDEFSEQ",
			"Randomization failed for default sequence '" ~
			seq.get_type_name() ~ "' for phase '" ~
			phase.get_name() ~ "'");
	    return;
	  }
	}
      }
  
      fork!("uvm_sequence_base/start_phase_sequence")({
	  uvm_sequence_process_wrapper w = new uvm_sequence_process_wrapper();
	  // reseed this process for random stability
	  w.pid = Process.self();
	  w.seq = seq;
	  w.pid.srandom(uvm_create_random_seed(seq.get_type_name(),
					       this.get_full_name()));
	  synchronized(this) {
	    _m_default_sequences[phase] = w;
	  }
	  // this will either complete naturally, or be killed later
	  seq.start(this);
	  synchronized(this) {
	    _m_default_sequences.remove(phase);
	  }
	});
  
    }
  }

  // Function: stop_phase_sequence
  //
  // Stop the default sequence for this phase, if any exists, and it
  // is still executing.

  // stop_phase_sequence
  // --------------------

  void stop_phase_sequence(uvm_phase phase) {
    synchronized(this) {
      auto pseq_wrap = phase in _m_default_sequences;
      if (pseq_wrap !is null) {
	uvm_info("PHASESEQ",
		 "Killing default sequence '" ~
		 pseq_wrap.seq.get_type_name() ~
		 "' for phase '" ~ phase.get_name() ~ "'", UVM_FULL);
        pseq_wrap.seq.kill();
      }
      else {
        uvm_info("PHASESEQ",
		 "No default sequence to kill for phase '" ~
		 phase.get_name() ~ "'", UVM_FULL);
      }
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
  void wait_for_grant(uvm_sequence_base sequence_ptr,
			     int item_priority = -1,
			     bool lock_request = false) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequencer",
		       "wait_for_grant passed null sequence_ptr", UVM_NONE);
    }

    uvm_sequence_request req_s;
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
  void wait_for_item_done(uvm_sequence_base sequence_ptr,
			  int transaction_id) {
    int sequence_id;
    synchronized(this) {
      sequence_id = sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, true);
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
	_m_wait_for_item_ids.wait();
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

  bool is_blocked(uvm_sequence_base sequence_ptr) {
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
  // Returns 1 if the sequence referred to in the parameter currently has a lock
  // on this sequencer, 0 otherwise.
  //
  // Note that even if this sequence has a lock, a child sequence may also have
  // a lock, in which case the sequence is still blocked from issuing
  // operations on the sequencer
  //

  // has_lock
  // --------

  bool has_lock(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequence_controller",
		       "has_lock passed null sequence_ptr", UVM_NONE);
    }
    synchronized(this) {
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
  void lock(uvm_sequence_base sequence_ptr) {
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
  void grab(uvm_sequence_base sequence_ptr) {
    m_lock_req(sequence_ptr, false);
  }


  // Function: unlock
  //
  // Removes any locks and grabs obtained by the specified sequence_ptr.
  //

  // unlock
  // ------

  void unlock(uvm_sequence_base sequence_ptr) {
    m_unlock_req(sequence_ptr);
  }

  // Function: ungrab
  //
  // Removes any locks and grabs obtained by the specified sequence_ptr.
  //

  // ungrab
  // ------

  void  ungrab(uvm_sequence_base sequence_ptr) {
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

  void stop_sequences() { // FIXME -- find out if it would be
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

  bool is_grabbed() {
    synchronized(this) {
      return (_lock_list.length != 0);
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

  uvm_sequence_base current_grabber() {
    synchronized(this) {
      if (_lock_list.length == 0) {
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

  bool has_do_available() {
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
  // UVM_SEQ_ARB_FIFO          - Requests are granted in FIFO order (default)
  // UVM_SEQ_ARB_WEIGHTED      - Requests are granted randomly by weight
  // UVM_SEQ_ARB_RANDOM        - Requests are granted randomly
  // UVM_SEQ_ARB_STRICT_FIFO   - Requests at highest priority granted in FIFO order
  // UVM_SEQ_ARB_STRICT_RANDOM - Requests at highest priority granted in randomly
  // UVM_SEQ_ARB_USER          - Arbitration is delegated to the user-defined
  //                         function, user_priority_arbitration. That function
  //                         will specify the next sequence to grant.
  //
  // The default user function specifies FIFO order.
  //

  // set_arbitration
  // ---------------

  void set_arbitration(UVM_SEQ_ARB_TYPE val) {
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

  UVM_SEQ_ARB_TYPE get_arbitration() {
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
  void wait_for_sequences() {
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

  void send_request(uvm_sequence_base sequence_ptr,
			   uvm_sequence_item t,
			   bool rerandomize = false) {
    return;
  }

  // Function: set_max_zero_time_wait_relevant_count
  //
  // Can be called at any time to change the maximum number of times 
  // wait_for_relevant() can be called by the sequencer in zero time before
  // an error is declared.  The default maximum is 10.

  // void set_max_zero_time_wait_relevant_count(int new_val) ;

  // set_max_zero_time_wait_relevant_count
  // ------------

  void set_max_zero_time_wait_relevant_count(int new_val) {
    synchronized(this) {
      _m_max_zero_time_wait_relevant_count = new_val ;
    }
  }



  //----------------------------------------------------------------------------
  // INTERNAL METHODS - DO NOT CALL DIRECTLY, ONLY OVERLOAD IF VIRTUAL
  //----------------------------------------------------------------------------

  // grant_queued_locks
  // ------------------
  // Any lock or grab requests that are at the front of the queue will be
  // granted at the earliest possible time.  This function grants any queues
  // at the front that are not locked out

  void grant_queued_locks() {
    synchronized(this) {
      // first remove sequences with dead lock control process
      auto defunct_items =
	filter!(item => item.request == SEQ_TYPE_LOCK &&
		item.process_id.isDefunct())(_arb_sequence_q[]);
      foreach(item; defunct_items) {
	uvm_error("SEQLCKZMB",
		  format("The task responsible for requesting a" ~
			 " lock on sequencer '%s' for sequence '%s'" ~
			 " has been killed, to avoid a deadlock the " ~
			 "sequence will be removed from the arbitration " ~
			 "queues", this.get_full_name(),
			 item.sequence_ptr.get_full_name()));
	remove_sequence_from_queues(item.sequence_ptr);
      }
  
      // now move all is_blocked() into lock_list
      uvm_sequence_request[] blocked_seqs;
      uvm_sequence_request[] not_blocked_seqs;  
      size_t b = _arb_sequence_q.length; // index for first non-LOCK request

      // int[] q1;
      // q1 = arb_sequence_q.find_first_index(item) with (item.request!=SEQ_TYPE_LOCK);
      auto c = countUntil!(item =>
			   item.request != SEQ_TYPE_LOCK)(_arb_sequence_q[]);
      // if(q1.size())
      // 	b=q1[0];  
      if(c != -1) {
	b = c;
      }
      if(b != 0) { // at least one lock
	auto leading_lock_reqs = _arb_sequence_q[0..b]; // set of locks; arb_sequence[b] is the first req!=SEQ_TYPE_LOCK	
	// split into blocked/not-blocked requests
	foreach(item; leading_lock_reqs) {
	  if(is_blocked(item.sequence_ptr) != 0) {
	    blocked_seqs ~= item;
	  }
	  else {
	    not_blocked_seqs ~= item;
	  }
	}
		
	if(b > _arb_sequence_q.length - 1) {
	  _arb_sequence_q = blocked_seqs;
	}
	else {
	  _arb_sequence_q = blocked_seqs ~ _arb_sequence_q[b..$];
	}
      }
	  
      foreach(item; not_blocked_seqs) {
	_lock_list.pushBack(item.sequence_ptr);  
	m_set_arbitration_completed(item.request_id);
      }
	
      // trigger listeners if lock list has changed
      if(not_blocked_seqs.length != 0) {
	m_update_lists();
      }
    }
  }



  // m_select_sequence
  // -----------------

  // task
  void m_select_sequence() {
    ptrdiff_t selected_sequence;
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

  int m_choose_next_request() {
    synchronized(this) {
      Queue!int avail_sequences;
      Queue!int highest_sequences;
      grant_queued_locks();

      int i = 0;
      while (i < _arb_sequence_q.length) {
	if(_arb_sequence_q[i].process_id.isDefunct()) {
	  uvm_error("SEQREQZMB",
		    format("The task responsible for requesting a" ~
			   " wait_for_grant on sequencer '%s' for" ~
			   " sequence '%s' has been killed, to avoid" ~
			   " a deadlock the sequence will be removed" ~
			   " from the arbitration queues", this.get_full_name(),
			   _arb_sequence_q[i].sequence_ptr.get_full_name()));
	  remove_sequence_from_queues(_arb_sequence_q[i].sequence_ptr);
	  continue;
	}

	if (i < _arb_sequence_q.length)
	  if (_arb_sequence_q[i].request == SEQ_TYPE_REQ)
	    if (is_blocked(_arb_sequence_q[i].sequence_ptr) is false)
	      if (_arb_sequence_q[i].sequence_ptr.is_relevant() is true) {
		if (_m_arbitration == UVM_SEQ_ARB_FIFO) {
		  return i;
		}
		else avail_sequences.pushBack(i);
	      }

	++i;
      }

      // Return immediately if there are 0 or 1 available sequences
      if (_m_arbitration is UVM_SEQ_ARB_FIFO) {
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
	for (i = 0; i < avail_sequences.length; ++i) {
	  if (is_blocked(_arb_sequence_q[avail_sequences[i]].sequence_ptr) != 0) {
	    avail_sequences.remove(i);
	    --i;
	  }
	}
	if (avail_sequences.length < 1) {
	  return -1;
	}
	if (avail_sequences.length == 1) {
	  return avail_sequences[0];
	}
      }

      //  Weighted Priority Distribution
      // Pick an available sequence based on weighted priorities of available sequences
      if (_m_arbitration == UVM_SEQ_ARB_WEIGHTED) {
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
	uvm_report_fatal("Sequencer", "UVM Internal error in weighted" ~
			 " arbitration code", UVM_NONE);
      }

      //  Random Distribution
      if (_m_arbitration == UVM_SEQ_ARB_RANDOM) {
	i = cast(int) uniform(0, avail_sequences.length);
	return avail_sequences[i];
      }

      //  Strict Fifo
      if (_m_arbitration == UVM_SEQ_ARB_STRICT_FIFO ||
	  _m_arbitration == UVM_SEQ_ARB_STRICT_RANDOM) {
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
	if (_m_arbitration == UVM_SEQ_ARB_STRICT_FIFO) {
	  return(highest_sequences[0]);
	}

	i = cast(int) uniform(0, highest_sequences.length);
	return highest_sequences[i];
      }

      if (_m_arbitration == UVM_SEQ_ARB_USER) {
	i = user_priority_arbitration( avail_sequences);

	// Check that the returned sequence is in the list of available
	// sequences.  Failure to use an available sequence will cause
	// highly unpredictable results.

	// highest_sequences = avail_sequences[].find with (item == i);
	highest_sequences = filter!(a => a == i)(avail_sequences[]);
	if (highest_sequences.length == 0) {
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
  void m_wait_for_arbitration_completed(int request_id) {

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

  void m_set_arbitration_completed(int request_id) {
    synchronized(this) {
      _arb_completed[request_id] = true;
    }
  }


  // m_lock_req
  // ----------
  // Internal method. Called by a sequence to request a lock.
  // Puts the lock request onto the arbitration queue.

  //task
  private void m_lock_req(uvm_sequence_base sequence_ptr, bool lock) {
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

      if (lock is true) {
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

  void m_unlock_req(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequencer",
		       "m_unlock_req passed null sequence_ptr", UVM_NONE);
    }
    synchronized(this) {	// FIXME -- deadlock possible flag
      int seqid = sequence_ptr.get_inst_id();

      auto c = countUntil!(item =>
			   item.get_inst_id == seqid)(_lock_list[]);
      if(c != -1) {
	_lock_list.remove(c);
	grant_queued_locks(); // grant lock requests 
	m_update_lists();	 
      }
      else {
	uvm_report_warning("SQRUNL", 
			   "Sequence '" ~ sequence_ptr.get_full_name() ~
			   "' called ungrab / unlock, but didn't have lock",
			   UVM_NONE);
      }
    }
  }


  // remove_sequence_from_queues
  // ---------------------------

  private void remove_sequence_from_queues(uvm_sequence_base sequence_ptr) {
    synchronized(this) {
      int seq_id = sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, false);
      // Remove all queued items for this sequence and any child sequences
      int i = 0;
      do {
	if (_arb_sequence_q.length > i) {
	  if ((_arb_sequence_q[i].sequence_id == seq_id) ||
	      (is_child(sequence_ptr, _arb_sequence_q[i].sequence_ptr))) {
	    if (sequence_ptr.get_sequence_state() == UVM_FINISHED)
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
	    if (sequence_ptr.get_sequence_state() == UVM_FINISHED)
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
      m_unregister_sequence(sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, true));
    }
  }

  // m_sequence_exiting
  // ------------------

  void m_sequence_exiting(uvm_sequence_base sequence_ptr) {
    remove_sequence_from_queues(sequence_ptr);
  }

  // kill_sequence
  // -------------

  void kill_sequence(uvm_sequence_base sequence_ptr) {
    synchronized(this) {
      remove_sequence_from_queues(sequence_ptr);
      sequence_ptr.m_kill();
    }
  }


  // analysis_write
  // --------------

  void analysis_write(uvm_sequence_item t) {
    return;
  }


  override void build() {
    synchronized(this) {
      int dummy;
      super.build();
      version(UVM_INCLUDE_DEPRECATED) {
	// deprecated parameters for sequencer. Use uvm_sequence_library class
	// for sequence library functionality.
	if (uvm_config_db!(string).get(this, "", "default_sequence",
				       _default_sequence)) {
	  uvm_warning("UVM_DEPRECATED", "default_sequence config parameter is"
		      " deprecated and not part of the UVM standard. See"
		      " documentation for uvm_sequencer_base::"
		      "start_phase_sequence().");
	  _m_default_seq_set = true;
	}
	if (uvm_config_db!(int).get(this, "", "count", _count)) {
	  uvm_warning("UVM_DEPRECATED", "count config parameter is deprecated"
		      " and not part of the UVM standard");
	}
	if (uvm_config_db!(uint).get(this, "", "max_random_count",
				     _max_random_count)) {
	  uvm_warning("UVM_DEPRECATED", "count config parameter is deprecated"
		      " and not part of the UVM standard");
	}
	if (uvm_config_db!(uint).get(this, "", "max_random_depth",
				     _max_random_depth)) {
	  uvm_warning("UVM_DEPRECATED", "max_random_depth config parameter is"
		      " deprecated and not part of the UVM standard. Use "
		      "'uvm_sequence_library' class for sequence library "
		      "functionality");
	}
	if (uvm_config_db!(int).get(this, "", "pound_zero_count", dummy)) {
	  uvm_warning("UVM_DEPRECATED", "pound_zero_count was set but ignored. "
		      "Sequencer/driver synchronization now uses "
		      "'uvm_wait_for_nba_region'");
	}
      }
    }
  }

  // build_phase
  // -----------

  override void build_phase(uvm_phase phase) {
    // For mantis 3402, the config stuff must be done in the deprecated
    // build() phase in order for a manual build call to work. Both
    // the manual build call and the config settings in build() are
    // deprecated.
    super.build_phase(phase);
  }

  // do_print
  // --------

  override void do_print(uvm_printer printer) {
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

  int m_register_sequence(uvm_sequence_base sequence_ptr) {
    synchronized(this) {
      if (sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, true) > 0) {
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

  void m_unregister_sequence(int sequence_id) {
    synchronized(this) {
      if (sequence_id !in _reg_sequences) {
	return;
      }
      _reg_sequences.remove(sequence_id);
    }
  }

  // m_find_sequence
  // ---------------

  uvm_sequence_base m_find_sequence(int sequence_id) {
    synchronized(this) {
      // When sequence_id is -1, return the first available sequence.  This is used
      // when deleting all sequences
      if (sequence_id == -1) {
	auto r = sort(_reg_sequences.keys);
	if(r.length != 0) {
	  return(_reg_sequences[r[0]]);
	}
	return null;
      }
      auto pseq = sequence_id in _reg_sequences;
      if (pseq is null) {
	return null;
      }
      return *pseq;
    }
  }

  // m_update_lists
  // --------------

  void m_update_lists() {
    ++m_lock_arb_size;
  }


  // convert2string
  // ----------------

  override string convert2string() {
    return to!string;
  }

  string to(T)() if(is(T == string)) {
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

  size_t m_find_number_driver_connections() {
    return 0;
  }


  // m_wait_arb_not_equal
  // --------------------

  // task
  void m_wait_arb_not_equal() {
    // wait (m_arb_size != m_lock_arb_size);
    while(m_lock_arb_size.get == m_arb_size) {
      m_lock_arb_size.getEvent.wait();
    }
  }

  // m_wait_for_available_sequence
  // -----------------------------

  // task
  void m_wait_for_available_sequence() {
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
    auto seqF = fork!("uvm_sequencer_base/m_wait_for_available_sequence")({
	// One path in fork is for any wait_for_relevant to return
	synchronized(this) {
	  _m_is_relevant_completed = false;

	  for(size_t i = 0; i < is_relevant_entries.length; ++i) {
	    (size_t k) {
	      auto seq = _arb_sequence_q[is_relevant_entries[k]];
	      fork({
		  seq.sequence_ptr.wait_for_relevant();
		  synchronized(this) {
		    auto time_now = getRootEntity.getSimTime;
		    if (time_now != _m_last_wait_relevant_time) {
		      _m_last_wait_relevant_time = time_now;
		      _m_wait_relevant_count = 0;
		    }
		    else {
		      _m_wait_relevant_count++ ;
		      if(_m_wait_relevant_count >
			 _m_max_zero_time_wait_relevant_count) {
			uvm_fatal("SEQRELEVANTLOOP",
				  format("Zero time loop detected," ~
					 " passed wait_for_relevant %0d" ~
					 " times without time advancing",
					 _m_wait_relevant_count));
		      }
		    }
		    _m_is_relevant_completed = true;
		  }
		});
	    } (i);
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

  // m_get_seq_item_priority
  // -----------------------

  int m_get_seq_item_priority(uvm_sequence_request seq_q_entry) {
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

  @uvm_immutable_sync
  private WithEvent!bool _m_is_relevant_completed;

  // Access to following internal methods provided via seq_item_export

  version(UVM_DISABLE_AUTO_ITEM_RECORDING) {
    @uvm_private_sync
      private bool _m_auto_item_recording = false;
  }
  else {
    @uvm_private_sync
      private bool _m_auto_item_recording = true;
  }

  void disable_auto_item_recording() {
    synchronized(this) {
      _m_auto_item_recording = false;
    }
  }

  bool is_auto_item_recording_enabled() {
    synchronized(this) {
      return _m_auto_item_recording;
    }
  }

  //----------------------------------------------------------------------------
  // DEPRECATED - DO NOT USE IN NEW DESIGNS - NOT PART OF UVM STANDARD
  //----------------------------------------------------------------------------

  version(UVM_INCLUDE_DEPRECATED) {
    mixin Randomization;
    // Variable- count
    //
    // Sets the number of items to execute.
    //
    // Supercedes the max_random_count variable for uvm_random_sequence class
    // for backward compatibility.

    int _count = -1;

    int _m_random_count;
    int _m_exhaustive_count;
    int _m_simple_count;

    uint _max_random_count = 10;
    uint _max_random_depth = 4;

    protected string _default_sequence = "uvm_random_sequence";
    protected bool _m_default_seq_set;


    Queue!string _sequences;
    Queue!string sequences() {
      synchronized(this) {
	return _sequences.dup;
      }
    }
    
    protected int[string] _sequence_ids;

    version(UVM_NO_RAND) {
      protected int _seq_kind;
    }
    else {
      protected @rand int _seq_kind;
    }

    // add_sequence
    // ------------
    //
    // Adds a sequence of type specified in the type_name paramter to the
    // sequencer's sequence library.

    void add_sequence(string type_name) {

      uvm_warning("UVM_DEPRECATED", "Registering sequence '" ~ type_name ~
  		  "' with sequencer '" ~ get_full_name() ~ "' is deprecated. ");

      synchronized(this) {
	//assign typename key to an int based on size
	//used with get_seq_kind to return an int key to match a type name
	if (type_name !in _sequence_ids) {
	  _sequence_ids[type_name] = cast(int) _sequences.length;
	  //used w/ get_sequence to return a uvm_sequence factory object that
	  //matches an int id
	  _sequences.pushBack(type_name);
	}
      }
    }

    // remove_sequence
    // ---------------

    void remove_sequence(string type_name) {
      synchronized(this) {
	_sequence_ids.remove(type_name);
	for (int i = 0; i < _sequences.length; i++) {
	  if (_sequences[i] == type_name) {
	    _sequences.remove(i);
	  }
	}
      }
    }

    // set_sequences_queue
    // -------------------

    void set_sequences_queue(ref Queue!string sequencer_sequence_lib) {
      synchronized(this) {
	for(int j=0; j < sequencer_sequence_lib.length; j++) {
	  _sequence_ids[sequencer_sequence_lib[j]] = cast(int) _sequences.length;
	  _sequences.pushBack(sequencer_sequence_lib[j]);
	}
      }
    }

    // start_default_sequence
    // ----------------------
    // Called when the run phase begins, this method starts the default sequence,
    // as specified by the default_sequence member variable.
    //

    // task
    void start_default_sequence() {
      uvm_sequence_base m_seq;
      synchronized(this) {
	// Default sequence was cleared, or the count is zero
	if (_default_sequence == "" || _count == 0 ||
	    (_sequences.length == 0 && _default_sequence == "uvm_random_sequence")) {
	  return;
	}

	// Have run-time phases and no user setting of default sequence
	if(_m_default_seq_set == false && m_domain !is null) {
	  _default_sequence = "";
	  uvm_info("NODEFSEQ", "The \"default_sequence\" has not been set. "
		   "Since this sequencer has a runtime phase schedule, the "
		   "uvm_random_sequence is not being started for the run phase.",
		   UVM_HIGH);
	  return;
	}

	// Have a user setting for both old and new default sequence mechanisms
	if (_m_default_seq_set == true &&
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
	if(_sequences.length == 2 &&
	   _sequences[0] == "uvm_random_sequence" &&
	   _sequences[1] == "uvm_exhaustive_sequence") {
	  uvm_report_warning("NOUSERSEQ", "No user sequence available. "
			     "Not starting the (deprecated) default sequence.",
			     UVM_HIGH);
	  return;
	}

	uvm_warning("UVM_DEPRECATED", "Starting (deprecated) default sequence '" ~
		    _default_sequence ~ "' on sequencer '" ~ get_full_name() ~
		    "'. See documentation for uvm_sequencer_base::"
		    "start_phase_sequence() for information on " ~
		    "starting default sequences in UVM.");

	uvm_coreservice_t cs = uvm_coreservice_t.get();
	uvm_factory factory = cs.get_factory();
	m_seq = cast(uvm_sequence_base)
	  factory.create_object_by_name(_default_sequence,
					get_full_name(), _default_sequence);
	//create the sequence object
	if (m_seq is null) {
	  uvm_report_fatal("FCTSEQ", "Default sequence set to invalid value : " ~
			   _default_sequence, UVM_NONE);
	}

	if (m_seq is null) {
	  uvm_report_fatal("STRDEFSEQ", "Null m_sequencer reference", UVM_NONE);
	}
	synchronized(m_seq) {
	  m_seq.set_starting_phase = run_ph;
	  m_seq.print_sequence_info = true;
	  m_seq.set_parent_sequence(null);
	  m_seq.set_sequencer(this);
	  m_seq.reseed();
	}
	version(UVM_NO_RAND) {}
	else {
	  try{
	    m_seq.randomize();
	  }
	  catch {
	    uvm_report_warning("STRDEFSEQ", "Failed to randomize sequence");
	  }
	}
      }
      m_seq.start(this);
    }

    // get_seq_kind
    // ------------
    // Returns an int seq_kind correlating to the sequence of type type_name
    // in the sequencers sequence library. If the named sequence is not
    // registered a SEQNF warning is issued and -1 is returned.

    int get_seq_kind(string type_name) {

      uvm_warning("UVM_DEPRECATED", format("%m is deprecated"));
      synchronized(this) {
  	if (type_name in _sequence_ids) {
  	  return _sequence_ids[type_name];
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

    uvm_sequence_base get_sequence(int req_kind) {
      synchronized(this) {
	uvm_warning("UVM_DEPRECATED", format("%m is deprecated"));

	if (req_kind < 0 || req_kind >= _sequences.length) {
	  uvm_report_error("SEQRNG",
			   format("Kind arg '%0d' out of range. Need 0-%0d",
				  req_kind, _sequences.length-1));
	}

	string m_seq_type = _sequences[req_kind];

	uvm_coreservice_t cs = uvm_coreservice_t.get();                         
	uvm_factory factory = cs.get_factory();
	uvm_sequence_base m_seq = cast(uvm_sequence_base)
	  factory.create_object_by_name(m_seq_type, get_full_name(), m_seq_type);
	if (m_seq is null) {
	  uvm_report_fatal("FCTSEQ",
			   format("Factory cannot produce a sequence of type %0s.",
				  m_seq_type), UVM_NONE);
	}

	m_seq.print_sequence_info = true;
	m_seq.set_sequencer (this);
	return m_seq;
      }
    }

    // num_sequences
    // -------------

    size_t num_sequences() {
      synchronized(this) {
  	return _sequences.length;
      }
    }

    // m_add_builtin_seqs
    // ------------------

    void m_add_builtin_seqs(bool add_simple = true) {
      synchronized(this) {
	if("uvm_random_sequence" !in _sequence_ids) {
	  add_sequence("uvm_random_sequence");
	}
	if("uvm_exhaustive_sequence" !in _sequence_ids) {
	  add_sequence("uvm_exhaustive_sequence");
	}
	if(add_simple is true) {
	  if("uvm_simple_sequence" !in _sequence_ids)
	    add_sequence("uvm_simple_sequence");
	}
      }
    }

    // run_phase
    // ---------

    // task
    override void run_phase(uvm_phase phase) {
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
      SEQ_TYPE_GRAB} // FIXME SEQ_TYPE_GRAB is unused

mixin(declareEnums!seq_req_t());

class uvm_sequence_request
{
  mixin(uvm_sync_string);
  @uvm_public_sync
  private bool               _grant;
  @uvm_public_sync
  private int                _sequence_id;
  @uvm_public_sync
  private int                _request_id;
  @uvm_public_sync
  private int                _item_priority;
  @uvm_public_sync
  private Process            _process_id;
  @uvm_public_sync
  private seq_req_t          _request;
  @uvm_public_sync
  private uvm_sequence_base  _sequence_ptr;
}
