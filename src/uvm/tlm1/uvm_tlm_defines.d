module uvm.tlm1.uvm_tlm_defines;
// // MACRO: `uvm_blocking_put_imp_decl
// //
// //| `uvm_blocking_put_imp_decl(SFX)
// //
// // Define the class uvm_blocking_put_impSFX for providing blocking put
// // implementations.  ~SFX~ is the suffix for the new class type.

// `define uvm_blocking_put_imp_decl(SFX) \
// class uvm_blocking_put_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_BLOCKING_PUT_MASK,`"uvm_blocking_put_imp``SFX`",IMP) \
//   `UVM_BLOCKING_PUT_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_nonblocking_put_imp_decl
// //
// //| `uvm_nonblocking_put_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_put_impSFX for providing non-blocking
// // put implementations.  ~SFX~ is the suffix for the new class type.

// `define uvm_nonblocking_put_imp_decl(SFX) \
// class uvm_nonblocking_put_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_NONBLOCKING_PUT_MASK,`"uvm_nonblocking_put_imp``SFX`",IMP) \
//   `UVM_NONBLOCKING_PUT_IMP_SFX( SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_put_imp_decl
// //
// //| `uvm_put_imp_decl(SFX)
// //
// // Define the class uvm_put_impSFX for providing both blocking and
// // non-blocking put implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_put_imp_decl(SFX) \
// class uvm_put_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_PUT_MASK,`"uvm_put_imp``SFX`",IMP) \
//   `UVM_BLOCKING_PUT_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_NONBLOCKING_PUT_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_blocking_get_imp_decl
// //
// //| `uvm_blocking_get_imp_decl(SFX)
// //
// // Define the class uvm_blocking_get_impSFX for providing blocking get
// // implementations.  ~SFX~ is the suffix for the new class type.

// `define uvm_blocking_get_imp_decl(SFX) \
// class uvm_blocking_get_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_BLOCKING_GET_MASK,`"uvm_blocking_get_imp``SFX`",IMP) \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_nonblocking_get_imp_decl
// //
// //| `uvm_nonblocking_get_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_get_impSFX for providing non-blocking
// // get implementations.  ~SFX~ is the suffix for the new class type.

// `define uvm_nonblocking_get_imp_decl(SFX) \
// class uvm_nonblocking_get_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_NONBLOCKING_GET_MASK,`"uvm_nonblocking_get_imp``SFX`",IMP) \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_get_imp_decl
// //
// //| `uvm_get_imp_decl(SFX)
// //
// // Define the class uvm_get_impSFX for providing both blocking and
// // non-blocking get implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_get_imp_decl(SFX) \
// class uvm_get_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_GET_MASK,`"uvm_get_imp``SFX`",IMP) \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_blocking_peek_imp_decl
// //
// //| `uvm_blocking_peek_imp_decl(SFX)
// //
// // Define the class uvm_blocking_peek_impSFX for providing blocking peek
// // implementations.  ~SFX~ is the suffix for the new class type.

// `define uvm_blocking_peek_imp_decl(SFX) \
// class uvm_blocking_peek_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_BLOCKING_PEEK_MASK,`"uvm_blocking_peek_imp``SFX`",IMP) \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_nonblocking_peek_imp_decl
// //
// //| `uvm_nonblocking_peek_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_peek_impSFX for providing non-blocking
// // peek implementations.  ~SFX~ is the suffix for the new class type.

// `define uvm_nonblocking_peek_imp_decl(SFX) \
// class uvm_nonblocking_peek_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_NONBLOCKING_PEEK_MASK,`"uvm_nonblocking_peek_imp``SFX`",IMP) \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_peek_imp_decl
// //
// //| `uvm_peek_imp_decl(SFX)
// //
// // Define the class uvm_peek_impSFX for providing both blocking and
// // non-blocking peek implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_peek_imp_decl(SFX) \
// class uvm_peek_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_PEEK_MASK,`"uvm_peek_imp``SFX`",IMP) \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
// endclass


