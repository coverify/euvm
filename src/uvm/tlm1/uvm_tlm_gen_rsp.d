//
//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Synopsys, Inc.
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
//----------------------------------------------------------------------


//------------------------------------------------------------------------------
// Title -- NODOCS -- UVM TLM Channel Classes
//------------------------------------------------------------------------------
// This section defines built-in UVM TLM channel classes.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_tlm_gen_rsp_channel #(RSP)
//
// The uvm_tlm_gen_rsp_channel contains a generate FIFO of type ~RSP~ and a response
// FIFO of type ~RSP~. These FIFOs can be of any size. This channel is
// particularly useful for dealing with pipelined protocols where the generate
// and response are not tightly coupled.
//
// Type parameters:
//
// RSP - Type of the reponse transactions conveyed by this channel.
//
//------------------------------------------------------------------------------

module uvm.tlm1.uvm_tlm_gen_rsp;
import uvm.meta.meta;		// qualifiedTypeName

import uvm.tlm1.uvm_imps;
import uvm.tlm1.uvm_exports;
import uvm.tlm1.uvm_analysis_port;
import uvm.tlm1.uvm_tlm_fifos;

import uvm.base;

import esdl.rand.misc: rand;

// @uvm-ieee 1800.2-2017 auto 12.2.9.1.1
class uvm_tlm_gen_rsp_channel(RSP): uvm_component, rand.disable
{
  mixin uvm_component_essentials;
  
  // Port -- NODOCS -- get_peek_response_export
  //
  // The get_peek_response_export provides all the blocking and non-blocking get
  // and peek interface methods to the response FIFO:
  //
  //|  task get (output T t);
  //|  function bit can_get ();
  //|  function bit try_get (output T t);
  //|  task peek (output T t);
  //|  function bit can_peek ();
  //|  function bit try_peek (output T t);
  //
  // Any get or peek port variant can connect to and retrieve transactions from
  // the response FIFO via this export, provided the transaction types match.

  uvm_get_peek_export!(RSP) get_peek_response_export;

  alias get_export                           = get_peek_response_export;
  alias get_response_export                  = get_peek_response_export;
  alias blocking_get_response_export         = get_peek_response_export;
  alias nonblocking_get_response_export      = get_peek_response_export;
  alias peek_response_export                 = get_peek_response_export;
  alias blocking_peek_response_export        = get_peek_response_export;
  alias nonblocking_peek_response_export     = get_peek_response_export;
  alias blocking_get_peek_response_export    = get_peek_response_export;
  alias nonblocking_get_peek_response_export = get_peek_response_export;


  // Port -- NODOCS -- get_peek_generate_export
  //
  // The get_peek_generate_export provides all the blocking and non-blocking get and peek
  // interface methods to the response FIFO:
  //
  //|  task get (output T t);
  //|  function bit can_get ();
  //|  function bit try_get (output T t);
  //|  task peek (output T t);
  //|  function bit can_peek ();
  //|  function bit try_peek (output T t);
  //
  // Any get or peek port variant can connect to and retrieve transactions from
  // the response FIFO via this export, provided the transaction types match.


  uvm_get_peek_export!(RSP) get_peek_generate_export;

  alias gen_export                           = get_peek_generate_export;
  alias get_generate_export                  = get_peek_generate_export;
  alias blocking_get_generate_export         = get_peek_generate_export;
  alias nonblocking_get_generate_export      = get_peek_generate_export;
  alias peek_generate_export                 = get_peek_generate_export;
  alias blocking_peek_generate_export        = get_peek_generate_export;
  alias nonblocking_peek_generate_export     = get_peek_generate_export;
  alias blocking_get_peek_generate_export    = get_peek_generate_export;
  alias nonblocking_get_peek_generate_export = get_peek_generate_export;

  // Port -- NODOCS -- put_response_export
  //
  // The put_export provides both the blocking and non-blocking put interface
  // methods to the response FIFO:
  //
  //|  task put (input T t);
  //|  function bit can_put ();
  //|  function bit try_put (input T t);
  //
  // Any put port variant can connect and send transactions to the response FIFO
  // via this export, provided the transaction types match.

