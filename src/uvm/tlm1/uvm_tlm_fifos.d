//
//------------------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Synopsys, Inc.
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

module uvm.tlm1.uvm_tlm_fifos;

// typedef class uvm_tlm_event;
import uvm.tlm1.uvm_tlm_fifo_base;
import uvm.tlm1.uvm_analysis_port;

import uvm.base.uvm_component;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_component_defines;

import uvm.meta.mailbox;

import esdl.rand.misc: rand;

//------------------------------------------------------------------------------
//
// Title -- NODOCS -- TLM FIFO Classes
//
// This section defines TLM-based FIFO classes.
//
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_tlm_fifo
//
// This class provides storage of transactions between two independently running
// processes. Transactions are put into the FIFO via the ~put_export~.
// transactions are fetched from the FIFO in the order they arrived via the
// ~get_peek_export~. The ~put_export~ and ~get_peek_export~ are inherited from
// the <uvm_tlm_fifo_base #(T)> super class, and the interface methods provided by
// these exports are defined by the <uvm_tlm_if_base #(T1,T2)> class.
//
//------------------------------------------------------------------------------

class uvm_tlm_fifo_common(T=int, size_t N=0):
  uvm_tlm_fifo_base!(T), rand.disable
{
  import esdl.base.core: Process;

  mixin uvm_component_essentials;

  // _m is effectively immutable
  private MailboxBase!T _m;
  private MailboxBase!T m() {
    return _m;
  }

  // _m_size is effectively immutable
  private size_t _m_size;
  private size_t m_size() {
    return _m_size;
  }

  version(UVM_USE_PROCESS_CONTAINER) {
    import uvm.base.uvm_misc: process_container_c;
    protected bool[process_container_c] _m_pending_blocked_gets;
  }
  else {
    protected bool[Process] _m_pending_blocked_gets;
  }


  // Function -- NODOCS -- new
  //
  // The ~name~ and ~parent~ are the normal uvm_component constructor arguments.
  // The ~parent~ should be null if the <uvm_tlm_fifo> is going to be used in a
  // statically elaborated construct (e.g., a module). The ~size~ indicates the
  // maximum size of the FIFO; a value of zero indicates no upper bound.

  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent);
      // _m = new Mailbox!T(size);
      _m_size = size;
    }
  }

  // Function -- NODOCS -- size
  //
  // Returns the capacity of the FIFO-- that is, the number of entries
  // the FIFO is capable of holding. A return value of 0 indicates the
  // FIFO capacity has no limit.

  override public size_t size() {
    synchronized (this) {
      return m_size;
    }
  }


  // Function -- NODOCS -- used
  //
  // Returns the number of entries put into the FIFO.

  override public size_t used() {
    synchronized (this) {
      return m.num();
    }
  }


  // Function -- NODOCS -- is_empty
  //
  // Returns 1 when there are no entries in the FIFO, 0 otherwise.

  override public bool is_empty() {
    synchronized (this) {
      return (m.num is 0);
    }
  }


  // Function -- NODOCS -- is_full
  //
  // Returns 1 when the number of entries in the FIFO is equal to its <size>,
  // 0 otherwise.

  override public bool is_full() {
    synchronized (this) {
      return (m_size !is 0) && (m.num() is m_size);
    }
  }

  // task
  override public void put(T t) {
    m.put(t);
    put_ap.write(t);
  }

  // task
  override public void get(out T t) {
    version (UVM_USE_PROCESS_CONTAINER) {
      process_container_c pid = new process_container_c(Process.self);
      synchronized (this) {
	_m_pending_blocked_gets[pid] = true;
      }
      m.get(t);
      synchronized (this) {
	_m_pending_blocked_gets.remove(pid);
      }
      get_ap.write(t);
    }
    else {
      Process pid = Process.self;
      synchronized (this) {
	_m_pending_blocked_gets[pid] = true;
      }
      m.get(t);
      synchronized (this) {
	_m_pending_blocked_gets.remove(pid);
      }
      get_ap.write(t);
    }
  }

  // task
  override public void peek(out T t) {
    m.peek(t);
  }

  override public bool try_get(out T t) {
    if (! m.try_get(t)) {
      return false;
    }

    get_ap.write(t);
    return true;
  }

  override public bool try_peek(out T t) {
    if (! m.try_peek(t)) {
      return false;
    }
    return true;
  }

  override public bool try_put(T t) {
    if (! m.try_put(t)) {
      return false;
    }

    put_ap.write(t);
    return true;
  }

  // Should always be called under synchronized (this) lock
  // else if some action is sought right after can_put on basis
  // of the result, the result may not hold for long in multicore
  // environment
  override public bool can_put() {
    synchronized (this) {
      return m_size is 0 || m.num() < m_size;
    }
  }

  // undocumented function for clearing zombie gets
  protected void m_clear_zombie_gets() {
    version (UVM_USE_PROCESS_CONTAINER) {
      process_container_c[] zombie_gets;
      foreach (proc, b; _m_pending_blocked_gets)
	if (proc.p.isKilled()) zombie_gets ~= proc;
      foreach (proc; zombie_gets) {
	synchronized (this) {
	  _m_pending_blocked_gets.remove(proc);
	}
      }
    }
    else {
      Process[] zombie_gets;
      foreach (proc, b; _m_pending_blocked_gets)
	if (proc.isKilled()) zombie_gets ~= proc;
      foreach (proc; zombie_gets) {
	synchronized (this) {
	  _m_pending_blocked_gets.remove(proc);
	}
      }
    }
  }
  
  override public bool can_get() {
    m_clear_zombie_gets();
    synchronized (this) {
      return m.num() > 0 && _m_pending_blocked_gets.length == 0;
    }
  }

  override public bool can_peek() {
    synchronized (this) {
      return m.num() > 0;
    }
  }


  // Function -- NODOCS -- flush
  //
  // Removes all entries from the FIFO, after which <used> returns 0
  // and <is_empty> returns 1.

  override public void flush() {
    synchronized (this) {
      m_clear_zombie_gets();
      
      if (m.num() > 0 && _m_pending_blocked_gets.length != 0) {
	uvm_report_error("flush failed" ,
			 "there are blocked gets preventing the flush",
			 uvm_verbosity.UVM_NONE);
	return;
      }

      T t;
      bool r = true;
      while (r) r = try_get(t) ;

    }
  }
}

