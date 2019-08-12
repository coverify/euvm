//
//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2014-2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2014-2018 NVIDIA Corporation
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

module uvm.tlm1.uvm_tlm_fifo_base;

import uvm.meta.misc;

import uvm.tlm1.uvm_imps;
import uvm.tlm1.uvm_analysis_port;

import uvm.base.uvm_component;
import uvm.base.uvm_component_defines;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_phase;

import esdl.base.core;

class uvm_tlm_event
{
  Event trigger;
  this() {
    synchronized (this) {
      trigger.initialize("trigger");
    }
  }
}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_tlm_fifo_base #(T)
//
// This class is the base for <uvm_tlm_fifo #(T)>. It defines the UVM TLM exports
// through which all transaction-based FIFO operations occur. It also defines
// default implementations for each inteface method provided by these exports.
//
// The interface methods provided by the <put_export> and the <get_peek_export>
// are defined and described by <uvm_tlm_if_base #(T1,T2)>.  See the UVM TLM Overview
// section 12.1 for a general discussion of UVM TLM interface definition and usage.
//
// Parameter type
//
// T - The type of transactions to be stored by this FIFO.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 12.2.8.1.1
abstract class uvm_tlm_fifo_base(T=int): uvm_component
{

  mixin uvm_abstract_component_essentials;

  enum string UVM_TLM_FIFO_TASK_ERROR =
    "fifo channel task not implemented";
  enum string UVM_TLM_FIFO_FUNCTION_ERROR =
    "fifo channel function not implemented";

  alias uvm_tlm_fifo_base!(T) this_type;

  mixin (uvm_sync_string);

  // Port -- NODOCS -- put_export
  //
  // The ~put_export~ provides both the blocking and non-blocking put interface
  // methods to any attached port:
  //
  //|  task put (input T t)
  //|  function bit can_put ()
  //|  function bit try_put (input T t)
  //
  // Any ~put~ port variant can connect and send transactions to the FIFO via this
  // export, provided the transaction types match. See <uvm_tlm_if_base #(T1,T2)>
  // for more information on each of the above interface methods.

  @uvm_immutable_sync
  private uvm_put_imp!(T, this_type) _put_export;


  // Port -- NODOCS -- get_peek_export
  //
  // The ~get_peek_export~ provides all the blocking and non-blocking get and peek
  // interface methods:
  //
  //|  task get (output T t)
  //|  function bit can_get ()
  //|  function bit try_get (output T t)
  //|  task peek (output T t)
  //|  function bit can_peek ()
  //|  function bit try_peek (output T t)
  //
  // Any ~get~ or ~peek~ port variant can connect to and retrieve transactions from
  // the FIFO via this export, provided the transaction types match. See
  // <uvm_tlm_if_base #(T1,T2)> for more information on each of the above interface
  // methods.

  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _get_peek_export;


  // Port -- NODOCS -- put_ap
  //
  // Transactions passed via ~put~ or ~try_put~ (via any port connected to the
  // <put_export>) are sent out this port via its ~write~ method.
  //
  //|  function void write (T t)
  //
  // All connected analysis exports and imps will receive put transactions.
  // See <uvm_tlm_if_base #(T1,T2)> for more information on the ~write~ interface
  // method.

  @uvm_immutable_sync
  private uvm_analysis_port!(T) _put_ap;


  // Port -- NODOCS -- get_ap
  //
  // Transactions passed via ~get~, ~try_get~, ~peek~, or ~try_peek~ (via any
  // port connected to the <get_peek_export>) are sent out this port via its
  // ~write~ method.
  //
  //|  function void write (T t)
  //
  // All connected analysis exports and imps will receive get transactions.
  // See <uvm_tlm_if_base #(T1,T2)> for more information on the ~write~ method.

  @uvm_immutable_sync
  private uvm_analysis_port!(T) _get_ap;


  // The following are aliases to the above put_export.

  @uvm_immutable_sync
  private uvm_put_imp!(T, this_type) _blocking_put_export;
  @uvm_immutable_sync
  private uvm_put_imp!(T, this_type) _nonblocking_put_export;