  uvm_put_export!(RSP) put_response_export;

  alias put_export                           = put_response_export;
  alias blocking_put_response_export         = put_response_export;
  alias nonblocking_put_response_export      = put_response_export;

  // Port -- NODOCS -- response_ap
  //
  // Transactions passed via ~put~ or ~try_put~ (via any port connected to the
  // put_response_export) are sent out this port via its write method.
  //
  //|  function void write (T t);
  //
  // All connected analysis exports and imps will receive these transactions.

  uvm_analysis_port!(RSP) response_ap;


  // Port -- NODOCS -- slave_export
  //
  // Exports a single interface that allows a slave to get or peek generates and
  // to put responses. It is a combination of the get_peek_generate_export
  // and put_response_export.

  uvm_slave_imp!(RSP, RSP, this_type,
		 uvm_tlm_async_push_fifo!RSP,
		 uvm_tlm_async_pull_fifo!RSP) slave_export;

  alias blocking_slave_export     = slave_export;
  alias nonblocking_slave_export  = slave_export;

  // internal fifos
  protected uvm_tlm_async_push_fifo!(RSP) m_generate_fifo;
  protected uvm_tlm_async_pull_fifo!(RSP) m_response_fifo;


  // Function -- NODOCS -- new
  //
  // The ~name~ and ~parent~ are the standard <uvm_component> constructor arguments.
  // The ~parent~ must be null if this component is defined within a static
  // component such as a module, program block, or interface. The last two
  // arguments specify the generate and response FIFO sizes, which have default
  // values of 1.

  // @uvm-ieee 1800.2-2017 auto 12.2.9.1.11
  this(string name=null, uvm_component parent=null,
       int generate_fifo_size=1,
       int response_fifo_size=1) {
    synchronized (this) {
      super(name, parent);

      m_generate_fifo  = new uvm_tlm_async_push_fifo!(RSP)
	("generate_fifo",  this, generate_fifo_size);

      m_response_fifo = new uvm_tlm_async_pull_fifo!(RSP)
	("response_fifo", this, response_fifo_size);

      response_ap     = new uvm_analysis_port!(RSP)
	("response_ap", this);

      get_peek_generate_export  = new uvm_get_peek_export!(RSP)
	("get_peek_generate_export",  this);

      put_response_export      = new uvm_put_export!(RSP)
	("put_response_export",      this);

      get_peek_response_export = new uvm_get_peek_export!(RSP)
	("get_peek_response_export", this);

      slave_export = new uvm_slave_imp!(RSP, RSP, this_type,
					uvm_tlm_async_push_fifo!RSP,
					uvm_tlm_async_pull_fifo!RSP)
	("slave_export",  this, m_generate_fifo, m_response_fifo);

      // This function is defined in the base class uvm_component
      set_report_id_action_hier(s_connection_error_id, uvm_action_type.UVM_NO_ACTION);

    }
  }

  override void connect_phase(uvm_phase phase) {
    synchronized (this) {
      // put_generate_export.connect       (m_generate_fifo.put_export);
      get_peek_generate_export.connect  (m_generate_fifo.get_peek_export);
      // m_generate_fifo.put_ap.connect    (generate_ap);
      put_response_export.connect       (m_response_fifo.put_export);
      get_peek_response_export.connect  (m_response_fifo.get_peek_export);
      m_response_fifo.put_ap.connect    (response_ap);
    }
  }

