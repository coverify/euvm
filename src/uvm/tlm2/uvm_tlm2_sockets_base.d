//----------------------------------------------------------------------
//   Copyright 2010 Mentor Graphics Corporation
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2016 Coverify Systems Technology
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

module uvm.tlm2.uvm_tlm2_sockets_base;

//----------------------------------------------------------------------
// Title: TLM Socket Base Classes
//
// A collection of base classes, one for each socket type.  The reason
// for having a base class for each socket is that all the socket (base)
// types must be known before connect is defined.  Socket connection
// semantics are provided in the derived classes, which are user
// visible.
//
// Termination Sockets - A termination socket must be the terminus
// of every TLM path.  A transaction originates with an initiator socket
// and ultimately ends up in a target socket.  There may be zero or more
// pass-through sockets between initiator and target.
//
// Pass-through Sockets - Pass-through initiators are ports and contain
// exports for instance IS-A port and HAS-A export. Pass-through targets
// are the opposite, they are exports and contain ports.
//----------------------------------------------------------------------


//----------------------------------------------------------------------
// Class: uvm_tlm_b_target_socket_base
//
// IS-A forward imp; has no backward path except via the payload
// contents.
//----------------------------------------------------------------------
class uvm_tlm_b_target_socket_base(T=uvm_tlm_generic_payload)
  : uvm_port_base!(uvm_tlm_if!(T))
  {
    this(string name, uvm_component parent) {
      synchronized(this) {
	super(name, parent, UVM_IMPLEMENTATION, 1, 1);
	m_if_mask = UVM_TLM_B_MASK;
      }
    }
    // `UVM_TLM_GET_TYPE_NAME("uvm_tlm_b_target_socket")
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_b_initiator_socket_base
//
// IS-A forward port; has no backward path except via the payload
// contents
//----------------------------------------------------------------------
class uvm_tlm_b_initiator_socket_base(T=uvm_tlm_generic_payload)
  : uvm_port_base!(uvm_tlm_if!(T))
  {
    // `UVM_PORT_COMMON(`UVM_TLM_B_MASK, "uvm_tlm_b_initiator_socket")
    this(string name, uvm_component parent,
	 int min_size=1, int max_size=1) {
      synchronized(this) {
	super(name, parent, UVM_PORT, min_size, max_size);
	m_if_mask = UVM_TLM_B_MASK;
      }
    }
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }
    // `UVM_TLM_B_TRANSPORT_IMP(this.m_if, T, t, delay)
    // task
    void b_transport(T t, uvm_tlm_time delay) {
      if(delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		  ".b_transport() called with 'null' delay");
	return;
      }
      this.mf_if.b_transport(t, delay);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_target_socket_base
//
// IS-A forward imp; HAS-A backward port
//----------------------------------------------------------------------
class uvm_tlm_nb_target_socket_base(T=uvm_tlm_generic_payload,
				    P=uvm_tlm_phase_e)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {

    uvm_tlm_nb_transport_bw_port!(T,P) bw_port;

    this(string name, uvm_component parent) {
      synchronized(this) {
	super (name, parent, UVM_IMPLEMENTATION, 1, 1);
	m_if_mask = UVM_TLM_NB_FW_MASK;
      }
    }

    // `UVM_TLM_GET_TYPE_NAME("uvm_tlm_nb_target_socket")
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }

    // `UVM_TLM_NB_TRANSPORT_BW_IMP(bw_port, T, P, t, p, delay)
    uvm_tlm_sync_e nb_transport_bw(T t, ref P p, in uvm_tlm_time delay) {
      if (delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name(),
		  ".nb_transport_bw() called with 'null' delay");
	return UVM_TLM_COMPLETED;
      }
      return bw_port.nb_transport_bw(t, p, delay);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_initiator_socket_base
//
// IS-A forward port; HAS-A backward imp
//----------------------------------------------------------------------
class uvm_tlm_nb_initiator_socket_base(T=uvm_tlm_generic_payload,
				       P=uvm_tlm_phase_e)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {
    this(string name, uvm_component parent) {
      synchronized(this) {
	super (name, parent, UVM_PORT, 1, 1);
	m_if_mask = UVM_TLM_NB_FW_MASK;
      }
    }

    // `UVM_TLM_GET_TYPE_NAME("uvm_tlm_nb_initiator_socket")
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }

    // `UVM_TLM_NB_TRANSPORT_FW_IMP(this.m_if, T, P, t, p, delay)
    uvm_tlm_sync_e nb_transport_fw(T t, ref P p, in uvm_tlm_time delay) {
      if (delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		  ".nb_transport_fw() called with 'null' delay");
	return UVM_TLM_COMPLETED;
      }
      return this.mf_if.nb_transport_fw(t, p, delay);
    }
  }