// // MACRO: `uvm_blocking_get_peek_imp_decl
// //
// //| `uvm_blocking_get_peek_imp_decl(SFX)
// //
// // Define the class uvm_blocking_get_peek_impSFX for providing the
// // blocking get_peek implemenation.

// `define uvm_blocking_get_peek_imp_decl(SFX) \
// class uvm_blocking_get_peek_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_BLOCKING_GET_PEEK_MASK,`"uvm_blocking_get_peek_imp``SFX`",IMP) \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_nonblocking_get_peek_imp_decl
// //
// //| `uvm_nonblocking_get_peek_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_get_peek_impSFX for providing non-blocking
// // get_peek implemenation.

// `define uvm_nonblocking_get_peek_imp_decl(SFX) \
// class uvm_nonblocking_get_peek_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_NONBLOCKING_GET_PEEK_MASK,`"uvm_nonblocking_get_peek_imp``SFX`",IMP) \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
// endclass


// // MACRO: `uvm_get_peek_imp_decl
// //
// //| `uvm_get_peek_imp_decl(SFX)
// //
// // Define the class uvm_get_peek_impSFX for providing both blocking and
// // non-blocking get_peek implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_get_peek_imp_decl(SFX) \
// class uvm_get_peek_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_GET_PEEK_MASK,`"uvm_get_peek_imp``SFX`",IMP) \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_imp, T, t) \
// endclass

// // MACRO: `uvm_blocking_master_imp_decl
// //
// //| `uvm_blocking_master_imp_decl(SFX)
// //
// // Define the class uvm_blocking_master_impSFX for providing the
// // blocking master implemenation.

// `define uvm_blocking_master_imp_decl(SFX) \
// class uvm_blocking_master_imp``SFX #(type REQ=int, type RSP=int, type IMP=int, \
//                                      type REQ_IMP=IMP, type RSP_IMP=IMP) \
//   extends uvm_port_base #(uvm_tlm_if_base #(REQ, RSP)); \
//   typedef IMP     this_imp_type; \
//   typedef REQ_IMP this_req_type; \
//   typedef RSP_IMP this_rsp_type; \
//   `UVM_MS_IMP_COMMON(`UVM_TLM_BLOCKING_MASTER_MASK,`"uvm_blocking_master_imp``SFX`") \
//   \
//   `UVM_BLOCKING_PUT_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   \
// endclass

// // MACRO: `uvm_nonblocking_master_imp_decl
// //
// //| `uvm_nonblocking_master_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_master_impSFX for providing the
// // non-blocking master implemenation.

// `define uvm_nonblocking_master_imp_decl(SFX) \
// class uvm_nonblocking_master_imp``SFX #(type REQ=int, type RSP=int, type IMP=int, \
//                                    type REQ_IMP=IMP, type RSP_IMP=IMP) \
//   extends uvm_port_base #(uvm_tlm_if_base #(REQ, RSP)); \
//   typedef IMP     this_imp_type; \
//   typedef REQ_IMP this_req_type; \
//   typedef RSP_IMP this_rsp_type; \
//   `UVM_MS_IMP_COMMON(`UVM_TLM_NONBLOCKING_MASTER_MASK,`"uvm_nonblocking_master_imp``SFX`") \
//   \
//   `UVM_NONBLOCKING_PUT_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   \
// endclass

// // MACRO: `uvm_master_imp_decl
// //
// //| `uvm_master_imp_decl(SFX)
// //
// // Define the class uvm_master_impSFX for providing both blocking and
// // non-blocking master implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_master_imp_decl(SFX) \
// class uvm_master_imp``SFX #(type REQ=int, type RSP=int, type IMP=int, \
//                             type REQ_IMP=IMP, type RSP_IMP=IMP) \
//   extends uvm_port_base #(uvm_tlm_if_base #(REQ, RSP)); \
//   typedef IMP     this_imp_type; \
//   typedef REQ_IMP this_req_type; \
//   typedef RSP_IMP this_rsp_type; \
//   `UVM_MS_IMP_COMMON(`UVM_TLM_MASTER_MASK,`"uvm_master_imp``SFX`") \
//   \
//   `UVM_BLOCKING_PUT_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   `UVM_NONBLOCKING_PUT_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   \
// endclass