  // The following are all aliased to the above get_peek_export, which provides
  // the superset of these interfaces.

  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _blocking_get_export;
  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _nonblocking_get_export;
  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _get_export;

  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _blocking_peek_export;
  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _nonblocking_peek_export;
  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _peek_export;

  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _blocking_get_peek_export;
  @uvm_immutable_sync
  private uvm_get_peek_imp!(T, this_type) _nonblocking_get_peek_export;


  // Function -- NODOCS -- new
  //
  // The ~name~ and ~parent~ are the normal uvm_component constructor arguments.
  // The ~parent~ should be null if the uvm_tlm_fifo is going to be used in a
  // statically elaborated construct (e.g., a module). The ~size~ indicates the
  // maximum size of the FIFO. A value of zero indicates no upper bound.

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.7
  // @uvm-ieee 1800.2-2017 auto 12.2.8.2.1
  // @uvm-ieee 1800.2-2017 auto 12.2.8.3.2
  public this(string name = null, uvm_component parent = null) {
    synchronized (this) {
      super(name, parent);

      _put_export = new uvm_put_imp!(T, this_type) ("put_export", this);
      _blocking_put_export     = put_export;
      _nonblocking_put_export  = put_export;

      _get_peek_export = new uvm_get_peek_imp!(T, this_type)("get_peek_export",
							     this);
      _blocking_get_peek_export    = get_peek_export;
      _nonblocking_get_peek_export = get_peek_export;
      _blocking_get_export         = get_peek_export;
      _nonblocking_get_export      = get_peek_export;
      _get_export                  = get_peek_export;
      _blocking_peek_export        = get_peek_export;
      _nonblocking_peek_export     = get_peek_export;
      _peek_export                 = get_peek_export;

      _put_ap = new uvm_analysis_port!(T)("put_ap", this);
      _get_ap = new uvm_analysis_port!(T)("get_ap", this);

    }
  }

  //turn off auto config
  override bool use_automatic_config() {
    return false;
  }
   
  // @uvm-ieee 1800.2-2017 auto 12.2.8.2.6
  override public void flush() {
    uvm_report_error("flush", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.2.2
  public size_t size() {
    uvm_report_error("size", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // task
  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.3
  public void put(T t) {
    uvm_report_error("put", UVM_TLM_FIFO_TASK_ERROR, uvm_verbosity.UVM_NONE);
  }

  // task
  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.4
  public void get(out T t) {
    uvm_report_error("get", UVM_TLM_FIFO_TASK_ERROR, uvm_verbosity.UVM_NONE);
  }

  // task
  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.4
  public void peek(out T t) {
    uvm_report_error("peek", UVM_TLM_FIFO_TASK_ERROR, uvm_verbosity.UVM_NONE);
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.3
  public bool try_put(T t) {
    uvm_report_error("try_put", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.4
  public bool try_get(out T t) {
    uvm_report_error("try_get", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.4
  public bool try_peek(out T t) {
    uvm_report_error("try_peek", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.3
  public bool can_put() {
    uvm_report_error("can_put", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.4
  public bool can_get() {
    uvm_report_error("can_get", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.1.4
  public bool can_peek() {
    uvm_report_error("can_peek", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  public uvm_tlm_event ok_to_put() {
    uvm_report_error("ok_to_put", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return null;
  }

  public uvm_tlm_event ok_to_get() {
    uvm_report_error("ok_to_get", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return null;
  }

  public uvm_tlm_event ok_to_peek() {
    uvm_report_error("ok_to_peek", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return null;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.2.4
  public bool is_empty() {
    uvm_report_error("is_empty", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.2.5
  public bool is_full() {
    uvm_report_error("is_full", UVM_TLM_FIFO_FUNCTION_ERROR);
    return 0;
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.8.2.3
  public size_t used() {
    uvm_report_error("used", UVM_TLM_FIFO_FUNCTION_ERROR, uvm_verbosity.UVM_NONE);
    return 0;
  }

}
