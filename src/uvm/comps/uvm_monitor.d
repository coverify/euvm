//
//-----------------------------------------------------------------------------
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
//-----------------------------------------------------------------------------
module uvm.comps.uvm_monitor;
import uvm.base.uvm_component;

//-----------------------------------------------------------------------------
// CLASS: uvm_monitor
//
// This class should be used as the base class for user-defined monitors.
//
// Deriving from uvm_monitor allows you to distinguish monitors from generic
// component types inheriting from uvm_component.  Such monitors will
// automatically inherit features that may be added to uvm_monitor in the future.
//
//-----------------------------------------------------------------------------

abstract class uvm_monitor: uvm_component
{
  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  enum string type_name = "uvm_monitor";

  override string get_type_name () {
    return type_name;
  }
}