// // MACRO: `uvm_blocking_slave_imp_decl
// //
// //| `uvm_blocking_slave_imp_decl(SFX)
// //
// // Define the class uvm_blocking_slave_impSFX for providing the
// // blocking slave implemenation.

// `define uvm_blocking_slave_imp_decl(SFX) \
// class uvm_blocking_slave_imp``SFX #(type REQ=int, type RSP=int, type IMP=int, \
//                                     type REQ_IMP=IMP, type RSP_IMP=IMP) \
//   extends uvm_port_base #(uvm_tlm_if_base #(RSP, REQ)); \
//   typedef IMP     this_imp_type; \
//   typedef REQ_IMP this_req_type; \
//   typedef RSP_IMP this_rsp_type; \
//   `UVM_MS_IMP_COMMON(`UVM_TLM_BLOCKING_SLAVE_MASK,`"uvm_blocking_slave_imp``SFX`") \
//   \
//   `UVM_BLOCKING_PUT_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   \
// endclass

// // MACRO: `uvm_nonblocking_slave_imp_decl
// //
// //| `uvm_nonblocking_slave_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_slave_impSFX for providing the
// // non-blocking slave implemenation.

// `define uvm_nonblocking_slave_imp_decl(SFX) \
// class uvm_nonblocking_slave_imp``SFX #(type REQ=int, type RSP=int, type IMP=int, \
//                                        type REQ_IMP=IMP, type RSP_IMP=IMP) \
//   extends uvm_port_base #(uvm_tlm_if_base #(RSP, REQ)); \
//   typedef IMP     this_imp_type; \
//   typedef REQ_IMP this_req_type; \
//   typedef RSP_IMP this_rsp_type; \
//   `UVM_MS_IMP_COMMON(`UVM_TLM_NONBLOCKING_SLAVE_MASK,`"uvm_nonblocking_slave_imp``SFX`") \
//   \
//   `UVM_NONBLOCKING_PUT_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   \
// endclass

// // MACRO: `uvm_slave_imp_decl
// //
// //| `uvm_slave_imp_decl(SFX)
// //
// // Define the class uvm_slave_impSFX for providing both blocking and
// // non-blocking slave implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_slave_imp_decl(SFX) \
// class uvm_slave_imp``SFX #(type REQ=int, type RSP=int, type IMP=int, \
//                            type REQ_IMP=IMP, type RSP_IMP=IMP) \
//   extends uvm_port_base #(uvm_tlm_if_base #(RSP, REQ)); \
//   typedef IMP     this_imp_type; \
//   typedef REQ_IMP this_req_type; \
//   typedef RSP_IMP this_rsp_type; \
//   `UVM_MS_IMP_COMMON(`UVM_TLM_SLAVE_MASK,`"uvm_slave_imp``SFX`") \
//   \
//   `UVM_BLOCKING_PUT_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   `UVM_NONBLOCKING_PUT_IMP_SFX(SFX, m_rsp_imp, RSP, t) // rsp \
//   \
//   `UVM_BLOCKING_GET_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   `UVM_BLOCKING_PEEK_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   `UVM_NONBLOCKING_GET_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   `UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, m_req_imp, REQ, t) // req \
//   \
// endclass

// // MACRO: `uvm_blocking_transport_imp_decl
// //
// //| `uvm_blocking_transport_imp_decl(SFX)
// //
// // Define the class uvm_blocking_transport_impSFX for providing the
// // blocking transport implemenation.

// `define uvm_blocking_transport_imp_decl(SFX) \
// class uvm_blocking_transport_imp``SFX #(type REQ=int, type RSP=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(REQ, RSP)); \
//   `UVM_IMP_COMMON(`UVM_TLM_BLOCKING_TRANSPORT_MASK,`"uvm_blocking_transport_imp``SFX`",IMP) \
//   `UVM_BLOCKING_TRANSPORT_IMP_SFX(SFX, m_imp, REQ, RSP, req, rsp) \
// endclass

// // MACRO: `uvm_nonblocking_transport_imp_decl
// //
// //| `uvm_nonblocking_transport_imp_decl(SFX)
// //
// // Define the class uvm_nonblocking_transport_impSFX for providing the
// // non-blocking transport implemenation.

