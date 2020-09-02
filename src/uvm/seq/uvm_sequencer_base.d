//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2017 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2014 Intel Corporation
// Copyright 2010-2017 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 Verilab
// Copyright 2010-2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2013-2018 Cisco Systems, Inc.
// Copyright 2012 Accellera Systems Initiative
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
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_component_defines;
import uvm.base.uvm_globals;
import uvm.base.uvm_resource;
import uvm.base.uvm_resource_base;
import uvm.base.uvm_phase;
import uvm.base.uvm_domain;
import uvm.base.uvm_printer;
import uvm.base.uvm_misc;
import uvm.meta.misc;

import esdl.data.queue;
import esdl.base.core;

import esdl.rand.misc: rand;

version(UVM_NO_RAND) {}
 else {
   import esdl.rand: randomize;
 }
  
import std.random: uniform;
import std.algorithm;
import std.string: format;

alias uvm_config_seq = uvm_config_db!uvm_sequence_base;
// typedef class uvm_sequence_request;


// Utility class for tracking default_sequences
// TBD -- make this a struct
@rand(false)
class uvm_sequence_process_wrapper
{
  mixin (uvm_sync_string);
  @uvm_private_sync
  Process _pid;
  @uvm_private_sync
  uvm_sequence_base _seq;
}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_sequencer_base
//
// The library implements some public API beyond what is documented
// in 1800.2.  It also modifies some API described erroneously in 1800.2.
//
//------------------------------------------------------------------------------

// Implementation artifact, extends virtual class uvm_sequence_base
// so that it can be constructed for execute_item
@rand(false)
class m_uvm_sqr_seq_base: uvm_sequence_base
{
  this(string name="unnamed-m_uvm_sqr_seq_base") {
    super(name);
  }
}

// @uvm-ieee 1800.2-2017 auto 15.3.1
@rand(false)
abstract class uvm_sequencer_base: uvm_component
{
  enum seq_req_t: byte
  {   SEQ_TYPE_REQ,
      SEQ_TYPE_LOCK
      }


  static class uvm_once: uvm_once_base
  {
    @uvm_private_sync
    private int _g_request_id;
    @uvm_private_sync
    private int _g_sequence_id = 1;
    @uvm_private_sync
    private int _g_sequencer_id = 1;
    @uvm_none_sync
    uvm_sequencer_base[uint] _all_sequencer_insts;
  };

  static uvm_sequencer_base[uint] all_sequencer_insts() {
    synchronized(_uvm_once_inst) {
      return _uvm_once_inst._all_sequencer_insts.dup;
    }
  }

  mixin (uvm_once_sync_string);
  mixin (uvm_sync_string);

  mixin uvm_abstract_component_essentials;

  static int inc_g_request_id() {
    synchronized (_uvm_once_inst) {
      return _uvm_once_inst._g_request_id++;
    }
  }

  static int inc_g_sequence_id() {
    synchronized (_uvm_once_inst) {
      return _uvm_once_inst._g_sequence_id++;
    }
  }

  static int inc_g_sequencer_id() {
    synchronized (_uvm_once_inst) {
      return _uvm_once_inst._g_sequencer_id++;
    }
  }

  // make sure that all accesses to _arb_sequence_q are made under
  // synchronized (this) lock

  // queue of sequences waiting for arbitration
  protected Queue!uvm_sequence_request _arb_sequence_q;

  // make sure that all accesses to _arb_completed are made under
  // synchronized (this) lock
  // declared protected in SV version
  private bool[int]                    _arb_completed;

  // make sure that all accesses to _lock_list are made under
  // synchronized (this) lock
  // declared protected in SV version
  private Queue!uvm_sequence_base      _lock_list;

  // make sure that all accesses to _reg_sequences are made under
  // synchronized (this) lock
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


  // Function -- NODOCS -- new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for uvm_component: name is the name of the
  // instance, and parent is the handle to the hierarchical parent.

