//
//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2010-2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2015-2018 NVIDIA Corporation
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

//------------------------------------------------------------------------------
// Title -- NODOCS -- UVM TLM Export Classes
//------------------------------------------------------------------------------
// The following classes define the UVM TLM export classes.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_*_export #(T)
//
// The unidirectional uvm_*_export is a port that ~forwards~ or ~promotes~
// an interface implementation from a child component to its parent.
// An export can be connected to any compatible child export or imp port.
// It must ultimately be connected to at least one implementation
// of its associated interface.
//
// The interface type represented by the asterisk is any of the following
//
//|  blocking_put
//|  nonblocking_put
//|  put
//|
//|  blocking_get
//|  nonblocking_get
//|  get
//|
//|  blocking_peek
//|  nonblocking_peek
//|  peek
//|
//|  blocking_get_peek
//|  nonblocking_get_peek
//|  get_peek
//
// Type parameters
//
// T - The type of transaction to be communicated by the export
//
// Exports are connected to interface implementations directly via
// <uvm_*_imp #(T,IMP)> ports or indirectly via other <uvm_*_export #(T)> exports.
//
//------------------------------------------------------------------------------


// Function -- NODOCS -- new
//
// The ~name~ and ~parent~ are the standard <uvm_component> constructor arguments.
// The ~min_size~ and ~max_size~ specify the minimum and maximum number of
// interfaces that must have been supplied to this port by the end of elaboration.
//
//|  function new (string name,
//|                uvm_component parent,
//|                int min_size=1,
//|                int max_size=1)

module uvm.tlm1.uvm_exports;
import uvm.tlm1.uvm_tlm_ifs;
import uvm.tlm1.uvm_tlm_defines;

import uvm.base.uvm_port_base;
import uvm.base.uvm_component;
import uvm.base.uvm_object_globals;

import esdl.rand.misc: _esdl__Norand;

class uvm_blocking_put_export(T=int): uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_PUT_MASK,"uvm_blocking_put_export")
  // `UVM_BLOCKING_PUT_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_BLOCKING_PUT_MASK;
    }
  }
  string get_type_name() {
    return "uvm_blocking_put_export";
  }

  // task
  void put (T t) {
    m_if.put(t);
  }
}

class uvm_nonblocking_put_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_PUT_MASK,"uvm_nonblocking_put_export")
  // `UVM_NONBLOCKING_PUT_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NONBLOCKING_PUT_MASK;
    }
  }

  string get_type_name() {
    return "uvm_nonblocking_put_export";
  }

  bool try_put (T t) {
    return m_if.try_put(t);
  }

  bool can_put() {
    return m_if.can_put();
  }
}

class uvm_put_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_PUT_MASK,"uvm_put_export")
  // `UVM_PUT_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_PUT_MASK;
    }
  }
  override string get_type_name() {
    return "uvm_put_export";
  }

  // task
  override void put(T t) {
    m_if.put(t);
  }

  override bool try_put (T t) {
    return m_if.try_put(t);
  }

  override bool can_put() {
    return m_if.can_put();
  }
}

class uvm_blocking_get_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_GET_MASK,"uvm_blocking_get_export")
  // `UVM_BLOCKING_GET_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
    m_if_mask = UVM_TLM_BLOCKING_GET_MASK;
  }

  string get_type_name() {
    return "uvm_blocking_get_export";
  }

  // task
  void get (out T t) {
    m_if.get(t);
  }

}

class uvm_nonblocking_get_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_GET_MASK,"uvm_nonblocking_get_export")
  // `UVM_NONBLOCKING_GET_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
    m_if_mask = UVM_TLM_NONBLOCKING_GET_MASK;
  }

  string get_type_name() {
    return "uvm_nonblocking_get_export";
  }

  bool try_get (out T t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    return m_if.can_get();
  }
}

class uvm_get_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_GET_MASK,"uvm_get_export")
  // `UVM_GET_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_GET_MASK;
    }
  }

  string get_type_name() {
    return "uvm_get_export";
  }

  // task
  void get (out T t) {
    m_if.get(t);
  }

  bool try_get (out T t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    return m_if.can_get();
  }
}

class uvm_blocking_peek_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_PEEK_MASK,"uvm_blocking_peek_export")
  // `UVM_BLOCKING_PEEK_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_BLOCKING_PEEK_MASK;
    }
  }

  string get_type_name() {
    return "uvm_blocking_peek_export";
  }

  // task
  void peek (out T t) {
    m_if.peek(t);
  }
}

class uvm_nonblocking_peek_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_PEEK_MASK,"uvm_nonblocking_peek_export")
  // `UVM_NONBLOCKING_PEEK_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NONBLOCKING_PEEK_MASK;
    }
  }

  string get_type_name() {
    return "uvm_nonblocking_peek_export";
  }

  bool try_peek (out T t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }
}