//----------------------------------------------------------------------
// Class: uvm_tlm_nb_passthrough_initiator_socket_base
//
// IS-A forward port; HAS-A backward export
//----------------------------------------------------------------------
class uvm_tlm_nb_passthrough_initiator_socket_base(T=uvm_tlm_generic_payload,
						   P=uvm_tlm_phase_e)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {
    
    uvm_tlm_nb_transport_bw_export!(T,P) bw_export;

    this(string name, uvm_component parent,
	 int min_size=1, int max_size=1) {
      synchronized(this) {
	super(name, parent, UVM_PORT, min_size, max_size);
	m_if_mask = UVM_TLM_NB_FW_MASK;
	bw_export = new uvm_tlm_nb_transport_bw_export!(T,P)("bw_export",
							     get_comp());
      }
    }

    // `UVM_TLM_GET_TYPE_NAME("uvm_tlm_nb_passthrough_initiator_socket")
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }

    // `UVM_TLM_NB_TRANSPORT_FW_IMP(this.m_if, T, P, t, p, delay)
    mixin UVM_TLM_NB_TRANSPORT_FW_IMP!(this.m_if, T, P);
    // `UVM_TLM_NB_TRANSPORT_BW_IMP(bw_export, T, P, t, p, delay)
    mixin UVM_TLM_NB_TRANSPORT_BW_IMP!(bw_export, T, P);
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_passthrough_target_socket_base
//
// IS-A forward export; HAS-A backward port
//----------------------------------------------------------------------
class uvm_tlm_nb_passthrough_target_socket_base(T=uvm_tlm_generic_payload,
						P=uvm_tlm_phase_e)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {

    uvm_tlm_nb_transport_bw_port!(T,P) bw_port;

    this(string name, uvm_component parent,
	 int min_size=1, int max_size=1) {
      super (name, parent, UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_TLM_NB_FW_MASK;
      bw_port = new uvm_tlm_nb_transport_bw_port!(T,P)("bw_port", get_comp());
    }

    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }

    // `UVM_TLM_NB_TRANSPORT_FW_IMP(this.m_if, T, P, t, p, delay)
    mixin UVM_TLM_NB_TRANSPORT_FW_IMP!(this.m_if, T, P);
    // `UVM_TLM_NB_TRANSPORT_BW_IMP(bw_port, T, P, t, p, delay)
    mixin UVM_TLM_NB_TRANSPORT_BW_IMP!(bw_port, T, P);
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_b_passthrough_initiator_socket_base
//
// IS-A forward port
//----------------------------------------------------------------------
class uvm_tlm_b_passthrough_initiator_socket_base(T=uvm_tlm_generic_payload)
  : uvm_port_base!(uvm_tlm_if!(T))
  {

    // `UVM_PORT_COMMON(`UVM_TLM_B_MASK, "uvm_tlm_b_passthrough_initiator_socket")
    this(string name, uvm_component parent,
	 int min_size=1, int max_size=1) {
      synchronized(this) {
	super (name, parent, UVM_PORT, min_size, max_size);
	m_if_mask = UVM_TLM_B_MASK;
      }
    }
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }
    // `UVM_TLM_B_TRANSPORT_IMP(this.m_if, T, t, delay)
    // task
    void b_transport(T t, uvm_tlm_time delay) {
      if (delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		  ".b_transport() called with 'null' delay");
       return;
      }
      this.m_if.b_transport(t, delay);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_b_passthrough_target_socket_base
//
// IS-A forward export
//----------------------------------------------------------------------
class uvm_tlm_b_passthrough_target_socket_base(T=uvm_tlm_generic_payload)
  : uvm_port_base!(uvm_tlm_if!(T))
  {

    // `UVM_EXPORT_COMMON(`UVM_TLM_B_MASK, "uvm_tlm_b_passthrough_target_socket")
    mixin UVM_EXPORT_COMMON!(UVM_TLM_B_MASK);
    // `UVM_TLM_B_TRANSPORT_IMP(this.m_if, T, t, delay)
    //  task
    mixin UVM_TLM_B_TRANSPORT_IMP!(this.m_if, T);
  }

