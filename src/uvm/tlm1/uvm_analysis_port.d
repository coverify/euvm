//
//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2010 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2015 NVIDIA Corporation
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
// Title -- NODOCS -- Analysis Ports
//------------------------------------------------------------------------------
//
// This section defines the port, export, and imp classes used for transaction
// analysis.
//
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_analysis_port
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
import esdl.rand.misc: _esdl__Norand;

private alias Identity(alias A) = A;
private alias parentOf(alias sym) = Identity!(__traits(parent, sym));

// @uvm-ieee 1800.2-2017 auto 12.2.10.1.1
class uvm_analysis_port(T): uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{
  public this(string name=null, uvm_component parent=null) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_PORT, 0, UVM_UNBOUNDED_CONNECTIONS);
      m_if_mask = UVM_TLM_ANALYSIS_MASK;
    }
  }

  override public string get_type_name() {
    return "uvm_analysis_port";
  }

  // @uvm-ieee 1800.2-2017 auto 12.2.10.1.2
  override public void write (T t) {
    synchronized (this) {
      uvm_tlm_if_base!(T, T) tif;
      for (size_t i = 0; i < this.size(); ++i) {
	tif = this.get_if (i);
	if ( tif is null ) {
	  uvm_report_fatal ("NTCONN", "No uvm_tlm interface is connected to " ~
			    get_full_name() ~ " for executing write()",
			    uvm_verbosity.UVM_NONE);
	}
	tif.write (t);
      }
    }
  }

}



//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_analysis_imp
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

// @uvm-ieee 1800.2-2017 auto 12.2.10.2
class uvm_analysis_imp(T, IMP, string F=""): uvm_port_base!(uvm_tlm_if_base !(T,T)), _esdl__Norand
if (is (IMP: uvm_component))
{
  // `UVM_IMP_COMMON(`UVM_TLM_ANALYSIS_MASK,"uvm_analysis_imp",IMP)
  private IMP m_imp;
  public this (string name, IMP imp) {
    synchronized (this) {
      super (name, imp, uvm_port_type_e.UVM_IMPLEMENTATION, 1, 1);
      m_imp = imp;
      m_if_mask = UVM_TLM_ANALYSIS_MASK;
    }
  }

  override public string get_type_name() {
    return "uvm_analysis_imp";
  }

  override public void write (T t) {
    static if (F == "") {
      m_imp.write(t);
    }
    else {
      mixin ("m_imp." ~ F ~ "(t);");
    }
  }
}

class uvm_analysis_imp(T, IMP, alias F): uvm_port_base!(uvm_tlm_if_base !(T,T)), _esdl__Norand
if (is (IMP: uvm_component))
{
  // `UVM_IMP_COMMON(`UVM_TLM_ANALYSIS_MASK,"uvm_analysis_imp",IMP)
  private IMP m_imp;
  public this (string name, IMP imp) {
    synchronized (this) {
      super (name, imp, uvm_port_type_e.UVM_IMPLEMENTATION, 1, 1);
      m_imp = imp;
      m_if_mask = UVM_TLM_ANALYSIS_MASK;
    }
  }

  override public string get_type_name() {
    return "uvm_analysis_imp";
  }

  override public void write(T t) {
    auto dg = recreateDelegate!F(m_imp);
    dg(t);
  }
}

template uvm_analysis_imp(IMP, alias F = IMP.write)
  if (is (IMP: uvm_component))
{
  // `UVM_IMP_COMMON(`UVM_TLM_ANALYSIS_MASK,"uvm_analysis_imp",IMP)
  import std.traits: ParameterTypeTuple;
  alias TT = ParameterTypeTuple!F;
  static assert (TT.length == 1);
  alias T = TT[0];

  class uvm_analysis_imp: uvm_port_base!(uvm_tlm_if_base !(T,T))
  {
    private IMP m_imp;
    public this (string name, IMP imp) {
      synchronized (this) {
	super (name, imp, uvm_port_type_e.UVM_IMPLEMENTATION, 1, 1);
	m_imp = imp;
	m_if_mask = UVM_TLM_ANALYSIS_MASK;
      }
    }

    override public string get_type_name() {
      return "uvm_analysis_imp";
    }

    override public void write(T t) {
      auto dg = recreateDelegate!F(m_imp);
      dg(t);
    }
  }
}

template uvm_analysis_imp(alias F)
{
  alias uvm_analysis_imp = uvm_analysis_imp!(parentOf!F, F);
}


private auto recreateDelegate(alias F, T)(T _entity)
{
  import std.functional: toDelegate;
  alias DG = typeof(toDelegate(&F));
  DG dg;
  dg.funcptr = &F;
  dg.ptr = *(cast (void **) (&_entity));
  return dg;
}


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_analysis_export
//
// Exports a lower-level <uvm_analysis_imp> to its parent.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 12.2.10.3.1
class uvm_analysis_export(T): uvm_port_base!(uvm_tlm_if_base!(T,T)), _esdl__Norand
{

  // @uvm-ieee 1800.2-2017 auto 12.2.10.3.2
  public this(string name=null, uvm_component parent = null) {
    synchronized (this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, 1, UVM_UNBOUNDED_CONNECTIONS);
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
    synchronized (this) {
      uvm_tlm_if_base!(T, T) tif;
      for (int i = 0; i < this.size(); i++) {
	tif = this.get_if (i);
	if (tif is null) {
	  uvm_report_fatal ("NTCONN", "No uvm_tlm interface is connected to " ~
			    get_full_name() ~ " for executing write()",
			    uvm_verbosity.UVM_NONE);
	}
	tif.write (t);
      }
    }
  }
}
