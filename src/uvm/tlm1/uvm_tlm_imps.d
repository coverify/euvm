//
//----------------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2018 NVIDIA Corporation
// Copyright 2018 Synopsys, Inc.
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

module uvm.tlm1.uvm_tlm_imps;

// *ifndef UVM_TLM_IMPS_SVH
// *define UVM_TLM_IMPS_SVH

//
// These IMP macros define implementations of the uvm_*_port, uvm_*_export,
// and uvm_*_imp ports.
//


//---------------------------------------------------------------
// Macros for implementations of UVM ports and exports

/*
*define UVM_BLOCKING_PUT_IMP(IMP, TYPE, arg) \
  task put (TYPE arg); \
    if (m_imp_list.size()) == 0) begin \
      uvm_report_error("Port Not Bound","Blocking put to unbound port will wait forever.", uvm_verbosity.UVM_NONE);
      @IMP;
    end
    if (bcast_mode) begin \
      if (m_imp_list.size()) > 1) \
        fork
          begin
            foreach (m_imp_list[index]) \
              fork \
                automatic int i = index; \
                begin m_imp_list[i].put(arg); end \
              join_none \
            wait fork; \
          end \
        join \
      else \
        m_imp_list[0].put(arg); \
    end \
    else  \
      if (IMP != null) \
        IMP.put(arg); \
  endtask \

*define UVM_NONBLOCKING_PUT_IMP(IMP, TYPE, arg) \
  function bit try_put(input TYPE arg); \
    if (bcast_mode) begin \
      if (!can_put()) \
        return 0; \
      foreach (m_imp_list[index]) \
        void'(m_imp_list[index].try_put(arg)); \
      return 1; \
    end  \
    if (IMP != null) \
      return IMP.try_put(arg)); \
    return 0; \
  endfunction \
  \
  function bit can_put(); \
    if (bcast_mode) begin \
      if (m_imp_list.size()) begin \
        foreach (m_imp_list[index]) begin \
          if (!m_imp_list[index].can_put() \
            return 0; \
        end \
        return 1; \
      end \
      return 0; \
    end \
    if (IMP != null) \
      return IMP.can_put(); \
    return 0; \
  endfunction

*/

//-----------------------------------------------------------------------
// UVM TLM imp implementations

// *define UVM_BLOCKING_PUT_IMP(IMP, TYPE, arg)	\
//   task put (TYPE arg); \
//     IMP.put(arg); \
//   endtask

mixin template UVM_BLOCKING_PUT_IMP(alias IMP, TYPE)
{
  void put(TYPE arg) {
    IMP.put(arg);
  }
}

// *define UVM_NONBLOCKING_PUT_IMP(IMP, TYPE, arg)	\
//  function bit try_put (TYPE arg); \
//     return IMP.try_put(arg); \
//   endfunction \
//   function bit can_put(); \
//     return IMP.can_put(); \
//  endfunction

mixin template UVM_NONBLOCKING_PUT_IMP(alias IMP, TYPE)
{ // IMP has to be effectively immutable
  bool try_put (TYPE arg) {
    return IMP.try_put(arg);
  }
  bool can_put() {
    return IMP.can_put();
  }
}

// *define UVM_BLOCKING_GET_IMP(IMP, TYPE, arg)	\
//   task get (output TYPE arg); \
//     IMP.get(arg); \
//   endtask

mixin template UVM_BLOCKING_GET_IMP(alias IMP, TYPE)
{ // IMP has to be effectively immutable
  void get (out TYPE arg) {
    IMP.get(arg);
  }
}
  
// *define UVM_NONBLOCKING_GET_IMP(IMP, TYPE, arg)	\
//   function bit try_get (output TYPE arg); \
//     return IMP.try_get(arg); \
//   endfunction \
//   function bit can_get(); \
//     return IMP.can_get(); \
//   endfunction

mixin template UVM_NONBLOCKING_GET_IMP(alias IMP, TYPE)
{
  bool try_get (out TYPE arg) {
    return IMP.try_get(arg);
  }
  bool can_get() {
    return IMP.can_get();
  }
}

// *define UVM_BLOCKING_PEEK_IMP(IMP, TYPE, arg) \
//   task peek (output TYPE arg); \
//     IMP.peek(arg); \
//   endtask

mixin template UVM_BLOCKING_PEEK_IMP(alias IMP, TYPE)
{
  void peek(out TYPE arg) {
    IMP.peek(arg);
  }
}