// `define uvm_nonblocking_transport_imp_decl(SFX) \
// class uvm_nonblocking_transport_imp``SFX #(type REQ=int, type RSP=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(REQ, RSP)); \
//   `UVM_IMP_COMMON(`UVM_TLM_NONBLOCKING_TRANSPORT_MASK,`"uvm_nonblocking_transport_imp``SFX`",IMP) \
//   `UVM_NONBLOCKING_TRANSPORT_IMP_SFX(SFX, m_imp, REQ, RSP, req, rsp) \
// endclass

// `define uvm_non_blocking_transport_imp_decl(SFX) \
//   `uvm_nonblocking_transport_imp_decl(SFX)

// // MACRO: `uvm_transport_imp_decl
// //
// //| `uvm_transport_imp_decl(SFX)
// //
// // Define the class uvm_transport_impSFX for providing both blocking and
// // non-blocking transport implementations.  ~SFX~ is the suffix for the new class
// // type.

// `define uvm_transport_imp_decl(SFX) \
// class uvm_transport_imp``SFX #(type REQ=int, type RSP=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(REQ, RSP)); \
//   `UVM_IMP_COMMON(`UVM_TLM_TRANSPORT_MASK,`"uvm_transport_imp``SFX`",IMP) \
//   `UVM_BLOCKING_TRANSPORT_IMP_SFX(SFX, m_imp, REQ, RSP, req, rsp) \
//   `UVM_NONBLOCKING_TRANSPORT_IMP_SFX(SFX, m_imp, REQ, RSP, req, rsp) \
// endclass

// // MACRO: `uvm_analysis_imp_decl
// //
// //| `uvm_analysis_imp_decl(SFX)
// //
// // Define the class uvm_analysis_impSFX for providing an analysis
// // implementation. ~SFX~ is the suffix for the new class type. The analysis
// // implemenation is the write function. The `uvm_analysis_imp_decl allows
// // for a scoreboard (or other analysis component) to support input from many
// // places. For example:
// //
// //| `uvm_analysis_imp_decl(_ingress)
// //| `uvm_analysis_imp_decl(_egress)
// //|
// //| class myscoreboard extends uvm_component;
// //|   uvm_analysis_imp_ingress#(mydata, myscoreboard) ingress;
// //|   uvm_analysis_imp_egress#(mydata, myscoreboard) egress;
// //|   mydata ingress_list[$];
// //|   ...
// //|
// //|   function new(string name, uvm_component parent);
// //|     super.new(name,parent);
// //|     ingress = new("ingress", this);
// //|     egress = new("egress", this);
// //|   endfunction
// //|
// //|   function void write_ingress(mydata t);
// //|     ingress_list.push_back(t);
// //|   endfunction
// //|
// //|   function void write_egress(mydata t);
// //|     find_match_in_ingress_list(t);
// //|   endfunction
// //|
// //|   function void find_match_in_ingress_list(mydata t);
// //|     //implement scoreboarding for this particular dut
// //|     ...
// //|   endfunction
// //| endclass

// `define uvm_analysis_imp_decl(SFX) \
// class uvm_analysis_imp``SFX #(type T=int, type IMP=int) \
//   extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
//   `UVM_IMP_COMMON(`UVM_TLM_ANALYSIS_MASK,`"uvm_analysis_imp``SFX`",IMP) \
//   function void write( input T t); \
//     m_imp.write``SFX( t); \
//   endfunction \
//   \
// endclass


// // These imps are used in uvm_*_port, uvm_*_export and uvm_*_imp, using suffixes
// //

// `define UVM_BLOCKING_PUT_IMP_SFX(SFX, imp, TYPE, arg) \
//   task put( input TYPE arg); imp.put``SFX( arg); endtask

// `define UVM_BLOCKING_GET_IMP_SFX(SFX, imp, TYPE, arg) \
//   task get( output TYPE arg); imp.get``SFX( arg); endtask

