//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
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

module uvm.comps.uvm_in_order_comparator;
import uvm.comps.uvm_policies;

import uvm.base.uvm_component;

//------------------------------------------------------------------------------
// Title: Comparators
//
// The following classes define comparators for objects and built-in types.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
// CLASS: uvm_in_order_comparator #(T,comp_type,convert,pair_type)
//
// Compares two streams of data objects of the type parameter, T.
// These transactions may either be classes or built-in types. To be
// successfully compared, the two streams of data must be in the same order.
// Apart from that, there are no assumptions made about the relative timing of
// the two streams of data.
//
// Type parameters
//
//   T       - Specifies the type of transactions to be compared.
//
//   comp_type - A policy class to compare the two
//               transaction streams. It must provide the static method
//               "function bit comp(T a, T b)" which returns ~TRUE~
//               if ~a~ and ~b~ are the same.
//
//   convert - A policy class to convert the transactions being compared
//             to a string. It must provide the static method
//             "function string convert2string(T a)".
//
//  pair_type - A policy class to allow pairs of transactions to be handled as
//              a single <uvm_object> type.
//
// Built in types (such as ints, bits, logic, and structs) can be compared using
// the default values for comp_type, convert, and pair_type. For convenience,
// you can use the subtype, <uvm_in_order_built_in_comparator #(T)>
// for built-in types.
//
// When T is a <uvm_object>, you can use the convenience subtype
// <uvm_in_order_class_comparator #(T)>.
//
// Comparisons are commutative, meaning it does not matter which data stream is
// connected to which export, before_export or after_export.
//
// Comparisons are done in order and as soon as a transaction is received from
// both streams. Internal fifos are used to buffer incoming transactions on one
// stream until a transaction to compare arrives on the other stream.
//
//------------------------------------------------------------------------------

class uvm_in_order_comparator (T = int ,
			       comp_type = uvm_built_in_comp!T ,
			       convert = uvm_built_in_converter!T ,
			       pair_type = uvm_built_in_pair!T ):  uvm_component
{
  alias uvm_in_order_comparator!(T,comp_type,convert,pair_type) this_type;
  mixin uvm_component_utils;

  enum string type_name =
    "uvm_in_order_comparator!(T,comp_type,convert,pair_type)";

  // Port: before_export
  //
  // The export to which one stream of data is written. The port must be
  // connected to an analysis port that will provide such data.

  uvm_analysis_export!T before_export;


  // Port: after_export
  //
  // The export to which the other stream of data is written. The port must be
  // connected to an analysis port that will provide such data.

  uvm_analysis_export!T after_export;


  // Port: pair_ap
  //
  // The comparator sends out pairs of transactions across this analysis port.
  // Both matched and unmatched pairs are published via a pair_type objects.
  // Any connected analysis export(s) will receive these transaction pairs.

  uvm_analysis_port!pair_type pair_ap;

  private uvm_tlm_analysis_fifo!T m_before_fifo;
  private uvm_tlm_analysis_fifo!T m_after_fifo;

  int m_matches, m_mismatches;

  public this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);

      before_export = new uvm_analysis_export!T("before_export", this);
      after_export  = new uvm_analysis_export!T("after_export", this);
      pair_ap       = new uvm_analysis_port!pair_type("pair_ap", this);

      m_before_fifo = new uvm_tlm_analysis_fifo!T("before", this);
      m_after_fifo  = new uvm_tlm_analysis_fifo!T("after", this);
      m_matches = 0;
      m_mismatches = 0;
    }
  }

  public string get_type_name() {
    return type_name;
  }

  override public void connect_phase(uvm_phase phase) {
    before_export.connect(m_before_fifo.analysis_export);
    after_export.connect(m_after_fifo.analysis_export);
  }


  // Task- run_phase
  //
  // Internal method.
  //
  // Takes pairs of before and after transactions and compares them.
  // Status information is updated according to the results of the comparison.
  // Each pair is published to the pair_ap analysis port.

  // task
  public void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    while(true) {
      T b;
      T a;
      string s;

      m_before_fifo.get(b);
      m_after_fifo.get(a);

      if(! comp_type.comp(b, a)) {

	s = format("%s differs from %s", convert.convert2string(a),
		   convert.convert2string(b));

	uvm_report_warning("Comparator Mismatch", s);

	m_mismatches++;

      }
      else {
	s = convert.convert2string(b);
	uvm_report_info("Comparator Match", s);
	m_matches++;
      }

      // we make the assumption here that a transaction "sent for
      // analysis" is safe from being edited by another process.
      // Hence, it is safe not to clone a and b.

      pair_type pair = new pair_type("after/before");
      pair.first = a;
      pair.second = b;
      pair_ap.write(pair);
    }

  }


  // Function: flush
  //
  // This method sets m_matches and m_mismatches back to zero. The
  // <uvm_tlm_fifo::flush> takes care of flushing the FIFOs.

  public void flush() {
    synchronized(this) {
      m_matches = 0;
      m_mismatches = 0;
    }
  }

};


//------------------------------------------------------------------------------
//
// CLASS: uvm_in_order_built_in_comparator #(T)
//
// This class uses the uvm_built_in_* comparison, converter, and pair classes.
// Use this class for built-in types (int, bit, string, etc.)
//
//------------------------------------------------------------------------------

class uvm_in_order_built_in_comparator(T=int): uvm_in_order_comparator!T
{
  alias uvm_in_order_built_in_comparator!T this_type;
  mixin uvm_component_utils;

  enum  string type_name = "uvm_in_order_built_in_comparator!T";

  public this(string name, uvm_component parent) {
    super(name, parent);
  }

  public string get_type_name () {
    return type_name;
  }

}


//------------------------------------------------------------------------------
//
// CLASS: uvm_in_order_class_comparator #(T)
//
// This class uses the uvm_class_* comparison, converter, and pair classes.
// Use this class for comparing user-defined objects of type T, which must
// provide compare() and convert2string() method.
//
//------------------------------------------------------------------------------

class uvm_in_order_class_comparator(T = int ):
  uvm_in_order_comparator!(T, uvm_class_comp!T, uvm_class_converter!T,
			   uvm_class_pair!(T, T))
{
  alias uvm_in_order_class_comparator!T this_type;
  mixin uvm_component_utils;

  enum string type_name = "uvm_in_order_class_comparator!T";

  public this(string name, uvm_component parent) {
    super(name, parent);
  }

  public string get_type_name() {
    return type_name;
  }

}