class uvm_peek_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_PEEK_MASK,"uvm_peek_export")
  // `UVM_PEEK_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_PEEK_MASK;
    }
  }

  string get_type_name() {
    return "uvm_peek_export";
  }

  // task
  void peek (out T t) {
    m_if.peek(t);
  }

  bool try_peek (out T t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }

}

class uvm_blocking_get_peek_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_GET_PEEK_MASK,"uvm_blocking_get_peek_export")
  // `UVM_BLOCKING_GET_PEEK_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_BLOCKING_GET_PEEK_MASK;
    }
  }

  string get_type_name() {
    return "uvm_blocking_get_peek_export";
  }


  // task
  void get (out T t) {
    m_if.get(t);
  }

  // task
  void peek (out T t) {
    m_if.peek(t);
  }
}

class uvm_nonblocking_get_peek_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_GET_PEEK_MASK,"uvm_nonblocking_get_peek_export")
  // `UVM_NONBLOCKING_GET_PEEK_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NONBLOCKING_GET_PEEK_MASK;
    }
  }

  string get_type_name() {
    return "uvm_nonblocking_get_peek_export";
  }

  bool try_get (out T t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    return m_if.can_get();
  }

  bool try_peek (out T t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }

}

class uvm_get_peek_export(T=int):
  uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_GET_PEEK_MASK,"uvm_get_peek_export")
  // `UVM_GET_PEEK_IMP (this.m_if, T, t)
  this(string name=null, uvm_component parent=null,
       int min_size=1, int max_size=1) {
    synchronized (this) {
      super (name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_GET_PEEK_MASK;
    }
  }

  override string get_type_name() {
    return "uvm_get_peek_export";
  }

  // task
  override void get (out T t) {
    m_if.get(t);
  }

  // task
  override void peek (out T t) {
    m_if.peek(t);
  }

  override bool try_get (out T t) {
    return m_if.try_get(t);
  }

  override bool can_get() {
    return m_if.can_get();
  }

  override bool try_peek (out T t) {
    return m_if.try_peek(t);
  }

  override bool can_peek() {
    return m_if.can_peek();
  }

}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_*_export #(REQ,RSP)
//
// The bidirectional uvm_*_export is a port that ~forwards~ or ~promotes~
// an interface implementation from a child component to its parent.
// An export can be connected to any compatible child export or imp port.
// It must ultimately be connected to at least one implementation
// of its associated interface.
//
// The interface type represented by the asterisk is any of the following
//
//|  blocking_transport
//|  nonblocking_transport
//|  transport
//|
//|  blocking_master
//|  nonblocking_master
//|  master
//|
//|  blocking_slave
//|  nonblocking_slave
//|  slave
//
// Type parameters
//
// REQ - The type of request transaction to be communicated by the export
//
// RSP - The type of response transaction to be communicated by the export
//
// Exports are connected to interface implementations directly via
// <uvm_*_imp #(REQ, RSP, IMP, REQ_IMP, RSP_IMP)> ports or indirectly via other
// <uvm_*_export #(REQ,RSP)> exports.
//
//------------------------------------------------------------------------------

// Function -- NODOCS -- new
//
// The ~name~ and ~parent~ are the standard <uvm_component> constructor arguments.
// The ~min_size~ and ~max_size~ specify the minimum and maximum number of
// interfaces that must have been supplied to this port by the end of elaboration.
//
//|  function new (string name,
//|                uvm_component parent,
//|                int min_size=1,
//|                int max_size=1)


class uvm_blocking_master_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(REQ, RSP)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_MASTER_MASK,"uvm_blocking_master_export")
  // `UVM_BLOCKING_PUT_IMP (this.m_if, REQ, t)
  // `UVM_BLOCKING_GET_PEEK_IMP (this.m_if, RSP, t)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_BLOCKING_MASTER_MASK;
    }
  }

  string get_type_name() {
    return "uvm_blocking_master_export";
  }

  // task
  void put (REQ t) {
    m_if.put(t);
  }

  // task
  void get (out RSP t) {
    m_if.get(t);
  }

  // task
  void peek (out RSP t) {
    m_if.peek(t);
  }
}

class uvm_nonblocking_master_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(REQ, RSP)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_MASTER_MASK,"uvm_nonblocking_master_export")
  // `UVM_NONBLOCKING_PUT_IMP (this.m_if, REQ, t)
  // `UVM_NONBLOCKING_GET_PEEK_IMP (this.m_if, RSP, t)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NONBLOCKING_MASTER_MASK;
    }
  }

  string get_type_name() {
    return "uvm_nonblocking_master_export";
  }

  bool try_put (REQ t) {
    return m_if.try_put(t);
  }

  bool can_put() {
    return m_if.can_put();
  }

  bool try_get (out RSP t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    return m_if.can_get();
  }

  bool try_peek (out RSP t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }
}

