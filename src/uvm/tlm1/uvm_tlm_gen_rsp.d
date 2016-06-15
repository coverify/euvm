//
//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
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


//------------------------------------------------------------------------------
// Title: TLM Channel Classes
//------------------------------------------------------------------------------
// This section defines built-in TLM channel classes.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
// CLASS: uvm_tlm_gen_rsp_channel #(RSP)
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

import uvm.base.uvm_port_base;
import uvm.base.uvm_component;
import uvm.base.uvm_object;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_phase;


class uvm_tlm_gen_rsp_channel(RSP): uvm_component
{
  mixin uvm_component_essentials;
  
  alias this_type = uvm_tlm_gen_rsp_channel!(RSP);

  enum string type_name = qualifiedTypeName!this_type;

  // Port: get_peek_response_export
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


  // Port: get_peek_generate_export
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

  // Port: put_response_export
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

  // Port: response_ap
  //
  // Transactions passed via ~put~ or ~try_put~ (via any port connected to the
  // put_response_export) are sent out this port via its write method.
  //
  //|  function void write (T t);
  //
  // All connected analysis exports and imps will receive these transactions.

  uvm_analysis_port!(RSP) response_ap;


  // Port: slave_export
  //
  // Exports a single interface that allows a slave to get or peek generates and
  // to put responses. It is a combination of the get_peek_generate_export
  // and put_response_export.

  uvm_slave_imp!(RSP, RSP, this_type,
		 uvm_tlm_fifo_egress!RSP,
		 uvm_tlm_fifo_ingress!RSP) slave_export;

  alias blocking_slave_export     = slave_export;
  alias nonblocking_slave_export  = slave_export;

  // internal fifos
  protected uvm_tlm_fifo_egress!(RSP) m_generate_fifo;
  protected uvm_tlm_fifo_ingress!(RSP) m_response_fifo;


  // Function: new
  //
  // The ~name~ and ~parent~ are the standard <uvm_component> constructor arguments.
  // The ~parent~ must be null if this component is defined within a static
  // component such as a module, program block, or interface. The last two
  // arguments specify the generate and response FIFO sizes, which have default
  // values of 1.

  this(string name=null, uvm_component parent=null,
       int generate_fifo_size=1,
       int response_fifo_size=1) {
    synchronized(this) {
      super(name, parent);

      m_generate_fifo  = new uvm_tlm_fifo_egress!(RSP)
	("generate_fifo",  this, generate_fifo_size);

      m_response_fifo = new uvm_tlm_fifo_ingress!(RSP)
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
					uvm_tlm_fifo_egress!RSP,
					uvm_tlm_fifo_ingress!RSP)
	("slave_export",  this, m_generate_fifo, m_response_fifo);

      // This function is defined in the base class uvm_component
      set_report_id_action_hier(s_connection_error_id, UVM_NO_ACTION);

    }
  }

  override void connect_phase(uvm_phase phase) {
    synchronized(this) {
      // put_generate_export.connect       (m_generate_fifo.put_export);
      get_peek_generate_export.connect  (m_generate_fifo.get_peek_export);
      // m_generate_fifo.put_ap.connect    (generate_ap);
      put_response_export.connect       (m_response_fifo.put_export);
      get_peek_response_export.connect  (m_response_fifo.get_peek_export);
      m_response_fifo.put_ap.connect    (response_ap);
    }
  }

  override void run_phase(uvm_phase phase) {
    while(true) {
      auto rsp = new RSP(this.get_name() ~ "/rsp");
      m_generate_fifo.put(rsp);
    }
  }

  // get_type_name
  // -------------

  override string get_type_name () {
    return type_name;
  }


  // create
  // ------

  override uvm_object create (string name="") {
    synchronized(this) {
      this_type v;
      v = new this_type(name);
      return v;
    }
  }
}
