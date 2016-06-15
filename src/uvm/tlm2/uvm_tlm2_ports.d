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

module uvm.tlm2.uvm_tlm2_ports;
//----------------------------------------------------------------------
// Title: TLM2 ports
//
// The following defines TLM2 port classes.
//
//----------------------------------------------------------------------

// class: uvm_tlm_b_transport_port
//
// Class providing the blocking transport port,
// The port can be bound to one export.
// There is no backward path for the blocking transport.

class uvm_tlm_b_transport_port(T=uvm_tlm_generic_payload)
  : uvm_port_base!(uvm_tlm_if!(T))
  {
    // `UVM_PORT_COMMON(`UVM_TLM_B_MASK, "uvm_tlm_b_transport_port")
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


// class: uvm_tlm_nb_transport_fw_port
//
// Class providing the non-blocking backward transport port.
// Transactions received from the producer, on the forward path, are
// sent back to the producer on the backward path using this
// non-blocking transport port.
// The port can be bound to one export.
//
  
class uvm_tlm_nb_transport_fw_port(T=uvm_tlm_generic_payload,
				   P=uvm_tlm_phase_e)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {
    // `UVM_PORT_COMMON(`UVM_TLM_NB_FW_MASK, "uvm_tlm_nb_transport_fw_port")
    this(string name, uvm_component parent,
	 int min_size=1, int max_size=1) {
      synchronized(this) {
	super(name, parent, UVM_PORT, min_size, max_size);
	m_if_mask = UVM_TLM_NB_FW_MASK;
      }
    }
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

// class: uvm_tlm_nb_transport_bw_port
//
// Class providing the non-blocking backward transport port.
// Transactions received from the producer, on the forward path, are
// sent back to the producer on the backward path using this
// non-blocking transport port
// The port can be bound to one export.
//
  
class uvm_tlm_nb_transport_bw_port(T=uvm_tlm_generic_payload,
				   P=uvm_tlm_phase_e)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {
    // `UVM_PORT_COMMON(`UVM_TLM_NB_BW_MASK, "uvm_tlm_nb_transport_bw_port")
    this(string name, uvm_component parent,
	 int min_size=1, int max_size=1) {
      synchronized(this) {
	super(name, parent, UVM_PORT, min_size, max_size);
	m_if_mask = UVM_TLM_NB_BW_MASK;
      }
    }
    string get_type_name() {
      return qualifiedTypeName(typeof(this));
    }

    // `UVM_TLM_NB_TRANSPORT_BW_IMP(this.m_if, T, P, t, p, delay)
    uvm_tlm_sync_e nb_transport_bw(T t, ref P p, in uvm_tlm_time delay) {
      if (delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		  ".nb_transport_bw() called with 'null' delay");
	return UVM_TLM_COMPLETED;
      }
      return this.mf_if.nb_transport_bw(t, p, delay);
    }
  }
