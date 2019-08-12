//
//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
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
//------------------------------------------------------------------------------
module uvm.comps.uvm_subscriber;

import uvm.base;
import uvm.tlm1.uvm_analysis_port;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_subscriber
//
// This class provides an analysis export for receiving transactions from a
// connected analysis export. Making such a connection "subscribes" this
// component to any transactions emitted by the connected analysis port.
//
// Subtypes of this class must define the write method to process the incoming
// transactions. This class is particularly useful when designing a coverage
// collector that attaches to a monitor.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 13.9.1
abstract class uvm_subscriber(T=int): uvm_component
{
  alias uvm_subscriber!T this_type;

  // Port -- NODOCS -- analysis_export
  //
  // This export provides access to the write method, which derived subscribers
  // must implement.

  // effectively immutable
  uvm_analysis_imp!(T, this_type) analysis_export;

  // Function -- NODOCS -- new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.

  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      analysis_export = new uvm_analysis_imp!(T, this_type)("analysis_imp", this);
    }
  }

  // Function -- NODOCS -- write
  //
  // A pure virtual method that must be defined in each subclass. Access
  // to this method by outside components should be done via the
  // analysis_export.

  // @uvm-ieee 1800.2-2017 auto 13.9.3.2
  abstract void write(T t);
}
