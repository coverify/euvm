//
//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
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
// Title: Analysis Ports
//------------------------------------------------------------------------------
//
// This section defines the port, export, and imp classes used for transaction
// analysis.
//
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Class: uvm_analysis_port
//
// Broadcasts a value to all subscribers implementing a <uvm_analysis_imp>.
//
//| class mon extends uvm_component;
//|   uvm_analysis_port#(trans) ap;
//|
//|   function new(string name = "sb", uvm_component parent = null);
//|      super.new(name, parent);
//|      ap = new("ap", this);
//|   endfunction
//|
//|   task run_phase(uvm_phase phase);
//|       trans t;
//|       ...
//|       ap.write(t);
//|       ...
//|   endfunction
//| endclass
//------------------------------------------------------------------------------

module uvm.tlm1.uvm_analysis_port;
import uvm.base.uvm_port_base;
import uvm.base.uvm_component;
import uvm.base.uvm_phase;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;


import uvm.tlm1.uvm_tlm_ifs;
import uvm.tlm1.uvm_tlm_defines;


class uvm_analysis_port(T=int): uvm_port_base!(uvm_tlm_if_base!(T,T))
{
  public this(string name=null, uvm_component parent=null) {
    synchronized(this) {
      super(name, parent, UVM_PORT, 0, UVM_UNBOUNDED_CONNECTIONS);
      m_if_mask = UVM_TLM_ANALYSIS_MASK;
    }
  }

  override public string get_type_name() {
    return "uvm_analysis_port";
  }

  // Method: write
  // Send specified value to all connected interface
  override public void write (T t) {
    synchronized(this) {
      uvm_tlm_if_base!(T, T) tif;
      for (size_t i = 0; i < this.size(); ++i) {
	tif = this.get_if (i);
	if ( tif is null ) {
	  uvm_report_fatal ("NTCONN", "No uvm_tlm interface is connected to " ~
			    get_full_name() ~ " for executing write()",
			    UVM_NONE);
	}
	tif.write (t);
      }
    }
  }

}



//------------------------------------------------------------------------------
// Class: uvm_analysis_imp
//
// Receives all transactions broadcasted by a <uvm_analysis_port>. It serves as
// the termination point of an analysis port/export/imp connection. The component
// attached to the ~imp~ class--called a ~subscriber~-- implements the analysis
// interface.
//
// Will invoke the ~write(T)~ method in the parent component.
// The implementation of the ~write(T)~ method must not modify
// the value passed to it.
//
//| class sb extends uvm_component;
//|   uvm_analysis_imp#(trans, sb) ap;
//|
//|   function new(string name = "sb", uvm_component parent = null);
//|      super.new(name, parent);
//|      ap = new("ap", this);
//|   endfunction
//|
//|   function void write(trans t);
//|       ...
//|   endfunction
//| endclass
//------------------------------------------------------------------------------

class uvm_analysis_imp(T=int, IMP=int): uvm_port_base!(uvm_tlm_if_base !(T,T))
{
  // `UVM_IMP_COMMON(`UVM_TLM_ANALYSIS_MASK,"uvm_analysis_imp",IMP)
  private IMP m_imp;
  public this (string name, IMP imp) {
    synchronized(this) {
      super (name, imp, UVM_IMPLEMENTATION, 1, 1);
      m_imp = imp;
      m_if_mask = UVM_TLM_ANALYSIS_MASK;
    }
  }

  override public string get_type_name() {
    return "uvm_analysis_imp";
  }

  override public void write (T t) {
    synchronized(this) {
      m_imp.write (t);
    }
  }

}



//------------------------------------------------------------------------------
// Class: uvm_analysis_export
//
// Exports a lower-level <uvm_analysis_imp> to its parent.
//------------------------------------------------------------------------------

class uvm_analysis_export(T=int): uvm_port_base!(uvm_tlm_if_base!(T,T))
{
  // Function: new
  // Instantiate the export.
  public this(string name=null, uvm_component parent = null) {
    synchronized(this) {
      super(name, parent, UVM_EXPORT, 1, UVM_UNBOUNDED_CONNECTIONS);
      m_if_mask = UVM_TLM_ANALYSIS_MASK;
    }
  }


  override public string get_type_name() {
    return "uvm_analysis_export";
  }

  // analysis port differs from other ports in that it broadcasts
  // to all connected interfaces. Ports only send to the interface
  // at the index specified in a call to set_if (0 by default).
  override public void write (T t) {
    synchronized(this) {
      uvm_tlm_if_base!(T, T) tif;
      for (int i = 0; i < this.size(); i++) {
	tif = this.get_if (i);
	if (tif is null) {
	  uvm_report_fatal ("NTCONN", "No uvm_tlm interface is connected to " ~
			    get_full_name() ~ " for executing write()",
			    UVM_NONE);
	}
	tif.write (t);
      }
    }
  }

}
