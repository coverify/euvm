//----------------------------------------------------------------------
//   Copyright 2010-2011 Mentor Graphics Corporation
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

module uvm.tlm2.uvm_tlm2_imps;

//----------------------------------------------------------------------
// Title: TLM2 imps (interface implementations)
//
// This section defines the implementation classes for connecting TLM2
// interfaces.
//
// TLM imps bind a TLM interface with the object that contains the
// interface implementation.
// In addition to the transaction type and the phase type, the imps
// are parameterized with the type of the object that will provide the
// implementation. Most often this will be the type of the component
// where the imp resides. The constructor of the imp takes as an argument
// an object of type IMP and installs it as the implementation object.
// Most often the imp constructor argument is "this".
//----------------------------------------------------------------------

//--------------------------
// Group: IMP binding macros
//--------------------------

// Macro: `UVM_TLM_NB_TRANSPORT_FW_IMP
//
// The macro wraps the forward path call function nb_transport_fw()
//
// The first call to this method for a transaction marks the initial timing point.
// Every call to this method may mark a timing point in the execution of the
// transaction. The timing annotation argument allows the timing points
// to be offset from the simulation times at which the forward path is used.
// The final timing point of a transaction may be marked by a call
// to nb_transport_bw() within <`UVM_TLM_NB_TRANSPORT_BW_IMP> or a return from this
// or subsequent call to nb_transport_fw().
//
// See <TLM2 Interfaces, Ports, Exports and Transport Interfaces Subset>
// for more details on the semantics and rules of the nonblocking
// transport interface.

mixin template UVM_TLM_NB_TRANSPORT_FW_IMP(alias IMP, T, P)
{
  public uvm_tlm_sync_e nb_transport_fw(T t, ref P p, uvm_tlm_time delay) {
    if (delay is null) {
      uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		".nb_transport_fw() called with 'null' delay");
      return UVM_TLM_COMPLETED;
    }
    return IMP.nb_transport_fw(t, p, delay);
  }
}

// Macro: `UVM_TLM_NB_TRANSPORT_BW_IMP
//
//
// Implementation of the backward path.
// The macro wraps the function called nb_transport_bw().
// This function MUST be implemented in the INITIATOR component class.
//
// Every call to this method may mark a timing point, including the final
// timing point, in the execution of the transaction.
// The timing annotation argument allows the timing point
// to be offset from the simulation times at which the backward path is used.
// The final timing point of a transaction may be marked by a call
// to nb_transport_fw() within <`UVM_TLM_NB_TRANSPORT_FW_IMP> or a return from
// this or subsequent call to nb_transport_bw().
//
// See <TLM2 Interfaces, Ports, Exports and Transport Interfaces Subset>
// for more details on the semantics and rules of the nonblocking
// transport interface.
//
// Example:
//
//| class master extends uvm_component;
//|    uvm_tlm_nb_initiator_socket
//|          #(trans, uvm_tlm_phase_e, this_t) initiator_socket;
//|
//|    function void build_phase(uvm_phase phase);
//|       initiator_socket = new("initiator_socket", this, this);
//|    endfunction
//|
//|    function uvm_tlm_sync_e nb_transport_bw(trans t,
//|                                   ref uvm_tlm_phase_e p,
//|                                   input uvm_tlm_time delay);
//|        transaction = t;
//|        state = p;
//|        return UVM_TLM_ACCEPTED;
//|    endfunction
//|
//|    ...
//| endclass

mixin template UVM_TLM_NB_TRANSPORT_BW_IMP(alias imp, T, P)
{
  public uvm_tlm_sync_e nb_transport_bw(T t, ref P p, in uvm_tlm_time delay) {
    if (delay is null) {
      uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		".nb_transport_bw() called with 'null' delay");
      return UVM_TLM_COMPLETED;
    }
    return imp.nb_transport_bw(t, p, delay);
  }
}

// Macro: `UVM_TLM_B_TRANSPORT_IMP
//
// The macro wraps the function b_transport()
// Execute a blocking transaction. Once this method returns,
// the transaction is assumed to have been executed. Whether
// that execution is succesful or not must be indicated by the
// transaction itself.
//
// The callee may modify or update the transaction object, subject
// to any constraints imposed by the transaction class. The
// initiator may re-use a transaction object from one call to
// the next and across calls to b_transport().
//
// The call to b_transport shall mark the first timing point of the
// transaction. The return from b_transport() shall mark the final
// timing point of the transaction. The timing annotation argument
// allows the timing points to be offset from the simulation times
// at which the task call and return are executed.

mixin template UVM_TLM_B_TRANSPORT_IMP(alias imp, T)
{
  // task
  public void b_transport(T t, uvm_tlm_time delay) {
    if (delay is null) {
      uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		".b_transport() called with 'null' delay");
      return;
    }
    imp.b_transport(t, delay);
  }
}


//---------------------------
// Group: IMP binding classes
//---------------------------

//----------------------------------------------------------------------
// Class: uvm_tlm_b_transport_imp
//
// Used like exports, except an addtional class parameter specifices
// the type of the implementation object.  When the
// imp is instantiated the implementation object is bound.
//----------------------------------------------------------------------

class uvm_tlm_b_transport_imp(T=uvm_tlm_generic_payload,
			      IMP=int): 
  uvm_port_base!(uvm_tlm_if!T)
{
  mixin UVM_IMP_COMMON!(UVM_TLM_B_MASK, IMP);
  mixin UVM_TLM_B_TRANSPORT_IMP!(m_imp, T);
}

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_transport_fw_imp
//
// Used like exports, except an addtional class parameter specifices
// the type of the implementation object.  When the
// imp is instantiated the implementation object is bound.
//----------------------------------------------------------------------

class uvm_tlm_nb_transport_fw_imp(T=uvm_tlm_generic_payload,
				  P=uvm_tlm_phase_e,
				  IMP=int)
  : uvm_port_base!(uvm_tlm_if!(T,P)) {
    // `UVM_IMP_COMMON(`UVM_TLM_NB_FW_MASK, "uvm_tlm_nb_transport_fw_imp", IMP)
    mixin UVM_IMP_COMMON!(UVM_TLM_B_MASK, IMP);
    // `UVM_TLM_NB_TRANSPORT_FW_IMP(m_imp, T, P, t, p, delay)
    mixin UVM_TLM_NB_TRANSPORT_FW_IMP!(m_imp, T, P);
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_transport_bw_imp
//
// Used like exports, except an addtional class parameter specifices
// the type of the implementation object.  When the
// imp is instantiated the implementation object is bound.
//----------------------------------------------------------------------

class uvm_tlm_nb_transport_bw_imp(T=uvm_tlm_generic_payload,
				  P=uvm_tlm_phase_e,
				  IMP=int)
  : uvm_port_base!(uvm_tlm_if!(T,P))
  {
    /* `UVM_IMP_COMMON(`UVM_TLM_NB_BW_MASK, "uvm_tlm_nb_transport_bw_imp", IMP) */
    mixin UVM_IMP_COMMON!(UVM_TLM_BW_MASK, IMP);
    /* `UVM_TLM_NB_TRANSPORT_BW_IMP(m_imp, T, P, t, p, delay) */
    mixin UVM_TLM_NB_TRANSPORT_BW_IMP!(m_imp, T, P);
  }