// *define UVM_NONBLOCKING_PEEK_IMP(IMP, TYPE, arg)	\
//   function bit try_peek (output TYPE arg); \
//     return IMP.try_peek(arg); \
//   endfunction \
//   function bit can_peek(); \
//     return IMP.can_peek(); \
//   endfunction

mixin template  UVM_NONBLOCKING_PEEK_IMP(alias IMP, TYPE)
{
  bool try_peek (out TYPE arg) {
    return IMP.try_peek(arg);
  }
  bool can_peek() {
    return IMP.can_peek();		      
  }
}

// *define UVM_BLOCKING_TRANSPORT_IMP(IMP, REQ, RSP, req_arg, rsp_arg)	\
//   task transport (REQ req_arg, output RSP rsp_arg); \
//     IMP.transport(req_arg, rsp_arg); \
//   endtask

mixin template UVM_BLOCKING_TRANSPORT_IMP(alias IMP, REQ, RSP)
{
  void transport(REQ req_arg, out RSP rsp_arg) {
    IMP.transport(req_arg, rsp_arg);
  }
}

/* *define UVM_NONBLOCKING_TRANSPORT_IMP(IMP, REQ, RSP, req_arg, rsp_arg) \ */
/*   function bit nb_transport (REQ req_arg, output RSP rsp_arg); \ */
/*     return IMP.nb_transport(req_arg, rsp_arg); \ */
/*   endfunction */

mixin template UVM_NONBLOCKING_TRANSPORT_IMP(alias IMP, REQ, RSP) {
  bool nb_transport (REQ req_arg, out RSP rsp_arg) {
    return IMP.nb_transport(req_arg, rsp_arg);
  }
}

/* *define UVM_PUT_IMP(IMP, TYPE, arg) \ */
/*   *UVM_BLOCKING_PUT_IMP(IMP, TYPE, arg) \ */
/*   *UVM_NONBLOCKING_PUT_IMP(IMP, TYPE, arg) */

mixin template UVM_PUT_IMP(alias IMP, TYPE) {
  mixin UVM_BLOCKING_PUT_IMP!(IMP, TYPE);
  mixin UVM_NONBLOCKING_PUT_IMP!(IMP, TYPE);
}

/* *define UVM_GET_IMP(IMP, TYPE, arg) \ */
/*   *UVM_BLOCKING_GET_IMP(IMP, TYPE, arg) \ */
/*   *UVM_NONBLOCKING_GET_IMP(IMP, TYPE, arg) */

mixin template UVM_GET_IMP(alias IMP, TYPE) {
  mixin UVM_BLOCKING_GET_IMP!(IMP, TYPE);
  mixin UVM_NONBLOCKING_GET_IMP!(IMP, TYPE);
}

/* *define UVM_PEEK_IMP(IMP, TYPE, arg) \ */
/*   *UVM_BLOCKING_PEEK_IMP(IMP, TYPE, arg) \ */
/*   *UVM_NONBLOCKING_PEEK_IMP(IMP, TYPE, arg) */

mixin template UVM_PEEK_IMP(alias IMP, TYPE) {
  mixin UVM_BLOCKING_PEEK_IMP!(IMP, TYPE);
  mixin UVM_NONBLOCKING_PEEK_IMP!(IMP, TYPE);
}

/* *define UVM_BLOCKING_GET_PEEK_IMP(IMP, TYPE, arg) \ */
/*   *UVM_BLOCKING_GET_IMP(IMP, TYPE, arg) \ */
/*   *UVM_BLOCKING_PEEK_IMP(IMP, TYPE, arg) */

mixin template UVM_BLOCKING_GET_PEEK_IMP(alias IMP, TYPE) {
  mixin UVM_BLOCKING_GET_IMP!(IMP, TYPE);
  mixin UVM_BLOCKING_PEEK_IMP!(IMP, TYPE);
}

/* *define UVM_NONBLOCKING_GET_PEEK_IMP(IMP, TYPE, arg) \ */
/*   *UVM_NONBLOCKING_GET_IMP(IMP, TYPE, arg) \ */
/*   *UVM_NONBLOCKING_PEEK_IMP(IMP, TYPE, arg) */

mixin template UVM_NONBLOCKING_GET_PEEK_IMP(alias IMP, TYPE) {
  mixin UVM_NONBLOCKING_GET_IMP!(IMP, TYPE);
  mixin UVM_NONBLOCKING_PEEK_IMP!(IMP, TYPE);
}

