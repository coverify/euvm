//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
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
module uvm.seq.uvm_sequencer_analysis_fifo;
import uvm.seq.uvm_sequencer_base;

import uvm.tlm1.uvm_tlm_fifos;
import uvm.tlm1.uvm_analysis_port;

import uvm.base.uvm_component;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;

import uvm.meta.misc;

class uvm_sequencer_analysis_fifo (RSP = uvm_sequence_item)
  : uvm_tlm_fifo!RSP
{
  mixin uvm_component_utils;

  mixin uvm_sync;

  @uvm_immutable_sync
    private uvm_analysis_imp!(RSP, uvm_sequencer_analysis_fifo!RSP)
    _analysis_export;

  @uvm_public_sync
    private uvm_sequencer_base _sequencer_ptr;

  public this(string name, uvm_component parent = null) {
    synchronized(this) {
      super(name, parent, 0);
      _analysis_export =
	new uvm_analysis_imp!(RSP, uvm_sequencer_analysis_fifo!RSP)
					    ("analysis_export", this);
    }
  }

  public void write(RSP t) {
    if (sequencer_ptr is null) {
      uvm_report_fatal ("SEQRNULL", "The sequencer pointer is null when"
			" attempting a write", UVM_NONE);
      sequencer_ptr.analysis_write(t);
    }
  }
}
