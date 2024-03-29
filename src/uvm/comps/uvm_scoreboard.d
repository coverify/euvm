//
//-----------------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
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
module uvm.comps.uvm_scoreboard;
import uvm.base;
import esdl.rand.misc: rand;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_scoreboard
//
// The uvm_scoreboard virtual class should be used as the base class for
// user-defined scoreboards.
//
// Deriving from uvm_scoreboard will allow you to distinguish scoreboards from
// other component types inheriting directly from uvm_component. Such
// scoreboards will automatically inherit and benefit from features that may be
// added to uvm_scoreboard in the future.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 13.6.1
abstract class uvm_scoreboard: uvm_component, rand.barrier
{
  mixin uvm_abstract_component_essentials;
  
  // Function -- NODOCS -- new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.

  this(string name, uvm_component parent) {
    super(name, parent);
  }

}