// @uvm-ieee 1800.2-2020 auto 18.2.8.2
class uvm_tlm_fifo(T=int, size_t N=0):
  uvm_tlm_fifo_common!(T, N), rand.disable
{
  mixin uvm_component_essentials;
  // mixin uvm_type_name_decl;

  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent, size);
      _m = new Mailbox!T(size);
    }
  }
}

class uvm_tlm_async_pull_fifo(T=int, size_t N=0):
  uvm_tlm_fifo_common!(T, N), rand.disable
{
  mixin uvm_component_essentials;
  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent, size);
      _m = new MailInbox!T(parent, size);
    }
  }
}

class uvm_tlm_async_push_fifo(T=int, size_t N=0):
  uvm_tlm_fifo_common!(T, N), rand.disable
{
  mixin uvm_component_essentials;
  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent, size);
      _m = new MailOutbox!T(parent, size);
    }
  }
}

class uvm_tlm_async_fifo(T=int, size_t N=0):
  uvm_tlm_fifo_common!(T, N), rand.disable
{
  mixin uvm_component_essentials;
  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent, size);
      _m = new MailInOutbox!T(parent, size);
    }
  }
}

class uvm_tlm_vpi_pull_fifo(T=int, size_t N=0):
  uvm_tlm_fifo_common!(T, N), rand.disable
{
  mixin uvm_component_essentials;
  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent, size);
      _m = new MailVpiInbox!T(parent, size);
    }
  }
}

class uvm_tlm_vpi_push_fifo(T=int, size_t N=0):
  uvm_tlm_fifo_common!(T, N), rand.disable
{
  mixin uvm_component_essentials;
  public this(string name=null, uvm_component parent = null, int size = 1) {
    synchronized (this) {
      super(name, parent, size);
      _m = new MailVpiOutbox!T(parent, size);
    }
  }
}

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_tlm_analysis_fifo
//
// An analysis_fifo is a <uvm_tlm_fifo> with an unbounded size and a write interface.
// It can be used any place a <uvm_analysis_imp> is used. Typical usage is
// as a buffer between an <uvm_analysis_port> in an initiator component
// and TLM1 target component.
//
//------------------------------------------------------------------------------

class uvm_tlm_analysis_fifo(T=int):
  uvm_tlm_fifo!T, rand.disable
{

  mixin uvm_component_essentials;
  mixin uvm_type_name_decl;

    // Port -- NODOCS -- analysis_export #(T)
  //
  // The analysis_export provides the write method to all connected analysis
  // ports and parent exports:
  //
  //|  function void write (T t)
  //
  // Access via ports bound to this export is the normal mechanism for writing
  // to an analysis FIFO.
  // See write method of <uvm_tlm_if_base #(T1,T2)> for more information.

  uvm_analysis_imp!(T, uvm_tlm_analysis_fifo!T) analysis_export;


  // Function -- NODOCS -- new
  //
  // This is the standard uvm_component constructor. ~name~ is the local name
  // of this component. The ~parent~ should be left unspecified when this
  // component is instantiated in statically elaborated constructs and must be
  // specified when this component is a child of another UVM component.

  public this(string name=null,  uvm_component parent = null) {
    synchronized (this) {
      super(name, parent, 0); // analysis fifo must be unbounded
      analysis_export = new uvm_analysis_imp!(T, uvm_tlm_analysis_fifo!T)("analysis_export", this);
    }
  }

  public void write(T t) {
    this.try_put(t); // unbounded => must succeed
  }
}
