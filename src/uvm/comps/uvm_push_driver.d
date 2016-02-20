//
//------------------------------------------------------------------------------
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
//------------------------------------------------------------------------------
module uvm.comps.uvm_push_driver;
import uvm.base.uvm_component;
import uvm.seq.uvm_sequence_item;
import uvm.base.uvm_globals; // uvm_report_fatal
import uvm.tlm1.uvm_imps;
import uvm.tlm1.uvm_analysis_port;

import std.string;

//------------------------------------------------------------------------------
//
// CLASS: uvm_push_driver #(REQ,RSP)
//
// Base class for a driver that passively receives transactions, i.e. does not
// initiate requests transactions. Also known as ~push~ mode. Its ports are
// typically connected to the corresponding ports in a push sequencer as follows:
//
//|  push_sequencer.req_port.connect(push_driver.req_export);
//|  push_driver.rsp_port.connect(push_sequencer.rsp_export);
//
// The ~rsp_port~ needs connecting only if the driver will use it to write
// responses to the analysis export in the sequencer.
//
//------------------------------------------------------------------------------

class uvm_push_driver(REQ=uvm_sequence_item,
		      RSP=REQ): uvm_component
{
  // Port: req_export
  //
  // This export provides the blocking put interface whose default
  // implementation produces an error. Derived drivers must override ~put~
  // with an appropriate implementation (and not call super.put). Ports
  // connected to this export will supply the driver with transactions.

  // Effectively immutable
  uvm_blocking_put_imp!(REQ, uvm_push_driver!(REQ,RSP)) req_export;

  // Port: rsp_port
  //
  // This analysis port is used to send response transactions back to the
  // originating sequencer.

  // Effectively immutable
  uvm_analysis_port!RSP rsp_port;

  REQ req;
  RSP rsp;

  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.

  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      req_export = new uvm_blocking_put_imp!(REQ, uvm_push_driver!(REQ,RSP))("req_export", this);
      rsp_port   = new uvm_analysis_port!RSP("rsp_port", this);
    }
  }

  void check_port_connections() {
    if (req_export.size() != 1) {
      uvm_report_fatal("Connection Error",
		       format("Must connect to seq_item_port(%0d)",
			      req_export.size()), UVM_NONE);
    }
  }

  void end_of_elaboration_phase(uvm_phase phase) {
    super.end_of_elaboration_phase(phase);
    check_port_connections();
  }

  // task
  void put(REQ item) {
    uvm_report_fatal("UVM_PUSH_DRIVER", "Put task for push driver is not implemented", UVM_NONE);
  }

  enum string type_name = "uvm_push_driver!(REQ,RSP)";

  string get_type_name () {
    return type_name;
  }
}