  // @uvm-ieee 1800.2-2017 auto 15.3.2.1
  this(string name, uvm_component parent) {
    synchronized (this) {
      super(name, parent);
      _m_lock_arb_size = new WithEvent!int("_m_lock_arb_size");
      _m_is_relevant_completed = new WithEvent!bool("_m_is_relevant_completed");
      _m_wait_for_item_sequence_id = new WithEvent!int("_m_wait_for_item_sequence_id");
      _m_wait_for_item_transaction_id = new WithEvent!int("_m_wait_for_item_transaction_id");
      _m_wait_for_item_ids.initialize("_m_wait_for_item_ids");
      _m_wait_for_item_ids = _m_wait_for_item_sequence_id.getEvent() |
	_m_wait_for_item_transaction_id.getEvent();
      _m_sequencer_id = inc_g_sequencer_id();
      _m_lock_arb_size = -1;
    }
    synchronized (_uvm_once_inst) {
      _uvm_once_inst._all_sequencer_insts[m_sequencer_id] = this;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.2
  final bool is_child(uvm_sequence_base parent,
			     uvm_sequence_base child) {

    if (child is null) {
      uvm_report_fatal("uvm_sequencer", "is_child passed null child", uvm_verbosity.UVM_NONE);
    }

    if (parent is null) {
      uvm_report_fatal("uvm_sequencer", "is_child passed null parent", uvm_verbosity.UVM_NONE);
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


  // @uvm-ieee 1800.2-2017 auto 15.3.2.3
  static int user_priority_arbitration(Queue!int avail_sequences) {
    return avail_sequences[0];
  }


  // Task -- NODOCS -- execute_item
  //
  // Executes the given transaction ~item~ directly on this sequencer. A temporary
  // parent sequence is automatically created for the ~item~.  There is no capability to
  // retrieve responses. If the driver returns responses, they will accumulate in the
  // sequencer, eventually causing response overflow unless
  // <uvm_sequence_base::set_response_queue_error_report_enabled> is called.

  // execute_item
  // ------------

  // task
  // @uvm-ieee 1800.2-2017 auto 15.3.2.5
  final void execute_item(uvm_sequence_item item) {
    m_uvm_sqr_seq_base seq =
      new m_uvm_sqr_seq_base("execute_item_seq");
    item.set_sequencer(this);
    item.set_parent_sequence(seq);
    seq.set_sequencer(this);
    seq.start_item(item);
    seq.finish_item(item);
  }

  // Hidden array, keeps track of running default sequences
  private uvm_sequence_process_wrapper[uvm_phase] _m_default_sequences;


  // Function -- NODOCS -- start_phase_sequence
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
    synchronized (this) {
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
      for (int i = 0; seq is null && i < rq.length; i++) {
	uvm_resource_base rsrc = rq.get(i);
    
	// uvm_config_db#(uvm_sequence_base)?
	// Priority is given to uvm_sequence_base because it is a specific sequence instance
	// and thus more specific than one that is dynamically created via the
	// factory and the object wrapper.
	auto sbr = cast (uvm_resource!(uvm_sequence_base)) rsrc;
	if (sbr !is null) {
	  seq = sbr.read(this);
	  if (seq is null) {
	    uvm_info("UVM/SQR/PH/DEF/SB/NULL",
		     "Default phase sequence for phase '" ~ phase.get_name() ~
		     "' explicitly disabled", uvm_verbosity.UVM_FULL);
	    return;
	  }
	}
    
	// uvm_config_db#(uvm_object_wrapper)?
	else {
	  auto owr = cast (uvm_resource!(uvm_object_wrapper)) rsrc;
	  if (owr !is null) {
	    uvm_object_wrapper wrapper = owr.read(this);
	    if (wrapper is null) {
	      uvm_info("UVM/SQR/PH/DEF/OW/NULL",
		       "Default phase sequence for phase '" ~
		       phase.get_name() ~ "' explicitly disabled", uvm_verbosity.UVM_FULL);
	      return;
	    }

	    seq = cast (uvm_sequence_base)
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
  
      if (seq is null) {
	uvm_info("PHASESEQ", "No default phase sequence for phase '" ~
		 phase.get_name() ~ "'", uvm_verbosity.UVM_FULL);
	return;
      }
  
      uvm_info("PHASESEQ", "Starting default sequence '" ~
	       seq.get_type_name() ~ "' for phase '" ~ phase.get_name() ~
	       "'", uvm_verbosity.UVM_FULL);
  
      seq.print_sequence_info = true;
      seq.set_sequencer(this);
      seq.reseed();
      seq.set_starting_phase(phase);
  
      version(UVM_NO_RAND) {}
      else {
	if (seq.get_randomize_enabled()) {
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
	  synchronized (this) {
	    _m_default_sequences[phase] = w;
	  }
	  // this will either complete naturally, or be killed later
	  seq.start(this);
	  synchronized (this) {
	    _m_default_sequences.remove(phase);
	  }
	});
  
    }
  }

  // Function -- NODOCS -- stop_phase_sequence
  //
  // Stop the default sequence for this phase, if any exists, and it
  // is still executing.

  // stop_phase_sequence
  // --------------------

  void stop_phase_sequence(uvm_phase phase) {
    synchronized (this) {
      auto pseq_wrap = phase in _m_default_sequences;
      if (pseq_wrap !is null) {
	uvm_info("PHASESEQ",
		 "Killing default sequence '" ~
		 pseq_wrap.seq.get_type_name() ~
		 "' for phase '" ~ phase.get_name() ~ "'", uvm_verbosity.UVM_FULL);
        pseq_wrap.seq.kill();
      }
      else {
        uvm_info("PHASESEQ",
		 "No default sequence to kill for phase '" ~
		 phase.get_name() ~ "'", uvm_verbosity.UVM_FULL);
      }
    }
  }

  // Task -- NODOCS -- wait_for_grant
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
  // @uvm-ieee 1800.2-2017 auto 15.3.2.6
  void wait_for_grant(uvm_sequence_base sequence_ptr,
			     int item_priority = -1,
			     bool lock_request = false) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequencer",
		       "wait_for_grant passed null sequence_ptr", uvm_verbosity.UVM_NONE);
    }

    uvm_sequence_request req_s;
    synchronized (this) {
      // FIXME -- decide whether this has to be under synchronized lock
      int my_seq_id = m_register_sequence(sequence_ptr);

      // If lock_request is asserted, then issue a lock.  Don't wait for the response, since
      // there is a request immediately following the lock request
      if (lock_request is true) {
	req_s = new uvm_sequence_request();
	synchronized (req_s) {
	  req_s.grant = false;
	  req_s.sequence_id = my_seq_id;
	  req_s.request = seq_req_t.SEQ_TYPE_LOCK;
	  req_s.sequence_ptr = sequence_ptr;
	  req_s.request_id = inc_g_request_id();
	  req_s.process_id = Process.self;
	}
	_arb_sequence_q.pushBack(req_s);
      }

      // Push the request onto the queue
      req_s = new uvm_sequence_request();
      synchronized (req_s) {
	req_s.grant = false;
	req_s.request = seq_req_t.SEQ_TYPE_REQ;
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

  // task
  // @uvm-ieee 1800.2-2017 auto 15.3.2.7
  void wait_for_item_done(uvm_sequence_base sequence_ptr,
			  int transaction_id) {
    int sequence_id;
    synchronized (this) {
      sequence_id = sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, true);
      _m_wait_for_item_sequence_id = -1;
      _m_wait_for_item_transaction_id = -1;
    }

    if (transaction_id == -1) {
      // wait (m_wait_for_item_sequence_id == sequence_id);
      while (m_wait_for_item_sequence_id.get != sequence_id) {
	m_wait_for_item_sequence_id.getEvent.wait();
      }
    }
    else {
      // wait ((m_wait_for_item_sequence_id == sequence_id &&
      //	      m_wait_for_item_transaction_id == transaction_id));

      // while ((m_wait_for_item_sequence_id != sequence_id) ||
      //	     (m_wait_for_item_transaction_id != transaction_id)) {
      //	 wait(m_wait_for_item_sequence_event || m_wait_for_item_transaction_event);
      // }
      while (m_wait_for_item_sequence_id.get != sequence_id ||
	    m_wait_for_item_transaction_id.get != transaction_id) {
	_m_wait_for_item_ids.wait();
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.8
  bool is_blocked(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequence_controller",
		       "is_blocked passed null sequence_ptr", uvm_verbosity.UVM_NONE);
    }

    synchronized (this) {
      foreach (lock; _lock_list) {
	if ((lock.get_inst_id() != sequence_ptr.get_inst_id()) &&
	    (is_child(lock, sequence_ptr) is false)) {
	  return true;
	}
      }
      return false;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 15.3.2.9
  bool has_lock(uvm_sequence_base sequence_ptr) {
    if (sequence_ptr is null) {
      uvm_report_fatal("uvm_sequence_controller",
		       "has_lock passed null sequence_ptr", uvm_verbosity.UVM_NONE);
    }
    synchronized (this) {
      int my_seq_id = m_register_sequence(sequence_ptr);
      foreach (lock; _lock_list) {
	if (lock.get_inst_id() == sequence_ptr.get_inst_id()) {
	  return true;
	}
      }
      return false;
    }
  }

  // task
  // @uvm-ieee 1800.2-2017 auto 15.3.2.10
  void lock(uvm_sequence_base sequence_ptr) {
    m_lock_req(sequence_ptr, true);
  }

  // task
  // @uvm-ieee 1800.2-2017 auto 15.3.2.11
  void grab(uvm_sequence_base sequence_ptr) {
    m_lock_req(sequence_ptr, false);
  }


  // Function -- NODOCS -- unlock
  //
  //| extern virtual function void unlock(uvm_sequence_base sequence_ptr);
  //
  // Implementation of unlock, as defined in P1800.2-2017 section 15.3.2.12.
  // 
  // NOTE: unlock is documented in error as a virtual task, whereas it is 
  // implemented as a virtual function.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto 15.3.2.12
  void unlock(uvm_sequence_base sequence_ptr) {
    m_unlock_req(sequence_ptr);
  }

  // Function -- NODOCS -- ungrab
  //
  //| extern virtual function void ungrab(uvm_sequence_base sequence_ptr);
  //
  // Implementation of ungrab, as defined in P1800.2-2017 section 15.3.2.13.
  // 
  // NOTE: ungrab is documented in error as a virtual task, whereas it is 
  // implemented as a virtual function.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto 15.3.2.13
  void  ungrab(uvm_sequence_base sequence_ptr) {
    m_unlock_req(sequence_ptr);
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.14
  void stop_sequences() { // FIXME -- find out if it would be
				 // appropriate to have a synchronized
				 // lock for this function
    synchronized (this) {
      uvm_sequence_base seq_ptr = m_find_sequence(-1);
      while (seq_ptr !is null) {
	kill_sequence(seq_ptr);
	seq_ptr = m_find_sequence(-1);
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.15
  bool is_grabbed() {
    synchronized (this) {
      return (_lock_list.length != 0);
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.16
  uvm_sequence_base current_grabber() {
    synchronized (this) {
      if (_lock_list.length == 0) {
	return null;
      }
      return _lock_list[$-1];
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.17
  bool has_do_available() {
    synchronized (this) {
      foreach (arb_seq; _arb_sequence_q) {
	if ((arb_seq.sequence_ptr.is_relevant() is true) &&
	    (is_blocked(arb_seq.sequence_ptr) is false)) {
	  return true;
	}
      }
      return false;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.19
  void set_arbitration(uvm_sequencer_arb_mode val) {
    synchronized (this) {
      _m_arbitration = val;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.18
  uvm_sequencer_arb_mode get_arbitration() {
    synchronized (this) {
      return _m_arbitration;
    }
  }


  // Task -- NODOCS -- wait_for_sequences
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


  // Function -- NODOCS -- send_request
  //
  // Derived classes implement this function to send a request item to the
  // sequencer, which will forward it to the driver.  If the rerandomize bit
  // is set, the item will be randomized before being sent to the driver.
  //
  // This function may only be called after a <wait_for_grant> call.

  // @uvm-ieee 1800.2-2017 auto 15.3.2.20
  void send_request(uvm_sequence_base sequence_ptr,
			   uvm_sequence_item t,
			   bool rerandomize = false) {
    return;
  }


  // @uvm-ieee 1800.2-2017 auto 15.3.2.21
  void set_max_zero_time_wait_relevant_count(int new_val) {
    synchronized (this) {
      _m_max_zero_time_wait_relevant_count = new_val ;
    }
  }

  // Added in IEEE. Not in UVM 1.2
  // @uvm-ieee 1800.2-2017 auto 15.3.2.4
  uvm_sequence_base get_arbitration_sequence( int index ) {
    synchronized (this) {
      return _arb_sequence_q[index].sequence_ptr;
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
    synchronized (this) {
      // remove and report any zombies
      auto zombies =
	filter!(item => item.request == seq_req_t.SEQ_TYPE_LOCK &&
		item.process_id.isDefunct())(_arb_sequence_q[]);
      foreach (zombie; zombies) {
	uvm_error("SEQLCKZMB",
		  format("The task responsible for requesting a" ~
			 " lock on sequencer '%s' for sequence '%s'" ~
			 " has been killed, to avoid a deadlock the " ~
			 "sequence will be removed from the arbitration " ~
			 "queues", this.get_full_name(),
			 zombie.sequence_ptr.get_full_name()));
	remove_sequence_from_queues(zombie.sequence_ptr);
      }
  
      // grant the first lock request that is not blocked, if any
      auto c = countUntil!(item =>
			   (item.request == seq_req_t.SEQ_TYPE_LOCK &&
			    is_blocked(item.sequence_ptr)))(_arb_sequence_q[]);
      if (c != -1) {
	uvm_sequence_request lock_req = _arb_sequence_q[c];
	_lock_list ~= lock_req.sequence_ptr;
	m_set_arbitration_completed(lock_req.request_id);
	_arb_sequence_q.remove(c);
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
    synchronized (this) {
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
    synchronized (this) {
      Queue!int avail_sequences;
      Queue!int highest_sequences;
      grant_queued_locks();

      int i = 0;
      while (i < _arb_sequence_q.length) {
	if (_arb_sequence_q[i].process_id.isDefunct()) {
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
	  if (_arb_sequence_q[i].request == seq_req_t.SEQ_TYPE_REQ)
	    if (is_blocked(_arb_sequence_q[i].sequence_ptr) is false)
	      if (_arb_sequence_q[i].sequence_ptr.is_relevant() is true) {
		if (_m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_FIFO) {
		  return i;
		}
		else avail_sequences.pushBack(i);
	      }

	++i;
      }

      // Return immediately if there are 0 or 1 available sequences
      if (_m_arbitration is uvm_sequencer_arb_mode.UVM_SEQ_ARB_FIFO) {
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
      if (_m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_WEIGHTED) {
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
			 " arbitration code", uvm_verbosity.UVM_NONE);
      }

      //  Random Distribution
      if (_m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_RANDOM) {
	i = cast (int) uniform(0, avail_sequences.length);
	return avail_sequences[i];
      }

      //  Strict Fifo
      if (_m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_STRICT_FIFO ||
	  _m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_STRICT_RANDOM) {
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
	if (_m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_STRICT_FIFO) {
	  return (highest_sequences[0]);
	}

	i = cast (int) uniform(0, highest_sequences.length);
	return highest_sequences[i];
      }

      if (_m_arbitration == uvm_sequencer_arb_mode.UVM_SEQ_ARB_USER) {
	i = user_priority_arbitration( avail_sequences);

	// Check that the returned sequence is in the list of available
	// sequences.  Failure to use an available sequence will cause
	// highly unpredictable results.

	// highest_sequences = avail_sequences[].find with (item == i);
	highest_sequences = filter!(a => a == i)(avail_sequences[]);
	if (highest_sequences.length == 0) {
	  uvm_report_fatal("Sequencer",
			   format("Error in User arbitration, sequence %0d" ~
				  " not available\n%s", i, convert2string()),
			   uvm_verbosity.UVM_NONE);
	}
	return (i);
      }

      uvm_report_fatal("Sequencer", "Internal error: Failed to choose sequence",
		       uvm_verbosity.UVM_NONE);
      // The assert statement is required since otherwise DMD
      // complains that the function does not return a value
      assert (false, "Sequencer, Internal error: Failed to choose sequence");
    }
  }


  // m_wait_for_arbitration_completed
  // --------------------------------

  // task
  void m_wait_for_arbitration_completed(int request_id) {

    // Search the list of arb_wait_q, see if this item is done
    while (true) {
      int lock_arb_size = m_lock_arb_size.get;
      synchronized (this) {
	if (request_id in _arb_completed) {
	  _arb_completed.remove(request_id);
	  return;
	}
      }
      while (lock_arb_size == m_lock_arb_size.get) {
	m_lock_arb_size.getEvent.wait();
      }
    }
  }

  // m_set_arbitration_completed
  // ---------------------------

  void m_set_arbitration_completed(int request_id) {
    synchronized (this) {
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
		       "lock_req passed null sequence_ptr", uvm_verbosity.UVM_NONE);
    }
    uvm_sequence_request new_req;
    synchronized (this) {	// FIXME -- deadlock possible flag
      int my_seq_id = m_register_sequence(sequence_ptr);
      new_req = new uvm_sequence_request();
      synchronized (new_req) {
	new_req.grant = false;
	new_req.sequence_id = sequence_ptr.get_sequence_id();
	new_req.request = seq_req_t.SEQ_TYPE_LOCK;
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
		       "m_unlock_req passed null sequence_ptr", uvm_verbosity.UVM_NONE);
    }
    synchronized (this) {	// FIXME -- deadlock possible flag
      int seqid = sequence_ptr.get_inst_id();

      auto c = countUntil!(item =>
			   item.get_inst_id == seqid)(_lock_list[]);
      if (c != -1) {
	_lock_list.remove(c);
	grant_queued_locks(); // grant lock requests 
	m_update_lists();	 
      }
      else {
	uvm_report_warning("SQRUNL", 
			   "Sequence '" ~ sequence_ptr.get_full_name() ~
			   "' called ungrab / unlock, but didn't have lock",
			   uvm_verbosity.UVM_NONE);
      }
    }
  }


  // remove_sequence_from_queues
  // ---------------------------

  private void remove_sequence_from_queues(uvm_sequence_base sequence_ptr) {
    synchronized (this) {
      int seq_id = sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, false);
      // Remove all queued items for this sequence and any child sequences
      int i = 0;
      do {
	if (_arb_sequence_q.length > i) {
	  if ((_arb_sequence_q[i].sequence_id == seq_id) ||
	      (is_child(sequence_ptr, _arb_sequence_q[i].sequence_ptr))) {
	    if (sequence_ptr.get_sequence_state() == uvm_sequence_state.UVM_FINISHED)
	      uvm_error("SEQFINERR",
			format("Parent sequence '%s' should not finish before" ~
			       " all items from itself and items from descendent" ~
			       " sequences are processed.  The item request from" ~
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
	    if (sequence_ptr.get_sequence_state() == uvm_sequence_state.UVM_FINISHED)
	      uvm_error("SEQFINERR",
			format("Parent sequence '%s' should not finish before" ~
			       " locks from itself and descedent sequences are" ~
			       " removed.  The lock held by the child sequence" ~
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
    synchronized (this) {
      remove_sequence_from_queues(sequence_ptr);
      sequence_ptr.m_kill();
    }
  }


  // analysis_write
  // --------------

  void analysis_write(uvm_sequence_item t) {
    return;
  }


  // do_print
  // --------

  override void do_print(uvm_printer printer) {
    synchronized (this) {
      super.do_print(printer);
      printer.print_array_header("arbitration_queue", _arb_sequence_q.length);
      foreach (i, arb_seq; _arb_sequence_q) {
	printer.print_string(format("[%0d]", i) ~
			     format("%s@seqid%0d", arb_seq.request,
				    arb_seq.sequence_id), "[");
      }
      printer.print_array_footer(_arb_sequence_q.length);

      printer.print_array_header("lock_queue", _lock_list.length);
      foreach (i, lock; _lock_list) {
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
    synchronized (this) {
      if (sequence_ptr.m_get_sqr_sequence_id(_m_sequencer_id, true) > 0) {
	return sequence_ptr.get_sequence_id();
      }
      sequence_ptr.m_set_sqr_sequence_id(_m_sequencer_id, inc_g_sequence_id());
      _reg_sequences[sequence_ptr.get_sequence_id()] = sequence_ptr;
      // }
      // Decide if it is fine to have sequence_ptr under
      // synchronized (this) lock -- may lead to deadlocks
      return sequence_ptr.get_sequence_id();
    }
  }

  // m_unregister_sequence
  // ---------------------

  void m_unregister_sequence(int sequence_id) {
    synchronized (this) {
      if (sequence_id !in _reg_sequences) {
	return;
      }
      _reg_sequences.remove(sequence_id);
    }
  }

  // m_find_sequence
  // ---------------

  uvm_sequence_base m_find_sequence(int sequence_id) {
    synchronized (this) {
      // When sequence_id is -1, return the first available sequence.  This is used
      // when deleting all sequences
      if (sequence_id == -1) {
	auto r = sort(_reg_sequences.keys);
	if (r.length != 0) {
	  return (_reg_sequences[r[0]]);
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

  string to(T)() if (is (T == string)) {
      synchronized (this) {
	string s = "  -- arb i/id/type: ";
	foreach (i, arb_seq; _arb_sequence_q) {
	  s ~= format(" %0d/%0d/%s ", i, arb_seq.sequence_id,
		      arb_seq.request);
	}
	s ~= "\n -- _lock_list i/id: ";
	foreach (i, lock; _lock_list) {
	  s ~= format(" %0d/%0d", i, lock.get_sequence_id());
	}
	return (s);
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
    while (m_lock_arb_size.get == m_arb_size) {
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
    synchronized (this) {
      m_arb_size = m_lock_arb_size.get;
      for (int i = 0; i < _arb_sequence_q.length; ++i) {
	if (_arb_sequence_q[i].request == seq_req_t.SEQ_TYPE_REQ) {
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
	synchronized (this) {
	  _m_is_relevant_completed = false;

	  for (size_t i = 0; i < is_relevant_entries.length; ++i) {
	    (size_t k) {
	      auto seq = _arb_sequence_q[is_relevant_entries[k]];
	      fork({
		  seq.sequence_ptr.wait_for_relevant();
		  synchronized (this) {
		    auto time_now = getRootEntity.getSimTime;
		    if (time_now != _m_last_wait_relevant_time) {
		      _m_last_wait_relevant_time = time_now;
		      _m_wait_relevant_count = 0;
		    }
		    else {
		      _m_wait_relevant_count++ ;
		      if (_m_wait_relevant_count >
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
	while (m_is_relevant_completed.get is false) {
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
				seq_q_entry.item_priority), uvm_verbosity.UVM_NONE);
      }
      return seq_q_entry.item_priority;
    }
    // Otherwise, use the priority of the calling sequence
    if (seq_q_entry.sequence_ptr.get_priority() < 0) {
      uvm_report_fatal("SEQDEFPRI",
		       format("Sequence %s has illegal priority: %0d",
			      seq_q_entry.sequence_ptr.get_full_name(),
			      seq_q_entry.sequence_ptr.get_priority()), uvm_verbosity.UVM_NONE);
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

  // Function: disable_auto_item_recording
  //
  // Disables auto_item_recording
  // 
  // This function is the implementation of the 
  // uvm_sqr_if_base::disable_auto_item_recording() method detailed in
  // IEEE1800.2 section 15.2.1.2.10
  // 
  // This function is implemented here to allow <uvm_push_sequencer#(REQ,RSP)>
  // and <uvm_push_driver#(REQ,RSP)> access to the call.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  void disable_auto_item_recording() {
    synchronized (this) {
      _m_auto_item_recording = false;
    }
  }

  // Function: is_auto_item_recording_enabled
  //
  // Returns 1 is auto_item_recording is enabled,
  // otherwise 0
  // 
  // This function is the implementation of the 
  // uvm_sqr_if_base::is_auto_item_recording_enabled() method detailed in
  // IEEE1800.2 section 15.2.1.2.11
  // 
  // This function is implemented here to allow <uvm_push_sequencer#(REQ,RSP)>
  // and <uvm_push_driver#(REQ,RSP)> access to the call.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  bool is_auto_item_recording_enabled() {
    synchronized (this) {
      return _m_auto_item_recording;
    }
  }

}

//------------------------------------------------------------------------------
//
// Class- uvm_sequence_request
//
//------------------------------------------------------------------------------

@rand(false)
class uvm_sequence_request
{
  mixin (uvm_sync_string);
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
  private uvm_sequencer_base.seq_req_t
                             _request;
  @uvm_public_sync
  private uvm_sequence_base  _sequence_ptr;
}