  override void run_phase(uvm_phase phase) {
    while (true) {
      auto rsp = new RSP(this.get_name() ~ "/rsp");
      m_generate_fifo.put(rsp);
    }
  }

}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_tlm_transport_channel #(REQ,RSP)
//
// A uvm_tlm_transport_channel is a <uvm_tlm_req_rsp_channel #(REQ,RSP)> that implements
// the transport interface. It is useful when modeling a non-pipelined bus at
// the transaction level. Because the requests and responses have a tightly
// coupled one-to-one relationship, the request and response FIFO sizes are both
// set to one.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 12.2.9.2.1
class uvm_tlm_transport_channel(REQ, RSP=REQ):
  uvm_tlm_req_rsp_channel!(REQ, RSP), rand.disable
{

  mixin uvm_component_essentials;
  
  alias this_type = uvm_tlm_transport_channel!(REQ, RSP);

  // Port -- NODOCS -- transport_export
  //
  // The put_export provides both the blocking and non-blocking transport
  // interface methods to the response FIFO:
  //
  //|  task transport(REQ request, output RSP response);
  //|  function bit nb_transport(REQ request, output RSP response);
  //
  // Any transport port variant can connect to and send requests and retrieve
  // responses via this export, provided the transaction types match. Upon
  // return, the response argument carries the response to the request.

  uvm_transport_imp!(REQ, RSP, this_type) transport_export;


  // Function -- NODOCS -- new
  //
  // The ~name~ and ~parent~ are the standard <uvm_component> constructor
  // arguments. The ~parent~ must be ~null~ if this component is defined within a
  // statically elaborated construct such as a module, program block, or
  // interface.

  // @uvm-ieee 1800.2-2017 auto 12.2.9.2.3
  this(string name, uvm_component parent=null) {
    synchronized (this) {
      super(name, parent, true, true);
      transport_export =
	new uvm_transport_imp!(REQ, RSP, this_type)("transport_export", this);
    }
  }

  // task
  // @uvm-ieee 1800.2-2017 auto 12.2.9.2.2
  void transport(REQ request, out RSP response) {
    this.m_request_fifo.put(request);
    this.m_response_fifo.get(response);
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.9.2.2
  bool nb_transport(REQ req, out RSP rsp) {
    synchronized (this) {
    if (this.m_request_fifo.try_put(req))
      return this.m_response_fifo.try_get(rsp);
    else
      return false;
    }
  }
}

class uvm_tlm_gen_rsp_vpi_channel(RSP):
  uvm_component, rand.disable
{
  mixin uvm_component_essentials;

  alias this_type = uvm_tlm_gen_rsp_vpi_channel!(RSP);

  enum string type_name = qualifiedTypeName!this_type;

  // Port -- NODOCS -- get_peek_response_export
  //
  // The get_peek_response_export provides all the blocking and non-blocking get
  // and peek interface methods to the response FIFO:
  //
  //|  task get (output T t);
  //|  function bit can_get ();
  //|  function bit try_get (output T t);
  //|  task peek (output T t);
  //|  function bit can_peek ();
  //|  function bit try_peek (output T t);
  //
  // Any get or peek port variant can connect to and retrieve transactions from
  // the response FIFO via this export, provided the transaction types match.

  uvm_get_peek_export!(RSP) get_peek_response_export;

  alias get_export                           = get_peek_response_export;
  alias get_response_export                  = get_peek_response_export;
  alias blocking_get_response_export         = get_peek_response_export;
  alias nonblocking_get_response_export      = get_peek_response_export;
  alias peek_response_export                 = get_peek_response_export;
  alias blocking_peek_response_export        = get_peek_response_export;
  alias nonblocking_peek_response_export     = get_peek_response_export;
  alias blocking_get_peek_response_export    = get_peek_response_export;
  alias nonblocking_get_peek_response_export = get_peek_response_export;


  // Port -- NODOCS -- get_peek_generate_export
  //
  // The get_peek_generate_export provides all the blocking and non-blocking get and peek
  // interface methods to the response FIFO:
  //
  //|  task get (output T t);
  //|  function bit can_get ();
  //|  function bit try_get (output T t);
  //|  task peek (output T t);
  //|  function bit can_peek ();
  //|  function bit try_peek (output T t);
  //
  // Any get or peek port variant can connect to and retrieve transactions from
  // the response FIFO via this export, provided the transaction types match.


  uvm_get_peek_export!(RSP) get_peek_generate_export;

  alias gen_export                           = get_peek_generate_export;
  alias get_generate_export                  = get_peek_generate_export;
  alias blocking_get_generate_export         = get_peek_generate_export;
  alias nonblocking_get_generate_export      = get_peek_generate_export;
  alias peek_generate_export                 = get_peek_generate_export;
  alias blocking_peek_generate_export        = get_peek_generate_export;
  alias nonblocking_peek_generate_export     = get_peek_generate_export;
  alias blocking_get_peek_generate_export    = get_peek_generate_export;
  alias nonblocking_get_peek_generate_export = get_peek_generate_export;

  // Port -- NODOCS -- put_response_export
  //
  // The put_export provides both the blocking and non-blocking put interface
  // methods to the response FIFO:
  //
  //|  task put (input T t);
  //|  function bit can_put ();
  //|  function bit try_put (input T t);
  //
  // Any put port variant can connect and send transactions to the response FIFO
  // via this export, provided the transaction types match.

  uvm_put_export!(RSP) put_response_export;

  alias put_export                           = put_response_export;
  alias blocking_put_response_export         = put_response_export;
  alias nonblocking_put_response_export      = put_response_export;

  // Port -- NODOCS -- response_ap
  //
  // Transactions passed via ~put~ or ~try_put~ (via any port connected to the
  // put_response_export) are sent out this port via its write method.
  //
  //|  function void write (T t);
  //
  // All connected analysis exports and imps will receive these transactions.

  uvm_analysis_port!(RSP) response_ap;


  // Port -- NODOCS -- slave_export
  //
  // Exports a single interface that allows a slave to get or peek generates and
  // to put responses. It is a combination of the get_peek_generate_export
  // and put_response_export.

  uvm_slave_imp!(RSP, RSP, this_type,
		 uvm_tlm_vpi_push_fifo!RSP,
		 uvm_tlm_vpi_pull_fifo!RSP) slave_export;

  alias blocking_slave_export     = slave_export;
  alias nonblocking_slave_export  = slave_export;

  // internal fifos
  protected uvm_tlm_vpi_push_fifo!(RSP) m_generate_fifo;
  protected uvm_tlm_vpi_pull_fifo!(RSP) m_response_fifo;


  // Function -- NODOCS -- new
  //
  // The ~name~ and ~parent~ are the standard <uvm_component> constructor arguments.
  // The ~parent~ must be null if this component is defined within a static
  // component such as a module, program block, or interface. The last two
  // arguments specify the generate and response FIFO sizes, which have default
  // values of 1.

  this(string name=null, uvm_component parent=null,
       int generate_fifo_size=1,
       int response_fifo_size=1) {
    synchronized (this) {
      super(name, parent);

      m_generate_fifo  = new uvm_tlm_vpi_push_fifo!(RSP)
	("generate_fifo",  this, generate_fifo_size);

      m_response_fifo = new uvm_tlm_vpi_pull_fifo!(RSP)
	("response_fifo", this, response_fifo_size);

      response_ap     = new uvm_analysis_port!(RSP)
	("response_ap", this);

      get_peek_generate_export  = new uvm_get_peek_export!(RSP)
	("get_peek_generate_export",  this);

      put_response_export      = new uvm_put_export!(RSP)
	("put_response_export",      this);

      get_peek_response_export = new uvm_get_peek_export!(RSP)
	("get_peek_response_export", this);

      slave_export = new uvm_slave_imp!(RSP, RSP, this_type,
					uvm_tlm_vpi_push_fifo!RSP,
					uvm_tlm_vpi_pull_fifo!RSP)
	("slave_export",  this, m_generate_fifo, m_response_fifo);

      // This function is defined in the base class uvm_component
      set_report_id_action_hier(s_connection_error_id, uvm_action_type.UVM_NO_ACTION);

    }
  }

  override void connect_phase(uvm_phase phase) {
    synchronized (this) {
      // put_generate_export.connect       (m_generate_fifo.put_export);
      get_peek_generate_export.connect  (m_generate_fifo.get_peek_export);
      // m_generate_fifo.put_ap.connect    (generate_ap);
      put_response_export.connect       (m_response_fifo.put_export);
      get_peek_response_export.connect  (m_response_fifo.get_peek_export);
      m_response_fifo.put_ap.connect    (response_ap);
    }
  }

  override void run_phase(uvm_phase phase) {
    while (true) {
      auto rsp = new RSP(this.get_name() ~ "/rsp");
      m_generate_fifo.put(rsp);
    }
  }

}