/* *define UVM_GET_PEEK_IMP(IMP, TYPE, arg) \ */
/*   *UVM_BLOCKING_GET_PEEK_IMP(IMP, TYPE, arg) \ */
/*   *UVM_NONBLOCKING_GET_PEEK_IMP(IMP, TYPE, arg) */

mixin template UVM_GET_PEEK_IMP(alias IMP, TYPE) {
  mixin UVM_BLOCKING_GET_PEEK_IMP!(IMP, TYPE);
  mixin UVM_NONBLOCKING_GET_PEEK_IMP!(IMP, TYPE);
}

/* *define UVM_TRANSPORT_IMP(IMP, REQ, RSP, req_arg, rsp_arg) \ */
/*   *UVM_BLOCKING_TRANSPORT_IMP(IMP, REQ, RSP, req_arg, rsp_arg) \ */
/*   *UVM_NONBLOCKING_TRANSPORT_IMP(IMP, REQ, RSP, req_arg, rsp_arg) */

mixin template UVM_TRANSPORT_IMP(alias IMP, REQ, RSP) {
  mixin UVM_BLOCKING_TRANSPORT_IMP!(IMP, REQ, RSP);
  mixin UVM_NONBLOCKING_TRANSPORT_IMP!(IMP, REQ, RSP);
}

/* *define UVM_TLM_GET_TYPE_NAME(NAME) \ */
/*   virtual function string get_type_name(); \ */
/*     return NAME; \ */
/*   endfunction */

mixin template UVM_TLM_GET_TYPE_NAME(string NAME) {
  string get_type_name() {
    return NAME;
  }
}

mixin template UVM_TLM_GET_TYPE_NAME() {
  string get_type_name() {
    return qualifiedTypeName(typeof(this));
  }
}

/* *define UVM_PORT_COMMON(MASK,TYPE_NAME) \
/*   function new (string name, uvm_component parent, \ */
/*                 int min_size=1, int max_size=1); \ */
/*     super.new (name, parent, UVM_PORT, min_size, max_size); \ */
/*     m_if_mask = MASK; \ */
/*   endfunction \ */
/*   *UVM_TLM_GET_TYPE_NAME(TYPE_NAME) */

mixin template UVM_PORT_COMMON(uint MASK, string TYPE_NAME) {
  this(string name, uvm_component parent,
       int min_size=1, int max_size=1) {
    super(name, parent, uvm_port_type_e.UVM_PORT, min_size, max_size);
    m_if_mask = MASK;
  }
  mixin UVM_TLM_GET_TYPE_NAME!(TYPE_NAME);
}

mixin template UVM_PORT_COMMON(uint MASK) {
  this(string name, uvm_component parent,
       int min_size=1, int max_size=1) {
    super(name, parent, uvm_port_type_e.UVM_PORT, min_size, max_size);
    m_if_mask = MASK;
  }
  mixin UVM_TLM_GET_TYPE_NAME;
}

/* *define UVM_SEQ_PORT(MASK,TYPE_NAME) \ */
/*   function new (string name, uvm_component parent, \ */
/*                 int min_size=0, int max_size=1); \ */
/*     super.new (name, parent, UVM_PORT, min_size, max_size); \ */
/*     m_if_mask = MASK; \ */
/*   endfunction \ */
/*   *UVM_TLM_GET_TYPE_NAME(TYPE_NAME) */
  
mixin template UVM_SEQ_PORT(uint MASK, string TYPE_NAME) {
  this(string name, uvm_component parent,
       int min_size=0, int max_size=1) {
    super(name, parent, uvm_port_type_e.UVM_PORT, min_size, max_size);
    m_if_mask = MASK;
  }
  
  mixin UVM_TLM_GET_TYPE_NAME!(TYPE_NAME);
}
  
mixin template UVM_SEQ_PORT(uint MASK) {
  this(string name, uvm_component parent,
       int min_size=0, int max_size=1) {
    super(name, parent, uvm_port_type_e.UVM_PORT, min_size, max_size);
    m_if_mask = MASK;
  }
  
  mixin UVM_TLM_GET_TYPE_NAME;
}
  
/* *define UVM_EXPORT_COMMON(MASK,TYPE_NAME) \ */
/*   function new (string name, uvm_component parent, \ */
/*                 int min_size=1, int max_size=1); \ */
/*     super.new (name, parent, UVM_EXPORT, min_size, max_size); \ */
/*     m_if_mask = MASK; \ */
/*   endfunction \ */
/*   *UVM_TLM_GET_TYPE_NAME(TYPE_NAME) */
  