// `define UVM_BLOCKING_PEEK_IMP_SFX(SFX, imp, TYPE, arg) \
//   task peek( output TYPE arg);imp.peek``SFX( arg); endtask

// `define UVM_NONBLOCKING_PUT_IMP_SFX(SFX, imp, TYPE, arg) \
//   function bit try_put( input TYPE arg); \
//     if( !imp.try_put``SFX( arg)) return 0; \
//     return 1; \
//   endfunction \
//   function bit can_put(); return imp.can_put``SFX(); endfunction

// `define UVM_NONBLOCKING_GET_IMP_SFX(SFX, imp, TYPE, arg) \
//   function bit try_get( output TYPE arg); \
//     if( !imp.try_get``SFX( arg)) return 0; \
//     return 1; \
//   endfunction \
//   function bit can_get(); return imp.can_get``SFX(); endfunction

// `define UVM_NONBLOCKING_PEEK_IMP_SFX(SFX, imp, TYPE, arg) \
//   function bit try_peek( output TYPE arg); \
//     if( !imp.try_peek``SFX( arg)) return 0; \
//     return 1; \
//   endfunction \
//   function bit can_peek(); return imp.can_peek``SFX(); endfunction

// `define UVM_BLOCKING_TRANSPORT_IMP_SFX(SFX, imp, REQ, RSP, req_arg, rsp_arg) \
//   task transport( input REQ req_arg, output RSP rsp_arg); \
//     imp.transport``SFX(req_arg, rsp_arg); \
//   endtask

// `define UVM_NONBLOCKING_TRANSPORT_IMP_SFX(SFX, imp, REQ, RSP, req_arg, rsp_arg) \
//   function bit nb_transport( input REQ req_arg, output RSP rsp_arg); \
//     if(imp) return imp.nb_transport``SFX(req_arg, rsp_arg); \
//   endfunction

// primitive interfaces
enum int UVM_TLM_BLOCKING_PUT_MASK         =  (1<<0);
enum int UVM_TLM_BLOCKING_GET_MASK         =  (1<<1);
enum int UVM_TLM_BLOCKING_PEEK_MASK        =  (1<<2);
enum int UVM_TLM_BLOCKING_TRANSPORT_MASK   =  (1<<3);

enum int UVM_TLM_NONBLOCKING_PUT_MASK      =  (1<<4);
enum int UVM_TLM_NONBLOCKING_GET_MASK      =  (1<<5);
enum int UVM_TLM_NONBLOCKING_PEEK_MASK     =  (1<<6);
enum int UVM_TLM_NONBLOCKING_TRANSPORT_MASK=  (1<<7);

enum int UVM_TLM_ANALYSIS_MASK             =  (1<<8);

enum int UVM_TLM_MASTER_BIT_MASK           =  (1<<9);
enum int UVM_TLM_SLAVE_BIT_MASK            =  (1<<10);
// combination interfaces
enum int UVM_TLM_PUT_MASK                 =  (UVM_TLM_BLOCKING_PUT_MASK    | UVM_TLM_NONBLOCKING_PUT_MASK);
enum int UVM_TLM_GET_MASK                 =  (UVM_TLM_BLOCKING_GET_MASK    | UVM_TLM_NONBLOCKING_GET_MASK);
enum int UVM_TLM_PEEK_MASK                =  (UVM_TLM_BLOCKING_PEEK_MASK   | UVM_TLM_NONBLOCKING_PEEK_MASK);

enum int UVM_TLM_BLOCKING_GET_PEEK_MASK   =  (UVM_TLM_BLOCKING_GET_MASK    | UVM_TLM_BLOCKING_PEEK_MASK);
enum int UVM_TLM_BLOCKING_MASTER_MASK     =  (UVM_TLM_BLOCKING_PUT_MASK       | UVM_TLM_BLOCKING_GET_MASK | UVM_TLM_BLOCKING_PEEK_MASK | UVM_TLM_MASTER_BIT_MASK);
enum int UVM_TLM_BLOCKING_SLAVE_MASK      =  (UVM_TLM_BLOCKING_PUT_MASK       | UVM_TLM_BLOCKING_GET_MASK | UVM_TLM_BLOCKING_PEEK_MASK | UVM_TLM_SLAVE_BIT_MASK);