class uvm_master_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(REQ, RSP)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_MASTER_MASK,"uvm_master_export")
  // `UVM_PUT_IMP (this.m_if, REQ, t)
  // `UVM_GET_PEEK_IMP (this.m_if, RSP, t)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_MASTER_MASK;
    }
  }

  string get_type_name() {
    return "uvm_master_export";
  }

  // task
  void put (REQ t) {
    m_if.put(t);
  }

  bool try_put (REQ t) {
    return m_if.try_put(t);
  }

  bool can_put() {
    return m_if.can_put();
  }

  // task
  void get (out RSP t) {
    m_if.get(t);
  }

  // task
  void peek (out RSP t) {
    m_if.peek(t);
  }

  bool try_get (out RSP t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    return m_if.can_get();
  }

  bool try_peek (out RSP t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }
}

class uvm_blocking_slave_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(RSP, REQ)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_SLAVE_MASK,"uvm_blocking_slave_export")
  // `UVM_BLOCKING_PUT_IMP (this.m_if, RSP, t)
  // `UVM_BLOCKING_GET_PEEK_IMP (this.m_if, REQ, t)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_BLOCKING_SLAVE_MASK;
    }
  }

  string get_type_name() {
    return "uvm_blocking_slave_export";
  }

  // task
  void put (RSP t) {
    m_if.put(t);
  }

  // task
  void get (out REQ t) {
    m_if.get(t);
  }

  // task
  void peek (out REQ t) {
    m_if.peek(t);
  }
}

class uvm_nonblocking_slave_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(RSP, REQ)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_SLAVE_MASK,"uvm_nonblocking_slave_export")
  // `UVM_NONBLOCKING_PUT_IMP (this.m_if, RSP, t)
  // `UVM_NONBLOCKING_GET_PEEK_IMP (this.m_if, REQ, t)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NONBLOCKING_SLAVE_MASK;
    }
  }

  string get_type_name() {
    return "uvm_nonblocking_slave_export";
  }

  bool try_put (RSP t) {
    return m_if.try_put(t);
  }

  bool can_put() {
    uvm_port_base!(uvm_tlm_if_base!(T,T)) _m_if;
    return m_if.can_put();
  }

  bool try_get (out REQ t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    return m_if.can_get();
  }

  bool try_peek (out REQ t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }
}

class uvm_slave_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(RSP, REQ)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_SLAVE_MASK,"uvm_slave_export")
  // `UVM_PUT_IMP (this.m_if, RSP, t)
  // `UVM_GET_PEEK_IMP (this.m_if, REQ, t)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_SLAVE_MASK;
    }
  }

  string get_type_name() {
    return "uvm_slave_export";
  }

  // task
  void put (RSP t) {
    m_if.put(t);
  }

  bool try_put (RSP t) {
    return m_if.try_put(t);
  }

  bool can_put() {
    return m_if.can_put();
  }

  // task
  void get (out REQ t) {
    m_if.get(t);
  }

  // task
  void peek (out REQ t) {
    m_if.peek(t);
  }

  bool try_get (out REQ t) {
    return m_if.try_get(t);
  }

  bool can_get() {
    m_if.can_get();
  }

  bool try_peek (out REQ t) {
    return m_if.try_peek(t);
  }

  bool can_peek() {
    return m_if.can_peek();
  }
}


class uvm_blocking_transport_export (REQ=int, RSP=REQ):
  uvm_port_base!(uvm_tlm_if_base !(REQ, RSP)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_BLOCKING_TRANSPORT_MASK,"uvm_blocking_transport_export")
  // `UVM_BLOCKING_TRANSPORT_IMP (this.m_if, REQ, RSP, req, rsp)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_BLOCKING_TRANSPORT_MASK;
    }
  }

  string get_type_name() {
    return "uvm_blocking_transport_export";
  }

  // task
  void transport (REQ req, out RSP rsp) {
    m_if.transport(req, rsp);
  }
}

class uvm_nonblocking_transport_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(REQ, RSP)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_NONBLOCKING_TRANSPORT_MASK,"uvm_nonblocking_transport_export")
  // `UVM_NONBLOCKING_TRANSPORT_IMP (this.m_if, REQ, RSP, req, rsp)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NONBLOCKING_TRANSPORT_MASK;
    }
  }

  string get_type_name() {
    return "uvm_nonblocking_transport_export";
  }

  bool nb_transport (REQ req, out RSP rsp) {
    return m_if.nb_transport(req, rsp);
  }
}

class uvm_transport_export (REQ=int, RSP=REQ):
  uvm_port_base !(uvm_tlm_if_base !(REQ, RSP)), _esdl__Norand
{
  // `UVM_EXPORT_COMMON(`UVM_TLM_TRANSPORT_MASK,"uvm_transport_export")
  // `UVM_TRANSPORT_IMP (this.m_if, REQ, RSP, req, rsp)
  this (string name=null, uvm_component parent=null,
	int min_size=1, int max_size=1) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_TRANSPORT_MASK;
    }
  }

  string get_type_name() {
    return "uvm_transport_export";
  }

  // task
  void transport (REQ req, out RSP rsp) {
    m_if.transport(req, rsp);
  }

  bool nb_transport (REQ req, out RSP rsp) {
    return m_if.nb_transport(req, rsp);
  }
}