mixin template UVM_EXPORT_COMMON(uint MASK, string TYPE_NAME) {
  this(string name, uvm_component parent,
       int min_size=1, int max_size=1) {
    super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
    m_if_mask = MASK;
  }
  mixin UVM_TLM_GET_TYPE_NAME!(TYPE_NAME);
}

mixin template UVM_EXPORT_COMMON(uint MASK) {
  this(string name, uvm_component parent,
       int min_size=1, int max_size=1) {
    super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
    m_if_mask = MASK;
  }
  mixin UVM_TLM_GET_TYPE_NAME;
}
  
/* *define UVM_IMP_COMMON(MASK,TYPE_NAME,IMP) \ */
/*   local IMP m_imp; \ */
/*   function new (string name, IMP IMP); \ */
/*     super.new (name, IMP, UVM_IMPLEMENTATION, 1, 1); \ */
/*     m_imp = IMP; \ */
/*     m_if_mask = MASK; \ */
/*   endfunction \ */
/*   *UVM_TLM_GET_TYPE_NAME(TYPE_NAME) */

mixin template UVM_IMP_COMMON(uint MASK, string TYPE_NAME, IMP) {
  private IMP _m_imp;
  this(string name, IMP imp) {
    synchronized (this) {
      super(name, imp, uvm_port_type_e.UVM_IMPLEMENTATION, 1, 1);
      _m_imp = IMP;
      m_if_mask = MASK;
    }
  }
  mixin UVM_TLM_GET_TYPE_NAME!(TYPE_NAME);
}

mixin template UVM_IMP_COMMON(uint MASK, IMP) {
  private IMP _m_imp;
  this(string name, IMP imp) {
    synchronized (this) {
      super(name, imp, uvm_port_type_e.UVM_IMPLEMENTATION, 1, 1);
      _m_imp = IMP;
      m_if_mask = MASK;
    }
  }
  mixin UVM_TLM_GET_TYPE_NAME;
}

/* *define UVM_MS_IMP_COMMON(MASK,TYPE_NAME) \ */
/*   local this_req_type m_req_imp; \ */
/*   local this_rsp_type m_rsp_imp; \ */
/*   function new (string name, this_imp_type IMP, \ */
/*                 this_req_type req_imp = null, this_rsp_type rsp_imp = null); \ */
/*     super.new (name, IMP, UVM_IMPLEMENTATION, 1, 1); \ */
/*     if (req_imp==null) $cast(req_imp, IMP); \ */
/*     if (rsp_imp==null) $cast(rsp_imp, IMP); \ */
/*     m_req_imp = req_imp; \ */
/*     m_rsp_imp = rsp_imp; \ */
/*     m_if_mask = MASK; \ */
/*   endfunction  \ */
/*   *UVM_TLM_GET_TYPE_NAME(TYPE_NAME) */

mixin template UVM_MS_IMP_COMMON(uint MASK, string TYPE_NAME) {
  private this_req_type _m_req_imp;
  private this_rsp_type _m_rsp_imp;
  this(string name, this_imp_type imp,
       this_req_type req_imp = null, this_rsp_type rsp_imp = null) {
    synchronized (this) {
      super(name, imp, UVM_impLEMENTATION, 1, 1);
      if (req_imp is null) req_imp = cast (this_req_type) imp;
      if (rsp_imp is null) rsp_imp = cast (this_rsp_type) imp;
      _m_req_imp = req_imp;
      _m_rsp_imp = rsp_imp;
      m_if_mask = MASK;
    }
  }
  mixin UVM_TLM_GET_TYPE_NAME!(TYPE_NAME);
}

mixin template UVM_MS_IMP_COMMON(uint MASK) {
  private this_req_type _m_req_imp;
  private this_rsp_type _m_rsp_imp;
  this(string name, this_imp_type imp,
       this_req_type req_imp = null, this_rsp_type rsp_imp = null) {
    synchronized (this) {
      super(name, imp, UVM_impLEMENTATION, 1, 1);
      if (req_imp is null) req_imp = cast (this_req_type) imp;
      if (rsp_imp is null) rsp_imp = cast (this_rsp_type) imp;
      _m_req_imp = req_imp;
      _m_rsp_imp = rsp_imp;
      m_if_mask = MASK;
    }
  }
  mixin UVM_TLM_GET_TYPE_NAME;
}

/* *endif */