enum int UVM_TLM_NONBLOCKING_GET_PEEK_MASK=  (UVM_TLM_NONBLOCKING_GET_MASK | UVM_TLM_NONBLOCKING_PEEK_MASK);
enum int UVM_TLM_NONBLOCKING_MASTER_MASK  =  (UVM_TLM_NONBLOCKING_PUT_MASK    | UVM_TLM_NONBLOCKING_GET_MASK | UVM_TLM_NONBLOCKING_PEEK_MASK | UVM_TLM_MASTER_BIT_MASK);
enum int UVM_TLM_NONBLOCKING_SLAVE_MASK   =  (UVM_TLM_NONBLOCKING_PUT_MASK    | UVM_TLM_NONBLOCKING_GET_MASK | UVM_TLM_NONBLOCKING_PEEK_MASK | UVM_TLM_SLAVE_BIT_MASK);

enum int UVM_TLM_GET_PEEK_MASK            =  (UVM_TLM_GET_MASK | UVM_TLM_PEEK_MASK);
enum int UVM_TLM_MASTER_MASK              =  (UVM_TLM_BLOCKING_MASTER_MASK    | UVM_TLM_NONBLOCKING_MASTER_MASK);
enum int UVM_TLM_SLAVE_MASK               =  (UVM_TLM_BLOCKING_SLAVE_MASK    | UVM_TLM_NONBLOCKING_SLAVE_MASK);
enum int UVM_TLM_TRANSPORT_MASK           =  (UVM_TLM_BLOCKING_TRANSPORT_MASK | UVM_TLM_NONBLOCKING_TRANSPORT_MASK);

enum int UVM_SEQ_ITEM_GET_NEXT_ITEM_MASK      =  (1<<0);
enum int UVM_SEQ_ITEM_TRY_NEXT_ITEM_MASK      =  (1<<1);
enum int UVM_SEQ_ITEM_ITEM_DONE_MASK          =  (1<<2);
enum int UVM_SEQ_ITEM_HAS_DO_AVAILABLE_MASK   =  (1<<3);
enum int UVM_SEQ_ITEM_WAIT_FOR_SEQUENCES_MASK =  (1<<4);
enum int UVM_SEQ_ITEM_PUT_RESPONSE_MASK       =  (1<<5);
enum int UVM_SEQ_ITEM_PUT_MASK                =  (1<<6);
enum int UVM_SEQ_ITEM_GET_MASK                =  (1<<7);
enum int UVM_SEQ_ITEM_PEEK_MASK               =  (1<<8);

enum int UVM_SEQ_ITEM_PULL_MASK  = (UVM_SEQ_ITEM_GET_NEXT_ITEM_MASK |
				    UVM_SEQ_ITEM_TRY_NEXT_ITEM_MASK |
				    UVM_SEQ_ITEM_ITEM_DONE_MASK |
				    UVM_SEQ_ITEM_HAS_DO_AVAILABLE_MASK |
				    UVM_SEQ_ITEM_WAIT_FOR_SEQUENCES_MASK |
				    UVM_SEQ_ITEM_PUT_RESPONSE_MASK |
				    UVM_SEQ_ITEM_PUT_MASK |
				    UVM_SEQ_ITEM_GET_MASK |
				    UVM_SEQ_ITEM_PEEK_MASK);

enum int UVM_SEQ_ITEM_UNI_PULL_MASK = (UVM_SEQ_ITEM_GET_NEXT_ITEM_MASK |
				       UVM_SEQ_ITEM_TRY_NEXT_ITEM_MASK |
				       UVM_SEQ_ITEM_ITEM_DONE_MASK |
				       UVM_SEQ_ITEM_HAS_DO_AVAILABLE_MASK |
				       UVM_SEQ_ITEM_WAIT_FOR_SEQUENCES_MASK |
				       UVM_SEQ_ITEM_GET_MASK |
				       UVM_SEQ_ITEM_PEEK_MASK);

enum int UVM_SEQ_ITEM_PUSH_MASK  = (UVM_SEQ_ITEM_PUT_MASK);
